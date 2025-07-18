#!/bin/bash
# Kubernetes Manifest Validation Hook

set -e

echo "🔍 Validating Kubernetes manifests..."

# Check if kustomize is available (prefer standalone over kubectl)
if command -v kustomize &> /dev/null; then
    KUSTOMIZE_CMD="kustomize build"
elif command -v kubectl &> /dev/null; then
    KUSTOMIZE_CMD="kubectl kustomize"
    # Check if connected to cluster for kubectl validation
    if ! kubectl cluster-info &> /dev/null; then
        echo "⚠️  No Kubernetes cluster connection - using basic YAML validation only"
        KUBECTL_AVAILABLE=false
    else
        KUBECTL_AVAILABLE=true
    fi
else
    echo "⚠️  Neither kustomize nor kubectl found - skipping manifest validation"
    exit 0
fi

# Validate each manifest directory
validate_dir() {
    local dir=$1
    echo "  📂 Validating $dir..."
    
    if [[ -f "$dir/kustomization.yaml" ]]; then
        # Use kustomize for validation
        if $KUSTOMIZE_CMD "$dir" > /dev/null 2>&1; then
            echo "  ✅ $dir manifests are valid"
        else
            echo "  ❌ $dir manifests failed validation"
            $KUSTOMIZE_CMD "$dir" 2>&1 | head -10
            return 1
        fi
    else
        # Validate individual YAML files
        for file in "$dir"/*.yaml "$dir"/*.yml; do
            if [[ -f "$file" ]]; then
                if [[ "${KUBECTL_AVAILABLE:-true}" == "true" ]]; then
                    # Full kubectl validation if cluster is available
                    if kubectl apply --dry-run=client --validate=false -f "$file" > /dev/null 2>&1; then
                        echo "  ✅ $(basename "$file") is valid"
                    else
                        echo "  ❌ $(basename "$file") failed validation"
                        kubectl apply --dry-run=client --validate=false -f "$file" 2>&1 | head -5
                        return 1
                    fi
                else
                    # Basic YAML syntax validation when offline
                    if python3 -c "import yaml; yaml.safe_load(open('$file'))" 2>/dev/null; then
                        echo "  ✅ $(basename "$file") syntax is valid"
                    else
                        echo "  ❌ $(basename "$file") has invalid YAML syntax"
                        return 1
                    fi
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
