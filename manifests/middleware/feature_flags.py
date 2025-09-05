#!/usr/bin/env python3
"""
Feature Flag Provider Abstraction Layer
Supports LaunchDarkly and Statsig providers
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


class FeatureFlagProvider(ABC):
    """Abstract base class for feature flag providers"""

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


class LaunchDarklyProvider(FeatureFlagProvider):
    """LaunchDarkly feature flag provider"""

    def __init__(self, webhook_secret: str = ""):
        self.webhook_secret = webhook_secret

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
    """Statsig feature flag provider"""

    def __init__(self, webhook_secret: str = ""):
        self.webhook_secret = webhook_secret

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
        webhook_secret = os.getenv('WEBHOOK_SECRET', '')

        if self.provider_type == 'launchdarkly':
            self.provider = LaunchDarklyProvider(webhook_secret)
        elif self.provider_type == 'statsig':
            self.provider = StatsigProvider(webhook_secret)
        else:
            raise ValueError(f"Unsupported provider type: {provider_type}")

    def get_provider(self) -> FeatureFlagProvider:
        """Get the current provider instance"""
        return self.provider

    def get_provider_type(self) -> str:
        """Get the provider type"""
        return self.provider_type
