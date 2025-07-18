#!/bin/bash

set -e

LOG_FILE="cluster-cleanup-$(date +%Y%m%d-%H%M%S).log"
PROTECTED_NAMESPACES=("kube-system" "default" "kube-public" "kube-node-lease" "gatekeeper-system" "aws-observability" "azure-system" "gke-system")
DRY_RUN=false
FORCE=false

echo "🔍 Starting cluster cleanup..." | tee -a "$LOG_FILE"

# Parse arguments
for arg in "$@"; do
    case $arg in
        --dry-run)
            DRY_RUN=true
            ;;
        --force)
            FORCE=true
            ;;
        *)
            echo "❌ Unknown argument: \"$arg\"" | tee -a "$LOG_FILE"
            exit 1
            ;;
    esac
done

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
        kubectl delete crd $(kubectl get crd | grep spotinst | awk '{print $1}') >> "$LOG_FILE" 2>&1 || true
    else
        echo "⚠️  Ocean controller would be removed (dry-run)" | tee -a "$LOG_FILE"
    fi
else
    echo "✅ No Ocean controller detected." | tee -a "$LOG_FILE"
fi

# Delete non-protected namespaces
for ns in "${NAMESPACES_TO_DELETE[@]}"; do
    if "$DRY_RUN"; then
        echo "🚫 Would delete namespace: $ns" | tee -a "$LOG_FILE"
    elif "$FORCE"; then
        echo "🗑️ Deleting namespace: $ns" | tee -a "$LOG_FILE"
        kubectl delete ns "$ns" >> "$LOG_FILE" 2>&1 || true
    fi
done

echo "✅ Cleanup complete. Log saved to $LOG_FILE"
