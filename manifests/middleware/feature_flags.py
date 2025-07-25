#!/usr/bin/env python3
"""
Feature Flag Provider Abstraction Layer
Supports LaunchDarkly and Statsig providers with actual SDK integration
"""

import os
import json
import logging
import requests
import hmac
import hashlib
from abc import ABC, abstractmethod
from typing import Dict, Any, Optional
from flask import request

logger = logging.getLogger(__name__)

# Conditional imports based on available providers
try:
    from ldclient import LDClient, Config, Context
    LAUNCHDARKLY_AVAILABLE = True
    logger.info("LaunchDarkly SDK imported successfully")
except ImportError:
    LAUNCHDARKLY_AVAILABLE = False
    logger.info("LaunchDarkly SDK not available")

try:
    from statsig import statsig
    STATSIG_AVAILABLE = True
    logger.info("Statsig SDK imported successfully")
except ImportError:
    STATSIG_AVAILABLE = False
    logger.info("Statsig SDK not available")


class FeatureFlagProvider(ABC):
    """Abstract base class for feature flag providers"""
    
    @abstractmethod
    def initialize(self) -> bool:
        """Initialize the SDK client"""
        pass
    
    @abstractmethod
    def evaluate_flag(self, flag_key: str, user_context: Dict[str, Any] = None, default_value: bool = False) -> bool:
        """Evaluate a feature flag"""
        pass
    
    @abstractmethod
    def verify_webhook_signature(self, payload: bytes, signature: str) -> bool:
        """Verify webhook signature"""
        pass
    
    @abstractmethod
    def parse_webhook_payload(self, payload: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        """Parse webhook payload and extract flag information"""
        pass
    
    @abstractmethod
    def get_webhook_endpoint(self) -> str:
        """Get the webhook endpoint path"""
        pass
    
    @abstractmethod
    def close(self):
        """Close the SDK client"""
        pass


class LaunchDarklyProvider(FeatureFlagProvider):
    """LaunchDarkly feature flag provider with actual SDK integration"""
    
    def __init__(self, sdk_key: str = "", webhook_secret: str = ""):
        if not LAUNCHDARKLY_AVAILABLE:
            raise ImportError("LaunchDarkly SDK not installed. Install with: pip install launchdarkly-server-sdk")
        
        self.sdk_key = sdk_key or os.getenv('LAUNCHDARKLY_SDK_KEY', '')
        self.webhook_secret = webhook_secret or os.getenv('WEBHOOK_SECRET', '')
        self.client = None
        
        if not self.sdk_key:
            raise ValueError("LaunchDarkly SDK key is required")
    
    def initialize(self) -> bool:
        """Initialize the LaunchDarkly client"""
        try:
            config = Config(
                sdk_key=self.sdk_key,
                send_events=True,
                stream=True,  # Enable streaming for real-time updates
                application={
                    'id': 'storm-surge',
                    'version': os.getenv('APP_VERSION', 'beta-v1.1.0')
                }
            )
            self.client = LDClient(config=config)
            
            if self.client.is_initialized():
                logger.info("LaunchDarkly client initialized successfully")
                return True
            else:
                logger.error("LaunchDarkly client failed to initialize")
                return False
                
        except Exception as e:
            logger.error(f"Failed to initialize LaunchDarkly client: {e}")
            return False
    
    def evaluate_flag(self, flag_key: str, user_context: Dict[str, Any] = None, default_value: bool = False) -> bool:
        """Evaluate a LaunchDarkly feature flag"""
        if not self.client:
            logger.error("LaunchDarkly client not initialized")
            return default_value
        
        try:
            # Create LaunchDarkly context from user info
            context = Context.builder('storm-surge-system').build()
            if user_context:
                context = Context.builder(user_context.get('user_id', 'anonymous')).name(
                    user_context.get('name', 'Anonymous')
                ).build()
            
            flag_value = self.client.variation(flag_key, context, default_value)
            logger.debug(f"Evaluated flag {flag_key}: {flag_value}")
            return flag_value
            
        except Exception as e:
            logger.error(f"Failed to evaluate flag {flag_key}: {e}")
            return default_value
    
    def close(self):
        """Close the LaunchDarkly client"""
        if self.client:
            self.client.close()
            logger.info("LaunchDarkly client closed")
    
    def verify_webhook_signature(self, payload: bytes, signature: str) -> bool:
        """Verify LaunchDarkly webhook signature"""
        if not self.webhook_secret:
            logger.warning("No webhook secret configured - skipping signature verification")
            return True

        expected_signature = hmac.new(
            self.webhook_secret.encode('utf-8'),
            payload,
            hashlib.sha256
        ).hexdigest()

        return hmac.compare_digest(signature, expected_signature)
    
    def parse_webhook_payload(self, payload: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        """Parse LaunchDarkly webhook payload"""
        if payload.get('kind') == 'flag':
            flag_key = payload.get('data', {}).get('key', '')
            if flag_key == 'enable-cost-optimizer':
                return {
                    'flag_key': flag_key,
                    'flag_value': payload.get('data', {}).get('value', False),
                    'provider': 'launchdarkly'
                }
        return None
    
    def get_webhook_endpoint(self) -> str:
        return '/webhook/launchdarkly'


class StatsigProvider(FeatureFlagProvider):
    """Statsig feature flag provider with actual SDK integration"""
    
    def __init__(self, server_key: str = "", webhook_secret: str = ""):
        if not STATSIG_AVAILABLE:
            raise ImportError("Statsig SDK not installed. Install with: pip install statsig")
        
        self.server_key = server_key or os.getenv('STATSIG_SERVER_KEY', '')
        self.webhook_secret = webhook_secret or os.getenv('WEBHOOK_SECRET', '')
        self.initialized = False
        
        if not self.server_key:
            raise ValueError("Statsig server key is required")
    
    def initialize(self) -> bool:
        """Initialize the Statsig client"""
        try:
            statsig.initialize(
                self.server_key,
                options={
                    'api': os.getenv('STATSIG_API_URL', 'https://statsigapi.net/v1'),
                    'environment': {'tier': os.getenv('ENVIRONMENT', 'development')},
                    'disable_diagnostics': False,
                    'local_mode': False
                }
            )
            self.initialized = True
            logger.info("Statsig client initialized successfully")
            return True
            
        except Exception as e:
            logger.error(f"Failed to initialize Statsig client: {e}")
            return False
    
    def evaluate_flag(self, flag_key: str, user_context: Dict[str, Any] = None, default_value: bool = False) -> bool:
        """Evaluate a Statsig feature gate"""
        if not self.initialized:
            logger.error("Statsig client not initialized")
            return default_value
        
        try:
            # Create Statsig user from context
            user = {'userID': 'storm-surge-system'}
            if user_context:
                user = {
                    'userID': user_context.get('user_id', 'anonymous'),
                    'email': user_context.get('email'),
                    'custom': user_context.get('custom', {})
                }
            
            flag_value = statsig.check_gate(user, flag_key)
            logger.debug(f"Evaluated gate {flag_key}: {flag_value}")
            return flag_value
            
        except Exception as e:
            logger.error(f"Failed to evaluate gate {flag_key}: {e}")
            return default_value
    
    def close(self):
        """Close the Statsig client"""
        if self.initialized:
            try:
                statsig.shutdown()
                self.initialized = False
                logger.info("Statsig client shutdown")
            except Exception as e:
                logger.error(f"Error shutting down Statsig client: {e}")
    
    def verify_webhook_signature(self, payload: bytes, signature: str) -> bool:
        """Verify Statsig webhook signature"""
        if not self.webhook_secret:
            logger.warning("No webhook secret configured - skipping signature verification")
            return True

        expected_signature = hmac.new(
            self.webhook_secret.encode('utf-8'),
            payload,
            hashlib.sha256
        ).hexdigest()

        return hmac.compare_digest(f"sha256={expected_signature}", signature)
    
    def parse_webhook_payload(self, payload: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        """Parse Statsig webhook payload"""
        if payload.get('event_type') == 'gate_config_updated':
            gate_name = payload.get('data', {}).get('name', '')
            if gate_name == 'enable_cost_optimizer':
                return {
                    'flag_key': gate_name,
                    'flag_value': payload.get('data', {}).get('enabled', False),
                    'provider': 'statsig'
                }
        return None
    
    def get_webhook_endpoint(self) -> str:
        return '/webhook/statsig'


class FeatureFlagManager:
    """Manages feature flag providers and routing"""
    
    def __init__(self, provider_type: str):
        self.provider_type = provider_type.lower()
        self.provider = None
        self.initialized = False
        
        # Initialize the appropriate provider
        try:
            if self.provider_type == 'launchdarkly':
                sdk_key = os.getenv('LAUNCHDARKLY_SDK_KEY', '')
                webhook_secret = os.getenv('WEBHOOK_SECRET', '')
                self.provider = LaunchDarklyProvider(sdk_key, webhook_secret)
                
            elif self.provider_type == 'statsig':
                server_key = os.getenv('STATSIG_SERVER_KEY', '')
                webhook_secret = os.getenv('WEBHOOK_SECRET', '')
                self.provider = StatsigProvider(server_key, webhook_secret)
                
            else:
                raise ValueError(f"Unsupported provider type: {provider_type}")
            
            # Initialize the provider
            if self.provider:
                self.initialized = self.provider.initialize()
                if self.initialized:
                    logger.info(f"Feature flag manager initialized with {provider_type}")
                else:
                    logger.error(f"Failed to initialize {provider_type} provider")
            
        except Exception as e:
            logger.error(f"Failed to create {provider_type} provider: {e}")
            raise
    
    def get_provider(self) -> FeatureFlagProvider:
        """Get the current provider instance"""
        if not self.provider:
            raise RuntimeError("No provider initialized")
        return self.provider
    
    def get_provider_type(self) -> str:
        """Get the provider type"""
        return self.provider_type
    
    def is_initialized(self) -> bool:
        """Check if the provider is properly initialized"""
        return self.initialized
    
    def evaluate_flag(self, flag_key: str, user_context: Dict[str, Any] = None, default_value: bool = False) -> bool:
        """Evaluate a feature flag using the configured provider"""
        if not self.initialized or not self.provider:
            logger.warning(f"Provider not initialized, returning default value for {flag_key}")
            return default_value
        
        return self.provider.evaluate_flag(flag_key, user_context, default_value)
    
    def close(self):
        """Close the provider connection"""
        if self.provider:
            self.provider.close()
            self.initialized = False
            logger.info("Feature flag manager closed")