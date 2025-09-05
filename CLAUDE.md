# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Storm-Surge (OceanSurge) is a FinOps-focused platform that demonstrates real-time infrastructure cost optimization through feature flag toggles. It integrates LaunchDarkly/Statsig feature flags with Spot Ocean API to enable dynamic Kubernetes cluster scaling based on cost optimization strategies.

## Key Commands

### Frontend Development (React Dashboard)
```bash
cd frontend
npm install              # Install dependencies
npm run dev              # Start development server (Vite)
npm run build            # Build production bundle
npm run lint             # Run ESLint checks
npm run test             # Run Vitest tests
```

### Python Components (Middleware/FinOps)
```bash
# Middleware Flask API
cd manifests/middleware
pip install -r requirements.txt

# FinOps Controller
cd finops
pip install -r requirements.txt
python finops_controller.py

# Run Python tests
python3 tests/test_middleware.py
python3 tests/test_security.py
python3 tests/test_scripts.py
python3 finops/tests/test_finops_controller.py
```

### Deployment & Testing
```bash
# Interactive deployment with region/zone selection
./scripts/deploy.sh --provider=gke   # or eks | aks

# Production deployment with all integrations
./scripts/prod_deploy_preview.sh --provider=gke

# Local validation & testing
./test-local.sh                      # Quick validation suite
./tests/test-suite.sh                 # Comprehensive test suite

# Pre-commit hooks
pre-commit install
pre-commit run --all-files

# Cleanup clusters
./scripts/cleanup/cluster-sweep.sh
```

### Kubernetes Operations
```bash
# Deploy middleware
kubectl apply -k manifests/middleware/
kubectl get pods -n oceansurge
kubectl logs -f deployment/ld-spot-middleware -n oceansurge

# Port forward for testing
kubectl port-forward -n oceansurge svc/feature-flag-middleware 8000:80

# Check HPA status
kubectl get hpa -n oceansurge
```

## Architecture Overview

### Core Integration Flow
The system connects feature flags to infrastructure scaling through this flow:
1. **Feature Flag Change** → Webhook triggers middleware
2. **Middleware** validates and processes the change via Flask API
3. **Spot Ocean API** receives scaling commands based on flag state
4. **Cluster Scaling** executes (cost optimization vs performance mode)
5. **WebSocket Events** notify the frontend dashboard in real-time

### Component Architecture

**Middleware (`manifests/middleware/`)**: Flask-based bridge between feature flag providers and Spot Ocean API. Handles webhook verification, provider abstraction (LaunchDarkly/Statsig), and WebSocket communication.

**FinOps Controller (`finops/`)**: Scheduled optimization controller for time-based scaling (business hours vs after-hours). Currently placeholder implementation with scheduling framework.

**Deployment Scripts (`scripts/`)**: Multi-cloud deployment orchestration with provider abstraction. Unified interface (`deploy.sh`) delegates to provider-specific scripts (gke.sh, eks.sh, aks.sh) with retry logic and smart cluster detection.

**Frontend Dashboard (`frontend/`)**: React + TypeScript dashboard with Vite bundler. Real-time WebSocket integration, React Query for state management, and comprehensive monitoring UI for flags, clusters, and costs.

**Kubernetes Resources (`manifests/`)**: Kustomize-based configuration with dedicated `oceansurge` namespace. Organized into base/, middleware/, finops/, and sec_fixes/ (GKE-specific security).

### Key Integration Points

**Feature Flag Providers**: Abstract provider pattern supports both LaunchDarkly and Statsig. Configure via `feature_flag_configure.py` or environment variables.

**Spot Ocean API**: Cluster scaling integration requires SPOT_API_TOKEN and SPOT_CLUSTER_ID. Handles scaling operations based on `enable-cost-optimizer` flag state.

**Multi-Cloud Support**: Deployment scripts support GKE, EKS, and AKS with region/zone validation. Interactive mode guides through configuration, non-interactive mode uses defaults.

**WebSocket Events**: Real-time bidirectional communication between middleware and frontend. Events include flag changes, scaling operations, alerts, and metrics updates.

## Testing Approach

Run tests at multiple levels:
- **Unit Tests**: Python test files in `tests/` and `finops/tests/`
- **Integration Tests**: `test-local.sh` validates manifests and scripts
- **Pre-commit Hooks**: Automated validation on git commits
- **Manual Testing**: Deploy to local cluster and use port-forwarding

Security validations include checking for hardcoded secrets, insecure ports (GKE), proper RBAC configuration, and webhook signature verification.
- Always use descriptive variable names