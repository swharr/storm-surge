#!/usr/bin/env python3
"""
Pytest configuration and fixtures for FinOps Controller tests
"""

import pytest
import os
import sys
from unittest.mock import Mock, patch
from datetime import datetime
import pytz

# Add parent directory to path for imports
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from finops_controller import StormSurgeFinOpsController


@pytest.fixture
def finops_controller():
    """Create a FinOps controller instance for testing"""
    return StormSurgeFinOpsController()


@pytest.fixture
def mock_credentials():
    """Mock credentials for testing"""
    return {
        'LAUNCHDARKLY_SDK_KEY': 'test-sdk-12345678-1234-1234-1234-123456789012',
        'SPOT_API_TOKEN': 'test-spot-api-token',
        'SPOT_CLUSTER_ID': 'ocn-test12345',
        'WEBHOOK_SECRET': 'test-webhook-secret'
    }


@pytest.fixture
def mock_environment(mock_credentials):
    """Mock environment variables for testing"""
    with patch.dict(os.environ, mock_credentials):
        yield mock_credentials


@pytest.fixture
def mock_business_hours():
    """Mock business hours (9 AM UTC)"""
    with patch('finops_controller.datetime') as mock_datetime:
        mock_datetime.now.return_value = datetime(2024, 1, 1, 9, 0, 0, tzinfo=pytz.UTC)
        yield mock_datetime


@pytest.fixture
def mock_after_hours():
    """Mock after hours (10 PM UTC)"""
    with patch('finops_controller.datetime') as mock_datetime:
        mock_datetime.now.return_value = datetime(2024, 1, 1, 22, 0, 0, tzinfo=pytz.UTC)
        yield mock_datetime


@pytest.fixture
def mock_weekend():
    """Mock weekend (Saturday 10 AM UTC)"""
    with patch('finops_controller.datetime') as mock_datetime:
        mock_datetime.now.return_value = datetime(2024, 1, 6, 10, 0, 0, tzinfo=pytz.UTC)
        yield mock_datetime


@pytest.fixture
def mock_launchdarkly_api():
    """Mock LaunchDarkly API responses"""
    with patch('requests.get') as mock_get:
        mock_response = Mock()
        mock_response.json.return_value = {
            "enable-cost-optimizer": True
        }
        mock_response.status_code = 200
        mock_get.return_value = mock_response
        yield mock_get


@pytest.fixture
def mock_spot_api():
    """Mock Spot Ocean API responses"""
    with patch('requests.get') as mock_get, patch('requests.put') as mock_put:
        # Mock GET cluster info response
        mock_get_response = Mock()
        mock_get_response.json.return_value = {
            "response": {
                "capacity": {
                    "target": 3,
                    "minimum": 1,
                    "maximum": 10
                }
            }
        }
        mock_get_response.status_code = 200
        mock_get.return_value = mock_get_response
        
        # Mock PUT scaling response
        mock_put_response = Mock()
        mock_put_response.status_code = 200
        mock_put.return_value = mock_put_response
        
        yield {"get": mock_get, "put": mock_put}


@pytest.fixture
def mock_webhook_payload():
    """Mock LaunchDarkly webhook payload"""
    return {
        "kind": "flag",
        "data": {
            "key": "enable-cost-optimizer",
            "value": True,
            "timestamp": datetime.now(pytz.UTC).isoformat()
        }
    }


@pytest.fixture
def mock_api_failure():
    """Mock API failure scenarios"""
    def _mock_failure(service="both"):
        patches = []
        
        if service in ["launchdarkly", "both"]:
            patches.append(patch('requests.get', side_effect=ConnectionError("LaunchDarkly API down")))
        
        if service in ["spot", "both"]:
            patches.append(patch('requests.put', side_effect=ConnectionError("Spot API down")))
        
        return patches
    
    return _mock_failure


@pytest.fixture(scope="session")
def test_data_dir():
    """Get test data directory"""
    return os.path.join(os.path.dirname(__file__), 'data')


@pytest.fixture
def sample_cluster_config():
    """Sample cluster configuration for testing"""
    return {
        "cluster_id": "ocn-test12345",
        "capacity": {
            "target": 3,
            "minimum": 1,
            "maximum": 10
        },
        "scaling_policies": {
            "scale_down_delay": 300,
            "scale_up_delay": 60
        },
        "cost_optimization": {
            "enabled": True,
            "business_hours": {
                "start": "06:00",
                "end": "18:00",
                "timezone": "UTC"
            }
        }
    }


# Pytest configuration
def pytest_configure(config):
    """Configure pytest"""
    # Add custom markers
    config.addinivalue_line(
        "markers", "integration: mark test as integration test"
    )
    config.addinivalue_line(
        "markers", "slow: mark test as slow running"
    )
    config.addinivalue_line(
        "markers", "api: mark test as API test"
    )


def pytest_collection_modifyitems(config, items):
    """Modify test collection"""
    # Add markers to tests based on their names
    for item in items:
        if "integration" in item.nodeid:
            item.add_marker(pytest.mark.integration)
        if "api" in item.nodeid:
            item.add_marker(pytest.mark.api)
        if "slow" in item.nodeid:
            item.add_marker(pytest.mark.slow)