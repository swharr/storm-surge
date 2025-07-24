# Storm Surge Frontend Kubernetes Deployment

This directory contains Kubernetes manifests for deploying the Storm Surge React frontend application.

## Overview

The React frontend provides a modern web interface for managing feature flags, monitoring cluster metrics, and viewing real-time analytics for the Storm Surge system.

## Architecture

- **Frontend**: React 18 with TypeScript, TailwindCSS, and Vite
- **Backend Integration**: Communicates with the middleware API at `/api/*`
- **Real-time Updates**: WebSocket connection to `/socket.io/*`
- **Deployment**: Nginx serving static files with API proxy configuration

## Prerequisites

1. Kubernetes cluster with nginx-ingress controller
2. The Storm Surge middleware already deployed in the `oceansurge` namespace
3. Docker image built for the frontend application

## Building the Docker Image

```bash
# From the frontend directory
cd /Users/swharr/Documents/GitHub/storm-surge/frontend

# Build the Docker image
docker build -t storm-surge-frontend:latest .

# Tag for your registry (optional)
docker tag storm-surge-frontend:latest your-registry/storm-surge-frontend:latest

# Push to registry (optional)
docker push your-registry/storm-surge-frontend:latest
```

## Deployment

### Option 1: Using Kustomize (Recommended)

```bash
# Deploy using kustomize
kubectl apply -k /Users/swharr/Documents/GitHub/storm-surge/frontend/k8s

# Verify deployment
kubectl get pods -n oceansurge -l app=storm-surge-frontend
kubectl get svc -n oceansurge storm-surge-frontend
kubectl get ingress -n oceansurge storm-surge-frontend
```

### Option 2: Direct YAML Application

```bash
# Apply manifests in order
kubectl apply -f configmap.yaml
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
kubectl apply -f ingress.yaml
```

## Configuration

### Environment Variables

The frontend can be configured using the ConfigMap `storm-surge-frontend-config`:

- `REACT_APP_API_BASE_URL`: Backend API base URL (default: "/api")
- `REACT_APP_WS_URL`: WebSocket URL (default: "/socket.io")
- `REACT_APP_VERSION`: Application version
- `REACT_APP_ENVIRONMENT`: Environment name
- `REACT_APP_ENABLE_ANALYTICS`: Enable analytics features
- `REACT_APP_ENABLE_REALTIME`: Enable real-time updates
- `REACT_APP_ENABLE_COST_TRACKING`: Enable cost tracking features

### Ingress Configuration

The application is accessible through:
- **Frontend**: `https://storm-surge.local/`
- **API**: `https://storm-surge.local/api/*` (proxied to middleware)
- **WebSocket**: `https://storm-surge.local/socket.io/*` (proxied to middleware)

Update the `storm-surge.local` hostname in `ingress.yaml` to match your domain.

## Scaling

The deployment is configured with:
- **Replicas**: 2 (for high availability)
- **Resources**: 
  - Requests: 128Mi memory, 100m CPU
  - Limits: 256Mi memory, 200m CPU
- **Rolling Updates**: Maximum 1 unavailable, maximum 1 surge

To scale the deployment:

```bash
kubectl scale deployment storm-surge-frontend -n oceansurge --replicas=3
```

## Monitoring

### Health Checks

The application includes health checks:
- **Readiness Probe**: `/health` endpoint (5s intervals)
- **Liveness Probe**: `/health` endpoint (10s intervals)

### Logs

View application logs:

```bash
# View logs from all frontend pods
kubectl logs -l app=storm-surge-frontend -n oceansurge

# Follow logs from a specific pod
kubectl logs -f deployment/storm-surge-frontend -n oceansurge
```

## Troubleshooting

### Common Issues

1. **Backend API Connection Issues**
   - Verify the middleware service is running: `kubectl get svc feature-flag-middleware -n oceansurge`
   - Check middleware logs: `kubectl logs deployment/feature-flag-middleware -n oceansurge`

2. **Image Pull Errors**
   - Ensure the Docker image is built and available
   - Check image name and tag in `deployment.yaml`

3. **Ingress Not Working**
   - Verify nginx-ingress controller is installed
   - Check ingress status: `kubectl describe ingress storm-surge-frontend -n oceansurge`

4. **WebSocket Connection Failures**
   - Verify the middleware supports WebSocket connections
   - Check nginx ingress annotations for WebSocket support

### Debug Commands

```bash
# Check pod status
kubectl get pods -n oceansurge -l app=storm-surge-frontend

# Describe deployment for events
kubectl describe deployment storm-surge-frontend -n oceansurge

# Check service endpoints
kubectl get endpoints storm-surge-frontend -n oceansurge

# Test internal connectivity
kubectl run debug --rm -i --tty --image=busybox -- sh
# From inside the pod:
# wget -qO- http://storm-surge-frontend.oceansurge.svc.cluster.local/health
```

## Security

The deployment includes security best practices:
- **Non-root user**: Runs as user 101 (nginx)
- **Read-only filesystem**: Root filesystem is read-only
- **No privilege escalation**: `allowPrivilegeEscalation: false`
- **Dropped capabilities**: All Linux capabilities dropped
- **Security headers**: Nginx configured with security headers

## Updates

To update the frontend:

1. Build new Docker image with updated tag
2. Update image tag in `deployment.yaml` or `kustomization.yaml`
3. Apply the changes: `kubectl apply -k .`
4. Monitor rollout: `kubectl rollout status deployment/storm-surge-frontend -n oceansurge`

## Cleanup

To remove the frontend deployment:

```bash
# Using kustomize
kubectl delete -k /Users/swharr/Documents/GitHub/storm-surge/frontend/k8s

# Or individual resources
kubectl delete ingress,service,deployment,configmap -l app=storm-surge-frontend -n oceansurge
```