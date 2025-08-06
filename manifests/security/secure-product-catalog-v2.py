#!/usr/bin/env python3
"""
Production-Ready Product Catalog API
Implements security best practices for a real-world Kubernetes application
"""

import os
import sys
import time
import asyncio
import secrets
from typing import List, Optional, Dict, Any
from contextlib import asynccontextmanager
from datetime import datetime, timedelta

import asyncpg
import redis.asyncio as redis
from fastapi import FastAPI, HTTPException, Depends, Query, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.trustedhost import TrustedHostMiddleware
from fastapi.middleware.gzip import GZipMiddleware
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel, Field, validator
import jwt
from passlib.context import CryptContext
import structlog
from prometheus_client import Counter, Histogram, Gauge, generate_latest
from prometheus_client import CONTENT_TYPE_LATEST
from fastapi.responses import Response, PlainTextResponse
import hashlib
import hmac

# Configure structured logging
structlog.configure(
    processors=[
        structlog.stdlib.filter_by_level,
        structlog.stdlib.add_logger_name,
        structlog.stdlib.add_log_level,
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.StackInfoRenderer(),
        structlog.processors.format_exc_info,
        structlog.processors.JSONRenderer()
    ],
    context_class=dict,
    logger_factory=structlog.stdlib.LoggerFactory(),
    wrapper_class=structlog.stdlib.BoundLogger,
    cache_logger_on_first_use=True,
)

logger = structlog.get_logger()

# Security configuration
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
security = HTTPBearer()

# Environment configuration with secure defaults
CONFIG = {
    "jwt_secret": os.getenv("JWT_SECRET", secrets.token_urlsafe(32)),
    "jwt_algorithm": "HS256",
    "jwt_expiration_minutes": int(os.getenv("JWT_EXPIRATION_MINUTES", "30")),
    "api_rate_limit": int(os.getenv("API_RATE_LIMIT", "100")),
    "api_rate_window": int(os.getenv("API_RATE_WINDOW", "3600")),
    "database_pool_size": int(os.getenv("DATABASE_POOL_SIZE", "10")),
    "redis_ttl": int(os.getenv("REDIS_TTL", "300")),
    "allowed_origins": os.getenv("ALLOWED_ORIGINS", "https://stormsurge.example.com").split(","),
    "trusted_hosts": os.getenv("TRUSTED_HOSTS", "api.stormsurge.example.com,localhost").split(","),
}

# Prometheus metrics
request_count = Counter('http_requests_total', 'Total HTTP requests', ['method', 'endpoint', 'status'])
request_duration = Histogram('http_request_duration_seconds', 'HTTP request duration', ['method', 'endpoint'])
active_requests = Gauge('http_requests_active', 'Active HTTP requests')
db_connections = Gauge('database_connections_active', 'Active database connections')
cache_hits = Counter('cache_hits_total', 'Cache hit count', ['operation'])
cache_misses = Counter('cache_misses_total', 'Cache miss count', ['operation'])
authentication_attempts = Counter('authentication_attempts_total', 'Authentication attempts', ['result'])
rate_limit_exceeded = Counter('rate_limit_exceeded_total', 'Rate limit exceeded count', ['endpoint'])

# Global connections
db_pool: Optional[asyncpg.Pool] = None
redis_client: Optional[redis.Redis] = None

# Rate limiting storage
rate_limit_storage: Dict[str, List[float]] = {}

# Data models with validation
class Product(BaseModel):
    id: Optional[int] = None
    name: str = Field(..., min_length=1, max_length=255)
    description: str = Field(..., max_length=1000)
    price: float = Field(..., gt=0, le=999999.99)
    category: str = Field(..., min_length=1, max_length=100)
    sku: str = Field(..., regex=r'^[A-Z0-9\-]+$', max_length=50)
    stock_quantity: int = Field(..., ge=0, le=999999)
    manufacturer: str = Field(..., min_length=1, max_length=100)
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
    
    @validator('name', 'description', 'category', 'manufacturer')
    def no_script_tags(cls, v):
        if '<script' in v.lower() or 'javascript:' in v.lower():
            raise ValueError('Invalid characters detected')
        return v

class ProductCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=255)
    description: str = Field(..., max_length=1000)
    price: float = Field(..., gt=0, le=999999.99)
    category: str = Field(..., min_length=1, max_length=100)
    sku: str = Field(..., regex=r'^[A-Z0-9\-]+$', max_length=50)
    stock_quantity: int = Field(..., ge=0, le=999999)
    manufacturer: str = Field(..., min_length=1, max_length=100)

class ProductUpdate(BaseModel):
    name: Optional[str] = Field(None, min_length=1, max_length=255)
    description: Optional[str] = Field(None, max_length=1000)
    price: Optional[float] = Field(None, gt=0, le=999999.99)
    stock_quantity: Optional[int] = Field(None, ge=0, le=999999)

class UserLogin(BaseModel):
    username: str = Field(..., min_length=3, max_length=50)
    password: str = Field(..., min_length=8, max_length=100)

class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"
    expires_in: int

# Security utilities
def create_access_token(data: dict, expires_delta: Optional[timedelta] = None):
    """Create JWT token with expiration"""
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=CONFIG["jwt_expiration_minutes"])
    
    to_encode.update({"exp": expire, "iat": datetime.utcnow()})
    encoded_jwt = jwt.encode(to_encode, CONFIG["jwt_secret"], algorithm=CONFIG["jwt_algorithm"])
    return encoded_jwt

def verify_token(token: str) -> dict:
    """Verify and decode JWT token"""
    try:
        payload = jwt.decode(token, CONFIG["jwt_secret"], algorithms=[CONFIG["jwt_algorithm"]])
        return payload
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token expired")
    except jwt.JWTError:
        raise HTTPException(status_code=401, detail="Invalid token")

async def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security)):
    """Dependency to get current authenticated user"""
    token = credentials.credentials
    payload = verify_token(token)
    return payload

def check_rate_limit(identifier: str, limit: int, window: int) -> bool:
    """Simple in-memory rate limiting"""
    current_time = time.time()
    
    # Clean old entries
    if identifier in rate_limit_storage:
        rate_limit_storage[identifier] = [
            t for t in rate_limit_storage[identifier] 
            if t > current_time - window
        ]
    else:
        rate_limit_storage[identifier] = []
    
    # Check limit
    if len(rate_limit_storage[identifier]) >= limit:
        return False
    
    # Add current request
    rate_limit_storage[identifier].append(current_time)
    return True

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan management"""
    # Startup
    logger.info("Starting Product Catalog API", version="1.0.0")
    
    global db_pool, redis_client
    
    # Initialize database
    try:
        db_pool = await asyncpg.create_pool(
            host=os.getenv("DATABASE_HOST", "postgresql"),
            port=int(os.getenv("DATABASE_PORT", "5432")),
            user=os.getenv("DATABASE_USER", "app_user"),
            password=os.getenv("DATABASE_PASSWORD"),
            database=os.getenv("DATABASE_NAME", "stormsurge"),
            min_size=2,
            max_size=CONFIG["database_pool_size"],
            command_timeout=30,
            ssl="prefer"
        )
        logger.info("Database connection pool created")
        
        # Create tables if needed
        await create_tables()
        
    except Exception as e:
        logger.error("Failed to connect to database", error=str(e))
        raise
    
    # Initialize Redis
    try:
        redis_client = redis.from_url(
            f"redis://:{os.getenv('REDIS_PASSWORD')}@{os.getenv('REDIS_HOST', 'redis')}:{os.getenv('REDIS_PORT', '6379')}/0",
            decode_responses=True
        )
        await redis_client.ping()
        logger.info("Redis connection established")
    except Exception as e:
        logger.error("Failed to connect to Redis", error=str(e))
        # Continue without cache
        redis_client = None
    
    yield
    
    # Shutdown
    logger.info("Shutting down Product Catalog API")
    if db_pool:
        await db_pool.close()
    if redis_client:
        await redis_client.close()

# Create FastAPI app
app = FastAPI(
    title="Storm Surge Product Catalog API",
    description="Production-ready product catalog microservice",
    version="1.2.0-internal",
    lifespan=lifespan,
    docs_url="/api/docs",
    redoc_url="/api/redoc",
    openapi_url="/api/openapi.json"
)

# Add security middleware
app.add_middleware(
    TrustedHostMiddleware,
    allowed_hosts=CONFIG["trusted_hosts"]
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=CONFIG["allowed_origins"],
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE"],
    allow_headers=["*"],
)

app.add_middleware(GZipMiddleware, minimum_size=1000)

# Request tracking middleware
@app.middleware("http")
async def track_requests(request: Request, call_next):
    """Track request metrics and add security headers"""
    start_time = time.time()
    active_requests.inc()
    
    # Add request ID for tracing
    request_id = request.headers.get("X-Request-ID", secrets.token_urlsafe(16))
    
    try:
        response = await call_next(request)
        
        # Add security headers
        response.headers["X-Request-ID"] = request_id
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["X-Frame-Options"] = "DENY"
        response.headers["X-XSS-Protection"] = "1; mode=block"
        response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
        response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
        
        # Track metrics
        duration = time.time() - start_time
        request_count.labels(
            method=request.method,
            endpoint=request.url.path,
            status=response.status_code
        ).inc()
        request_duration.labels(
            method=request.method,
            endpoint=request.url.path
        ).observe(duration)
        
        return response
        
    finally:
        active_requests.dec()

# Database initialization
async def create_tables():
    """Create database tables if they don't exist"""
    create_sql = """
    CREATE TABLE IF NOT EXISTS products (
        id SERIAL PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        description TEXT,
        price DECIMAL(10,2) NOT NULL CHECK (price > 0),
        category VARCHAR(100) NOT NULL,
        sku VARCHAR(50) UNIQUE NOT NULL,
        stock_quantity INTEGER DEFAULT 0 CHECK (stock_quantity >= 0),
        manufacturer VARCHAR(100),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
    
    CREATE INDEX IF NOT EXISTS idx_products_category ON products(category);
    CREATE INDEX IF NOT EXISTS idx_products_sku ON products(sku);
    
    CREATE TABLE IF NOT EXISTS users (
        id SERIAL PRIMARY KEY,
        username VARCHAR(50) UNIQUE NOT NULL,
        password_hash VARCHAR(255) NOT NULL,
        is_active BOOLEAN DEFAULT true,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
    """
    
    async with db_pool.acquire() as conn:
        await conn.execute(create_sql)
        
        # Create default admin user if not exists
        admin_exists = await conn.fetchval(
            "SELECT EXISTS(SELECT 1 FROM users WHERE username = $1)",
            "admin"
        )
        
        if not admin_exists:
            admin_password = os.getenv("ADMIN_PASSWORD", secrets.token_urlsafe(16))
            password_hash = pwd_context.hash(admin_password)
            await conn.execute(
                "INSERT INTO users (username, password_hash) VALUES ($1, $2)",
                "admin", password_hash
            )
            logger.info("Created admin user", password=admin_password)

# API Endpoints
@app.get("/health", tags=["Health"])
async def health_check():
    """Health check endpoint"""
    try:
        # Check database
        async with db_pool.acquire() as conn:
            await conn.fetchval("SELECT 1")
        
        # Check Redis if available
        redis_status = "healthy"
        if redis_client:
            try:
                await redis_client.ping()
            except:
                redis_status = "degraded"
        
        return {
            "status": "healthy",
            "timestamp": datetime.utcnow().isoformat(),
            "database": "healthy",
            "cache": redis_status
        }
    except Exception as e:
        logger.error("Health check failed", error=str(e))
        raise HTTPException(status_code=503, detail="Service unhealthy")

@app.get("/ready", tags=["Health"])
async def readiness_check():
    """Readiness check endpoint"""
    return {"ready": True}

@app.get("/metrics", tags=["Monitoring"])
async def get_metrics():
    """Prometheus metrics endpoint"""
    # Update connection metrics
    if db_pool:
        db_connections.set(db_pool.get_size())
    
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)

@app.post("/api/auth/login", response_model=Token, tags=["Authentication"])
async def login(user_login: UserLogin):
    """Authenticate and receive JWT token"""
    # Rate limiting
    if not check_rate_limit(f"login:{user_login.username}", 5, 300):  # 5 attempts per 5 minutes
        authentication_attempts.labels(result="rate_limited").inc()
        rate_limit_exceeded.labels(endpoint="login").inc()
        raise HTTPException(status_code=429, detail="Too many login attempts")
    
    # Verify credentials
    async with db_pool.acquire() as conn:
        user = await conn.fetchrow(
            "SELECT id, username, password_hash FROM users WHERE username = $1 AND is_active = true",
            user_login.username
        )
    
    if not user or not pwd_context.verify(user_login.password, user["password_hash"]):
        authentication_attempts.labels(result="failed").inc()
        # Add delay to prevent brute force
        await asyncio.sleep(1)
        raise HTTPException(status_code=401, detail="Invalid credentials")
    
    # Create token
    access_token = create_access_token(
        data={"sub": user["username"], "user_id": user["id"]}
    )
    
    authentication_attempts.labels(result="success").inc()
    
    return {
        "access_token": access_token,
        "token_type": "bearer",
        "expires_in": CONFIG["jwt_expiration_minutes"] * 60
    }

@app.get("/api/products", response_model=List[Product], tags=["Products"])
async def get_products(
    category: Optional[str] = Query(None, max_length=100),
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
    current_user: dict = Depends(get_current_user)
):
    """Get products with optional filtering"""
    # Rate limiting per user
    if not check_rate_limit(
        f"products:{current_user['sub']}", 
        CONFIG["api_rate_limit"], 
        CONFIG["api_rate_window"]
    ):
        rate_limit_exceeded.labels(endpoint="products").inc()
        raise HTTPException(status_code=429, detail="Rate limit exceeded")
    
    # Try cache first
    cache_key = f"products:{category}:{limit}:{offset}"
    if redis_client:
        try:
            cached = await redis_client.get(cache_key)
            if cached:
                cache_hits.labels(operation="get_products").inc()
                import json
                return json.loads(cached)
        except Exception as e:
            logger.warning("Cache retrieval failed", error=str(e))
    
    cache_misses.labels(operation="get_products").inc()
    
    # Build query
    query = """
        SELECT id, name, description, price, category, sku, 
               stock_quantity, manufacturer, created_at, updated_at
        FROM products
    """
    params = []
    
    if category:
        query += " WHERE category = $1"
        params.append(category)
    
    query += f" ORDER BY created_at DESC LIMIT ${len(params) + 1} OFFSET ${len(params) + 2}"
    params.extend([limit, offset])
    
    # Execute query
    async with db_pool.acquire() as conn:
        rows = await conn.fetch(query, *params)
    
    products = [dict(row) for row in rows]
    
    # Cache results
    if redis_client and products:
        try:
            import json
            await redis_client.setex(
                cache_key, 
                CONFIG["redis_ttl"], 
                json.dumps(products, default=str)
            )
        except Exception as e:
            logger.warning("Cache storage failed", error=str(e))
    
    return products

@app.get("/api/products/{product_id}", response_model=Product, tags=["Products"])
async def get_product(
    product_id: int,
    current_user: dict = Depends(get_current_user)
):
    """Get a specific product"""
    # Try cache
    cache_key = f"product:{product_id}"
    if redis_client:
        try:
            cached = await redis_client.get(cache_key)
            if cached:
                cache_hits.labels(operation="get_product").inc()
                import json
                return json.loads(cached)
        except:
            pass
    
    cache_misses.labels(operation="get_product").inc()
    
    # Query database
    async with db_pool.acquire() as conn:
        row = await conn.fetchrow(
            """
            SELECT id, name, description, price, category, sku,
                   stock_quantity, manufacturer, created_at, updated_at
            FROM products WHERE id = $1
            """,
            product_id
        )
    
    if not row:
        raise HTTPException(status_code=404, detail="Product not found")
    
    product = dict(row)
    
    # Cache result
    if redis_client:
        try:
            import json
            await redis_client.setex(
                cache_key,
                CONFIG["redis_ttl"],
                json.dumps(product, default=str)
            )
        except:
            pass
    
    return product

@app.post("/api/products", response_model=Product, status_code=201, tags=["Products"])
async def create_product(
    product: ProductCreate,
    current_user: dict = Depends(get_current_user)
):
    """Create a new product (admin only)"""
    # Simple admin check - in production, use proper RBAC
    if current_user["sub"] != "admin":
        raise HTTPException(status_code=403, detail="Admin access required")
    
    try:
        async with db_pool.acquire() as conn:
            row = await conn.fetchrow(
                """
                INSERT INTO products (name, description, price, category, sku, 
                                    stock_quantity, manufacturer)
                VALUES ($1, $2, $3, $4, $5, $6, $7)
                RETURNING id, name, description, price, category, sku,
                          stock_quantity, manufacturer, created_at, updated_at
                """,
                product.name, product.description, product.price,
                product.category, product.sku, product.stock_quantity,
                product.manufacturer
            )
        
        # Invalidate cache
        if redis_client:
            try:
                await redis_client.delete(f"products:*")
            except:
                pass
        
        logger.info("Product created", product_id=row["id"], user=current_user["sub"])
        return dict(row)
        
    except asyncpg.UniqueViolationError:
        raise HTTPException(status_code=400, detail="SKU already exists")

@app.put("/api/products/{product_id}", response_model=Product, tags=["Products"])
async def update_product(
    product_id: int,
    product: ProductUpdate,
    current_user: dict = Depends(get_current_user)
):
    """Update a product (admin only)"""
    if current_user["sub"] != "admin":
        raise HTTPException(status_code=403, detail="Admin access required")
    
    # Build update query
    updates = []
    params = []
    param_count = 0
    
    for field, value in product.dict(exclude_unset=True).items():
        param_count += 1
        updates.append(f"{field} = ${param_count}")
        params.append(value)
    
    if not updates:
        raise HTTPException(status_code=400, detail="No fields to update")
    
    param_count += 1
    params.append(product_id)
    
    query = f"""
        UPDATE products 
        SET {', '.join(updates)}, updated_at = CURRENT_TIMESTAMP
        WHERE id = ${param_count}
        RETURNING id, name, description, price, category, sku,
                  stock_quantity, manufacturer, created_at, updated_at
    """
    
    async with db_pool.acquire() as conn:
        row = await conn.fetchrow(query, *params)
    
    if not row:
        raise HTTPException(status_code=404, detail="Product not found")
    
    # Invalidate cache
    if redis_client:
        try:
            await redis_client.delete(f"product:{product_id}")
            await redis_client.delete(f"products:*")
        except:
            pass
    
    logger.info("Product updated", product_id=product_id, user=current_user["sub"])
    return dict(row)

@app.delete("/api/products/{product_id}", status_code=204, tags=["Products"])
async def delete_product(
    product_id: int,
    current_user: dict = Depends(get_current_user)
):
    """Delete a product (admin only)"""
    if current_user["sub"] != "admin":
        raise HTTPException(status_code=403, detail="Admin access required")
    
    async with db_pool.acquire() as conn:
        result = await conn.execute(
            "DELETE FROM products WHERE id = $1",
            product_id
        )
    
    if result == "DELETE 0":
        raise HTTPException(status_code=404, detail="Product not found")
    
    # Invalidate cache
    if redis_client:
        try:
            await redis_client.delete(f"product:{product_id}")
            await redis_client.delete(f"products:*")
        except:
            pass
    
    logger.info("Product deleted", product_id=product_id, user=current_user["sub"])
    return Response(status_code=204)

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        app,
        host="0.0.0.0",
        port=int(os.getenv("PORT", "8080")),
        log_config={
            "version": 1,
            "disable_existing_loggers": False,
            "formatters": {
                "default": {
                    "format": "%(asctime)s - %(name)s - %(levelname)s - %(message)s",
                },
            },
            "handlers": {
                "default": {
                    "formatter": "default",
                    "class": "logging.StreamHandler",
                    "stream": "ext://sys.stdout",
                },
            },
            "root": {
                "level": "INFO",
                "handlers": ["default"],
            },
        }
    )