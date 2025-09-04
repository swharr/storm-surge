# Storm Surge Branch Comparison Guide

This document outlines the differences between Storm Surge branches to help you choose the right deployment option for your environment.

## Branch Overview

| Branch | Stability | Security Level | Features | Best For |
|--------|-----------|----------------|----------|----------|
| `main` | ✅ Stable | 🟡 Basic | Core K8s app | Production (minimal) |
| `dev` | 🟡 Development | 🟢 Enterprise | Full security + multi-cloud | Production (secure) |
| `beta-v1.1.0` | 🟠 Beta | 🟡 Enhanced | Auth + observability | Testing/staging |
| `core` | ⚫ Minimal | 🔴 Stripped | Bare essentials | Educational/POC |

## Detailed Branch Analysis

### 🌟 Main Branch (`main`)
**Target Use Case**: Stable production deployments with basic features

**Core Components**:
- Basic Kubernetes manifests (deployments, services, configmaps)
- Simple frontend with React/Tailwind
- Python middleware with Flask
- FinOps controller for cost optimization
- Basic HPA and load balancing

**Security Features**:
- ✅ Basic RBAC and network policies
- ✅ External secrets management
- ✅ TLS ingress configuration
- ✅ Input validation in scripts
- ✅ Rate limiting middleware

**Missing from Other Branches**:
- Advanced authentication system
- Comprehensive observability stack
- Multi-cloud deployment scripts
- Advanced security monitoring

**File Count**: ~60 core files
**Complexity**: Low-Medium

---

### 🔥 Dev Branch (`dev`) 
**Target Use Case**: Enterprise production with comprehensive security and multi-cloud support

**Everything from Main PLUS**:

**Enhanced Security**:
- 🛡️ Comprehensive security documentation (12 security guides)
- 🛡️ Multi-phase security deployment process
- 🛡️ Emergency security fixes procedures
- 🛡️ SQL injection prevention
- 🛡️ Advanced RBAC with fine-grained permissions
- 🛡️ Production security hardening
- 🛡️ Security monitoring and alerting

**Multi-Cloud Infrastructure**:
- ☁️ GCP/GKE deployment manifests and scripts
- ☁️ AWS/EKS deployment manifests and scripts  
- ☁️ Azure/AKS deployment manifests and scripts
- ☁️ Provider-specific IAM configurations
- ☁️ Cross-cloud networking setup

**Additional Features**:
- 📊 Load testing with K6
- 🔧 Advanced CI/CD workflows
- 📈 Enhanced monitoring with Grafana
- 🐰 RabbitMQ messaging integration
- 📦 Release packaging and versioning

**Documentation**:
- Deployment guides for each cloud provider
- Security checklists and procedures
- Credentials management documentation
- Emergency response procedures

**File Count**: ~150+ files
**Complexity**: High

---

### 🧪 Beta Branch (`beta-v1.1.0`)
**Target Use Case**: Feature testing and staging environments with authentication

**Everything from Main PLUS**:

**Authentication System**:
- 🔐 JWT-based user authentication
- 🔐 User registration and login endpoints
- 🔐 Role-based access control
- 🔐 Session management

**Advanced Observability**:
- 📊 OpenTelemetry Collector with full configuration
- 📊 Jaeger for distributed tracing
- 📊 Prometheus for metrics collection
- 📊 Custom business metrics and dashboards
- 📊 Telemetry for frontend, middleware, and infrastructure

**Enhanced Frontend**:
- ⚙️ ESLint v9 flat configuration
- ⚙️ Updated TypeScript 5.6+
- ⚙️ Vite 6.x build system
- ⚙️ Enhanced testing and validation

**Unique Files**:
- `docs/OBSERVABILITY.md` - Comprehensive observability guide
- `docs/SECURITY.md` - Security implementation details
- `frontend/eslint.config.js` - Modern ESLint configuration
- `manifests/observability/` - Full observability stack
- `manifests/middleware/metrics.py` - Custom metrics collection
- `manifests/middleware/telemetry.py` - OpenTelemetry integration

**File Count**: ~90 files
**Complexity**: Medium-High

---

### ⚙️ Core Branch (`core`)
**Target Use Case**: Educational, proof-of-concept, or minimal testing

**Stripped Down Version**:
- Minimal Kubernetes manifests
- Basic documentation only
- No advanced security features
- No observability stack
- No multi-cloud support
- Core pre-commit configuration

**What's Removed**:
- Most security enhancements
- Authentication system
- Observability components
- Multi-cloud infrastructure
- Advanced CI/CD features

**File Count**: ~20 core files
**Complexity**: Very Low

## Feature Matrix

| Feature | Main | Dev | Beta | Core |
|---------|------|-----|------|------|
| **Basic K8s App** | ✅ | ✅ | ✅ | ✅ |
| **FinOps Controller** | ✅ | ✅ | ✅ | ❌ |
| **Basic Security** | ✅ | ✅ | ✅ | ❌ |
| **Multi-Cloud Support** | ❌ | ✅ | ❌ | ❌ |
| **JWT Authentication** | ❌ | ❌ | ✅ | ❌ |
| **OpenTelemetry** | ❌ | ❌ | ✅ | ❌ |
| **Load Testing** | ❌ | ✅ | ❌ | ❌ |
| **Security Documentation** | ❌ | ✅ | ✅ | ❌ |
| **Enterprise RBAC** | ❌ | ✅ | ✅ | ❌ |
| **Messaging (RabbitMQ)** | ❌ | ✅ | ❌ | ❌ |

## Deployment Recommendations

### 🎯 Choose **Main** if you need:
- Stable, production-ready Kubernetes application
- Basic security features without complexity
- Simple deployment and maintenance
- Cost optimization with FinOps
- Minimal attack surface

### 🎯 Choose **Dev** if you need:
- Enterprise-grade security posture
- Multi-cloud deployment capabilities (GCP, AWS, Azure)
- Comprehensive security documentation
- Advanced CI/CD and release management
- Maximum feature set with all enhancements

### 🎯 Choose **Beta-v1.1.0** if you need:
- User authentication and session management
- Comprehensive monitoring and observability
- Modern frontend tooling (ESLint v9, TypeScript 5.6+)
- Distributed tracing and metrics collection
- Testing/staging environment features

### 🎯 Choose **Core** if you need:
- Educational or learning environment
- Proof-of-concept deployment
- Minimal resource usage
- Understanding basic Kubernetes patterns
- Starting point for custom development

## Security Comparison

| Security Feature | Main | Dev | Beta | Core |
|------------------|------|-----|------|------|
| **Secret Management** | External | External + Templates | External | None |
| **Network Policies** | Basic | Zero-trust | Enhanced | None |
| **RBAC** | Standard | Fine-grained | Enhanced | None |
| **TLS/Ingress** | Standard | Hardened | Standard | None |
| **Input Validation** | Basic | Comprehensive | Enhanced | None |
| **Vulnerability Scanning** | CI only | Full pipeline | Enhanced | None |

## Migration Path

```
Core → Main → Beta-v1.1.0 → Dev
  ↑      ↑         ↑         ↑
 POC   Prod     Testing   Enterprise
```

1. **Core to Main**: Add production features and basic security
2. **Main to Beta**: Add authentication and observability  
3. **Beta to Dev**: Add multi-cloud and enterprise security
4. **Any to Dev**: Direct upgrade for full feature set

## Quick Start Commands

### Main Branch
```bash
git checkout main
kubectl apply -k manifests/base/
```

### Dev Branch  
```bash
git checkout dev
# Choose cloud provider
./scripts/providers/gke.sh  # or eks.sh, aks.sh
```

### Beta Branch
```bash
git checkout beta-v1.1.0
kubectl apply -f manifests/observability/
kubectl apply -k manifests/base/
```

### Core Branch
```bash
git checkout core
kubectl apply -f manifests/  # minimal set
```

## Support and Documentation

- **Main**: Standard README and architecture docs
- **Dev**: Comprehensive guides for each cloud provider + security
- **Beta**: Observability and authentication guides
- **Core**: Minimal documentation only

Choose the branch that best matches your security requirements, infrastructure complexity, and operational maturity level.