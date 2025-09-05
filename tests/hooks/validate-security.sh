#!/bin/bash
# Security Validation Hook

set -e

echo "Validating security configurations..."

# Check for security contexts in deployments
check_security_contexts() {
    echo "  Checking security contexts..."

    local violations=0

    # Find all deployment files
    while IFS= read -r file; do
        first_kind=$(grep -m1 '^kind:' "$file" | awk '{print $2}')
        if [[ "$first_kind" == "Deployment" ]]; then
            echo "    Checking $(basename "$file")"

            # Check for runAsNonRoot
            if grep -A 20 "securityContext:" "$file" | grep -q "runAsNonRoot: true"; then
                echo "    OK: $(basename "$file") has runAsNonRoot: true"
            else
                echo "    ERROR: $(basename "$file") missing runAsNonRoot: true"
                violations=$((violations + 1))
            fi

            # Check for specific user ID (not root)
            if grep -A 20 "securityContext:" "$file" | grep -q "runAsUser:" && ! grep -A 20 "securityContext:" "$file" | grep -q "runAsUser: 0"; then
                echo "    OK: $(basename "$file") runs as non-root user"
            else
                echo "    ERROR: $(basename "$file") may run as root user"
                violations=$((violations + 1))
            fi

            # Check for privileged containers
            if grep -q "privileged: true" "$file"; then
                echo "    ERROR: $(basename "$file") has privileged containers"
                violations=$((violations + 1))
            else
                echo "    OK: $(basename "$file") no privileged containers"
            fi
        fi
    done < <(find manifests \( -name "*.yaml" -o -name "*.yml" \))

    return $violations
}

# Check for resource limits
check_resource_limits() {
    echo "  Checking resource limits..."

    local violations=0

    while IFS= read -r file; do
        first_kind=$(grep -m1 '^kind:' "$file" | awk '{print $2}')
        if [[ "$first_kind" == "Deployment" ]]; then
            echo "    Checking $(basename "$file")"

            # Check for resource requests
            if grep -A 10 "resources:" "$file" | grep -q "requests:"; then
                echo "    OK: $(basename "$file") has resource requests"
            else
                echo "    ERROR: $(basename "$file") missing resource requests"
                violations=$((violations + 1))
            fi

            # Check for resource limits
            if grep -A 10 "resources:" "$file" | grep -q "limits:"; then
                echo "    OK: $(basename "$file") has resource limits"
            else
                echo "    ERROR: $(basename "$file") missing resource limits"
                violations=$((violations + 1))
            fi
        fi
    done < <(find manifests \( -name "*.yaml" -o -name "*.yml" \))

    return $violations
}

# Check for hardcoded secrets
check_hardcoded_secrets() {
    echo "  Checking for hardcoded secrets..."

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

    while IFS= read -r file; do
        for pattern in "${patterns[@]}"; do
            if grep -i "$pattern" "$file" | grep -v "secretKeyRef\|configMapKeyRef\|valueFrom\|name:\|key:" > /dev/null 2>&1; then
                # Ignore dummy/example values
                if grep -iE "dummy|example|changeme|placeholder|test|sample|fake|mock|yourdomain|ocn-" "$file" > /dev/null; then
                    continue
                fi
                echo "    ERROR: $(basename "$file") may contain hardcoded secrets"
                violations=$((violations + 1))
                break
            fi
        done
    done < <(find manifests \( -name "*.yaml" -o -name "*.yml" \))

    if [[ $violations -eq 0 ]]; then
        echo "    OK: No hardcoded secrets detected"
    fi

    return $violations
}

# Check for proper image tags
check_image_tags() {
    echo "  Checking image tags..."

    local violations=0

    while IFS= read -r file; do
        # Look for images with latest tag or no tag
        if grep "image:" "$file" | grep -E ":latest|:[[:space:]]*$" > /dev/null 2>&1; then
            echo "    ERROR: $(basename "$file") uses 'latest' tag or no tag"
            violations=$((violations + 1))
        else
            echo "    OK: $(basename "$file") uses specific image tags"
        fi
    done < <(find manifests \( -name "*.yaml" -o -name "*.yml" \))

    return $violations
}

# Check for network policies (optional but recommended)
check_network_policies() {
    echo "  Checking network policies..."

    if find manifests \( -name "*.yaml" -o -name "*.yml" \) -exec grep -l "kind: NetworkPolicy" {} + > /dev/null 2>&1; then
        echo "    OK: Network policies found"
    else
        echo "    WARN: No network policies found (recommended for production)"
    fi
}

# Run all security checks
main() {
    if [[ ! -d "manifests" ]]; then
        echo "WARN: No manifests directory found - skipping security validation"
        exit 0
    fi

    local total_violations=0
    local violations

    check_security_contexts
    violations=$?
    total_violations=$((total_violations + violations))

    check_resource_limits
    violations=$?
    total_violations=$((total_violations + violations))

    check_hardcoded_secrets
    violations=$?
    total_violations=$((total_violations + violations))

    check_image_tags
    violations=$?
    total_violations=$((total_violations + violations))

    check_network_policies

    if [[ $total_violations -gt 0 ]]; then
        echo "❌ Security validation failed with $total_violations violations"
        exit 1
    else
        echo "✅ All security validations passed"
    fi
}

main "$@"
