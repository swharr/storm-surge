#!/bin/bash

# GCP GKE Cleanup Script
# Safely removes Storm Surge resources from Google Cloud Platform

set -e

CLUSTER_NAME=${STORM_CLUSTER_NAME:-"storm-surge-prod"}
REGION=${GCP_REGION:-"us-central1"}
PROJECT_ID=${PROJECT_ID:-""}
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
        --project=*)
            PROJECT_ID="${arg#*=}"
            ;;
        --help)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  --dry-run                 Show what would be deleted without deleting"
            echo "  --force                   Skip confirmation prompts"
            echo "  --cluster-name=NAME       GKE cluster name (default: storm-surge-prod)"
            echo "  --region=REGION          GCP region (default: us-central1)"
            echo "  --project=PROJECT_ID     GCP project ID"
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
if ! command -v gcloud &> /dev/null; then
    print_error "gcloud CLI not installed"
    exit 1
fi

if ! command -v kubectl &> /dev/null; then
    print_error "kubectl not installed"
    exit 1
fi

# Get project ID if not provided
if [ -z "$PROJECT_ID" ]; then
    PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
    if [ -z "$PROJECT_ID" ]; then
        print_error "No project ID specified and no default project configured"
        print_error "Use: gcloud config set project YOUR_PROJECT_ID"
        exit 1
    fi
fi

print_info "GCP GKE Cleanup for Storm Surge"
print_info "Cluster: $CLUSTER_NAME"
print_info "Region: $REGION"
print_info "Project: $PROJECT_ID"
echo

# Check if cluster exists
if ! gcloud container clusters describe "$CLUSTER_NAME" --region="$REGION" --project="$PROJECT_ID" &>/dev/null; then
    print_warning "Cluster $CLUSTER_NAME not found in region $REGION"
    exit 0
fi

# Get cluster credentials
print_info "Getting cluster credentials..."
if ! gcloud container clusters get-credentials "$CLUSTER_NAME" --region="$REGION" --project="$PROJECT_ID"; then
    print_error "Failed to get cluster credentials"
    exit 1
fi

# Show resources that will be deleted
print_info "Resources to be deleted:"
echo "- GKE Cluster: $CLUSTER_NAME"
echo "- All associated node pools"
echo "- Associated firewall rules (created by GKE)"
echo "- Load balancers created by Kubernetes services"

if [ "$DRY_RUN" = true ]; then
    print_info "DRY RUN - The following Kubernetes resources would be deleted:"
    kubectl get all -n storm-surge-prod 2>/dev/null || echo "  No resources in storm-surge-prod namespace"
    kubectl get ingress -A 2>/dev/null || echo "  No ingress resources found"
    echo
    print_info "The following GCP resources would be deleted:"
    echo "  GKE Cluster: $CLUSTER_NAME"
    gcloud container node-pools list --cluster="$CLUSTER_NAME" --region="$REGION" --project="$PROJECT_ID" 2>/dev/null || echo "  No node pools found"
    exit 0
fi

# Confirmation
if [ "$FORCE" != true ]; then
    print_warning "This will permanently delete the GKE cluster '$CLUSTER_NAME' and all associated resources"
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

# Delete any remaining ingress resources (these create load balancers)
print_info "Cleaning up ingress resources..."
kubectl delete ingress --all --all-namespaces --ignore-not-found=true --timeout=300s || true

# Wait for load balancers to be cleaned up
print_info "Waiting for GCP load balancers to be cleaned up..."
sleep 30

# Delete the GKE cluster
print_info "Deleting GKE cluster: $CLUSTER_NAME"
if gcloud container clusters delete "$CLUSTER_NAME" --region="$REGION" --project="$PROJECT_ID" --quiet; then
    print_info "Successfully deleted GKE cluster: $CLUSTER_NAME"
else
    print_error "Failed to delete GKE cluster"
    exit 1
fi

print_info "GCP GKE cleanup completed successfully"