# Ocean Surge - Development Environment

This is the **development branch** of Ocean Surge with realistic production workload components.

## 🏗️ Architecture Overview

### Core Services
- **Frontend**: Enhanced nginx proxy routing to microservices
- **Product Catalog API**: FastAPI service with PostgreSQL backend
- **Shopping Cart API**: FastAPI service with Redis persistence  
- **User Authentication API**: JWT-based auth service
- **Feature Flag Middleware**: LaunchDarkly integration (existing)

### Infrastructure Components
- **PostgreSQL**: Primary database for persistent data
- **Redis**: Caching and session storage
- **RabbitMQ**: Message queue for async processing
- **Prometheus**: Metrics collection and monitoring
- **Grafana**: Visualization and dashboards

### Load Testing
- **K6**: Realistic load testing scenarios

## 🚀 Deployment

### Prerequisites
- Kubernetes cluster (EKS/GKE/AKS)
- kubectl configured
- Container images built and pushed to registry

### Deploy Full Stack
```bash
# Deploy databases first
kubectl apply -k manifests/databases/

# Wait for databases to be ready
kubectl wait --for=condition=ready pod -l app=postgresql -n oceansurge --timeout=300s
kubectl wait --for=condition=ready pod -l app=redis -n oceansurge --timeout=300s

# Deploy services
kubectl apply -k manifests/dev/

# Deploy monitoring
kubectl apply -k manifests/monitoring/

# Deploy messaging
kubectl apply -k manifests/messaging/

# Run load tests (optional)
kubectl apply -k manifests/load-testing/
```

### Build Container Images
```bash
# Product Catalog API
cd manifests/services/product-catalog/
docker build -t oceansurge/product-catalog-api:dev .

# Shopping Cart API  
cd ../shopping-cart/
docker build -t oceansurge/shopping-cart-api:dev .

# User Auth API
cd ../user-auth/
docker build -t oceansurge/user-auth-api:dev .
```

## 📊 Monitoring & Observability

### Prometheus Metrics
- Application metrics: Request rates, latencies, errors
- Infrastructure metrics: CPU, memory, disk usage
- Business metrics: Active carts, user registrations

### Grafana Dashboards
- **Ocean Surge Overview**: Application performance dashboard
- Access: `http://<grafana-loadbalancer>/` (admin/admin123)

### Service Endpoints
- **Frontend**: `http://<frontend-loadbalancer>/`
- **Product API**: `http://<frontend-loadbalancer>/api/products`
- **Cart API**: `http://<frontend-loadbalancer>/api/carts`  
- **Auth API**: `http://<frontend-loadbalancer>/api/auth`
- **RabbitMQ Management**: `http://<rabbitmq-loadbalancer>/`

## 🧪 API Examples

### User Registration & Authentication
```bash
# Register user
curl -X POST http://<frontend>/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@example.com",
    "password": "SecurePass123",
    "first_name": "John",
    "last_name": "Doe"
  }'

# Login
curl -X POST http://<frontend>/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@example.com", 
    "password": "SecurePass123"
  }'
```

### Product Catalog
```bash
# Get products
curl http://<frontend>/api/products

# Get specific product
curl http://<frontend>/api/products/1

# Search by category
curl "http://<frontend>/api/products?category=Brakes&limit=10"
```

### Shopping Cart
```bash
# Create cart
curl -X POST http://<frontend>/api/carts \
  -H "Authorization: Bearer <token>"

# Add item to cart
curl -X POST http://<frontend>/api/carts/<cart_id>/items \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{"product_id": 1, "quantity": 2}'

# Get cart
curl http://<frontend>/api/carts/<cart_id> \
  -H "Authorization: Bearer <token>"
```

## 🔧 Configuration

### Environment Variables
Each service supports configuration via environment variables:

- **Database**: `POSTGRES_HOST`, `POSTGRES_USER`, `POSTGRES_PASSWORD`
- **Cache**: `REDIS_HOST`, `REDIS_PORT`
- **Auth**: `JWT_SECRET_KEY`
- **Logging**: `LOG_LEVEL`

### Secrets Management
Sensitive data is stored in Kubernetes secrets:
- Database credentials
- JWT signing keys
- Service-to-service authentication

## 🧪 Load Testing

The K6 load test simulates realistic user workflows:
1. User registration and authentication
2. Product browsing and search
3. Shopping cart operations
4. Concurrent user sessions

Run load test:
```bash
kubectl apply -f manifests/load-testing/k6-load-test.yaml
kubectl logs -f job/k6-load-test -n oceansurge
```

## 📈 Scaling

Services are configured with:
- **HPA**: Horizontal Pod Autoscaling based on CPU/memory
- **Resource Limits**: Proper resource requests and limits
- **Readiness/Liveness Probes**: Health checking
- **Multiple Replicas**: High availability

## 🔒 Security Features

- **Non-root containers**: All services run as non-root users
- **Network policies**: Pod-to-pod communication restrictions
- **RBAC**: Proper service account permissions
- **Secrets**: Encrypted credential storage
- **JWT Authentication**: Stateless user authentication

## 🐛 Troubleshooting

### Check service health
```bash
# Check all pods
kubectl get pods -n oceansurge

# Check specific service logs
kubectl logs -f deployment/product-catalog-api -n oceansurge

# Check database connectivity
kubectl exec -it deployment/postgresql -n oceansurge -- psql -U oceansurge -d oceansurge -c "SELECT version();"
```

### Common Issues
1. **Database connection errors**: Ensure PostgreSQL is ready before starting services
2. **Redis connection errors**: Check Redis pod status and network connectivity
3. **Image pull errors**: Verify container images are built and accessible
4. **Service discovery**: Ensure Kubernetes DNS is working properly

This development environment provides a realistic production-like workload for testing, monitoring, and scaling Ocean Surge applications.