#!/bin/bash
set -e
set -o pipefail

# Resolve project root regardless of caller's CWD
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT"

if [ ! -d "manifests/base" ]; then
    echo "❌ Error: manifests/base directory not found in $PROJECT_ROOT" >&2
    echo "This script must be run from a storm-surge repository" >&2
    exit 1
fi

# Get configuration from environment or use defaults
REGION=${STORM_REGION:-"eastus"}
ZONE=${STORM_ZONE:-"1"}
NODES=${STORM_NODES:-"2"}
CLUSTER_NAME=${STORM_CLUSTER_NAME:-"storm-surge-aks"}
RESOURCE_GROUP="storm-surge-rg"
RETRY_COUNT=${STORM_RETRY_COUNT:-"3"}
RETRY_DELAY=${STORM_RETRY_DELAY:-"30"}

# Retry function for workload deployment
retry_command() {
    local description="$1"
    local max_attempts="$2"
    local delay="$3"
    shift 3
    local command=("$@")

    for ((attempt=1; attempt<=max_attempts; attempt++)); do
        echo "📋 $description (attempt $attempt/$max_attempts)..."

        if "${command[@]}"; then
            echo "✅ $description succeeded"
            return 0
        else
            if [ "$attempt" -lt "$max_attempts" ]; then
                echo "⚠️  $description failed, retrying in ${delay}s..."
                sleep "$delay"
            else
                echo "❌ $description failed after $max_attempts attempts"
                return 1
            fi
        fi
    done
}

echo "🛠️  Provisioning AKS Cluster..."
echo "   📍 Region: $REGION"
echo "   🗺️  Zone: $ZONE"
echo "   🖥️  Nodes: $NODES"
echo "   🏷️  Cluster: $CLUSTER_NAME"
echo "   📦 Resource Group: $RESOURCE_GROUP"
echo

if ! command -v az &> /dev/null; then
    echo "❌ Azure CLI not installed" >&2
    echo "   Install: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
fi

# Validate Azure authentication
if ! az account show &>/dev/null; then
    echo "❌ Not authenticated with Azure" >&2
    echo "   Run: az login"
    exit 1
fi

# Validate zone is valid (1, 2, or 3)
if [[ ! "$ZONE" =~ ^[123]$ ]]; then
    echo "❌ Invalid zone '$ZONE' for Azure" >&2
    echo "   Zone must be 1, 2, or 3"
    exit 1
fi

if [ "$STORM_SKIP_CLUSTER_CREATION" = "true" ]; then
  echo "⚡ Skipping cluster creation, using existing cluster..."
  echo "🔑 Getting cluster credentials..."
  az aks get-credentials --resource-group "$RESOURCE_GROUP" --name "$CLUSTER_NAME"
else
  echo "🔧 Creating resource group..."
  az group create --name "$RESOURCE_GROUP" --location "$REGION"

  echo "🔧 Creating AKS cluster with $NODES nodes..."
  az aks create --resource-group "$RESOURCE_GROUP" \
    --name "$CLUSTER_NAME" \
    --location "$REGION" \
    --zones "$ZONE" \
    --node-count "$NODES" \
    --node-vm-size Standard_B2s \
    --generate-ssh-keys \
    --enable-cluster-autoscaler \
    --min-count 1 \
    --max-count 10 \
    --enable-managed-identity \
    2>&1 | tee -a logs/aks-deploy.log

  echo "🔑 Getting cluster credentials..."
  az aks get-credentials --resource-group "$RESOURCE_GROUP" --name "$CLUSTER_NAME"
fi

echo "🚀 Deploying OceanSurge application..."
# Create logs directory if it doesn't exist
mkdir -p logs

# Deploy the application with retry logic
echo "📦 Applying Kubernetes manifests..."
retry_command "Kubernetes manifests deployment" "$RETRY_COUNT" "$RETRY_DELAY" \
    bash -c "set -o pipefail; kubectl apply -k manifests/base/ 2>&1 | tee -a logs/aks-deploy.log"

echo "🚀 Deploying middleware layer..."
retry_command "Middleware deployment" "$RETRY_COUNT" "$RETRY_DELAY" \
    scripts/deploy-middleware.sh

echo "💰 Deploying FinOps controller..."
retry_command "FinOps controller deployment" "$RETRY_COUNT" "$RETRY_DELAY" \
    scripts/deploy-finops.sh

echo "⏳ Waiting for deployments to be ready..."
echo "   This may take up to 5 minutes..."
if retry_command "Deployment readiness check" "$RETRY_COUNT" "$RETRY_DELAY" \
    kubectl wait --for=condition=available --timeout=300s deployment --all -n oceansurge; then
    echo "✅ All deployments are ready!"
else
    echo "⚠️  Some deployments took longer than expected, but may still be starting..."
    echo "📋 Current status:"
    kubectl get pods,svc,hpa -n oceansurge
    echo
    echo "🔍 Check pod status with: kubectl get pods -n oceansurge"
    echo "📊 Check logs with: kubectl logs -n oceansurge <pod-name>"
fi

echo "📋 Deployment status:"
kubectl get pods,svc,hpa -n oceansurge

echo "✅ AKS cluster and application deployment complete!"
echo
echo "🌐 Access Information:"
echo "   📍 Cluster: $CLUSTER_NAME"
echo "   🗺️  Region: $REGION"
echo "   🖥️  Nodes: $NODES"
echo "   📦 Resource Group: $RESOURCE_GROUP"
echo
echo "🔗 To access your application:"
FRONTEND_IP=$(kubectl get service frontend-service -n oceansurge -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "<pending>")
MIDDLEWARE_IP=$(kubectl get service ld-spot-middleware -n oceansurge -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "<pending>")

echo "   🌍 Frontend: http://$FRONTEND_IP"
echo "   🔗 Middleware: http://$MIDDLEWARE_IP"
echo
echo "📋 Management Commands:"
echo "   kubectl get pods -n oceansurge          # View pod status"
echo "   kubectl get services -n oceansurge      # View services"
echo "   kubectl logs -n oceansurge <pod-name>   # View logs"
echo "   az aks delete --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME  # Delete cluster"
