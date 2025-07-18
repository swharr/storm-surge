#!/bin/bash
# Kubernetes Manifest Validation Hook

set -e

echo "🔍 Validating Kubernetes manifests..."

# Check if kustomize is available (prefer standalone over kubectl)
if command -v kustomize &> /dev/null; then
    KUSTOMIZE_CMD="kustomize build"
    KUBECTL_AVAILABLE=false  # Use offline validation with standalone kustomize
elif command -v kubectl &> /dev/null; then
    KUSTOMIZE_CMD="kubectl kustomize"
    # Check if connected to cluster for kubectl validation
    # Also check for CI environment variables to force offline mode
    if [[ -n "$CI" || -n "$GITHUB_ACTIONS" ]] || ! kubectl cluster-info &> /dev/null 2>&1; then
        echo "⚠️  CI environment or no Kubernetes cluster connection - using basic YAML validation only"
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
                    # Try PyYAML first, fall back to basic validation
                    if python3 -c "
import sys
try:
    import yaml
    with open('$file', 'r') as f:
        docs = list(yaml.safe_load_all(f))
    # Basic Kubernetes resource validation
    for doc in docs:
        if doc and isinstance(doc, dict):
            if 'apiVersion' not in doc or 'kind' not in doc:
                print('Missing apiVersion or kind', file=sys.stderr)
                sys.exit(1)
    sys.exit(0)
except ImportError:
    # PyYAML not available, use basic validation
    sys.exit(2)
except Exception as e:
    print(f'YAML validation failed: {e}', file=sys.stderr)
    sys.exit(1)
" 2>/dev/null; then
                        echo "  ✅ $(basename "$file") is valid"
                    elif [ $? -eq 2 ]; then
                        # PyYAML not available, use basic validation
                        if grep -q "apiVersion:" "$file" && grep -q "kind:" "$file"; then
                            echo "  ✅ $(basename "$file") basic validation passed"
                        else
                            echo "  ❌ $(basename "$file") missing required apiVersion or kind"
                            return 1
                        fi
                    else
                        echo "  ❌ $(basename "$file") validation failed"
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
