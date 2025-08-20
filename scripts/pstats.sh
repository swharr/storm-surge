#!/bin/bash

# Storm Surge Platform Status Script (pstats.sh)
# Comprehensive status check for all deployed clusters across cloud providers

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Status tracking
TOTAL_CLUSTERS=0
RUNNING_CLUSTERS=0
FAILED_CLUSTERS=0

print_header() {
    echo -e "${BOLD}${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${BLUE}║                    Storm Surge Platform Status                ║${NC}"
    echo -e "${BOLD}${BLUE}║                         $(date '+%Y-%m-%d %H:%M:%S')                         ║${NC}"
    echo -e "${BOLD}${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo
}

print_section() {
    echo -e "${CYAN}${BOLD}=== $1 ===${NC}"
}

print_status() {
    local status=$1
    local message=$2
    case $status in
        "RUNNING")
            echo -e "  ${GREEN}✓ RUNNING${NC}  $message"
            ((RUNNING_CLUSTERS++))
            ;;
        "STOPPED")
            echo -e "  ${YELLOW}⊘ STOPPED${NC}  $message"
            ;;
        "FAILED")
            echo -e "  ${RED}✗ FAILED${NC}   $message"
            ((FAILED_CLUSTERS++))
            ;;
        "DELETING")
            echo -e "  ${YELLOW}⌛ DELETING${NC} $message"
            ;;
        "CREATING")
            echo -e "  ${BLUE}⟳ CREATING${NC} $message"
            ;;
        "NONE")
            echo -e "  ${YELLOW}○ NONE${NC}     $message"
            ;;
        *)
            echo -e "  ${YELLOW}? UNKNOWN${NC}  $message"
            ;;
    esac
}

print_cluster_details() {
    local cluster_name=$1
    local region=$2
    local status=$3
    local nodes=$4
    local version=$5
    local endpoint=$6
    local cloud_provider=${7:-"unknown"}
    local context_name=${8:-""}
    
    echo -e "    ${BOLD}Cluster:${NC} $cluster_name"
    echo -e "    ${BOLD}Cloud:${NC}   $cloud_provider"
    echo -e "    ${BOLD}Region:${NC}  $region"
    echo -e "    ${BOLD}Status:${NC}  $status"
    echo -e "    ${BOLD}Nodes:${NC}   $nodes"
    echo -e "    ${BOLD}Version:${NC} $version"
    if [[ -n "$endpoint" && "$endpoint" != "null" ]]; then
        echo -e "    ${BOLD}Endpoint:${NC} $endpoint"
    fi
    
    # Get cost information
    get_cluster_cost_info "$cluster_name" "$cloud_provider" "$region" "${project_id:-""}"
    
    # Get detailed pod and uptime information if cluster is accessible
    if [[ "$status" == "ACTIVE" || "$status" == "RUNNING" || "$status" == "Succeeded" ]] && command -v kubectl &> /dev/null; then
        get_cluster_workload_details "$cluster_name" "$cloud_provider" "$context_name"
    fi
    
    echo
}

get_cluster_cost_info() {
    local cluster_name=$1
    local cloud_provider=$2
    local region=$3
    local project_id=${4:-""}
    
    case $cloud_provider in
        "AWS")
            get_aws_cluster_cost "$cluster_name" "$region"
            ;;
        "GCP")
            get_gcp_cluster_cost "$cluster_name" "$region" "$project_id"
            ;;
        "Azure")
            get_azure_cluster_cost "$cluster_name" "$region"
            ;;
        *)
            echo -e "    ${BOLD}Cost:${NC}     Cost tracking not available for $cloud_provider"
            ;;
    esac
}

get_aws_cluster_cost() {
    local cluster_name=$1
    local region=$2
    
    # Get today's date and 30 days ago for cost calculation
    local end_date=$(date '+%Y-%m-%d')
    local start_date=$(date -d '30 days ago' '+%Y-%m-%d' 2>/dev/null || date -v-30d '+%Y-%m-%d' 2>/dev/null || echo "2024-01-01")
    
    # Try to get EKS cluster costs using AWS Cost Explorer
    local cost_result=$(aws ce get-cost-and-usage \
        --time-period Start="$start_date",End="$end_date" \
        --granularity MONTHLY \
        --metrics BlendedCost \
        --group-by Type=DIMENSION,Key=SERVICE \
        --filter file://<(echo '{
            "Dimensions": {
                "Key": "SERVICE",
                "Values": ["Amazon Elastic Kubernetes Service", "Amazon Elastic Compute Cloud - Compute"]
            }
        }') \
        --query 'ResultsByTime[0].Groups[?Keys[0]==`Amazon Elastic Kubernetes Service`].Metrics.BlendedCost.Amount' \
        --output text 2>/dev/null || echo "")
    
    if [[ -n "$cost_result" && "$cost_result" != "None" ]]; then
        local monthly_cost=$(echo "$cost_result" | head -1)
        local daily_cost=$(echo "scale=2; $monthly_cost / 30" | bc 2>/dev/null || echo "unknown")
        echo -e "    ${BOLD}Cost:${NC}     ~\$${daily_cost}/day, \$${monthly_cost}/month (estimated)"
    else
        # Fallback: estimate based on instance types
        local node_groups=$(aws eks describe-nodegroup --cluster-name "$cluster_name" --nodegroup-name $(aws eks list-nodegroups --cluster-name "$cluster_name" --query 'nodegroups[0]' --output text 2>/dev/null) --region "$region" --query 'nodegroup.instanceTypes[0]' --output text 2>/dev/null || echo "")
        
        if [[ -n "$node_groups" && "$node_groups" != "None" ]]; then
            echo -e "    ${BOLD}Cost:${NC}     Instance type: $node_groups (use AWS Cost Explorer for precise costs)"
        else
            echo -e "    ${BOLD}Cost:${NC}     Cost data unavailable (check AWS Cost Explorer)"
        fi
    fi
}

get_gcp_cluster_cost() {
    local cluster_name=$1
    local region=$2
    local project_id=$3
    
    # Try to get GKE cluster costs using Cloud Billing API
    local cost_result=$(gcloud billing budgets list --billing-account=$(gcloud billing projects describe "$project_id" --format="value(billingAccountName)" 2>/dev/null | sed 's/.*\///') --format="value(amount.specifiedAmount.units)" 2>/dev/null | head -1 || echo "")
    
    if [[ -n "$cost_result" ]]; then
        echo -e "    ${BOLD}Cost:${NC}     Budget: \$${cost_result} (use Cloud Billing for detailed costs)"
    else
        # Get machine type information for cost estimation
        local machine_type=$(gcloud container clusters describe "$cluster_name" --region="$region" --format="value(nodeConfig.machineType)" 2>/dev/null || echo "")
        
        if [[ -n "$machine_type" ]]; then
            echo -e "    ${BOLD}Cost:${NC}     Machine type: $machine_type (use Cloud Billing for precise costs)"
        else
            echo -e "    ${BOLD}Cost:${NC}     Cost data unavailable (check Cloud Billing console)"
        fi
    fi
}

get_azure_cluster_cost() {
    local cluster_name=$1
    local region=$2
    
    # Try to get resource group for cost calculation
    local resource_group=$(az aks show --name "$cluster_name" --query resourceGroup --output tsv 2>/dev/null || echo "")
    
    if [[ -n "$resource_group" ]]; then
        # Get VM SKU information for cost estimation
        local vm_size=$(az aks show --name "$cluster_name" --resource-group "$resource_group" --query "agentPoolProfiles[0].vmSize" --output tsv 2>/dev/null || echo "")
        
        if [[ -n "$vm_size" ]]; then
            echo -e "    ${BOLD}Cost:${NC}     VM size: $vm_size (use Azure Cost Management for precise costs)"
        else
            echo -e "    ${BOLD}Cost:${NC}     Cost data unavailable (check Azure Cost Management)"
        fi
    else
        echo -e "    ${BOLD}Cost:${NC}     Cost data unavailable (check Azure Cost Management)"
    fi
}

get_cluster_workload_details() {
    local cluster_name=$1
    local cloud_provider=$2
    local context_name=$3
    
    # Set the appropriate kubectl context
    case $cloud_provider in
        "AWS")
            # AWS context should already be set from update-kubeconfig
            ;;
        "GCP")
            if [[ -n "$context_name" ]]; then
                kubectl config use-context "$context_name" &>/dev/null
            fi
            ;;
        "Azure")
            if [[ -n "$context_name" ]]; then
                kubectl config use-context "$context_name" &>/dev/null
            fi
            ;;
    esac
    
    # Get total pods across all namespaces
    local total_pods=$(kubectl get pods --all-namespaces --no-headers 2>/dev/null | wc -l | tr -d ' ' || echo "0")
    local running_pods=$(kubectl get pods --all-namespaces --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l | tr -d ' ' || echo "0")
    local pending_pods=$(kubectl get pods --all-namespaces --field-selector=status.phase=Pending --no-headers 2>/dev/null | wc -l | tr -d ' ' || echo "0")
    local failed_pods=$(kubectl get pods --all-namespaces --field-selector=status.phase=Failed --no-headers 2>/dev/null | wc -l | tr -d ' ' || echo "0")
    
    echo -e "    ${BOLD}Pods:${NC}     ${GREEN}$running_pods running${NC}, $pending_pods pending, $failed_pods failed (total: $total_pods)"
    
    # Get Storm Surge specific workloads and their uptime
    local storm_surge_namespaces=$(kubectl get namespaces -o name 2>/dev/null | grep -E "(storm-surge|oceansurge)" | sed 's/namespace\///' || echo "")
    
    if [[ -n "$storm_surge_namespaces" ]]; then
        echo -e "    ${BOLD}Storm Surge Workloads:${NC}"
        
        while IFS= read -r namespace; do
            if [[ -z "$namespace" ]]; then continue; fi
            
            echo -e "      ${CYAN}Namespace: $namespace${NC}"
            
            # Get deployments and their status
            local deployments=$(kubectl get deployments -n "$namespace" --no-headers 2>/dev/null || echo "")
            if [[ -n "$deployments" ]]; then
                while IFS= read -r deployment_line; do
                    if [[ -z "$deployment_line" ]]; then continue; fi
                    
                    local deployment_name=$(echo "$deployment_line" | awk '{print $1}')
                    local ready=$(echo "$deployment_line" | awk '{print $2}')
                    local available=$(echo "$deployment_line" | awk '{print $4}')
                    local age=$(echo "$deployment_line" | awk '{print $5}')
                    
                    # Get pod details for this deployment
                    local pods=$(kubectl get pods -n "$namespace" -l app="$deployment_name" --no-headers 2>/dev/null || echo "")
                    local pod_count=$(echo "$pods" | grep -v '^$' | wc -l | tr -d ' ')
                    
                    # Calculate uptime from oldest pod
                    local oldest_pod_age=""
                    if [[ -n "$pods" && "$pod_count" -gt 0 ]]; then
                        oldest_pod_age=$(echo "$pods" | awk '{print $5}' | sort -V | tail -1)
                    fi
                    
                    local status_icon="${RED}✗${NC}"
                    if [[ "$available" == "1" || "$ready" == *"/"* ]]; then
                        local ready_count=$(echo "$ready" | cut -d'/' -f1)
                        local desired_count=$(echo "$ready" | cut -d'/' -f2)
                        if [[ "$ready_count" == "$desired_count" && "$ready_count" -gt 0 ]]; then
                            status_icon="${GREEN}✓${NC}"
                        elif [[ "$ready_count" -gt 0 ]]; then
                            status_icon="${YELLOW}⚠${NC}"
                        fi
                    fi
                    
                    echo -e "        $status_icon ${BOLD}$deployment_name${NC}: $ready ready, $pod_count pods, uptime: ${oldest_pod_age:-$age}"
                    
                done <<< "$deployments"
            fi
            
            # Get services
            local services=$(kubectl get services -n "$namespace" --no-headers 2>/dev/null | wc -l | tr -d ' ' || echo "0")
            echo -e "        ${BOLD}Services:${NC} $services"
            
        done <<< "$storm_surge_namespaces"
    fi
    
    # Get node resource utilization if metrics-server is available
    local node_metrics=$(kubectl top nodes --no-headers 2>/dev/null || echo "")
    if [[ -n "$node_metrics" ]]; then
        echo -e "    ${BOLD}Resource Usage:${NC}"
        while IFS= read -r node_line; do
            if [[ -z "$node_line" ]]; then continue; fi
            local node_name=$(echo "$node_line" | awk '{print $1}')
            local cpu_usage=$(echo "$node_line" | awk '{print $2}')
            local memory_usage=$(echo "$node_line" | awk '{print $4}')
            echo -e "      ${BOLD}$node_name${NC}: CPU $cpu_usage, Memory $memory_usage"
        done <<< "$node_metrics"
    fi
    
    # Get cluster uptime (age of oldest system pod)
    local kube_system_uptime=$(kubectl get pods -n kube-system --sort-by=.metadata.creationTimestamp --no-headers 2>/dev/null | head -1 | awk '{print $5}' || echo "unknown")
    if [[ "$kube_system_uptime" != "unknown" ]]; then
        echo -e "    ${BOLD}Cluster Uptime:${NC} $kube_system_uptime"
    fi
}

check_prerequisites() {
    local missing_tools=()
    
    # Check for kubectl
    if ! command -v kubectl &> /dev/null; then
        missing_tools+=("kubectl")
    fi
    
    # Check for jq
    if ! command -v jq &> /dev/null; then
        missing_tools+=("jq")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        echo -e "${RED}Missing required tools: ${missing_tools[*]}${NC}"
        echo "Please install missing tools for full functionality"
        return 1
    fi
    
    return 0
}

check_aws_clusters() {
    print_section "AWS EKS Clusters"
    
    if ! command -v aws &> /dev/null; then
        print_status "NONE" "AWS CLI not installed"
        return
    fi
    
    # Check AWS authentication
    if ! aws sts get-caller-identity &>/dev/null; then
        print_status "FAILED" "AWS credentials not configured"
        return
    fi
    
    local aws_account=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
    echo -e "  ${BOLD}AWS Account:${NC} $aws_account"
    echo
    
    # Common AWS regions for Storm Surge
    local regions=("us-east-1" "us-east-2" "us-west-1" "us-west-2" "eu-west-1" "eu-central-1" "ap-southeast-1")
    local found_clusters=false
    
    for region in "${regions[@]}"; do
        local clusters=$(aws eks list-clusters --region "$region" --query 'clusters[]' --output text 2>/dev/null)
        
        if [[ -n "$clusters" ]]; then
            found_clusters=true
            echo -e "  ${BOLD}Region: $region${NC}"
            
            for cluster in $clusters; do
                ((TOTAL_CLUSTERS++))
                
                # Get cluster details
                local cluster_info=$(aws eks describe-cluster --name "$cluster" --region "$region" --output json 2>/dev/null)
                local status=$(echo "$cluster_info" | jq -r '.cluster.status' 2>/dev/null || echo "UNKNOWN")
                local version=$(echo "$cluster_info" | jq -r '.cluster.version' 2>/dev/null || echo "unknown")
                local endpoint=$(echo "$cluster_info" | jq -r '.cluster.endpoint' 2>/dev/null || echo "")
                
                # Get node count
                local nodes="unknown"
                if command -v kubectl &> /dev/null && [[ "$status" == "ACTIVE" ]]; then
                    # Try to get cluster credentials
                    if aws eks update-kubeconfig --name "$cluster" --region "$region" &>/dev/null; then
                        nodes=$(kubectl get nodes --no-headers 2>/dev/null | wc -l | tr -d ' ' || echo "unknown")
                    fi
                fi
                
                case $status in
                    "ACTIVE")
                        print_status "RUNNING" "$cluster"
                        ;;
                    "CREATING")
                        print_status "CREATING" "$cluster"
                        ;;
                    "DELETING")
                        print_status "DELETING" "$cluster"
                        ;;
                    "FAILED")
                        print_status "FAILED" "$cluster"
                        ;;
                    *)
                        print_status "UNKNOWN" "$cluster (status: $status)"
                        ;;
                esac
                
                print_cluster_details "$cluster" "$region" "$status" "$nodes" "$version" "$endpoint" "AWS" "$cluster"
            done
        fi
    done
    
    if [[ "$found_clusters" == false ]]; then
        print_status "NONE" "No EKS clusters found in any region"
    fi
    
    echo
}

check_gcp_clusters() {
    print_section "Google Cloud GKE Clusters"
    
    if ! command -v gcloud &> /dev/null; then
        print_status "NONE" "Google Cloud CLI not installed"
        return
    fi
    
    # Check GCP authentication
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null | head -1 &>/dev/null; then
        print_status "FAILED" "Google Cloud credentials not configured"
        return
    fi
    
    local project_id=$(gcloud config get-value project 2>/dev/null)
    if [[ -z "$project_id" ]]; then
        print_status "FAILED" "No Google Cloud project configured"
        return
    fi
    
    echo -e "  ${BOLD}GCP Project:${NC} $project_id"
    echo
    
    # Get all GKE clusters
    local clusters=$(gcloud container clusters list --format="json" 2>/dev/null)
    
    if [[ -z "$clusters" || "$clusters" == "[]" ]]; then
        print_status "NONE" "No GKE clusters found"
        echo
        return
    fi
    
    # Parse cluster information
    local cluster_count=$(echo "$clusters" | jq length)
    
    for ((i=0; i<cluster_count; i++)); do
        ((TOTAL_CLUSTERS++))
        
        local cluster_name=$(echo "$clusters" | jq -r ".[$i].name")
        local location=$(echo "$clusters" | jq -r ".[$i].location")
        local status=$(echo "$clusters" | jq -r ".[$i].status")
        local version=$(echo "$clusters" | jq -r ".[$i].currentMasterVersion")
        local node_count=$(echo "$clusters" | jq -r ".[$i].currentNodeCount // 0")
        local endpoint=$(echo "$clusters" | jq -r ".[$i].endpoint")
        
        case $status in
            "RUNNING")
                print_status "RUNNING" "$cluster_name"
                ;;
            "PROVISIONING")
                print_status "CREATING" "$cluster_name"
                ;;
            "STOPPING")
                print_status "DELETING" "$cluster_name"
                ;;
            "ERROR")
                print_status "FAILED" "$cluster_name"
                ;;
            *)
                print_status "UNKNOWN" "$cluster_name (status: $status)"
                ;;
        esac
        
        print_cluster_details "$cluster_name" "$location" "$status" "$node_count" "$version" "$endpoint" "GCP" "gke_${project_id}_${location}_${cluster_name}"
    done
    
    echo
}

check_azure_clusters() {
    print_section "Azure AKS Clusters"
    
    if ! command -v az &> /dev/null; then
        print_status "NONE" "Azure CLI not installed"
        return
    fi
    
    # Check Azure authentication
    if ! az account show &>/dev/null; then
        print_status "FAILED" "Azure credentials not configured (run 'az login')"
        return
    fi
    
    local subscription_id=$(az account show --query id --output tsv 2>/dev/null)
    local subscription_name=$(az account show --query name --output tsv 2>/dev/null)
    echo -e "  ${BOLD}Azure Subscription:${NC} $subscription_name ($subscription_id)"
    echo
    
    # Get all AKS clusters
    local clusters=$(az aks list --output json 2>/dev/null)
    
    if [[ -z "$clusters" || "$clusters" == "[]" ]]; then
        print_status "NONE" "No AKS clusters found"
        echo
        return
    fi
    
    # Parse cluster information
    local cluster_count=$(echo "$clusters" | jq length)
    
    for ((i=0; i<cluster_count; i++)); do
        ((TOTAL_CLUSTERS++))
        
        local cluster_name=$(echo "$clusters" | jq -r ".[$i].name")
        local resource_group=$(echo "$clusters" | jq -r ".[$i].resourceGroup")
        local location=$(echo "$clusters" | jq -r ".[$i].location")
        local status=$(echo "$clusters" | jq -r ".[$i].provisioningState")
        local version=$(echo "$clusters" | jq -r ".[$i].kubernetesVersion")
        local node_count=$(echo "$clusters" | jq -r ".[$i].agentPoolProfiles[0].count // 0")
        local fqdn=$(echo "$clusters" | jq -r ".[$i].fqdn")
        
        case $status in
            "Succeeded")
                print_status "RUNNING" "$cluster_name"
                ;;
            "Creating")
                print_status "CREATING" "$cluster_name"
                ;;
            "Deleting")
                print_status "DELETING" "$cluster_name"
                ;;
            "Failed")
                print_status "FAILED" "$cluster_name"
                ;;
            *)
                print_status "UNKNOWN" "$cluster_name (status: $status)"
                ;;
        esac
        
        print_cluster_details "$cluster_name" "$location" "$status" "$node_count" "$version" "$fqdn" "Azure" "$cluster_name"
    done
    
    echo
}

check_local_clusters() {
    print_section "Local Development Clusters"
    
    local found_local=false
    
    # Check for minikube
    if command -v minikube &> /dev/null; then
        local minikube_status=$(minikube status --format="{{.Host}}" 2>/dev/null || echo "Stopped")
        if [[ "$minikube_status" == "Running" ]]; then
            print_status "RUNNING" "minikube"
            found_local=true
            echo -e "    ${BOLD}Type:${NC} Minikube"
            echo -e "    ${BOLD}Status:${NC} Running"
            if command -v kubectl &> /dev/null; then
                local nodes=$(kubectl get nodes --context=minikube --no-headers 2>/dev/null | wc -l | tr -d ' ' || echo "unknown")
                echo -e "    ${BOLD}Nodes:${NC} $nodes"
            fi
            echo
        else
            print_status "STOPPED" "minikube"
            found_local=true
        fi
    fi
    
    # Check for kind clusters
    if command -v kind &> /dev/null; then
        local kind_clusters=$(kind get clusters 2>/dev/null)
        if [[ -n "$kind_clusters" ]]; then
            while IFS= read -r cluster; do
                print_status "RUNNING" "kind: $cluster"
                found_local=true
                echo -e "    ${BOLD}Type:${NC} kind"
                echo -e "    ${BOLD}Cluster:${NC} $cluster"
                if command -v kubectl &> /dev/null; then
                    local nodes=$(kubectl get nodes --context="kind-$cluster" --no-headers 2>/dev/null | wc -l | tr -d ' ' || echo "unknown")
                    echo -e "    ${BOLD}Nodes:${NC} $nodes"
                fi
                echo
            done <<< "$kind_clusters"
        fi
    fi
    
    # Check for Docker Desktop Kubernetes
    if command -v kubectl &> /dev/null; then
        if kubectl config get-contexts docker-desktop &>/dev/null; then
            local docker_status=$(kubectl cluster-info --context=docker-desktop 2>/dev/null && echo "Running" || echo "Stopped")
            if [[ "$docker_status" == "Running" ]]; then
                print_status "RUNNING" "Docker Desktop Kubernetes"
                found_local=true
                echo -e "    ${BOLD}Type:${NC} Docker Desktop"
                echo -e "    ${BOLD}Status:${NC} Running"
                local nodes=$(kubectl get nodes --context=docker-desktop --no-headers 2>/dev/null | wc -l | tr -d ' ' || echo "unknown")
                echo -e "    ${BOLD}Nodes:${NC} $nodes"
                echo
            fi
        fi
    fi
    
    if [[ "$found_local" == false ]]; then
        print_status "NONE" "No local development clusters found"
    fi
    
    echo
}

check_storm_surge_deployments() {
    print_section "Storm Surge Application Deployments"
    
    if ! command -v kubectl &> /dev/null; then
        print_status "FAILED" "kubectl not available for checking deployments"
        return
    fi
    
    # Get all available contexts
    local contexts=$(kubectl config get-contexts -o name 2>/dev/null)
    local found_deployments=false
    
    if [[ -z "$contexts" ]]; then
        print_status "NONE" "No kubectl contexts available"
        return
    fi
    
    while IFS= read -r context; do
        if [[ -z "$context" ]]; then continue; fi
        
        # Check for Storm Surge namespaces
        local namespaces=$(kubectl get namespaces --context="$context" -o name 2>/dev/null | grep -E "(storm-surge|oceansurge)" | sed 's/namespace\///' || echo "")
        
        if [[ -n "$namespaces" ]]; then
            found_deployments=true
            echo -e "  ${BOLD}Context:${NC} $context"
            
            while IFS= read -r namespace; do
                if [[ -z "$namespace" ]]; then continue; fi
                
                echo -e "    ${BOLD}Namespace:${NC} $namespace"
                
                # Check deployments
                local deployments=$(kubectl get deployments --context="$context" -n "$namespace" --no-headers 2>/dev/null | wc -l | tr -d ' ' || echo "0")
                local running_pods=$(kubectl get pods --context="$context" -n "$namespace" --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l | tr -d ' ' || echo "0")
                local total_pods=$(kubectl get pods --context="$context" -n "$namespace" --no-headers 2>/dev/null | wc -l | tr -d ' ' || echo "0")
                local services=$(kubectl get services --context="$context" -n "$namespace" --no-headers 2>/dev/null | wc -l | tr -d ' ' || echo "0")
                
                echo -e "    ${BOLD}Deployments:${NC} $deployments"
                echo -e "    ${BOLD}Pods:${NC} $running_pods/$total_pods running"
                echo -e "    ${BOLD}Services:${NC} $services"
                
                # Check for specific Storm Surge components
                local components=("frontend" "product-catalog" "shopping-cart" "feature-flag-middleware")
                for component in "${components[@]}"; do
                    local component_status=$(kubectl get deployment "$component" --context="$context" -n "$namespace" -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null || echo "")
                    if [[ "$component_status" == "True" ]]; then
                        echo -e "      ${GREEN}✓${NC} $component"
                    elif [[ -n "$component_status" ]]; then
                        echo -e "      ${RED}✗${NC} $component"
                    fi
                done
                
                echo
            done <<< "$namespaces"
        fi
    done <<< "$contexts"
    
    if [[ "$found_deployments" == false ]]; then
        print_status "NONE" "No Storm Surge deployments found"
    fi
    
    echo
}

print_summary() {
    print_section "Summary"
    
    echo -e "  ${BOLD}Total Clusters Found:${NC} $TOTAL_CLUSTERS"
    echo -e "  ${BOLD}Running Clusters:${NC} ${GREEN}$RUNNING_CLUSTERS${NC}"
    echo -e "  ${BOLD}Failed Clusters:${NC} ${RED}$FAILED_CLUSTERS${NC}"
    echo
    
    if [[ $RUNNING_CLUSTERS -gt 0 ]]; then
        echo -e "${GREEN}${BOLD}✓ You have $RUNNING_CLUSTERS active Kubernetes cluster(s)${NC}"
    else
        echo -e "${YELLOW}${BOLD}○ No active clusters found${NC}"
    fi
    
    if [[ $FAILED_CLUSTERS -gt 0 ]]; then
        echo -e "${RED}${BOLD}✗ $FAILED_CLUSTERS cluster(s) require attention${NC}"
    fi
    
    echo
    echo -e "${CYAN}${BOLD}Quick Actions:${NC}"
    echo -e "  ${BOLD}Deploy new cluster:${NC} ./setup.sh"
    echo -e "  ${BOLD}Cleanup AWS:${NC} ./scripts/cleanup/cleanup-aws.sh"
    echo -e "  ${BOLD}Cleanup GCP:${NC} ./scripts/cleanup/cleanup-gcp.sh"
    echo -e "  ${BOLD}Cleanup Azure:${NC} ./scripts/cleanup/cleanup-azure.sh"
    echo
}

show_demo() {
    print_header
    echo -e "${YELLOW}${BOLD}Demo Mode - Simulated Storm Surge Platform Status${NC}"
    echo
    
    print_section "AWS EKS Clusters"
    echo -e "  ${BOLD}AWS Account:${NC} 123456789012"
    echo
    echo -e "  ${BOLD}Region: us-east-1${NC}"
    print_status "RUNNING" "storm-surge-prod"
    echo -e "    ${BOLD}Cluster:${NC} storm-surge-prod"
    echo -e "    ${BOLD}Cloud:${NC}   AWS"
    echo -e "    ${BOLD}Region:${NC}  us-east-1"
    echo -e "    ${BOLD}Status:${NC}  ACTIVE"
    echo -e "    ${BOLD}Nodes:${NC}   3"
    echo -e "    ${BOLD}Version:${NC} 1.28"
    echo -e "    ${BOLD}Endpoint:${NC} https://A1B2C3D4E5F6.gr7.us-east-1.eks.amazonaws.com"
    echo -e "    ${BOLD}Cost:${NC}     ~\$4.32/day, \$129.60/month (estimated)"
    echo -e "    ${BOLD}Pods:${NC}     ${GREEN}12 running${NC}, 0 pending, 0 failed (total: 12)"
    echo -e "    ${BOLD}Storm Surge Workloads:${NC}"
    echo -e "      ${CYAN}Namespace: storm-surge-prod${NC}"
    echo -e "        ${GREEN}✓${NC} ${BOLD}frontend${NC}: 1/1 ready, 1 pods, uptime: 2d5h"
    echo -e "        ${GREEN}✓${NC} ${BOLD}product-catalog${NC}: 2/2 ready, 2 pods, uptime: 2d5h"
    echo -e "        ${GREEN}✓${NC} ${BOLD}shopping-cart${NC}: 1/1 ready, 1 pods, uptime: 2d5h"
    echo -e "        ${GREEN}✓${NC} ${BOLD}feature-flag-middleware${NC}: 1/1 ready, 1 pods, uptime: 1d18h"
    echo -e "        ${BOLD}Services:${NC} 6"
    echo -e "    ${BOLD}Resource Usage:${NC}"
    echo -e "      ${BOLD}ip-10-0-1-100.ec2.internal${NC}: CPU 245m, Memory 892Mi"
    echo -e "      ${BOLD}ip-10-0-2-150.ec2.internal${NC}: CPU 189m, Memory 654Mi"
    echo -e "      ${BOLD}ip-10-0-3-200.ec2.internal${NC}: CPU 156m, Memory 523Mi"
    echo -e "    ${BOLD}Cluster Uptime:${NC} 2d5h"
    echo
    
    echo -e "  ${BOLD}Region: us-west-2${NC}"
    print_status "CREATING" "storm-surge-dev"
    echo -e "    ${BOLD}Cluster:${NC} storm-surge-dev"
    echo -e "    ${BOLD}Cloud:${NC}   AWS"
    echo -e "    ${BOLD}Region:${NC}  us-west-2"
    echo -e "    ${BOLD}Status:${NC}  CREATING"
    echo -e "    ${BOLD}Nodes:${NC}   2"
    echo -e "    ${BOLD}Version:${NC} 1.28"
    echo -e "    ${BOLD}Cost:${NC}     Instance type: t3.medium (use AWS Cost Explorer for precise costs)"
    echo
    
    print_section "Google Cloud GKE Clusters"
    echo -e "  ${BOLD}GCP Project:${NC} storm-surge-demo-12345"
    echo
    print_status "RUNNING" "storm-surge-gke"
    echo -e "    ${BOLD}Cluster:${NC} storm-surge-gke"
    echo -e "    ${BOLD}Cloud:${NC}   GCP"
    echo -e "    ${BOLD}Region:${NC}  us-central1"
    echo -e "    ${BOLD}Status:${NC}  RUNNING"
    echo -e "    ${BOLD}Nodes:${NC}   3"
    echo -e "    ${BOLD}Version:${NC} 1.28.7-gke.1026000"
    echo -e "    ${BOLD}Endpoint:${NC} 34.122.45.67"
    echo -e "    ${BOLD}Cost:${NC}     Machine type: e2-standard-2 (use Cloud Billing for precise costs)"
    echo -e "    ${BOLD}Pods:${NC}     ${GREEN}8 running${NC}, 1 pending, 0 failed (total: 9)"
    echo -e "    ${BOLD}Storm Surge Workloads:${NC}"
    echo -e "      ${CYAN}Namespace: oceansurge${NC}"
    echo -e "        ${GREEN}✓${NC} ${BOLD}frontend${NC}: 1/1 ready, 1 pods, uptime: 1d2h"
    echo -e "        ${YELLOW}⚠${NC} ${BOLD}product-catalog${NC}: 1/2 ready, 2 pods, uptime: 1d2h"
    echo -e "        ${GREEN}✓${NC} ${BOLD}shopping-cart${NC}: 1/1 ready, 1 pods, uptime: 1d2h"
    echo -e "        ${BOLD}Services:${NC} 4"
    echo -e "    ${BOLD}Cluster Uptime:${NC} 1d2h"
    echo
    
    print_section "Azure AKS Clusters"
    echo -e "  ${BOLD}Azure Subscription:${NC} Storm Surge Demo (12345678-1234-1234-1234-123456789012)"
    echo
    print_status "NONE" "No AKS clusters found"
    echo
    
    print_section "Local Development Clusters"
    print_status "RUNNING" "minikube"
    echo -e "    ${BOLD}Type:${NC} Minikube"
    echo -e "    ${BOLD}Status:${NC} Running"
    echo -e "    ${BOLD}Nodes:${NC} 1"
    echo
    print_status "RUNNING" "kind: storm-surge-local"
    echo -e "    ${BOLD}Type:${NC} kind"
    echo -e "    ${BOLD}Cluster:${NC} storm-surge-local"
    echo -e "    ${BOLD}Nodes:${NC} 3"
    echo
    
    print_section "Storm Surge Application Deployments"
    echo -e "  ${BOLD}Context:${NC} arn:aws:eks:us-east-1:123456789012:cluster/storm-surge-prod"
    echo -e "    ${BOLD}Namespace:${NC} storm-surge-prod"
    echo -e "    ${BOLD}Deployments:${NC} 4"
    echo -e "    ${BOLD}Pods:${NC} 5/5 running"
    echo -e "    ${BOLD}Services:${NC} 6"
    echo -e "      ${GREEN}✓${NC} frontend"
    echo -e "      ${GREEN}✓${NC} product-catalog"
    echo -e "      ${GREEN}✓${NC} shopping-cart"
    echo -e "      ${GREEN}✓${NC} feature-flag-middleware"
    echo
    echo -e "  ${BOLD}Context:${NC} gke_storm-surge-demo-12345_us-central1_storm-surge-gke"
    echo -e "    ${BOLD}Namespace:${NC} oceansurge"
    echo -e "    ${BOLD}Deployments:${NC} 3"
    echo -e "    ${BOLD}Pods:${NC} 3/4 running"
    echo -e "    ${BOLD}Services:${NC} 4"
    echo -e "      ${GREEN}✓${NC} frontend"
    echo -e "      ${RED}✗${NC} product-catalog"
    echo -e "      ${GREEN}✓${NC} shopping-cart"
    echo
    
    print_section "Summary"
    echo -e "  ${BOLD}Total Clusters Found:${NC} 4"
    echo -e "  ${BOLD}Running Clusters:${NC} ${GREEN}3${NC}"
    echo -e "  ${BOLD}Failed Clusters:${NC} ${RED}0${NC}"
    echo
    echo -e "${GREEN}${BOLD}✓ You have 3 active Kubernetes cluster(s)${NC}"
    echo
    echo -e "${CYAN}${BOLD}Quick Actions:${NC}"
    echo -e "  ${BOLD}Deploy new cluster:${NC} ./setup.sh"
    echo -e "  ${BOLD}Cleanup AWS:${NC} ./scripts/cleanup/cleanup-aws.sh"
    echo -e "  ${BOLD}Cleanup GCP:${NC} ./scripts/cleanup/cleanup-gcp.sh"
    echo -e "  ${BOLD}Cleanup Azure:${NC} ./scripts/cleanup/cleanup-azure.sh"
    echo
    
    exit 0
}

show_help() {
    echo "Storm Surge Platform Status Script"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help          Show this help message"
    echo "  --demo              Show demo output with sample data"
    echo "  --aws-only          Check only AWS EKS clusters"
    echo "  --gcp-only          Check only Google Cloud GKE clusters"
    echo "  --azure-only        Check only Azure AKS clusters"
    echo "  --local-only        Check only local development clusters"
    echo "  --no-apps           Skip application deployment checks"
    echo "  --json              Output in JSON format"
    echo ""
    echo "Examples:"
    echo "  $0                  # Check all cloud providers and local clusters"
    echo "  $0 --demo           # Show demo output with sample data"
    echo "  $0 --aws-only       # Check only AWS EKS clusters"
    echo "  $0 --no-apps        # Skip application deployment status"
    exit 0
}

# Parse command line arguments
AWS_ONLY=false
GCP_ONLY=false
AZURE_ONLY=false
LOCAL_ONLY=false
NO_APPS=false
JSON_OUTPUT=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            ;;
        --demo)
            show_demo
            ;;
        --aws-only)
            AWS_ONLY=true
            shift
            ;;
        --gcp-only)
            GCP_ONLY=true
            shift
            ;;
        --azure-only)
            AZURE_ONLY=true
            shift
            ;;
        --local-only)
            LOCAL_ONLY=true
            shift
            ;;
        --no-apps)
            NO_APPS=true
            shift
            ;;
        --json)
            JSON_OUTPUT=true
            shift
            ;;
        *)
            echo "Unknown option $1"
            show_help
            ;;
    esac
done

# Main execution
main() {
    if [[ "$JSON_OUTPUT" == true ]]; then
        echo "JSON output not yet implemented"
        exit 1
    fi
    
    print_header
    check_prerequisites
    
    if [[ "$AWS_ONLY" == true ]]; then
        check_aws_clusters
    elif [[ "$GCP_ONLY" == true ]]; then
        check_gcp_clusters
    elif [[ "$AZURE_ONLY" == true ]]; then
        check_azure_clusters
    elif [[ "$LOCAL_ONLY" == true ]]; then
        check_local_clusters
    else
        check_aws_clusters
        check_gcp_clusters
        check_azure_clusters
        check_local_clusters
    fi
    
    if [[ "$NO_APPS" != true ]]; then
        check_storm_surge_deployments
    fi
    
    print_summary
}

# Run main function
main "$@"