#!/bin/bash
# Security Validation Hook

set -e

echo "🔒 Validating security configurations..."

# Check for security contexts in deployments
check_security_contexts() {
    echo "  👤 Checking security contexts..."
    
    local violations=0
    
    # Find all deployment files
    find manifests -name "*.yaml" -o -name "*.yml" | while read -r file; do
        if grep -q "kind: Deployment" "$file"; then
            echo "    📄 Checking $(basename "$file")"
            
            # Check for runAsNonRoot
            if grep -A 20 "securityContext:" "$file" | grep -q "runAsNonRoot: true"; then
                echo "    ✅ $(basename "$file") has runAsNonRoot: true"
            else
                echo "    ❌ $(basename "$file") missing runAsNonRoot: true"
                violations=$((violations + 1))
            fi
            
            # Check for specific user ID (not root)
            if grep -A 20 "securityContext:" "$file" | grep -q "runAsUser:" && ! grep -A 20 "securityContext:" "$file" | grep -q "runAsUser: 0"; then
                echo "    ✅ $(basename "$file") runs as non-root user"
            else
                echo "    ❌ $(basename "$file") may run as root user"
                violations=$((violations + 1))
            fi
            
            # Check for privileged containers
            if grep -q "privileged: true" "$file"; then
                echo "    ❌ $(basename "$file") has privileged containers"
                violations=$((violations + 1))
            else
                echo "    ✅ $(basename "$file") no privileged containers"
            fi
        fi
    done
    
    return $violations
}

# Check for resource limits
check_resource_limits() {
    echo "  💾 Checking resource limits..."
    
    local violations=0
    
    find manifests -name "*.yaml" -o -name "*.yml" | while read -r file; do
        if grep -q "kind: Deployment" "$file"; then
            echo "    📄 Checking $(basename "$file")"
            
            # Check for resource requests
            if grep -A 10 "resources:" "$file" | grep -q "requests:"; then
                echo "    ✅ $(basename "$file") has resource requests"
            else
                echo "    ❌ $(basename "$file") missing resource requests"
                violations=$((violations + 1))
            fi
            
            # Check for resource limits
            if grep -A 10 "resources:" "$file" | grep -q "limits:"; then
                echo "    ✅ $(basename "$file") has resource limits"
            else
                echo "    ❌ $(basename "$file") missing resource limits"
                violations=$((violations + 1))
            fi
        fi
    done
    
    return $violations
}

# Check for hardcoded secrets
check_hardcoded_secrets() {
    echo "  🔑 Checking for hardcoded secrets..."
    
    local violations=0
    
    # Common secret patterns
    local patterns=(
        "password.*[:=]"
        "token.*[:=]"
        "key.*[:=]"
        "secret.*[:=]"
        "api_key"
        "apikey"
    )
    
    find manifests -name "*.yaml" -o -name "*.yml" | while read -r file; do
        for pattern in "${patterns[@]}"; do
            if grep -i "$pattern" "$file" | grep -v "secretKeyRef\|configMapKeyRef\|valueFrom" > /dev/null 2>&1; then
                echo "    ❌ $(basename "$file") may contain hardcoded secrets"
                violations=$((violations + 1))
                break
            fi
        done
    done
    
    if [[ $violations -eq 0 ]]; then
        echo "    ✅ No hardcoded secrets detected"
    fi
    
    return $violations
}

# Check for proper image tags
check_image_tags() {
    echo "  🏷️  Checking image tags..."
    
    local violations=0
    
    find manifests -name "*.yaml" -o -name "*.yml" | while read -r file; do
        # Look for images with latest tag or no tag
        if grep "image:" "$file" | grep -E ":latest|:[[:space:]]*$" > /dev/null 2>&1; then
            echo "    ❌ $(basename "$file") uses 'latest' tag or no tag"
            violations=$((violations + 1))
        else
            echo "    ✅ $(basename "$file") uses specific image tags"
        fi
    done
    
    return $violations
}

# Check for network policies (optional but recommended)
check_network_policies() {
    echo "  🌐 Checking network policies..."
    
    if find manifests -name "*.yaml" -o -name "*.yml" | xargs grep -l "kind: NetworkPolicy" > /dev/null 2>&1; then
        echo "    ✅ Network policies found"
    else
        echo "    ⚠️  No network policies found (recommended for production)"
    fi
}

# Run all security checks
main() {
    if [[ ! -d "manifests" ]]; then
        echo "⚠️  No manifests directory found - skipping security validation"
        exit 0
    fi
    
    local total_violations=0
    
    check_security_contexts
    total_violations=$((total_violations + $?))
    
    check_resource_limits
    total_violations=$((total_violations + $?))
    
    check_hardcoded_secrets
    total_violations=$((total_violations + $?))
    
    check_image_tags
    total_violations=$((total_violations + $?))
    
    check_network_policies
    
    if [[ $total_violations -gt 0 ]]; then
        echo "❌ Security validation failed with $total_violations violations"
        exit 1
    else
        echo "✅ All security validations passed"
    fi
}

main "$@"