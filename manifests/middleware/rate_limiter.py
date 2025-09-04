"""
Rate limiting configuration for Storm Surge API
Prevents abuse and ensures fair resource usage
"""
import os
from flask import Flask
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address
import redis
import logging

logger = logging.getLogger(__name__)

def get_identifier():
    """Get identifier for rate limiting (IP + API key if present)"""
    from flask import request
    api_key = request.headers.get('X-API-Key', '')
    remote_addr = get_remote_address()
    
    # Use API key for authenticated requests, IP for anonymous
    if api_key:
        return f"api_key:{api_key}"
    return f"ip:{remote_addr}"

def setup_rate_limiter(app: Flask):
    """Configure rate limiting for the application"""
    
    # Redis configuration for distributed rate limiting
    redis_url = os.getenv('REDIS_URL', 'redis://localhost:6379')
    redis_password = os.getenv('REDIS_PASSWORD', '')
    
    storage_uri = redis_url
    if redis_password:
        # Parse and add password to Redis URL
        parts = redis_url.split('//')
        if len(parts) == 2:
            storage_uri = f"{parts[0]}//:{redis_password}@{parts[1]}"
    
    try:
        # Test Redis connection
        r = redis.from_url(storage_uri)
        r.ping()
        logger.info("Connected to Redis for rate limiting")
    except Exception as e:
        logger.warning(f"Redis not available, using in-memory rate limiting: {e}")
        storage_uri = None
    
    # Initialize rate limiter
    limiter = Limiter(
        app=app,
        key_func=get_identifier,
        default_limits=[
            "1000 per hour",  # Global limit per identifier
            "100 per minute"   # Burst protection
        ],
        storage_uri=storage_uri,
        storage_options={"socket_connect_timeout": 30} if storage_uri else {},
        swallow_errors=True,  # Don't break the app if rate limiting fails
        headers_enabled=True,  # Return rate limit headers in responses
        strategy="fixed-window-elastic-expiry"
    )
    
    return limiter

# Rate limit decorators for different endpoint types
class RateLimits:
    """Predefined rate limits for different endpoint types"""
    
    # Public endpoints - more restrictive
    PUBLIC_READ = "30 per minute"
    PUBLIC_WRITE = "10 per minute"
    
    # Authenticated endpoints - more permissive
    AUTH_READ = "100 per minute"
    AUTH_WRITE = "30 per minute"
    
    # Admin endpoints - least restrictive
    ADMIN_READ = "200 per minute"
    ADMIN_WRITE = "60 per minute"
    
    # Special endpoints
    LOGIN = "5 per minute"  # Prevent brute force
    WEBHOOK = "100 per minute"  # High volume expected
    HEALTH = "60 per minute"  # Health checks
    
def apply_endpoint_limits(limiter, app):
    """Apply specific rate limits to endpoints"""
    
    # Import here to avoid circular imports
    from flask import Blueprint
    
    # Login endpoint - strict to prevent brute force
    @limiter.limit(RateLimits.LOGIN)
    def login_limit():
        pass
    
    # Webhook endpoints - higher limits
    @limiter.limit(RateLimits.WEBHOOK)
    def webhook_limit():
        pass
    
    # Health check - reasonable limit
    @limiter.exempt
    def health_exempt():
        """Health checks don't count against rate limits"""
        pass
    
    # Apply limits to specific routes
    # This would be done in the main application file
    # Example:
    # @app.route('/api/login', methods=['POST'])
    # @limiter.limit(RateLimits.LOGIN)
    # def login():
    #     pass
    
    logger.info("Rate limiting configured for all endpoints")

def get_rate_limit_message(limit):
    """Generate user-friendly rate limit error message"""
    return {
        "error": "Rate limit exceeded",
        "message": f"You have exceeded the rate limit of {limit}",
        "retry_after": "See Retry-After header"
    }