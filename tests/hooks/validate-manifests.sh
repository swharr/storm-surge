#!/bin/bash
# Kubernetes Manifest Validation Hook

set -e

echo "🔍 Validating Kubernetes manifests..."

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "⚠️  kubectl not found - skipping manifest validation"
    exit 0
fi

# Validate each manifest directory
validate_dir() {
    local dir=$1
    echo "  📂 Validating $dir..."
    
    if [[ -f "$dir/kustomization.yaml" ]]; then
        # Use kustomize for validation
        if kubectl kustomize "$dir" > /dev/null 2>&1; then
            echo "  ✅ $dir manifests are valid"
        else
            echo "  ❌ $dir manifests failed validation"
            kubectl kustomize "$dir" 2>&1 | head -10
            return 1
        fi
    else
        # Validate individual YAML files
        for file in "$dir"/*.yaml "$dir"/*.yml; do
            if [[ -f "$file" ]]; then
                if kubectl apply --dry-run=client -f "$file" > /dev/null 2>&1; then
                    echo "  ✅ $(basename "$file") is valid"
                else
                    echo "  ❌ $(basename "$file") failed validation"
                    kubectl apply --dry-run=client -f "$file" 2>&1 | head -5
                    return 1
                fi
            fi
        done
    fi
}

# Validate manifest directories
if [[ -d "manifests" ]]; then
    for dir in manifests/*/; do
        if [[ -d "$dir" ]]; then
            validate_dir "$dir"
        fi
    done
else
    echo "⚠️  No manifests directory found"
fi

echo "✅ All Kubernetes manifests validated successfully"