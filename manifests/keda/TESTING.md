# KEDA Integration Testing Guide

This guide provides step-by-step testing procedures for the KEDA integration with Storm-Surge.

## Pre-Deployment Validation

The following tests have been completed and passed:

### 1. Manifest Syntax Validation
- Kustomization builds successfully (422 lines generated)
- All required KEDA resources present (ScaledObject, TriggerAuthentication, ServiceMonitor)
- External scaler webhook logic validated
- Signature generation/verification working

### 2. Resource Structure Validation
- Namespaces: `keda` and `oceansurge` properly configured
- RBAC: ClusterRole/ClusterRoleBinding for KEDA installer
- Security: Non-root containers, proper resource limits
- Integration: ScaledObjects target correct deployments

## Deployment Testing Plan

### Phase 1: Cluster Setup
```bash
# 1. Deploy Storm-Surge to GKE cluster
./scripts/deploy.sh --provider=gke --region=us-central1 --zone=us-central1-a

# 2. Verify base Storm-Surge deployment
kubectl get pods -n oceansurge
kubectl get hpa -n oceansurge  # Should show existing HPA

# 3. Run baseline load test to verify current scaling
kubectl run load-test --image=busybox --restart=Never -- \
  sh -c 'while true; do wget -O- http://shopping-cart.oceansurge.svc.cluster.local; done'
```

### Phase 2: KEDA Installation
```bash
# 1. Deploy KEDA integration
kubectl apply -k manifests/keda/

# 2. Monitor KEDA installation
kubectl logs -f job/keda-installer -n keda

# 3. Verify KEDA components
kubectl get pods -n keda
kubectl get scaledobjects -n oceansurge
kubectl get triggerauthentication -n oceansurge

# 4. IMPORTANT: Remove legacy HPA to avoid conflicts
kubectl delete hpa shopping-cart-hpa -n oceansurge
```

### Phase 3: External Scaler Validation
```bash
# 1. Check external scaler is running
kubectl get pods -n oceansurge -l app=storm-surge-external-scaler
kubectl logs -f deployment/storm-surge-external-scaler -n oceansurge

# 2. Test health endpoints
kubectl port-forward -n oceansurge svc/storm-surge-external-scaler 8080:80
curl http://localhost:8080/health
curl http://localhost:8080/ready

# 3. Check metrics endpoint
curl http://localhost:8080:9090/metrics
```

### Phase 4: Feature Flag Integration Testing
```bash
# 1. Test webhook endpoint manually
kubectl port-forward -n oceansurge svc/storm-surge-external-scaler 8080:80

# 2. Send test webhook (in another terminal)
curl -X POST http://localhost:8080/webhook/feature-flag \
  -H "Content-Type: application/json" \
  -H "X-Storm-Surge-Signature: sha256=$(echo -n '{"flag":{"key":"enable-cost-optimizer","value":true}}' | openssl dgst -sha256 -hmac 'storm-surge-webhook-secret' -binary | xxd -p)" \
  -d '{"flag":{"key":"enable-cost-optimizer","value":true}}'

# 3. Verify KEDA responds to external scaler
kubectl get hpa shopping-cart-scaler -n oceansurge -w
```

### Phase 5: End-to-End Scaling Test
```bash
# 1. Start load generation
kubectl run load-generator --image=busybox --restart=Never -- \
  sh -c 'while true; do wget -O- http://shopping-cart.oceansurge.svc.cluster.local; sleep 0.1; done'

# 2. Monitor initial scaling (cost optimizer disabled)
watch kubectl get pods -n oceansurge

# 3. Enable cost optimizer via feature flag
# (Via LaunchDarkly dashboard or middleware API)

# 4. Verify scaling behavior changes
# Should see more aggressive scale-down with cost optimizer enabled

# 5. Monitor metrics
kubectl port-forward -n oceansurge svc/storm-surge-external-scaler 9090:9090
curl http://localhost:9090/metrics | grep storm_surge
```

## Success Criteria

### KEDA Installation Success
- [ ] KEDA operator pods running in `keda` namespace
- [ ] KEDA installation job completed successfully
- [ ] No error logs in KEDA operator

### ScaledObject Configuration Success
- [ ] `shopping-cart-scaler` and `product-catalog-scaler` created
- [ ] ScaledObjects show "Ready: True" status
- [ ] Legacy HPA removed without conflicts

### External Scaler Success
- [ ] External scaler pod running and healthy
- [ ] Health/ready endpoints responding
- [ ] Metrics endpoint exposing storm_surge metrics
- [ ] Webhook endpoint accepting POST requests

### Feature Flag Integration Success
- [ ] Webhook receives and processes feature flag events
- [ ] Cost optimizer flag changes scaling behavior
- [ ] Scaling metrics update in real-time
- [ ] No authentication errors in external scaler logs

### End-to-End Scaling Success
- [ ] KEDA scales pods based on CPU/memory metrics
- [ ] External trigger influences scaling decisions
- [ ] Cost optimizer mode reduces max replicas
- [ ] Scaling behavior follows configured policies

## Troubleshooting Common Issues

### KEDA Installation Issues
```bash
# Check KEDA installation logs
kubectl logs job/keda-installer -n keda

# Verify Helm repos are accessible
kubectl exec -it job/keda-installer -n keda -- helm repo list

# Check RBAC permissions
kubectl auth can-i '*' '*' --as=system:serviceaccount:keda:keda-installer
```

### ScaledObject Issues
```bash
# Check ScaledObject status
kubectl describe scaledobject shopping-cart-scaler -n oceansurge

# Verify target deployment exists
kubectl get deployment shopping-cart -n oceansurge

# Check KEDA operator logs
kubectl logs -f deployment/keda-operator -n keda
```

### External Scaler Issues
```bash
# Check external scaler logs
kubectl logs -f deployment/storm-surge-external-scaler -n oceansurge

# Verify secret is correctly mounted
kubectl exec deployment/storm-surge-external-scaler -n oceansurge -- env | grep WEBHOOK_SECRET

# Test webhook secret decoding
kubectl get secret storm-surge-webhook-secret -n oceansurge -o jsonpath='{.data.secret}' | base64 -d
```

### Feature Flag Integration Issues
```bash
# Verify middleware can reach external scaler
kubectl exec -it deployment/ld-spot-middleware -n oceansurge -- \
  nslookup storm-surge-external-scaler.oceansurge.svc.cluster.local

# Check webhook signature calculation
# (Ensure middleware and external scaler use same secret)

# Monitor webhook requests
kubectl logs -f deployment/storm-surge-external-scaler -n oceansurge | grep webhook
```

## Performance Benchmarks

### Expected Scaling Behavior

#### Normal Mode (cost-optimizer: false)
- **CPU Threshold**: 70%
- **Memory Threshold**: 80%
- **Min/Max Replicas**: 1-10
- **Scale Up**: 100% increase every 30s
- **Scale Down**: 50% reduction every 300s

#### Cost Optimization Mode (cost-optimizer: true)
- **CPU Threshold**: 70% (unchanged)
- **Memory Threshold**: 80% (unchanged)
- **Min/Max Replicas**: 1-5 (reduced max)
- **Scale Up**: 25% increase every 60s (more conservative)
- **Scale Down**: 50% reduction every 60s (more aggressive)

### Performance Metrics to Monitor
- Pod scaling response time: < 30 seconds
- External scaler response time: < 1 second
- Webhook processing time: < 100ms
- Memory usage of external scaler: < 256MB
- CPU usage of external scaler: < 200m

## Rollback Procedure

If KEDA integration fails:
```bash
# 1. Remove KEDA resources
kubectl delete -k manifests/keda/

# 2. Restore original HPA
kubectl apply -f manifests/base/hpa.yaml

# 3. Verify original functionality
kubectl get hpa -n oceansurge
kubectl get pods -n oceansurge
```

## Next Steps After Successful Testing
- [ ] Integrate webhook calls into Storm-Surge middleware
- [ ] Add KEDA metrics to Backstage Ocean provider
- [ ] Set up alerting for scaling events
- [ ] Document production deployment procedures
- [ ] Add chaos engineering tests for spot interruptions
