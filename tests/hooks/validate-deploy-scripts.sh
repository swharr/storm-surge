#!/bin/bash
# Deployment Script Validation Hook

set -e

echo "Validating deployment scripts..."

# Check script syntax
check_script_syntax() {
    local script=$1
    echo "  Checking syntax: $(basename "$script")"

    if bash -n "$script"; then
        echo "  OK: $(basename "$script") syntax is valid"
    else
        echo "  ERROR: $(basename "$script") has syntax errors"
        return 1
    fi
}

# Check for required functions/variables
check_script_requirements() {
    local script=$1
    local basename_script
    basename_script=$(basename "$script")

    echo "  Checking requirements: $basename_script"

    # Provider scripts should use environment variables
    if [[ "$script" == *"/providers/"* ]]; then
        if grep -q "STORM_REGION" "$script" && grep -q "STORM_ZONE" "$script" && grep -q "STORM_NODES" "$script"; then
            echo "  OK: $basename_script uses required environment variables"
        else
            echo "  ERROR: $basename_script missing required environment variables (STORM_REGION, STORM_ZONE, STORM_NODES)"
            return 1
        fi
    fi

    # Check for proper error handling
    if grep -q "set -e" "$script"; then
        echo "  OK: $basename_script has error handling enabled"
    else
        echo "  WARN: $basename_script missing 'set -e' for error handling"
    fi

    # Check for help/usage function in main scripts
    if [[ "$basename_script" == "deploy.sh" ]]; then
        if grep -q "show_usage" "$script"; then
        echo "  OK: $basename_script has usage function"
        else
            echo "  ERROR: $basename_script missing usage function"
            return 1
        fi
    fi
}

# Test script parameter validation
test_parameter_validation() {
    local script=$1
    local basename_script
    basename_script=$(basename "$script")

    echo "  Testing parameter validation: $basename_script"

    # Test help parameter for main deploy script
    if [[ "$basename_script" == "deploy.sh" ]]; then
        if timeout 5 "$script" --help > /dev/null 2>&1; then
            echo "  ERROR: deploy.sh should exit with error for --help"
            return 1
        else
            echo "  OK: deploy.sh help parameter working"
        fi

        # Test invalid provider
        if echo "n" | timeout 5 "$script" --provider=invalid > /dev/null 2>&1; then
            echo "  ERROR: deploy.sh should reject invalid provider"
            return 1
        else
            echo "  OK: deploy.sh invalid provider validation working"
        fi
    fi

    # Test zone validation for provider scripts
    if [[ "$basename_script" == "gke.sh" ]]; then
        export STORM_REGION="us-central1"
        export STORM_ZONE="us-west-2-a"
        export STORM_NODES="3"

        if timeout 5 "$script" > /dev/null 2>&1; then
            echo "  ERROR: gke.sh should reject mismatched zone/region"
            return 1
        else
            echo "  OK: gke.sh zone validation working"
        fi

        unset STORM_REGION STORM_ZONE STORM_NODES
    fi
}

# Validate all scripts in scripts directory
if [[ -d "scripts" ]]; then
    find scripts -name "*.sh" -type f | while read -r script; do
        check_script_syntax "$script"
        check_script_requirements "$script"

        # Only test parameter validation if script is executable
        if [[ -x "$script" ]]; then
            test_parameter_validation "$script"
        fi
    done
else
    echo "WARN: No scripts directory found"
fi

echo "OK: All deployment scripts validated successfully"
