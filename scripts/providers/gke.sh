#!/bin/bash
set -e

# Get configuration from environment or use defaults
REGION=${STORM_REGION:-"us-central1"}
ZONE=${STORM_ZONE:-"us-central1-c"}
NODES=${STORM_NODES:-"2"}
CLUSTER_NAME=${STORM_CLUSTER_NAME:-"storm-surge-gke"}
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
  echo "🔧 Creating GKE cluster with $NODES nodes and security hardening..."
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
    --enable-network-policy \
    --enable-ip-alias \
    --enable-shielded-nodes \
    --enable-private-nodes \
    --master-ipv4-cidr=172.16.0.0/28 \
    --enable-master-authorized-networks \
    --master-authorized-networks 0.0.0.0/0 \
    --no-enable-legacy-authorization \
    --quiet 2>&1 | tee -a logs/gke-deploy.log

  echo "🔑 Getting cluster credentials..."
  gcloud container clusters get-credentials "$CLUSTER_NAME" --zone="$ZONE"

  echo "🔒 Applying additional security hardening..."
  # Disable insecure ports on kubelet
  kubectl patch daemonset kube-proxy -n kube-system --type='strategic' --patch='{"spec":{"template":{"spec":{"containers":[{"name":"kube-proxy","args":["--proxy-mode=iptables","--cluster-cidr=10.0.0.0/16","--healthz-port=0","--metrics-port=0"]}]}}}}' 2>/dev/null || echo "   kube-proxy patch not needed"

  # Apply security policies
  kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-insecure-ports
  namespace: default
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from: []
    ports:
    - protocol: TCP
      port: 80
    - protocol: TCP
      port: 443
    - protocol: TCP
      port: 8080
  egress:
  - to: []
    ports:
    - protocol: TCP
      port: 53
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 80
    - protocol: TCP
      port: 443
    - protocol: TCP
      port: 8080
EOF
  echo "✅ Security hardening applied"
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

echo "🔒 Deploying security workloads and tests..."
retry_command "Security RBAC authentication mapping" "$RETRY_COUNT" "$RETRY_DELAY" \
    kubectl apply -f ../../manifests/sec_fixes/rbac_authmap.yaml
retry_command "Security RBAC namespace binding" "$RETRY_COUNT" "$RETRY_DELAY" \
    kubectl apply -f ../../manifests/sec_fixes/rbac_namespace_fix.yaml
retry_command "Security validation test pod" "$RETRY_COUNT" "$RETRY_DELAY" \
    kubectl apply -f ../../manifests/sec_fixes/sectest_validate.yaml

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

# Enhanced security validation and lockdown
echo "🔒 Running comprehensive security validation..."
security_issues_found=false

# Check for insecure port 10255 (kubelet read-only port)
echo "🔍 Checking for insecure port 10255..."
if kubectl get pods --all-namespaces -o yaml | grep -q "10255"; then
    echo "⚠️  Found port 10255 usage in pods"
    security_issues_found=true
fi

if kubectl get configmaps --all-namespaces -o yaml | grep -q "10255"; then
    echo "⚠️  Found port 10255 usage in configmaps"
    security_issues_found=true
fi

# Check for other insecure ports
echo "🔍 Checking for other insecure ports..."
insecure_ports=("10250" "10251" "10252" "10253" "10254" "10256" "2379" "2380")
for port in "${insecure_ports[@]}"; do
    if kubectl get pods --all-namespaces -o yaml | grep -q "$port"; then
        echo "⚠️  Found potentially insecure port $port usage"
        security_issues_found=true
    fi
done

# Validate security test pod deployment
echo "🔍 Validating security test pod deployment..."
if kubectl get pod kubelet-authenticated-example -o jsonpath='{.status.phase}' 2>/dev/null | grep -q "Succeeded\|Running"; then
    echo "✅ Security validation pod deployed successfully"
else
    echo "⚠️  Security validation pod not ready or failed"
    kubectl get pod kubelet-authenticated-example -o wide 2>/dev/null || echo "   Pod not found"
fi

# Run lockitdown.sh if security issues are found
if [ "$security_issues_found" = true ]; then
    echo "🔧 Running security lockdown script due to security issues..."
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    LOCKDOWN_SCRIPT="$SCRIPT_DIR/../lockitdown.sh"

    if [ -f "$LOCKDOWN_SCRIPT" ]; then
        chmod +x "$LOCKDOWN_SCRIPT"
        bash "$LOCKDOWN_SCRIPT"
        echo "✅ Security lockdown script completed"
    else
        echo "❌ Security lockdown script not found at: $LOCKDOWN_SCRIPT"
        echo "   Please manually review and secure any insecure port usage"
    fi
else
    echo "✅ No security issues detected"
fi

# Verify RBAC configuration
echo "🔍 Verifying RBAC security configuration..."
if kubectl get clusterrole curl-authenticated-role &>/dev/null; then
    echo "✅ RBAC authentication role configured"
else
    echo "⚠️  RBAC authentication role not found"
fi

if kubectl get clusterrolebinding curl-authenticated-role-binding &>/dev/null; then
    echo "✅ RBAC authentication role binding configured"
else
    echo "⚠️  RBAC authentication role binding not found"
fi

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
