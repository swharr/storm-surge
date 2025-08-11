#!/bin/bash

# GCP IAM Policy Application Script
# Applies the Storm Surge IAM role to a service account or user

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ROLE_FILE="${SCRIPT_DIR}/../../manifests/providerIAM/gcp/gke-admin-role.yaml"

print_header() {
    echo -e "${BLUE}GCP IAM Role Setup${NC}"
    echo -e "${BLUE}==================${NC}"
}

check_admin_access() {
    echo -e "${YELLOW}Checking GCP admin access...${NC}"
    
    local project=$(gcloud config get-value project 2>/dev/null)
    
    # Check if user can create IAM roles
    if gcloud iam roles list --project="$project" --limit=1 &>/dev/null; then
        echo -e "${GREEN}✓ IAM read access confirmed${NC}"
    else
        echo -e "${RED}✗ Cannot list IAM roles. Admin access required.${NC}"
        return 1
    fi
    
    # Check for specific permissions
    local user_email=$(gcloud auth list --filter=status:ACTIVE --format="value(account)")
    if gcloud projects get-iam-policy "$project" --flatten="bindings[].members" \
        --filter="bindings.members:$user_email" \
        --format="value(bindings.role)" | grep -q "roles/owner\|roles/iam.admin"; then
        echo -e "${GREEN}✓ IAM admin access confirmed${NC}"
    else
        echo -e "${YELLOW}! Limited IAM access detected${NC}"
        echo "You may need roles/owner or roles/iam.admin to create custom roles."
    fi
}

create_custom_role() {
    local project=$1
    echo -e "\n${BLUE}Creating custom IAM role...${NC}"
    
    # Check if role already exists
    if gcloud iam roles describe stormSurgeGKEAdmin --project="$project" &>/dev/null; then
        echo -e "${YELLOW}! Custom role already exists${NC}"
        read -p "Do you want to update the existing role? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            gcloud iam roles update stormSurgeGKEAdmin \
                --project="$project" \
                --file="$ROLE_FILE"
            echo -e "${GREEN}✓ Role updated${NC}"
        fi
    else
        # Create the custom role
        gcloud iam roles create stormSurgeGKEAdmin \
            --project="$project" \
            --file="$ROLE_FILE"
        echo -e "${GREEN}✓ Custom role created${NC}"
    fi
}

create_service_account() {
    local sa_name=$1
    local project=$2
    
    echo -e "\n${BLUE}Creating service account: $sa_name${NC}"
    
    # Check if service account already exists
    if gcloud iam service-accounts describe "$sa_name@$project.iam.gserviceaccount.com" &>/dev/null; then
        echo -e "${YELLOW}! Service account already exists${NC}"
    else
        # Create service account
        gcloud iam service-accounts create "$sa_name" \
            --display-name="Storm Surge GKE Admin" \
            --project="$project"
        echo -e "${GREEN}✓ Service account created${NC}"
    fi
    
    # Grant custom role to service account
    echo -e "${BLUE}Granting Storm Surge GKE Admin role...${NC}"
    gcloud projects add-iam-policy-binding "$project" \
        --member="serviceAccount:$sa_name@$project.iam.gserviceaccount.com" \
        --role="projects/$project/roles/stormSurgeGKEAdmin" \
        --condition=None
    
    echo -e "${GREEN}✓ Role granted${NC}"
    
    # Ask if user wants to create keys
    read -p "Create service account key? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        local key_file="storm-surge-gke-key.json"
        echo -e "${BLUE}Creating service account key...${NC}"
        gcloud iam service-accounts keys create "$key_file" \
            --iam-account="$sa_name@$project.iam.gserviceaccount.com"
        
        echo -e "${GREEN}✓ Key created: $key_file${NC}"
        echo -e "${YELLOW}IMPORTANT: Store this key file securely!${NC}"
        echo
        echo "To use this key:"
        echo "export GOOGLE_APPLICATION_CREDENTIALS=\"$(pwd)/$key_file\""
        echo "or"
        echo "gcloud auth activate-service-account --key-file=$key_file"
    fi
}

grant_to_user() {
    local email=$1
    local project=$2
    
    echo -e "\n${BLUE}Granting role to user: $email${NC}"
    
    # Grant custom role to user
    gcloud projects add-iam-policy-binding "$project" \
        --member="user:$email" \
        --role="projects/$project/roles/stormSurgeGKEAdmin" \
        --condition=None
    
    echo -e "${GREEN}✓ Role granted to $email${NC}"
}

use_predefined_roles() {
    local project=$1
    local member=$2
    
    echo -e "\n${BLUE}Applying predefined roles...${NC}"
    
    local roles=(
        "roles/container.admin"
        "roles/compute.admin"
        "roles/iam.serviceAccountAdmin"
        "roles/resourcemanager.projectIamAdmin"
    )
    
    for role in "${roles[@]}"; do
        echo -e "${BLUE}Granting $role...${NC}"
        gcloud projects add-iam-policy-binding "$project" \
            --member="$member" \
            --role="$role" \
            --condition=None
        echo -e "${GREEN}✓ Granted${NC}"
    done
}

main() {
    print_header
    
    # Check gcloud is configured
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" &>/dev/null; then
        echo -e "${RED}✗ gcloud CLI not configured${NC}"
        echo "Please run: gcloud auth login"
        exit 1
    fi
    
    # Get current project
    local project=$(gcloud config get-value project 2>/dev/null)
    if [ -z "$project" ]; then
        echo -e "${RED}✗ No default project set${NC}"
        read -p "Enter GCP project ID: " project
        gcloud config set project "$project"
    fi
    
    # Display current identity
    local account=$(gcloud auth list --filter=status:ACTIVE --format="value(account)")
    echo -e "\n${BLUE}Current GCP Identity:${NC}"
    echo "Account: $account"
    echo "Project: $project"
    
    # Check admin access
    check_admin_access || {
        echo -e "\n${YELLOW}Warning: You may not have sufficient permissions.${NC}"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        [[ ! $REPLY =~ ^[Yy]$ ]] && exit 1
    }
    
    # Main menu
    echo -e "\n${BLUE}IAM Configuration Options:${NC}"
    echo "1) Create custom role and service account"
    echo "2) Create custom role and grant to user"
    echo "3) Use predefined roles with service account"
    echo "4) Use predefined roles with user"
    echo "5) Skip IAM setup"
    
    read -p "Select option (1-5): " option
    
    case $option in
        1)
            # Create custom role
            create_custom_role "$project"
            
            # Create service account
            read -p "Enter name for service account [storm-surge-gke-admin]: " sa_name
            sa_name=${sa_name:-storm-surge-gke-admin}
            create_service_account "$sa_name" "$project"
            ;;
        2)
            # Create custom role
            create_custom_role "$project"
            
            # Grant to user
            read -p "Enter user email address: " email
            grant_to_user "$email" "$project"
            ;;
        3)
            # Create service account with predefined roles
            read -p "Enter name for service account [storm-surge-gke-admin]: " sa_name
            sa_name=${sa_name:-storm-surge-gke-admin}
            
            # Create SA first
            if ! gcloud iam service-accounts describe "$sa_name@$project.iam.gserviceaccount.com" &>/dev/null; then
                gcloud iam service-accounts create "$sa_name" \
                    --display-name="Storm Surge GKE Admin" \
                    --project="$project"
            fi
            
            use_predefined_roles "$project" "serviceAccount:$sa_name@$project.iam.gserviceaccount.com"
            
            # Ask about key creation
            read -p "Create service account key? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                gcloud iam service-accounts keys create "storm-surge-gke-key.json" \
                    --iam-account="$sa_name@$project.iam.gserviceaccount.com"
                echo -e "${GREEN}✓ Key created: storm-surge-gke-key.json${NC}"
            fi
            ;;
        4)
            # Grant predefined roles to user
            read -p "Enter user email address: " email
            use_predefined_roles "$project" "user:$email"
            ;;
        5)
            echo -e "${YELLOW}Skipping IAM setup${NC}"
            echo "Ensure you have applied the necessary permissions manually."
            ;;
        *)
            echo -e "${RED}Invalid option${NC}"
            exit 1
            ;;
    esac
    
    # Enable required APIs
    echo -e "\n${BLUE}Enabling required APIs...${NC}"
    local apis=(
        "container.googleapis.com"
        "compute.googleapis.com"
        "iam.googleapis.com"
        "cloudresourcemanager.googleapis.com"
    )
    
    for api in "${apis[@]}"; do
        if gcloud services list --enabled --filter="name:$api" --format="value(name)" | grep -q "$api"; then
            echo -e "${GREEN}✓ $api already enabled${NC}"
        else
            echo -e "${BLUE}Enabling $api...${NC}"
            gcloud services enable "$api"
            echo -e "${GREEN}✓ Enabled${NC}"
        fi
    done
    
    # Validate permissions
    echo -e "\n${BLUE}Validating IAM permissions...${NC}"
    if "${SCRIPT_DIR}/../../manifests/providerIAM/validate-permissions.sh" gcp; then
        echo -e "${GREEN}✓ GCP IAM setup complete!${NC}"
    else
        echo -e "${YELLOW}! Some permissions may be missing${NC}"
        echo "Review the role in: manifests/providerIAM/gcp/gke-admin-role.yaml"
    fi
}

main "$@"