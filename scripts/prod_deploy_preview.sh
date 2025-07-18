#!/bin/bash
set -e

# OceanSurge Production Deployment Preview
# This script deploys the complete OceanSurge stack with LaunchDarkly and Spot API integration

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Load .env if it exists
if [ -f .env ]; then
    log_info "Loading environment from .env"
    set -a
    source .env
    set +a
fi

show_usage() {
    echo "🌊 OceanSurge Production Deployment Preview"
    echo "=============================================="
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --provider=gke|eks|aks|all    Cloud provider to deploy to"
    echo "  --skip-middleware             Skip middleware deployment"
    echo "  --config-only                 Only generate configuration files"
    echo "  --help                        Show this help message"
    echo ""
    echo "Prerequisites:"
    echo "  - LaunchDarkly account with SDK key"
    echo "  - Spot API token and cluster access"
    echo "  - Cloud provider CLI tools (gcloud, aws/eksctl, or az)"
    echo "  - kubectl installed and configured"
    echo ""
    exit 1
}

# Parse arguments
PROVIDER=""
SKIP_MIDDLEWARE=false
CONFIG_ONLY=false

for arg in "$@"; do
    case $arg in
        --provider=*)
            PROVIDER="${arg#*=}"
            shift
            ;;
        --skip-middleware)
            SKIP_MIDDLEWARE=true
            shift
            ;;
        --config-only)
            CONFIG_ONLY=true
            shift
            ;;
        --help)
            show_usage
            ;;
        *)
            echo "Unknown option: \"$arg\""
            show_usage
            ;;
    esac
done

# Banner
echo ""
echo "🌊 ========================================"
echo "🌊 OceanSurge Production Deployment Preview"
echo "🌊 ========================================"
echo ""

# Check prerequisites
log_info "Checking prerequisites..."

# Check kubectl
if ! command -v kubectl &> /dev/null; then
    log_error "kubectl is not installed. Please install kubectl first."
    exit 1
fi

# Check if we're in the right directory
if [ ! -f "manifests/base/kustomization.yaml" ]; then
    log_error "This script must be run from the OceanSurge root directory"
    exit 1
fi

# Collect credentials
log_info "Collecting required credentials..."

# LaunchDarkly SDK Key
if [ -z "$LAUNCHDARKLY_SDK_KEY" ]; then
    echo ""
    log_warning "LaunchDarkly SDK Key is required for feature flag integration"
    echo "To get your SDK key:"
    echo "1. Log into LaunchDarkly"
    echo "2. Go to Account Settings > Projects"
    echo "3. Select your project and environment"
    echo "4. Copy the Server-side SDK key"
    echo ""
    read -p "Enter your LaunchDarkly SDK Key: " LAUNCHDARKLY_SDK_KEY
    
    if [ -z "$LAUNCHDARKLY_SDK_KEY" ]; then
        log_error "LaunchDarkly SDK Key is required"
        exit 1
    fi
fi

# Spot API Token
if [ -z "$SPOT_API_TOKEN" ]; then
    echo ""
    log_warning "Spot API Token is required for cluster scaling"
    echo "To get your Spot API token:"
    echo "1. Log into Spot Console"
    echo "2. Go to Settings > API"
    echo "3. Generate a new API token"
    echo "4. Copy the token value"
    echo ""
    read -p "Enter your Spot API Token: " SPOT_API_TOKEN
    
    if [ -z "$SPOT_API_TOKEN" ]; then
        log_error "Spot API Token is required"
        exit 1
    fi
fi

# Spot Cluster ID
if [ -z "$SPOT_CLUSTER_ID" ]; then
    echo ""
    log_warning "Spot Cluster ID is required for cluster management"
    echo "To get your Spot Cluster ID:"
    echo "1. Log into Spot Console"
    echo "2. Go to Ocean > Clusters"
    echo "3. Find your cluster and copy the ID (format: ocn-xxxxxxxx)"
    echo ""
    read -p "Enter your Spot Cluster ID: " SPOT_CLUSTER_ID
    
    if [ -z "$SPOT_CLUSTER_ID" ]; then
        log_error "Spot Cluster ID is required"
        exit 1
    fi
fi

# Webhook Secret (optional but recommended)
if [ -z "$WEBHOOK_SECRET" ]; then
    echo ""
    log_info "Webhook Secret is optional but recommended for security"
    read -p "Enter a webhook secret (or press Enter to skip): " WEBHOOK_SECRET
    
    if [ -z "$WEBHOOK_SECRET" ]; then
        WEBHOOK_SECRET="oceansurge-webhook-$(openssl rand -hex 16)"
        log_info "Generated webhook secret: $WEBHOOK_SECRET"
    fi
fi

# Provider selection
if [ -z "$PROVIDER" ]; then
    echo ""
    log_info "Select cloud provider for deployment:"
    echo "1) GKE (Google Kubernetes Engine)"
    echo "2) EKS (Amazon Elastic Kubernetes Service)"
    echo "3) AKS (Azure Kubernetes Service)"
    echo "4) All providers"
    echo ""
    read -p "Enter your choice (1-4): " PROVIDER_CHOICE
    
    case $PROVIDER_CHOICE in
        1) PROVIDER="gke" ;;
        2) PROVIDER="eks" ;;
        3) PROVIDER="aks" ;;
        4) PROVIDER="all" ;;
        *) log_error "Invalid choice"; exit 1 ;;
    esac
fi

# Validate provider
case $PROVIDER in
    gke|eks|aks|all) ;;
    *) log_error "Invalid provider: $PROVIDER"; show_usage ;;
esac

# Create/update configuration files
log_info "Creating configuration files..."

# Create temp directory for processed manifests
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# Process middleware secrets
cp -r manifests/middleware "$TEMP_DIR/"

# Update secrets with real values
sed -i.bak "s/\${LAUNCHDARKLY_SDK_KEY}/$LAUNCHDARKLY_SDK_KEY/g" "$TEMP_DIR/middleware/secret.yaml"
sed -i.bak "s/\${SPOT_API_TOKEN}/$SPOT_API_TOKEN/g" "$TEMP_DIR/middleware/secret.yaml"
sed -i.bak "s/\${WEBHOOK_SECRET}/$WEBHOOK_SECRET/g" "$TEMP_DIR/middleware/secret.yaml"

# Update configmap with cluster ID
sed -i.bak "s/ocn-12345678/$SPOT_CLUSTER_ID/g" "$TEMP_DIR/middleware/configmap.yaml"

# Remove backup files
rm -f "$TEMP_DIR/middleware"/*.bak

log_success "Configuration files updated with credentials"

# Save configuration to .env file
cat > .env << EOF
# OceanSurge Configuration
LAUNCHDARKLY_SDK_KEY=$LAUNCHDARKLY_SDK_KEY
SPOT_API_TOKEN=$SPOT_API_TOKEN
SPOT_CLUSTER_ID=$SPOT_CLUSTER_ID
WEBHOOK_SECRET=$WEBHOOK_SECRET
EOF

log_success "Configuration saved to .env file"

# Exit if config-only mode
if [ "$CONFIG_ONLY" = true ]; then
    log_success "Configuration files generated. You can now deploy manually."
    exit 0
fi

# Deployment functions
SCRIPTS_DIR=$(dirname "$0")/providers

deploy_base_app() {
    local provider=$1
    local script="${SCRIPTS_DIR}/${provider}.sh"
    
    if [ -f "$script" ]; then
        log_info "Deploying base application to $provider..."
        bash "$script"
    else
        log_error "Deployment script for provider '$provider' not found."
        return 1
    fi
}

deploy_middleware() {
    log_info "Deploying middleware components..."
    
    # Apply middleware manifests
    kubectl apply -k "$TEMP_DIR/middleware/"
    
    # Wait for middleware deployment to be ready
    log_info "Waiting for middleware deployment to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/ld-spot-middleware -n oceansurge
    
    # Get middleware service details
    log_info "Middleware service details:"
    kubectl get svc ld-spot-middleware -n oceansurge -o wide
    
    # Check if ingress is available
    if kubectl get ingress ld-spot-middleware-ingress -n oceansurge &>/dev/null; then
        log_info "Ingress configuration:"
        kubectl get ingress ld-spot-middleware-ingress -n oceansurge
        
        echo ""
        log_warning "Configure LaunchDarkly webhook URL:"
        echo "1. Get the external IP/hostname from the ingress above"
        echo "2. In LaunchDarkly, go to Integrations > Webhooks"
        echo "3. Add webhook URL: https://your-domain.com/webhook/launchdarkly"
        echo "4. Set the webhook secret to: $WEBHOOK_SECRET"
    fi
}

validate_deployment() {
    log_info "Validating deployment..."
    
    # Check base application
    if kubectl get deployment frontend -n oceansurge &>/dev/null; then
        log_success "Base application deployed successfully"
        kubectl get pods -n oceansurge -l app=frontend
    else
        log_error "Base application deployment failed"
        return 1
    fi
    
    # Check middleware if not skipped
    if [ "$SKIP_MIDDLEWARE" = false ]; then
        if kubectl get deployment ld-spot-middleware -n oceansurge &>/dev/null; then
            log_success "Middleware deployed successfully"
            kubectl get pods -n oceansurge -l app=ld-spot-middleware
        else
            log_error "Middleware deployment failed"
            return 1
        fi
    fi
    
    # Check services
    log_info "Service status:"
    kubectl get svc -n oceansurge
    
    # Check HPA
    if kubectl get hpa -n oceansurge &>/dev/null; then
        log_info "HPA status:"
        kubectl get hpa -n oceansurge
    fi
}

# Main deployment
log_info "Starting deployment to provider: $PROVIDER"

# Deploy to providers
if [ "$PROVIDER" = "all" ]; then
    for p in gke eks aks; do
        deploy_base_app $p
    done
else
    deploy_base_app $PROVIDER
fi

# Deploy middleware if not skipped
if [ "$SKIP_MIDDLEWARE" = false ]; then
    deploy_middleware
fi

# Validate deployment
validate_deployment

# Final summary
echo ""
echo "🎉 ========================================"
echo "🎉 OceanSurge Deployment Complete!"
echo "🎉 ========================================"
echo ""
log_success "Deployment completed successfully!"
echo ""
echo "📋 Next Steps:"
echo "1. Configure LaunchDarkly webhook (see instructions above)"
echo "2. Create feature flag 'enable-cost-optimizer' in LaunchDarkly"
echo "3. Test the integration by toggling the feature flag"
echo "4. Monitor cluster scaling in Spot Console"
echo ""
echo "🔗 Useful Commands:"
echo "  kubectl get pods -n oceansurge"
echo "  kubectl get svc -n oceansurge"
echo "  kubectl logs -f deployment/ld-spot-middleware -n oceansurge"
echo ""
echo "🌊 Happy sailing with OceanSurge! 🌊"