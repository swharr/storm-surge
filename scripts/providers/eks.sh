#!/bin/bash
set -e
echo "🛠️  Provisioning EKS Cluster..."
if ! command -v eksctl &> /dev/null; then
    echo "❌ eksctl not installed" >&2
    exit 1
fi

eksctl create cluster \
  --name storm-surge-eks \
  --region us-west-2 \
  --nodes 2 2>&1 | tee -a logs/eks-deploy.log

aws eks update-kubeconfig --name storm-surge-eks --region us-west-2

echo "🚀 Deploying OceanSurge application..."
# Create logs directory if it doesn't exist
mkdir -p logs

# Deploy the application
echo "📦 Applying Kubernetes manifests..."
kubectl apply -k manifests/base/ 2>&1 | tee -a logs/eks-deploy.log

echo "⏳ Waiting for deployments to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment --all -n oceansurge

echo "📋 Deployment status:"
kubectl get pods,svc,hpa -n oceansurge

echo "✅ EKS cluster and application ready"