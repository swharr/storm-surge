#!/bin/bash

# Storm Surge Core - Security Check Script
# Run this before committing to ensure security compliance

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}===========================================${NC}"
    echo -e "${BLUE}    Storm Surge Core Security Check${NC}"
    echo -e "${BLUE}===========================================${NC}"
    echo
}

print_check() {
    echo -e "${BLUE}[CHECK]${NC} $1"
}

print_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

print_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    FAILED=true
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Initialize
FAILED=false

print_header

# Check 1: Hardcoded credentials
# Excludes legitimate placeholders (CHANGEME_, REPLACE_WITH) and config patterns
print_check "Scanning for hardcoded credentials..."
if grep -r -i "password.*=" manifests/ --include="*.yaml" --include="*.yml" 2>/dev/null | \
   grep -v "REPLACE_WITH" | \
   grep -v "CHANGEME_" | \
   grep -v "#" | \
   grep -v "stringData:" | \
   grep -v "password_encryption" | \
   grep -v "postgresql.conf"; then
    print_fail "Found potential hardcoded passwords"
else
    print_pass "No hardcoded passwords found"
fi

# Check 2: API keys
print_check "Scanning for API keys..."
if grep -r -i "api.*key.*=" manifests/ --include="*.yaml" --include="*.yml" 2>/dev/null | \
   grep -v "REPLACE_WITH" | \
   grep -v "#"; then
    print_fail "Found potential API keys"
else
    print_pass "No hardcoded API keys found"
fi

# Check 3: Secret files
print_check "Scanning for secret files..."
if find . -name "*.pem" -o -name "*.key" -o -name "*.pfx" 2>/dev/null | grep -v ".git"; then
    print_fail "Found potential secret files"
else
    print_pass "No secret files found"
fi

# Check 4: Security contexts
print_check "Verifying security contexts..."
if grep -q "runAsNonRoot: true" manifests/middleware/deployment-minimal.yaml; then
    print_pass "Security context configured"
else
    print_fail "Missing runAsNonRoot in deployment"
fi

# Check 5: Resource limits
print_check "Verifying resource limits..."
if grep -q "limits:" manifests/middleware/deployment-minimal.yaml && \
   grep -q "requests:" manifests/middleware/deployment-minimal.yaml; then
    print_pass "Resource limits configured"
else
    print_fail "Missing resource limits"
fi

# Check 6: Namespace security
print_check "Verifying namespace security..."
if grep -q "pod-security.kubernetes.io/enforce: restricted" manifests/core/namespace.yaml; then
    print_pass "Pod Security Standards configured"
else
    print_warning "Pod Security Standards not enforced"
fi

# Check 7: Image tags
print_check "Verifying container images..."
if grep -r "image:.*:latest" manifests/ --include="*.yaml" 2>/dev/null; then
    print_warning "Found :latest tags (consider using specific versions)"
else
    print_pass "No :latest tags found"
fi

# Check 8: YAML validation
print_check "Validating YAML syntax..."
yaml_errors=0
for file in $(find manifests/ -name "*.yaml" -o -name "*.yml" 2>/dev/null); do
    # Skip non-Kubernetes files
    if grep -q "terraform\|aws::\|gcp::\|azure::" "$file" 2>/dev/null; then
        continue
    fi
    # Basic YAML syntax check
    if ! grep -E "^[a-zA-Z]|^---" "$file" >/dev/null 2>&1; then
        print_fail "Invalid YAML: $file"
        yaml_errors=$((yaml_errors + 1))
    fi
done
if [ $yaml_errors -eq 0 ]; then
    print_pass "YAML syntax check passed"
fi

# Summary
echo
echo -e "${BLUE}===========================================${NC}"
if [ "$FAILED" = true ]; then
    echo -e "${RED}Security check FAILED${NC}"
    echo "Please fix the issues above before committing"
    exit 1
else
    echo -e "${GREEN}Security check PASSED${NC}"
    echo "Ready to commit to GitHub"
fi
echo -e "${BLUE}===========================================${NC}"