#!/usr/bin/env python3
"""
Shopping Cart API Service
A realistic microservice for managing shopping carts with Redis persistence
"""

import asyncio
import os
import json
import uuid
from typing import List, Optional, Dict
from contextlib import asynccontextmanager
from datetime import datetime, timedelta

import redis.asyncio as redis
import structlog
from fastapi import FastAPI, HTTPException, Depends, Query, Header
from pydantic import BaseModel, Field
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
from fastapi.responses import Response
import httpx

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
REQUEST_COUNT = Counter('shopping_cart_requests_total', 'Total requests', ['method', 'endpoint'])
REQUEST_DURATION = Histogram('shopping_cart_request_duration_seconds', 'Request duration')
CACHE_OPERATIONS = Counter('shopping_cart_cache_operations_total', 'Cache operations', ['operation'])
CART_OPERATIONS = Counter('shopping_cart_operations_total', 'Cart operations', ['operation'])

# Redis client
redis_client = None

# Pydantic models
class CartItem(BaseModel):
    product_id: int
    name: str
    price: float
    quantity: int = Field(..., gt=0)
    sku: str
    
class CartItemAdd(BaseModel):
    product_id: int
    quantity: int = Field(..., gt=0)

class CartItemUpdate(BaseModel):
    quantity: int = Field(..., gt=0)

class Cart(BaseModel):
    cart_id: str
    user_id: Optional[str] = None
    items: List[CartItem] = []
    total_items: int = 0
    total_amount: float = 0.0
    created_at: datetime
    updated_at: datetime
    expires_at: datetime

class CartSummary(BaseModel):
    cart_id: str
    total_items: int
    total_amount: float
    item_count: int

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Manage application lifecycle"""
    # Startup
    logger.info("Starting Shopping Cart API")
    await init_redis()
    yield
    # Shutdown
    logger.info("Shutting down Shopping Cart API")
    if redis_client:
        await redis_client.close()

app = FastAPI(
    title="Shopping Cart API",
    description="Shopping cart microservice with Redis persistence",
    version="1.0.0",
    lifespan=lifespan
)

async def init_redis():
    """Initialize Redis connection"""
    global redis_client
    try:
        redis_client = redis.from_url(
            f"redis://{os.getenv('REDIS_HOST', 'redis')}:{os.getenv('REDIS_PORT', 6379)}/1"
        )
        await redis_client.ping()
        logger.info("Redis connection established")
    except Exception as e:
        logger.error("Failed to connect to Redis", error=str(e))
        raise

async def get_redis():
    """Redis dependency"""
    if not redis_client:
        raise HTTPException(status_code=503, detail="Cache not available")
    return redis_client

async def get_product_info(product_id: int) -> Dict:
    """Fetch product information from Product Catalog API"""
    try:
        product_api_url = os.getenv('PRODUCT_CATALOG_URL', 'http://product-catalog-api')
        async with httpx.AsyncClient() as client:
            response = await client.get(f"{product_api_url}/products/{product_id}")
            if response.status_code == 200:
                return response.json()
            elif response.status_code == 404:
                raise HTTPException(status_code=404, detail="Product not found")
            else:
                raise HTTPException(status_code=503, detail="Product service unavailable")
    except httpx.RequestError:
        raise HTTPException(status_code=503, detail="Product service unavailable")

def generate_cart_id() -> str:
    """Generate a unique cart ID"""
    return str(uuid.uuid4())

async def get_cart_key(cart_id: str) -> str:
    """Generate Redis key for cart"""
    return f"cart:{cart_id}"

async def serialize_cart(cart: Cart) -> str:
    """Serialize cart to JSON string"""
    cart_dict = cart.dict()
    # Convert datetime objects to ISO strings
    cart_dict['created_at'] = cart.created_at.isoformat()
    cart_dict['updated_at'] = cart.updated_at.isoformat()
    cart_dict['expires_at'] = cart.expires_at.isoformat()
    return json.dumps(cart_dict)

async def deserialize_cart(cart_json: str) -> Cart:
    """Deserialize cart from JSON string"""
    cart_dict = json.loads(cart_json)
    # Convert ISO strings back to datetime objects
    cart_dict['created_at'] = datetime.fromisoformat(cart_dict['created_at'])
    cart_dict['updated_at'] = datetime.fromisoformat(cart_dict['updated_at'])
    cart_dict['expires_at'] = datetime.fromisoformat(cart_dict['expires_at'])
    return Cart(**cart_dict)

# Health check endpoint
@app.get("/health")
async def health_check():
    """Health check endpoint"""
    try:
        await redis_client.ping()
        return {"status": "healthy", "service": "shopping-cart"}
    except Exception as e:
        logger.error("Health check failed", error=str(e))
        raise HTTPException(status_code=503, detail="Service unhealthy")

# Metrics endpoint
@app.get("/metrics")
async def metrics():
    """Prometheus metrics endpoint"""
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)

# Cart endpoints
@app.post("/carts", response_model=Cart, status_code=201)
async def create_cart(
    user_id: Optional[str] = Header(None, alias="X-User-ID"),
    redis_conn: redis.Redis = Depends(get_redis)
):
    """Create a new shopping cart"""
    REQUEST_COUNT.labels(method="POST", endpoint="carts").inc()
    
    with REQUEST_DURATION.time():
        cart_id = generate_cart_id()
        now = datetime.utcnow()
        expires_at = now + timedelta(hours=24)  # Cart expires in 24 hours
        
        cart = Cart(
            cart_id=cart_id,
            user_id=user_id,
            items=[],
            total_items=0,
            total_amount=0.0,
            created_at=now,
            updated_at=now,
            expires_at=expires_at
        )
        
        cart_key = await get_cart_key(cart_id)
        await redis_conn.setex(cart_key, 86400, await serialize_cart(cart))  # 24 hours TTL
        CACHE_OPERATIONS.labels(operation="set").inc()
        CART_OPERATIONS.labels(operation="create").inc()
        
        logger.info(f"Created cart {cart_id}")
        return cart

@app.get("/carts/{cart_id}", response_model=Cart)
async def get_cart(cart_id: str, redis_conn: redis.Redis = Depends(get_redis)):
    """Get a shopping cart"""
    REQUEST_COUNT.labels(method="GET", endpoint="cart").inc()
    
    with REQUEST_DURATION.time():
        cart_key = await get_cart_key(cart_id)
        cart_json = await redis_conn.get(cart_key)
        CACHE_OPERATIONS.labels(operation="get").inc()
        
        if not cart_json:
            raise HTTPException(status_code=404, detail="Cart not found")
        
        cart = await deserialize_cart(cart_json)
        
        # Check if cart has expired
        if datetime.utcnow() > cart.expires_at:
            await redis_conn.delete(cart_key)
            CACHE_OPERATIONS.labels(operation="delete").inc()
            raise HTTPException(status_code=404, detail="Cart expired")
        
        return cart

@app.post("/carts/{cart_id}/items", response_model=Cart)
async def add_item_to_cart(
    cart_id: str, 
    item: CartItemAdd, 
    redis_conn: redis.Redis = Depends(get_redis)
):
    """Add item to shopping cart"""
    REQUEST_COUNT.labels(method="POST", endpoint="cart_items").inc()
    
    with REQUEST_DURATION.time():
        # Get cart
        cart_key = await get_cart_key(cart_id)
        cart_json = await redis_conn.get(cart_key)
        CACHE_OPERATIONS.labels(operation="get").inc()
        
        if not cart_json:
            raise HTTPException(status_code=404, detail="Cart not found")
        
        cart = await deserialize_cart(cart_json)
        
        # Check if cart has expired
        if datetime.utcnow() > cart.expires_at:
            await redis_conn.delete(cart_key)
            CACHE_OPERATIONS.labels(operation="delete").inc()
            raise HTTPException(status_code=404, detail="Cart expired")
        
        # Get product information
        product_info = await get_product_info(item.product_id)
        
        # Check if item already exists in cart
        existing_item = None
        for cart_item in cart.items:
            if cart_item.product_id == item.product_id:
                existing_item = cart_item
                break
        
        if existing_item:
            # Update quantity
            existing_item.quantity += item.quantity
        else:
            # Add new item
            cart_item = CartItem(
                product_id=item.product_id,
                name=product_info['name'],
                price=product_info['price'],
                quantity=item.quantity,
                sku=product_info['sku']
            )
            cart.items.append(cart_item)
        
        # Recalculate totals
        cart.total_items = sum(item.quantity for item in cart.items)
        cart.total_amount = sum(item.price * item.quantity for item in cart.items)
        cart.updated_at = datetime.utcnow()
        
        # Save cart
        await redis_conn.setex(cart_key, 86400, await serialize_cart(cart))
        CACHE_OPERATIONS.labels(operation="set").inc()
        CART_OPERATIONS.labels(operation="add_item").inc()
        
        logger.info(f"Added item {item.product_id} to cart {cart_id}")
        return cart

@app.put("/carts/{cart_id}/items/{product_id}", response_model=Cart)
async def update_cart_item(
    cart_id: str, 
    product_id: int, 
    update: CartItemUpdate,
    redis_conn: redis.Redis = Depends(get_redis)
):
    """Update item quantity in cart"""
    REQUEST_COUNT.labels(method="PUT", endpoint="cart_item").inc()
    
    with REQUEST_DURATION.time():
        # Get cart
        cart_key = await get_cart_key(cart_id)
        cart_json = await redis_conn.get(cart_key)
        CACHE_OPERATIONS.labels(operation="get").inc()
        
        if not cart_json:
            raise HTTPException(status_code=404, detail="Cart not found")
        
        cart = await deserialize_cart(cart_json)
        
        # Find item
        item_found = False
        for cart_item in cart.items:
            if cart_item.product_id == product_id:
                cart_item.quantity = update.quantity
                item_found = True
                break
        
        if not item_found:
            raise HTTPException(status_code=404, detail="Item not found in cart")
        
        # Recalculate totals
        cart.total_items = sum(item.quantity for item in cart.items)
        cart.total_amount = sum(item.price * item.quantity for item in cart.items)
        cart.updated_at = datetime.utcnow()
        
        # Save cart
        await redis_conn.setex(cart_key, 86400, await serialize_cart(cart))
        CACHE_OPERATIONS.labels(operation="set").inc()
        CART_OPERATIONS.labels(operation="update_item").inc()
        
        logger.info(f"Updated item {product_id} in cart {cart_id}")
        return cart

@app.delete("/carts/{cart_id}/items/{product_id}", response_model=Cart)
async def remove_item_from_cart(
    cart_id: str, 
    product_id: int,
    redis_conn: redis.Redis = Depends(get_redis)
):
    """Remove item from cart"""
    REQUEST_COUNT.labels(method="DELETE", endpoint="cart_item").inc()
    
    with REQUEST_DURATION.time():
        # Get cart
        cart_key = await get_cart_key(cart_id)
        cart_json = await redis_conn.get(cart_key)
        CACHE_OPERATIONS.labels(operation="get").inc()
        
        if not cart_json:
            raise HTTPException(status_code=404, detail="Cart not found")
        
        cart = await deserialize_cart(cart_json)
        
        # Remove item
        cart.items = [item for item in cart.items if item.product_id != product_id]
        
        # Recalculate totals
        cart.total_items = sum(item.quantity for item in cart.items)
        cart.total_amount = sum(item.price * item.quantity for item in cart.items)
        cart.updated_at = datetime.utcnow()
        
        # Save cart
        await redis_conn.setex(cart_key, 86400, await serialize_cart(cart))
        CACHE_OPERATIONS.labels(operation="set").inc()
        CART_OPERATIONS.labels(operation="remove_item").inc()
        
        logger.info(f"Removed item {product_id} from cart {cart_id}")
        return cart

@app.delete("/carts/{cart_id}")
async def clear_cart(cart_id: str, redis_conn: redis.Redis = Depends(get_redis)):
    """Clear/delete a cart"""
    REQUEST_COUNT.labels(method="DELETE", endpoint="cart").inc()
    
    with REQUEST_DURATION.time():
        cart_key = await get_cart_key(cart_id)
        result = await redis_conn.delete(cart_key)
        CACHE_OPERATIONS.labels(operation="delete").inc()
        
        if result == 0:
            raise HTTPException(status_code=404, detail="Cart not found")
        
        CART_OPERATIONS.labels(operation="clear").inc()
        logger.info(f"Cleared cart {cart_id}")
        return {"message": "Cart cleared successfully"}

@app.get("/carts/{cart_id}/summary", response_model=CartSummary)
async def get_cart_summary(cart_id: str, redis_conn: redis.Redis = Depends(get_redis)):
    """Get cart summary"""
    REQUEST_COUNT.labels(method="GET", endpoint="cart_summary").inc()
    
    with REQUEST_DURATION.time():
        cart_key = await get_cart_key(cart_id)
        cart_json = await redis_conn.get(cart_key)
        CACHE_OPERATIONS.labels(operation="get").inc()
        
        if not cart_json:
            raise HTTPException(status_code=404, detail="Cart not found")
        
        cart = await deserialize_cart(cart_json)
        
        return CartSummary(
            cart_id=cart_id,
            total_items=cart.total_items,
            total_amount=cart.total_amount,
            item_count=len(cart.items)
        )

# Statistics endpoint for monitoring
@app.get("/stats")
async def get_stats(redis_conn: redis.Redis = Depends(get_redis)):
    """Get cart statistics"""
    try:
        # Get all cart keys
        cart_keys = await redis_conn.keys("cart:*")
        total_carts = len(cart_keys)
        
        # Sample some carts for statistics
        active_carts = 0
        total_items = 0
        sample_size = min(100, total_carts)  # Sample up to 100 carts
        
        if cart_keys:
            sample_keys = cart_keys[:sample_size]
            for key in sample_keys:
                cart_json = await redis_conn.get(key)
                if cart_json:
                    cart = await deserialize_cart(cart_json)
                    if datetime.utcnow() <= cart.expires_at:
                        active_carts += 1
                        total_items += cart.total_items
        
        return {
            "total_carts": total_carts,
            "active_carts": active_carts,
            "average_items_per_cart": total_items / max(active_carts, 1),
            "sample_size": sample_size
        }
    except Exception as e:
        logger.error("Failed to get stats", error=str(e))
        return {"error": "Failed to retrieve statistics"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8080)