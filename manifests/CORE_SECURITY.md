# Storm Surge Core - Security Configuration

## Overview

This document outlines the security configuration for Storm Surge Core, focusing on minimal attack surface and defense in depth.

## Secret Management

### Required Secrets

1. **Flask Secret Key**
   - Purpose: Session management for the middleware
   - Generation: `openssl rand -hex 32`
   - Storage: Kubernetes Secret `storm-surge-secrets`

### Secret Creation

```bash
# Generate and apply secrets
kubectl create secret generic storm-surge-secrets \
  --namespace=storm-surge-prod \
  --from-literal=flask-secret-key="$(openssl rand -hex 32)"
```

## Security Controls

### Pod Security

- All containers run as non-root (UID 1000)
- Read-only root filesystem where possible
- Minimal capabilities (only NET_BIND_SERVICE)
- Security contexts enforced at pod and container level

### Network Security

- Service exposed only through cloud load balancer
- No direct pod access from outside the cluster
- CORS configured for API endpoints

### Runtime Security

- Resource limits enforced (CPU and memory)
- Health checks prevent unhealthy pods from receiving traffic
- Automatic pod restart on failure

## Best Practices

1. **No Hardcoded Secrets**: All sensitive data in Kubernetes Secrets
2. **Minimal Permissions**: Containers run with minimal Linux capabilities
3. **Secure Defaults**: Security controls enabled by default
4. **Regular Updates**: Keep base images and dependencies updated

## Compliance

The core configuration follows:
- CIS Kubernetes Benchmark recommendations
- Pod Security Standards (Restricted profile)
- OWASP security guidelines for web applications