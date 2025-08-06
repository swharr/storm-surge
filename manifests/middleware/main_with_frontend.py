#!/usr/bin/env python3
"""
OceanSurge Middleware: Feature Flag to Spot API Integration
Handles feature flag webhook notifications and triggers Spot API actions
Supports LaunchDarkly and Statsig providers
"""

import os
import json
import logging
import requests
import hmac
import hashlib
from flask import Flask, request, jsonify
from typing import Dict, Any
import time
import atexit
from feature_flags import FeatureFlagManager
from logging_providers import LoggingManager

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# Configuration from environment variables
FEATURE_FLAG_PROVIDER = os.getenv('FEATURE_FLAG_PROVIDER', 'launchdarkly')
LOGGING_PROVIDER = os.getenv('LOGGING_PROVIDER', 'auto')
SPOT_API_TOKEN = os.getenv('SPOT_API_TOKEN', '')
LAUNCHDARKLY_SDK_KEY = os.getenv('LAUNCHDARKLY_SDK_KEY', '')
COST_IMPACT_THRESHOLD = float(os.getenv('COST_IMPACT_THRESHOLD', '0.05'))

# Spot API configuration
SPOT_API_BASE_URL = "https://api.spotinst.io/ocean/gcp/k8s"
SPOT_CLUSTER_ID = os.getenv('SPOT_CLUSTER_ID', '')

# Initialize feature flag manager
try:
    flag_manager = FeatureFlagManager(FEATURE_FLAG_PROVIDER)
    logger.info(f"Initialized feature flag provider: {FEATURE_FLAG_PROVIDER}")
except ValueError as e:
    logger.error(f"Failed to initialize feature flag provider: {e}")
    exit(1)

# Initialize logging manager
try:
    logging_manager = LoggingManager(LOGGING_PROVIDER, FEATURE_FLAG_PROVIDER)
    logger.info(f"Initialized logging provider: {logging_manager.get_provider_type()}")
except Exception as e:
    logger.error(f"Failed to initialize logging provider: {e}")
    logging_manager = None

# Register cleanup function to flush events on shutdown
def cleanup():
    if logging_manager:
        logging_manager.flush_events()
        logger.info("Flushed pending events on shutdown")

atexit.register(cleanup)


class SpotOceanManager:
    """Handles Spot Ocean API interactions"""

    def __init__(self, api_token: str, cluster_id: str):
        self.api_token = api_token
        self.cluster_id = cluster_id
        self.headers = {
            'Authorization': f'Bearer {api_token}',
            'Content-Type': 'application/json'
        }

    def get_cluster_info(self) -> Dict[str, Any]:
        """Get current cluster configuration"""
        try:
            response = requests.get(
                f"{SPOT_API_BASE_URL}/cluster/{self.cluster_id}?accountId=act-a65016de",
                headers=self.headers
            )
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            logger.error(f"Failed to get cluster info: {e}")
            return {}

    def scale_cluster(self, action: str, scale_factor: float = 1.2) -> bool:
        """Scale cluster based on cost optimization flag"""
        try:
            cluster_info = self.get_cluster_info()
            if not cluster_info:
                return False

            current_capacity = cluster_info.get('response', {}).get('capacity', {})

            if action == 'optimize':
                # Scale down for cost optimization
                new_capacity = {
                    'target': max(1, int(current_capacity.get('target', 2) * 0.8)),
                    'minimum': current_capacity.get('minimum', 1),
                    'maximum': current_capacity.get('maximum', 10)
                }
                logger.info(f"Scaling down cluster for cost optimization: {new_capacity}")
            else:
                # Scale up for performance
                new_capacity = {
                    'target': min(10, int(current_capacity.get('target', 2) * scale_factor)),
                    'minimum': current_capacity.get('minimum', 1),
                    'maximum': current_capacity.get('maximum', 10)
                }
                logger.info(f"Scaling up cluster for performance: {new_capacity}")

            response = requests.put(
                f"{SPOT_API_BASE_URL}/cluster/{self.cluster_id}?accountId=act-a65016de",
                headers=self.headers,
                json={'cluster': {'capacity': new_capacity}}
            )
            response.raise_for_status()
            return True

        except requests.exceptions.RequestException as e:
            logger.error(f"Failed to scale cluster: {e}")
            return False


def verify_webhook_signature(payload: bytes, signature: str) -> bool:
    """Verify LaunchDarkly webhook signature"""
    webhook_secret = os.getenv('WEBHOOK_SECRET', '')
    if not webhook_secret:
        logger.warning("No webhook secret configured - skipping signature verification")
        return True

    expected_signature = hmac.new(
        webhook_secret.encode('utf-8'),
        payload,
        hashlib.sha256
    ).hexdigest()

    return hmac.compare_digest(signature, expected_signature)


@app.route('/', methods=['GET'])
def index():
    """Serve the frontend dashboard"""
    return f"""<!DOCTYPE html>
<html>
<head>
    <title>Storm Surge Middleware</title>
    <style>
        body {{
            font-family: Arial, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            margin: 0;
            padding: 2rem;
            text-align: center;
        }}
        .container {{
            background: rgba(255,255,255,0.1);
            padding: 2rem;
            border-radius: 20px;
            backdrop-filter: blur(10px);
            max-width: 600px;
            margin: 0 auto;
        }}
        .status {{
            background: rgba(46,213,115,0.9);
            padding: 0.5rem 1rem;
            border-radius: 20px;
            display: inline-block;
            margin: 1rem 0;
        }}
        a {{
            color: #90EE90;
        }}
    </style>
</head>
<body>
    <div class="container">
        <h1>🌊 Storm Surge Feature Flag Middleware</h1>
        <div class="status">✅ Service Running</div>
        <p>Feature flag integration with Spot Ocean for dynamic infrastructure management.</p>
        <p><strong>Cluster ID:</strong> {SPOT_CLUSTER_ID}</p>
        <p><strong>Provider:</strong> {FEATURE_FLAG_PROVIDER}</p>
        <p><a href="/health">Health Check</a> | <a href="/api/cluster/status">Cluster Status</a></p>
    </div>
</body>
</html>"""


@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'timestamp': time.time(),
        'version': '0.1.1'
    })


@app.route('/webhook/launchdarkly', methods=['POST'])
def handle_launchdarkly_webhook():
    """Handle LaunchDarkly webhook notifications"""
    try:
        # Verify webhook signature
        signature = request.headers.get('X-LD-Signature', '')
        if not verify_webhook_signature(request.data, signature):
            logger.error("Invalid webhook signature")
            return jsonify({'error': 'Invalid signature'}), 401

        # Parse webhook payload
        payload = request.get_json()
        if not payload:
            return jsonify({'error': 'Invalid JSON payload'}), 400

        logger.info(f"Received LaunchDarkly webhook: {payload.get('kind', 'unknown')}")

        # Process flag change events
        if payload.get('kind') == 'flag':
            flag_key = payload.get('data', {}).get('key', '')

            if flag_key == 'enable-cost-optimizer':
                flag_value = payload.get('data', {}).get('value', False)

                # Initialize Spot Ocean manager
                spot_manager = SpotOceanManager(SPOT_API_TOKEN, SPOT_CLUSTER_ID)

                if flag_value:
                    # Cost optimization enabled - scale down
                    success = spot_manager.scale_cluster('optimize')
                    action = 'cost_optimization_enabled'
                else:
                    # Cost optimization disabled - scale up
                    success = spot_manager.scale_cluster('performance')
                    action = 'cost_optimization_disabled'

                logger.info(f"Processed flag change: {action}, success: {success}")

                return jsonify({
                    'status': 'processed',
                    'action': action,
                    'success': success,
                    'timestamp': time.time()
                })

        # Default response for other webhook types
        return jsonify({
            'status': 'received',
            'kind': payload.get('kind', 'unknown'),
            'timestamp': time.time()
        })

    except Exception as e:
        logger.error(f"Error processing webhook: {e}")
        return jsonify({'error': 'Internal server error'}), 500


@app.route('/api/cluster/status', methods=['GET'])
def get_cluster_status():
    """Get current cluster status"""
    try:
        spot_manager = SpotOceanManager(SPOT_API_TOKEN, SPOT_CLUSTER_ID)
        cluster_info = spot_manager.get_cluster_info()

        return jsonify({
            'cluster_id': SPOT_CLUSTER_ID,
            'status': 'active' if cluster_info else 'unavailable',
            'capacity': cluster_info.get('response', {}).get('capacity', {}),
            'timestamp': time.time()
        })

    except Exception as e:
        logger.error(f"Error getting cluster status: {e}")
        return jsonify({'error': 'Internal server error'}), 500


if __name__ == '__main__':
    logger.info("Starting OceanSurge Middleware")
    logger.info(f"LaunchDarkly SDK Key configured: {'Yes' if LAUNCHDARKLY_SDK_KEY else 'No'}")
    logger.info(f"Spot API Token configured: {'Yes' if SPOT_API_TOKEN else 'No'}")
    logger.info(f"Spot Cluster ID: {SPOT_CLUSTER_ID}")

    app.run(host='0.0.0.0', port=8000, debug=False)