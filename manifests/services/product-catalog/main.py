#!/usr/bin/env python3
"""
Product Catalog API Service
A realistic microservice for managing automotive parts catalog
"""

import asyncio
import os
import logging
from typing import List, Optional
from contextlib import asynccontextmanager

import asyncpg
import redis.asyncio as redis
import structlog
from fastapi import FastAPI, HTTPException, Depends, Query, Request
from pydantic import BaseModel, Field
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
from fastapi.responses import Response
from fastapi.middleware.cors import CORSMiddleware

# Import security middleware
import sys
sys.path.append('/app/security')
from api_security import (
    require_auth, require_rate_limit, add_security_headers,
    is_public_endpoint, APISecurityConfig
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

# Prometheus metrics
REQUEST_COUNT = Counter('product_catalog_requests_total', 'Total requests', ['method', 'endpoint'])
REQUEST_DURATION = Histogram('product_catalog_request_duration_seconds', 'Request duration')
DB_OPERATIONS = Counter('product_catalog_db_operations_total', 'Database operations', ['operation'])

# Database connection pool
db_pool = None
redis_client = None

# Pydantic models
class Product(BaseModel):
    id: Optional[int] = None
    name: str = Field(..., min_length=1, max_length=255)
    description: str = Field(..., max_length=1000)
    price: float = Field(..., gt=0)
    category: str = Field(..., max_length=100)
    sku: str = Field(..., max_length=50)
    stock_quantity: int = Field(..., ge=0)
    manufacturer: str = Field(..., max_length=100)
    year_compatibility: Optional[str] = None
    
class ProductCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=255)
    description: str = Field(..., max_length=1000)
    price: float = Field(..., gt=0)
    category: str = Field(..., max_length=100)
    sku: str = Field(..., max_length=50)
    stock_quantity: int = Field(..., ge=0)
    manufacturer: str = Field(..., max_length=100)
    year_compatibility: Optional[str] = None

class ProductUpdate(BaseModel):
    name: Optional[str] = Field(None, min_length=1, max_length=255)
    description: Optional[str] = Field(None, max_length=1000)
    price: Optional[float] = Field(None, gt=0)
    category: Optional[str] = Field(None, max_length=100)
    stock_quantity: Optional[int] = Field(None, ge=0)
    manufacturer: Optional[str] = Field(None, max_length=100)
    year_compatibility: Optional[str] = None

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Manage application lifecycle"""
    # Startup
    logger.info("Starting Product Catalog API")
    await init_database()
    await init_redis()
    await create_tables()
    await seed_data()
    yield
    # Shutdown
    logger.info("Shutting down Product Catalog API")
    if db_pool:
        await db_pool.close()
    if redis_client:
        await redis_client.close()

app = FastAPI(
    title="Product Catalog API",
    description="Automotive parts catalog microservice",
    version="1.0.0",
    lifespan=lifespan
)

# Configure CORS properly
app.add_middleware(
    CORSMiddleware,
    allow_origins=["https://yourdomain.com"],  # Replace with actual domain
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE"],
    allow_headers=["*"],
)

# Add security headers middleware
@app.middleware("http")
async def security_middleware(request: Request, call_next):
    response = await call_next(request)
    return add_security_headers(response)

async def init_database():
    """Initialize PostgreSQL connection pool"""
    global db_pool
    try:
        db_pool = await asyncpg.create_pool(
            host=os.getenv('POSTGRES_HOST', 'postgresql'),
            port=int(os.getenv('POSTGRES_PORT', 5432)),
            user=os.getenv('POSTGRES_USER', 'oceansurge'),
            password=os.getenv('POSTGRES_PASSWORD', ''),
            database=os.getenv('POSTGRES_DB', 'oceansurge'),
            min_size=2,
            max_size=10
        )
        logger.info("Database connection pool created")
    except Exception as e:
        logger.error("Failed to connect to database", error=str(e))
        raise

async def init_redis():
    """Initialize Redis connection"""
    global redis_client
    try:
        redis_client = redis.from_url(
            f"redis://{os.getenv('REDIS_HOST', 'redis')}:{os.getenv('REDIS_PORT', 6379)}/0"
        )
        await redis_client.ping()
        logger.info("Redis connection established")
    except Exception as e:
        logger.error("Failed to connect to Redis", error=str(e))
        raise

async def create_tables():
    """Create database tables if they don't exist"""
    create_table_sql = """
    CREATE TABLE IF NOT EXISTS products (
        id SERIAL PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        description TEXT,
        price DECIMAL(10,2) NOT NULL,
        category VARCHAR(100) NOT NULL,
        sku VARCHAR(50) UNIQUE NOT NULL,
        stock_quantity INTEGER DEFAULT 0,
        manufacturer VARCHAR(100),
        year_compatibility VARCHAR(50),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
    
    CREATE INDEX IF NOT EXISTS idx_products_category ON products(category);
    CREATE INDEX IF NOT EXISTS idx_products_manufacturer ON products(manufacturer);
    CREATE INDEX IF NOT EXISTS idx_products_sku ON products(sku);
    """
    
    async with db_pool.acquire() as conn:
        await conn.execute(create_table_sql)
        logger.info("Database tables created/verified")

async def seed_data():
    """Seed initial data"""
    check_sql = "SELECT COUNT(*) FROM products"
    async with db_pool.acquire() as conn:
        count = await conn.fetchval(check_sql)
        if count == 0:
            sample_products = [
                ("Brake Pads - Ceramic", "High-performance ceramic brake pads", 89.99, "Brakes", "BP-CER-001", 25, "Brembo", "2018-2023"),
                ("Oil Filter", "Premium oil filter for engine protection", 12.99, "Engine", "OF-PREM-002", 100, "Fram", "2015-2023"),
                ("Spark Plugs (Set of 4)", "Iridium spark plugs for better performance", 34.99, "Engine", "SP-IRD-003", 50, "NGK", "2010-2023"),
                ("Air Filter", "High-flow air filter", 24.99, "Engine", "AF-HF-004", 75, "K&N", "2012-2023"),
                ("Shock Absorbers", "Heavy-duty shock absorbers", 129.99, "Suspension", "SA-HD-005", 15, "Monroe", "2016-2023"),
                ("Tire - All Season", "All-season tire 225/60R16", 89.99, "Tires", "T-AS-225-006", 40, "Michelin", "2010-2023"),
                ("Battery", "12V automotive battery", 119.99, "Electrical", "BAT-12V-007", 20, "Interstate", "2008-2023"),
                ("Headlight Bulb", "LED headlight bulb H11", 45.99, "Electrical", "HB-LED-008", 60, "Philips", "2015-2023")
            ]
            
            insert_sql = """
            INSERT INTO products (name, description, price, category, sku, stock_quantity, manufacturer, year_compatibility)
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
            """
            
            for product in sample_products:
                await conn.execute(insert_sql, *product)
            
            logger.info(f"Seeded {len(sample_products)} sample products")

async def get_db():
    """Database dependency"""
    if not db_pool:
        raise HTTPException(status_code=503, detail="Database not available")
    return db_pool

# Health check endpoint
@app.get("/health")
async def health_check():
    """Health check endpoint"""
    try:
        # Check database
        async with db_pool.acquire() as conn:
            await conn.fetchval("SELECT 1")
        
        # Check Redis
        await redis_client.ping()
        
        return {"status": "healthy", "service": "product-catalog"}
    except Exception as e:
        logger.error("Health check failed", error=str(e))
        raise HTTPException(status_code=503, detail="Service unhealthy")

# Metrics endpoint
@app.get("/metrics")
async def metrics():
    """Prometheus metrics endpoint"""
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)

# Product endpoints
@app.get("/products", response_model=List[Product])
@require_auth(allowed_roles=['admin', 'service', 'readonly'])
@require_rate_limit(max_requests=1000, window_seconds=3600)
async def get_products(
    request: Request,
    category: Optional[str] = Query(None),
    manufacturer: Optional[str] = Query(None),
    limit: int = Query(20, le=100),
    offset: int = Query(0, ge=0),
    db: asyncpg.Pool = Depends(get_db)
):
    """Get products with optional filtering"""
    REQUEST_COUNT.labels(method="GET", endpoint="products").inc()
    
    with REQUEST_DURATION.time():
        # Try cache first
        cache_key = f"products:{category}:{manufacturer}:{limit}:{offset}"
        cached = await redis_client.get(cache_key)
        
        if cached:
            logger.info("Returning cached products")
            import json
            return json.loads(cached)  # Safe JSON deserialization
        
        # Build query
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
            DB_OPERATIONS.labels(operation="select").inc()
            
        products = [dict(row) for row in rows]
        
        # Cache for 5 minutes
        import json
        await redis_client.setex(cache_key, 300, json.dumps(products))
        
        logger.info(f"Retrieved {len(products)} products")
        return products

@app.get("/products/{product_id}", response_model=Product)
@require_auth(allowed_roles=['admin', 'service', 'readonly'])
@require_rate_limit(max_requests=1000, window_seconds=3600)
async def get_product(request: Request, product_id: int, db: asyncpg.Pool = Depends(get_db)):
    """Get a specific product"""
    REQUEST_COUNT.labels(method="GET", endpoint="product").inc()
    
    with REQUEST_DURATION.time():
        cache_key = f"product:{product_id}"
        cached = await redis_client.get(cache_key)
        
        if cached:
            import json
            return json.loads(cached)  # Safe JSON deserialization
        
        sql = """
        SELECT id, name, description, price, category, sku, stock_quantity, manufacturer, year_compatibility
        FROM products WHERE id = $1
        """
        
        async with db.acquire() as conn:
            row = await conn.fetchrow(sql, product_id)
            DB_OPERATIONS.labels(operation="select").inc()
            
        if not row:
            raise HTTPException(status_code=404, detail="Product not found")
        
        product = dict(row)
        import json
        await redis_client.setex(cache_key, 300, json.dumps(product))
        
        return product

@app.post("/products", response_model=Product, status_code=201)
@require_auth(allowed_roles=['admin', 'service'])
@require_rate_limit(max_requests=100, window_seconds=3600)
async def create_product(request: Request, product: ProductCreate, db: asyncpg.Pool = Depends(get_db)):
    """Create a new product"""
    REQUEST_COUNT.labels(method="POST", endpoint="products").inc()
    
    with REQUEST_DURATION.time():
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
                DB_OPERATIONS.labels(operation="insert").inc()
                
            # Invalidate relevant caches
            await redis_client.delete(f"products:{product.category}:*")
            
            logger.info(f"Created product {row['id']}")
            return dict(row)
            
        except asyncpg.UniqueViolationError:
            raise HTTPException(status_code=400, detail="SKU already exists")

@app.put("/products/{product_id}", response_model=Product)
@require_auth(allowed_roles=['admin', 'service'])
@require_rate_limit(max_requests=100, window_seconds=3600)
async def update_product(request: Request, product_id: int, product: ProductUpdate, db: asyncpg.Pool = Depends(get_db)):
    """Update a product"""
    REQUEST_COUNT.labels(method="PUT", endpoint="product").inc()
    
    with REQUEST_DURATION.time():
        # Build update query dynamically with field validation
        updates = []
        params = []
        param_count = 0
        
        # Whitelist of allowed fields to prevent SQL injection
        allowed_fields = {'name', 'description', 'price', 'category', 'sku', 
                         'stock_quantity', 'manufacturer', 'year_compatibility'}
        
        for field, value in product.dict(exclude_unset=True).items():
            if field not in allowed_fields:
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
            DB_OPERATIONS.labels(operation="update").inc()
            
        if not row:
            raise HTTPException(status_code=404, detail="Product not found")
        
        # Invalidate caches
        await redis_client.delete(f"product:{product_id}")
        await redis_client.delete(f"products:*")
        
        logger.info(f"Updated product {product_id}")
        return dict(row)

@app.delete("/products/{product_id}")
@require_auth(allowed_roles=['admin'])
@require_rate_limit(max_requests=50, window_seconds=3600)
async def delete_product(request: Request, product_id: int, db: asyncpg.Pool = Depends(get_db)):
    """Delete a product"""
    REQUEST_COUNT.labels(method="DELETE", endpoint="product").inc()
    
    with REQUEST_DURATION.time():
        sql = "DELETE FROM products WHERE id = $1"
        
        async with db.acquire() as conn:
            result = await conn.execute(sql, product_id)
            DB_OPERATIONS.labels(operation="delete").inc()
            
        if result == "DELETE 0":
            raise HTTPException(status_code=404, detail="Product not found")
        
        # Invalidate caches
        await redis_client.delete(f"product:{product_id}")
        await redis_client.delete(f"products:*")
        
        logger.info(f"Deleted product {product_id}")
        return {"message": "Product deleted successfully"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8080)