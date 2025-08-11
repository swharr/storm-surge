#!/bin/bash

# Azure IAM Policy Application Script
# Applies the Storm Surge RBAC role to a service principal or user

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ROLE_FILE="${SCRIPT_DIR}/../../manifests/providerIAM/azure/aks-admin-role.json"

print_header() {
    echo -e "${BLUE}Azure RBAC Setup${NC}"
    echo -e "${BLUE}================${NC}"
}

check_admin_access() {
    echo -e "${YELLOW}Checking Azure admin access...${NC}"
    
    # Check if user can create custom roles
    if az role definition list --custom-role-only true --output none &>/dev/null; then
        echo -e "${GREEN}✓ RBAC read access confirmed${NC}"
    else
        echo -e "${RED}✗ Cannot list role definitions. Admin access required.${NC}"
        return 1
    fi
    
    # Check for Owner or User Access Administrator role
    local user_id=$(az ad signed-in-user show --query id -o tsv 2>/dev/null)
    if [ -n "$user_id" ]; then
        if az role assignment list --assignee "$user_id" --query "[?roleDefinitionName=='Owner' || roleDefinitionName=='User Access Administrator']" -o tsv | grep -q .; then
            echo -e "${GREEN}✓ RBAC admin access confirmed${NC}"
        else
            echo -e "${YELLOW}! Limited RBAC access detected${NC}"
            echo "You may need Owner or User Access Administrator role."
        fi
    fi
}

create_custom_role() {
    echo -e "\n${BLUE}Creating custom RBAC role...${NC}"
    
    # Update subscription ID in role file
    local sub_id=$(az account show --query id -o tsv)
    local temp_role="/tmp/storm-surge-role.json"
    sed "s/{subscriptionId}/$sub_id/g" "$ROLE_FILE" > "$temp_role"
    
    # Check if role already exists
    if az role definition list --name "Storm Surge AKS Administrator" --query "[0]" &>/dev/null; then
        echo -e "${YELLOW}! Custom role already exists${NC}"
        read -p "Do you want to update the existing role? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            az role definition update --role-definition "$temp_role"
            echo -e "${GREEN}✓ Role updated${NC}"
        fi
    else
        # Create the custom role
        az role definition create --role-definition "$temp_role"
        echo -e "${GREEN}✓ Custom role created${NC}"
    fi
    
    rm -f "$temp_role"
}

create_service_principal() {
    local sp_name=$1
    
    echo -e "\n${BLUE}Creating service principal: $sp_name${NC}"
    
    # Create service principal with custom role
    local sp_output=$(az ad sp create-for-rbac \
        --name "$sp_name" \
        --role "Storm Surge AKS Administrator" \
        --scopes /subscriptions/$(az account show --query id -o tsv) \
        --output json)
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Service principal created${NC}"
        echo -e "${YELLOW}IMPORTANT: Save these credentials securely!${NC}"
        echo "App ID: $(echo $sp_output | jq -r .appId)"
        echo "Password: $(echo $sp_output | jq -r .password)"
        echo "Tenant: $(echo $sp_output | jq -r .tenant)"
        echo
        echo "To use these credentials:"
        echo "az login --service-principal -u <app-id> -p <password> --tenant <tenant>"
        echo
        echo "Or set environment variables:"
        echo "export AZURE_CLIENT_ID=<app-id>"
        echo "export AZURE_CLIENT_SECRET=<password>"
        echo "export AZURE_TENANT_ID=<tenant>"
        echo "export AZURE_SUBSCRIPTION_ID=$(az account show --query id -o tsv)"
    else
        echo -e "${RED}✗ Failed to create service principal${NC}"
        return 1
    fi
}

create_managed_identity() {
    local identity_name=$1
    local rg_name=$2
    
    echo -e "\n${BLUE}Creating managed identity: $identity_name${NC}"
    
    # Create resource group if it doesn't exist
    if ! az group show --name "$rg_name" &>/dev/null; then
        echo -e "${BLUE}Creating resource group: $rg_name${NC}"
        az group create --name "$rg_name" --location eastus
    fi
    
    # Create managed identity
    if az identity show --name "$identity_name" --resource-group "$rg_name" &>/dev/null; then
        echo -e "${YELLOW}! Managed identity already exists${NC}"
    else
        az identity create --name "$identity_name" --resource-group "$rg_name"
        echo -e "${GREEN}✓ Managed identity created${NC}"
    fi
    
    # Get identity details
    local client_id=$(az identity show --name "$identity_name" --resource-group "$rg_name" --query clientId -o tsv)
    local resource_id=$(az identity show --name "$identity_name" --resource-group "$rg_name" --query id -o tsv)
    
    # Assign custom role
    echo -e "${BLUE}Assigning Storm Surge AKS Administrator role...${NC}"
    az role assignment create \
        --assignee "$client_id" \
        --role "Storm Surge AKS Administrator" \
        --scope /subscriptions/$(az account show --query id -o tsv)
    
    echo -e "${GREEN}✓ Role assigned${NC}"
    echo
    echo "Managed Identity Resource ID: $resource_id"
    echo "Client ID: $client_id"
}

grant_to_user() {
    local email=$1
    
    echo -e "\n${BLUE}Granting role to user: $email${NC}"
    
    # Grant custom role to user
    az role assignment create \
        --assignee "$email" \
        --role "Storm Surge AKS Administrator" \
        --scope /subscriptions/$(az account show --query id -o tsv)
    
    echo -e "${GREEN}✓ Role granted to $email${NC}"
}

use_builtin_roles() {
    local assignee=$1
    
    echo -e "\n${BLUE}Applying built-in roles...${NC}"
    
    local roles=(
        "Contributor"
        "Network Contributor"
        "Key Vault Administrator"
    )
    
    for role in "${roles[@]}"; do
        echo -e "${BLUE}Granting $role...${NC}"
        az role assignment create \
            --assignee "$assignee" \
            --role "$role" \
            --scope /subscriptions/$(az account show --query id -o tsv)
        echo -e "${GREEN}✓ Granted${NC}"
    done
}

main() {
    print_header
    
    # Check Azure CLI is configured
    if ! az account show &>/dev/null; then
        echo -e "${RED}✗ Azure CLI not configured${NC}"
        echo "Please run: az login"
        exit 1
    fi
    
    # Display current identity
    local account=$(az account show --output json)
    echo -e "\n${BLUE}Current Azure Identity:${NC}"
    echo "Subscription: $(echo $account | jq -r .name)"
    echo "Subscription ID: $(echo $account | jq -r .id)"
    echo "User: $(echo $account | jq -r .user.name)"
    
    # Check admin access
    check_admin_access || {
        echo -e "\n${YELLOW}Warning: You may not have sufficient permissions.${NC}"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        [[ ! $REPLY =~ ^[Yy]$ ]] && exit 1
    }
    
    # Main menu
    echo -e "\n${BLUE}RBAC Configuration Options:${NC}"
    echo "1) Create custom role and service principal"
    echo "2) Create custom role and managed identity"
    echo "3) Create custom role and grant to user"
    echo "4) Use built-in roles with service principal"
    echo "5) Use built-in roles with user"
    echo "6) Skip RBAC setup"
    
    read -p "Select option (1-6): " option
    
    case $option in
        1)
            # Create custom role
            create_custom_role
            
            # Create service principal
            read -p "Enter name for service principal [storm-surge-aks-admin]: " sp_name
            sp_name=${sp_name:-storm-surge-aks-admin}
            create_service_principal "$sp_name"
            ;;
        2)
            # Create custom role
            create_custom_role
            
            # Create managed identity
            read -p "Enter name for managed identity [storm-surge-aks-identity]: " identity_name
            identity_name=${identity_name:-storm-surge-aks-identity}
            read -p "Enter resource group name [storm-surge-rg]: " rg_name
            rg_name=${rg_name:-storm-surge-rg}
            create_managed_identity "$identity_name" "$rg_name"
            ;;
        3)
            # Create custom role
            create_custom_role
            
            # Grant to user
            read -p "Enter user email address: " email
            grant_to_user "$email"
            ;;
        4)
            # Create service principal with built-in roles
            read -p "Enter name for service principal [storm-surge-aks-admin]: " sp_name
            sp_name=${sp_name:-storm-surge-aks-admin}
            
            # Create SP without role first
            local sp_output=$(az ad sp create-for-rbac --name "$sp_name" --skip-assignment --output json)
            local app_id=$(echo $sp_output | jq -r .appId)
            
            use_builtin_roles "$app_id"
            
            echo -e "\n${GREEN}✓ Service principal created with built-in roles${NC}"
            echo "App ID: $app_id"
            echo "Password: $(echo $sp_output | jq -r .password)"
            echo "Tenant: $(echo $sp_output | jq -r .tenant)"
            ;;
        5)
            # Grant built-in roles to user
            read -p "Enter user email address: " email
            use_builtin_roles "$email"
            ;;
        6)
            echo -e "${YELLOW}Skipping RBAC setup${NC}"
            echo "Ensure you have applied the necessary permissions manually."
            ;;
        *)
            echo -e "${RED}Invalid option${NC}"
            exit 1
            ;;
    esac
    
    # Register required resource providers
    echo -e "\n${BLUE}Registering required resource providers...${NC}"
    local providers=(
        "Microsoft.ContainerService"
        "Microsoft.Compute"
        "Microsoft.Network"
        "Microsoft.Storage"
        "Microsoft.KeyVault"
        "Microsoft.ManagedIdentity"
    )
    
    for provider in "${providers[@]}"; do
        local state=$(az provider show --namespace "$provider" --query registrationState -o tsv)
        if [ "$state" == "Registered" ]; then
            echo -e "${GREEN}✓ $provider already registered${NC}"
        else
            echo -e "${BLUE}Registering $provider...${NC}"
            az provider register --namespace "$provider"
            echo -e "${GREEN}✓ Registration initiated${NC}"
        fi
    done
    
    # Validate permissions
    echo -e "\n${BLUE}Validating RBAC permissions...${NC}"
    if "${SCRIPT_DIR}/../../manifests/providerIAM/validate-permissions.sh" azure; then
        echo -e "${GREEN}✓ Azure RBAC setup complete!${NC}"
    else
        echo -e "${YELLOW}! Some permissions may be missing${NC}"
        echo "Review the role in: manifests/providerIAM/azure/aks-admin-role.json"
    fi
}

main "$@"