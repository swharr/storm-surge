#!/bin/bash

# AWS IAM Policy Application Script
# Applies the Storm Surge IAM policy to a user or role

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
POLICY_FILE="${SCRIPT_DIR}/../../manifests/providerIAM/aws/eks-admin-policy.json"

print_header() {
    echo -e "${BLUE}AWS IAM Policy Setup${NC}"
    echo -e "${BLUE}====================${NC}"
}

check_admin_access() {
    echo -e "${YELLOW}Checking AWS admin access...${NC}"
    
    # Check if user can create IAM policies
    if aws iam list-policies --max-items 1 &>/dev/null; then
        echo -e "${GREEN}✓ IAM read access confirmed${NC}"
    else
        echo -e "${RED}✗ Cannot list IAM policies. Admin access required.${NC}"
        return 1
    fi
    
    # Check if user can create users/roles
    if aws iam simulate-principal-policy \
        --policy-source-arn $(aws sts get-caller-identity --query Arn --output text) \
        --action-names iam:CreateUser iam:CreateRole iam:PutUserPolicy iam:AttachRolePolicy \
        --output text --query 'EvaluationResults[?EvalDecision==`allowed`]' | grep -q allowed; then
        echo -e "${GREEN}✓ IAM admin access confirmed${NC}"
    else
        echo -e "${YELLOW}! Limited IAM access detected${NC}"
        echo "You may not have full admin access. Proceeding anyway..."
    fi
}

create_iam_user() {
    local username=$1
    echo -e "\n${BLUE}Creating IAM user: $username${NC}"
    
    # Check if user already exists
    if aws iam get-user --user-name "$username" &>/dev/null; then
        echo -e "${YELLOW}! User $username already exists${NC}"
        read -p "Do you want to update the existing user's policy? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return 1
        fi
    else
        # Create the user
        aws iam create-user --user-name "$username" --output table
        echo -e "${GREEN}✓ User created${NC}"
    fi
    
    # Apply the policy
    echo -e "${BLUE}Applying Storm Surge EKS Admin policy...${NC}"
    aws iam put-user-policy \
        --user-name "$username" \
        --policy-name "StormSurgeEKSAdminPolicy" \
        --policy-document "file://${POLICY_FILE}"
    
    echo -e "${GREEN}✓ Policy applied${NC}"
    
    # Ask if user wants to create access keys
    read -p "Create access keys for this user? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}Creating access keys...${NC}"
        local keys=$(aws iam create-access-key --user-name "$username" --output json)
        
        echo -e "${GREEN}✓ Access keys created${NC}"
        echo -e "${YELLOW}IMPORTANT: Save these credentials securely!${NC}"
        echo "Access Key ID: $(echo $keys | jq -r .AccessKey.AccessKeyId)"
        echo "Secret Access Key: $(echo $keys | jq -r .AccessKey.SecretAccessKey)"
        echo
        echo "Configure AWS CLI with: aws configure --profile storm-surge"
    fi
}

create_iam_role() {
    local rolename=$1
    echo -e "\n${BLUE}Creating IAM role: $rolename${NC}"
    
    # Create trust policy
    cat > /tmp/trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    },
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "$(aws sts get-caller-identity --query Arn --output text | sed 's/:user\/.*/:root/')"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
    
    # Check if role already exists
    if aws iam get-role --role-name "$rolename" &>/dev/null; then
        echo -e "${YELLOW}! Role $rolename already exists${NC}"
        read -p "Do you want to update the existing role's policy? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            rm -f /tmp/trust-policy.json
            return 1
        fi
    else
        # Create the role
        aws iam create-role \
            --role-name "$rolename" \
            --assume-role-policy-document file:///tmp/trust-policy.json \
            --output table
        echo -e "${GREEN}✓ Role created${NC}"
    fi
    
    # Apply the policy
    echo -e "${BLUE}Applying Storm Surge EKS Admin policy...${NC}"
    aws iam put-role-policy \
        --role-name "$rolename" \
        --policy-name "StormSurgeEKSAdminPolicy" \
        --policy-document "file://${POLICY_FILE}"
    
    echo -e "${GREEN}✓ Policy applied${NC}"
    
    # Create instance profile for EC2
    if ! aws iam get-instance-profile --instance-profile-name "$rolename" &>/dev/null; then
        aws iam create-instance-profile --instance-profile-name "$rolename"
        aws iam add-role-to-instance-profile \
            --instance-profile-name "$rolename" \
            --role-name "$rolename"
        echo -e "${GREEN}✓ Instance profile created${NC}"
    fi
    
    rm -f /tmp/trust-policy.json
    
    echo -e "\n${GREEN}Role ARN:${NC} $(aws iam get-role --role-name $rolename --query Role.Arn --output text)"
}

attach_to_existing() {
    echo -e "\n${BLUE}Attach policy to existing user/role${NC}"
    
    # Ask whether to attach to user or role
    echo "1) Attach to IAM User"
    echo "2) Attach to IAM Role"
    read -p "Select option (1-2): " choice
    
    case $choice in
        1)
            read -p "Enter IAM username: " username
            if aws iam get-user --user-name "$username" &>/dev/null; then
                aws iam put-user-policy \
                    --user-name "$username" \
                    --policy-name "StormSurgeEKSAdminPolicy" \
                    --policy-document "file://${POLICY_FILE}"
                echo -e "${GREEN}✓ Policy attached to user $username${NC}"
            else
                echo -e "${RED}✗ User $username not found${NC}"
                return 1
            fi
            ;;
        2)
            read -p "Enter IAM role name: " rolename
            if aws iam get-role --role-name "$rolename" &>/dev/null; then
                aws iam put-role-policy \
                    --role-name "$rolename" \
                    --policy-name "StormSurgeEKSAdminPolicy" \
                    --policy-document "file://${POLICY_FILE}"
                echo -e "${GREEN}✓ Policy attached to role $rolename${NC}"
            else
                echo -e "${RED}✗ Role $rolename not found${NC}"
                return 1
            fi
            ;;
        *)
            echo -e "${RED}Invalid option${NC}"
            return 1
            ;;
    esac
}

main() {
    print_header
    
    # Check AWS CLI is configured
    if ! aws sts get-caller-identity &>/dev/null; then
        echo -e "${RED}✗ AWS CLI not configured or credentials invalid${NC}"
        echo "Please run: aws configure"
        exit 1
    fi
    
    # Display current identity
    local identity=$(aws sts get-caller-identity --output json)
    echo -e "\n${BLUE}Current AWS Identity:${NC}"
    echo "Account: $(echo $identity | jq -r .Account)"
    echo "User ARN: $(echo $identity | jq -r .Arn)"
    
    # Check admin access
    check_admin_access || {
        echo -e "\n${YELLOW}Warning: You may not have sufficient permissions.${NC}"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        [[ ! $REPLY =~ ^[Yy]$ ]] && exit 1
    }
    
    # Main menu
    echo -e "\n${BLUE}IAM Configuration Options:${NC}"
    echo "1) Create new IAM user with policy"
    echo "2) Create new IAM role with policy"
    echo "3) Attach policy to existing user/role"
    echo "4) Skip IAM setup"
    
    read -p "Select option (1-4): " option
    
    case $option in
        1)
            read -p "Enter username for new IAM user [storm-surge-admin]: " username
            username=${username:-storm-surge-admin}
            create_iam_user "$username"
            ;;
        2)
            read -p "Enter name for new IAM role [StormSurgeEKSAdminRole]: " rolename
            rolename=${rolename:-StormSurgeEKSAdminRole}
            create_iam_role "$rolename"
            ;;
        3)
            attach_to_existing
            ;;
        4)
            echo -e "${YELLOW}Skipping IAM setup${NC}"
            echo "Ensure you have applied the necessary permissions manually."
            ;;
        *)
            echo -e "${RED}Invalid option${NC}"
            exit 1
            ;;
    esac
    
    # Validate permissions
    echo -e "\n${BLUE}Validating IAM permissions...${NC}"
    if "${SCRIPT_DIR}/../../manifests/providerIAM/validate-permissions.sh" aws; then
        echo -e "${GREEN}✓ AWS IAM setup complete!${NC}"
    else
        echo -e "${YELLOW}! Some permissions may be missing${NC}"
        echo "Review the policy in: manifests/providerIAM/aws/eks-admin-policy.json"
    fi
}

main "$@"