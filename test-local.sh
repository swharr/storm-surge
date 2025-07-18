#!/bin/bash
# Local Testing Script for Storm Surge
# Quick validation before committing changes

set -e

echo "🧪 Storm Surge Local Test Runner"
echo "================================="
echo

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

success() { echo -e "${GREEN}✅ $1${NC}"; }
error() { echo -e "${RED}❌ $1${NC}"; }
warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }

# Test 1: Script syntax validation
echo "1️⃣  Testing script syntax..."
if find scripts -name "*.sh" -exec bash -n {} \; > /dev/null 2>&1; then
    success "All scripts have valid syntax"
else
    error "Script syntax errors found"
    find scripts -name "*.sh" -exec bash -n {} \; 2>&1 | head -10
    exit 1
fi

# Test 2: Deployment script parameter validation
echo "2️⃣  Testing deployment script parameters..."
if timeout 5 ./scripts/deploy.sh --help > /dev/null 2>&1; then
    error "Deploy script should exit with error for --help"
    exit 1
else
    success "Help parameter validation working"
fi

# Test 3: Zone/region validation
echo "3️⃣  Testing zone/region validation..."
export STORM_REGION="us-central1"
export STORM_ZONE="us-west-2-a"
export STORM_NODES="3"

if timeout 5 ./scripts/providers/gke.sh > /dev/null 2>&1; then
    error "GKE script should reject mismatched zone/region"
    exit 1
else
    success "Zone/region validation working"
fi

unset STORM_REGION STORM_ZONE STORM_NODES

# Test 4: Kubernetes manifest validation (offline-friendly)
echo "4️⃣  Testing Kubernetes manifests..."
if command -v kustomize &> /dev/null; then
    # Use standalone kustomize for offline validation
    if kustomize build manifests/base/ > /dev/null 2>&1; then
        success "Base manifests are valid"
    else
        error "Base manifests validation failed"
        kustomize build manifests/base/ 2>&1 | head -5
        exit 1
    fi
    
    if kustomize build manifests/middleware/ > /dev/null 2>&1; then
        success "Middleware manifests are valid"
    else
        error "Middleware manifests validation failed"
        kustomize build manifests/middleware/ 2>&1 | head -5
        exit 1
    fi
elif command -v kubectl &> /dev/null; then
    # Fallback to kubectl if cluster is available and not in CI
    if [[ -z "$CI" && -z "$GITHUB_ACTIONS" ]] && kubectl cluster-info &> /dev/null; then
        if kubectl kustomize manifests/base/ > /dev/null 2>&1; then
            success "Base manifests are valid"
        else
            error "Base manifests validation failed"
            kubectl kustomize manifests/base/ 2>&1 | head -5
            exit 1
        fi
        
        if kubectl kustomize manifests/middleware/ > /dev/null 2>&1; then
            success "Middleware manifests are valid"
        else
            error "Middleware manifests validation failed"
            kubectl kustomize manifests/middleware/ 2>&1 | head -5
            exit 1
        fi
    else
        warning "No Kubernetes cluster connection - skipping manifest validation"
    fi
else
    warning "Neither kustomize nor kubectl found - skipping manifest validation"
fi

# Test 5: Security configuration check
echo "5️⃣  Testing security configurations..."
violations=0

# Check for runAsNonRoot in deployments
if ! find manifests -name "*.yaml" -exec grep -l "kind: Deployment" {} \; | xargs grep -c "runAsNonRoot: true" > /dev/null 2>&1; then
    warning "Some deployments may be missing runAsNonRoot: true"
    violations=$((violations + 1))
fi

# Check for resource limits
if ! find manifests -name "*.yaml" -exec grep -l "kind: Deployment" {} \; | xargs grep -c "limits:" > /dev/null 2>&1; then
    warning "Some deployments may be missing resource limits"
    violations=$((violations + 1))
fi

if [[ $violations -eq 0 ]]; then
    success "Security configurations look good"
else
    warning "Found $violations potential security issues"
fi

# Test 6: Check for hardcoded secrets
echo "6️⃣  Checking for hardcoded secrets..."
if grep -r -i "password\|token\|key\|secret" manifests/ | grep -v "secretKeyRef\|configMapKeyRef\|valueFrom" | grep -v ".git" > /dev/null 2>&1; then
    warning "Potential hardcoded secrets found:"
    grep -r -i "password\|token\|key\|secret" manifests/ | grep -v "secretKeyRef\|configMapKeyRef\|valueFrom" | head -3
else
    success "No hardcoded secrets detected"
fi

echo
echo "🎉 Local tests completed!"
echo
echo "Next steps:"
echo "  • Run full test suite: ./tests/test-suite.sh"
echo "  • Install pre-commit: pip install pre-commit && pre-commit install"
echo "  • Commit changes: git add . && git commit -m 'your message'"
echo
