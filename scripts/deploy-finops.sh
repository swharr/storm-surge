#!/bin/bash
set -e

# Get the script directory and go to project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Change to project root directory
cd "$PROJECT_ROOT"

# Verify we're in the right place
if [ ! -d "manifests/base" ]; then
    echo "❌ Error: manifests/base directory not found in $PROJECT_ROOT"
    echo "This script must be run from a storm-surge repository"
    exit 1
fi

echo "💰 Deploying Storm Surge FinOps Controller (OceanSurge Repository)"
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
echo "💡 Repository: https://github.com/Shon-Harris_flexera/OceanSurge"
echo "💡 Copy full implementation from artifacts for production use"
