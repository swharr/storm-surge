#!/bin/bash

# Storm Surge Multi-Cloud Setup Script
# Interactive deployment script for AWS EKS, Google GKE, and Azure AKS

set -e

# Help functionality
show_help() {
    echo "Storm Surge Multi-Cloud Setup Script"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message and exit"
    echo "  -p PROVIDER    Cloud provider (aws, gcp, azure)"
    echo "  -r REGION      Cloud region"
    echo "  -n NODES       Number of nodes (default: 3)"
    echo "  -f FQDN        Fully qualified domain name"
    echo ""
    echo "Interactive Mode:"
    echo "  Run without arguments for interactive setup"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Interactive mode"
    echo "  $0 -p aws -r us-west-2 -n 3         # AWS with specific settings"
    echo "  $0 --help                           # Show this help"
    exit 0
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      show_help
      ;;
    -p|--provider)
      CLOUD_PROVIDER="$2"
      shift 2
      ;;
    -r|--region)
      REGION="$2"
      shift 2
      ;;
    -n|--nodes)
      NODES="$2"
      shift 2
      ;;
    -f|--fqdn)
      FQDN="$2"
      shift 2
      ;;
    *)
      echo "Unknown option $1"
      show_help
      ;;
  esac
done

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print functions
print_header() {
    echo -e "${BLUE}===========================================${NC}"
    echo -e "${BLUE}    Storm Surge Multi-Cloud Setup${NC}"
    echo -e "${BLUE}===========================================${NC}"
    echo
}

print_step() {
    echo -e "${GREEN}[STEP]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Configuration variables
FQDN=""
DOMAIN=""
SUBDOMAIN=""
CLOUD_PROVIDER=""
PROJECT_ID=""
SUBSCRIPTION_ID=""
RESOURCE_GROUP=""
CLUSTER_NAME="storm-surge-prod"
NAMESPACE="storm-surge-prod"

# Check prerequisites
check_prerequisites() {
    print_step "Checking prerequisites..."
    
    local missing_tools=()
    
    # Check for kubectl
    if ! command -v kubectl &> /dev/null; then
        missing_tools+=("kubectl")
    fi
    
    # Check for helm
    if ! command -v helm &> /dev/null; then
        missing_tools+=("helm")
    fi
    
    # Check for openssl
    if ! command -v openssl &> /dev/null; then
        missing_tools+=("openssl")
    fi
    
    # Check for jq
    if ! command -v jq &> /dev/null; then
        missing_tools+=("jq")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        print_error "Missing required tools: ${missing_tools[*]}"
        print_info "Please install the missing tools and run the script again."
        exit 1
    fi
    
    print_info "All prerequisites satisfied"
}

# Collect user configuration
collect_configuration() {
    print_step "Collecting configuration..."
    
    # Get FQDN
    echo -e "${YELLOW}Enter your Fully Qualified Domain Name (FQDN):${NC}"
    echo -e "Examples: k8stest.company.com, api.stormsurge.com, my-app.example.org"
    read -p "FQDN: " FQDN
    
    # Validate FQDN format
    if [[ ! "$FQDN" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]*[a-zA-Z0-9]*\.[a-zA-Z]{2,}$ ]]; then
        print_error "Invalid FQDN format. Please use format: subdomain.domain.tld"
        exit 1
    fi
    
    # Extract domain and subdomain
    SUBDOMAIN=$(echo "$FQDN" | cut -d'.' -f1)
    DOMAIN=$(echo "$FQDN" | cut -d'.' -f2-)
    
    print_info "FQDN: $FQDN"
    print_info "Subdomain: $SUBDOMAIN"
    print_info "Domain: $DOMAIN"
    
    echo
    echo -e "${YELLOW}Select cloud provider:${NC}"
    echo "1) AWS EKS"
    echo "2) Google Cloud GKE"
    echo "3) Azure AKS"
    read -p "Choice [1-3]: " cloud_choice
    
    case $cloud_choice in
        1)
            CLOUD_PROVIDER="aws"
            collect_aws_config
            ;;
        2)
            CLOUD_PROVIDER="gcp"
            collect_gcp_config
            ;;
        3)
            CLOUD_PROVIDER="azure"
            collect_azure_config
            ;;
        *)
            print_error "Invalid choice"
            exit 1
            ;;
    esac
}

collect_aws_config() {
    print_step "Configuring AWS EKS..."
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI not found. Please install and configure AWS CLI."
        exit 1
    fi
    
    # Check eksctl
    if ! command -v eksctl &> /dev/null; then
        print_warning "eksctl not found. Installing..."
        curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
        sudo mv /tmp/eksctl /usr/local/bin
    fi
    
    # Get AWS account ID
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "")
    if [ -z "$AWS_ACCOUNT_ID" ]; then
        print_error "Cannot get AWS account ID. Please configure AWS CLI first."
        exit 1
    fi
    
    print_info "AWS Account ID: $AWS_ACCOUNT_ID"
    
    # Select region
    echo
    echo -e "${YELLOW}Select AWS region:${NC}"
    echo "1) us-east-1 (N. Virginia)"
    echo "2) us-west-2 (Oregon)"
    echo "3) eu-west-1 (Ireland)"
    echo "4) Custom region"
    read -p "Choice [1-4]: " region_choice
    
    case $region_choice in
        1) AWS_REGION="us-east-1" ;;
        2) AWS_REGION="us-west-2" ;;
        3) AWS_REGION="eu-west-1" ;;
        4) 
            read -p "Enter AWS region: " AWS_REGION
            ;;
        *) AWS_REGION="us-east-1" ;;
    esac
    
    export AWS_REGION
    print_info "AWS Region: $AWS_REGION"
}

collect_gcp_config() {
    print_step "Configuring Google Cloud GKE..."
    
    # Check gcloud CLI
    if ! command -v gcloud &> /dev/null; then
        print_error "Google Cloud CLI not found. Please install and configure gcloud CLI."
        exit 1
    fi
    
    # Get current project
    PROJECT_ID=$(gcloud config get-value project 2>/dev/null || echo "")
    if [ -z "$PROJECT_ID" ]; then
        read -p "Enter Google Cloud Project ID: " PROJECT_ID
        gcloud config set project "$PROJECT_ID"
    fi
    
    print_info "Google Cloud Project: $PROJECT_ID"
    
    # Select region
    echo
    echo -e "${YELLOW}Select GCP region:${NC}"
    echo "1) us-central1"
    echo "2) us-east1"
    echo "3) europe-west1"
    echo "4) Custom region"
    read -p "Choice [1-4]: " region_choice
    
    case $region_choice in
        1) GCP_REGION="us-central1" ;;
        2) GCP_REGION="us-east1" ;;
        3) GCP_REGION="europe-west1" ;;
        4) 
            read -p "Enter GCP region: " GCP_REGION
            ;;
        *) GCP_REGION="us-central1" ;;
    esac
    
    print_info "GCP Region: $GCP_REGION"
}

collect_azure_config() {
    print_step "Configuring Azure AKS..."
    
    # Check Azure CLI
    if ! command -v az &> /dev/null; then
        print_error "Azure CLI not found. Please install and configure Azure CLI."
        exit 1
    fi
    
    # Get subscription ID
    SUBSCRIPTION_ID=$(az account show --query id --output tsv 2>/dev/null || echo "")
    if [ -z "$SUBSCRIPTION_ID" ]; then
        print_error "Cannot get Azure subscription. Please login with 'az login'."
        exit 1
    fi
    
    print_info "Azure Subscription: $SUBSCRIPTION_ID"
    
    # Resource group
    RESOURCE_GROUP="storm-surge-prod-rg"
    read -p "Resource Group [$RESOURCE_GROUP]: " input_rg
    if [ ! -z "$input_rg" ]; then
        RESOURCE_GROUP="$input_rg"
    fi
    
    # Select location
    echo
    echo -e "${YELLOW}Select Azure location:${NC}"
    echo "1) East US"
    echo "2) West US 2"
    echo "3) West Europe"
    echo "4) Custom location"
    read -p "Choice [1-4]: " location_choice
    
    case $location_choice in
        1) AZURE_LOCATION="eastus" ;;
        2) AZURE_LOCATION="westus2" ;;
        3) AZURE_LOCATION="westeurope" ;;
        4) 
            read -p "Enter Azure location: " AZURE_LOCATION
            ;;
        *) AZURE_LOCATION="eastus" ;;
    esac
    
    print_info "Azure Location: $AZURE_LOCATION"
}

# IAM Setup Functions
setup_iam_policies() {
    echo
    echo -e "${YELLOW}═══════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}IAM Policy Setup${NC}"
    echo -e "${YELLOW}═══════════════════════════════════════════════${NC}"
    echo
    echo -e "${BLUE}Storm Surge requires administrative permissions to manage Kubernetes clusters.${NC}"
    echo -e "${BLUE}We can help you apply the necessary IAM policies to your cloud account.${NC}"
    echo
    echo -e "${YELLOW}IMPORTANT: You need admin access to apply these policies.${NC}"
    echo
    read -p "Would you like to apply IAM policies now? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        case $CLOUD_PROVIDER in
            aws)
                setup_aws_iam
                ;;
            gcp)
                setup_gcp_iam
                ;;
            azure)
                setup_azure_iam
                ;;
        esac
    else
        echo -e "${YELLOW}Skipping IAM setup.${NC}"
        echo "You can manually apply policies from: manifests/providerIAM/${CLOUD_PROVIDER}/"
        echo
        echo -e "${YELLOW}Warning: Deployment may fail without proper permissions!${NC}"
        read -p "Press Enter to continue..."
    fi
}

setup_aws_iam() {
    print_step "Setting up AWS IAM policies..."
    
    if [ -x "scripts/iam/apply-aws-iam.sh" ]; then
        scripts/iam/apply-aws-iam.sh
    else
        print_error "IAM setup script not found or not executable"
        echo "Please run manually: bash scripts/iam/apply-aws-iam.sh"
    fi
}

setup_gcp_iam() {
    print_step "Setting up GCP IAM policies..."
    
    if [ -x "scripts/iam/apply-gcp-iam.sh" ]; then
        scripts/iam/apply-gcp-iam.sh
    else
        print_error "IAM setup script not found or not executable"
        echo "Please run manually: bash scripts/iam/apply-gcp-iam.sh"
    fi
}

setup_azure_iam() {
    print_step "Setting up Azure RBAC policies..."
    
    if [ -x "scripts/iam/apply-azure-iam.sh" ]; then
        scripts/iam/apply-azure-iam.sh
    else
        print_error "IAM setup script not found or not executable"
        echo "Please run manually: bash scripts/iam/apply-azure-iam.sh"
    fi
}

validate_iam_permissions() {
    print_step "Validating IAM permissions..."
    
    if [ -x "manifests/providerIAM/validate-permissions.sh" ]; then
        if manifests/providerIAM/validate-permissions.sh "$CLOUD_PROVIDER"; then
            echo -e "${GREEN}✓ IAM permissions validated successfully${NC}"
            return 0
        else
            echo -e "${RED}✗ IAM permission validation failed${NC}"
            echo
            echo -e "${YELLOW}Some required permissions are missing.${NC}"
            echo "This may cause deployment failures."
            echo
            read -p "Continue anyway? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
        fi
    else
        print_warning "Permission validator not found. Skipping validation."
    fi
}

# Update configuration files with user values
update_configuration_files() {
    print_step "Updating configuration files with your settings..."
    
    # Create backup directory
    mkdir -p manifests/backup
    
    case $CLOUD_PROVIDER in
        aws)
            update_aws_config
            ;;
        gcp)
            update_gcp_config
            ;;
        azure)
            update_azure_config
            ;;
    esac
    
    # Update common files
    update_common_config
}

update_aws_config() {
    local config_file="manifests/cloud-infrastructure/aws-infrastructure.yaml"
    
    # Backup original
    cp "$config_file" "manifests/backup/aws-infrastructure-original.yaml"
    
    # Update FQDN references
    sed -i.bak "s/api\.stormsurge\.example\.com/$FQDN/g" "$config_file"
    sed -i.bak "s/\*\.stormsurge\.example\.com/*.$DOMAIN/g" "$config_file"
    
    # Update region
    sed -i.bak "s/region: us-east-1/region: $AWS_REGION/g" "$config_file"
    sed -i.bak "s/us-east-1/$AWS_REGION/g" "$config_file"
    
    # Update account ID placeholder
    sed -i.bak "s/ACCOUNT_ID/$AWS_ACCOUNT_ID/g" "$config_file"
    
    # Clean up backup files
    rm "$config_file.bak"
    
    print_info "Updated AWS configuration"
}

update_gcp_config() {
    local config_file="manifests/cloud-infrastructure/gcp-infrastructure.yaml"
    
    # Backup original
    cp "$config_file" "manifests/backup/gcp-infrastructure-original.yaml"
    
    # Update FQDN references
    sed -i.bak "s/api\.stormsurge\.example\.com/$FQDN/g" "$config_file"
    sed -i.bak "s/\*\.stormsurge\.example\.com/*.$DOMAIN/g" "$config_file"
    
    # Update region
    sed -i.bak "s/us-central1/$GCP_REGION/g" "$config_file"
    
    # Update project ID
    sed -i.bak "s/PROJECT_ID/$PROJECT_ID/g" "$config_file"
    
    # Clean up backup files
    rm "$config_file.bak"
    
    print_info "Updated GCP configuration"
}

update_azure_config() {
    local config_file="manifests/cloud-infrastructure/azure-infrastructure.yaml"
    
    # Backup original
    cp "$config_file" "manifests/backup/azure-infrastructure-original.yaml"
    
    # Update FQDN references
    sed -i.bak "s/api\.stormsurge\.example\.com/$FQDN/g" "$config_file"
    sed -i.bak "s/\*\.stormsurge\.example\.com/*.$DOMAIN/g" "$config_file"
    
    # Update location
    sed -i.bak "s/East US/$AZURE_LOCATION/g" "$config_file"
    sed -i.bak "s/eastus/$AZURE_LOCATION/g" "$config_file"
    
    # Update resource group
    sed -i.bak "s/storm-surge-prod-rg/$RESOURCE_GROUP/g" "$config_file"
    
    # Clean up backup files
    rm "$config_file.bak"
    
    print_info "Updated Azure configuration"
}

update_common_config() {
    # Update deployment guide
    sed -i.bak "s/api\.stormsurge\.example\.com/$FQDN/g" "manifests/DEPLOYMENT_GUIDE.md"
    sed -i.bak "s/\*\.stormsurge\.example\.com/*.$DOMAIN/g" "manifests/DEPLOYMENT_GUIDE.md"
    rm "manifests/DEPLOYMENT_GUIDE.md.bak"
    
    # Update ingress configurations
    find manifests/ -name "*.yaml" -type f -exec sed -i.bak "s/api\.stormsurge\.example\.com/$FQDN/g" {} \;
    find manifests/ -name "*.yaml" -type f -exec sed -i.bak "s/\*\.stormsurge\.example\.com/*.$DOMAIN/g" {} \;
    
    # Clean up all .bak files
    find manifests/ -name "*.bak" -type f -delete
    
    # Update database configuration templates with placeholders
    if [ -f "manifests/databases/postgresql.yaml" ]; then
        sed -i.bak "s/REPLACE_WITH_SECURE_PASSWORD/\${POSTGRES_PASSWORD}/g" "manifests/databases/postgresql.yaml"
        rm -f "manifests/databases/postgresql.yaml.bak"
    fi
    
    if [ -f "manifests/databases/redis.yaml" ]; then
        sed -i.bak "s/REPLACE_WITH_SECURE_PASSWORD/\${REDIS_PASSWORD}/g" "manifests/databases/redis.yaml"  
        rm -f "manifests/databases/redis.yaml.bak"
    fi
    
    print_info "Updated common configuration files"
}

# Generate secrets
generate_secrets() {
    print_step "Generating secure secrets..."
    
    # Create secrets directory
    mkdir -p manifests/secrets
    
    # Generate JWT secret
    JWT_SECRET=$(openssl rand -base64 32)
    
    # Generate admin password
    ADMIN_PASSWORD=$(openssl rand -base64 16)
    
    # Generate database passwords
    DB_PASSWORD=$(openssl rand -base64 20)
    REDIS_PASSWORD=$(openssl rand -base64 16)
    
    # Create secrets file
    cat > manifests/secrets/generated-secrets.yaml << EOF
# Generated Secrets for Storm Surge
# Store these securely and do not commit to version control!

apiVersion: v1
kind: Secret
metadata:
  name: app-secrets
  namespace: $NAMESPACE
type: Opaque
stringData:
  JWT_SECRET: "$JWT_SECRET"
  ADMIN_PASSWORD: "$ADMIN_PASSWORD"

---
apiVersion: v1
kind: Secret
metadata:
  name: db-credentials
  namespace: $NAMESPACE
type: Opaque
stringData:
  DATABASE_PASSWORD: "$DB_PASSWORD"
  DATABASE_USER: "app_user"
  DATABASE_NAME: "stormsurge"

---
apiVersion: v1
kind: Secret
metadata:
  name: redis-credentials
  namespace: $NAMESPACE
type: Opaque
stringData:
  REDIS_PASSWORD: "$REDIS_PASSWORD"
EOF

    # Create environment file for reference
    cat > manifests/secrets/.env << EOF
# Generated Environment Variables
# DO NOT COMMIT THIS FILE!

# Application
JWT_SECRET=$JWT_SECRET
ADMIN_PASSWORD=$ADMIN_PASSWORD

# Database
DATABASE_PASSWORD=$DB_PASSWORD
DATABASE_USER=app_user
DATABASE_NAME=stormsurge

# Redis
REDIS_PASSWORD=$REDIS_PASSWORD

# Domain Configuration
FQDN=$FQDN
DOMAIN=$DOMAIN
SUBDOMAIN=$SUBDOMAIN
EOF

    # Create .gitignore if it doesn't exist
    if [ ! -f manifests/secrets/.gitignore ]; then
        echo "# Ignore all secret files" > manifests/secrets/.gitignore
        echo ".env" >> manifests/secrets/.gitignore
        echo "*.key" >> manifests/secrets/.gitignore
        echo "*.pem" >> manifests/secrets/.gitignore
    fi
    
    print_info "Generated secrets saved to manifests/secrets/"
    print_warning "Keep these secrets secure and do not commit them to version control!"
}

# Deploy based on cloud provider
deploy_infrastructure() {
    print_step "Deploying infrastructure for $CLOUD_PROVIDER..."
    
    # Validate IAM permissions before deployment
    validate_iam_permissions
    
    case $CLOUD_PROVIDER in
        aws)
            deploy_aws
            ;;
        gcp)
            deploy_gcp
            ;;
        azure)
            deploy_azure
            ;;
    esac
}

deploy_aws() {
    print_info "Deploying AWS EKS cluster..."
    
    # Deploy cluster with eksctl
    eksctl create cluster -f manifests/cloud-infrastructure/aws-infrastructure.yaml
    
    # Install AWS Load Balancer Controller
    print_info "Installing AWS Load Balancer Controller..."
    kubectl apply -f https://github.com/kubernetes-sigs/aws-load-balancer-controller/releases/download/v2.7.0/v2_7_0_full.yaml
    
    # Wait for controller to be ready
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=aws-load-balancer-controller -n kube-system --timeout=300s
}

deploy_gcp() {
    print_info "Deploying GCP GKE cluster..."
    
    # Enable required APIs
    gcloud services enable container.googleapis.com
    gcloud services enable compute.googleapis.com
    
    # Check if Terraform is available
    if command -v terraform &> /dev/null; then
        cd manifests/cloud-infrastructure
        terraform init
        terraform plan -var="project_id=$PROJECT_ID"
        
        echo -e "${YELLOW}Do you want to apply the Terraform configuration? (y/n)${NC}"
        read -p "Apply: " apply_terraform
        
        if [[ "$apply_terraform" == "y" || "$apply_terraform" == "Y" ]]; then
            terraform apply -var="project_id=$PROJECT_ID" -auto-approve
        fi
        cd ../..
    else
        print_warning "Terraform not found. Please install Terraform to deploy GCP infrastructure."
        print_info "Manual deployment instructions are available in the DEPLOYMENT_GUIDE.md"
    fi
    
    # Get cluster credentials
    gcloud container clusters get-credentials $CLUSTER_NAME --region $GCP_REGION
}

deploy_azure() {
    print_info "Deploying Azure AKS cluster..."
    
    # Create resource group
    az group create --name $RESOURCE_GROUP --location $AZURE_LOCATION
    
    # Check if Terraform is available
    if command -v terraform &> /dev/null; then
        cd manifests/cloud-infrastructure
        terraform init
        terraform plan
        
        echo -e "${YELLOW}Do you want to apply the Terraform configuration? (y/n)${NC}"
        read -p "Apply: " apply_terraform
        
        if [[ "$apply_terraform" == "y" || "$apply_terraform" == "Y" ]]; then
            terraform apply -auto-approve
        fi
        cd ../..
    else
        print_warning "Terraform not found. Please install Terraform to deploy Azure infrastructure."
        print_info "Manual deployment instructions are available in the DEPLOYMENT_GUIDE.md"
    fi
    
    # Get cluster credentials
    az aks get-credentials --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME
}

# Deploy application
deploy_application() {
    print_step "Deploying Storm Surge application..."
    
    # Create namespace
    kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
    
    # Apply secrets
    kubectl apply -f manifests/secrets/generated-secrets.yaml
    
    # Deploy security hardening
    kubectl apply -f manifests/security/production-security-hardening.yaml
    
    # Deploy application services
    kubectl apply -f manifests/dev/services.yaml
    
    # Wait for deployments to be ready
    print_info "Waiting for deployments to be ready..."
    kubectl wait --for=condition=available deployment --all -n $NAMESPACE --timeout=600s
    
    # Get service endpoints
    print_info "Getting service information..."
    kubectl get services -n $NAMESPACE
    kubectl get ingress -n $NAMESPACE
}

# Show completion summary
show_completion_summary() {
    print_step "Deployment completed!"
    
    echo
    echo -e "${GREEN}=== DEPLOYMENT SUMMARY ===${NC}"
    echo -e "Cloud Provider: ${BLUE}$CLOUD_PROVIDER${NC}"
    echo -e "FQDN: ${BLUE}$FQDN${NC}"
    echo -e "Cluster: ${BLUE}$CLUSTER_NAME${NC}"
    echo -e "Namespace: ${BLUE}$NAMESPACE${NC}"
    echo
    
    echo -e "${YELLOW}=== NEXT STEPS ===${NC}"
    echo "1. Configure DNS to point $FQDN to your load balancer"
    echo "2. Verify SSL certificate provisioning"
    echo "3. Test application endpoints"
    echo "4. Set up monitoring and alerting"
    echo
    
    echo -e "${YELLOW}=== IMPORTANT NOTES ===${NC}"
    echo "• Admin credentials are stored in manifests/secrets/.env"
    echo "• Keep your secrets secure and do not commit them!"
    echo "• SSL certificates may take a few minutes to provision"
    echo "• Check the DEPLOYMENT_GUIDE.md for detailed instructions"
    echo
    
    echo -e "${GREEN}Storm Surge deployment completed successfully.${NC}"
    
    # Final IAM validation
    echo
    print_step "Final IAM validation..."
    if validate_iam_permissions; then
        echo -e "${GREEN}✓ IAM permissions verified for cluster management${NC}"
    else
        echo -e "${YELLOW}! Some IAM permissions may need adjustment for full cluster management${NC}"
        echo "Review: manifests/providerIAM/${CLOUD_PROVIDER}/README.md"
    fi
}

# Main execution
main() {
    print_header
    
    # Run setup steps
    check_prerequisites
    collect_configuration
    
    # IAM setup after cloud provider selection
    setup_iam_policies
    
    # Continue with configuration
    update_configuration_files
    generate_secrets
    
    echo
    echo -e "${YELLOW}Ready to deploy infrastructure. Continue? (y/n)${NC}"
    read -p "Continue: " continue_deploy
    
    if [[ "$continue_deploy" == "y" || "$continue_deploy" == "Y" ]]; then
        deploy_infrastructure
        deploy_application
        show_completion_summary
    else
        print_info "Setup completed. You can run the deployment manually later."
        print_info "Configuration files have been updated with your settings."
    fi
}

# Trap errors
trap 'print_error "Script failed on line $LINENO"' ERR

# Run main function
main "$@"