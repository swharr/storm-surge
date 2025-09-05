#!/usr/bin/env python3
"""
Comprehensive tests for OceanSurge Middleware
Tests Flask API endpoints, webhook handling, and Spot API integration
"""

import unittest
import json
import os
import sys
from unittest.mock import Mock, patch, MagicMock
import tempfile
import hmac
import hashlib
import time

# Add middleware directory to path
sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'manifests', 'middleware'))

try:
    from main import app, SpotOceanManager
    from feature_flags import FeatureFlagManager
    from logging_providers import LoggingManager
    from api_routes import api_bp
    MIDDLEWARE_AVAILABLE = True
except ImportError as e:
    MIDDLEWARE_AVAILABLE = False
    print(f"Warning: Could not import middleware: {e}")


class TestMiddlewareAvailability(unittest.TestCase):
    """Test middleware availability and import"""

    def test_middleware_import(self):
        """Test that middleware can be imported"""
        self.assertTrue(MIDDLEWARE_AVAILABLE, "Middleware should be importable")


@unittest.skipIf(not MIDDLEWARE_AVAILABLE, "Middleware not available")
class TestFlaskApplication(unittest.TestCase):
    """Test Flask application endpoints"""

    def setUp(self):
        """Set up test client"""
        self.app = app
        self.app.config['TESTING'] = True
        self.client = self.app.test_client()

    def test_health_endpoint(self):
        """Test health check endpoint"""
        response = self.client.get('/health')
        self.assertEqual(response.status_code, 200)

        data = json.loads(response.data)
        self.assertEqual(data['status'], 'healthy')
        self.assertIn('timestamp', data)
        self.assertIn('version', data)

    def test_health_endpoint_response_format(self):
        """Test health endpoint returns correct format"""
        response = self.client.get('/health')
        data = json.loads(response.data)

        required_fields = ['status', 'timestamp', 'version']
        for field in required_fields:
            self.assertIn(field, data)

        self.assertIsInstance(data['timestamp'], (int, float))
        self.assertIsInstance(data['version'], str)

    def test_cluster_status_endpoint(self):
        """Test cluster status endpoint"""
        with patch('main.SpotOceanManager') as mock_manager:
            mock_instance = Mock()
            mock_instance.get_cluster_info.return_value = {
                'response': {
                    'capacity': {
                        'target': 3,
                        'minimum': 1,
                        'maximum': 10
                    }
                }
            }
            mock_manager.return_value = mock_instance

            response = self.client.get('/api/cluster/status')
            self.assertEqual(response.status_code, 200)

            data = json.loads(response.data)
            self.assertIn('cluster_id', data)
            self.assertIn('status', data)
            self.assertIn('capacity', data)
            self.assertIn('timestamp', data)

    def test_cluster_status_error_handling(self):
        """Test cluster status error handling"""
        with patch('main.SpotOceanManager') as mock_manager:
            mock_instance = Mock()
            mock_instance.get_cluster_info.side_effect = Exception("API Error")
            mock_manager.return_value = mock_instance

            response = self.client.get('/api/cluster/status')
            self.assertEqual(response.status_code, 500)

            data = json.loads(response.data)
            self.assertIn('error', data)


@unittest.skipIf(not MIDDLEWARE_AVAILABLE, "Middleware not available")
class TestWebhookHandling(unittest.TestCase):
    """Test LaunchDarkly webhook handling"""

    def setUp(self):
        """Set up test client"""
        self.app = app
        self.app.config['TESTING'] = True
        self.client = self.app.test_client()

    def test_webhook_invalid_json(self):
        """Test webhook with invalid JSON"""
        response = self.client.post('/webhook/launchdarkly',
                                   data='invalid json',
                                   content_type='application/json')
        self.assertEqual(response.status_code, 400)

        data = json.loads(response.data)
        self.assertIn('error', data)

    def test_webhook_flag_change_enable_cost_optimizer(self):
        """Test webhook for enabling cost optimizer"""
        with patch('main.SpotOceanManager') as mock_manager:
            mock_instance = Mock()
            mock_instance.scale_cluster.return_value = True
            mock_manager.return_value = mock_instance

            webhook_payload = {
                'kind': 'flag',
                'data': {
                    'key': 'enable-cost-optimizer',
                    'value': True
                }
            }

            response = self.client.post('/webhook/launchdarkly',
                                       data=json.dumps(webhook_payload),
                                       content_type='application/json')

            self.assertEqual(response.status_code, 200)

            data = json.loads(response.data)
            self.assertEqual(data['status'], 'processed')
            self.assertEqual(data['action'], 'cost_optimization_enabled')
            self.assertTrue(data['success'])

            # Verify scale_cluster was called with 'optimize'
            mock_instance.scale_cluster.assert_called_once_with('optimize')

    def test_webhook_flag_change_disable_cost_optimizer(self):
        """Test webhook for disabling cost optimizer"""
        with patch('main.SpotOceanManager') as mock_manager:
            mock_instance = Mock()
            mock_instance.scale_cluster.return_value = True
            mock_manager.return_value = mock_instance

            webhook_payload = {
                'kind': 'flag',
                'data': {
                    'key': 'enable-cost-optimizer',
                    'value': False
                }
            }

            response = self.client.post('/webhook/launchdarkly',
                                       data=json.dumps(webhook_payload),
                                       content_type='application/json')

            self.assertEqual(response.status_code, 200)

            data = json.loads(response.data)
            self.assertEqual(data['status'], 'processed')
            self.assertEqual(data['action'], 'cost_optimization_disabled')
            self.assertTrue(data['success'])

            # Verify scale_cluster was called with 'performance'
            mock_instance.scale_cluster.assert_called_once_with('performance')

    def test_webhook_unknown_flag(self):
        """Test webhook for unknown flag"""
        webhook_payload = {
            'kind': 'flag',
            'data': {
                'key': 'unknown-flag',
                'value': True
            }
        }

        response = self.client.post('/webhook/launchdarkly',
                                   data=json.dumps(webhook_payload),
                                   content_type='application/json')

        self.assertEqual(response.status_code, 200)

        data = json.loads(response.data)
        self.assertEqual(data['status'], 'received')
        self.assertEqual(data['kind'], 'flag')

    def test_webhook_non_flag_event(self):
        """Test webhook for non-flag event"""
        webhook_payload = {
            'kind': 'environment',
            'data': {
                'name': 'production'
            }
        }

        response = self.client.post('/webhook/launchdarkly',
                                   data=json.dumps(webhook_payload),
                                   content_type='application/json')

        self.assertEqual(response.status_code, 200)

        data = json.loads(response.data)
        self.assertEqual(data['status'], 'received')
        self.assertEqual(data['kind'], 'environment')

    def test_webhook_scaling_failure(self):
        """Test webhook when scaling fails"""
        with patch('main.SpotOceanManager') as mock_manager:
            mock_instance = Mock()
            mock_instance.scale_cluster.return_value = False
            mock_manager.return_value = mock_instance

            webhook_payload = {
                'kind': 'flag',
                'data': {
                    'key': 'enable-cost-optimizer',
                    'value': True
                }
            }

            response = self.client.post('/webhook/launchdarkly',
                                       data=json.dumps(webhook_payload),
                                       content_type='application/json')

            self.assertEqual(response.status_code, 200)

            data = json.loads(response.data)
            self.assertEqual(data['status'], 'processed')
            self.assertFalse(data['success'])


@unittest.skipIf(not MIDDLEWARE_AVAILABLE, "Middleware not available")
class TestWebhookSecurity(unittest.TestCase):
    """Test webhook security features"""

    def setUp(self):
        """Set up test client"""
        self.app = app
        self.app.config['TESTING'] = True
        self.client = self.app.test_client()

    def test_webhook_signature_verification(self):
        """Test webhook signature verification via FeatureFlagManager"""
        if not MIDDLEWARE_AVAILABLE:
            self.skipTest("Middleware not available")

        # Test LaunchDarkly provider signature verification
        with patch.dict(os.environ, {'FEATURE_FLAG_PROVIDER': 'launchdarkly', 'LAUNCHDARKLY_SDK_KEY': 'test-key', 'WEBHOOK_SECRET': 'test-secret'}):
            flag_manager = FeatureFlagManager('launchdarkly')
            provider = flag_manager.get_provider()

            secret = "test-secret"
            payload = b'{"kind": "flag", "data": {"key": "test"}}'

            # Create valid signature
            signature = hmac.new(
                secret.encode('utf-8'),
                payload,
                hashlib.sha256
            ).hexdigest()

            # Test with correct signature
            self.assertTrue(provider.verify_webhook_signature(payload, signature))

            # Test with incorrect signature
            self.assertFalse(provider.verify_webhook_signature(payload, "invalid"))

    @patch.dict(os.environ, {'WEBHOOK_SECRET': 'test-secret'})
    def test_webhook_with_invalid_signature(self):
        """Test webhook rejection with invalid signature"""
        webhook_payload = {
            'kind': 'flag',
            'data': {
                'key': 'enable-cost-optimizer',
                'value': True
            }
        }

        response = self.client.post('/webhook/launchdarkly',
                                   data=json.dumps(webhook_payload),
                                   content_type='application/json',
                                   headers={'X-LD-Signature': 'invalid'})

        self.assertEqual(response.status_code, 401)

        data = json.loads(response.data)
        self.assertIn('error', data)
        self.assertEqual(data['error'], 'Invalid signature')


@unittest.skipIf(not MIDDLEWARE_AVAILABLE, "Middleware not available")
class TestSpotOceanManager(unittest.TestCase):
    """Test SpotOceanManager functionality"""

    def setUp(self):
        """Set up SpotOceanManager"""
        self.manager = SpotOceanManager("test-token", "test-cluster-id")

    def test_manager_initialization(self):
        """Test SpotOceanManager initialization"""
        self.assertEqual(self.manager.api_token, "test-token")
        self.assertEqual(self.manager.cluster_id, "test-cluster-id")
        self.assertIn('Authorization', self.manager.headers)
        self.assertIn('Content-Type', self.manager.headers)

    @patch('main.requests.get')
    def test_get_cluster_info_success(self, mock_get):
        """Test successful cluster info retrieval"""
        mock_response = Mock()
        mock_response.json.return_value = {
            'response': {
                'capacity': {
                    'target': 3,
                    'minimum': 1,
                    'maximum': 10
                }
            }
        }
        mock_response.raise_for_status.return_value = None
        mock_get.return_value = mock_response

        result = self.manager.get_cluster_info()

        self.assertIsInstance(result, dict)
        self.assertIn('response', result)
        mock_get.assert_called_once()

    @patch('main.requests.get')
    def test_get_cluster_info_failure(self, mock_get):
        """Test cluster info retrieval failure"""
        mock_get.side_effect = Exception("API Error")

        result = self.manager.get_cluster_info()

        self.assertEqual(result, {})

    @patch('main.requests.put')
    @patch('main.requests.get')
    def test_scale_cluster_optimize(self, mock_get, mock_put):
        """Test cluster scaling for optimization"""
        # Mock get_cluster_info
        mock_get_response = Mock()
        mock_get_response.json.return_value = {
            'response': {
                'capacity': {
                    'target': 5,
                    'minimum': 1,
                    'maximum': 10
                }
            }
        }
        mock_get_response.raise_for_status.return_value = None
        mock_get.return_value = mock_get_response

        # Mock scale request
        mock_put_response = Mock()
        mock_put_response.raise_for_status.return_value = None
        mock_put.return_value = mock_put_response

        result = self.manager.scale_cluster('optimize')

        self.assertTrue(result)
        mock_put.assert_called_once()

        # Verify the scaling payload
        call_args = mock_put.call_args
        payload = call_args[1]['json']
        self.assertEqual(payload['cluster']['capacity']['target'], 4)  # 5 * 0.8

    @patch('main.requests.put')
    @patch('main.requests.get')
    def test_scale_cluster_performance(self, mock_get, mock_put):
        """Test cluster scaling for performance"""
        # Mock get_cluster_info
        mock_get_response = Mock()
        mock_get_response.json.return_value = {
            'response': {
                'capacity': {
                    'target': 3,
                    'minimum': 1,
                    'maximum': 10
                }
            }
        }
        mock_get_response.raise_for_status.return_value = None
        mock_get.return_value = mock_get_response

        # Mock scale request
        mock_put_response = Mock()
        mock_put_response.raise_for_status.return_value = None
        mock_put.return_value = mock_put_response

        result = self.manager.scale_cluster('performance')

        self.assertTrue(result)
        mock_put.assert_called_once()

        # Verify the scaling payload
        call_args = mock_put.call_args
        payload = call_args[1]['json']
        self.assertEqual(payload['cluster']['capacity']['target'], 3)  # 3 * 1.2 = 3.6 -> 3

    @patch('main.requests.put')
    @patch('main.requests.get')
    def test_scale_cluster_failure(self, mock_get, mock_put):
        """Test cluster scaling failure"""
        # Mock get_cluster_info to succeed
        mock_get_response = Mock()
        mock_get_response.json.return_value = {
            'response': {
                'capacity': {
                    'target': 3,
                    'minimum': 1,
                    'maximum': 10
                }
            }
        }
        mock_get_response.raise_for_status.return_value = None
        mock_get.return_value = mock_get_response

        # Mock scale request to fail
        mock_put.side_effect = Exception("Scaling failed")

        result = self.manager.scale_cluster('optimize')

        self.assertFalse(result)

    @patch('main.requests.get')
    def test_scale_cluster_no_cluster_info(self, mock_get):
        """Test cluster scaling when cluster info is unavailable"""
        mock_get.side_effect = Exception("API Error")

        result = self.manager.scale_cluster('optimize')

        self.assertFalse(result)


class TestEnvironmentConfiguration(unittest.TestCase):
    """Test environment configuration handling"""

    def test_environment_variables_access(self):
        """Test that environment variables can be accessed"""
        # Test with mock environment variables
        with patch.dict(os.environ, {
            'LAUNCHDARKLY_SDK_KEY': 'test-ld-key',
            'SPOT_API_TOKEN': 'test-spot-token',
            'SPOT_CLUSTER_ID': 'test-cluster-id',
            'WEBHOOK_SECRET': 'test-secret'
        }):
            self.assertEqual(os.getenv('LAUNCHDARKLY_SDK_KEY'), 'test-ld-key')
            self.assertEqual(os.getenv('SPOT_API_TOKEN'), 'test-spot-token')
            self.assertEqual(os.getenv('SPOT_CLUSTER_ID'), 'test-cluster-id')
            self.assertEqual(os.getenv('WEBHOOK_SECRET'), 'test-secret')

    def test_default_environment_values(self):
        """Test default environment values"""
        # Test default values when environment variables are not set
        with patch.dict(os.environ, {}, clear=True):
            self.assertEqual(os.getenv('LAUNCHDARKLY_SDK_KEY', ''), '')
            self.assertEqual(os.getenv('SPOT_API_TOKEN', ''), '')
            self.assertEqual(os.getenv('COST_IMPACT_THRESHOLD', '0.05'), '0.05')


class TestSecurityValidation(unittest.TestCase):
    """Test security validation and error handling"""

    def test_input_validation(self):
        """Test input validation for various scenarios"""
        # Test empty strings
        self.assertEqual(os.getenv('NONEXISTENT_VAR', ''), '')

        # Test numeric conversion
        threshold = float(os.getenv('COST_IMPACT_THRESHOLD', '0.05'))
        self.assertIsInstance(threshold, float)
        self.assertEqual(threshold, 0.05)

    def test_hmac_signature_validation(self):
        """Test HMAC signature validation via provider implementation"""
        if not MIDDLEWARE_AVAILABLE:
            self.skipTest("Middleware not available")

        payload = b"{\"kind\": \"flag\", \"data\": {\"key\": \"test\"}}"
        secret = "test-secret"

        # LaunchDarkly provider signature behavior
        with patch.dict(os.environ, {'FEATURE_FLAG_PROVIDER': 'launchdarkly', 'WEBHOOK_SECRET': secret}):
            fm = FeatureFlagManager('launchdarkly')
            provider = fm.get_provider()
            valid_sig = hmac.new(secret.encode('utf-8'), payload, hashlib.sha256).hexdigest()
            self.assertTrue(provider.verify_webhook_signature(payload, valid_sig))
            self.assertFalse(provider.verify_webhook_signature(payload, 'invalid'))

        # If secret empty, provider should accept (no verification case)
        with patch.dict(os.environ, {'FEATURE_FLAG_PROVIDER': 'launchdarkly', 'WEBHOOK_SECRET': ''}):
            fm = FeatureFlagManager('launchdarkly')
            provider = fm.get_provider()
            self.assertTrue(provider.verify_webhook_signature(payload, 'any'))


if __name__ == '__main__':
    # Set up test environment
    os.environ['PYTHONPATH'] = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'manifests', 'middleware')

    # Print test information
    print("🧪 Running Middleware Tests")
    print("=" * 30)

    if MIDDLEWARE_AVAILABLE:
        print("✅ Middleware is available")
    else:
        print("⚠️  Middleware import failed - some tests will be skipped")

    print()

    # Run tests
    unittest.main(verbosity=2)
