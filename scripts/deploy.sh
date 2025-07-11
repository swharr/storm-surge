#!/bin/bash
set -e

# Load .env if it exists
if [ -f .env ]; then
    echo "📥 Loading environment from .env"
    set -a
    source .env
    set +a
fi

show_usage() {
  echo "Usage: $0 [--provider=gke|eks|aks|all] [--region=REGION] [--zone=ZONE] [--nodes=COUNT]"
  echo "  --provider: Cloud provider (gke, eks, aks, or all)"
  echo "  --region: Cloud region (e.g., us-central1, us-east-1, eastus)"
  echo "  --zone: Availability zone (must match region)"
  echo "  --nodes: Number of nodes (1-10, default: 4)"
  exit 1
}

# Parse arguments
PROVIDER=""
REGION=""
ZONE=""
NODES=""

for arg in "$@"; do
  case $arg in
    --provider=*)
      PROVIDER="${arg#*=}"
      shift
      ;;
    --region=*)
      REGION="${arg#*=}"
      shift
      ;;
    --zone=*)
      ZONE="${arg#*=}"
      shift
      ;;
    --nodes=*)
      NODES="${arg#*=}"
      shift
      ;;
    --all)
      PROVIDER="all"
      shift
      ;;
    --help|-h)
      show_usage
      ;;
    *)
      echo "❌ Unknown argument: $arg"
      show_usage
      ;;
  esac
done

echo "🌩️ Deploying Storm Surge via deploy.sh"
echo "======================================"

# Interactive provider selection
get_provider() {
  while true; do
    echo "📋 Available cloud providers:"
    echo "  1) gke  - Google Kubernetes Engine"
    echo "  2) eks  - Amazon Elastic Kubernetes Service"
    echo "  3) aks  - Azure Kubernetes Service"
    echo "  4) all  - Deploy to all providers"
    echo
    read -p "Select provider (1-4 or gke/eks/aks/all): " choice
    
    case $choice in
      1|gke) PROVIDER="gke"; break ;;
      2|eks) PROVIDER="eks"; break ;;
      3|aks) PROVIDER="aks"; break ;;
      4|all) PROVIDER="all"; break ;;
      *) echo "❌ Invalid choice. Please try again."; echo ;;
    esac
  done
}

# Interactive region selection based on provider
get_region() {
  local provider=$1
  while true; do
    case $provider in
      "gke")
        echo "📍 Available GCP regions:"
        echo "  1) us-central1    (Iowa)"
        echo "  2) us-east1       (South Carolina)"
        echo "  3) us-west1       (Oregon)"
        echo "  4) us-west2       (California)"
        echo "  5) europe-west1   (Belgium)"
        echo "  6) asia-east1     (Taiwan)"
        echo
        read -p "Select region (1-6 or enter region name): " choice
        case $choice in
          1) REGION="us-central1"; break ;;
          2) REGION="us-east1"; break ;;
          3) REGION="us-west1"; break ;;
          4) REGION="us-west2"; break ;;
          5) REGION="europe-west1"; break ;;
          6) REGION="asia-east1"; break ;;
          us-central1|us-east1|us-west1|us-west2|europe-west1|asia-east1)
            REGION="$choice"; break ;;
          *) echo "❌ Invalid choice. Please try again."; echo ;;
        esac
        ;;
      "eks")
        echo "📍 Available AWS regions:"
        echo "  1) us-east-1      (N. Virginia)"
        echo "  2) us-east-2      (Ohio)"
        echo "  3) us-west-1      (N. California)"
        echo "  4) us-west-2      (Oregon)"
        echo "  5) eu-west-1      (Ireland)"
        echo "  6) ap-southeast-1 (Singapore)"
        echo
        read -p "Select region (1-6 or enter region name): " choice
        case $choice in
          1) REGION="us-east-1"; break ;;
          2) REGION="us-east-2"; break ;;
          3) REGION="us-west-1"; break ;;
          4) REGION="us-west-2"; break ;;
          5) REGION="eu-west-1"; break ;;
          6) REGION="ap-southeast-1"; break ;;
          us-east-1|us-east-2|us-west-1|us-west-2|eu-west-1|ap-southeast-1)
            REGION="$choice"; break ;;
          *) echo "❌ Invalid choice. Please try again."; echo ;;
        esac
        ;;
      "aks")
        echo "📍 Available Azure regions:"
        echo "  1) eastus         (East US)"
        echo "  2) westus2        (West US 2)"
        echo "  3) centralus      (Central US)"
        echo "  4) westeurope     (West Europe)"
        echo "  5) southeastasia  (Southeast Asia)"
        echo
        read -p "Select region (1-5 or enter region name): " choice
        case $choice in
          1) REGION="eastus"; break ;;
          2) REGION="westus2"; break ;;
          3) REGION="centralus"; break ;;
          4) REGION="westeurope"; break ;;
          5) REGION="southeastasia"; break ;;
          eastus|westus2|centralus|westeurope|southeastasia)
            REGION="$choice"; break ;;
          *) echo "❌ Invalid choice. Please try again."; echo ;;
        esac
        ;;
    esac
  done
}

# Interactive zone selection with validation
get_zone() {
  local provider=$1
  local region=$2
  while true; do
    case $provider in
      "gke")
        echo "🗺️  Available zones in $region:"
        case $region in
          us-central1) echo "  a, b, c, f" ;;
          us-east1) echo "  b, c, d" ;;
          us-west1) echo "  a, b, c" ;;
          us-west2) echo "  a, b, c" ;;
          europe-west1) echo "  b, c, d" ;;
          asia-east1) echo "  a, b, c" ;;
        esac
        echo
        read -p "Enter zone suffix (e.g., 'a' for ${region}-a): " zone_suffix
        ZONE="${region}-${zone_suffix}"
        
        # Validate zone exists for region
        case $region in
          us-central1) [[ "$zone_suffix" =~ ^[abcf]$ ]] && break ;;
          us-east1) [[ "$zone_suffix" =~ ^[bcd]$ ]] && break ;;
          us-west1|us-west2) [[ "$zone_suffix" =~ ^[abc]$ ]] && break ;;
          europe-west1) [[ "$zone_suffix" =~ ^[bcd]$ ]] && break ;;
          asia-east1) [[ "$zone_suffix" =~ ^[abc]$ ]] && break ;;
        esac
        echo "❌ Invalid zone '$zone_suffix' for region '$region'. Please try again."
        echo
        ;;
      "eks")
        echo "🗺️  Available zones in $region:"
        case $region in
          us-east-1) echo "  a, b, c, d, e, f" ;;
          us-east-2) echo "  a, b, c" ;;
          us-west-1) echo "  a, c" ;;
          us-west-2) echo "  a, b, c, d" ;;
          eu-west-1) echo "  a, b, c" ;;
          ap-southeast-1) echo "  a, b, c" ;;
        esac
        echo
        read -p "Enter zone suffix (e.g., 'a' for ${region}a): " zone_suffix
        ZONE="${region}${zone_suffix}"
        
        # Validate zone exists for region
        case $region in
          us-east-1) [[ "$zone_suffix" =~ ^[abcdef]$ ]] && break ;;
          us-east-2|eu-west-1|ap-southeast-1) [[ "$zone_suffix" =~ ^[abc]$ ]] && break ;;
          us-west-1) [[ "$zone_suffix" =~ ^[ac]$ ]] && break ;;
          us-west-2) [[ "$zone_suffix" =~ ^[abcd]$ ]] && break ;;
        esac
        echo "❌ Invalid zone '$zone_suffix' for region '$region'. Please try again."
        echo
        ;;
      "aks")
        echo "🗺️  Azure zones in $region:"
        echo "  1, 2, 3 (availability zones)"
        echo
        read -p "Enter zone number (1-3): " zone_num
        case $zone_num in
          1|2|3) ZONE="$zone_num"; break ;;
          *) echo "❌ Invalid zone. Please enter 1, 2, or 3."; echo ;;
        esac
        ;;
    esac
  done
}

# Interactive node count selection
get_node_count() {
  while true; do
    echo "🖥️  Node configuration:"
    echo "  • Default: 4 nodes (recommended)"
    echo "  • Range: 1-10 nodes maximum"
    echo
    read -p "Enter number of nodes (1-10, or 'default' for 4): " node_input
    
    case $node_input in
      "default"|"Default"|"DEFAULT"|"")
        NODES=4
        break
        ;;
      [1-9]|10)
        NODES=$node_input
        break
        ;;
      *)
        echo "❌ Invalid input. Please enter a number between 1-10 or 'default'."
        echo
        ;;
    esac
  done
}

if [ -z "$PROVIDER" ]; then
  echo "❓ No provider specified."
  get_provider
fi

SCRIPTS_DIR=$(dirname "$0")/providers

# Check if cluster exists for each provider
check_cluster_exists() {
  local provider=$1
  local region=$2
  local zone=$3
  
  case $provider in
    "gke")
      if command -v gcloud &> /dev/null; then
        gcloud container clusters describe "storm-surge-gke" --zone="$zone" &>/dev/null
      else
        return 1
      fi
      ;;
    "eks")
      if command -v aws &> /dev/null; then
        aws eks describe-cluster --name "storm-surge-eks" --region="$region" &>/dev/null
      else
        return 1
      fi
      ;;
    "aks")
      if command -v az &> /dev/null; then
        az aks show --resource-group "storm-surge-rg" --name "storm-surge-aks" &>/dev/null
      else
        return 1
      fi
      ;;
    *)
      return 1
      ;;
  esac
}

# Prompt user for action when cluster exists
handle_existing_cluster() {
  local provider=$1
  
  echo "🔍 Found existing storm-surge-$provider cluster!"
  echo
  echo "   What would you like to do?"
  echo "   1) Deploy workloads only (faster, uses existing cluster)"
  echo "   2) Delete and recreate cluster (slower, fresh start)"
  echo "   3) Cancel deployment"
  echo
  
  while true; do
    read -p "Select option (1-3): " choice
    case $choice in
      1)
        echo "✅ Will deploy workloads to existing cluster"
        export STORM_SKIP_CLUSTER_CREATION="true"
        return 0
        ;;
      2)
        echo "🗑️  Will delete and recreate cluster"
        export STORM_SKIP_CLUSTER_CREATION="false"
        delete_existing_cluster "$provider"
        return 0
        ;;
      3)
        echo "❌ Deployment cancelled"
        exit 0
        ;;
      *)
        echo "❌ Invalid choice. Please enter 1, 2, or 3."
        ;;
    esac
  done
}

# Delete existing cluster
delete_existing_cluster() {
  local provider=$1
  
  echo "🗑️  Deleting existing $provider cluster..."
  case $provider in
    "gke")
      if gcloud container clusters delete "storm-surge-gke" --zone="$ZONE" --quiet; then
        echo "✅ GKE cluster deleted"
      else
        echo "❌ Failed to delete GKE cluster"
        exit 1
      fi
      ;;
    "eks")
      if eksctl delete cluster "storm-surge-eks" --region="$REGION"; then
        echo "✅ EKS cluster deleted"
      else
        echo "❌ Failed to delete EKS cluster"
        exit 1
      fi
      ;;
    "aks")
      if az aks delete --resource-group "storm-surge-rg" --name "storm-surge-aks" --yes; then
        echo "✅ AKS cluster deleted"
      else
        echo "❌ Failed to delete AKS cluster"
        exit 1
      fi
      ;;
  esac
}

run_provider() {
  local p=$1
  local script="${SCRIPTS_DIR}/${p}.sh"
  
  if [ -f "$script" ]; then
    echo "🚀 Running deployment script for $p..."
    echo "   Region: $REGION"
    echo "   Zone: $ZONE"
    echo "   Nodes: $NODES"
    echo
    
    # Export variables for the provider script
    export STORM_REGION="$REGION"
    export STORM_ZONE="$ZONE"
    export STORM_NODES="$NODES"
    
    bash "$script"
  else
    echo "❌ Deployment script for provider '$p' not found."
    exit 1
  fi
}

# Collect configuration for each provider
if [ "$PROVIDER" = "all" ]; then
  echo "🌍 Deploying to all providers..."
  echo "You'll need to configure each provider separately:"
  echo
  
  for p in gke eks aks; do
    echo "=== Configuring $p ==="
    
    if [ -z "$REGION" ]; then
      get_region $p
    fi
    
    if [ -z "$ZONE" ]; then
      get_zone $p $REGION
    fi
    
    if [ -z "$NODES" ]; then
      get_node_count
    fi
    
    # Check if cluster exists and handle accordingly
    if check_cluster_exists "$p" "$REGION" "$ZONE"; then
      handle_existing_cluster "$p"
    fi
    
    run_provider $p
    
    # Reset for next provider
    REGION=""
    ZONE=""
    NODES=""
    echo
  done
else
  # Single provider deployment
  if [ -z "$REGION" ]; then
    get_region $PROVIDER
  fi
  
  if [ -z "$ZONE" ]; then
    get_zone $PROVIDER $REGION
  fi
  
  if [ -z "$NODES" ]; then
    get_node_count
  fi
  
  # Check if cluster exists and handle accordingly
  if check_cluster_exists "$PROVIDER" "$REGION" "$ZONE"; then
    handle_existing_cluster "$PROVIDER"
  fi
  
  echo
  echo "🎯 Deployment Configuration:"
  echo "   Provider: $PROVIDER"
  echo "   Region: $REGION"
  echo "   Zone: $ZONE"
  echo "   Nodes: $NODES"
  echo
  
  read -p "Proceed with deployment? (y/N): " confirm
  case $confirm in
    [Yy]|[Yy][Ee][Ss])
      run_provider $PROVIDER
      ;;
    *)
      echo "❌ Deployment cancelled."
      exit 0
      ;;
  esac
fi

echo "✅ All deployments completed."