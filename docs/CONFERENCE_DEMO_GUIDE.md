# Storm Surge Conference Demo Guide

## Overview

This guide provides comprehensive instructions for demonstrating Storm Surge at conferences, showcasing enterprise-grade Kubernetes deployment patterns with well-architected framework compliance.

## Pre-Demo Setup (15 minutes)

### 1. Environment Preparation
```bash
# Clone and navigate to demo branch
git clone https://github.com/your-org/storm-surge.git
cd storm-surge
git checkout dev

# Set demo environment variables
export DEMO_MODE=true
export STORM_CLUSTER_NAME="conference-demo"
export STORM_NODES=3
```

### 2. Cloud Provider Selection
Choose your preferred provider based on audience:

**Google Cloud (Recommended for K8s demos)**
```bash
export STORM_PROVIDER=gke
export STORM_REGION=us-central1
export STORM_ZONE=us-central1-a
```

**AWS (Enterprise audience)**
```bash
export STORM_PROVIDER=eks
export STORM_REGION=us-west-2
export STORM_ZONES="us-west-2a us-west-2b"
```

**Azure (Microsoft-focused events)**
```bash
export STORM_PROVIDER=aks
export STORM_REGION=eastus
export STORM_ZONE=1
```

### 3. Deploy Demo Infrastructure
```bash
# Deploy with monitoring and demo features
kubectl apply -k manifests/demo/

# Verify deployment
./scripts/demo-check.sh
```

## Demo Script (20-30 minutes)

### Phase 1: Architecture Overview (5 minutes)

**Key Points:**
- Multi-cloud Kubernetes platform (AWS/GCP/Azure)
- Production-ready security controls
- Enterprise-grade observability
- Cost optimization with FinOps

**Visual Elements:**
```bash
# Show cluster overview
kubectl get nodes -o wide

# Display application components
kubectl get pods,svc,hpa -n oceansurge

# Show security hardening
kubectl get networkpolicies,poddisruptionbudgets -n oceansurge
```

### Phase 2: Scaling Demonstration (8-10 minutes)

**Scenario:** "Demonstrate Kubernetes horizontal pod autoscaling under load"

```bash
# Show initial state
kubectl get hpa -n oceansurge
kubectl top pods -n oceansurge

# Generate load (in separate terminal)
kubectl run -i --tty load-generator --rm --image=busybox --restart=Never -- /bin/sh
# Inside load generator:
while true; do wget -q -O- http://frontend-service.oceansurge.svc.cluster.local/; done

# Monitor scaling in real-time
watch kubectl get pods,hpa -n oceansurge
```

**Expected Results:**
- Shopping cart pods scale from 2 → 8+ replicas
- Frontend pods scale from 3 → 6 replicas
- HPA shows CPU utilization increasing

### Phase 3: Observability Stack (5-7 minutes)

**Scenario:** "Enterprise monitoring with Prometheus and Grafana"

```bash
# Access Grafana dashboard
kubectl port-forward svc/grafana-service 3000:3000 -n monitoring
# Open browser to http://localhost:3000 (admin/admin)

# Show Prometheus metrics
kubectl port-forward svc/prometheus-service 9090:9090 -n monitoring
# Open browser to http://localhost:9090
```

**Key Metrics to Highlight:**
- Pod CPU/Memory utilization
- HPA scaling events
- Application request rates
- Cluster resource consumption

### Phase 4: FinOps Integration (5-8 minutes)

**Scenario:** "Cost optimization with feature flags and automation"

```bash
# Show FinOps controller status
kubectl logs -f deployment/finops-controller -n oceansurge

# Check FinOps metrics
curl http://finops-controller.oceansurge.svc.cluster.local:8080/metrics

# Demonstrate cost optimization mode
# (In demo mode, automatically toggles based on time)
```

**Key Talking Points:**
- LaunchDarkly feature flag integration
- Spot Ocean API for cluster optimization
- Business hours vs. off-hours scaling
- Real-time cost impact monitoring

### Phase 5: Security & Compliance (3-5 minutes)

**Scenario:** "Production-grade security controls"

```bash
# Show security contexts
kubectl get pods -n oceansurge -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.securityContext}{"\n"}{end}'

# Display network policies
kubectl describe networkpolicy deny-all-default -n oceansurge

# Show RBAC configuration
kubectl get roles,rolebindings,clusterroles,clusterrolebindings | grep storm-surge
```

## Advanced Demo Features

### A/B Testing with Feature Flags
```bash
# Toggle feature flags to show infrastructure changes
python3 scripts/demo-feature-toggle.py --flag=cost-optimizer --value=true

# Monitor cluster response
kubectl get pods -w -n oceansurge
```

### Chaos Engineering
```bash
# Introduce controlled failures
kubectl delete pod -l app=shopping-cart -n oceansurge

# Show automatic recovery
watch kubectl get pods -n oceansurge
```

### Multi-Cloud Comparison
```bash
# Show provider-specific configurations
diff -u scripts/providers/gke.sh scripts/providers/eks.sh
diff -u scripts/providers/eks.sh scripts/providers/aks.sh
```

## Troubleshooting

### Common Issues

**Pods Not Scaling:**
```bash
# Check HPA status
kubectl describe hpa shopping-cart-hpa -n oceansurge

# Verify metrics server
kubectl get apiservice v1beta1.metrics.k8s.io
```

**LoadBalancer Pending:**
```bash
# Check cloud provider setup
kubectl describe svc frontend-service -n oceansurge

# Verify firewall rules (GKE example)
gcloud compute firewall-rules list | grep conference-demo
```

**Monitoring Not Available:**
```bash
# Check monitoring namespace
kubectl get pods -n monitoring

# Restart monitoring stack
kubectl rollout restart deployment/prometheus -n monitoring
kubectl rollout restart deployment/grafana -n monitoring
```

### Recovery Commands
```bash
# Reset demo environment
kubectl delete namespace oceansurge monitoring
kubectl apply -k manifests/demo/

# Quick status check
./scripts/demo-check.sh --verbose
```

## Audience Q&A Preparation

### Technical Questions

**Q: "How does this handle multi-zone failures?"**
A: Show pod anti-affinity rules and node distribution:
```bash
kubectl get pods -o wide -n oceansurge
kubectl describe deployment frontend -n oceansurge | grep -A 10 "Anti"
```

**Q: "What about data persistence?"**
A: Demonstrate StatefulSet capabilities and PVC management:
```bash
kubectl get pv,pvc
kubectl describe statefulset database -n oceansurge
```

**Q: "How do you manage secrets at scale?"**
A: Show external secrets integration:
```bash
kubectl get secrets -n oceansurge
kubectl describe secret finops-credentials -n oceansurge
```

### Business Questions

**Q: "What are the cost savings?"**
A: Present FinOps metrics and optimization scenarios:
- Off-hours scaling: 30-50% cost reduction
- Right-sizing: 20-30% optimization
- Spot instances: Up to 70% savings

**Q: "How complex is the setup?"**
A: Demonstrate one-command deployment:
```bash
./scripts/deploy.sh --provider=gke --yes
```

## Post-Demo Resources

### Audience Handouts
- QR code to GitHub repository
- Architecture diagram (high-level)
- Cost optimization case studies
- Contact information for follow-up

### Follow-up Materials
```bash
# Generate demo report
./scripts/generate-demo-report.sh

# Export configurations
kubectl get all -n oceansurge -o yaml > storm-surge-demo-export.yaml
```

## Demo Timing

| Phase | Duration | Key Message |
|-------|----------|-------------|
| Architecture Overview | 5 min | Enterprise-grade K8s platform |
| Scaling Demo | 8-10 min | Automatic resource optimization |
| Observability | 5-7 min | Production monitoring stack |
| FinOps Integration | 5-8 min | Cost optimization automation |
| Security & Compliance | 3-5 min | Defense-in-depth security |
| **Total** | **26-35 min** | **Complete platform demonstration** |

## Success Metrics

### Technical Metrics
- Pod scaling response time: < 60 seconds
- Application availability: > 99.9%
- Resource utilization: 60-80% target
- Security policies: 100% compliance

### Audience Engagement
- Questions during demo: Target 5-8
- Repository stars: Track post-demo
- Follow-up inquiries: Document contacts
- Demo feedback: Collect via survey

## Conference-Specific Customizations

### KubeCon / Cloud Native Events
- Focus on CNCF ecosystem integration
- Emphasize cloud-native patterns
- Highlight Prometheus/Grafana/OpenTelemetry

### Enterprise/Financial Events
- Emphasize FinOps and cost optimization
- Show ROI calculations
- Highlight compliance features

### Developer Conferences
- Show deployment simplicity
- Emphasize developer experience
- Demonstrate local testing capabilities

### Security-Focused Events
- Deep dive on security controls
- Show threat modeling
- Demonstrate compliance reporting