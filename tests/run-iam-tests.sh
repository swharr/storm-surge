#!/bin/bash

# IAM Test Runner
# Runs all IAM-related tests with appropriate error handling

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}IAM Policy Test Suite${NC}"
echo -e "${BLUE}=========================================${NC}"
echo

# Test 1: Quick validation
echo -e "${BLUE}1. Quick IAM Validation${NC}"
if ./tests/validate-iam-quick.sh; then
    echo -e "${GREEN}PASSED: Quick validation${NC}"
else
    echo -e "${RED}FAILED: Quick validation${NC}"
    exit 1
fi
echo

# Test 2: Shell tests (if jq is available)
echo -e "${BLUE}2. Shell-based Tests${NC}"
if command -v jq >/dev/null 2>&1; then
    if ./tests/test-iam-policies.sh >/dev/null 2>&1; then
        echo -e "${GREEN}PASSED: Shell tests${NC}"
    else
        echo -e "${RED}FAILED: Shell tests${NC}"
        echo "Running with verbose output:"
        ./tests/test-iam-policies.sh
        exit 1
    fi
else
    echo -e "${YELLOW}SKIPPED: jq not available, skipping shell tests${NC}"
fi
echo

# Test 3: Python tests (if PyYAML is available)
echo -e "${BLUE}3. Python-based Tests${NC}"
if python3 -c "import yaml" >/dev/null 2>&1; then
    if python3 tests/test_iam_policies.py >/dev/null 2>&1; then
        echo -e "${GREEN}PASSED: Python tests${NC}"
    else
        echo -e "${RED}FAILED: Python tests${NC}"
        echo "Running with verbose output:"
        python3 tests/test_iam_policies.py -v
        exit 1
    fi
else
    echo -e "${YELLOW}SKIPPED: PyYAML not available, skipping Python tests${NC}"
fi
echo

# Test 4: Script syntax validation
echo -e "${BLUE}4. Script Syntax Validation${NC}"
failed_scripts=0
for script in scripts/iam/*.sh manifests/providerIAM/validate-permissions.sh; do
    if [ -f "$script" ]; then
        if bash -n "$script" >/dev/null 2>&1; then
            echo -e "${GREEN}PASSED${NC} $script"
        else
            echo -e "${RED}FAILED${NC} $script"
            failed_scripts=$((failed_scripts + 1))
        fi
    fi
done

if [ $failed_scripts -eq 0 ]; then
    echo -e "${GREEN}All scripts have valid syntax${NC}"
else
    echo -e "${RED}$failed_scripts scripts have syntax errors${NC}"
    exit 1
fi
echo

# Summary
echo -e "${BLUE}=========================================${NC}"
echo -e "${GREEN}All IAM tests completed successfully!${NC}"
echo -e "${BLUE}=========================================${NC}"