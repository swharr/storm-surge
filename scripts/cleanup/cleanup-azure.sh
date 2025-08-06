#!/bin/bash

# Azure AKS Cleanup Script
# Safely removes Storm Surge resources from Microsoft Azure

set -e

CLUSTER_NAME=${STORM_CLUSTER_NAME:-"storm-surge-prod"}
RESOURCE_GROUP=${RESOURCE_GROUP:-"storm-surge-prod-rg"}
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
        --resource-group=*)
            RESOURCE_GROUP="${arg#*=}"
            ;;
        --help)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  --dry-run                    Show what would be deleted without deleting"
            echo "  --force                      Skip confirmation prompts"
            echo "  --cluster-name=NAME          AKS cluster name (default: storm-surge-prod)"
            echo "  --resource-group=GROUP       Azure resource group (default: storm-surge-prod-rg)"
            echo "  --help                       Show this help message"
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
if ! command -v az &> /dev/null; then
    print_error "Azure CLI not installed"
    exit 1
fi

if ! command -v kubectl &> /dev/null; then
    print_error "kubectl not installed"
    exit 1
fi

# Check if logged in
if ! az account show &>/dev/null; then
    print_error "Not logged in to Azure. Run: az login"
    exit 1
fi

print_info "Azure AKS Cleanup for Storm Surge"
print_info "Cluster: $CLUSTER_NAME"
print_info "Resource Group: $RESOURCE_GROUP"
echo

# Check if resource group exists
if ! az group show --name "$RESOURCE_GROUP" &>/dev/null; then
    print_warning "Resource group $RESOURCE_GROUP not found"
    exit 0
fi

# Check if cluster exists
if ! az aks show --name "$CLUSTER_NAME" --resource-group "$RESOURCE_GROUP" &>/dev/null; then
    print_warning "Cluster $CLUSTER_NAME not found in resource group $RESOURCE_GROUP"
    exit 0
fi

# Get cluster credentials
print_info "Getting cluster credentials..."
if ! az aks get-credentials --name "$CLUSTER_NAME" --resource-group "$RESOURCE_GROUP" --overwrite-existing; then
    print_error "Failed to get cluster credentials"
    exit 1
fi

# Show resources that will be deleted
print_info "Resources to be deleted:"
echo "- AKS Cluster: $CLUSTER_NAME"
echo "- All associated node pools and scale sets"
echo "- Associated load balancers and public IPs"
echo "- Associated network security groups (created by AKS)"

if [ "$DRY_RUN" = true ]; then
    print_info "DRY RUN - The following Kubernetes resources would be deleted:"
    kubectl get all -n storm-surge-prod 2>/dev/null || echo "  No resources in storm-surge-prod namespace"
    kubectl get ingress -A 2>/dev/null || echo "  No ingress resources found"
    echo
    print_info "The following Azure resources would be deleted:"
    echo "  AKS Cluster: $CLUSTER_NAME"
    az aks nodepool list --cluster-name "$CLUSTER_NAME" --resource-group "$RESOURCE_GROUP" --query "[].name" -o tsv 2>/dev/null || echo "  No node pools found"
    exit 0
fi

# Confirmation
if [ "$FORCE" != true ]; then
    print_warning "This will permanently delete the AKS cluster '$CLUSTER_NAME' and all associated resources"
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
print_info "Waiting for Azure load balancers to be cleaned up..."
sleep 30

# Delete the AKS cluster
print_info "Deleting AKS cluster: $CLUSTER_NAME"
if az aks delete --name "$CLUSTER_NAME" --resource-group "$RESOURCE_GROUP" --yes --no-wait; then
    print_info "AKS cluster deletion initiated: $CLUSTER_NAME"
    print_info "Note: Deletion continues in the background and may take several minutes"
else
    print_error "Failed to delete AKS cluster"
    exit 1
fi

# Optionally delete the entire resource group
echo
print_warning "The resource group '$RESOURCE_GROUP' still exists and may contain other resources"
if [ "$FORCE" != true ]; then
    read -p "Do you want to delete the entire resource group? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Deleting resource group: $RESOURCE_GROUP"
        az group delete --name "$RESOURCE_GROUP" --yes --no-wait
        print_info "Resource group deletion initiated (continues in background)"
    fi
else
    print_info "Skipping resource group deletion (use manual deletion if needed)"
fi

print_info "Azure AKS cleanup completed successfully"