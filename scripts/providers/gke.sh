#!/bin/bash
set -e

# Get configuration from environment or use defaults
REGION=${STORM_REGION:-"us-central1"}
ZONE=${STORM_ZONE:-"us-central1-c"}
NODES=${STORM_NODES:-"2"}
CLUSTER_NAME="storm-surge-gke"
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
            if [ $attempt -lt $max_attempts ]; then
                echo "⚠️  $description failed, retrying in ${delay}s..."
                sleep "$delay"
            else
                echo "❌ $description failed after $max_attempts attempts"
                return 1
            fi
        fi
    done
}

echo "🛠️  Provisioning GKE Cluster..."
echo "   📍 Region: $REGION"
echo "   🗺️  Zone: $ZONE"
echo "   🖥️  Nodes: $NODES"
echo "   🏷️  Cluster: $CLUSTER_NAME"
echo

if ! command -v gcloud &> /dev/null; then
    echo "❌ gcloud CLI not installed" >&2
    echo "   Install: https://cloud.google.com/sdk/docs/install"
    exit 1
fi

# Validate gcloud authentication
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
    echo "❌ Not authenticated with gcloud" >&2
    echo "   Run: gcloud auth login"
    exit 1
fi

# Validate zone is in the correct region
if [[ "$ZONE" != "$REGION"* ]]; then
    echo "❌ Zone '$ZONE' does not match region '$REGION'" >&2
    echo "   Zone must start with region name (e.g., us-central1-a)"
    exit 1
fi

if [ "$STORM_SKIP_CLUSTER_CREATION" = "true" ]; then
  echo "⚡ Skipping cluster creation, using existing cluster..."
  echo "🔑 Getting cluster credentials..."
  gcloud container clusters get-credentials "$CLUSTER_NAME" --zone="$ZONE"
else
  echo "🔧 Creating GKE cluster with $NODES nodes..."
  gcloud container clusters create "$CLUSTER_NAME" \
    --zone="$ZONE" \
    --num-nodes="$NODES" \
    --machine-type=e2-medium \
    --disk-size=20GB \
    --enable-autoscaling \
    --min-nodes=1 \
    --max-nodes=10 \
    --enable-autorepair \
    --enable-autoupgrade \
    --quiet 2>&1 | tee -a logs/gke-deploy.log

  echo "🔑 Getting cluster credentials..."
  gcloud container clusters get-credentials "$CLUSTER_NAME" --zone="$ZONE"
fi

echo "🚀 Deploying OceanSurge application..."
# Create logs directory if it doesn't exist
mkdir -p logs

# Deploy the application with retry logic
echo "📦 Applying Kubernetes manifests..."
retry_command "Kubernetes manifests deployment" "$RETRY_COUNT" "$RETRY_DELAY" \
    bash -c "kubectl apply -k ../../manifests/base/ 2>&1 | tee -a logs/gke-deploy.log"

echo "🚀 Deploying middleware layer..."
retry_command "Middleware deployment" "$RETRY_COUNT" "$RETRY_DELAY" \
    ./deploy-middleware.sh

echo "💰 Deploying FinOps controller..."
retry_command "FinOps controller deployment" "$RETRY_COUNT" "$RETRY_DELAY" \
    ./deploy-finops.sh

echo "⏳ Waiting for deployments to be ready..."
echo "   This may take up to 5 minutes..."
retry_command "Deployment readiness check" "$RETRY_COUNT" "$RETRY_DELAY" \
    kubectl wait --for=condition=available --timeout=300s deployment --all -n oceansurge

if [ $? -eq 0 ]; then
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

echo "✅ GKE cluster and application deployment complete!"
echo
echo "🌐 Access Information:"
echo "   📍 Cluster: $CLUSTER_NAME"
echo "   🗺️  Zone: $ZONE"
echo "   🖥️  Nodes: $NODES"
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
echo "   gcloud container clusters delete $CLUSTER_NAME --zone=$ZONE  # Delete cluster"