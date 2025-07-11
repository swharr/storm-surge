#!/bin/bash
set -e

# Get configuration from environment or use defaults
REGION=${STORM_REGION:-"us-west-2"}
ZONE=${STORM_ZONE:-"us-west-2a"}
NODES=${STORM_NODES:-"2"}
CLUSTER_NAME="storm-surge-eks"

echo "🛠️  Provisioning EKS Cluster..."
echo "   📍 Region: $REGION"
echo "   🗺️  Zone: $ZONE"
echo "   🖥️  Nodes: $NODES"
echo "   🏷️  Cluster: $CLUSTER_NAME"
echo

if ! command -v eksctl &> /dev/null; then
    echo "❌ eksctl not installed" >&2
    echo "   Install: https://eksctl.io/installation/"
    exit 1
fi

if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI not installed" >&2
    echo "   Install: https://aws.amazon.com/cli/"
    exit 1
fi

# Validate AWS authentication
if ! aws sts get-caller-identity &>/dev/null; then
    echo "❌ Not authenticated with AWS" >&2
    echo "   Run: aws configure"
    exit 1
fi

# Validate zone is in the correct region
if [[ "$ZONE" != "$REGION"* ]]; then
    echo "❌ Zone '$ZONE' does not match region '$REGION'" >&2
    echo "   Zone must start with region name (e.g., us-west-2a)"
    exit 1
fi

echo "🔧 Creating EKS cluster with $NODES nodes..."
eksctl create cluster \
  --name "$CLUSTER_NAME" \
  --region "$REGION" \
  --zones "$ZONE" \
  --nodes "$NODES" \
  --node-type t3.medium \
  --node-volume-size 20 \
  --managed 2>&1 | tee -a logs/eks-deploy.log

echo "🔑 Updating kubeconfig..."
aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$REGION"

echo "🚀 Deploying OceanSurge application..."
# Create logs directory if it doesn't exist
mkdir -p logs

# Deploy the application
echo "📦 Applying Kubernetes manifests..."
kubectl apply -k manifests/base/ 2>&1 | tee -a logs/eks-deploy.log

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

echo "✅ EKS cluster and application deployment complete!"
echo
echo "🌐 Access Information:"
echo "   📍 Cluster: $CLUSTER_NAME"
echo "   🗺️  Region: $REGION"
echo "   🖥️  Nodes: $NODES"
echo
echo "🔗 To access your application:"
FRONTEND_IP=$(kubectl get service frontend-service -n oceansurge -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "<pending>")
MIDDLEWARE_IP=$(kubectl get service ld-spot-middleware -n oceansurge -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "<pending>")

echo "   🌍 Frontend: http://$FRONTEND_IP"
echo "   🔗 Middleware: http://$MIDDLEWARE_IP"
echo
echo "📋 Management Commands:"
echo "   kubectl get pods -n oceansurge          # View pod status"
echo "   kubectl get services -n oceansurge      # View services"
echo "   kubectl logs -n oceansurge <pod-name>   # View logs"
echo "   eksctl delete cluster $CLUSTER_NAME --region=$REGION  # Delete cluster"