# Storm Surge Workload and Container Comparison

This document provides a detailed analysis of workload specifications, container definitions, and integration differences across all Storm Surge branches.

## Container Image Matrix

| Component | Main | Dev | Beta | Core |
|-----------|------|-----|------|------|
| **Frontend** | `nginxinc/nginx-unprivileged:alpine` | `nginx:alpine` | `nginxinc/nginx-unprivileged:alpine` | ❌ None |
| **Product Catalog** | `nginxinc/nginx-unprivileged:alpine` | `oceansurge/product-catalog-api:dev` | `nginxinc/nginx-unprivileged:alpine` | ❌ None |
| **Shopping Cart** | `nginxinc/nginx-unprivileged:alpine` | `oceansurge/shopping-cart-api:dev` | `nginxinc/nginx-unprivileged:alpine` | ❌ None |
| **Middleware** | `python:3.11-slim` | `python:3.11-slim` | `python:3.11-slim` | `python:3.11-slim` |
| **FinOps Controller** | `python:3.11-slim` | `python:3.11-slim` | `python:3.11-slim` | ❌ None |
| **PostgreSQL** | `postgres:14-alpine` | `postgres:15-alpine` | `postgres:14-alpine` | `postgres:14-alpine` |
| **Redis** | `redis:7-alpine` | `redis:7-alpine` | `redis:7-alpine` | `redis:7-alpine` |
| **Jaeger** | ❌ None | ❌ None | `jaegertracing/all-in-one:1.53` | ❌ None |
| **OpenTelemetry** | ❌ None | ❌ None | `otel/opentelemetry-collector-contrib:0.91.0` | ❌ None |
| **Prometheus** | ❌ None | ❌ None | `prom/prometheus:v2.48.1` | ❌ None |
| **Grafana** | ❌ None | `grafana/grafana:10.2.0` | ❌ None | ❌ None |
| **RabbitMQ** | ❌ None | `rabbitmq:3.12-management-alpine` | ❌ None | ❌ None |
| **K6 Load Testing** | ❌ None | `grafana/k6:0.47.0` | ❌ None | ❌ None |
| **User Auth Service** | ❌ None | `oceansurge/user-auth-api:dev` | ❌ None | ❌ None |

## Workload Type Distribution

### Main Branch (7 Workloads)
- **Deployments**: 4 (frontend, product-catalog, shopping-cart, middleware)
- **StatefulSets**: 2 (postgresql, redis)
- **CronJobs**: 1 (postgresql-backup)

### Dev Branch (15+ Workloads)
- **Deployments**: 12+ (all main + user-auth, grafana, k6-testing, monitoring, security)
- **StatefulSets**: 2 (postgresql, redis)
- **CronJobs**: 1 (postgresql-backup)
- **Jobs**: 2+ (load-testing, validation)

### Beta Branch (10 Workloads)
- **Deployments**: 7 (all main + jaeger, otelcol, prometheus)
- **StatefulSets**: 2 (postgresql, redis)
- **CronJobs**: 1 (postgresql-backup)

### Core Branch (1 Workload)
- **Deployments**: 1 (minimal middleware only)
- **StatefulSets**: 0
- **CronJobs**: 0

## Container Security Contexts

| Security Setting | Main | Dev | Beta | Core |
|-----------------|------|-----|------|------|
| **runAsNonRoot** | ✅ true | ✅ true | ✅ true | ✅ true |
| **runAsUser** | 101/1000 | 101/1000/999 | 101/1000/999 | 1000 |
| **fsGroup** | ✅ Set | ✅ Set | ✅ Set | ✅ Set |
| **allowPrivilegeEscalation** | ✅ false | ✅ false | ✅ false | ❌ Not set |
| **capabilities.drop** | ✅ ALL | ✅ ALL | ✅ ALL | ❌ Not set |
| **readOnlyRootFilesystem** | ❌ false | ❌ false | ❌ false | ❌ Not set |

## Resource Allocation by Branch

### Main Branch
```yaml
# Standard resource configuration
requests:
  cpu: 100m      # All services start with 100m
  memory: 128Mi  # Base memory allocation
limits:
  cpu: 200-500m  # Conservative scaling
  memory: 256Mi-1Gi
```

### Dev Branch  
```yaml
# Enhanced resource configuration
requests:
  cpu: 100-250m  # Higher baseline for complex services
  memory: 128-512Mi
limits:
  cpu: 500m-2000m  # Enterprise-scale limits
  memory: 512Mi-4Gi
```

### Beta Branch
```yaml
# Observability-optimized resources
requests:
  cpu: 100m      # Consistent baseline
  memory: 128-256Mi  # Optimized for telemetry
limits:
  cpu: 500-1000m # Balanced for monitoring
  memory: 512Mi-2Gi
```

### Core Branch
```yaml
# Minimal resource configuration
requests:
  cpu: 100m      # Single service only
  memory: 128Mi
limits:
  cpu: 500m      # Basic scaling
  memory: 256Mi
```

## Integration Analysis by Branch

### 🌟 Main Branch Integrations
**External Dependencies**:
- ✅ **LaunchDarkly SDK**: Feature flag management
- ✅ **Spot Ocean API**: Cluster scaling automation
- ❌ **Authentication**: None
- ❌ **Observability**: Basic health checks only
- ❌ **Messaging**: None

**Container Communication**:
- Frontend → Product Catalog (HTTP)
- Frontend → Shopping Cart (HTTP)
- All services → PostgreSQL (TCP 5432)
- Rate limiting → Redis (TCP 6379)

### 🔥 Dev Branch Integrations
**External Dependencies**:
- ✅ **LaunchDarkly SDK**: Enterprise feature flag management
- ✅ **Spot Ocean API**: Advanced cluster scaling with policies
- ✅ **Grafana Cloud**: Metrics and dashboards
- ✅ **K6 Cloud**: Load testing and performance monitoring
- ✅ **Cloud Provider APIs**: Multi-cloud infrastructure automation
- ✅ **RabbitMQ**: Asynchronous messaging and event processing

**Container Communication**:
- All main branch communication PLUS:
- User Auth Service ↔ PostgreSQL (authentication data)
- RabbitMQ → All services (event messaging)
- Grafana → Prometheus (metrics collection)
- K6 → All services (load testing)
- Monitoring stack → All services (health monitoring)

### 🧪 Beta Branch Integrations
**External Dependencies**:
- ✅ **LaunchDarkly/Statsig SDK**: Dual provider support
- ✅ **Spot Ocean API**: Standard cluster scaling
- ✅ **Jaeger**: Distributed tracing backend
- ✅ **OpenTelemetry**: Telemetry collection and processing
- ✅ **Prometheus**: Metrics storage and alerting

**Container Communication**:
- All main branch communication PLUS:
- Frontend → OpenTelemetry Collector (OTLP HTTP :4318)
- Middleware → OpenTelemetry Collector (OTLP gRPC :4317)
- OpenTelemetry Collector → Jaeger (:14250)
- OpenTelemetry Collector → Prometheus (:8889)
- Prometheus → All services (metrics scraping)

### ⚙️ Core Branch Integrations
**External Dependencies**:
- ❌ **No external integrations**
- ❌ **No feature flag providers**
- ❌ **No scaling automation**
- ❌ **No observability stack**

**Container Communication**:
- Single middleware service only
- Basic health check endpoints
- No inter-service communication

## Persistent Storage Comparison

| Storage Component | Main | Dev | Beta | Core |
|------------------|------|-----|------|------|
| **PostgreSQL PVC** | 20Gi SSD | 20Gi SSD + backup | 20Gi SSD | ❌ None |
| **Redis PVC** | 10Gi SSD | 10Gi SSD | 10Gi SSD | ❌ None |
| **Backup Storage** | 50Gi (CronJob) | 50Gi + retention | 50Gi (CronJob) | ❌ None |
| **StorageClass** | `storm-surge-ssd` | `storm-surge-ssd` | `storm-surge-ssd` | ❌ None |
| **Volume Expansion** | ✅ Enabled | ✅ Enabled | ✅ Enabled | ❌ None |

## Health Check Configuration

### Probe Timing Matrix
| Component | Branch | Readiness | Liveness | Startup |
|-----------|--------|-----------|----------|---------|
| **Frontend** | Main | 5s/5s/3s | 30s/10s/5s | 10s/5s/3s |
| **Product Catalog** | Main | 5s/5s/3s | 30s/10s/5s | 10s/5s/3s |
| **Shopping Cart** | Main | 5s/5s/3s | 30s/10s/5s | 15s/5s/3s |
| **Middleware** | All | 10s/5s/3s | 30s/10s/5s | 15s/5s/3s |
| **PostgreSQL** | All | 5s/5s | 30s/10s | N/A |
| **Redis** | All | 5s/5s | 30s/10s | N/A |
| **Jaeger** | Beta | 5s/10s | 30s/30s | N/A |
| **OpenTelemetry** | Beta | 15s/10s | 60s/30s | N/A |

*Format: initialDelay/period/timeout*

## Port Configuration

### Service Ports by Branch
| Service | Main | Dev | Beta | Core |
|---------|------|-----|------|------|
| **Frontend** | 8080 | 8080 | 8080 | ❌ |
| **Product Catalog** | 8080 | 8080 | 8080 | ❌ |
| **Shopping Cart** | 8080 | 8080 | 8080 | ❌ |
| **Middleware** | 8000 | 8000 | 8000 | 8000 |
| **PostgreSQL** | 5432 | 5432 | 5432 | 5432* |
| **Redis** | 6379 | 6379 | 6379 | 6379* |
| **Jaeger UI** | ❌ | ❌ | 16686 | ❌ |
| **Jaeger Collector** | ❌ | ❌ | 14250/14268 | ❌ |
| **OpenTelemetry** | ❌ | ❌ | 4317/4318 | ❌ |
| **Prometheus** | ❌ | ❌ | 9090 | ❌ |
| **RabbitMQ** | ❌ | 5672/15672 | ❌ | ❌ |
| **Grafana** | ❌ | 3000 | ❌ | ❌ |

*Core: Database ports exist but databases not deployed by default

## Environment Variables by Component

### Middleware Service (All Branches)
**Common Variables**:
```yaml
- NAMESPACE: metadata.namespace
- NODE_NAME: spec.nodeName  
- PYTHONUNBUFFERED: "1"
- ENVIRONMENT: "production"
- LOG_LEVEL: "INFO"
```

**Branch-Specific Variables**:

#### Main Branch
```yaml
- FEATURE_FLAG_PROVIDER: configMap
- LAUNCHDARKLY_SDK_KEY: secret
- SPOT_API_TOKEN: secret
- SPOT_CLUSTER_ID: configMap
- WEBHOOK_SECRET: secret
```

#### Dev Branch (Additional)
```yaml
- RABBITMQ_HOST: configMap
- GRAFANA_API_KEY: secret
- CLOUD_PROVIDER: configMap
- INFRASTRUCTURE_MODE: "multi-cloud"
- SECURITY_LEVEL: "enterprise"
```

#### Beta Branch (Additional)
```yaml
- OTEL_EXPORTER_OTLP_ENDPOINT: "http://otelcol:4317"
- OTEL_ENABLE_PROMETHEUS: "true"
- JAEGER_ENDPOINT: "http://jaeger-collector:14250"
- METRICS_ENABLED: "true"
```

#### Core Branch (Minimal)
```yaml
- CLUSTER_NAME: "storm-surge-prod"
- FLASK_SECRET_KEY: secret
```

## Database Workload Analysis

### PostgreSQL Configuration
| Setting | Main | Dev | Beta | Core |
|---------|------|-----|------|------|
| **Version** | postgres:14-alpine | postgres:15-alpine | postgres:14-alpine | postgres:14-alpine |
| **Workload Type** | StatefulSet | StatefulSet | StatefulSet | ❌ None |
| **Replicas** | 1 | 1 | 1 | ❌ |
| **Storage** | 20Gi PVC | 20Gi PVC | 20Gi PVC | ❌ |
| **Memory Request** | 512Mi | 512Mi | 512Mi | ❌ |
| **Memory Limit** | 2Gi | 2Gi | 2Gi | ❌ |
| **CPU Request** | 250m | 250m | 250m | ❌ |
| **CPU Limit** | 1000m | 1000m | 1000m | ❌ |
| **Backup Strategy** | CronJob (daily) | CronJob + retention | CronJob (daily) | ❌ |

### Redis Configuration
| Setting | Main | Dev | Beta | Core |
|---------|------|-----|------|------|
| **Version** | redis:7-alpine | redis:7-alpine | redis:7-alpine | redis:7-alpine |
| **Workload Type** | StatefulSet | StatefulSet | StatefulSet | ❌ None |
| **Authentication** | ✅ Password | ✅ Password | ✅ Password | ❌ |
| **Persistence** | ✅ 10Gi PVC | ✅ 10Gi PVC | ✅ 10Gi PVC | ❌ |
| **Memory Request** | 128Mi | 128Mi | 128Mi | ❌ |
| **Memory Limit** | 512Mi | 512Mi | 512Mi | ❌ |
| **Configuration** | ConfigMap | ConfigMap | ConfigMap | ❌ |

## Observability Stack Comparison

### Beta Branch (Full Stack)
```yaml
# OpenTelemetry Collector
image: otel/opentelemetry-collector-contrib:0.91.0
resources:
  requests: { memory: 256Mi, cpu: 100m }
  limits: { memory: 512Mi, cpu: 500m }
ports: [4317, 4318, 8889, 13133, 55679]

# Jaeger
image: jaegertracing/all-in-one:1.53  
resources:
  requests: { memory: 256Mi, cpu: 100m }
  limits: { memory: 512Mi, cpu: 500m }
ports: [16686, 14250, 14268, 14269]

# Prometheus
image: prom/prometheus:v2.48.1
resources:
  requests: { memory: 512Mi, cpu: 200m }
  limits: { memory: 1Gi, cpu: 1000m }
ports: [9090]
```

### Dev Branch (Monitoring)
```yaml
# Grafana
image: grafana/grafana:10.2.0
resources:
  requests: { memory: 256Mi, cpu: 100m }
  limits: { memory: 512Mi, cpu: 500m }
ports: [3000]

# Prometheus
image: prom/prometheus:v2.47.0
resources:
  requests: { memory: 512Mi, cpu: 200m }
  limits: { memory: 1Gi, cpu: 1000m }
```

### Main/Core Branches
- **No observability stack**
- **Basic health checks only**
- **No distributed tracing**
- **No metrics collection**

## Application Service Communication

### Main Branch Network Flow
```
Frontend (8080) → nginx → Product Catalog (8080)
                        → Shopping Cart (8080)
                        
Middleware (8000) → PostgreSQL (5432)
                  → Redis (6379)
                  → LaunchDarkly API (HTTPS)
                  → Spot Ocean API (HTTPS)
```

### Dev Branch Network Flow (Additional)
```
User Auth (8080) → PostgreSQL (5432)
RabbitMQ (5672) → All services
Grafana (3000) → Prometheus (9090) → All services
K6 (random) → All services (load testing)
```

### Beta Branch Network Flow (Additional)
```
Frontend → OpenTelemetry (4318/HTTP)
Middleware → OpenTelemetry (4317/gRPC)
OpenTelemetry → Jaeger (14250)
                → Prometheus (8889)
Prometheus → All services (scraping)
```

### Core Branch Network Flow
```
Middleware (8000) → Health checks only
```

## Scaling Configuration

### Horizontal Pod Autoscaler (HPA)
| Component | Main | Dev | Beta | Core |
|-----------|------|-----|------|------|
| **Shopping Cart** | CPU 70% (1-10 pods) | CPU 70% (1-20 pods) | CPU 70% (1-10 pods) | ❌ |
| **Product Catalog** | CPU 80% (2-8 pods) | CPU 80% (2-15 pods) | CPU 80% (2-8 pods) | ❌ |
| **Frontend** | CPU 60% (2-6 pods) | CPU 60% (2-12 pods) | CPU 60% (2-6 pods) | ❌ |
| **Middleware** | CPU 75% (1-5 pods) | CPU 75% (1-10 pods) | CPU 75% (1-5 pods) | Manual (2) |

### Vertical Pod Autoscaler (VPA)
- **Main**: ❌ Not configured
- **Dev**: ✅ Enabled for all services with update mode
- **Beta**: ❌ Not configured  
- **Core**: ❌ Not configured

## initContainer Usage

### Main Branch
- **No initContainers**

### Dev Branch  
```yaml
# RabbitMQ Init
- name: rabbitmq-init
  image: rabbitmq:3.12-management-alpine
  # Sets up exchanges and queues

# Database Init  
- name: db-migration
  image: postgres:15-alpine
  # Runs database migrations
```

### Beta Branch
```yaml
# Middleware Init
- name: setup-python-env
  image: python:3.11-slim
  # Installs Python dependencies
```

### Core Branch
- **No initContainers**

## Volume Configuration

### Main Branch
```yaml
# ConfigMap volumes for static content
- nginx-config (configMap)
- html-content (configMap)
- app-code (configMap)

# Persistent volumes for data
- postgresql-storage (PVC 20Gi)
- redis-storage (PVC 10Gi)
- backup-storage (PVC 50Gi)

# Temporary volumes
- nginx-cache (emptyDir)
- nginx-run (emptyDir)
```

### Dev Branch (Additional)
```yaml
# Monitoring volumes
- grafana-storage (PVC 10Gi)
- prometheus-data (PVC 50Gi)

# RabbitMQ volumes  
- rabbitmq-data (PVC 20Gi)

# TLS certificates
- tls-certs (secret)
```

### Beta Branch (Additional)
```yaml
# Observability volumes
- jaeger-storage (emptyDir - memory mode)
- otelcol-config (configMap)
- prometheus-config (configMap)

# Telemetry processing
- shared-deps (emptyDir)
```

### Core Branch
```yaml
# Minimal volumes only
- app-code (configMap)
```

## Service Account Configuration

### RBAC Service Accounts by Branch
| Account | Main | Dev | Beta | Core |
|---------|------|-----|------|------|
| **default** | Basic permissions | Basic permissions | Basic permissions | Basic permissions |
| **middleware-sa** | API access | Enhanced API access | Enhanced API access | ❌ |
| **database-sa** | DB access | DB access | DB access | ❌ |
| **monitoring-sa** | ❌ | Metrics access | Metrics access | ❌ |
| **observability-sa** | ❌ | ❌ | Full telemetry access | ❌ |

## Feature Flag Integration

### LaunchDarkly Integration
| Branch | SDK Version | Features | Webhooks |
|--------|-------------|----------|----------|
| **Main** | 8.2.1 | Basic flags | ✅ `/webhook/launchdarkly` |
| **Dev** | 8.3.0+ | Enterprise features | ✅ Enhanced validation |
| **Beta** | 8.2.1 | Dual provider support | ✅ `/webhook/launchdarkly` + `/webhook/statsig` |
| **Core** | ❌ None | ❌ | ❌ |

### Spot Ocean Integration  
| Branch | API Features | Scaling Policies | Node Management |
|--------|-------------|------------------|-----------------|
| **Main** | Basic scaling | Standard | Manual |
| **Dev** | Advanced policies | Automated + custom | Intelligent provisioning |
| **Beta** | Standard scaling | Standard | Manual |
| **Core** | ❌ None | ❌ | ❌ |

## Deployment Complexity Score

| Branch | Workloads | Containers | PVCs | Secrets | ConfigMaps | Services | Score |
|--------|-----------|-----------|------|---------|-----------|----------|-------|
| **Main** | 7 | 9 | 4 | 6 | 12 | 8 | **Medium** (46 objects) |
| **Dev** | 15+ | 25+ | 8+ | 15+ | 25+ | 20+ | **High** (108+ objects) |
| **Beta** | 10 | 15 | 4 | 8 | 15 | 12 | **Medium-High** (64 objects) |
| **Core** | 1 | 1 | 0 | 2 | 3 | 2 | **Very Low** (9 objects) |

## Container Registry Strategy

### Image Sources
- **Main**: Mix of official images (nginx, python, postgres, redis)
- **Dev**: Custom images + official images + monitoring stack
- **Beta**: Official images + observability stack  
- **Core**: Official images only

### Update Strategy
- **Main**: Pinned versions with security updates
- **Dev**: Latest stable with custom builds
- **Beta**: Pinned versions optimized for telemetry
- **Core**: Minimal pinned versions

## Quick Deployment Commands

### Main Branch
```bash
kubectl apply -k manifests/base/
kubectl apply -f manifests/databases/persistent-storage.yaml
kubectl apply -f manifests/middleware/deployment.yaml
kubectl apply -f manifests/finops/finops-controller.yaml
```

### Dev Branch
```bash
./setup.sh  # Interactive enterprise setup
# OR
kubectl apply -k manifests/dev/
kubectl apply -f manifests/monitoring/
kubectl apply -f manifests/messaging/
```

### Beta Branch  
```bash
kubectl apply -f manifests/observability/
kubectl apply -k manifests/base/
kubectl apply -f manifests/middleware/deployment.yaml
```

### Core Branch
```bash
kubectl apply -f manifests/core/deployment.yaml
kubectl apply -f manifests/core/service.yaml  
kubectl apply -f manifests/core/configmap.yaml
```

This analysis shows the progression from Core (minimal single container) to Dev (enterprise-grade multi-cloud platform) with each branch targeting specific deployment scenarios and operational maturity levels.