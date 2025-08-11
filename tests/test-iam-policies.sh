#!/bin/bash

# IAM Policy Validation Tests
# Validates IAM policy files are properly formatted and contain required permissions

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test results
TESTS_PASSED=0
TESTS_FAILED=0

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

print_test_header() {
    echo -e "${BLUE}=========================================${NC}"
    echo -e "${BLUE}IAM Policy Validation Tests${NC}"
    echo -e "${BLUE}=========================================${NC}"
    echo
}

pass_test() {
    echo -e "${GREEN}✓ PASS${NC}: $1"
    ((TESTS_PASSED++))
}

fail_test() {
    echo -e "${RED}✗ FAIL${NC}: $1"
    echo -e "  ${YELLOW}Reason: $2${NC}"
    ((TESTS_FAILED++))
}

# Test AWS IAM Policy
test_aws_iam_policy() {
    echo -e "\n${BLUE}Testing AWS IAM Policy...${NC}"
    
    local policy_file="$PROJECT_ROOT/manifests/providerIAM/aws/eks-admin-policy.json"
    
    # Test 1: File exists
    if [ -f "$policy_file" ]; then
        pass_test "AWS policy file exists"
    else
        fail_test "AWS policy file exists" "File not found: $policy_file"
        return
    fi
    
    # Test 2: Valid JSON
    if jq empty "$policy_file" 2>/dev/null; then
        pass_test "AWS policy is valid JSON"
    else
        fail_test "AWS policy is valid JSON" "Invalid JSON syntax"
        return
    fi
    
    # Test 3: Has required structure
    local version=$(jq -r '.Version' "$policy_file")
    if [ "$version" = "2012-10-17" ]; then
        pass_test "AWS policy has correct version"
    else
        fail_test "AWS policy has correct version" "Expected '2012-10-17', got '$version'"
    fi
    
    # Test 4: Has statements
    local statement_count=$(jq '.Statement | length' "$policy_file")
    if [ "$statement_count" -gt 0 ]; then
        pass_test "AWS policy has statements ($statement_count found)"
    else
        fail_test "AWS policy has statements" "No statements found"
    fi
    
    # Test 5: Check for required EKS permissions
    local eks_perms=$(jq -r '.Statement[] | select(.Action[]? | contains("eks:")) | .Action[]' "$policy_file" | grep -c "eks:" || true)
    if [ "$eks_perms" -gt 0 ]; then
        pass_test "AWS policy includes EKS permissions ($eks_perms actions)"
    else
        fail_test "AWS policy includes EKS permissions" "No eks:* actions found"
    fi
    
    # Test 6: Check for required EC2 permissions
    local ec2_perms=$(jq -r '.Statement[] | select(.Action[]? | contains("ec2:")) | .Action[]' "$policy_file" | grep -c "ec2:" || true)
    if [ "$ec2_perms" -gt 0 ]; then
        pass_test "AWS policy includes EC2 permissions ($ec2_perms actions)"
    else
        fail_test "AWS policy includes EC2 permissions" "No ec2:* actions found"
    fi
    
    # Test 7: Check for required IAM permissions
    local iam_perms=$(jq -r '.Statement[] | select(.Action[]? | contains("iam:")) | .Action[]' "$policy_file" | grep -c "iam:" || true)
    if [ "$iam_perms" -gt 0 ]; then
        pass_test "AWS policy includes IAM permissions ($iam_perms actions)"
    else
        fail_test "AWS policy includes IAM permissions" "No iam:* actions found"
    fi
    
    # Test 8: Check critical EKS permissions
    local critical_perms=("eks:CreateCluster" "eks:DeleteCluster" "eks:UpdateClusterConfig" "eks:DescribeCluster")
    local missing_perms=()
    
    for perm in "${critical_perms[@]}"; do
        if ! jq -r '.Statement[].Action[]?' "$policy_file" | grep -q "^${perm}$\|^eks:\*$"; then
            missing_perms+=("$perm")
        fi
    done
    
    if [ ${#missing_perms[@]} -eq 0 ]; then
        pass_test "AWS policy has critical EKS permissions"
    else
        fail_test "AWS policy has critical EKS permissions" "Missing: ${missing_perms[*]}"
    fi
}

# Test GCP IAM Role
test_gcp_iam_role() {
    echo -e "\n${BLUE}Testing GCP IAM Role...${NC}"
    
    local role_file="$PROJECT_ROOT/manifests/providerIAM/gcp/gke-admin-role.yaml"
    
    # Test 1: File exists
    if [ -f "$role_file" ]; then
        pass_test "GCP role file exists"
    else
        fail_test "GCP role file exists" "File not found: $role_file"
        return
    fi
    
    # Test 2: Valid YAML
    if python3 -c "import yaml; yaml.safe_load(open('$role_file'))" 2>/dev/null; then
        pass_test "GCP role is valid YAML"
    else
        fail_test "GCP role is valid YAML" "Invalid YAML syntax"
        return
    fi
    
    # Test 3: Has required fields
    local title=$(python3 -c "import yaml; print(yaml.safe_load(open('$role_file')).get('title', ''))")
    if [ -n "$title" ]; then
        pass_test "GCP role has title: $title"
    else
        fail_test "GCP role has title" "Title field missing"
    fi
    
    # Test 4: Has permissions
    local perm_count=$(python3 -c "import yaml; print(len(yaml.safe_load(open('$role_file')).get('includedPermissions', [])))")
    if [ "$perm_count" -gt 0 ]; then
        pass_test "GCP role has permissions ($perm_count found)"
    else
        fail_test "GCP role has permissions" "No permissions found"
    fi
    
    # Test 5: Check for GKE permissions
    local gke_perms=$(grep -c "container\." "$role_file" || true)
    if [ "$gke_perms" -gt 0 ]; then
        pass_test "GCP role includes GKE permissions ($gke_perms found)"
    else
        fail_test "GCP role includes GKE permissions" "No container.* permissions found"
    fi
    
    # Test 6: Check for Compute permissions
    local compute_perms=$(grep -c "compute\." "$role_file" || true)
    if [ "$compute_perms" -gt 0 ]; then
        pass_test "GCP role includes Compute permissions ($compute_perms found)"
    else
        fail_test "GCP role includes Compute permissions" "No compute.* permissions found"
    fi
    
    # Test 7: Check critical GKE permissions
    local critical_perms=("container.clusters.create" "container.clusters.delete" "container.clusters.update" "container.clusters.get")
    local missing_perms=()
    
    for perm in "${critical_perms[@]}"; do
        if ! grep -q "^- $perm$" "$role_file"; then
            missing_perms+=("$perm")
        fi
    done
    
    if [ ${#missing_perms[@]} -eq 0 ]; then
        pass_test "GCP role has critical GKE permissions"
    else
        fail_test "GCP role has critical GKE permissions" "Missing: ${missing_perms[*]}"
    fi
}

# Test Azure RBAC Role
test_azure_rbac_role() {
    echo -e "\n${BLUE}Testing Azure RBAC Role...${NC}"
    
    local role_file="$PROJECT_ROOT/manifests/providerIAM/azure/aks-admin-role.json"
    
    # Test 1: File exists
    if [ -f "$role_file" ]; then
        pass_test "Azure role file exists"
    else
        fail_test "Azure role file exists" "File not found: $role_file"
        return
    fi
    
    # Test 2: Valid JSON
    if jq empty "$role_file" 2>/dev/null; then
        pass_test "Azure role is valid JSON"
    else
        fail_test "Azure role is valid JSON" "Invalid JSON syntax"
        return
    fi
    
    # Test 3: Has required fields
    local name=$(jq -r '.Name' "$role_file")
    if [ -n "$name" ] && [ "$name" != "null" ]; then
        pass_test "Azure role has name: $name"
    else
        fail_test "Azure role has name" "Name field missing"
    fi
    
    # Test 4: Has actions
    local action_count=$(jq '.Actions | length' "$role_file")
    if [ "$action_count" -gt 0 ]; then
        pass_test "Azure role has actions ($action_count found)"
    else
        fail_test "Azure role has actions" "No actions found"
    fi
    
    # Test 5: Check for AKS permissions
    local aks_perms=$(jq -r '.Actions[]' "$role_file" | grep -c "Microsoft.ContainerService" || true)
    if [ "$aks_perms" -gt 0 ]; then
        pass_test "Azure role includes AKS permissions ($aks_perms actions)"
    else
        fail_test "Azure role includes AKS permissions" "No Microsoft.ContainerService/* actions found"
    fi
    
    # Test 6: Check for Compute permissions
    local compute_perms=$(jq -r '.Actions[]' "$role_file" | grep -c "Microsoft.Compute" || true)
    if [ "$compute_perms" -gt 0 ]; then
        pass_test "Azure role includes Compute permissions ($compute_perms actions)"
    else
        fail_test "Azure role includes Compute permissions" "No Microsoft.Compute/* actions found"
    fi
    
    # Test 7: Check for Network permissions
    local network_perms=$(jq -r '.Actions[]' "$role_file" | grep -c "Microsoft.Network" || true)
    if [ "$network_perms" -gt 0 ]; then
        pass_test "Azure role includes Network permissions ($network_perms actions)"
    else
        fail_test "Azure role includes Network permissions" "No Microsoft.Network/* actions found"
    fi
    
    # Test 8: Has assignable scopes
    local scope_count=$(jq '.AssignableScopes | length' "$role_file")
    if [ "$scope_count" -gt 0 ]; then
        pass_test "Azure role has assignable scopes"
    else
        fail_test "Azure role has assignable scopes" "No assignable scopes defined"
    fi
}

# Test IAM validation script
test_validation_script() {
    echo -e "\n${BLUE}Testing IAM Validation Script...${NC}"
    
    local script_file="$PROJECT_ROOT/manifests/providerIAM/validate-permissions.sh"
    
    # Test 1: File exists
    if [ -f "$script_file" ]; then
        pass_test "Validation script exists"
    else
        fail_test "Validation script exists" "File not found: $script_file"
        return
    fi
    
    # Test 2: Is executable
    if [ -x "$script_file" ]; then
        pass_test "Validation script is executable"
    else
        fail_test "Validation script is executable" "Script not executable"
    fi
    
    # Test 3: Has shebang
    if head -1 "$script_file" | grep -q "^#!/bin/bash"; then
        pass_test "Validation script has proper shebang"
    else
        fail_test "Validation script has proper shebang" "Missing or incorrect shebang"
    fi
    
    # Test 4: Syntax check
    if bash -n "$script_file" 2>/dev/null; then
        pass_test "Validation script has valid syntax"
    else
        fail_test "Validation script has valid syntax" "Bash syntax errors found"
    fi
}

# Test IAM setup scripts
test_iam_setup_scripts() {
    echo -e "\n${BLUE}Testing IAM Setup Scripts...${NC}"
    
    local providers=("aws" "gcp" "azure")
    
    for provider in "${providers[@]}"; do
        local script_file="$PROJECT_ROOT/scripts/iam/apply-${provider}-iam.sh"
        
        # Test 1: File exists
        if [ -f "$script_file" ]; then
            pass_test "$provider IAM setup script exists"
        else
            fail_test "$provider IAM setup script exists" "File not found: $script_file"
            continue
        fi
        
        # Test 2: Is executable
        if [ -x "$script_file" ]; then
            pass_test "$provider IAM setup script is executable"
        else
            fail_test "$provider IAM setup script is executable" "Script not executable"
        fi
        
        # Test 3: Syntax check
        if bash -n "$script_file" 2>/dev/null; then
            pass_test "$provider IAM setup script has valid syntax"
        else
            fail_test "$provider IAM setup script has valid syntax" "Bash syntax errors found"
        fi
    done
}

# Test README files
test_readme_files() {
    echo -e "\n${BLUE}Testing README Documentation...${NC}"
    
    local providers=("aws" "gcp" "azure")
    
    # Test main README
    if [ -f "$PROJECT_ROOT/manifests/providerIAM/README.md" ]; then
        pass_test "Main providerIAM README exists"
    else
        fail_test "Main providerIAM README exists" "File not found"
    fi
    
    # Test provider-specific READMEs
    for provider in "${providers[@]}"; do
        local readme="$PROJECT_ROOT/manifests/providerIAM/$provider/README.md"
        if [ -f "$readme" ]; then
            pass_test "$provider README exists"
            
            # Check for required sections
            if grep -q "Usage" "$readme"; then
                pass_test "$provider README has Usage section"
            else
                fail_test "$provider README has Usage section" "Missing Usage instructions"
            fi
            
            if grep -q "Security" "$readme"; then
                pass_test "$provider README has Security section"
            else
                fail_test "$provider README has Security section" "Missing Security considerations"
            fi
        else
            fail_test "$provider README exists" "File not found: $readme"
        fi
    done
}

# Print summary
print_summary() {
    echo
    echo -e "${BLUE}=========================================${NC}"
    echo -e "${BLUE}Test Summary${NC}"
    echo -e "${BLUE}=========================================${NC}"
    echo
    echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"
    echo
    
    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}All IAM policy tests passed!${NC}"
        return 0
    else
        echo -e "${RED}Some IAM policy tests failed!${NC}"
        return 1
    fi
}

# Main execution
main() {
    print_test_header
    
    # Check dependencies
    if ! command -v jq &>/dev/null; then
        echo -e "${YELLOW}Warning: jq not installed. Some tests will be skipped.${NC}"
    fi
    
    if ! command -v python3 &>/dev/null; then
        echo -e "${YELLOW}Warning: python3 not installed. Some tests will be skipped.${NC}"
    fi
    
    # Run tests
    test_aws_iam_policy
    test_gcp_iam_role
    test_azure_rbac_role
    test_validation_script
    test_iam_setup_scripts
    test_readme_files
    
    # Print summary and exit with appropriate code
    print_summary
}

# Run main function
main "$@"