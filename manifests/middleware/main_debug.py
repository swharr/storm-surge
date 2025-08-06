#!/usr/bin/env python3
"""
OceanSurge Middleware: Feature Flag to Spot API Integration - Debug Version
Temporarily disables signature verification to debug LaunchDarkly integration
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

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# Configuration from environment variables
FEATURE_FLAG_PROVIDER = os.getenv('FEATURE_FLAG_PROVIDER', 'launchdarkly')
SPOT_API_TOKEN = os.getenv('SPOT_API_TOKEN', '')
SPOT_API_BASE_URL = "https://api.spotinst.io/ocean/gcp/k8s"
SPOT_CLUSTER_ID = os.getenv('SPOT_CLUSTER_ID', '')

class SpotOceanManager:
    def __init__(self, api_token: str, cluster_id: str):
        self.api_token = api_token
        self.cluster_id = cluster_id
        self.headers = {'Authorization': f'Bearer {api_token}', 'Content-Type': 'application/json'}

    def get_cluster_info(self) -> Dict[str, Any]:
        try:
            response = requests.get(f"{SPOT_API_BASE_URL}/cluster/{self.cluster_id}?accountId=act-a65016de", headers=self.headers)
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            logger.error(f"Failed to get cluster info: {e}")
            return {}

    def scale_cluster(self, action: str, scale_factor: float = 1.2) -> bool:
        try:
            cluster_info = self.get_cluster_info()
            if not cluster_info:
                return False
            current_capacity = cluster_info.get('response', {}).get('capacity', {})
            if action == 'optimize':
                new_capacity = {'target': max(1, int(current_capacity.get('target', 2) * 0.8)), 'minimum': current_capacity.get('minimum', 1), 'maximum': current_capacity.get('maximum', 10)}
                logger.info(f"🔽 Scaling DOWN cluster for cost optimization: {new_capacity}")
            else:
                new_capacity = {'target': min(10, int(current_capacity.get('target', 2) * scale_factor)), 'minimum': current_capacity.get('minimum', 1), 'maximum': current_capacity.get('maximum', 10)}
                logger.info(f"🔼 Scaling UP cluster for performance: {new_capacity}")
            response = requests.put(f"{SPOT_API_BASE_URL}/cluster/{self.cluster_id}?accountId=act-a65016de", headers=self.headers, json={'cluster': {'capacity': new_capacity}})
            response.raise_for_status()
            return True
        except requests.exceptions.RequestException as e:
            logger.error(f"Failed to scale cluster: {e}")
            return False

@app.route('/', methods=['GET'])
def index():
    return f"""<!DOCTYPE html><html><head><title>Storm Surge Middleware - DEBUG MODE</title><style>body{{font-family: Arial, sans-serif; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; margin: 0; padding: 2rem; text-align: center;}}.container{{background: rgba(255,255,255,0.1); padding: 2rem; border-radius: 20px; backdrop-filter: blur(10px); max-width: 600px; margin: 0 auto;}}.status{{background: rgba(255,165,0,0.9); padding: 0.5rem 1rem; border-radius: 20px; display: inline-block; margin: 1rem 0;}}a{{color: #90EE90;}}</style></head><body><div class="container"><h1>🌊 Storm Surge Feature Flag Middleware</h1><div class="status">🐛 DEBUG MODE - Signature Disabled</div><p>Feature flag integration with Spot Ocean for dynamic infrastructure management.</p><p><strong>Cluster ID:</strong> {SPOT_CLUSTER_ID}</p><p><strong>Provider:</strong> {FEATURE_FLAG_PROVIDER}</p><p><a href="/health">Health Check</a> | <a href="/api/cluster/status">Cluster Status</a></p></div></body></html>"""

@app.route('/health', methods=['GET'])
def health_check():
    return jsonify({'status': 'healthy', 'timestamp': time.time(), 'version': '0.1.1-debug'})

@app.route('/webhook/launchdarkly', methods=['POST'])
def handle_launchdarkly_webhook():
    try:
        logger.info("🚀 WEBHOOK RECEIVED - LaunchDarkly")
        
        # Log headers for debugging
        logger.info(f"📋 Headers: {dict(request.headers)}")
        
        # Get raw data for signature verification
        raw_data = request.data
        logger.info(f"📦 Raw payload size: {len(raw_data)} bytes")
        
        # Log signature from header
        signature = request.headers.get('X-LD-Signature', '')
        logger.info(f"🔐 Received signature: {signature}")
        
        # For debugging - temporarily skip signature verification
        logger.warning("⚠️  SKIPPING SIGNATURE VERIFICATION FOR DEBUG")
        
        # Parse JSON payload
        payload = request.get_json()
        if not payload:
            logger.error("❌ No JSON payload received")
            return jsonify({'error': 'Invalid JSON payload'}), 400
        
        logger.info(f"📋 LaunchDarkly webhook payload: {json.dumps(payload, indent=2)}")
        
        # Process flag change events - LaunchDarkly audit log format
        if payload.get('kind') == 'flag':
            # Extract flag key from LaunchDarkly audit log format
            flag_key = payload.get('target', {}).get('name', '')  # Try name first
            if not flag_key:
                # Fallback: extract from resources array
                resources = payload.get('target', {}).get('resources', [])
                if resources:
                    resource = resources[0]  # e.g., "proj/default:env/test:flag/enable-cost-optimizer"
                    if ':flag/' in resource:
                        flag_key = resource.split(':flag/')[-1]
            
            logger.info(f"🏴 Processing flag change: {flag_key}")
            
            if flag_key == 'enable-cost-optimizer' or flag_key == 'Enable Cost Optimizer':
                # Extract flag value from LaunchDarkly audit log format
                # Check if the flag was turned on or off based on the title/description
                title_verb = payload.get('titleVerb', '').lower()
                current_version = payload.get('currentVersion', {})
                environments = current_version.get('environments', {})
                test_env = environments.get('test', {})
                flag_value = test_env.get('on', False)
                
                logger.info(f"💰 Cost optimizer flag changed to: {flag_value} (action: {title_verb})")
                
                spot_manager = SpotOceanManager(SPOT_API_TOKEN, SPOT_CLUSTER_ID)
                
                if flag_value:
                    success = spot_manager.scale_cluster('optimize')
                    action = 'cost_optimization_enabled'
                    logger.info("🔽 COST OPTIMIZATION ENABLED - Scaling down cluster")
                else:
                    success = spot_manager.scale_cluster('performance') 
                    action = 'cost_optimization_disabled'
                    logger.info("🔼 COST OPTIMIZATION DISABLED - Scaling up cluster")
                
                logger.info(f"✅ Processed flag change: {action}, success: {success}")
                
                return jsonify({
                    'status': 'processed',
                    'action': action,
                    'success': success,
                    'timestamp': time.time(),
                    'debug': 'signature_verification_disabled'
                })
            else:
                logger.info(f"🏴 Ignoring flag: {flag_key} (not enable-cost-optimizer)")
        
        return jsonify({
            'status': 'received',
            'kind': payload.get('kind', 'unknown'),
            'timestamp': time.time(),
            'debug': 'signature_verification_disabled'
        })
        
    except Exception as e:
        logger.error(f"💥 Error processing webhook: {e}")
        return jsonify({'error': 'Internal server error'}), 500

@app.route('/api/cluster/status', methods=['GET'])
def get_cluster_status():
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
    logger.info("🚀 Starting OceanSurge Middleware - DEBUG MODE")
    logger.info("⚠️  WARNING: Signature verification is DISABLED for debugging")
    logger.info(f"📊 Spot Cluster ID: {SPOT_CLUSTER_ID}")
    app.run(host='0.0.0.0', port=8000, debug=False)