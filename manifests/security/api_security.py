#!/usr/bin/env python3
"""
API Security Middleware
Centralized authentication, rate limiting, and security headers
"""

import os
import time
import hashlib
import hmac
from typing import Optional, Dict, Any
from functools import wraps
from collections import defaultdict, deque

from fastapi import HTTPException, Request, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from fastapi.responses import JSONResponse
import structlog

logger = structlog.get_logger()

# Configuration
API_KEYS = {
    'admin': os.getenv('ADMIN_API_KEY', 'REPLACE_WITH_ADMIN_KEY'),
    'service': os.getenv('SERVICE_API_KEY', 'REPLACE_WITH_SERVICE_KEY'),
    'readonly': os.getenv('READONLY_API_KEY', 'REPLACE_WITH_READONLY_KEY')
}

WEBHOOK_SECRET = os.getenv('WEBHOOK_SECRET', 'REPLACE_WITH_WEBHOOK_SECRET')

# Rate limiting storage (in production, use Redis)
rate_limit_storage = defaultdict(lambda: deque())

class APIKeyAuth:
    """API Key Authentication"""
    
    def __init__(self):
        self.security = HTTPBearer(auto_error=False)
    
    async def __call__(self, request: Request) -> Optional[str]:
        # Check for API key in headers
        api_key = request.headers.get('X-API-Key')
        
        if not api_key:
            # Check Authorization header
            credentials: HTTPAuthorizationCredentials = await self.security(request)
            if credentials:
                api_key = credentials.credentials
        
        if not api_key:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="API key required",
                headers={"WWW-Authenticate": "Bearer"},
            )
        
        # Validate API key
        user_type = self._validate_api_key(api_key)
        if not user_type:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid API key",
                headers={"WWW-Authenticate": "Bearer"},
            )
        
        logger.info("API request authenticated", user_type=user_type, ip=request.client.host)
        return user_type
    
    def _validate_api_key(self, api_key: str) -> Optional[str]:
        """Validate API key and return user type"""
        for user_type, valid_key in API_KEYS.items():
            if valid_key != 'REPLACE_WITH_' + user_type.upper() + '_KEY':
                if hmac.compare_digest(api_key, valid_key):
                    return user_type
        return None

class RateLimiter:
    """Rate limiting middleware"""
    
    def __init__(self, max_requests: int = 100, window_seconds: int = 3600):
        self.max_requests = max_requests
        self.window_seconds = window_seconds
    
    async def __call__(self, request: Request):
        client_ip = request.client.host
        current_time = time.time()
        
        # Clean old requests
        requests = rate_limit_storage[client_ip]
        while requests and requests[0] < current_time - self.window_seconds:
            requests.popleft()
        
        # Check rate limit
        if len(requests) >= self.max_requests:
            logger.warning("Rate limit exceeded", ip=client_ip, requests=len(requests))
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail=f"Rate limit exceeded. Maximum {self.max_requests} requests per hour.",
                headers={
                    "Retry-After": str(int(self.window_seconds - (current_time - requests[0]))),
                    "X-RateLimit-Limit": str(self.max_requests),
                    "X-RateLimit-Remaining": str(max(0, self.max_requests - len(requests))),
                    "X-RateLimit-Reset": str(int(requests[0] + self.window_seconds))
                }
            )
        
        # Add current request
        requests.append(current_time)

def verify_webhook_signature(payload: bytes, signature: str) -> bool:
    """Verify webhook signature"""
    if not WEBHOOK_SECRET or WEBHOOK_SECRET.startswith('REPLACE_WITH_'):
        logger.warning("Webhook secret not configured - signature verification disabled")
        return True  # Allow in dev mode
    
    try:
        expected_sig = hmac.new(
            WEBHOOK_SECRET.encode(),
            payload,
            hashlib.sha256
        ).hexdigest()
        
        # Handle different signature formats
        if signature.startswith('sha256='):
            signature = signature[7:]
        
        return hmac.compare_digest(expected_sig, signature)
    except Exception as e:
        logger.error("Webhook signature verification failed", error=str(e))
        return False

def add_security_headers(response):
    """Add security headers to response"""
    response.headers.update({
        'X-Content-Type-Options': 'nosniff',
        'X-Frame-Options': 'DENY',
        'X-XSS-Protection': '1; mode=block',
        'Strict-Transport-Security': 'max-age=31536000; includeSubDomains',
        'Content-Security-Policy': "default-src 'self'",
        'Referrer-Policy': 'strict-origin-when-cross-origin',
        'Permissions-Policy': 'geolocation=(), microphone=(), camera=()'
    })
    return response

# Permission decorators
def require_auth(allowed_roles: list = None):
    """Decorator to require authentication with optional role check"""
    def decorator(func):
        @wraps(func)
        async def wrapper(*args, **kwargs):
            # Extract request from args/kwargs
            request = None
            for arg in args:
                if isinstance(arg, Request):
                    request = arg
                    break
            
            if not request:
                raise HTTPException(status_code=500, detail="Request object not found")
            
            # Authenticate
            auth = APIKeyAuth()
            user_type = await auth(request)
            
            # Check permissions
            if allowed_roles and user_type not in allowed_roles:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail=f"Access denied. Required roles: {allowed_roles}"
                )
            
            # Add user info to request
            request.state.user_type = user_type
            return await func(*args, **kwargs)
        return wrapper
    return decorator

def require_rate_limit(max_requests: int = 100, window_seconds: int = 3600):
    """Decorator to add rate limiting"""
    def decorator(func):
        @wraps(func)
        async def wrapper(*args, **kwargs):
            # Extract request from args/kwargs
            request = None
            for arg in args:
                if isinstance(arg, Request):
                    request = arg
                    break
            
            if request:
                limiter = RateLimiter(max_requests, window_seconds)
                await limiter(request)
            
            return await func(*args, **kwargs)
        return wrapper
    return decorator

# Public endpoints that don't require auth
PUBLIC_ENDPOINTS = {
    '/health',
    '/metrics',
    '/docs',
    '/openapi.json',
    '/redoc'
}

def is_public_endpoint(path: str) -> bool:
    """Check if endpoint is public"""
    return path in PUBLIC_ENDPOINTS or path.startswith('/static/')

# API Security Configuration
class APISecurityConfig:
    """Centralized API security configuration"""
    
    # Rate limits by endpoint type
    RATE_LIMITS = {
        'public': {'max_requests': 1000, 'window_seconds': 3600},
        'authenticated': {'max_requests': 5000, 'window_seconds': 3600},
        'admin': {'max_requests': 10000, 'window_seconds': 3600}
    }
    
    # Permission matrix
    PERMISSIONS = {
        'admin': ['read', 'write', 'delete', 'admin'],
        'service': ['read', 'write'],
        'readonly': ['read']
    }
    
    @classmethod
    def get_rate_limit_for_user(cls, user_type: str) -> Dict[str, int]:
        """Get rate limit configuration for user type"""
        if user_type == 'admin':
            return cls.RATE_LIMITS['admin']
        elif user_type in ['service', 'readonly']:
            return cls.RATE_LIMITS['authenticated']
        else:
            return cls.RATE_LIMITS['public']
    
    @classmethod
    def check_permission(cls, user_type: str, required_permission: str) -> bool:
        """Check if user has required permission"""
        user_permissions = cls.PERMISSIONS.get(user_type, [])
        return required_permission in user_permissions