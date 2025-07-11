#!/bin/bash
set -e
echo "🛠️  Provisioning AKS Cluster..."
if ! command -v az &> /dev/null; then
    echo "❌ Azure CLI not installed" >&2
    exit 1
fi

az group create --name storm-surge-rg --location eastus
az aks create --resource-group storm-surge-rg \
  --name storm-surge-aks \
  --node-count 2 --generate-ssh-keys \
  --enable-cluster-autoscaler --min-count 1 --max-count 3 \
  2>&1 | tee -a logs/aks-deploy.log

az aks get-credentials --resource-group storm-surge-rg --name storm-surge-aks

echo "🚀 Deploying OceanSurge application..."
# Create logs directory if it doesn't exist
mkdir -p logs

# Deploy the application
echo "📦 Applying Kubernetes manifests..."
kubectl apply -k manifests/base/ 2>&1 | tee -a logs/aks-deploy.log

echo "⏳ Waiting for deployments to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment --all -n oceansurge

echo "📋 Deployment status:"
kubectl get pods,svc,hpa -n oceansurge

echo "✅ AKS cluster and application ready"