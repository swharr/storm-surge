#!/usr/bin/env python3
"""
Secure Product Catalog API Service
Production-ready with comprehensive security controls
"""

import asyncio
import os
import sys
from typing import List, Optional
from contextlib import asynccontextmanager

import asyncpg
import redis.asyncio as redis
import structlog
from fastapi import FastAPI, HTTPException, Depends, Query, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.trustedhost import TrustedHostMiddleware
from pydantic import BaseModel, Field
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
from fastapi.responses import Response

# Import security modules
sys.path.append('/app/security')
from secure_api_auth import (
    require_auth, require_rate_limit, add_security_headers,
    SecurityConfig, jwt_manager
)

# Configure structured logging
structlog.configure(
    processors=[
        structlog.stdlib.filter_by_level,
        structlog.stdlib.add_logger_name,
        structlog.stdlib.add_log_level,
        structlog.stdlib.PositionalArgumentsFormatter(),
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

# Security-enhanced Prometheus metrics
REQUEST_COUNT = Counter('product_catalog_requests_total', 'Total requests', ['method', 'endpoint', 'status', 'user_type'])
REQUEST_DURATION = Histogram('product_catalog_request_duration_seconds', 'Request duration', ['endpoint'])
DB_OPERATIONS = Counter('product_catalog_db_operations_total', 'Database operations', ['operation', 'status'])
AUTH_ATTEMPTS = Counter('product_catalog_auth_attempts_total', 'Authentication attempts', ['method', 'status'])
SECURITY_EVENTS = Counter('product_catalog_security_events_total', 'Security events', ['event_type'])

# Database connection pool
db_pool = None
redis_client = None

# Enhanced Pydantic models with security validation
class Product(BaseModel):
    id: Optional[int] = None
    name: str = Field(..., min_length=1, max_length=255, regex=r'^[a-zA-Z0-9\s\-\.\(\)]+$')
    description: str = Field(..., max_length=1000, regex=r'^[a-zA-Z0-9\s\-\.\(\)\n\r,;:!?]+$')
    price: float = Field(..., gt=0, le=999999.99)
    category: str = Field(..., max_length=100, regex=r'^[a-zA-Z0-9\s\-]+$')
    sku: str = Field(..., max_length=50, regex=r'^[A-Z0-9\-]+$')
    stock_quantity: int = Field(..., ge=0, le=999999)
    manufacturer: str = Field(..., max_length=100, regex=r'^[a-zA-Z0-9\s\-\.\&]+$')
    year_compatibility: Optional[str] = Field(None, regex=r'^\d{4}-\d{4}$|^\d{4}$')

class ProductCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=255, regex=r'^[a-zA-Z0-9\s\-\.\(\)]+$')
    description: str = Field(..., max_length=1000, regex=r'^[a-zA-Z0-9\s\-\.\(\)\n\r,;:!?]+$')
    price: float = Field(..., gt=0, le=999999.99)
    category: str = Field(..., max_length=100, regex=r'^[a-zA-Z0-9\s\-]+$')
    sku: str = Field(..., max_length=50, regex=r'^[A-Z0-9\-]+$')
    stock_quantity: int = Field(..., ge=0, le=999999)
    manufacturer: str = Field(..., max_length=100, regex=r'^[a-zA-Z0-9\s\-\.\&]+$')
    year_compatibility: Optional[str] = Field(None, regex=r'^\d{4}-\d{4}$|^\d{4}$')

class ProductUpdate(BaseModel):
    name: Optional[str] = Field(None, min_length=1, max_length=255, regex=r'^[a-zA-Z0-9\s\-\.\(\)]+$')
    description: Optional[str] = Field(None, max_length=1000, regex=r'^[a-zA-Z0-9\s\-\.\(\)\n\r,;:!?]+$')
    price: Optional[float] = Field(None, gt=0, le=999999.99)
    category: Optional[str] = Field(None, max_length=100, regex=r'^[a-zA-Z0-9\s\-]+$')
    stock_quantity: Optional[int] = Field(None, ge=0, le=999999)
    manufacturer: Optional[str] = Field(None, max_length=100, regex=r'^[a-zA-Z0-9\s\-\.\&]+$')
    year_compatibility: Optional[str] = Field(None, regex=r'^\d{4}-\d{4}$|^\d{4}$')

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Secure application lifecycle management"""
    logger.info("Starting Secure Product Catalog API")
    
    try:
        # Verify security configuration
        SecurityConfig.validate_config()
        
        # Initialize database and cache
        await init_database()
        await init_redis()
        await create_tables()
        await seed_data()
        
        logger.info("Product Catalog API started successfully")
        yield
        
    except Exception as e:
        logger.error("Failed to start application", error=str(e))
        raise
    finally:
        # Shutdown
        logger.info("Shutting down Product Catalog API")
        if db_pool:
            await db_pool.close()
        if redis_client:
            await redis_client.close()

app = FastAPI(
    title="Secure Product Catalog API",
    description="Production-ready automotive parts catalog microservice with comprehensive security",
    version="2.0.0-secure",
    lifespan=lifespan,
    docs_url=None,  # Disable swagger in production
    redoc_url=None,  # Disable redoc in production
)

# Security middleware
app.add_middleware(
    TrustedHostMiddleware, 
    allowed_hosts=["*.yourdomain.com", "localhost", "127.0.0.1"]
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["https://yourdomain.com", "https://trailforge.com"],
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE"],
    allow_headers=["Authorization", "Content-Type", "X-API-Key"],
    expose_headers=["X-RateLimit-Remaining", "X-RateLimit-Reset"]
)

# Security headers middleware
@app.middleware("http")
async def security_middleware(request: Request, call_next):
    # Log request for security monitoring
    logger.info("API request", 
               method=request.method,
               path=request.url.path,
               ip=request.client.host,
               user_agent=request.headers.get("user-agent", "unknown")[:100])
    
    start_time = asyncio.get_event_loop().time()
    
    try:
        response = await call_next(request)
        
        # Add security headers
        response = add_security_headers(response)
        
        # Record metrics
        duration = asyncio.get_event_loop().time() - start_time
        user_type = getattr(request.state, 'auth', {}).get('user_type', 'anonymous')
        
        REQUEST_COUNT.labels(
            method=request.method,
            endpoint=request.url.path,
            status=response.status_code,
            user_type=user_type
        ).inc()
        
        REQUEST_DURATION.labels(endpoint=request.url.path).observe(duration)
        
        return response
        
    except Exception as e:
        SECURITY_EVENTS.labels(event_type='request_error').inc()
        logger.error("Request processing failed", error=str(e), path=request.url.path)
        raise

async def init_database():
    """Initialize secure PostgreSQL connection pool"""
    global db_pool
    try:
        db_pool = await asyncpg.create_pool(
            host=os.getenv('POSTGRES_HOST', 'postgresql'),
            port=int(os.getenv('POSTGRES_PORT', 5432)),
            user=os.getenv('POSTGRES_USER', 'oceansurge'),
            password=os.getenv('POSTGRES_PASSWORD'),
            database=os.getenv('POSTGRES_DB', 'oceansurge'),
            min_size=2,
            max_size=10,
            command_timeout=30,
            server_settings={
                'application_name': 'product-catalog-secure',
                'jit': 'off'  # Disable JIT for security
            }
        )
        logger.info("Secure database connection pool created")
    except Exception as e:
        logger.error("Failed to connect to database", error=str(e))
        SECURITY_EVENTS.labels(event_type='database_connection_failed').inc()
        raise

async def init_redis():
    """Initialize secure Redis connection"""
    global redis_client
    try:
        redis_client = redis.from_url(
            f"redis://:{os.getenv('REDIS_PASSWORD')}@{os.getenv('REDIS_HOST', 'redis')}:{os.getenv('REDIS_PORT', 6379)}/0",
            socket_connect_timeout=5,
            socket_timeout=5,
            health_check_interval=30
        )
        await redis_client.ping()
        logger.info("Secure Redis connection established")
    except Exception as e:
        logger.error("Failed to connect to Redis", error=str(e))
        SECURITY_EVENTS.labels(event_type='redis_connection_failed').inc()
        raise

async def create_tables():
    """Create database tables with security constraints"""
    create_table_sql = """
    CREATE TABLE IF NOT EXISTS products (
        id SERIAL PRIMARY KEY,
        name VARCHAR(255) NOT NULL CHECK (length(name) > 0),
        description TEXT CHECK (length(description) <= 1000),
        price DECIMAL(10,2) NOT NULL CHECK (price > 0 AND price <= 999999.99),
        category VARCHAR(100) NOT NULL CHECK (length(category) > 0),
        sku VARCHAR(50) UNIQUE NOT NULL CHECK (sku ~ '^[A-Z0-9\-]+$'),
        stock_quantity INTEGER DEFAULT 0 CHECK (stock_quantity >= 0 AND stock_quantity <= 999999),
        manufacturer VARCHAR(100) CHECK (length(manufacturer) > 0),
        year_compatibility VARCHAR(50) CHECK (year_compatibility ~ '^\d{4}-\d{4}$|^\d{4}$' OR year_compatibility IS NULL),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
    
    CREATE INDEX IF NOT EXISTS idx_products_category ON products(category);
    CREATE INDEX IF NOT EXISTS idx_products_manufacturer ON products(manufacturer);
    CREATE INDEX IF NOT EXISTS idx_products_sku ON products(sku);
    CREATE INDEX IF NOT EXISTS idx_products_price ON products(price);
    
    -- Row Level Security (if supported)
    -- ALTER TABLE products ENABLE ROW LEVEL SECURITY;
    """
    
    async with db_pool.acquire() as conn:
        await conn.execute(create_table_sql)
        logger.info("Secure database tables created/verified")

async def seed_data():
    """Seed initial data securely"""
    check_sql = "SELECT COUNT(*) FROM products"
    async with db_pool.acquire() as conn:
        count = await conn.fetchval(check_sql)
        if count == 0:
            # Secure sample data
            sample_products = [
                ("Brake Pads - Ceramic", "High-performance ceramic brake pads for superior stopping power", 89.99, "Brakes", "BP-CER-001", 25, "Brembo", "2018-2023"),
                ("Oil Filter Premium", "Premium oil filter for maximum engine protection", 12.99, "Engine", "OF-PREM-002", 100, "Fram", "2015-2023"),
                ("Spark Plugs Iridium Set", "Iridium spark plugs set of 4 for enhanced performance", 34.99, "Engine", "SP-IRD-003", 50, "NGK", "2010-2023"),
                ("High-Flow Air Filter", "High-flow air filter for improved engine breathing", 24.99, "Engine", "AF-HF-004", 75, "K&N", "2012-2023"),
                ("Heavy-Duty Shock Absorbers", "Premium heavy-duty shock absorbers for smooth ride", 129.99, "Suspension", "SA-HD-005", 15, "Monroe", "2016-2023")
            ]
            
            insert_sql = """
            INSERT INTO products (name, description, price, category, sku, stock_quantity, manufacturer, year_compatibility)
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
            """
            
            for product in sample_products:
                await conn.execute(insert_sql, *product)
            
            logger.info(f"Seeded {len(sample_products)} secure sample products")

async def get_db():
    """Secure database dependency"""
    if not db_pool:
        raise HTTPException(status_code=503, detail="Database not available")
    return db_pool

# Public endpoints (no authentication required)
@app.get("/health")
async def health_check(request: Request):
    """Secure health check endpoint"""
    try:
        # Check database
        async with db_pool.acquire() as conn:
            await conn.fetchval("SELECT 1")
        
        # Check Redis
        await redis_client.ping()
        
        return {"status": "healthy", "service": "product-catalog-secure", "version": "2.0.0"}
    except Exception as e:
        logger.error("Health check failed", error=str(e))
        SECURITY_EVENTS.labels(event_type='health_check_failed').inc()
        raise HTTPException(status_code=503, detail="Service unhealthy")

@app.get("/metrics")
async def metrics(request: Request):
    """Secure Prometheus metrics endpoint"""
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)

# Secured API endpoints
@app.get("/products", response_model=List[Product])
@require_auth(auth_methods=['api_key', 'jwt'], required_permissions=['read'])
@require_rate_limit(identifier='get_products', max_requests=1000, window_seconds=3600)
async def get_products(
    request: Request,
    category: Optional[str] = Query(None, regex=r'^[a-zA-Z0-9\s\-]+$'),
    manufacturer: Optional[str] = Query(None, regex=r'^[a-zA-Z0-9\s\-\.\&]+$'),
    limit: int = Query(20, le=100, ge=1),
    offset: int = Query(0, ge=0),
    db: asyncpg.Pool = Depends(get_db)
):
    """Get products with security controls"""
    
    with REQUEST_DURATION.labels(endpoint='get_products').time():
        # Build secure cache key
        cache_key = f"products:{category}:{manufacturer}:{limit}:{offset}"
        
        try:
            cached = await redis_client.get(cache_key)
            if cached:
                logger.info("Returning cached products", user=request.state.auth.get('user_type'))
                import json
                return json.loads(cached)
        except Exception as e:
            logger.warning("Cache retrieval failed", error=str(e))
        
        # Build secure parameterized query
        where_clauses = []
        params = []
        param_count = 0
        
        if category:
            param_count += 1
            where_clauses.append(f"category = ${param_count}")
            params.append(category)
        
        if manufacturer:
            param_count += 1
            where_clauses.append(f"manufacturer = ${param_count}")
            params.append(manufacturer)
        
        where_sql = " WHERE " + " AND ".join(where_clauses) if where_clauses else ""
        
        param_count += 1
        limit_param = f"${param_count}"
        params.append(limit)
        
        param_count += 1
        offset_param = f"${param_count}"
        params.append(offset)
        
        sql = f"""
        SELECT id, name, description, price, category, sku, stock_quantity, manufacturer, year_compatibility
        FROM products {where_sql}
        ORDER BY name
        LIMIT {limit_param} OFFSET {offset_param}
        """
        
        async with db.acquire() as conn:
            rows = await conn.fetch(sql, *params)
            DB_OPERATIONS.labels(operation='select', status='success').inc()
            
        products = [dict(row) for row in rows]
        
        # Secure caching (5 minutes)
        try:
            import json
            await redis_client.setex(cache_key, 300, json.dumps(products))
        except Exception as e:
            logger.warning("Cache storage failed", error=str(e))
        
        logger.info(f"Retrieved {len(products)} products", 
                   user=request.state.auth.get('user_type'),
                   category=category,
                   manufacturer=manufacturer)
        return products

@app.get("/products/{product_id}", response_model=Product)
@require_auth(auth_methods=['api_key', 'jwt'], required_permissions=['read'])
@require_rate_limit(identifier='get_product', max_requests=2000, window_seconds=3600)
async def get_product(request: Request, product_id: int = Field(..., gt=0), db: asyncpg.Pool = Depends(get_db)):
    """Get specific product with security controls"""
    
    with REQUEST_DURATION.labels(endpoint='get_product').time():
        cache_key = f"product:{product_id}"
        
        try:
            cached = await redis_client.get(cache_key)
            if cached:
                import json
                return json.loads(cached)
        except Exception as e:
            logger.warning("Cache retrieval failed", error=str(e))
        
        sql = """
        SELECT id, name, description, price, category, sku, stock_quantity, manufacturer, year_compatibility
        FROM products WHERE id = $1
        """
        
        async with db.acquire() as conn:
            row = await conn.fetchrow(sql, product_id)
            DB_OPERATIONS.labels(operation='select', status='success').inc()
            
        if not row:
            logger.warning("Product not found", product_id=product_id, user=request.state.auth.get('user_type'))
            raise HTTPException(status_code=404, detail="Product not found")
        
        product = dict(row)
        
        # Cache for 5 minutes
        try:
            import json
            await redis_client.setex(cache_key, 300, json.dumps(product))
        except Exception as e:
            logger.warning("Cache storage failed", error=str(e))
        
        return product

@app.post("/products", response_model=Product, status_code=201)
@require_auth(auth_methods=['api_key', 'jwt'], required_permissions=['write'])
@require_rate_limit(identifier='create_product', max_requests=100, window_seconds=3600)
async def create_product(request: Request, product: ProductCreate, db: asyncpg.Pool = Depends(get_db)):
    """Create product with security controls"""
    
    with REQUEST_DURATION.labels(endpoint='create_product').time():
        sql = """
        INSERT INTO products (name, description, price, category, sku, stock_quantity, manufacturer, year_compatibility)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
        RETURNING id, name, description, price, category, sku, stock_quantity, manufacturer, year_compatibility
        """
        
        try:
            async with db.acquire() as conn:
                row = await conn.fetchrow(
                    sql, 
                    product.name, product.description, product.price, 
                    product.category, product.sku, product.stock_quantity,
                    product.manufacturer, product.year_compatibility
                )
                DB_OPERATIONS.labels(operation='insert', status='success').inc()
                
            # Invalidate relevant caches securely
            try:
                pattern = f"products:*{product.category}*"
                # Note: In production, use more efficient cache invalidation
                await redis_client.delete(pattern)
            except Exception as e:
                logger.warning("Cache invalidation failed", error=str(e))
            
            logger.info(f"Created product {row['id']}", 
                       user=request.state.auth.get('user_type'),
                       sku=product.sku)
            return dict(row)
            
        except asyncpg.UniqueViolationError:
            DB_OPERATIONS.labels(operation='insert', status='error').inc()
            logger.warning("Duplicate SKU attempt", sku=product.sku, user=request.state.auth.get('user_type'))
            raise HTTPException(status_code=400, detail="SKU already exists")

@app.put("/products/{product_id}", response_model=Product)
@require_auth(auth_methods=['api_key', 'jwt'], required_permissions=['write'])
@require_rate_limit(identifier='update_product', max_requests=100, window_seconds=3600)
async def update_product(request: Request, product_id: int = Field(..., gt=0), product: ProductUpdate = None, db: asyncpg.Pool = Depends(get_db)):
    """Update product with security controls"""
    
    with REQUEST_DURATION.labels(endpoint='update_product').time():
        # Secure field validation
        updates = []
        params = []
        param_count = 0
        
        # Strict whitelist of allowed fields
        allowed_fields = {'name', 'description', 'price', 'category', 'stock_quantity', 'manufacturer', 'year_compatibility'}
        
        for field, value in product.dict(exclude_unset=True).items():
            if field not in allowed_fields:
                SECURITY_EVENTS.labels(event_type='invalid_field_access').inc()
                logger.warning("Invalid field update attempt", field=field, user=request.state.auth.get('user_type'))
                raise HTTPException(status_code=400, detail=f"Invalid field: {field}")
            param_count += 1
            updates.append(f"{field} = ${param_count}")
            params.append(value)
        
        if not updates:
            raise HTTPException(status_code=400, detail="No fields to update")
        
        param_count += 1
        params.append(product_id)
        
        sql = f"""
        UPDATE products SET {', '.join(updates)}, updated_at = CURRENT_TIMESTAMP
        WHERE id = ${param_count}
        RETURNING id, name, description, price, category, sku, stock_quantity, manufacturer, year_compatibility
        """
        
        async with db.acquire() as conn:
            row = await conn.fetchrow(sql, *params)
            DB_OPERATIONS.labels(operation='update', status='success').inc()
            
        if not row:
            logger.warning("Product not found for update", product_id=product_id, user=request.state.auth.get('user_type'))
            raise HTTPException(status_code=404, detail="Product not found")
        
        # Secure cache invalidation
        try:
            await redis_client.delete(f"product:{product_id}")
            await redis_client.delete(f"products:*")
        except Exception as e:
            logger.warning("Cache invalidation failed", error=str(e))
        
        logger.info(f"Updated product {product_id}", user=request.state.auth.get('user_type'))
        return dict(row)

@app.delete("/products/{product_id}")
@require_auth(auth_methods=['api_key', 'jwt'], required_permissions=['admin'])
@require_rate_limit(identifier='delete_product', max_requests=50, window_seconds=3600)
async def delete_product(request: Request, product_id: int = Field(..., gt=0), db: asyncpg.Pool = Depends(get_db)):
    """Delete product with security controls (admin only)"""
    
    with REQUEST_DURATION.labels(endpoint='delete_product').time():
        sql = "DELETE FROM products WHERE id = $1"
        
        async with db.acquire() as conn:
            result = await conn.execute(sql, product_id)
            DB_OPERATIONS.labels(operation='delete', status='success').inc()
            
        if result == "DELETE 0":
            logger.warning("Product not found for deletion", product_id=product_id, user=request.state.auth.get('user_type'))
            raise HTTPException(status_code=404, detail="Product not found")
        
        # Secure cache invalidation
        try:
            await redis_client.delete(f"product:{product_id}")
            await redis_client.delete(f"products:*")
        except Exception as e:
            logger.warning("Cache invalidation failed", error=str(e))
        
        logger.info(f"Deleted product {product_id}", user=request.state.auth.get('user_type'))
        return {"message": "Product deleted successfully"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8080)