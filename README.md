# 🌊 Storm Surge: Kubernetes Elasticity + FinOps Testing with Spot Ocean + Feature Flags

![Kubernetes](https://img.shields.io/badge/kubernetes-%23326ce5.svg?style=for-the-badge&logo=kubernetes&logoColor=white)
![LaunchDarkly](https://img.shields.io/badge/LaunchDarkly-Feature--Flags-blue?style=for-the-badge)
![Statsig](https://img.shields.io/badge/Statsig-Feature--Flags-purple?style=for-the-badge)
![Flexera Spot](https://img.shields.io/badge/Flexera--Spot-Ocean-blue?style=for-the-badge)
![Spot.io](https://img.shields.io/badge/Spot.io-Ocean-blue?style=for-the-badge)
![AWS](https://img.shields.io/badge/AWS-%23FF9900.svg?style=for-the-badge&logo=amazon-aws&logoColor=white)
![Google Cloud](https://img.shields.io/badge/GoogleCloud-%234285F4.svg?style=for-the-badge&logo=google-cloud&logoColor=white)
![Azure](https://img.shields.io/badge/azure-%230072C6.svg?style=for-the-badge&logo=microsoftazure&logoColor=white)

A FinOps-focused microservices demo app for testing real-time scaling, feature flag toggling, and infrastructure cost optimization — designed to run on **GKE**, **EKS**, or **AKS** using the Hyperscaler provided Managed Kubernetes with **Spot Ocean** and either **LaunchDarkly** or **Statsig** as your feature flag provider.

### ⚡ Feature Flag Provider Support

Storm Surge integrates with **either** LaunchDarkly **OR** Statsig for feature flag management:

| Provider | Flag Type | Flag Name | Webhook URL |
|----------|-----------|-----------|-------------|
| **LaunchDarkly** | Boolean Flag | `enable-cost-optimizer` | `/webhook/launchdarkly` |
| **Statsig** | Feature Gate | `enable_cost_optimizer` | `/webhook/statsig` |

**🚨 Important**: Choose **ONE** provider during setup. Both providers cannot be used simultaneously in the same deployment.

### 🎯 Key Features

- **Intelligent Region/Zone Selection**: Interactive deployment with validation for all cloud providers
- **Robust Retry Logic**: Automatic retry mechanisms for deployment operations with configurable timeouts
- **Embedded Local Testing**: Built-in validation suite with security checks and offline-capable manifest validation
- **Enhanced Security**: Comprehensive security controls, RBAC validation, and insecure port hardening
- **Security Workloads**: Integrated security validation tests and defensive security measures (GKE-specific)
- **Cluster Management**: Smart cluster detection with options to reuse or recreate existing clusters
- **Custom Cluster Naming**: Support for user-defined cluster names with validation and fallback defaults
- **Shell Script Robustness**: ShellCheck compliant scripts with proper error handling and input validation

---

## 🚀 Highlights

- ⚙️ **Feature Flag Integration**: Real-time feature flag control with webhook middleware using either **LaunchDarkly** or **Statsig** to monitor and fire off infrastructure changes
- 🌊 **Spot Ocean API**: Automated cluster scaling based on cost optimization flags from your chosen feature flag provider.
- 🛠️ **Multi-Cloud**: Deploy to GCP, AWS, or Azure with unified CLI (You need to have the API and CLI tools included)
- 📈 **Cost Tracking**: Infrastructure impact monitoring via feature flag changes
- 🔄 **Automated Scaling**: Dynamic right-sizing and node pool optimization
- 🌐 **Production Ready**: Complete middleware with ingress, secrets, and monitoring
- 💥 **Load Testing**: Built-in chaos testing and performance validation to simulate activity and show responsiveness

---

## 🧪 How It Works

You use feature flags from either **LaunchDarkly** or **Statsig** (like `enable-cost-optimizer` or `enable_cost_optimizer`) to toggle infrastructure behavior, which is reflected in your app and metrics.

**Important**: Storm Surge supports either LaunchDarkly **OR** Statsig as your feature flag provider, but not both simultaneously. Choose the provider that best fits your organization's needs during setup.

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

# With custom cluster naming
./scripts/deploy.sh --provider=gke --cluster-name=my-custom-cluster --region=us-central1 --zone=us-central1-a
```

### Enhanced Deployment Logic
The main deployment script (`scripts/deploy.sh`) includes comprehensive improvements:

- **Intelligent Argument Parsing**: Robust command-line argument handling with validation and help system
- **Provider Configuration**: Built-in region/zone mappings for GKE, EKS, and AKS with validation
- **Interactive Mode**: User-friendly prompts for provider, region, zone, and cluster configuration
- **Non-Interactive Mode**: `--yes` flag for automated deployments with sensible defaults
- **Existing Cluster Detection**: Smart detection of existing clusters with user choice options:
  - Deploy workloads only (faster, reuses existing cluster)
  - Delete and recreate cluster (slower, fresh start)
  - Cancel deployment
- **Multi-Provider Support**: Deploy to single provider or all providers with unified interface
- **Custom Cluster Naming**: Support for custom cluster names with alphanumeric validation and automatic fallback to defaults
- **Environment Variable Loading**: Automatic `.env` file loading for configuration
- **CLI Tool Validation**: Checks for required CLI tools (gcloud, aws, az) before deployment

### GKE Security Enhancements
The GKE deployment script (`scripts/providers/gke.sh`) includes enhanced security features:

- **Cluster Hardening**: Creates clusters with shielded nodes, private networking, and disabled legacy authorization
- **Security Workloads**: Automatically deploys RBAC authentication mapping, namespace role bindings, and validation test pods
- **Insecure Port Detection**: Comprehensive scanning for insecure ports (10255, 10250-10256, 2379-2380)
- **Network Policies**: Applies restrictive network policies blocking insecure kubelet access
- **Automatic Lockdown**: Executes security lockdown script (`lockitdown.sh`) when security issues are detected
- **RBAC Validation**: Verifies proper role-based access control configuration post-deployment

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

The production script will collect your chosen feature flag provider credentials (LaunchDarkly SDK key OR Statsig server key), Spot API token, and cluster configuration interactively.

---

## 🧪 Local Testing & Validation

### Quick Local Tests
```bash
# Run embedded local validation suite (now supports offline validation)
./test-local.sh

# Full test suite with comprehensive checks
./tests/test-suite.sh
```

### Offline Validation Support
The testing suite now supports offline validation when no Kubernetes cluster is available:

```bash
# Install standalone kustomize for offline validation (recommended)
curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash
sudo mv kustomize /usr/local/bin/

# Validation priorities:
# 1. Standalone kustomize (offline-friendly)
# 2. kubectl with cluster connection (full validation)
# 3. Basic YAML syntax validation (fallback)
```

The validation scripts automatically detect available tools and connectivity, providing graceful fallbacks for offline environments.

### Pre-commit Hooks Setup
```bash
# Install pre-commit hooks for automated validation
pip install pre-commit
pre-commit install

# Run pre-commit on all files manually
pre-commit run --all-files

# Pre-commit automatically runs on git commits to validate:
# - YAML syntax and formatting
# - Markdown lint checks
# - Trailing whitespace removal
# - End-of-file formatting
```

### Advanced Test Suites
```bash
# Run individual test suites
python3 tests/test_middleware.py        # Middleware and Flask API tests
python3 tests/test_security.py          # Security and compliance tests
python3 tests/test_scripts.py           # Script validation tests

# Run FinOps controller tests (requires virtual environment)
python3 -m venv finops-venv
source finops-venv/bin/activate
pip install -r finops/requirements.txt
python3 finops/tests/test_basic.py
python3 finops/tests/test_finops_controller.py
python3 finops/tests/test_integration.py
```

### Test Coverage

#### 🧪 **Comprehensive Test Suite (104/112 tests passing - 92.9% success rate)**

**FinOps Controller Tests** (43/43 tests - 100% ✅)
- Controller initialization and method validation
- Environment variable handling and configuration
- LaunchDarkly integration readiness testing
- Spot Ocean API integration scenarios
- Business hours and timezone handling
- Error handling and failure recovery

**Middleware Tests** (21/24 tests - 87.5% ✅)
- Flask application endpoint testing (health, cluster status)
- LaunchDarkly webhook handling and validation
- Spot Ocean API integration and scaling operations
- Security validation (HMAC signatures, input validation)
- Error handling scenarios and edge cases

**Security Tests** (15/19 tests - 78.9% ✅)
- Kubernetes security configurations (security contexts, resource limits)
- Container image security (no :latest tags, trusted registries)
- Secrets management (no hardcoded secrets, proper Secret resources)
- Script security (permissions, credentials, shebangs)
- Dockerfile security practices and compliance checks

**Script Validation Tests** (25/26 tests - 96.2% ✅)
- Script syntax validation and structure
- Deployment script functionality and parameter validation
- Cloud provider script authentication and region validation
- Utility script testing and security aspects
- Documentation and help functionality

#### 🔧 **Legacy Test Coverage**
- **Script Syntax**: Validates all bash scripts for syntax errors
- **Parameter Validation**: Tests deployment script argument handling
- **Zone/Region Validation**: Ensures proper region-zone combinations
- **Kubernetes Manifests**: Validates all YAML manifests with kustomize
- **Security Configuration**: Checks for runAsNonRoot, resource limits
- **Secret Detection**: Scans for hardcoded credentials
- **Insecure Port Detection**: Validates cluster configuration for insecure ports
- **RBAC Validation**: Tests role-based access control configuration

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

## ⚙️ Feature Flag Provider Setup

Storm Surge supports **either** **LaunchDarkly** **OR** **Statsig** for feature flag management. You must choose one provider during setup - both cannot be used simultaneously. Use the interactive configuration script to set up your preferred provider.

### Quick Setup
```bash
# Interactive configuration for feature flag provider
python feature_flag_configure.py
```

### Manual Configuration

#### LaunchDarkly Setup
1. Create a boolean flag: `enable-cost-optimizer`
2. Get your **Server-side SDK key** from LaunchDarkly (Account Settings > Projects > Environment)
3. Configure webhook endpoint (after deployment):
   - URL: `https://your-domain.com/webhook/launchdarkly`
   - Secret: Generated during deployment

#### Statsig Setup
1. Create a feature gate: `enable_cost_optimizer`
2. Get your **Server Key** from Statsig Console (Project Settings > Keys & Environments)
3. Configure webhook endpoint (after deployment):
   - URL: `https://your-domain.com/webhook/statsig`
   - Secret: Generated during deployment

### Spot API Configuration
**Pre-Requisite**: You need to have a Spot Console (https://console.spotinst.com) base organization set up with your Admin account verified.
1. Get your **Spot API token** from Spot Console (Settings > API)
2. Find your **Spot Cluster ID** (Ocean > Clusters)
3. Ensure cluster has proper permissions for scaling

### Environment Variables
```bash
# Required for production deployment
export FEATURE_FLAG_PROVIDER="launchdarkly"  # or "statsig" (choose ONE)

# For LaunchDarkly (if FEATURE_FLAG_PROVIDER="launchdarkly")
export LAUNCHDARKLY_SDK_KEY="api-integration-key-from-ld-here"

# For Statsig (if FEATURE_FLAG_PROVIDER="statsig") 
export STATSIG_SERVER_KEY="secret-server-key-from-statsig"

# Required for all deployments
export SPOT_API_TOKEN="your-spot-api-token"
export SPOT_CLUSTER_ID="ocn-cluster-id"
export WEBHOOK_SECRET="your-webhook-secret"
```

**⚠️ Important**: Only set the environment variables for your chosen provider. Do not set both `LAUNCHDARKLY_SDK_KEY` and `STATSIG_SERVER_KEY` simultaneously.

4. Toggle the flag → see automated cluster scaling in real time

---

## ☁️ Cloud Provider Support

| Provider | Script                              | Requirements          | Security Features |
|----------|-------------------------------------|------------------------|-------------------|
| GKE      | `scripts/providers/gke.sh`          | `gcloud`, enabled APIs | Enhanced security hardening, insecure port detection, RBAC validation |
| EKS      | `scripts/providers/eks.sh`          | `aws`, `eksctl`        | Standard security controls |
| AKS      | `scripts/providers/aks.sh`          | `az`, login session    | Standard security controls |

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
│   ├── sec_fixes/                   # Security validation and hardening (GKE-specific)
│   │   ├── rbac_authmap.yaml        # RBAC authentication mapping
│   │   ├── rbac_namespace_fix.yaml  # RBAC namespace role binding
│   │   └── sectest_validate.yaml    # Security validation test pod
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
- [x] **Security Hardening**: Embedded security checks and validation with insecure port detection
- [x] **Local Testing Suite**: Built-in validation with syntax, security, and offline-capable manifest checks
- [x] **Cluster Management**: Smart detection and handling of existing clusters
- [x] **Interactive Configuration**: User-friendly deployment with guided setup
- [x] **Enhanced Deployment Logic**: Improved argument parsing, validation, and multi-provider support with intelligent defaults
- [x] **Existing Cluster Management**: Smart detection and handling of existing clusters with user choice options
- [x] **Security Workloads Integration**: RBAC validation, authenticated kubelet access testing, and defensive security measures (GKE-specific)
- [x] **Enhanced GKE Security**: Integrated security workloads deployment, comprehensive insecure port detection, and automatic security lockdown script execution
- [x] **Offline Validation Support**: Standalone kustomize validation with graceful fallbacks for offline environments
- [x] **Shell Script Quality**: ShellCheck compliant scripts with proper quoting, error handling, and input validation
- [ ] **Feature Flag Webhook Integration**: Real-time feature flag processing for LaunchDarkly and Statsig (In Progress)
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
- **Insecure port hardening**: Automatic detection and mitigation of insecure ports (10255, 10250-10256, 2379-2380) - GKE deployments
- **Network policies**: Restrictive network policies blocking insecure kubelet access - GKE deployments
- **RBAC validation**: Comprehensive role-based access control with authenticated kubelet access testing - GKE deployments
- **Security workloads**: Integrated security validation pods and defensive security measures - GKE deployments
- **Cluster hardening**: Enhanced GKE cluster creation with shielded nodes, private networking, and disabled legacy authorization

> **Note**: The security workloads in `manifests/sec_fixes/` are specifically designed for GKE deployments to address Google Cloud-specific security configurations. **AKS and EKS users do not need these security fixes** as Azure and AWS managed Kubernetes services have different security models and built-in protections.

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
- 💬 [Spot Slack](https://community.flexera.com)
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
# Deploy with feature flag provider + Spot API integration
./scripts/prod_deploy_preview.sh --provider=gke

# Monitor middleware logs
kubectl logs -f deployment/ld-spot-middleware -n oceansurge

# Check scaling status
kubectl get hpa -n oceansurge
```

### Testing the Integration
```bash
# Create the cost optimizer flag in your chosen provider:
# - LaunchDarkly: Create boolean flag "enable-cost-optimizer" 
# - Statsig: Create feature gate "enable_cost_optimizer"
# 
# Toggle flag ON → Cluster scales down for cost optimization
# Toggle flag OFF → Cluster scales up for performance

# Monitor scaling in Spot Console
# Check middleware webhook logs
kubectl logs -f deployment/ld-spot-middleware -n oceansurge

# Run local validation before deployment
./test-local.sh

# Test specific provider deployment with custom cluster name
export STORM_REGION="us-central1"
export STORM_ZONE="us-central1-a"
export STORM_NODES="3"
export STORM_CLUSTER_NAME="my-test-cluster"
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

**Custom Cluster Naming**
```bash
# Interactive mode prompts for cluster name
./scripts/deploy.sh --provider=gke
# Enter custom name or press Enter for default: storm-surge-gke

# Non-interactive mode with custom name
./scripts/deploy.sh --provider=gke --cluster-name=production-cluster --yes

# Invalid names automatically fall back to defaults
./scripts/deploy.sh --provider=gke --cluster-name=invalid@name --yes
# Will use: storm-surge-gke (default)
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

**Version**: beta-v1.1.0
**Updated**: 2025-07-24 - Beta release with complete authentication system, user management, role-based access control, and comprehensive frontend integration
**Status**: BETA RELEASE - Ready for Testing and Evaluation -
Made with ❤️ for the FinOps Practicioner and Developer Community
