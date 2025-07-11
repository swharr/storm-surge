# 🌊 OceanSurge: Kubernetes Elasticity + FinOps Testing with Spot Ocean + LaunchDarkly

![Kubernetes](https://img.shields.io/badge/kubernetes-%23326ce5.svg?style=for-the-badge&logo=kubernetes&logoColor=white)
![LaunchDarkly](https://img.shields.io/badge/LaunchDarkly-Feature--Flags-blue?style=for-the-badge)
![Flexera Spot](https://img.shields.io/badge/Flexera--Spot-Ocean-blue?style=for-the-badge)
![Spot.io](https://img.shields.io/badge/Spot.io-Ocean-blue?style=for-the-badge)
![AWS](https://img.shields.io/badge/AWS-%23FF9900.svg?style=for-the-badge&logo=amazon-aws&logoColor=white)
![Google Cloud](https://img.shields.io/badge/GoogleCloud-%234285F4.svg?style=for-the-badge&logo=google-cloud&logoColor=white)
![Azure](https://img.shields.io/badge/azure-%230072C6.svg?style=for-the-badge&logo=microsoftazure&logoColor=white)

A FinOps-focused microservices demo app for testing real-time scaling, feature flag toggling, and infrastructure cost optimization — designed to run on **GKE**, **EKS**, or **AKS** using the Hyperscaler provided Managed Kubernetes with **Spot Ocean** and **LaunchDarkly**.

---

## 🚀 Highlights

- ⚙️ **LaunchDarkly Integration**: Real-time feature flag control with webhook middleware to monitor and fire off infrastructure changes
- 🌊 **Spot Ocean API**: Automated cluster scaling based on cost optimization flags in the LaunchDarkly Integration.
- 🛠️ **Multi-Cloud**: Deploy to GCP, AWS, or Azure with unified CLI (You need to have the API and CLI tools included)
- 📈 **Cost Tracking**: Infrastructure impact monitoring via feature flag changes
- 🔄 **Automated Scaling**: Dynamic right-sizing and node pool optimization
- 🌐 **Production Ready**: Complete middleware with ingress, secrets, and monitoring
- 💥 **Load Testing**: Built-in chaos testing and performance validation to simulate activity and show responsiveness

---

## 🧪 How It Works

You use LaunchDarkly feature flags (like `enable-cost-optimizer`) to toggle infrastructure behavior, which is reflected in your app and metrics.

This repo ties application behavior directly to cost outcomes.

---

## 🧰 Quickstart

### Basic Deployment
```bash
git clone https://github.com/swharr/ocean-surge.git
cd ocean-surge
./scripts/deploy.sh --provider=gke   # or eks | aks | all
```

### Production Deployment (Recommended)
```bash
# Full deployment with All Features across all three hyperscalers (if configured)
./scripts/prod_deploy_preview.sh

# Or specify provider directly
./scripts/prod_deploy_preview.sh --provider=gke #or "azure" or "aws"

# Configuration only (no deployment)
./scripts/prod_deploy_preview.sh --config-only
```

The production script will collect your LaunchDarkly SDK key, Spot API token, and cluster configuration interactively.

---

## ⚙️ LaunchDarkly + Spot API Setup

### LaunchDarkly Configuration
1. Create a boolean flag: `enable-cost-optimizer`
2. Get your **Server-side SDK key** from LaunchDarkly (Account Settings > Projects > Environment)
3. Configure webhook endpoint (after deployment):
   - URL: `https://your-domain.com/webhook/launchdarkly`
   - Secret: Generated during deployment

### Spot API Configuration
** Pre-Requiste** You need to have a Spot Console (https://console.spotinst.com) base organization set up with your Admin account verified.
1. Get your **Spot API token** from Spot Console (Settings > API)
2. Find your **Spot Cluster ID** (Ocean > Clusters)
3. Ensure cluster has proper permissions for scaling

### Environment Variables
```bash
# Required for production deployment
export LAUNCHDARKLY_SDK_KEY="api-integration-key-from-ld-here"
export SPOT_API_TOKEN="your-spot-api-token"
export SPOT_CLUSTER_ID="ocn-cluster-id"
export WEBHOOK_SECRET="your-webhook-secret"
```

4. Toggle the flag → see automated cluster scaling in real time

---

## ☁️ Cloud Provider Support

| Provider | Script                              | Requirements          |
|----------|-------------------------------------|------------------------|
| GKE      | `scripts/providers/gke.sh`          | `gcloud`, enabled APIs |
| EKS      | `scripts/providers/eks.sh`          | `aws`, `eksctl`        |
| AKS      | `scripts/providers/aks.sh`          | `az`, login session    |

---

## 🗃️ Project Structure

```
ocean-surge/
├── scripts/
│   ├── deploy.sh                    # Basic deployment
│   ├── prod_deploy_preview.sh       # Production deployment with integrations
│   ├── deploy-middleware.sh         # Middleware-only deployment
│   └── cleanup/
│       ├── cleanup.sh               # Destroys all cluster resources except for default namespaces, and then de-registers from Spot Ocean
│   └── providers/
│       ├── gke.sh                   # Google Kubernetes Engine
│       ├── eks.sh                   # Amazon EKS
│       └── aks.sh                   # Azure AKS
├── manifests/
│   ├── base/                        # Core application manifests
│   │   ├── kustomization.yaml
│   │   ├── deployments.yaml         # Core Application with web front end. 
│   │   ├── services.yaml
│   │   ├── configmaps.yaml
│   │   └── hpa.yaml
│   └── middleware/                  # API Controller Middleware to talk between LaunchDarkly, Spot, and the Workload
│       ├── kustomization.yaml
│       ├── deployment.yaml          # Python Flask middleware
│       ├── service.yaml             # LoadBalancer + Ingress
│       ├── configmap.yaml           # Application code + configuration
│       └── secret.yaml              # API keys and webhooks
├── logs/                            # Deployment logs
├── .env                            # Environment configuration
└── README.md
```

---

## 🎯 Current Status

- [ ] **LaunchDarkly Webhook Integration**: Real-time feature flag processing (In Progress)
- [ ] **Spot Ocean API Integration**: Automated cluster scaling (In Progress)
- [x] **Multi-Cloud Deployment**: GKE, EKS, AKS support
- [x] **Production Middleware**: Flask app with proper security
- [x] **Interactive Deployment**: Credential collection and validation
- [x] **Load Testing**: Built-in traffic generation and scaling tests
- [x] **Monitoring**: Health checks, logging, and status endpoints

## 🧠 Roadmap 

- [ ] OpenFeature + flagd support
- [ ] Backstage IDP Scaffolding 
- [ ] Microsoft Azure DevOps Pipeline
- [ ] Github Runners for Deploy
- [ ] FinOps Alerts based on infra changes
- [ ] Advanced Spot Ocean policies (scheduling, taints)
- [ ] GitOps flow via ArgoCD
- [ ] FinOps Dashboard plugin
- [ ] Multi-cluster support
- [ ] Advanced cost analytics
- [ ] Karpenter Support? 
- [ ] Bring your own Application to test with 
- [ ] NetApp Trident / Cloud Insights integration for Storage control (and testing)

---

## 📞 Support Channels

- 📖 [Flexera Docs](https://docs.spot.io)
- 💬 [Spot Slack](https://community.spot.io)
- 🐛 GitHub Issues

---

## 🔧 Usage Examples

### Basic Demo Deployment
```bash
# Deploy just the demo application
./scripts/deploy.sh --provider=gke
```

### Full Production Stack
```bash
# Deploy with LaunchDarkly + Spot API integration
./scripts/prod_deploy_preview.sh --provider=gke

# Monitor middleware logs
kubectl logs -f deployment/ld-spot-middleware -n oceansurge

# Check scaling status
kubectl get hpa -n oceansurge
```

### Testing the Integration
```bash
# Create the cost optimizer flag in LaunchDarkly
# Toggle flag ON → Cluster scales down for cost optimization
# Toggle flag OFF → Cluster scales up for performance

# Monitor scaling in Spot Console
# Check middleware webhook logs
kubectl logs -f deployment/ld-spot-middleware -n oceansurge
```

---

**Version**: v0.1.1-rebase  
**Status**: NOT PRODUCTION READY - For Alpha Testing Only -   
Made with ❤️ for the FinOps Practicioner and Developer Community