#!/bin/bash
set -e

# Get configuration from environment or use defaults
REGION=${STORM_REGION:-"eastus"}
ZONE=${STORM_ZONE:-"1"}
NODES=${STORM_NODES:-"2"}
CLUSTER_NAME="storm-surge-aks"
RESOURCE_GROUP="storm-surge-rg"

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

echo "🚀 Deploying OceanSurge application..."
# Create logs directory if it doesn't exist
mkdir -p logs

# Deploy the application
echo "📦 Applying Kubernetes manifests..."
kubectl apply -k manifests/base/ 2>&1 | tee -a logs/aks-deploy.log

echo "🚀 Deploying middleware layer..."
./scripts/deploy-middleware.sh

echo "💰 Deploying FinOps controller..."
./scripts/deploy-finops.sh

echo "⏳ Waiting for deployments to be ready..."
echo "   This may take up to 5 minutes..."
if ! kubectl wait --for=condition=available --timeout=300s deployment --all -n oceansurge; then
    echo "⚠️  Some deployments took longer than expected, but may still be starting..."
    echo "📋 Current status:"
    kubectl get pods,svc,hpa -n oceansurge
    echo
    echo "🔍 Check pod status with: kubectl get pods -n oceansurge"
    echo "📊 Check logs with: kubectl logs -n oceansurge <pod-name>"
else
    echo "✅ All deployments are ready!"
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