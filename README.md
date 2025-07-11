# 🌊 OceanSurge: Kubernetes Elasticity + FinOps Testing with Spot Ocean + LaunchDarkly

![Kubernetes](https://img.shields.io/badge/kubernetes-%23326ce5.svg?style=for-the-badge&logo=kubernetes&logoColor=white)
![LaunchDarkly](https://img.shields.io/badge/LaunchDarkly-Feature--Flags-blue?style=for-the-badge)
![Flexera Spot](https://img.shields.io/badge/Flexera--Spot-Ocean-blue?style=for-the-badge)
![Spot.io](https://img.shields.io/badge/Spot.io-Ocean-blue?style=for-the-badge)
![AWS](https://img.shields.io/badge/AWS-%23FF9900.svg?style=for-the-badge&logo=amazon-aws&logoColor=white)
![Google Cloud](https://img.shields.io/badge/GoogleCloud-%234285F4.svg?style=for-the-badge&logo=google-cloud&logoColor=white)
![Azure](https://img.shields.io/badge/azure-%230072C6.svg?style=for-the-badge&logo=microsoftazure&logoColor=white)

A FinOps-focused microservices demo app for testing real-time scaling, feature flag toggling, and infrastructure cost optimization — designed to run on **GKE**, **EKS**, or **AKS** using the Hyperscaler provided Managed Kubernetes with **Spot Ocean** and **LaunchDarkly**.

### 🎯 Key Features

- **Intelligent Region/Zone Selection**: Interactive deployment with validation for all cloud providers
- **Robust Retry Logic**: Automatic retry mechanisms for deployment operations with configurable timeouts
- **Embedded Local Testing**: Built-in validation suite with security checks and manifest validation
- **Enhanced Security**: Comprehensive security controls and validation throughout deployment
- **Cluster Management**: Smart cluster detection with options to reuse or recreate existing clusters

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

# Interactive deployment with region/zone selection
./scripts/deploy.sh --provider=gke   # or eks | aks | all

# Or specify parameters directly
./scripts/deploy.sh --provider=gke --region=us-central1 --zone=us-central1-a --nodes=4
```

### Supported Regions & Zones

**GKE (Google Cloud)**
- `us-central1` (Iowa): zones a, b, c, f
- `us-east1` (South Carolina): zones b, c, d
- `us-west1` (Oregon): zones a, b, c
- `us-west2` (California): zones a, b, c
- `europe-west1` (Belgium): zones b, c, d
- `asia-east1` (Taiwan): zones a, b, c

**EKS (AWS)**
- `us-east-1` (N. Virginia): zones a, b, c, d, e, f
- `us-east-2` (Ohio): zones a, b, c
- `us-west-1` (N. California): zones a, c
- `us-west-2` (Oregon): zones a, b, c, d
- `eu-west-1` (Ireland): zones a, b, c
- `ap-southeast-1` (Singapore): zones a, b, c

**AKS (Azure)**
- `eastus` (East US): zones 1, 2, 3
- `westus2` (West US 2): zones 1, 2, 3
- `centralus` (Central US): zones 1, 2, 3
- `westeurope` (West Europe): zones 1, 2, 3
- `southeastasia` (Southeast Asia): zones 1, 2, 3

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

## 🧪 Local Testing & Validation

### Quick Local Tests
```bash
# Run embedded local validation suite
./test-local.sh

# Full test suite with comprehensive checks
./tests/test-suite.sh
```

### Test Coverage
- **Script Syntax**: Validates all bash scripts for syntax errors
- **Parameter Validation**: Tests deployment script argument handling
- **Zone/Region Validation**: Ensures proper region-zone combinations
- **Kubernetes Manifests**: Validates all YAML manifests with kustomize
- **Security Configuration**: Checks for runAsNonRoot, resource limits
- **Secret Detection**: Scans for hardcoded credentials

### Retry Logic & Error Handling

All deployment scripts include robust retry mechanisms:

```bash
# Environment variables for retry configuration
export STORM_RETRY_COUNT=3      # Number of retry attempts (default: 3)
export STORM_RETRY_DELAY=30     # Delay between retries in seconds (default: 30)
```

Retry logic applies to:
- Cluster creation operations
- Workload deployment
- Health check validations
- API calls to cloud providers

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
│   ├── deploy.sh                    # Interactive deployment with region/zone selection
│   ├── deploy-middleware.sh         # Middleware-only deployment
│   ├── deploy-finops.sh            # FinOps controller deployment
│   ├── test-local.sh               # Embedded local testing suite
│   ├── prod_deploy_preview.sh      # Production deployment with integrations
│   ├── cleanup/
│   │   └── cluster-sweep.sh         # Comprehensive cluster cleanup
│   └── providers/
│       ├── gke.sh                   # Google Kubernetes Engine with retry logic
│       ├── eks.sh                   # Amazon EKS with retry logic  
│       └── aks.sh                   # Azure AKS with retry logic
├── manifests/
│   ├── base/                        # Core application manifests
│   │   ├── kustomization.yaml
│   │   ├── deployments.yaml         # Core Application with web front end
│   │   ├── services.yaml
│   │   ├── configmaps.yaml
│   │   ├── namespace.yaml           # oceansurge namespace
│   │   └── hpa.yaml
│   ├── middleware/                  # API Controller Middleware
│   │   ├── kustomization.yaml
│   │   ├── deployment.yaml          # Python Flask middleware
│   │   ├── service.yaml             # LoadBalancer + Ingress
│   │   ├── configmap.yaml           # Application code + configuration
│   │   └── secret.yaml              # API keys and webhooks
│   └── finops/                      # FinOps controller manifests
│       └── kustomization.yaml
├── tests/
│   ├── test-suite.sh               # Comprehensive test suite
│   ├── hooks/                       # Git hooks for validation
│   │   ├── validate-deploy-scripts.sh
│   │   ├── validate-manifests.sh
│   │   └── validate-security.sh
│   └── README.md
├── finops/
│   ├── finops_controller.py         # FinOps controller implementation
│   ├── requirements.txt
│   └── tests/                       # FinOps-specific tests
├── logs/                            # Deployment logs
├── .env                            # Environment configuration
└── README.md
```

---

## 🎯 Current Status

- [x] **Enhanced Multi-Cloud Deployment**: GKE, EKS, AKS with intelligent region/zone selection
- [x] **Robust Error Handling**: Comprehensive retry logic and validation
- [x] **Security Hardening**: Embedded security checks and validation
- [x] **Local Testing Suite**: Built-in validation with syntax, security, and manifest checks
- [x] **Cluster Management**: Smart detection and handling of existing clusters
- [x] **Interactive Configuration**: User-friendly deployment with guided setup
- [ ] **LaunchDarkly Webhook Integration**: Real-time feature flag processing (In Progress)
- [ ] **Spot Ocean API Integration**: Automated cluster scaling (In Progress)
- [x] **Production Middleware**: Flask app with proper security
- [x] **Load Testing**: Built-in traffic generation and scaling tests
- [x] **Monitoring**: Health checks, logging, and status endpoints

### 🔒 Security Features

- **Non-root containers**: All deployments run with `runAsNonRoot: true`
- **Resource limits**: Comprehensive CPU/memory limits on all workloads
- **Secret management**: No hardcoded credentials, proper Kubernetes secrets
- **Namespace isolation**: Dedicated `oceansurge` namespace for all resources
- **Validation hooks**: Pre-commit hooks for security and syntax validation
- **Region restrictions**: Cloud deployment restricted to approved regions only

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

# Run local validation before deployment
./test-local.sh

# Test specific provider deployment
export STORM_REGION="us-central1"
export STORM_ZONE="us-central1-a" 
export STORM_NODES="3"
./scripts/providers/gke.sh
```

### Troubleshooting

**Zone/Region Mismatch**
```bash
# Error: Zone 'us-west-2-a' invalid for region 'us-central1'
# Solution: Use matching zone (us-central1-a) or different region
```

**Existing Cluster Detected**
```bash
# The deployment script will prompt you to:
# 1) Deploy workloads only (reuse existing cluster)
# 2) Delete and recreate cluster (fresh start)  
# 3) Cancel deployment
```

**Retry Logic in Action**
```bash
# Deployment operations will automatically retry on failure:
# 📋 Creating cluster (attempt 1/3)...
# ⚠️  Creating cluster failed, retrying in 30s...
# 📋 Creating cluster (attempt 2/3)...
# ✅ Creating cluster succeeded
```

---

**Version**: v0.1.4-alpha-poc  
**Status**: NOT PRODUCTION READY - For Alpha Testing Only -   
Made with ❤️ for the FinOps Practicioner and Developer Community