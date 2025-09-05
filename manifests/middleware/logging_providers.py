#!/usr/bin/env python3
"""
Logging Provider Abstraction Layer
Supports LaunchDarkly and Statsig for logging feature flag events and metrics
"""

import os
import json
import logging
import requests
import time
from abc import ABC, abstractmethod
from typing import Dict, Any, Optional, List
from datetime import datetime, timezone

logger = logging.getLogger(__name__)


class LoggingProvider(ABC):
    """Abstract base class for logging providers"""

    @abstractmethod
    def log_flag_evaluation(self, flag_key: str, flag_value: Any, user_context: Optional[Dict] = None, metadata: Optional[Dict] = None) -> bool:
        """Log a feature flag evaluation event"""
        pass

    @abstractmethod
    def log_webhook_event(self, event_type: str, payload: Dict[str, Any], response_status: int, metadata: Optional[Dict] = None) -> bool:
        """Log a webhook event"""
        pass

    @abstractmethod
    def log_cluster_action(self, action: str, cluster_id: str, success: bool, details: Optional[Dict] = None) -> bool:
        """Log a cluster scaling action"""
        pass

    @abstractmethod
    def log_custom_event(self, event_name: str, properties: Dict[str, Any]) -> bool:
        """Log a custom event"""
        pass

    @abstractmethod
    def flush_events(self) -> bool:
        """Flush any pending events"""
        pass


class LaunchDarklyLoggingProvider(LoggingProvider):
    """LaunchDarkly logging provider using Events API"""

    def __init__(self, sdk_key: str):
        self.sdk_key = sdk_key
        self.events_url = "https://events.launchdarkly.com/bulk"
        self.headers = {
            'Authorization': sdk_key,
            'Content-Type': 'application/json',
            'User-Agent': 'Storm-Surge-Middleware/1.0'
        }
        self.pending_events = []
        self.max_batch_size = 100

    def _create_user_context(self, user_context: Optional[Dict] = None) -> Dict[str, Any]:
        """Create LaunchDarkly user context"""
        default_context = {
            "key": "storm-surge-middleware",
            "kind": "user",
            "name": "Storm Surge Middleware",
            "custom": {
                "service": "ocean-surge-middleware",
                "version": "1.1.0"
            }
        }

        if user_context:
            default_context["custom"].update(user_context)

        return default_context

    def log_flag_evaluation(self, flag_key: str, flag_value: Any, user_context: Optional[Dict] = None, metadata: Optional[Dict] = None) -> bool:
        """Log a feature flag evaluation event to LaunchDarkly"""
        try:
            event = {
                "kind": "feature",
                "creationDate": int(time.time() * 1000),
                "key": flag_key,
                "value": flag_value,
                "default": False,
                "user": self._create_user_context(user_context),
                "version": 1
            }

            if metadata:
                event["custom"] = metadata

            self.pending_events.append(event)

            if len(self.pending_events) >= self.max_batch_size:
                return self.flush_events()

            return True

        except Exception as e:
            logger.error(f"Failed to log flag evaluation to LaunchDarkly: {e}")
            return False

    def log_webhook_event(self, event_type: str, payload: Dict[str, Any], response_status: int, metadata: Optional[Dict] = None) -> bool:
        """Log a webhook event as a custom event"""
        properties = {
            "event_type": event_type,
            "response_status": response_status,
            "payload_size": len(json.dumps(payload)),
            "timestamp": datetime.now(timezone.utc).isoformat()
        }

        if metadata:
            properties.update(metadata)

        return self.log_custom_event("webhook_received", properties)

    def log_cluster_action(self, action: str, cluster_id: str, success: bool, details: Optional[Dict] = None) -> bool:
        """Log a cluster scaling action"""
        properties = {
            "action": action,
            "cluster_id": cluster_id,
            "success": success,
            "timestamp": datetime.now(timezone.utc).isoformat()
        }

        if details:
            properties.update(details)

        return self.log_custom_event("cluster_action", properties)

    def log_custom_event(self, event_name: str, properties: Dict[str, Any]) -> bool:
        """Log a custom event to LaunchDarkly"""
        try:
            event = {
                "kind": "custom",
                "creationDate": int(time.time() * 1000),
                "key": event_name,
                "user": self._create_user_context(),
                "data": properties
            }

            self.pending_events.append(event)

            if len(self.pending_events) >= self.max_batch_size:
                return self.flush_events()

            return True

        except Exception as e:
            logger.error(f"Failed to log custom event to LaunchDarkly: {e}")
            return False

    def flush_events(self) -> bool:
        """Flush pending events to LaunchDarkly"""
        if not self.pending_events:
            return True

        try:
            response = requests.post(
                self.events_url,
                headers=self.headers,
                json=self.pending_events,
                timeout=10
            )

            if response.status_code in [200, 202]:
                logger.info(f"Successfully sent {len(self.pending_events)} events to LaunchDarkly")
                self.pending_events.clear()
                return True
            else:
                logger.error(f"Failed to send events to LaunchDarkly: {response.status_code} - {response.text}")
                return False

        except Exception as e:
            logger.error(f"Failed to flush events to LaunchDarkly: {e}")
            return False


class StatsigLoggingProvider(LoggingProvider):
    """Statsig logging provider using Events API"""

    def __init__(self, server_key: str):
        self.server_key = server_key
        self.events_url = "https://statsigapi.net/v1/log_event"
        self.headers = {
            'STATSIG-API-KEY': server_key,
            'Content-Type': 'application/json',
            'User-Agent': 'Storm-Surge-Middleware/1.0'
        }
        self.pending_events = []
        self.max_batch_size = 100

    def _create_user_context(self, user_context: Optional[Dict] = None) -> Dict[str, Any]:
        """Create Statsig user context"""
        default_context = {
            "userID": "storm-surge-middleware",
            "email": "middleware@oceansurge.com",
            "custom": {
                "service": "ocean-surge-middleware",
                "version": "1.1.0"
            }
        }

        if user_context:
            default_context["custom"].update(user_context)

        return default_context

    def log_flag_evaluation(self, flag_key: str, flag_value: Any, user_context: Optional[Dict] = None, metadata: Optional[Dict] = None) -> bool:
        """Log a feature flag evaluation event to Statsig"""
        try:
            event = {
                "eventName": "gate_evaluation",
                "user": self._create_user_context(user_context),
                "time": int(time.time() * 1000),
                "metadata": {
                    "gate_name": flag_key,
                    "gate_value": flag_value,
                    "source": "storm_surge_middleware"
                }
            }

            if metadata:
                event["metadata"].update(metadata)

            self.pending_events.append(event)

            if len(self.pending_events) >= self.max_batch_size:
                return self.flush_events()

            return True

        except Exception as e:
            logger.error(f"Failed to log flag evaluation to Statsig: {e}")
            return False

    def log_webhook_event(self, event_type: str, payload: Dict[str, Any], response_status: int, metadata: Optional[Dict] = None) -> bool:
        """Log a webhook event"""
        properties = {
            "event_type": event_type,
            "response_status": response_status,
            "payload_size": len(json.dumps(payload)),
            "timestamp": datetime.now(timezone.utc).isoformat()
        }

        if metadata:
            properties.update(metadata)

        return self.log_custom_event("webhook_received", properties)

    def log_cluster_action(self, action: str, cluster_id: str, success: bool, details: Optional[Dict] = None) -> bool:
        """Log a cluster scaling action"""
        properties = {
            "action": action,
            "cluster_id": cluster_id,
            "success": success,
            "timestamp": datetime.now(timezone.utc).isoformat()
        }

        if details:
            properties.update(details)

        return self.log_custom_event("cluster_action", properties)

    def log_custom_event(self, event_name: str, properties: Dict[str, Any]) -> bool:
        """Log a custom event to Statsig"""
        try:
            event = {
                "eventName": event_name,
                "user": self._create_user_context(),
                "time": int(time.time() * 1000),
                "metadata": properties
            }

            self.pending_events.append(event)

            if len(self.pending_events) >= self.max_batch_size:
                return self.flush_events()

            return True

        except Exception as e:
            logger.error(f"Failed to log custom event to Statsig: {e}")
            return False

    def flush_events(self) -> bool:
        """Flush pending events to Statsig"""
        if not self.pending_events:
            return True

        try:
            payload = {
                "events": self.pending_events,
                "statsigMetadata": {
                    "sdkType": "storm-surge-middleware",
                    "sdkVersion": "1.0.1"
                }
            }

            response = requests.post(
                self.events_url,
                headers=self.headers,
                json=payload,
                timeout=10
            )

            if response.status_code in [200, 202]:
                logger.info(f"Successfully sent {len(self.pending_events)} events to Statsig")
                self.pending_events.clear()
                return True
            else:
                logger.error(f"Failed to send events to Statsig: {response.status_code} - {response.text}")
                return False

        except Exception as e:
            logger.error(f"Failed to flush events to Statsig: {e}")
            return False


class LoggingManager:
    """Manages logging providers"""

    def __init__(self, provider_type: str, feature_flag_provider_type: str):
        self.provider_type = provider_type.lower()
        self.feature_flag_provider_type = feature_flag_provider_type.lower()
        self.provider = None

        # Initialize logging provider based on type
        if self.provider_type == 'launchdarkly':
            sdk_key = os.getenv('LAUNCHDARKLY_SDK_KEY', '')
            if sdk_key:
                self.provider = LaunchDarklyLoggingProvider(sdk_key)
            else:
                logger.warning("LaunchDarkly SDK key not provided for logging")

        elif self.provider_type == 'statsig':
            server_key = os.getenv('STATSIG_SERVER_KEY', '')
            if server_key:
                self.provider = StatsigLoggingProvider(server_key)
            else:
                logger.warning("Statsig server key not provided for logging")

        elif self.provider_type == 'auto':
            # Auto-detect based on feature flag provider
            if self.feature_flag_provider_type == 'launchdarkly':
                sdk_key = os.getenv('LAUNCHDARKLY_SDK_KEY', '')
                if sdk_key:
                    self.provider = LaunchDarklyLoggingProvider(sdk_key)
                    self.provider_type = 'launchdarkly'
            elif self.feature_flag_provider_type == 'statsig':
                server_key = os.getenv('STATSIG_SERVER_KEY', '')
                if server_key:
                    self.provider = StatsigLoggingProvider(server_key)
                    self.provider_type = 'statsig'

        elif self.provider_type == 'disabled':
            logger.info("Logging provider disabled")

        else:
            logger.warning(f"Unknown logging provider type: {provider_type}")

    def get_provider(self) -> Optional[LoggingProvider]:
        """Get the current logging provider instance"""
        return self.provider

    def get_provider_type(self) -> str:
        """Get the logging provider type"""
        return self.provider_type

    def log_flag_evaluation(self, flag_key: str, flag_value: Any, user_context: Optional[Dict] = None, metadata: Optional[Dict] = None) -> bool:
        """Log flag evaluation if provider is available"""
        if self.provider:
            return self.provider.log_flag_evaluation(flag_key, flag_value, user_context, metadata)
        return True

    def log_webhook_event(self, event_type: str, payload: Dict[str, Any], response_status: int, metadata: Optional[Dict] = None) -> bool:
        """Log webhook event if provider is available"""
        if self.provider:
            return self.provider.log_webhook_event(event_type, payload, response_status, metadata)
        return True

    def log_cluster_action(self, action: str, cluster_id: str, success: bool, details: Optional[Dict] = None) -> bool:
        """Log cluster action if provider is available"""
        if self.provider:
            return self.provider.log_cluster_action(action, cluster_id, success, details)
        return True

    def log_custom_event(self, event_name: str, properties: Dict[str, Any]) -> bool:
        """Log custom event if provider is available"""
        if self.provider:
            return self.provider.log_custom_event(event_name, properties)
        return True

    def flush_events(self) -> bool:
        """Flush pending events if provider is available"""
        if self.provider:
            return self.provider.flush_events()
        return True
