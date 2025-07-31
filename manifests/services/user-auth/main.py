#!/usr/bin/env python3
"""
User Authentication API Service
JWT-based authentication service for Ocean Surge
"""

import asyncio
import os
import json
from datetime import datetime, timedelta
from typing import Optional
from contextlib import asynccontextmanager

import asyncpg
import redis.asyncio as redis
import structlog
from fastapi import FastAPI, HTTPException, Depends, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel, EmailStr, Field
from passlib.context import CryptContext
from jose import JWTError, jwt
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
from fastapi.responses import Response

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

# Configuration
SECRET_KEY = os.getenv("JWT_SECRET_KEY", "oceansurge-jwt-secret-key-change-in-production")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 30

# Password hashing
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# HTTP Bearer for JWT
security = HTTPBearer()

# Database and Redis connections
db_pool = None
redis_client = None

# Prometheus metrics
REQUEST_COUNT = Counter('user_auth_requests_total', 'Total requests', ['method', 'endpoint'])
REQUEST_DURATION = Histogram('user_auth_request_duration_seconds', 'Request duration')
AUTH_OPERATIONS = Counter('user_auth_operations_total', 'Auth operations', ['operation'])

# Pydantic models
class UserCreate(BaseModel):
    email: EmailStr
    password: str = Field(..., min_length=8)
    first_name: str = Field(..., min_length=1, max_length=50)
    last_name: str = Field(..., min_length=1, max_length=50)

class UserLogin(BaseModel):
    email: EmailStr
    password: str

class User(BaseModel):
    id: int
    email: str
    first_name: str
    last_name: str
    is_active: bool
    created_at: datetime

class Token(BaseModel):
    access_token: str
    token_type: str
    expires_in: int

class TokenData(BaseModel):
    email: Optional[str] = None

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Manage application lifecycle"""
    logger.info("Starting User Auth API")
    await init_database()
    await init_redis()
    await create_tables()
    yield
    logger.info("Shutting down User Auth API")
    if db_pool:
        await db_pool.close()
    if redis_client:
        await redis_client.close()

app = FastAPI(
    title="User Authentication API",
    description="JWT-based authentication service",
    version="1.0.0",
    lifespan=lifespan
)

async def init_database():
    """Initialize PostgreSQL connection pool"""
    global db_pool
    try:
        db_pool = await asyncpg.create_pool(
            host=os.getenv('POSTGRES_HOST', 'postgresql'),
            port=int(os.getenv('POSTGRES_PORT', 5432)),
            user=os.getenv('POSTGRES_USER', 'oceansurge'),
            password=os.getenv('POSTGRES_PASSWORD', 'Postgres123'),
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
            f"redis://{os.getenv('REDIS_HOST', 'redis')}:{os.getenv('REDIS_PORT', 6379)}/2"
        )
        await redis_client.ping()
        logger.info("Redis connection established")
    except Exception as e:
        logger.error("Failed to connect to Redis", error=str(e))
        raise

async def create_tables():
    """Create database tables if they don't exist"""
    create_table_sql = """
    CREATE TABLE IF NOT EXISTS users (
        id SERIAL PRIMARY KEY,
        email VARCHAR(255) UNIQUE NOT NULL,
        hashed_password VARCHAR(255) NOT NULL,
        first_name VARCHAR(50) NOT NULL,
        last_name VARCHAR(50) NOT NULL,
        is_active BOOLEAN DEFAULT TRUE,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
    
    CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
    """
    
    async with db_pool.acquire() as conn:
        await conn.execute(create_table_sql)
        logger.info("Database tables created/verified")

def verify_password(plain_password, hashed_password):
    """Verify a password against its hash"""
    return pwd_context.verify(plain_password, hashed_password)

def get_password_hash(password):
    """Generate password hash"""
    return pwd_context.hash(password)

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None):
    """Create JWT access token"""
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=15)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

async def get_user_by_email(email: str):
    """Get user by email from database"""
    sql = "SELECT id, email, hashed_password, first_name, last_name, is_active, created_at FROM users WHERE email = $1"
    async with db_pool.acquire() as conn:
        row = await conn.fetchrow(sql, email)
        return dict(row) if row else None

async def authenticate_user(email: str, password: str):
    """Authenticate user credentials"""
    user = await get_user_by_email(email)
    if not user:
        return False
    if not verify_password(password, user["hashed_password"]):
        return False
    return user

async def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security)):
    """Get current user from JWT token"""
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    
    try:
        token = credentials.credentials
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        email: str = payload.get("sub")
        if email is None:
            raise credentials_exception
        token_data = TokenData(email=email)
    except JWTError:
        raise credentials_exception
    
    # Check if token is blacklisted
    blacklisted = await redis_client.get(f"blacklist:{token}")
    if blacklisted:
        raise credentials_exception
    
    user = await get_user_by_email(email=token_data.email)
    if user is None:
        raise credentials_exception
    return user

async def get_current_active_user(current_user: dict = Depends(get_current_user)):
    """Get current active user"""
    if not current_user["is_active"]:
        raise HTTPException(status_code=400, detail="Inactive user")
    return current_user

# Health check endpoint
@app.get("/health")
async def health_check():
    """Health check endpoint"""
    try:
        async with db_pool.acquire() as conn:
            await conn.fetchval("SELECT 1")
        await redis_client.ping()
        return {"status": "healthy", "service": "user-auth"}
    except Exception as e:
        logger.error("Health check failed", error=str(e))
        raise HTTPException(status_code=503, detail="Service unhealthy")

# Metrics endpoint
@app.get("/metrics")
async def metrics():
    """Prometheus metrics endpoint"""
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)

# Authentication endpoints
@app.post("/register", response_model=User, status_code=201)
async def register_user(user: UserCreate):
    """Register a new user"""
    REQUEST_COUNT.labels(method="POST", endpoint="register").inc()
    
    with REQUEST_DURATION.time():
        # Check if user already exists
        existing_user = await get_user_by_email(user.email)
        if existing_user:
            raise HTTPException(
                status_code=400,
                detail="Email already registered"
            )
        
        # Hash password
        hashed_password = get_password_hash(user.password)
        
        # Insert user
        sql = """
        INSERT INTO users (email, hashed_password, first_name, last_name)
        VALUES ($1, $2, $3, $4)
        RETURNING id, email, first_name, last_name, is_active, created_at
        """
        
        async with db_pool.acquire() as conn:
            row = await conn.fetchrow(
                sql, user.email, hashed_password, 
                user.first_name, user.last_name
            )
            
        AUTH_OPERATIONS.labels(operation="register").inc()
        logger.info(f"User registered: {user.email}")
        return User(**dict(row))

@app.post("/login", response_model=Token)
async def login_user(form_data: UserLogin):
    """Login user and return JWT token"""
    REQUEST_COUNT.labels(method="POST", endpoint="login").inc()
    
    with REQUEST_DURATION.time():
        user = await authenticate_user(form_data.email, form_data.password)
        if not user:
            AUTH_OPERATIONS.labels(operation="login_failed").inc()
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Incorrect email or password",
                headers={"WWW-Authenticate": "Bearer"},
            )
        
        access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
        access_token = create_access_token(
            data={"sub": user["email"]}, expires_delta=access_token_expires
        )
        
        # Store token info in Redis for tracking
        token_info = {
            "user_id": user["id"],
            "email": user["email"],
            "created_at": datetime.utcnow().isoformat()
        }
        await redis_client.setex(
            f"token:{access_token}", 
            ACCESS_TOKEN_EXPIRE_MINUTES * 60, 
            json.dumps(token_info)
        )
        
        AUTH_OPERATIONS.labels(operation="login_success").inc()
        logger.info(f"User logged in: {user['email']}")
        
        return {
            "access_token": access_token,
            "token_type": "bearer",
            "expires_in": ACCESS_TOKEN_EXPIRE_MINUTES * 60
        }

@app.post("/logout")
async def logout_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    current_user: dict = Depends(get_current_active_user)
):
    """Logout user by blacklisting token"""
    REQUEST_COUNT.labels(method="POST", endpoint="logout").inc()
    
    with REQUEST_DURATION.time():
        token = credentials.credentials
        
        # Get token expiration from JWT
        try:
            payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
            exp = payload.get("exp")
            if exp:
                # Blacklist token until it expires
                ttl = max(0, exp - int(datetime.utcnow().timestamp()))
                await redis_client.setex(f"blacklist:{token}", ttl, "true")
        except JWTError:
            pass  # Token is invalid anyway
        
        # Remove token info
        await redis_client.delete(f"token:{token}")
        
        AUTH_OPERATIONS.labels(operation="logout").inc()
        logger.info(f"User logged out: {current_user['email']}")
        
        return {"message": "Successfully logged out"}

@app.get("/me", response_model=User)
async def read_users_me(current_user: dict = Depends(get_current_active_user)):
    """Get current user profile"""
    REQUEST_COUNT.labels(method="GET", endpoint="me").inc()
    
    return User(**current_user)

@app.get("/verify")
async def verify_token(current_user: dict = Depends(get_current_active_user)):
    """Verify if token is valid"""
    REQUEST_COUNT.labels(method="GET", endpoint="verify").inc()
    
    return {
        "valid": True,
        "user_id": current_user["id"],
        "email": current_user["email"]
    }

# Admin endpoints
@app.get("/users/{user_id}", response_model=User)
async def get_user_by_id(
    user_id: int, 
    current_user: dict = Depends(get_current_active_user)
):
    """Get user by ID (admin or self only)"""
    REQUEST_COUNT.labels(method="GET", endpoint="user").inc()
    
    # For now, users can only access their own profile
    if current_user["id"] != user_id:
        raise HTTPException(
            status_code=403,
            detail="Not enough permissions"
        )
    
    sql = "SELECT id, email, first_name, last_name, is_active, created_at FROM users WHERE id = $1"
    async with db_pool.acquire() as conn:
        row = await conn.fetchrow(sql, user_id)
        
    if not row:
        raise HTTPException(status_code=404, detail="User not found")
    
    return User(**dict(row))

# Statistics endpoint
@app.get("/stats")
async def get_auth_stats():
    """Get authentication statistics"""
    try:
        # Get total registered users
        async with db_pool.acquire() as conn:
            total_users = await conn.fetchval("SELECT COUNT(*) FROM users")
            active_users = await conn.fetchval("SELECT COUNT(*) FROM users WHERE is_active = true")
        
        # Get active sessions (rough estimate based on Redis tokens)
        token_keys = await redis_client.keys("token:*")
        active_sessions = len(token_keys)
        
        return {
            "total_users": total_users,
            "active_users": active_users,
            "active_sessions": active_sessions
        }
    except Exception as e:
        logger.error("Failed to get auth stats", error=str(e))
        return {"error": "Failed to retrieve statistics"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8080)