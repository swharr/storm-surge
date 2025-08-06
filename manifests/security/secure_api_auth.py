#!/usr/bin/env python3
"""
Production-Ready API Authentication & Authorization System
Comprehensive security middleware for Storm Surge APIs
"""

import os
import time
import json
import hmac
import hashlib
import logging
from datetime import datetime, timedelta
from typing import Optional, Dict, List, Any, Callable
from functools import wraps
from collections import defaultdict, deque

import jwt
import redis
import structlog
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from fastapi import HTTPException, Request, status, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel, Field

# Configure structured logging
structlog.configure(
    processors=[
        structlog.stdlib.filter_by_level,
        structlog.stdlib.add_logger_name,
        structlog.stdlib.add_log_level,
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.JSONRenderer()
    ],
    wrapper_class=structlog.stdlib.BoundLogger,
    cache_logger_on_first_use=True,
)

logger = structlog.get_logger()

# Security Configuration
class SecurityConfig:
    """Centralized security configuration"""
    
    # JWT Configuration
    JWT_ALGORITHM = "RS256"  # Use RSA for better security
    JWT_ACCESS_TOKEN_EXPIRE_MINUTES = 15  # Short-lived tokens
    JWT_REFRESH_TOKEN_EXPIRE_DAYS = 7
    
    # API Key Configuration
    API_KEYS = {
        'admin': os.getenv('API_ADMIN_KEY', ''),
        'service': os.getenv('API_SERVICE_KEY', ''),
        'readonly': os.getenv('API_READONLY_KEY', '')
    }
    
    # Rate Limiting Configuration
    RATE_LIMITS = {
        'public': {'requests': 100, 'window': 3600},      # 100/hour
        'authenticated': {'requests': 1000, 'window': 3600}, # 1000/hour
        'admin': {'requests': 5000, 'window': 3600}       # 5000/hour
    }
    
    # Redis Configuration
    REDIS_HOST = os.getenv('REDIS_HOST', 'redis')
    REDIS_PORT = int(os.getenv('REDIS_PORT', 6379))
    REDIS_PASSWORD = os.getenv('REDIS_PASSWORD', '')
    
    # Webhook Configuration
    WEBHOOK_SECRET = os.getenv('WEBHOOK_SECRET', '')
    
    @classmethod
    def validate_config(cls):
        """Validate security configuration"""
        missing = []
        
        if not cls.API_KEYS['admin']:
            missing.append('API_ADMIN_KEY')
        if not cls.API_KEYS['service']:
            missing.append('API_SERVICE_KEY')
        if not cls.API_KEYS['readonly']:
            missing.append('API_READONLY_KEY')
        if not cls.REDIS_PASSWORD:
            missing.append('REDIS_PASSWORD')
        if not cls.WEBHOOK_SECRET:
            missing.append('WEBHOOK_SECRET')
            
        if missing:
            raise ValueError(f"Missing required environment variables: {missing}")

# Initialize Redis with authentication
def get_redis_client():
    """Get authenticated Redis client"""
    try:
        client = redis.Redis(
            host=SecurityConfig.REDIS_HOST,
            port=SecurityConfig.REDIS_PORT,
            password=SecurityConfig.REDIS_PASSWORD,
            decode_responses=True,
            socket_connect_timeout=5,
            socket_timeout=5,
            retry_on_timeout=True,
            health_check_interval=30
        )
        # Test connection
        client.ping()
        logger.info("Redis connection established")
        return client
    except Exception as e:
        logger.error("Redis connection failed", error=str(e))
        raise

redis_client = get_redis_client()

# JWT Token Management
class JWTManager:
    """Secure JWT token management with RSA keys"""
    
    def __init__(self):
        self.private_key = self._load_private_key()
        self.public_key = self._load_public_key()
    
    def _load_private_key(self):
        """Load RSA private key"""
        key_data = os.getenv('JWT_PRIVATE_KEY')
        if key_data:
            return serialization.load_pem_private_key(
                key_data.encode(), password=None
            )
        else:
            # Generate key if not provided (dev only)
            logger.warning("No JWT private key provided, generating temporary key")
            return rsa.generate_private_key(public_exponent=65537, key_size=2048)
    
    def _load_public_key(self):
        """Load RSA public key"""
        key_data = os.getenv('JWT_PUBLIC_KEY')
        if key_data:
            return serialization.load_pem_public_key(key_data.encode())
        else:
            return self.private_key.public_key()
    
    def create_access_token(self, data: dict, expires_delta: Optional[timedelta] = None):
        """Create JWT access token"""
        to_encode = data.copy()
        
        if expires_delta:
            expire = datetime.utcnow() + expires_delta
        else:
            expire = datetime.utcnow() + timedelta(
                minutes=SecurityConfig.JWT_ACCESS_TOKEN_EXPIRE_MINUTES
            )
        
        to_encode.update({
            "exp": expire,
            "iat": datetime.utcnow(),
            "type": "access"
        })
        
        token = jwt.encode(to_encode, self.private_key, algorithm=SecurityConfig.JWT_ALGORITHM)
        
        # Store token in Redis for revocation tracking
        redis_client.setex(
            f"token:{token[:16]}",  # Use token prefix as key
            int(expires_delta.total_seconds()) if expires_delta else SecurityConfig.JWT_ACCESS_TOKEN_EXPIRE_MINUTES * 60,
            json.dumps({"user": data.get("sub"), "created": time.time()})
        )
        
        return token
    
    def verify_token(self, token: str) -> dict:
        """Verify and decode JWT token"""
        try:
            # Check if token is revoked
            token_key = f"token:{token[:16]}"
            if not redis_client.exists(token_key):
                raise jwt.InvalidTokenError("Token revoked or expired")
            
            # Verify token signature and expiration
            payload = jwt.decode(
                token, self.public_key, 
                algorithms=[SecurityConfig.JWT_ALGORITHM]
            )
            
            logger.info("Token verified successfully", user=payload.get("sub"))
            return payload
            
        except jwt.ExpiredSignatureError:
            logger.warning("Token expired", token_prefix=token[:16])
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Token expired"
            )
        except jwt.InvalidTokenError as e:
            logger.warning("Invalid token", error=str(e), token_prefix=token[:16])
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid token"
            )
    
    def revoke_token(self, token: str):
        """Revoke a JWT token"""
        token_key = f"token:{token[:16]}"
        redis_client.delete(token_key)
        logger.info("Token revoked", token_prefix=token[:16])

jwt_manager = JWTManager()

# Rate Limiting
class RateLimiter:
    """Advanced rate limiting with Redis backend"""
    
    def __init__(self, max_requests: int, window_seconds: int, identifier: str):
        self.max_requests = max_requests
        self.window_seconds = window_seconds
        self.identifier = identifier
    
    async def is_allowed(self, request: Request) -> bool:
        """Check if request is within rate limits"""
        # Create unique key for this client
        client_ip = request.client.host
        user_agent = request.headers.get("user-agent", "unknown")[:50]
        key = f"rate_limit:{self.identifier}:{client_ip}:{hashlib.md5(user_agent.encode()).hexdigest()[:8]}"
        
        current_time = int(time.time())
        window_start = current_time - self.window_seconds
        
        # Use Redis sorted set for sliding window
        pipe = redis_client.pipeline()
        
        # Remove old entries
        pipe.zremrangebyscore(key, 0, window_start)
        
        # Count current requests
        pipe.zcard(key)
        
        # Add current request
        pipe.zadd(key, {f"{current_time}:{os.urandom(8).hex()}": current_time})
        
        # Set expiration
        pipe.expire(key, self.window_seconds)
        
        results = pipe.execute()
        current_requests = results[1]
        
        if current_requests >= self.max_requests:
            logger.warning("Rate limit exceeded", 
                         identifier=self.identifier,
                         ip=client_ip,
                         requests=current_requests,
                         limit=self.max_requests)
            return False
        
        return True

# Authentication Classes
class APIKeyAuth:
    """API Key authentication"""
    
    def __init__(self):
        self.security = HTTPBearer(auto_error=False)
    
    async def __call__(self, request: Request) -> Optional[Dict[str, Any]]:
        # Check X-API-Key header first
        api_key = request.headers.get('X-API-Key')
        
        if not api_key:
            # Check Authorization Bearer token
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
            logger.warning("Invalid API key attempt", 
                         ip=request.client.host,
                         key_prefix=api_key[:8] if api_key else "none")
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid API key"
            )
        
        logger.info("API key authentication successful", 
                   user_type=user_type, 
                   ip=request.client.host,
                   endpoint=str(request.url.path))
        
        return {
            "user_type": user_type,
            "auth_method": "api_key",
            "permissions": self._get_permissions(user_type)
        }
    
    def _validate_api_key(self, api_key: str) -> Optional[str]:
        """Validate API key using constant-time comparison"""
        for user_type, valid_key in SecurityConfig.API_KEYS.items():
            if valid_key and hmac.compare_digest(api_key, valid_key):
                return user_type
        return None
    
    def _get_permissions(self, user_type: str) -> List[str]:
        """Get permissions for user type"""
        permissions_map = {
            'admin': ['read', 'write', 'delete', 'admin'],
            'service': ['read', 'write'],
            'readonly': ['read']
        }
        return permissions_map.get(user_type, [])

class JWTAuth:
    """JWT token authentication"""
    
    def __init__(self):
        self.security = HTTPBearer()
    
    async def __call__(self, request: Request) -> Dict[str, Any]:
        credentials: HTTPAuthorizationCredentials = await self.security(request)
        
        if not credentials:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Bearer token required"
            )
        
        payload = jwt_manager.verify_token(credentials.credentials)
        
        return {
            "user_id": payload.get("sub"),
            "user_type": payload.get("user_type", "user"),
            "auth_method": "jwt",
            "permissions": payload.get("permissions", ["read"])
        }

# Permission Decorators
def require_auth(auth_methods: List[str] = None, required_permissions: List[str] = None):
    """Require authentication with optional permission check"""
    def decorator(func: Callable) -> Callable:
        @wraps(func)
        async def wrapper(*args, **kwargs):
            request = None
            
            # Find request object in arguments
            for arg in args:
                if isinstance(arg, Request):
                    request = arg
                    break
            
            if not request:
                raise HTTPException(status_code=500, detail="Request object not found")
            
            # Try different authentication methods
            auth_info = None
            auth_methods_to_try = auth_methods or ['api_key', 'jwt']
            
            for method in auth_methods_to_try:
                try:
                    if method == 'api_key':
                        auth_info = await APIKeyAuth()(request)
                        break
                    elif method == 'jwt':
                        auth_info = await JWTAuth()(request)
                        break
                except HTTPException:
                    continue
            
            if not auth_info:
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="Authentication required"
                )
            
            # Check permissions
            if required_permissions:
                user_permissions = auth_info.get("permissions", [])
                if not any(perm in user_permissions for perm in required_permissions):
                    logger.warning("Insufficient permissions", 
                                 user=auth_info.get("user_type"),
                                 required=required_permissions,
                                 has=user_permissions)
                    raise HTTPException(
                        status_code=status.HTTP_403_FORBIDDEN,
                        detail=f"Insufficient permissions. Required: {required_permissions}"
                    )
            
            # Add auth info to request state
            request.state.auth = auth_info
            
            return await func(*args, **kwargs)
        return wrapper
    return decorator

def require_rate_limit(identifier: str, max_requests: int = 100, window_seconds: int = 3600):
    """Add rate limiting to endpoint"""
    def decorator(func: Callable) -> Callable:
        @wraps(func)
        async def wrapper(*args, **kwargs):
            request = None
            
            for arg in args:
                if isinstance(arg, Request):
                    request = arg
                    break
            
            if request:
                limiter = RateLimiter(max_requests, window_seconds, identifier)
                if not await limiter.is_allowed(request):
                    raise HTTPException(
                        status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                        detail=f"Rate limit exceeded. Max {max_requests} requests per {window_seconds} seconds",
                        headers={
                            "Retry-After": str(window_seconds),
                            "X-RateLimit-Limit": str(max_requests),
                            "X-RateLimit-Window": str(window_seconds)
                        }
                    )
            
            return await func(*args, **kwargs)
        return wrapper
    return decorator

# Webhook Security
def verify_webhook_signature(payload: bytes, signature: str, secret: str = None) -> bool:
    """Verify webhook signature"""
    webhook_secret = secret or SecurityConfig.WEBHOOK_SECRET
    
    if not webhook_secret:
        logger.error("Webhook secret not configured")
        return False
    
    try:
        expected_sig = hmac.new(
            webhook_secret.encode(),
            payload,
            hashlib.sha256
        ).hexdigest()
        
        # Handle different signature formats
        if signature.startswith('sha256='):
            signature = signature[7:]
        
        is_valid = hmac.compare_digest(expected_sig, signature)
        
        if not is_valid:
            logger.warning("Invalid webhook signature",
                         expected_prefix=expected_sig[:8],
                         received_prefix=signature[:8])
        
        return is_valid
        
    except Exception as e:
        logger.error("Webhook signature verification failed", error=str(e))
        return False

# Security Headers Middleware
def add_security_headers(response):
    """Add comprehensive security headers"""
    security_headers = {
        'X-Content-Type-Options': 'nosniff',
        'X-Frame-Options': 'DENY',
        'X-XSS-Protection': '1; mode=block',
        'Strict-Transport-Security': 'max-age=31536000; includeSubDomains; preload',
        'Content-Security-Policy': "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'",
        'Referrer-Policy': 'strict-origin-when-cross-origin',
        'Permissions-Policy': 'geolocation=(), microphone=(), camera=(), payment=(), usb=(), magnetometer=(), gyroscope=()',
        'X-Permitted-Cross-Domain-Policies': 'none',
        'X-DNS-Prefetch-Control': 'off'
    }
    
    for header, value in security_headers.items():
        response.headers[header] = value
    
    return response

# Initialize security configuration
try:
    SecurityConfig.validate_config()
    logger.info("Security configuration validated successfully")
except Exception as e:
    logger.error("Security configuration validation failed", error=str(e))
    # In production, this should fail fast
    # raise e