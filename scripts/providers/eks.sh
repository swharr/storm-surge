#!/bin/bash
set -e

# Get configuration from environment or use defaults
REGION=${STORM_REGION:-"us-west-2"}
ZONE=${STORM_ZONE:-"us-west-2a"}
NODES=${STORM_NODES:-"2"}
CLUSTER_NAME=${STORM_CLUSTER_NAME:-"storm-surge-eks"}
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

echo "🛠️  Provisioning EKS Cluster..."
echo "   📍 Region: $REGION"
echo "   🗺️  Zones: $ZONE"
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
    if [ -n "$AWS_PROFILE" ]; then
        echo "   Profile '$AWS_PROFILE' is not valid or has expired credentials"
    else
        echo "   Run: aws configure"
    fi
    exit 1
fi

# Display AWS identity for confirmation
if [ -n "$AWS_PROFILE" ]; then
    echo "🔐 Using AWS Profile: $AWS_PROFILE"
fi
AWS_IDENTITY=$(aws sts get-caller-identity --query 'Arn' --output text)
echo "🔑 AWS Identity: $AWS_IDENTITY"

# Validate zones are in the correct region
# ZONE can contain multiple zones separated by spaces for EKS
for z in $ZONE; do
    if [[ "$z" != "$REGION"* ]]; then
        echo "❌ Zone '$z' does not match region '$REGION'" >&2
        echo "   Zone must start with region name (e.g., us-west-2a)"
        exit 1
    fi
done

if [ "$STORM_SKIP_CLUSTER_CREATION" = "true" ]; then
  echo "⚡ Skipping cluster creation, using existing cluster..."
  echo "🔑 Updating kubeconfig..."
  aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$REGION"
else
  echo "🔧 Creating EKS cluster with $NODES nodes..."
  # Convert space-separated zones to comma-separated for eksctl
  ZONES_COMMA=$(echo "$ZONE" | tr ' ' ',')
  echo "   🗺️  Using availability zones: $ZONES_COMMA"

  eksctl create cluster \
    --name "$CLUSTER_NAME" \
    --region "$REGION" \
    --zones "$ZONES_COMMA" \
    --nodes "$NODES" \
    --node-type t3.medium \
    --node-volume-size 20 \
    --managed 2>&1 | tee -a logs/eks-deploy.log

  echo "🔑 Updating kubeconfig..."
  aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$REGION"
fi

echo "🚀 Deploying OceanSurge application..."
# Create logs directory if it doesn't exist
mkdir -p logs

# Deploy the application with retry logic
echo "📦 Applying Kubernetes manifests..."
retry_command "Kubernetes manifests deployment" "$RETRY_COUNT" "$RETRY_DELAY" \
    bash -c "kubectl apply -k ../../manifests/base/ 2>&1 | tee -a logs/eks-deploy.log"

echo "🚀 Deploying middleware layer..."
retry_command "Middleware deployment" "$RETRY_COUNT" "$RETRY_DELAY" \
    ./deploy-middleware.sh

echo "💰 Deploying FinOps controller..."
retry_command "FinOps controller deployment" "$RETRY_COUNT" "$RETRY_DELAY" \
    ./deploy-finops.sh

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
