# Storm Surge Core

**Version**: core-v1.0.0

## Overview

Storm Surge Core is a minimal, production-ready Kubernetes deployment stack focused on security and simplicity. This branch contains only the essential components needed to run a basic Kubernetes application with proper security controls.

## Features

- **Multi-Cloud Support**: Deploy to AWS EKS, Google GKE, or Azure AKS
- **Security-First Design**: Implements Kubernetes security best practices
- **Minimal Dependencies**: No third-party integrations or external services
- **Production-Ready**: Includes health checks, monitoring endpoints, and proper resource limits
- **IAM Policies**: Pre-configured IAM policies for each cloud provider

## Quick Start

```bash
# Interactive setup
./setup-minimal.sh

# Or with parameters
./setup-minimal.sh -p aws -r us-west-2 -n 3
```

## Architecture

### Core Components

1. **Middleware Service**
   - Minimal Python Flask application
   - Health check endpoint
   - Basic metrics collection
   - CORS-enabled for frontend integration

2. **Load Balancer**
   - Cloud-native load balancer (ELB/GLB/ALB)
   - Automatic SSL termination (when configured)
   - Health probe configuration

3. **Security Features**
   - Pod Security Standards (restricted)
   - Network Policies
   - Secrets management
   - Non-root containers
   - Security contexts

## Deployment

### Prerequisites

- kubectl installed
- Cloud provider CLI (aws/gcloud/az)
- Docker (for local development)
- Administrative access to cloud account

### Basic Deployment

```bash
# Deploy using Kustomize
kubectl apply -k manifests/core/

# Or deploy individual components
kubectl apply -f manifests/middleware/configmap-minimal.yaml
kubectl apply -f manifests/middleware/deployment-minimal.yaml
kubectl apply -f manifests/middleware/service-minimal.yaml
```

### Verify Deployment

```bash
# Check pod status
kubectl get pods -n storm-surge-prod

# Get load balancer URL
kubectl get service storm-surge-lb -n storm-surge-prod

# Check application health
curl http://<LOAD_BALANCER_IP>/health
```

## API Endpoints

- `GET /health` - Health check endpoint
- `GET /api/v1/status` - Application status
- `GET /api/v1/metrics` - Basic metrics

## Configuration

### Environment Variables

- `NAMESPACE` - Kubernetes namespace (auto-populated)
- `NODE_NAME` - Node name (auto-populated)
- `CLUSTER_NAME` - Cluster identifier
- `FLASK_SECRET_KEY` - Flask session secret (auto-generated)

### Resource Limits

```yaml
resources:
  requests:
    memory: "128Mi"
    cpu: "100m"
  limits:
    memory: "256Mi"
    cpu: "500m"
```

## Security

### IAM Policies

Pre-configured IAM policies are available for each cloud provider:

- AWS: `manifests/providerIAM/aws/eks-admin-policy.json`
- GCP: `manifests/providerIAM/gcp/gke-admin-role.yaml`
- Azure: `manifests/providerIAM/azure/aks-admin-role.json`

### Security Best Practices

1. All containers run as non-root
2. Security contexts enforced
3. Network policies enabled
4. Secrets stored securely
5. No hardcoded credentials
6. Minimal container capabilities

## Monitoring

Basic monitoring is available through the metrics endpoint:

```bash
# Get application metrics
curl http://<LOAD_BALANCER_IP>/api/v1/metrics
```

## Testing & Validation

### Basic Health Checks

```bash
# Test health endpoint
curl http://<LOAD_BALANCER_IP>/health

# Check API status
curl http://<LOAD_BALANCER_IP>/api/v1/status

# Monitor metrics
curl http://<LOAD_BALANCER_IP>/api/v1/metrics
```

### Deployment Validation

```bash
# Verify all pods are running
kubectl get pods -n storm-surge-prod

# Check deployment status
kubectl rollout status deployment/storm-surge-middleware -n storm-surge-prod

# View logs
kubectl logs -f deployment/storm-surge-middleware -n storm-surge-prod
```

### Security Validation

```bash
# Verify security contexts
kubectl get pods -n storm-surge-prod -o jsonpath='{.items[*].spec.securityContext}'

# Check service endpoints
kubectl get endpoints -n storm-surge-prod
```

## Cleanup

To remove the deployment:

```bash
# Delete all resources
kubectl delete namespace storm-surge-prod

# Or use cloud-specific cleanup
./scripts/cleanup/<provider>-cleanup.sh
```

## Support

For issues or questions, please refer to the main Storm Surge documentation or create an issue in the repository.

## License

See LICENSE file in the root directory.