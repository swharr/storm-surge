#!/bin/bash
set -e

echo "Updating OceanSurge Repository References"
echo "============================================"

# Check if we're in the right directory
if [[ ! $(basename "$PWD") == "ocean-surge" ]] && [[ ! $(basename "$PWD") == "OceanSurge" ]]; then
    echo "WARN: Please run this script from your ocean-surge or OceanSurge directory"
    echo "Current directory: $PWD"
    exit 1
fi

echo "Updating repository references to OceanSurge..."

# Update README.md
echo "Updating README.md..."
sed -i.bak 's|github.com/your-username/storm-surge|github.com/Shon-Harris_flexera/OceanSurge|g' README.md
sed -i.bak 's|github.com/YOUR-USERNAME/storm-surge|github.com/Shon-Harris_flexera/OceanSurge|g' README.md
sed -i.bak 's|#storm-surge|#oceansurge|g' README.md
sed -i.bak 's|storm-surge/|OceanSurge/|g' README.md

# Update all documentation files
echo "Updating documentation files..."
find docs/ -name "*.md" -type f -exec sed -i.bak 's|storm-surge|OceanSurge|g' {} \; 2>/dev/null || true

# Update Kubernetes manifests to use consistent naming
echo "Updating Kubernetes manifests..."
find manifests/ -name "*.yaml" -type f -exec sed -i.bak 's|namespace: storm-surge|namespace: oceansurge|g' {} \; 2>/dev/null || true
find manifests/ -name "*.yaml" -type f -exec sed -i.bak 's|name: storm-surge|name: oceansurge|g' {} \; 2>/dev/null || true

# Update scripts with proper references
echo "Updating scripts..."
find scripts/ -name "*.sh" -type f -exec sed -i.bak 's|storm-surge|oceansurge|g' {} \; 2>/dev/null || true

# Update Python files
echo "Updating Python files..."
find finops/ -name "*.py" -type f -exec sed -i.bak 's|storm-surge|oceansurge|g' {} \; 2>/dev/null || true

# Update configuration files
echo "Updating configuration files..."
find configs/ -name "*.json" -type f -exec sed -i.bak 's|storm-surge|oceansurge|g' {} \; 2>/dev/null || true

# Update chaos testing scripts
echo "Updating chaos testing scripts..."
find chaos-testing/ -name "*.sh" -type f -exec sed -i.bak 's|storm-surge|oceansurge|g' {} \; 2>/dev/null || true

echo "Creating updated namespace configuration..."

# Create proper namespace manifest
cat > manifests/base/namespace.yaml << 'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: oceansurge
  labels:
    name: oceansurge
    app.kubernetes.io/name: storm-surge
    app.kubernetes.io/part-of: oceansurge
    storm-surge.io/managed: "true"
EOF

echo "Updating Kustomization files..."

# Update kustomization files
cat > manifests/base/kustomization.yaml << 'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: oceansurge

resources:
- namespace.yaml
- storm-surge-app.yaml

commonLabels:
  app.kubernetes.io/name: storm-surge
  app.kubernetes.io/part-of: oceansurge
  app.kubernetes.io/version: v1.0

images:
- name: storm-surge/frontend
  newTag: v1.0
EOF

# Create finops kustomization
mkdir -p manifests/finops
cat > manifests/finops/kustomization.yaml << 'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: oceansurge

resources:
- ../base
- finops-controller.yaml

commonLabels:
  app.kubernetes.io/name: storm-surge
  app.kubernetes.io/component: finops
  app.kubernetes.io/part-of: oceansurge
EOF

echo "Updating git configuration..."

# Update git remote if it exists
if git remote get-url origin 2>/dev/null; then
    echo "Updating git remote URL..."
    git remote set-url origin https://github.com/swharr/storm-surge.git
fi

echo "Updating deployment scripts with correct repository..."

# Update main deployment script
cat > scripts/deploy.sh << 'EOF'
#!/bin/bash
set -e

echo "Deploying Storm Surge from OceanSurge Repository"
echo "=================================================="

# Check prerequisites
if ! command -v kubectl &> /dev/null; then
    echo "ERROR: kubectl not found. Please install kubectl."
    exit 1
fi

if ! kubectl cluster-info &> /dev/null; then
    echo "ERROR: kubectl not connected to cluster."
    exit 1
fi

echo "OK: Prerequisites check passed"

# Create namespace
echo "Creating oceansurge namespace..."
kubectl apply -f manifests/base/namespace.yaml

# Deploy base application
echo "Deploying Storm Surge application..."
kubectl apply -k manifests/base/

# Wait for deployment
echo "Waiting for deployment..."
kubectl wait --for=condition=available --timeout=300s deployment --all -n oceansurge

# Get frontend URL
echo "Getting frontend URL..."
FRONTEND_IP=$(kubectl get service frontend-service -n oceansurge -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending")

echo "OK: Storm Surge deployed successfully!"
echo ""
echo "Frontend URL: http://$FRONTEND_IP"
echo "Monitor with: kubectl get pods -n oceansurge"
echo "Logs: kubectl logs -l app=frontend -n oceansurge"
echo ""
echo "Ready to weather the scaling storm!"
echo "Repository: https://github.com/swharr/storm-surge"
EOF

# Update load test script
cat > scripts/load-test.sh << 'EOF'
#!/bin/bash

INTENSITY=${1:-"moderate"}
DURATION=${2:-"300"}

echo "Starting $INTENSITY storm for ${DURATION}s"
echo "Repository: OceanSurge by Shon-Harris_flexera"

# Get frontend URL
FRONTEND_URL=$(kubectl get service frontend-service -n oceansurge -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

if [ -z "$FRONTEND_URL" ]; then
    echo "ERROR: Frontend service not ready"
    echo "Check: kubectl get svc -n oceansurge"
    exit 1
fi

case $INTENSITY in
    "light")
        CONCURRENT=10
        ;;
    "moderate")
        CONCURRENT=25
        ;;
    "severe")
        CONCURRENT=50
        ;;
    "hurricane")
        CONCURRENT=100
        ;;
    *)
        echo "ERROR: Invalid intensity. Use: light, moderate, severe, hurricane"
        exit 1
        ;;
esac

echo "Generating storm with $CONCURRENT concurrent requests"
echo "Target: http://$FRONTEND_URL"

# Use curl if wrk not available
if command -v wrk &> /dev/null; then
    wrk -t4 -c$CONCURRENT -d${DURATION}s http://$FRONTEND_URL
else
    echo "Using curl (install wrk for better load testing)"
    for i in $(seq 1 $CONCURRENT); do
        (
            for j in $(seq 1 $((DURATION/5))); do
                curl -s "http://$FRONTEND_URL" > /dev/null
                sleep 5
            done
        ) &
    done
    wait
fi

echo "OK: Storm complete!"
echo "Check scaling: kubectl get pods -n oceansurge"
EOF

# Update FinOps deployment script
cat > scripts/deploy-finops.sh << 'EOF'
#!/bin/bash
set -e

echo "Deploying Storm Surge FinOps Controller (OceanSurge Repository)"
echo "=================================================================="

# Check environment variables
if [ -z "$SPOT_API_TOKEN" ]; then
    echo "⚠️  SPOT_API_TOKEN not set - using demo mode"
    export SPOT_API_TOKEN="demo-token"
fi

if [ -z "$LAUNCHDARKLY_SDK_KEY" ]; then
    echo "⚠️  LAUNCHDARKLY_SDK_KEY not set - using demo mode"
    export LAUNCHDARKLY_SDK_KEY="demo-key"
fi

# Create namespace if it doesn't exist
kubectl apply -f manifests/base/namespace.yaml

echo "🔑 Creating secrets..."
kubectl create secret generic finops-credentials \
    --from-literal=spot-token="$SPOT_API_TOKEN" \
    --from-literal=launchdarkly-key="$LAUNCHDARKLY_SDK_KEY" \
    --namespace=oceansurge \
    --dry-run=client -o yaml | kubectl apply -f -

echo "📦 Deploying FinOps controller..."
if [ -f "manifests/finops/finops-controller.yaml" ]; then
    kubectl apply -k manifests/finops/
else
    echo "⚠️  FinOps manifests not found. Copy from artifacts first."
    echo "   See: manifests/finops/ directory"
fi

echo "✅ FinOps controller deployment complete!"
echo "💡 Repository: https://github.com/swharr/storm-surge"
echo "💡 Copy full implementation from artifacts for production use"
EOF

# Make scripts executable
chmod +x scripts/*.sh

echo "🏷️ Creating proper Git tags..."

# Create version tags
cat > .gittags << 'EOF'
# Git tagging strategy for OceanSurge
# Repository: https://github.com/swharr/storm-surge

# v1.0 - Storm Surge (Initial Release)
git tag -a v1.0-storm-surge -m "🌩️ Storm Surge v1.0 - First Storm

The inaugural release from OceanSurge repository!
Product name: Storm Surge
Repository: OceanSurge

Features:
⚡ Realistic e-commerce workloads
🌊 Spot Ocean integration
💰 FinOps cost optimization with LaunchDarkly
🔥 Chaos engineering capabilities
☁️ Multi-cloud support (AWS, GCP, Azure)
📊 Built-in monitoring and load testing

Ready to weather any Kubernetes scaling storm!"

# Future releases
# v1.1 - Lightning Strike
# v1.2 - Thunder Roll
# v2.0 - Perfect Storm
EOF

echo "📚 Updating documentation with repository info..."

# Update architecture docs
cat > docs/REPOSITORY.md << 'EOF'
# 📁 OceanSurge Repository Guide

## Repository Information

- **Repository Name**: OceanSurge
- **Repository URL**: https://github.com/swharr/storm-surge
- **Product Name**: Storm Surge
- **Namespace**: oceansurge

## Naming Convention

We use a dual naming strategy:

### Repository Level
- **GitHub Repository**: `OceanSurge`
- **Kubernetes Namespace**: `oceansurge`
- **Docker Images**: `oceansurge/service-name`

### Product Level
- **Product Name**: Storm Surge
- **Version Tags**: `v1.0-storm-surge`
- **Documentation**: References "Storm Surge"
- **UI/Frontend**: Displays "Storm Surge"

## Quick Commands

```bash
# Clone repository
git clone https://github.com/swharr/storm-surge.git

# Deploy Storm Surge
cd OceanSurge
./scripts/deploy.sh

# Monitor in oceansurge namespace
kubectl get pods -n oceansurge

# Access frontend
kubectl get svc frontend-service -n oceansurge
```

## Repository Structure

```
OceanSurge/                    # Repository root
├── manifests/
│   ├── base/                  # Core Storm Surge app
│   ├── finops/               # FinOps controller
│   └── ocean/                # Spot Ocean configs
├── scripts/                   # Deployment scripts
├── chaos-testing/             # Chaos engineering
├── finops/                    # Python FinOps code
└── docs/                      # Documentation
```

This structure maintains clarity between the repository name (OceanSurge) and the product name (Storm Surge).
EOF

echo "🧹 Cleaning up backup files..."
find . -name "*.bak" -delete 2>/dev/null || true

echo "✅ Repository update complete!"
echo ""
echo "📋 Summary:"
echo "  Repository: OceanSurge"
echo "  Product: Storm Surge"
echo "  Namespace: oceansurge"
echo "  URL: https://github.com/swharr/storm-surge"
echo ""
echo "🚀 Ready to commit and push:"
echo "  git add ."
echo "  git commit -m '📁 Update repository references for OceanSurge'"
echo "  git push -u origin main"
echo ""
echo "🏷️ To create version tag:"
echo "  git tag -a v1.0-storm-surge -m '🌩️ Storm Surge v1.0 - First Storm'"
echo "  git push origin v1.0-storm-surge"
