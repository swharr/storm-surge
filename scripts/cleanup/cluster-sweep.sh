#!/bin/bash

# Kubernetes Namespace Cleanup Script
# Safely removes application namespaces while protecting system namespaces

set -e

LOG_FILE="cluster-cleanup-$(date +%Y%m%d-%H%M%S).log"
PROTECTED_NAMESPACES=("kube-system" "default" "kube-public" "kube-node-lease" "gatekeeper-system" "aws-observability" "azure-system" "gke-system" "kube-flannel" "metallb-system" "ingress-nginx" "cert-manager" "monitoring" "istio-system")
DRY_RUN=false
FORCE=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

print_info "Starting Kubernetes namespace cleanup..."

# Parse arguments
for arg in "$@"; do
    case $arg in
        --dry-run)
            DRY_RUN=true
            ;;
        --force)
            FORCE=true
            ;;
        --help)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  --dry-run    Show what would be deleted without deleting"
            echo "  --force      Skip confirmation prompts"
            echo "  --help       Show this help message"
            echo ""
            echo "Protected namespaces (never deleted):"
            printf "  %s\n" "${PROTECTED_NAMESPACES[@]}"
            exit 0
            ;;
        *)
            print_error "Unknown argument: \"$arg\""
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl not found. Please install kubectl first."
    exit 1
fi

# Check if we can connect to cluster
if ! kubectl cluster-info &>/dev/null; then
    print_error "Cannot connect to Kubernetes cluster. Check your kubeconfig."
    exit 1
fi

# Get all namespaces
ALL_NAMESPACES=$(kubectl get ns -o jsonpath='{.items[*].metadata.name}')

# Find namespaces to delete
NAMESPACES_TO_DELETE=()
for ns in $ALL_NAMESPACES; do
    skip=0
    for pns in "${PROTECTED_NAMESPACES[@]}"; do
        if [[ "$ns" == "$pns" ]]; then
            skip=1
            break
        fi
    done
    if [[ $skip -eq 0 ]]; then
        NAMESPACES_TO_DELETE+=("$ns")
    fi
done

# Optionally deregister Spot Ocean controller
echo "🛰️ Checking for Ocean Controller..." | tee -a "$LOG_FILE"
if kubectl get deployment -A | grep -q ocean-controller; then
    OCEAN_NS=$(kubectl get deployment -A | grep ocean-controller | awk '{print $1}')
    echo "🔻 Ocean controller found in namespace '$OCEAN_NS'" | tee -a "$LOG_FILE"
    echo "☠️  Will deregister and delete Spot Ocean CRDs and resources" | tee -a "$LOG_FILE"
    if "$FORCE"; then
        # Delete ocean-controller and CRDs
        kubectl delete ns "$OCEAN_NS" --grace-period=0 --force >> "$LOG_FILE" 2>&1 || true
        kubectl delete crd "$(kubectl get crd | grep spotinst | awk '{print $1}')" >> "$LOG_FILE" 2>&1 || true
    else
        echo "⚠️  Ocean controller would be removed (dry-run)" | tee -a "$LOG_FILE"
    fi
else
    echo "✅ No Ocean controller detected." | tee -a "$LOG_FILE"
fi

# Show what will be deleted and get confirmation
if [ ${#NAMESPACES_TO_DELETE[@]} -eq 0 ]; then
    print_info "No application namespaces found to delete"
    exit 0
fi

print_info "Namespaces that will be deleted:"
for ns in "${NAMESPACES_TO_DELETE[@]}"; do
    echo "  - $ns"
done

if [ "$DRY_RUN" != true ] && [ "$FORCE" != true ]; then
    echo
    print_warning "This will permanently delete ${#NAMESPACES_TO_DELETE[@]} namespace(s) and all resources within them"
    read -p "Are you sure you want to continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Cleanup cancelled"
        exit 0
    fi
fi

# Delete non-protected namespaces
for ns in "${NAMESPACES_TO_DELETE[@]}"; do
    if "$DRY_RUN"; then
        print_info "Would delete namespace: $ns"
    else
        print_info "Deleting namespace: $ns"
        if kubectl delete ns "$ns" --timeout=300s >> "$LOG_FILE" 2>&1; then
            print_info "Successfully deleted namespace: $ns"
        else
            print_warning "Failed to delete namespace: $ns (check log for details)"
        fi
    fi
done

print_info "Namespace cleanup complete. Log saved to $LOG_FILE"
