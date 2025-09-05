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
from flask import Flask, request, jsonify
from flask_socketio import SocketIO, emit
from flask_cors import CORS
from typing import Dict, Any
import time
import atexit
from feature_flags import FeatureFlagManager
from logging_providers import LoggingManager
from api_routes import api_bp
from api_routes import limiter as api_limiter
from api_routes import verify_token, is_session_valid

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)
app.config['SECRET_KEY'] = os.getenv('FLASK_SECRET_KEY', 'storm-surge-secret-key-change-in-production')

# Enable CORS for React frontend (allow credentials for cookie auth)
CORS(app, origins=["http://localhost:3000", "https://storm-surge.local"], supports_credentials=True)

# Initialize SocketIO with CORS support
socketio = SocketIO(app, cors_allowed_origins=["http://localhost:3000", "https://storm-surge.local"])

# Register API blueprint
app.register_blueprint(api_bp)

# Initialize API rate limiting
api_limiter.init_app(app)

# Configuration from environment variables
FEATURE_FLAG_PROVIDER = os.getenv('FEATURE_FLAG_PROVIDER', 'launchdarkly')
LOGGING_PROVIDER = os.getenv('LOGGING_PROVIDER', 'auto')
SPOT_API_TOKEN = os.getenv('SPOT_API_TOKEN', '')
COST_IMPACT_THRESHOLD = float(os.getenv('COST_IMPACT_THRESHOLD', '0.05'))

# Spot API configuration
SPOT_API_BASE_URL = "https://api.spotinst.io/ocean/k8s"
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
                f"{SPOT_API_BASE_URL}/cluster/{self.cluster_id}",
                headers=self.headers
            )
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            logger.error(f"Failed to get cluster info: {e}")
            return {}

    def scale_cluster(self, action: str, scale_factor: float = 1.2) -> bool:
        """Scale cluster based on cost optimization flag"""
        start_time = time.time()
        details = {"scale_factor": scale_factor, "action": action}

        try:
            cluster_info = self.get_cluster_info()
            if not cluster_info:
                details["error"] = "Failed to get cluster info"
                if logging_manager:
                    logging_manager.log_cluster_action(action, self.cluster_id, False, details)
                return False

            current_capacity = cluster_info.get('response', {}).get('capacity', {})
            details["current_capacity"] = current_capacity

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

            details["new_capacity"] = new_capacity

            response = requests.put(
                f"{SPOT_API_BASE_URL}/cluster/{self.cluster_id}",
                headers=self.headers,
                json={'cluster': {'capacity': new_capacity}}
            )
            response.raise_for_status()

            details["duration_ms"] = int((time.time() - start_time) * 1000)
            details["response_status"] = response.status_code

            # Log successful cluster action
            if logging_manager:
                logging_manager.log_cluster_action(action, self.cluster_id, True, details)

            # Emit WebSocket event for real-time updates
            socketio.emit('cluster_scaled', {
                'cluster_id': self.cluster_id,
                'event_type': action,
                'success': True,
                'timestamp': time.time(),
                'details': details
            })

            return True

        except requests.exceptions.RequestException as e:
            details["error"] = str(e)
            details["duration_ms"] = int((time.time() - start_time) * 1000)

            logger.error(f"Failed to scale cluster: {e}")

            # Log failed cluster action
            if logging_manager:
                logging_manager.log_cluster_action(action, self.cluster_id, False, details)

            # Emit WebSocket event for failed scaling
            socketio.emit('cluster_scaled', {
                'cluster_id': self.cluster_id,
                'event_type': action,
                'success': False,
                'timestamp': time.time(),
                'details': details
            })

            return False




@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'timestamp': time.time(),
        'version': 'beta-v1.1.0'
    })


@app.route('/webhook/launchdarkly', methods=['POST'])
def handle_launchdarkly_webhook():
    """Handle LaunchDarkly webhook notifications"""
    return handle_feature_flag_webhook('launchdarkly')


@app.route('/webhook/statsig', methods=['POST'])
def handle_statsig_webhook():
    """Handle Statsig webhook notifications"""
    return handle_feature_flag_webhook('statsig')


def handle_feature_flag_webhook(provider_name: str):
    """Generic webhook handler for feature flag providers"""
    start_time = time.time()
    response_status = 200
    webhook_metadata = {"provider": provider_name, "endpoint": request.endpoint}

    try:
        provider = flag_manager.get_provider()

        # Verify this is the correct provider
        if flag_manager.get_provider_type() != provider_name:
            response_status = 400
            error_response = jsonify({'error': f'Wrong provider endpoint. Expected {flag_manager.get_provider_type()}'})

            # Log webhook event
            if logging_manager:
                webhook_metadata["error"] = "Wrong provider endpoint"
                webhook_metadata["duration_ms"] = int((time.time() - start_time) * 1000)
                logging_manager.log_webhook_event("webhook_error", {}, response_status, webhook_metadata)

            return error_response, response_status

        # Get signature header based on provider
        if provider_name == 'launchdarkly':
            signature = request.headers.get('X-LD-Signature', '')
        elif provider_name == 'statsig':
            signature = request.headers.get('X-Statsig-Signature', '')
        else:
            signature = ''

        # Verify webhook signature
        if not provider.verify_webhook_signature(request.data, signature):
            logger.error("Invalid webhook signature")
            response_status = 401
            error_response = jsonify({'error': 'Invalid signature'})

            # Log webhook event
            if logging_manager:
                webhook_metadata["error"] = "Invalid signature"
                webhook_metadata["duration_ms"] = int((time.time() - start_time) * 1000)
                logging_manager.log_webhook_event("webhook_error", {}, response_status, webhook_metadata)

            return error_response, response_status

        # Parse webhook payload
        try:
            payload = request.get_json(force=True)
        except Exception as json_error:
            response_status = 400
            error_response = jsonify({'error': 'Invalid JSON payload'})
            
            # Log webhook event
            if logging_manager:
                webhook_metadata["error"] = "Invalid JSON payload"
                webhook_metadata["duration_ms"] = int((time.time() - start_time) * 1000)
                logging_manager.log_webhook_event("webhook_error", {}, response_status, webhook_metadata)
                
            return error_response, response_status
            
        if not payload:
            response_status = 400
            error_response = jsonify({'error': 'Empty JSON payload'})

            # Log webhook event
            if logging_manager:
                webhook_metadata["error"] = "Invalid JSON payload"
                webhook_metadata["duration_ms"] = int((time.time() - start_time) * 1000)
                logging_manager.log_webhook_event("webhook_error", {}, response_status, webhook_metadata)

            return error_response, response_status

        logger.info(f"Received {provider_name} webhook: {payload}")

        # Parse flag data using provider-specific logic
        flag_data = provider.parse_webhook_payload(payload)

        if flag_data:
            flag_key = flag_data.get('flag_key')
            flag_value = flag_data.get('flag_value')

            # Log flag evaluation
            if logging_manager:
                logging_manager.log_flag_evaluation(
                    flag_key,
                    flag_value,
                    metadata={"source": "webhook", "provider": provider_name}
                )

            # Emit WebSocket event for flag change
            socketio.emit('flag_changed', {
                'flag_key': flag_key,
                'enabled': flag_value,
                'timestamp': time.time(),
                'provider': provider_name
            })

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

            # Log webhook processing success
            webhook_metadata.update({
                "flag_key": flag_key,
                "flag_value": flag_value,
                "action": action,
                "success": success,
                "duration_ms": int((time.time() - start_time) * 1000)
            })

            response_data = {
                'status': 'processed',
                'action': action,
                'success': success,
                'provider': provider_name,
                'flag_key': flag_key,
                'timestamp': time.time()
            }
        else:
            # No flag data to process
            webhook_metadata.update({
                "status": "received_no_action",
                "duration_ms": int((time.time() - start_time) * 1000)
            })

            response_data = {
                'status': 'received',
                'kind': payload.get('kind', 'unknown'),
                'provider': provider_name,
                'timestamp': time.time()
            }

        # Log successful webhook event
        if logging_manager:
            logging_manager.log_webhook_event("webhook_processed", payload, response_status, webhook_metadata)

        return jsonify(response_data)

    except Exception as e:
        logger.error(f"Error processing {provider_name} webhook: {e}")
        response_status = 500

        # Log webhook error
        if logging_manager:
            webhook_metadata.update({
                "error": str(e),
                "duration_ms": int((time.time() - start_time) * 1000)
            })
            logging_manager.log_webhook_event("webhook_error", {}, response_status, webhook_metadata)

        return jsonify({'error': 'Internal server error'}), response_status


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


# WebSocket connection handlers
@socketio.on('connect')
def handle_connect():
    """Handle WebSocket connection with optional auth validation in production"""
    env = os.getenv('ENVIRONMENT', 'development').lower()
    if env == 'production':
        token = request.cookies.get('auth_token')
        if not token or not is_session_valid(token) or not verify_token(token):
            logger.warning("WebSocket connect rejected: unauthenticated")
            return False  # reject connection

    logger.info("Client connected to WebSocket")
    emit('connected', {'status': 'Connected to Storm Surge'})

@socketio.on('disconnect')
def handle_disconnect():
    """Handle WebSocket disconnection"""
    logger.info("Client disconnected from WebSocket")

@socketio.on('subscribe')
def handle_subscribe(data):
    """Handle subscription to specific events"""
    logger.info(f"Client subscribed to: {data}")
    emit('subscribed', {'subscriptions': data})


if __name__ == '__main__':
    logger.info("Starting OceanSurge Middleware")
    logger.info(f"Feature Flag Provider: {FEATURE_FLAG_PROVIDER}")
    logger.info(f"Logging Provider: {logging_manager.get_provider_type() if logging_manager else 'disabled'}")
    logger.info(f"Spot API Token configured: {'Yes' if SPOT_API_TOKEN else 'No'}")
    logger.info(f"Spot Cluster ID: {SPOT_CLUSTER_ID}")

    # Log application startup
    if logging_manager:
        logging_manager.log_custom_event("application_startup", {
            "feature_flag_provider": FEATURE_FLAG_PROVIDER,
            "logging_provider": logging_manager.get_provider_type(),
            "spot_cluster_id": SPOT_CLUSTER_ID,
            "version": "1.0.1"
        })

    # Use SocketIO instead of Flask's built-in server
    socketio.run(app, host='0.0.0.0', port=8000, debug=False)
