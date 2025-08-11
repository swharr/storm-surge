#!/bin/bash

# Storm Surge IAM Permission Validator
# Tests if the current credentials have the necessary permissions

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    echo -e "${BLUE}=====================================${NC}"
    echo -e "${BLUE}Storm Surge IAM Permission Validator${NC}"
    echo -e "${BLUE}=====================================${NC}"
    echo
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}!${NC} $1"
}

validate_aws() {
    echo -e "${BLUE}Validating AWS Permissions...${NC}"
    
    # Check if AWS CLI is configured
    if ! aws sts get-caller-identity &>/dev/null; then
        print_error "AWS credentials not configured or invalid"
        return 1
    fi
    
    local identity=$(aws sts get-caller-identity --output json)
    echo "Identity: $(echo $identity | jq -r '.Arn')"
    echo
    
    # Test critical permissions
    local failed=0
    
    # EKS permissions
    if aws eks list-clusters &>/dev/null; then
        print_success "EKS list clusters"
    else
        print_error "EKS list clusters"
        ((failed++))
    fi
    
    # EC2 permissions
    if aws ec2 describe-vpcs &>/dev/null; then
        print_success "EC2 describe VPCs"
    else
        print_error "EC2 describe VPCs"
        ((failed++))
    fi
    
    # IAM permissions
    if aws iam list-roles --max-items 1 &>/dev/null; then
        print_success "IAM list roles"
    else
        print_error "IAM list roles"
        ((failed++))
    fi
    
    # Auto Scaling permissions
    if aws autoscaling describe-auto-scaling-groups --max-records 1 &>/dev/null; then
        print_success "Auto Scaling describe groups"
    else
        print_error "Auto Scaling describe groups"
        ((failed++))
    fi
    
    if [ $failed -eq 0 ]; then
        echo -e "\n${GREEN}AWS permissions validated successfully!${NC}"
    else
        echo -e "\n${RED}AWS permission validation failed. $failed tests failed.${NC}"
        echo "Please ensure the IAM policy from aws/eks-admin-policy.json is applied."
    fi
    
    return $failed
}

validate_gcp() {
    echo -e "${BLUE}Validating GCP Permissions...${NC}"
    
    # Check if gcloud is configured
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" &>/dev/null; then
        print_error "GCP credentials not configured"
        return 1
    fi
    
    local account=$(gcloud auth list --filter=status:ACTIVE --format="value(account)")
    local project=$(gcloud config get-value project 2>/dev/null)
    echo "Account: $account"
    echo "Project: $project"
    echo
    
    # Test critical permissions
    local failed=0
    
    # GKE permissions
    if gcloud container clusters list --limit=1 &>/dev/null; then
        print_success "GKE list clusters"
    else
        print_error "GKE list clusters"
        ((failed++))
    fi
    
    # Compute permissions
    if gcloud compute instances list --limit=1 &>/dev/null; then
        print_success "Compute list instances"
    else
        print_error "Compute list instances"
        ((failed++))
    fi
    
    # IAM permissions
    if gcloud iam service-accounts list --limit=1 &>/dev/null; then
        print_success "IAM list service accounts"
    else
        print_error "IAM list service accounts"
        ((failed++))
    fi
    
    # Network permissions
    if gcloud compute networks list --limit=1 &>/dev/null; then
        print_success "Compute list networks"
    else
        print_error "Compute list networks"
        ((failed++))
    fi
    
    if [ $failed -eq 0 ]; then
        echo -e "\n${GREEN}GCP permissions validated successfully!${NC}"
    else
        echo -e "\n${RED}GCP permission validation failed. $failed tests failed.${NC}"
        echo "Please ensure the custom role from gcp/gke-admin-role.yaml is applied."
    fi
    
    return $failed
}

validate_azure() {
    echo -e "${BLUE}Validating Azure Permissions...${NC}"
    
    # Check if Azure CLI is configured
    if ! az account show &>/dev/null; then
        print_error "Azure credentials not configured"
        return 1
    fi
    
    local account=$(az account show --output json)
    echo "Subscription: $(echo $account | jq -r '.name')"
    echo "User: $(echo $account | jq -r '.user.name')"
    echo
    
    # Test critical permissions
    local failed=0
    
    # AKS permissions
    if az aks list --output table &>/dev/null; then
        print_success "AKS list clusters"
    else
        print_error "AKS list clusters"
        ((failed++))
    fi
    
    # Compute permissions
    if az vm list --output table &>/dev/null; then
        print_success "VM list"
    else
        print_error "VM list"
        ((failed++))
    fi
    
    # Network permissions
    if az network vnet list --output table &>/dev/null; then
        print_success "Network list VNets"
    else
        print_error "Network list VNets"
        ((failed++))
    fi
    
    # Identity permissions
    if az identity list --output table &>/dev/null; then
        print_success "Identity list"
    else
        print_error "Identity list"
        ((failed++))
    fi
    
    if [ $failed -eq 0 ]; then
        echo -e "\n${GREEN}Azure permissions validated successfully!${NC}"
    else
        echo -e "\n${RED}Azure permission validation failed. $failed tests failed.${NC}"
        echo "Please ensure the custom role from azure/aks-admin-role.json is applied."
    fi
    
    return $failed
}

# Main execution
print_header

# Check which cloud providers to validate
if [ $# -eq 0 ]; then
    echo "Usage: $0 [aws|gcp|azure|all]"
    echo
    echo "Examples:"
    echo "  $0 aws      # Validate AWS permissions only"
    echo "  $0 gcp      # Validate GCP permissions only"
    echo "  $0 azure    # Validate Azure permissions only"
    echo "  $0 all      # Validate all cloud providers"
    exit 1
fi

case $1 in
    aws)
        validate_aws
        ;;
    gcp)
        validate_gcp
        ;;
    azure)
        validate_azure
        ;;
    all)
        echo "Validating all cloud providers..."
        echo
        
        total_failed=0
        
        # AWS
        if command -v aws &>/dev/null; then
            validate_aws || total_failed=$((total_failed + $?))
            echo
        else
            print_warning "AWS CLI not installed, skipping AWS validation"
        fi
        
        # GCP
        if command -v gcloud &>/dev/null; then
            validate_gcp || total_failed=$((total_failed + $?))
            echo
        else
            print_warning "gcloud CLI not installed, skipping GCP validation"
        fi
        
        # Azure
        if command -v az &>/dev/null; then
            validate_azure || total_failed=$((total_failed + $?))
            echo
        else
            print_warning "Azure CLI not installed, skipping Azure validation"
        fi
        
        if [ $total_failed -eq 0 ]; then
            echo -e "${GREEN}All cloud provider permissions validated successfully!${NC}"
        else
            echo -e "${RED}Some permission validations failed.${NC}"
            exit 1
        fi
        ;;
    *)
        echo "Invalid option: $1"
        echo "Use: aws, gcp, azure, or all"
        exit 1
        ;;
esac