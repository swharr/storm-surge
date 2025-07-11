#!/bin/bash
set -e
echo "🛠️  Provisioning GKE Cluster..."
if ! command -v gcloud &> /dev/null; then
    echo "❌ gcloud CLI not installed" >&2
    exit 1
fi

gcloud container clusters create storm-surge-gke \
  --zone=us-central1-c \
  --num-nodes=2 --quiet 2>&1 | tee -a logs/gke-deploy.log

gcloud container clusters get-credentials storm-surge-gke --zone=us-central1-c

echo "🚀 Deploying OceanSurge application..."
# Create logs directory if it doesn't exist
mkdir -p logs

# Deploy the application
echo "📦 Applying Kubernetes manifests..."
kubectl apply -k manifests/base/ 2>&1 | tee -a logs/gke-deploy.log

echo "⏳ Waiting for deployments to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment --all -n oceansurge

echo "📋 Deployment status:"
kubectl get pods,svc,hpa -n oceansurge

echo "✅ GKE cluster and application ready"