#!/usr/bin/env python3
"""
API Routes for Storm Surge Dashboard
Extends the middleware with comprehensive REST API endpoints
"""

import os
import json
import logging
import time
from datetime import datetime, timedelta
from flask import Blueprint, request, jsonify, make_response, session
from typing import Dict, Any, List, Optional
import jwt
from functools import wraps
import hashlib
import secrets
import bcrypt
import uuid
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address
import redis
from flask_session import Session

logger = logging.getLogger(__name__)

# Create API blueprint
api_bp = Blueprint('api', __name__, url_prefix='/api')

# API rate limiter with stricter defaults
limiter = Limiter(
    key_func=get_remote_address, 
    default_limits=["100 per hour", "20 per minute"],
    storage_uri=os.getenv('REDIS_URL', 'memory://')
)

# Password hashing functions
def hash_password(password: str) -> str:
    """Hash a password using bcrypt"""
    salt = bcrypt.gensalt()
    return bcrypt.hashpw(password.encode('utf-8'), salt).decode('utf-8')

def verify_password(password: str, hashed: str) -> bool:
    """Verify a password against its hash"""
    return bcrypt.checkpw(password.encode('utf-8'), hashed.encode('utf-8'))

def generate_user_id() -> str:
    """Generate a unique user ID"""
    return str(uuid.uuid4())

# Pre-computed password hashes to avoid runtime hashing
# Passwords: admin123, operator123, viewer123
PRECOMPUTED_HASHES = {
    'admin123': '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewdBPj3w8kGuVpoi',
    'operator123': '$2b$12$EXRkfkdmHxNG8fiunsWce.k7Z5lEo3KYl6YzTcxm5Lw4QJiS5yJoq',
    'viewer123': '$2b$12$V8BNKt4BrRo9NnWONnDhXOKMn4C7cz2VKf5VvJGUqfV2k2H8WzBuO'
}

def get_mock_users():
    """Get mock users with pre-computed hashes (development only)"""
    env = os.getenv('ENVIRONMENT', 'development').lower()
    if env == 'production':
        logger.error("Mock users should not be used in production")
        return {}
    
    return {
        'admin@stormsurge.dev': {
            'id': 'admin-user-uuid-1',
            'email': 'admin@stormsurge.dev',
            'name': 'Admin User',
            'role': 'admin',
            'password_hash': PRECOMPUTED_HASHES['admin123'],
            'created_at': '2024-01-01T00:00:00Z',
            'last_login': None,
            'is_active': True,
            'failed_login_attempts': 0,
            'locked_until': None
        },
        'operator@stormsurge.dev': {
            'id': 'operator-user-uuid-2',
            'email': 'operator@stormsurge.dev', 
            'name': 'Operator User',
            'role': 'operator',
            'password_hash': PRECOMPUTED_HASHES['operator123'],
            'created_at': '2024-01-01T00:00:00Z',
            'last_login': None,
            'is_active': True,
            'failed_login_attempts': 0,
            'locked_until': None
        },
        'viewer@stormsurge.dev': {
            'id': 'viewer-user-uuid-3',
            'email': 'viewer@stormsurge.dev',
            'name': 'Viewer User', 
            'role': 'viewer',
            'password_hash': PRECOMPUTED_HASHES['viewer123'],
            'created_at': '2024-01-01T00:00:00Z',
            'last_login': None,
            'is_active': True,
            'failed_login_attempts': 0,
            'locked_until': None
        }
    }

# Mock database (in production, replace with real database)
MOCK_USERS = get_mock_users()

MOCK_FLAGS = [
    {
        'key': 'enable-cost-optimizer',
        'name': 'Cost Optimizer',
        'description': 'Enable automatic cost optimization for clusters',
        'enabled': True,
        'provider': 'launchdarkly',
        'environments': ['production', 'staging'],
        'last_modified': '2024-07-24T10:00:00Z',
        'modified_by': 'admin@stormsurge.dev',
        'tags': ['cost', 'optimization']
    },
    {
        'key': 'new-dashboard-ui',
        'name': 'New Dashboard UI',
        'description': 'Enable the new React-based dashboard interface',
        'enabled': False,
        'provider': 'statsig',
        'environments': ['development', 'staging'],
        'last_modified': '2024-07-24T09:30:00Z',
        'modified_by': 'operator@stormsurge.dev',
        'tags': ['ui', 'frontend']
    }
]

MOCK_CLUSTERS = [
    {
        'cluster_id': 'gke-prod-us-central1',
        'cluster_name': 'Production GKE',
        'provider': 'gcp',
        'current_nodes': 8,
        'target_nodes': 8,
        'min_nodes': 3,
        'max_nodes': 20,
        'cpu_utilization': 65,
        'memory_utilization': 72,
        'cost_per_hour': 12.50,
        'estimated_monthly_cost': 9000,
        'status': 'healthy',
        'last_updated': datetime.utcnow().isoformat() + 'Z'
    },
    {
        'cluster_id': 'eks-staging-us-west2',
        'cluster_name': 'Staging EKS',
        'provider': 'aws',
        'current_nodes': 4,
        'target_nodes': 4,
        'min_nodes': 2,
        'max_nodes': 10,
        'cpu_utilization': 45,
        'memory_utilization': 58,
        'cost_per_hour': 6.20,
        'estimated_monthly_cost': 4464,
        'status': 'healthy',
        'last_updated': datetime.utcnow().isoformat() + 'Z'
    }
]

# JWT configuration - Fail if not properly configured in production
JWT_SECRET = os.getenv('JWT_SECRET')
if not JWT_SECRET:
    env = os.getenv('ENVIRONMENT', 'development').lower()
    if env == 'production':
        raise ValueError("JWT_SECRET environment variable must be set in production")
    JWT_SECRET = 'development-secret-key-not-for-production'
    logger.warning("Using development JWT secret - NOT SUITABLE FOR PRODUCTION")

JWT_ALGORITHM = 'HS256'
JWT_EXPIRATION = 24 * 60 * 60  # 24 hours

# Redis connection for session storage
redis_client = None

def init_redis():
    """Initialize Redis connection for session storage"""
    global redis_client
    try:
        redis_url = os.getenv('REDIS_URL', 'redis://localhost:6379/0')
        redis_client = redis.from_url(redis_url, decode_responses=True)
        redis_client.ping()  # Test connection
        logger.info(f"Redis connected successfully: {redis_url}")
        return True
    except Exception as e:
        logger.warning(f"Redis connection failed: {e}. Falling back to in-memory sessions")
        return False

# Fallback in-memory sessions for development
_memory_sessions = {}

def create_session(user_id: str, token: str) -> None:
    """Create a new session in Redis or memory fallback"""
    session_data = {
        'user_id': user_id,
        'created_at': datetime.utcnow().isoformat(),
        'last_activity': datetime.utcnow().isoformat()
    }
    
    if redis_client:
        try:
            redis_client.setex(f"session:{token}", JWT_EXPIRATION, json.dumps(session_data))
            return
        except Exception as e:
            logger.error(f"Redis session creation failed: {e}")
    
    # Fallback to memory
    _memory_sessions[token] = {
        'user_id': user_id,
        'created_at': datetime.utcnow(),
        'last_activity': datetime.utcnow()
    }

def invalidate_session(token: str) -> None:
    """Invalidate a session"""
    if redis_client:
        try:
            redis_client.delete(f"session:{token}")
            return
        except Exception as e:
            logger.error(f"Redis session invalidation failed: {e}")
    
    # Fallback to memory
    _memory_sessions.pop(token, None)

def invalidate_all_user_sessions(user_id: str) -> None:
    """Invalidate all sessions for a user (for session rotation)"""
    if redis_client:
        try:
            # Find and delete all sessions for this user
            for key in redis_client.scan_iter(match="session:*"):
                session_data = redis_client.get(key)
                if session_data:
                    data = json.loads(session_data)
                    if data.get('user_id') == user_id:
                        redis_client.delete(key)
            return
        except Exception as e:
            logger.error(f"Redis bulk session invalidation failed: {e}")
    
    # Fallback to memory
    to_remove = [token for token, data in _memory_sessions.items() if data['user_id'] == user_id]
    for token in to_remove:
        _memory_sessions.pop(token, None)

def is_session_valid(token: str) -> bool:
    """Check if session is valid and update last activity"""
    if redis_client:
        try:
            session_data = redis_client.get(f"session:{token}")
            if session_data:
                data = json.loads(session_data)
                data['last_activity'] = datetime.utcnow().isoformat()
                redis_client.setex(f"session:{token}", JWT_EXPIRATION, json.dumps(data))
                return True
            return False
        except Exception as e:
            logger.error(f"Redis session validation failed: {e}")
    
    # Fallback to memory
    if token in _memory_sessions:
        _memory_sessions[token]['last_activity'] = datetime.utcnow()
        return True
    return False

def generate_token(user_data: Dict[str, Any]) -> str:
    """Generate JWT token for user"""
    payload = {
        'user_id': user_data['id'],
        'email': user_data['email'],
        'role': user_data['role'],
        'exp': datetime.utcnow() + timedelta(seconds=JWT_EXPIRATION),
        'iat': datetime.utcnow()
    }
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)

def verify_token(token: str) -> Optional[Dict[str, Any]]:
    """Verify JWT token and return user data"""
    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
        return payload
    except jwt.ExpiredSignatureError:
        return None
    except jwt.InvalidTokenError:
        return None

def require_auth(f):
    """Decorator to require authentication with session validation"""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        # Prefer httpOnly cookie; fall back to Authorization header for backward compatibility
        token = request.cookies.get('auth_token')
        if not token:
            auth_header = request.headers.get('Authorization')
            if auth_header and auth_header.startswith('Bearer '):
                token = auth_header.split(' ')[1]
        if not token:
            return jsonify({'error': 'Authentication required'}), 401
        
        # Check if session is valid
        if not is_session_valid(token):
            return jsonify({'error': 'Session expired or invalid'}), 401
        
        user_data = verify_token(token)
        if not user_data:
            invalidate_session(token)
            return jsonify({'error': 'Invalid or expired token'}), 401
        
        # Check if user is still active
        user = MOCK_USERS.get(user_data.get('email', ''))
        if not user or not user.get('is_active', True):
            invalidate_session(token)
            return jsonify({'error': 'Account is disabled'}), 401
        
        request.current_user = user_data
        return f(*args, **kwargs)
    return decorated_function

def require_role(required_role: str):
    """Decorator to require specific role"""
    def decorator(f):
        @wraps(f)
        def decorated_function(*args, **kwargs):
            if not hasattr(request, 'current_user'):
                return jsonify({'error': 'Authentication required'}), 401
            
            user_role = request.current_user.get('role')
            role_hierarchy = {'viewer': 1, 'operator': 2, 'admin': 3}
            
            if role_hierarchy.get(user_role, 0) < role_hierarchy.get(required_role, 999):
                return jsonify({'error': 'Insufficient permissions'}), 403
            
            return f(*args, **kwargs)
        return decorated_function
    return decorator


# CSRF protection for state-changing requests when using cookie auth
def require_csrf(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        # Skip CSRF for safe methods
        if request.method in ('GET', 'HEAD', 'OPTIONS'):
            return f(*args, **kwargs)
        # Allow login without CSRF (no session yet)
        if request.path.endswith('/auth/login'):
            return f(*args, **kwargs)
        csrf_cookie = request.cookies.get('csrf_token')
        csrf_header = request.headers.get('X-CSRF-Token')
        
        # Use constant-time comparison to prevent timing attacks
        if not csrf_cookie or not csrf_header or not secrets.compare_digest(csrf_cookie, csrf_header):
            return jsonify({'error': 'CSRF validation failed'}), 403
        return f(*args, **kwargs)
    return decorated_function

# Authentication endpoints
@api_bp.route('/auth/login', methods=['POST'])
@limiter.limit("5 per minute")
def login():
    """User login endpoint with security features"""
    data = request.get_json()
    email = data.get('email', '').lower().strip()
    password = data.get('password', '')
    
    if not email or not password:
        return jsonify({'error': 'Email and password required'}), 400
    
    user = MOCK_USERS.get(email)
    if not user:
        return jsonify({'error': 'Invalid credentials'}), 401
    
    # Check if account is active
    if not user.get('is_active', True):
        return jsonify({'error': 'Account is disabled'}), 401
    
    # Check if account is locked
    locked_until = user.get('locked_until')
    if locked_until and datetime.fromisoformat(locked_until.replace('Z', '+00:00')) > datetime.utcnow():
        return jsonify({'error': 'Account is temporarily locked due to failed login attempts'}), 401
    
    # Verify password using bcrypt
    if not verify_password(password, user['password_hash']):
        # Increment failed login attempts
        user['failed_login_attempts'] = user.get('failed_login_attempts', 0) + 1
        
        # Lock account after 5 failed attempts for 15 minutes
        if user['failed_login_attempts'] >= 5:
            user['locked_until'] = (datetime.utcnow() + timedelta(minutes=15)).isoformat() + 'Z'
            return jsonify({'error': 'Account locked due to too many failed login attempts. Try again in 15 minutes.'}), 401
        
        return jsonify({'error': 'Invalid credentials'}), 401
    
    # Reset failed login attempts on successful login
    user['failed_login_attempts'] = 0
    user['locked_until'] = None
    
    # Update last login
    user['last_login'] = datetime.utcnow().isoformat() + 'Z'
    
    # Generate token and CSRF token
    token = generate_token(user)
    csrf_token = secrets.token_urlsafe(24)

    # Create session
    create_session(user['id'], token)

    # Prepare response and set cookies
    user_data = {k: v for k, v in user.items() if k not in ['password_hash', 'failed_login_attempts', 'locked_until']}
    logger.info(f"User {email} logged in successfully")

    resp = make_response(jsonify({'user': user_data}))
    # Determine cookie security
    secure_cookies = os.getenv('ENVIRONMENT', 'production').lower() == 'production'
    # Auth cookie: httpOnly, secure (in prod), strict same-site
    resp.set_cookie(
        'auth_token', token,
        httponly=True, secure=secure_cookies, samesite='Strict', max_age=JWT_EXPIRATION, path='/'
    )
    # CSRF cookie: readable by JS to set header
    resp.set_cookie(
        'csrf_token', csrf_token,
        httponly=False, secure=secure_cookies, samesite='Strict', max_age=JWT_EXPIRATION, path='/'
    )
    return resp

@api_bp.route('/auth/logout', methods=['POST'])
@require_auth
@require_csrf
def logout():
    """User logout endpoint with session invalidation"""
    auth_header = request.headers.get('Authorization')
    if auth_header and auth_header.startswith('Bearer '):
        token = auth_header.split(' ')[1]
        invalidate_session(token)
        logger.info(f"User {request.current_user.get('email')} logged out")
    resp = make_response(jsonify({'message': 'Logged out successfully'}))
    # Clear cookies
    resp.set_cookie('auth_token', '', expires=0, path='/')
    resp.set_cookie('csrf_token', '', expires=0, path='/')
    return resp

@api_bp.route('/auth/register', methods=['POST'])
@limiter.limit("3 per minute")  # Strict rate limiting for user creation
@require_auth
@require_role('admin')
@require_csrf
def register_user():
    """User registration endpoint (admin only)"""
    data = request.get_json()
    email = data.get('email', '').lower().strip()
    password = data.get('password', '')
    name = data.get('name', '').strip()
    role = data.get('role', 'viewer').lower()
    
    # Validation
    if not email or not password or not name:
        return jsonify({'error': 'Email, password, and name are required'}), 400
    
    if len(password) < 8:
        return jsonify({'error': 'Password must be at least 8 characters long'}), 400
    
    if role not in ['admin', 'operator', 'viewer']:
        return jsonify({'error': 'Invalid role. Must be admin, operator, or viewer'}), 400
    
    if email in MOCK_USERS:
        return jsonify({'error': 'User with this email already exists'}), 409
    
    # Create new user
    user_id = generate_user_id()
    new_user = {
        'id': user_id,
        'email': email,
        'name': name,
        'role': role,
        'password_hash': hash_password(password),
        'created_at': datetime.utcnow().isoformat() + 'Z',
        'last_login': None,
        'is_active': True,
        'failed_login_attempts': 0,
        'locked_until': None
    }
    
    MOCK_USERS[email] = new_user
    
    # Return user data without sensitive fields
    user_data = {k: v for k, v in new_user.items() if k not in ['password_hash', 'failed_login_attempts', 'locked_until']}
    
    logger.info(f"New user {email} registered by {request.current_user.get('email')}")
    
    return jsonify({
        'message': 'User registered successfully',
        'user': user_data
    }), 201

@api_bp.route('/auth/change-password', methods=['POST'])
@limiter.limit("3 per minute")  # Rate limit password changes
@require_auth
@require_csrf
def change_password():
    """Change user password"""
    data = request.get_json()
    current_password = data.get('current_password', '')
    new_password = data.get('new_password', '')
    
    if not current_password or not new_password:
        return jsonify({'error': 'Current password and new password are required'}), 400
    
    if len(new_password) < 8:
        return jsonify({'error': 'New password must be at least 8 characters long'}), 400
    
    user_email = request.current_user.get('email')
    user = MOCK_USERS.get(user_email)
    
    if not user:
        return jsonify({'error': 'User not found'}), 404
    
    # Verify current password
    if not verify_password(current_password, user['password_hash']):
        return jsonify({'error': 'Current password is incorrect'}), 401
    
    # Update password
    user['password_hash'] = hash_password(new_password)
    
    # Invalidate all sessions for security (session rotation)
    invalidate_all_user_sessions(user['id'])
    
    logger.info(f"User {user_email} changed their password - all sessions invalidated")
    
    return jsonify({
        'message': 'Password changed successfully. Please log in again.',
        'session_invalidated': True
    })

@api_bp.route('/auth/me', methods=['GET'])
@require_auth
def get_current_user():
    """Get current user information"""
    user_id = request.current_user['user_id']
    user_email = request.current_user['email']
    
    # Find user in mock database
    user = next((u for u in MOCK_USERS.values() if u['id'] == user_id), None)
    if not user:
        return jsonify({'error': 'User not found'}), 404
    
    user_data = {k: v for k, v in user.items() if k not in ['password_hash', 'failed_login_attempts', 'locked_until']}
    return jsonify(user_data)

# User management endpoints (admin only)
@api_bp.route('/users', methods=['GET'])
@require_auth
@require_role('admin')
def list_users():
    """List all users (admin only)"""
    users = []
    for user in MOCK_USERS.values():
        user_data = {k: v for k, v in user.items() if k not in ['password_hash', 'failed_login_attempts', 'locked_until']}
        users.append(user_data)
    
    return jsonify(users)

@api_bp.route('/users', methods=['POST'])
@require_auth
@require_role('admin')
@require_csrf
def create_user():
    """Create a new user (admin only)"""
    data = request.get_json()
    
    # Validate required fields
    required_fields = ['email', 'password', 'name', 'role']
    for field in required_fields:
        if not data.get(field):
            return jsonify({'error': f'Missing required field: {field}'}), 400
    
    # Check if user already exists
    if data['email'] in MOCK_USERS:
        return jsonify({'error': 'User already exists'}), 400
    
    # Validate role
    if data['role'] not in ['admin', 'operator', 'viewer']:
        return jsonify({'error': 'Invalid role'}), 400
    
    # Create new user
    user_id = generate_user_id()
    new_user = {
        'id': user_id,
        'email': data['email'],
        'name': data['name'],
        'role': data['role'],
        'password_hash': hash_password(data['password']),
        'created_at': datetime.utcnow().isoformat() + 'Z',
        'last_login': None,
        'is_active': True,
        'failed_login_attempts': 0,
        'locked_until': None
    }
    
    # Add to mock database
    MOCK_USERS[data['email']] = new_user
    
    # Return user data (without password hash)
    user_response = {k: v for k, v in new_user.items() if k not in ['password_hash', 'failed_login_attempts', 'locked_until']}
    
    return jsonify({
        'message': 'User created successfully',
        'user': user_response
    }), 201

@api_bp.route('/users/<user_id>', methods=['GET'])
@require_auth
@require_role('admin')
def get_user(user_id):
    """Get specific user (admin only)"""
    user = next((u for u in MOCK_USERS.values() if u['id'] == user_id), None)
    if not user:
        return jsonify({'error': 'User not found'}), 404
    
    user_data = {k: v for k, v in user.items() if k not in ['password_hash', 'failed_login_attempts', 'locked_until']}
    return jsonify(user_data)

@api_bp.route('/users/<user_id>', methods=['PUT'])
@require_auth
@require_role('admin')
@require_csrf
def update_user(user_id):
    """Update user (admin only)"""
    data = request.get_json()
    
    user = next((u for u in MOCK_USERS.values() if u['id'] == user_id), None)
    if not user:
        return jsonify({'error': 'User not found'}), 404
    
    # Update allowed fields
    if 'name' in data:
        user['name'] = data['name'].strip()
    
    if 'role' in data:
        if data['role'] not in ['admin', 'operator', 'viewer']:
            return jsonify({'error': 'Invalid role'}), 400
        user['role'] = data['role']
    
    if 'is_active' in data:
        user['is_active'] = bool(data['is_active'])
    
    # Reset failed login attempts if reactivating user
    if data.get('is_active') and not user.get('is_active'):
        user['failed_login_attempts'] = 0
        user['locked_until'] = None
    
    logger.info(f"User {user['email']} updated by {request.current_user.get('email')}")
    
    user_data = {k: v for k, v in user.items() if k not in ['password_hash', 'failed_login_attempts', 'locked_until']}
    return jsonify(user_data)

@api_bp.route('/users/<user_id>', methods=['DELETE'])
@require_auth
@require_role('admin')
@require_csrf
def delete_user(user_id):
    """Delete user (admin only)"""
    # Prevent deleting self
    if user_id == request.current_user.get('user_id'):
        return jsonify({'error': 'Cannot delete your own account'}), 400
    
    user_email = None
    for email, user in list(MOCK_USERS.items()):
        if user['id'] == user_id:
            user_email = email
            break
    
    if not user_email:
        return jsonify({'error': 'User not found'}), 404
    
    del MOCK_USERS[user_email]
    
    logger.info(f"User {user_email} deleted by {request.current_user.get('email')}")
    
    return jsonify({'message': 'User deleted successfully'})

@api_bp.route('/users/<user_id>/reset-password', methods=['POST'])
@limiter.limit("5 per minute")  # Rate limit password resets
@require_auth
@require_role('admin')
@require_csrf
def reset_user_password(user_id):
    """Reset user password (admin only)"""
    data = request.get_json()
    new_password = data.get('new_password', '')
    
    if len(new_password) < 8:
        return jsonify({'error': 'New password must be at least 8 characters long'}), 400
    
    user = next((u for u in MOCK_USERS.values() if u['id'] == user_id), None)
    if not user:
        return jsonify({'error': 'User not found'}), 404
    
    # Update password and reset login attempts
    user['password_hash'] = hash_password(new_password)
    user['failed_login_attempts'] = 0
    user['locked_until'] = None
    
    logger.info(f"Password reset for user {user['email']} by {request.current_user.get('email')}")
    
    return jsonify({'message': 'Password reset successfully'})

# Feature flags endpoints
@api_bp.route('/flags', methods=['GET'])
@require_auth
def get_flags():
    """Get all feature flags"""
    return jsonify(MOCK_FLAGS)

@api_bp.route('/flags/<flag_key>', methods=['GET'])
@require_auth
def get_flag(flag_key):
    """Get specific feature flag"""
    flag = next((f for f in MOCK_FLAGS if f['key'] == flag_key), None)
    if not flag:
        return jsonify({'error': 'Flag not found'}), 404
    return jsonify(flag)

@api_bp.route('/flags/<flag_key>/toggle', methods=['PATCH'])
@require_auth
@require_role('operator')
def toggle_flag(flag_key):
    """Toggle feature flag on/off"""
    flag = next((f for f in MOCK_FLAGS if f['key'] == flag_key), None)
    if not flag:
        return jsonify({'error': 'Flag not found'}), 404
    
    data = request.get_json()
    enabled = data.get('enabled')
    
    if enabled is None:
        return jsonify({'error': 'enabled field required'}), 400
    
    flag['enabled'] = bool(enabled)
    flag['last_modified'] = datetime.utcnow().isoformat() + 'Z'
    flag['modified_by'] = request.current_user['email']
    
    return jsonify(flag)

# Clusters endpoints
@api_bp.route('/clusters', methods=['GET'])
@require_auth
def get_clusters():
    """Get all clusters"""
    return jsonify(MOCK_CLUSTERS)

@api_bp.route('/clusters/<cluster_id>', methods=['GET'])
@require_auth
def get_cluster(cluster_id):
    """Get specific cluster"""
    cluster = next((c for c in MOCK_CLUSTERS if c['cluster_id'] == cluster_id), None)
    if not cluster:
        return jsonify({'error': 'Cluster not found'}), 404
    return jsonify(cluster)

# Cost metrics endpoints
@api_bp.route('/costs/metrics', methods=['GET'])
@require_auth
def get_cost_metrics():
    """Get cost metrics"""
    time_range = request.args.get('range', '24h')
    
    # Mock cost data
    total_hourly = sum(c['cost_per_hour'] for c in MOCK_CLUSTERS)
    
    metrics = {
        'current_hourly': total_hourly,
        'projected_daily': total_hourly * 24,
        'projected_monthly': total_hourly * 24 * 30,
        'savings_today': 45.30,
        'savings_this_month': 1250.80,
        'optimization_percentage': 15.2,
        'last_optimization': '2024-07-24T08:30:00Z'
    }
    
    return jsonify(metrics)

@api_bp.route('/costs/history', methods=['GET'])
@require_auth
def get_cost_history():
    """Get historical cost data"""
    time_range = request.args.get('range', '7d')
    
    # Generate mock historical data
    days = 7 if time_range == '7d' else 30
    history = []
    
    base_cost = sum(c['cost_per_hour'] for c in MOCK_CLUSTERS) * 24
    
    for i in range(days):
        date = datetime.utcnow() - timedelta(days=days-i-1)
        cost = base_cost + (i * 10) + ((-1) ** i * 50)  # Add some variation
        savings = cost * 0.15  # 15% savings
        
        history.append({
            'timestamp': date.isoformat() + 'Z',
            'cost': round(cost, 2),
            'savings': round(savings, 2)
        })
    
    return jsonify(history)

# Scaling events endpoints
@api_bp.route('/scaling-events', methods=['GET'])
@require_auth
def get_scaling_events():
    """Get scaling events"""
    cluster_id = request.args.get('clusterId')
    limit = int(request.args.get('limit', 50))
    
    # Mock scaling events data
    events = []
    for i in range(min(limit, 20)):
        event_time = datetime.utcnow() - timedelta(hours=i*2, minutes=i*15)
        events.append({
            'id': f'event_{i+1}',
            'cluster_id': cluster_id or MOCK_CLUSTERS[i % len(MOCK_CLUSTERS)]['cluster_id'],
            'event_type': 'scale_up' if i % 2 == 0 else 'scale_down',
            'old_node_count': 5 + (i % 3),
            'new_node_count': 6 + (i % 3) if i % 2 == 0 else 4 + (i % 3),
            'reason': 'Cost optimization' if i % 3 == 0 else 'High CPU utilization',
            'triggered_by': 'system',
            'timestamp': event_time.isoformat() + 'Z',
            'success': True,
            'duration': 1200 + (i * 100),
            'cost_impact': round((-1) ** i * 2.5, 2)
        })
    
    return jsonify(events)

# System health endpoint
@api_bp.route('/health', methods=['GET'])
def get_system_health():
    """Get system health status"""
    health = {
        'status': 'healthy',
        'components': {
            'api': 'up',
            'database': 'up',
            'flag_provider': 'up',
            'clusters': 'up'
        },
        'uptime': 157320,  # seconds
        'last_health_check': datetime.utcnow().isoformat() + 'Z',
        'version': '1.1.0'
    }
    
    return jsonify(health)

# Settings endpoints
@api_bp.route('/settings', methods=['GET'])
@require_auth
@require_role('admin')
def get_settings():
    """Get system settings"""
    settings = {
        'feature_flag_provider': os.getenv('FEATURE_FLAG_PROVIDER', 'launchdarkly'),
        'logging_provider': os.getenv('LOGGING_PROVIDER', 'auto'),
        'cost_impact_threshold': float(os.getenv('COST_IMPACT_THRESHOLD', '0.05')),
        'auto_scaling_enabled': True,
        'cost_optimization_enabled': True,
        'notification_settings': {
            'email_enabled': True,
            'slack_enabled': False,
            'webhook_enabled': True
        }
    }
    
    return jsonify(settings)

@api_bp.route('/test-connection', methods=['POST'])
@require_auth
@require_role('admin')
def test_connection():
    """Test connection to external services"""
    data = request.get_json()
    provider = data.get('provider')
    credentials = data.get('credentials', {})
    
    # Mock connection test
    if provider in ['launchdarkly', 'statsig']:
        # In real implementation, test actual connection
        success = len(credentials.get('api_key', '')) > 10
        message = 'Connection successful' if success else 'Invalid credentials'
        
        return jsonify({
            'success': success,
            'message': message
        })
    
    return jsonify({
        'success': False,
        'message': 'Unsupported provider'
    }), 400

# Export endpoints
@api_bp.route('/export/<data_type>', methods=['GET'])
@require_auth
@require_role('operator')
def export_data(data_type):
    """Export data in various formats"""
    format_type = request.args.get('format', 'csv')
    
    if data_type not in ['audit_logs', 'scaling_events', 'cost_reports']:
        return jsonify({'error': 'Invalid data type'}), 400
    
    # Mock CSV export
    if format_type == 'csv':
        csv_content = f"# {data_type.replace('_', ' ').title()} Export\n"
        csv_content += f"# Generated on {datetime.utcnow().isoformat()}\n"
        csv_content += "timestamp,event,details\n"
        csv_content += f"{datetime.utcnow().isoformat()},export_requested,{data_type}\n"
        
        from flask import Response
        return Response(
            csv_content,
            mimetype='text/csv',
            headers={'Content-Disposition': f'attachment; filename={data_type}_{int(time.time())}.csv'}
        )
    
    return jsonify({'error': 'Unsupported format'}), 400

# Error handlers
@api_bp.errorhandler(404)
def not_found(error):
    return jsonify({'error': 'Endpoint not found'}), 404

@api_bp.errorhandler(500)
def internal_error(error):
    return jsonify({'error': 'Internal server error'}), 500
