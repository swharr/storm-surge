# KEDA Integration for Storm-Surge

This directory contains KEDA (Kubernetes Event-Driven Autoscaling) integration for the Storm-Surge FinOps platform. KEDA replaces the traditional HPA with more sophisticated autoscaling triggered by feature flags.

## Overview

The KEDA integration enables:
- **Feature flag-driven autoscaling**: Scale services based on `enable-cost-optimizer` flag state
- **Enhanced cost optimization**: More aggressive scaling during cost optimization mode
- **Multi-metric scaling**: CPU, memory, and external trigger support
- **WebSocket integration**: Real-time scaling events in the Storm-Surge dashboard

## Architecture

```
LaunchDarkly/Statsig → Storm-Surge Middleware → External Scaler → KEDA → Kubernetes
                                           ↓
                                    WebSocket Events → Dashboard
```

## Components

### 1. KEDA Installation (`keda-install.yaml`)
- Helm-based KEDA installation job
- Includes Prometheus metrics support
- Proper RBAC configuration

### 2. ScaledObjects (`scaled-objects.yaml`)
- `shopping-cart-scaler`: Main component with feature flag integration
- `product-catalog-scaler`: Secondary component with baseline scaling
- TriggerAuthentication for secure webhook integration

### 3. External Scaler Service (`external-scaler-service.yaml`)
- Python-based external scaler that receives feature flag webhooks
- Implements KEDA external scaler protocol
- Provides metrics endpoint for monitoring

### 4. Deployment Patches (`patches/deployment-annotations.yaml`)
- Adds KEDA-specific annotations to existing deployments
- Ensures proper integration with Storm-Surge components

## Installation

### Prerequisites
- Kubernetes cluster with Storm-Surge deployed
- Helm 3.x installed in the cluster
- Storm-Surge middleware configured and running

### Deploy KEDA Integration

1. **Apply KEDA manifests:**
   ```bash
   kubectl apply -k manifests/keda/
   ```

2. **Wait for KEDA installation:**
   ```bash
   kubectl wait --for=condition=complete job/keda-installer -n keda --timeout=300s
   ```

3. **Verify KEDA is running:**
   ```bash
   kubectl get pods -n keda
   kubectl get scaledobjects -n oceansurge
   ```

### Remove Legacy HPA (Important!)
Once KEDA is deployed, remove the original HPA to avoid conflicts:
```bash
kubectl delete hpa shopping-cart-hpa -n oceansurge
```

## Configuration

### Feature Flag Integration

The external scaler listens for webhooks from the Storm-Surge middleware at:
- **Endpoint**: `http://storm-surge-external-scaler.oceansurge.svc.cluster.local/webhook/feature-flag`
- **Authentication**: HMAC SHA256 signature verification
- **Headers**: `X-Storm-Surge-Signature`

### Scaling Behavior

#### Cost Optimizer Enabled (`enable-cost-optimizer: true`)
- **Shopping Cart**: Min 1, Max 5 replicas
- **Product Catalog**: Min 1, Max 3 replicas
- **Aggressive scale-down**: 50% reduction every 60s
- **Conservative scale-up**: 25% increase every 60s

#### Cost Optimizer Disabled (`enable-cost-optimizer: false`)
- **Shopping Cart**: Min 1, Max 10 replicas
- **Product Catalog**: Min 1, Max 5 replicas
- **Normal scaling**: 100% increase every 30s, 50% reduction every 300s

### Webhook Secret Configuration

Update the webhook secret in `scaled-objects.yaml`:
```bash
# Generate new secret
echo -n "your-webhook-secret" | base64

# Update the secret in the manifest
kubectl patch secret storm-surge-webhook-secret -n oceansurge \
  --type='json' -p='[{"op": "replace", "path": "/data/secret", "value": "your-base64-secret"}]'
```

## Integration with Storm-Surge Middleware

### Webhook Payload Format

The middleware should send webhooks in this format:
```json
{
  "flag": {
    "key": "enable-cost-optimizer",
    "value": true
  },
  "timestamp": "2024-01-01T00:00:00Z",
  "source": "launchdarkly"
}
```

### Middleware Code Update

Add this to your Flask middleware (`manifests/middleware/`):
```python
import requests
import hmac
import hashlib

def send_keda_webhook(flag_key, flag_value):
    """Send scaling event to KEDA external scaler"""
    payload = {
        "flag": {
            "key": flag_key,
            "value": flag_value
        },
        "timestamp": datetime.utcnow().isoformat() + "Z",
        "source": "storm-surge-middleware"
    }
    
    webhook_secret = os.getenv('KEDA_WEBHOOK_SECRET', '')
    signature = hmac.new(
        webhook_secret.encode(),
        json.dumps(payload).encode(),
        hashlib.sha256
    ).hexdigest()
    
    headers = {
        'Content-Type': 'application/json',
        'X-Storm-Surge-Signature': f'sha256={signature}'
    }
    
    requests.post(
        'http://storm-surge-external-scaler.oceansurge.svc.cluster.local/webhook/feature-flag',
        json=payload,
        headers=headers
    )
```

## Monitoring

### Metrics

The external scaler exposes metrics on port 9090:
- `storm_surge_replicas{component="shopping-cart"}`: Current desired replicas
- `storm_surge_cost_optimizer{component="shopping-cart"}`: Cost optimizer state (0/1)

### Dashboard Integration

WebSocket events are sent to the Storm-Surge dashboard:
```javascript
// Frontend integration
websocket.on('keda-scaling-event', (event) => {
  console.log('KEDA scaling:', event.component, 'to', event.replicas);
  updateScalingChart(event);
});
```

## Troubleshooting

### Check KEDA Status
```bash
kubectl get scaledobjects -n oceansurge
kubectl describe scaledobject shopping-cart-scaler -n oceansurge
```

### View External Scaler Logs
```bash
kubectl logs -f deployment/storm-surge-external-scaler -n oceansurge
```

### Test Webhook Manually
```bash
curl -X POST http://localhost:8080/webhook/feature-flag \
  -H "Content-Type: application/json" \
  -H "X-Storm-Surge-Signature: sha256=test" \
  -d '{"flag":{"key":"enable-cost-optimizer","value":true}}'
```

### Common Issues

1. **HPA Conflicts**: Remove legacy HPA before deploying KEDA
2. **Webhook Authentication**: Ensure webhook secret matches between middleware and external scaler
3. **Network Policies**: Verify middleware can reach external scaler service
4. **RBAC Issues**: Check KEDA has proper permissions to scale deployments

## Testing

### Load Testing with Feature Flags

1. **Enable cost optimizer:**
   ```bash
   # Via LaunchDarkly dashboard or API
   curl -X PATCH "https://app.launchdarkly.com/api/v2/flags/project-key/enable-cost-optimizer" \
     -H "Authorization: your-api-key" \
     -d '{"value": true}'
   ```

2. **Generate load:**
   ```bash
   kubectl run load-test --image=busybox --restart=Never -- \
     sh -c 'while true; do wget -O- http://shopping-cart.oceansurge.svc.cluster.local; done'
   ```

3. **Monitor scaling:**
   ```bash
   watch kubectl get pods -n oceansurge
   kubectl get hpa shopping-cart-scaler -n oceansurge
   ```

## Rollback

To rollback to HPA-based autoscaling:

1. **Remove KEDA resources:**
   ```bash
   kubectl delete -k manifests/keda/
   ```

2. **Restore original HPA:**
   ```bash
   kubectl apply -f manifests/base/hpa.yaml
   ```

## Next Steps

- [ ] Add custom metrics from Ocean API
- [ ] Implement time-based scaling policies
- [ ] Add Slack/Teams notifications for scaling events
- [ ] Integrate with Backstage catalog for scaling history
- [ ] Add chaos engineering tests for spot instance interruptions