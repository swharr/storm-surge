#!/bin/bash

# AWS EKS Cleanup Script
# Safely removes Storm Surge resources from AWS

set -e

CLUSTER_NAME=${STORM_CLUSTER_NAME:-"storm-surge-prod"}
REGION=${AWS_REGION:-"us-east-1"}
DRY_RUN=false
FORCE=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Parse arguments
for arg in "$@"; do
    case $arg in
        --dry-run)
            DRY_RUN=true
            print_info "Running in dry-run mode - no resources will be deleted"
            ;;
        --force)
            FORCE=true
            ;;
        --cluster-name=*)
            CLUSTER_NAME="${arg#*=}"
            ;;
        --region=*)
            REGION="${arg#*=}"
            ;;
        --help)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  --dry-run                 Show what would be deleted without deleting"
            echo "  --force                   Skip confirmation prompts"
            echo "  --cluster-name=NAME       EKS cluster name (default: storm-surge-prod)"
            echo "  --region=REGION          AWS region (default: us-east-1)"
            echo "  --help                   Show this help message"
            exit 0
            ;;
        *)
            print_error "Unknown argument: $arg"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Check prerequisites
if ! command -v aws &> /dev/null; then
    print_error "AWS CLI not installed"
    exit 1
fi

if ! command -v eksctl &> /dev/null; then
    print_error "eksctl not installed"
    exit 1
fi

if ! command -v kubectl &> /dev/null; then
    print_error "kubectl not installed"
    exit 1
fi

print_info "AWS EKS Cleanup for Storm Surge"
print_info "Cluster: $CLUSTER_NAME"
print_info "Region: $REGION"
echo

# Check if cluster exists
if ! eksctl get cluster --name="$CLUSTER_NAME" --region="$REGION" &>/dev/null; then
    print_warning "Cluster $CLUSTER_NAME not found in region $REGION"
    exit 0
fi

# Get cluster credentials
print_info "Getting cluster credentials..."
if ! aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$REGION"; then
    print_error "Failed to get cluster credentials"
    exit 1
fi

# Show resources that will be deleted
print_info "Resources to be deleted:"
echo "- EKS Cluster: $CLUSTER_NAME"
echo "- All associated node groups"
echo "- Associated security groups (created by EKS)"
echo "- Load balancers created by Kubernetes services"

if [ "$DRY_RUN" = true ]; then
    print_info "DRY RUN - The following Kubernetes resources would be deleted:"
    kubectl get all -n storm-surge-prod 2>/dev/null || echo "  No resources in storm-surge-prod namespace"
    kubectl get ingress -A 2>/dev/null || echo "  No ingress resources found"
    echo
    print_info "The following AWS resources would be deleted:"
    echo "  EKS Cluster: $CLUSTER_NAME"
    eksctl get nodegroup --cluster="$CLUSTER_NAME" --region="$REGION" 2>/dev/null || echo "  No node groups found"
    exit 0
fi

# Confirmation
if [ "$FORCE" != true ]; then
    print_warning "This will permanently delete the EKS cluster '$CLUSTER_NAME' and all associated resources"
    read -p "Are you sure you want to continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Cleanup cancelled"
        exit 0
    fi
fi

# Delete Kubernetes resources first
print_info "Deleting Kubernetes resources..."
kubectl delete namespace storm-surge-prod --ignore-not-found=true --timeout=300s || true

# Delete any remaining ingress resources (these create ALBs)
print_info "Cleaning up ingress resources..."
kubectl delete ingress --all --all-namespaces --ignore-not-found=true --timeout=300s || true

# Wait for load balancers to be cleaned up
print_info "Waiting for AWS load balancers to be cleaned up..."
sleep 30

# Delete the EKS cluster
print_info "Deleting EKS cluster: $CLUSTER_NAME"
if eksctl delete cluster --name="$CLUSTER_NAME" --region="$REGION" --wait; then
    print_info "Successfully deleted EKS cluster: $CLUSTER_NAME"
else
    print_error "Failed to delete EKS cluster"
    exit 1
fi

print_info "AWS EKS cleanup completed successfully"