#!/bin/bash

# Storm Surge Multi-Cloud Cleanup Script
# Safely removes Storm Surge resources from AWS, GCP, or Azure

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    echo -e "${BLUE}===========================================${NC}"
    echo -e "${BLUE}    Storm Surge Multi-Cloud Cleanup${NC}"
    echo -e "${BLUE}===========================================${NC}"
    echo
}

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

show_help() {
    cat << EOF
Usage: $0 [options]

Multi-cloud cleanup script for Storm Surge infrastructure.

Options:
  --provider=PROVIDER      Cloud provider: aws, gcp, azure, or all
  --dry-run               Show what would be deleted without deleting
  --force                 Skip confirmation prompts
  --cluster-name=NAME     Cluster name (default: storm-surge-prod)
  --help                  Show this help message

Provider-specific options:
  AWS:
    --region=REGION       AWS region (default: us-east-1)
    
  GCP:
    --region=REGION       GCP region (default: us-central1)
    --project=PROJECT_ID  GCP project ID
    
  Azure:
    --resource-group=RG   Azure resource group (default: storm-surge-prod-rg)

Examples:
  $0 --provider=aws --dry-run
  $0 --provider=gcp --project=my-project --force
  $0 --provider=azure --resource-group=my-rg
  $0 --provider=all --dry-run

EOF
}

# Default values
PROVIDER=""
DRY_RUN=false
FORCE=false
CLUSTER_NAME="storm-surge-prod"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --provider=*)
            PROVIDER="${1#*=}"
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        --cluster-name=*)
            CLUSTER_NAME="${1#*=}"
            shift
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            # Pass through other arguments to provider-specific scripts
            EXTRA_ARGS="$EXTRA_ARGS $1"
            shift
            ;;
    esac
done

print_header

# Validate provider
if [ -z "$PROVIDER" ]; then
    print_error "Provider not specified"
    echo "Use --provider=aws|gcp|azure|all"
    echo "Use --help for more information"
    exit 1
fi

if [[ ! "$PROVIDER" =~ ^(aws|gcp|azure|all)$ ]]; then
    print_error "Invalid provider: $PROVIDER"
    echo "Valid providers: aws, gcp, azure, all"
    exit 1
fi

# Check if cleanup scripts exist
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/cleanup"

cleanup_provider() {
    local provider="$1"
    local script="$SCRIPT_DIR/cleanup-${provider}.sh"
    
    if [ ! -f "$script" ]; then
        print_error "Cleanup script not found: $script"
        return 1
    fi
    
    print_info "Starting ${provider^^} cleanup..."
    echo
    
    # Build arguments
    local args=""
    [ "$DRY_RUN" = true ] && args="$args --dry-run"
    [ "$FORCE" = true ] && args="$args --force"
    [ -n "$CLUSTER_NAME" ] && args="$args --cluster-name=$CLUSTER_NAME"
    
    # Add extra arguments
    args="$args $EXTRA_ARGS"
    
    # Execute cleanup script
    if bash "$script" $args; then
        print_info "${provider^^} cleanup completed successfully"
    else
        print_error "${provider^^} cleanup failed"
        return 1
    fi
    
    echo
}

# Execute cleanup based on provider
case "$PROVIDER" in
    "aws")
        cleanup_provider "aws"
        ;;
    "gcp")
        cleanup_provider "gcp"
        ;;
    "azure")
        cleanup_provider "azure"
        ;;
    "all")
        print_warning "Running cleanup for ALL cloud providers"
        if [ "$FORCE" != true ] && [ "$DRY_RUN" != true ]; then
            read -p "Are you sure you want to cleanup ALL cloud providers? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                print_info "Cleanup cancelled"
                exit 0
            fi
        fi
        
        print_info "Cleaning up all cloud providers..."
        echo
        
        # Run cleanup for each provider if resources exist
        for provider in aws gcp azure; do
            script="$SCRIPT_DIR/cleanup-${provider}.sh"
            if [ -f "$script" ]; then
                print_info "Checking for ${provider^^} resources..."
                cleanup_provider "$provider" || print_warning "${provider^^} cleanup encountered errors"
            else
                print_warning "Cleanup script not found for $provider"
            fi
        done
        ;;
esac

print_info "Multi-cloud cleanup process completed"

# Show general cleanup recommendations
echo
print_info "Additional cleanup recommendations:"
echo "1. Check for any remaining load balancers or public IPs in your cloud console"
echo "2. Verify that persistent volumes have been properly deleted"
echo "3. Review DNS records that may have been created"
echo "4. Check for any custom IAM roles or service accounts that are no longer needed"
echo "5. Verify that SSL certificates are properly cleaned up"
echo
print_info "For complete resource cleanup, review your cloud provider console"