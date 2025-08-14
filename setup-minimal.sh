#!/bin/bash

# Storm Surge Core Setup Script
# Minimal setup for core Kubernetes deployment

set -e

# Help functionality
show_help() {
    echo "Storm Surge Core Setup Script"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message and exit"
    echo "  -p PROVIDER    Cloud provider (aws, gcp, azure)"
    echo "  -r REGION      Cloud region"
    echo "  -n NODES       Number of nodes (default: 3)"
    echo ""
    echo "Interactive Mode:"
    echo "  Run without arguments for interactive setup"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Interactive mode"
    echo "  $0 -p aws -r us-west-2 -n 3         # AWS with specific settings"
    echo "  $0 --help                           # Show this help"
    exit 0
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      show_help
      ;;
    -p|--provider)
      CLOUD_PROVIDER="$2"
      shift 2
      ;;
    -r|--region)
      REGION="$2"
      shift 2
      ;;
    -n|--nodes)
      NODES="$2"
      shift 2
      ;;
    *)
      echo "Unknown option $1"
      show_help
      ;;
  esac
done

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print functions
print_header() {
    echo -e "${BLUE}===========================================${NC}"
    echo -e "${BLUE}    Storm Surge Core Setup${NC}"
    echo -e "${BLUE}===========================================${NC}"
    echo
}

print_step() {
    echo -e "${GREEN}[STEP]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Configuration variables
CLUSTER_NAME="storm-surge-core"
NAMESPACE="storm-surge-prod"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Welcome message
print_header
echo "Welcome to Storm Surge Core Setup"
echo "This script will help you deploy the core Kubernetes stack"
echo

# Select cloud provider
if [ -z "$CLOUD_PROVIDER" ]; then
    echo "Please select your cloud provider:"
    echo "1) AWS (EKS)"
    echo "2) Google Cloud (GKE)"
    echo "3) Azure (AKS)"
    read -p "Enter your choice (1-3): " provider_choice

    case $provider_choice in
        1) CLOUD_PROVIDER="aws" ;;
        2) CLOUD_PROVIDER="gcp" ;;
        3) CLOUD_PROVIDER="azure" ;;
        *) print_error "Invalid choice"; exit 1 ;;
    esac
fi

print_info "Selected cloud provider: $CLOUD_PROVIDER"

# Set cloud-specific defaults
case $CLOUD_PROVIDER in
    aws)
        DEFAULT_REGION="us-west-2"
        PROVIDER_NAME="AWS EKS"
        ;;
    gcp)
        DEFAULT_REGION="us-central1"
        PROVIDER_NAME="Google GKE"
        ;;
    azure)
        DEFAULT_REGION="eastus"
        PROVIDER_NAME="Azure AKS"
        ;;
esac

# Select region
if [ -z "$REGION" ]; then
    read -p "Enter the region (default: $DEFAULT_REGION): " REGION
    REGION=${REGION:-$DEFAULT_REGION}
fi

# Set number of nodes
if [ -z "$NODES" ]; then
    read -p "Enter the number of nodes (default: 3): " NODES
    NODES=${NODES:-3}
fi

# Summary
echo
print_info "Configuration Summary:"
echo "  Provider: $PROVIDER_NAME"
echo "  Region: $REGION"
echo "  Cluster Name: $CLUSTER_NAME"
echo "  Nodes: $NODES"
echo "  Namespace: $NAMESPACE"
echo

read -p "Continue with this configuration? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_warning "Setup cancelled"
    exit 0
fi

# Check prerequisites
print_step "Checking prerequisites..."

check_command() {
    if ! command -v $1 &> /dev/null; then
        print_error "$1 is not installed. Please install it first."
        exit 1
    else
        print_info "$1 is installed"
    fi
}

# Check required tools
check_command kubectl
check_command docker

# Check cloud-specific CLI
case $CLOUD_PROVIDER in
    aws)
        check_command aws
        ;;
    gcp)
        check_command gcloud
        ;;
    azure)
        check_command az
        ;;
esac

# IAM Policy Setup (Optional)
setup_iam_policies() {
    echo -e "${YELLOW}IAM Policy Setup${NC}"
    echo -e "${BLUE}Storm Surge requires administrative permissions to manage Kubernetes clusters.${NC}"
    echo
    read -p "Would you like to apply IAM policies now? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        case $CLOUD_PROVIDER in
            aws)
                if [ -x "$SCRIPT_DIR/scripts/iam/apply-aws-iam.sh" ]; then
                    print_info "Applying AWS IAM policies..."
                    "$SCRIPT_DIR/scripts/iam/apply-aws-iam.sh"
                else
                    print_warning "AWS IAM script not found. Please apply policies manually."
                fi
                ;;
            gcp)
                if [ -x "$SCRIPT_DIR/scripts/iam/apply-gcp-iam.sh" ]; then
                    print_info "Applying GCP IAM policies..."
                    "$SCRIPT_DIR/scripts/iam/apply-gcp-iam.sh"
                else
                    print_warning "GCP IAM script not found. Please apply policies manually."
                fi
                ;;
            azure)
                if [ -x "$SCRIPT_DIR/scripts/iam/apply-azure-iam.sh" ]; then
                    print_info "Applying Azure IAM policies..."
                    "$SCRIPT_DIR/scripts/iam/apply-azure-iam.sh"
                else
                    print_warning "Azure IAM script not found. Please apply policies manually."
                fi
                ;;
        esac
    else
        print_info "Skipping IAM setup. Ensure you have the necessary permissions."
    fi
}

# Execute IAM setup
setup_iam_policies
echo

# Deploy cluster
print_step "Deploying Kubernetes cluster..."

export STORM_CLUSTER_NAME=$CLUSTER_NAME
export STORM_REGION=$REGION
export STORM_NODES=$NODES

case $CLOUD_PROVIDER in
    aws)
        print_info "Deploying EKS cluster..."
        if [ -f "scripts/providers/eks.sh" ]; then
            bash scripts/providers/eks.sh
        else
            print_error "EKS deployment script not found"
            exit 1
        fi
        ;;
    gcp)
        print_info "Deploying GKE cluster..."
        if [ -f "scripts/providers/gke.sh" ]; then
            bash scripts/providers/gke.sh
        else
            print_error "GKE deployment script not found"
            exit 1
        fi
        ;;
    azure)
        print_info "Deploying AKS cluster..."
        if [ -f "scripts/providers/aks.sh" ]; then
            bash scripts/providers/aks.sh
        else
            print_error "AKS deployment script not found"
            exit 1
        fi
        ;;
esac

# Wait for cluster to be ready
print_step "Waiting for cluster to be ready..."
kubectl wait --for=condition=Ready nodes --all --timeout=300s || {
    print_warning "Some nodes are not ready yet. You may need to wait a bit longer."
}

# Create namespace
print_step "Creating namespace..."
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Generate minimal secrets
print_step "Generating secrets..."
mkdir -p manifests/secrets

# Generate Flask secret key
FLASK_SECRET_KEY=$(openssl rand -hex 32)

# Create secret
kubectl create secret generic storm-surge-secrets \
    --namespace=$NAMESPACE \
    --from-literal=flask-secret-key="$FLASK_SECRET_KEY" \
    --dry-run=client -o yaml | kubectl apply -f -

# Deploy core middleware
print_step "Deploying core middleware..."
kubectl apply -f manifests/middleware/configmap-minimal.yaml
kubectl apply -f manifests/middleware/deployment-minimal.yaml
kubectl apply -f manifests/middleware/service-minimal.yaml

# Wait for deployment
print_step "Waiting for deployment to be ready..."
kubectl wait --for=condition=available --timeout=300s \
    deployment/storm-surge-middleware \
    --namespace=$NAMESPACE

# Get load balancer URL
print_step "Getting load balancer URL..."
echo "Waiting for load balancer to be provisioned..."

# Wait for external IP
for i in {1..30}; do
    EXTERNAL_IP=$(kubectl get service storm-surge-lb \
        --namespace=$NAMESPACE \
        -o jsonpath='{.status.loadBalancer.ingress[0].ip}{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
    
    if [ -n "$EXTERNAL_IP" ]; then
        break
    fi
    
    echo -n "."
    sleep 10
done
echo

if [ -n "$EXTERNAL_IP" ]; then
    print_info "Load balancer URL: http://$EXTERNAL_IP"
else
    print_warning "Load balancer IP not yet available. Check with:"
    echo "kubectl get service storm-surge-lb --namespace=$NAMESPACE"
fi

# Deployment summary
echo
print_header
echo "Storm Surge Core deployment completed!"
echo
echo "Cluster Information:"
echo "  Provider: $PROVIDER_NAME"
echo "  Region: $REGION"
echo "  Cluster Name: $CLUSTER_NAME"
echo "  Namespace: $NAMESPACE"
echo
echo "Access Information:"
if [ -n "$EXTERNAL_IP" ]; then
    echo "  Application URL: http://$EXTERNAL_IP"
fi
echo "  Health Check: http://$EXTERNAL_IP/health"
echo "  API Status: http://$EXTERNAL_IP/api/v1/status"
echo
echo "Useful commands:"
echo "  kubectl get pods -n $NAMESPACE"
echo "  kubectl logs -f deployment/storm-surge-middleware -n $NAMESPACE"
echo "  kubectl get service storm-surge-lb -n $NAMESPACE"
echo
print_info "Setup complete!"