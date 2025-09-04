"""
Authentication middleware for Storm Surge API endpoints
Provides JWT-based authentication and API key validation
"""
import os
import jwt
import logging
from functools import wraps
from flask import request, jsonify
from datetime import datetime, timedelta
import hashlib
import hmac

logger = logging.getLogger(__name__)

# Configuration from environment
JWT_SECRET = os.getenv('JWT_SECRET_KEY', '')
JWT_ALGORITHM = os.getenv('JWT_ALGORITHM', 'HS256')
JWT_EXPIRATION_HOURS = int(os.getenv('JWT_EXPIRATION_HOURS', '24'))
API_KEY_HEADER = 'X-API-Key'
API_KEYS = {}  # Loaded from secrets

def load_api_keys():
    """Load API keys from environment/secrets"""
    global API_KEYS
    # Load different access level API keys
    admin_key = os.getenv('ADMIN_API_KEY', '')
    service_key = os.getenv('SERVICE_API_KEY', '')
    readonly_key = os.getenv('READONLY_API_KEY', '')
    
    if admin_key:
        API_KEYS[admin_key] = {'role': 'admin', 'permissions': ['read', 'write', 'delete']}
    if service_key:
        API_KEYS[service_key] = {'role': 'service', 'permissions': ['read', 'write']}
    if readonly_key:
        API_KEYS[readonly_key] = {'role': 'readonly', 'permissions': ['read']}

def require_api_key(required_permission='read'):
    """Decorator to require API key authentication"""
    def decorator(f):
        @wraps(f)
        def decorated_function(*args, **kwargs):
            api_key = request.headers.get(API_KEY_HEADER)
            
            if not api_key:
                logger.warning(f"Missing API key for {request.path}")
                return jsonify({'error': 'API key required'}), 401
            
            if api_key not in API_KEYS:
                logger.warning(f"Invalid API key attempt for {request.path}")
                return jsonify({'error': 'Invalid API key'}), 401
            
            key_info = API_KEYS[api_key]
            if required_permission not in key_info['permissions']:
                logger.warning(f"Insufficient permissions for {request.path}")
                return jsonify({'error': 'Insufficient permissions'}), 403
            
            # Add user context to request
            request.api_key_role = key_info['role']
            return f(*args, **kwargs)
        return decorated_function
    return decorator

def require_jwt(f):
    """Decorator to require JWT authentication"""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        token = None
        auth_header = request.headers.get('Authorization')
        
        if auth_header:
            try:
                token = auth_header.split(' ')[1]  # Bearer <token>
            except IndexError:
                return jsonify({'error': 'Invalid authorization header format'}), 401
        
        if not token:
            return jsonify({'error': 'Token required'}), 401
        
        try:
            payload = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
            request.jwt_user = payload
        except jwt.ExpiredSignatureError:
            return jsonify({'error': 'Token expired'}), 401
        except jwt.InvalidTokenError:
            return jsonify({'error': 'Invalid token'}), 401
        
        return f(*args, **kwargs)
    return decorated_function

def generate_jwt_token(user_id, role='user'):
    """Generate a JWT token for a user"""
    if not JWT_SECRET:
        raise ValueError("JWT_SECRET_KEY not configured")
    
    payload = {
        'user_id': user_id,
        'role': role,
        'exp': datetime.utcnow() + timedelta(hours=JWT_EXPIRATION_HOURS),
        'iat': datetime.utcnow()
    }
    
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)

def verify_webhook_signature(payload, signature, secret):
    """Verify webhook signature using HMAC"""
    if not secret:
        logger.error("Webhook secret not configured")
        return False
    
    expected_signature = hmac.new(
        secret.encode('utf-8'),
        payload,
        hashlib.sha256
    ).hexdigest()
    
    return hmac.compare_digest(signature, expected_signature)

# Initialize API keys on module load
load_api_keys()