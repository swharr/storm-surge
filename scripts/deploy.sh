#!/bin/bash
set -e

# Load .env if it exists
if [ -f .env ]; then
    echo "Loading environment from .env"
    set -a
    source .env
    set +a
fi

show_usage() {
  echo "Usage: $0 [--provider=gke|eks|aks|all] [--region=REGION] [--zone=ZONE] [--nodes=COUNT] [--cluster-name=NAME] [--aws-profile=PROFILE] [--yes]"
  echo "  --provider: Cloud provider (gke, eks, aks, or all)"
  echo "  --region: Cloud region (e.g., us-central1, us-east-1, eastus)"
  echo "  --zone: Availability zone (must match region)"
  echo "  --nodes: Number of nodes (1-10, default: 4)"
  echo "  --cluster-name: Custom cluster name (default: storm-surge-PROVIDER)"
  echo "  --aws-profile: AWS profile to use (for EKS deployments)"
  echo "  --yes: Skip interactive prompts (use defaults)"
  exit 1
}

# Parse arguments
PROVIDER=""
REGION=""
ZONE=""
NODES=""
CLUSTER_NAME=""
AWS_PROFILE=""
NON_INTERACTIVE=false

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
    --cluster-name=*)
      CLUSTER_NAME="${arg#*=}"
      shift
      ;;
    --aws-profile=*)
      AWS_PROFILE="${arg#*=}"
      shift
      ;;
    --yes)
      NON_INTERACTIVE=true
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
      echo "❌ Unknown argument: \"$arg\""
      show_usage
      ;;
  esac
done

echo "Deploying Storm Surge via deploy.sh"
echo "==================================="

# Provider configuration data (bash 3.2 compatible)
get_provider_config() {
  local provider=$1
  case $provider in
    "gke")
      echo 'regions:us-central1:Iowa:a,b,c,f|us-east1:South Carolina:b,c,d|us-west1:Oregon:a,b,c|us-west2:California:a,b,c|europe-west1:Belgium:b,c,d|asia-east1:Taiwan:a,b,c|cli_tool:gcloud'
      ;;
    "eks")
      echo 'regions:us-east-1:N. Virginia:a,b,c,d,e,f|us-east-2:Ohio:a,b,c|us-west-1:N. California:a,b,c|us-west-2:Oregon:a,b,c|eu-west-1:Ireland:a,b,c|ap-southeast-1:Singapore:a,b,c|cli_tool:aws'
      ;;
    "aks")
      echo 'regions:eastus:East US:1,2,3|westus2:West US 2:1,2,3|centralus:Central US:1,2,3|westeurope:West Europe:1,2,3|southeastasia:Southeast Asia:1,2,3|cli_tool:az'
      ;;
  esac
}

# Parse region data from config string
parse_regions() {
  local provider=$1
  local config
  config=$(get_provider_config "$provider")
  echo "$config" | grep -o 'regions:[^|]*' | sed 's/regions://' | tr '|' '\n' | cut -d':' -f1 | sort
}

# Parse zones for a specific region
parse_zones() {
  local provider=$1
  local region=$2
  local config
  config=$(get_provider_config "$provider")
  echo "$config" | grep -o 'regions:[^|]*' | sed 's/regions://' | tr '|' '\n' | grep "^$region:" | cut -d':' -f3 | tr ',' ' '
}

# Parse region name
parse_region_name() {
  local provider=$1
  local region=$2
  local config
  config=$(get_provider_config "$provider")
  echo "$config" | grep -o 'regions:[^|]*' | sed 's/regions://' | tr '|' '\n' | grep "^$region:" | cut -d':' -f2
}

# Get CLI tool for provider
get_cli_tool() {
  local provider=$1
  local config
  config=$(get_provider_config "$provider")
  echo "$config" | grep -o 'cli_tool:[^|]*' | cut -d':' -f2
}

# Get cluster name for provider (custom or default)
get_cluster_name_for_provider() {
  local provider=$1
  if [ -n "$CLUSTER_NAME" ]; then
    echo "$CLUSTER_NAME"
  else
    echo "storm-surge-$provider"
  fi
}

# Check if CLI tools are available
CLI_TOOLS_CHECKED=false
CLI_TOOLS_AVAILABLE=()
check_cli_tools() {
  if [ "$CLI_TOOLS_CHECKED" = "true" ]; then
    return 0
  fi

  for tool in gcloud aws az; do
    if command -v "$tool" &> /dev/null; then
      CLI_TOOLS_AVAILABLE+=("$tool")
    fi
  done
  CLI_TOOLS_CHECKED=true
}

# Check if specific CLI tool is available
is_cli_available() {
  local tool=$1
  check_cli_tools
  for available in "${CLI_TOOLS_AVAILABLE[@]}"; do
    if [ "$available" = "$tool" ]; then
      return 0
    fi
  done
  return 1
}

# Interactive provider selection
get_provider() {
  if [ "$NON_INTERACTIVE" = "true" ]; then
    PROVIDER="gke"
    echo "Non-interactive mode: Using default provider 'gke'"
    return
  fi

  while true; do
    echo "Available cloud providers:"
    echo "  1) gke  - Google Kubernetes Engine"
    echo "  2) eks  - Amazon Elastic Kubernetes Service"
    echo "  3) aks  - Azure Kubernetes Service"
    echo "  4) all  - Deploy to all providers"
    echo
    read -r -p "Select provider (1-4 or gke/eks/aks/all): " choice

    case $choice in
      1|gke) PROVIDER="gke"; break ;;
      2|eks) PROVIDER="eks"; break ;;
      3|aks) PROVIDER="aks"; break ;;
      4|all) PROVIDER="all"; break ;;
      *) echo "ERROR: Invalid choice. Please try again."; echo ;;
    esac
  done
}

# Interactive region selection based on provider
get_region() {
  local provider=$1

  if [ "$NON_INTERACTIVE" = "true" ]; then
    case $provider in
      "gke") REGION="us-central1" ;;
      "eks") REGION="us-east-1" ;;
      "aks") REGION="eastus" ;;
    esac
    echo "Non-interactive mode: Using default region '$REGION'"
    return
  fi

  local regions
  # shellcheck disable=SC2207
  regions=($(parse_regions "$provider"))
  local i=1

  echo "Available $provider regions:"
  for region in "${regions[@]}"; do
    local name
    name=$(parse_region_name "$provider" "$region")
    printf "  %d) %-15s (%s)\n" $i "$region" "$name"
    ((i++))
  done
  echo

  while true; do
    read -r -p "Select region (1-${#regions[@]} or enter region name): " choice

    # Check if it's a number
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#regions[@]}" ]; then
      REGION="${regions[$((choice-1))]}"
      break
    # Check if it's a valid region name
    elif printf '%s\n' "${regions[@]}" | grep -q "^$choice$"; then
      REGION="$choice"
      break
    else
      echo "ERROR: Invalid choice. Please try again."
      echo
    fi
  done
}

# Interactive zone selection with validation
get_zone() {
  local provider=$1
  local region=$2
  local zones
  # shellcheck disable=SC2207
  zones=($(parse_zones "$provider" "$region"))

  if [ "$NON_INTERACTIVE" = "true" ]; then
    if [ "$provider" = "eks" ]; then
      # For EKS, use at least 2 zones by default
      local default_zones=()
      for i in 0 1; do
        if [ $i -lt ${#zones[@]} ]; then
          default_zones+=("${region}${zones[$i]}")
        fi
      done
      ZONE="${default_zones[*]}"
      echo "Non-interactive mode: Using default zones '$ZONE'"
    else
      ZONE="${zones[0]}"
      if [ "$provider" = "gke" ]; then
        ZONE="${region}-${zones[0]}"
      fi
      echo "Non-interactive mode: Using default zone '$ZONE'"
    fi
    return
  fi

  case $provider in
    "gke")
      while true; do
        echo "Available zones in $region:"
        echo "  ${zones[*]}"
        echo
        read -r -p "Enter zone suffix (e.g., 'a' for ${region}-a): " zone_suffix
        ZONE="${region}-${zone_suffix}"

        # Validate zone exists in the zones array
        if printf '%s\n' "${zones[@]}" | grep -q "^$zone_suffix$"; then
          break
        else
          echo "ERROR: Invalid zone '$zone_suffix' for region '$region'. Please try again."
          echo
        fi
      done
      ;;
    "eks")
      echo "Available zones in $region:"
      echo "  ${zones[*]}"
      echo
      echo "WARN: EKS requires at least 2 availability zones for high availability"
      echo

      local selected_zones=()
      while true; do
        read -r -p "Enter zones separated by spaces (e.g., 'a b c' for ${region}a ${region}b ${region}c): " zone_input

        # Convert input to array
        # shellcheck disable=SC2206
        local input_zones=($zone_input)

        # Check if at least 2 zones were provided
        if [ ${#input_zones[@]} -lt 2 ]; then
          echo "ERROR: Please select at least 2 availability zones for EKS"
          echo
          continue
        fi

        # Validate all zones exist
        local all_valid=true
        selected_zones=()
        for z in "${input_zones[@]}"; do
          if printf '%s\n' "${zones[@]}" | grep -q "^$z$"; then
            selected_zones+=("${region}${z}")
          else
            echo "ERROR: Invalid zone '$z' for region '$region'"
            all_valid=false
            break
          fi
        done

        if [ "$all_valid" = "true" ]; then
          ZONE="${selected_zones[*]}"
          break
        else
          echo "Please try again."
          echo
        fi
      done
      ;;
    "aks")
      while true; do
        echo "Available zones in $region:"
        echo "  ${zones[*]}"
        echo
        read -r -p "Enter zone number (1-3): " zone_suffix
        ZONE="$zone_suffix"

        # Validate zone exists in the zones array
        if printf '%s\n' "${zones[@]}" | grep -q "^$zone_suffix$"; then
          break
        else
          echo "ERROR: Invalid zone '$zone_suffix' for region '$region'. Please try again."
          echo
        fi
      done
      ;;
  esac
}

# Interactive node count selection
get_node_count() {
  if [ "$NON_INTERACTIVE" = "true" ]; then
    NODES=4
    echo "Non-interactive mode: Using default node count '4'"
    return
  fi

  while true; do
    echo "Node configuration:"
    echo "  - Default: 4 nodes (recommended)"
    echo "  - Range: 1-10 nodes maximum"
    echo
    read -r -p "Enter number of nodes (1-10, or 'default' for 4): " node_input

    case $node_input in
      "default"|"Default"|"DEFAULT"|"")
        NODES=4
        break
        ;;
      [1-9]|10)
        NODES="$node_input"
        break
        ;;
      *)
        echo "ERROR: Invalid input. Please enter a number between 1-10 or 'default'."
        echo
        ;;
    esac
  done
}

# Interactive cluster name selection
get_cluster_name() {
  local provider=$1
  local default_name="storm-surge-$provider"

  if [ "$NON_INTERACTIVE" = "true" ]; then
    CLUSTER_NAME="$default_name"
    echo "Non-interactive mode: Using default cluster name '$CLUSTER_NAME'"
    return
  fi

  echo "Cluster naming:"
  echo "  - Default: $default_name"
  echo "  - Custom: Enter your preferred name (alphanumeric and hyphens only)"
  echo
  read -r -p "Enter cluster name (or press Enter for default): " name_input

  if [ -z "$name_input" ]; then
    CLUSTER_NAME="$default_name"
  else
    # Validate cluster name format
    if [[ "$name_input" =~ ^[a-zA-Z0-9-]+$ ]] && [[ ! "$name_input" =~ ^- ]] && [[ ! "$name_input" =~ -$ ]]; then
      CLUSTER_NAME="$name_input"
    else
      echo "ERROR: Invalid cluster name. Must contain only alphanumeric characters and hyphens, and cannot start or end with a hyphen."
      echo "Using default name: $default_name"
      CLUSTER_NAME="$default_name"
    fi
  fi

  echo "OK: Cluster name set to: $CLUSTER_NAME"
}

# Get AWS profile for EKS deployments
get_aws_profile() {
  # Check if AWS CLI is available
  if ! command -v aws &> /dev/null; then
    echo "WARN: AWS CLI not installed. Skipping profile selection."
    return
  fi

  # First check if we can already authenticate with current settings
  if [ -z "$AWS_PROFILE" ]; then
    if aws sts get-caller-identity &>/dev/null 2>&1; then
      echo "✅ AWS credentials are already configured"
      return
    fi
  else
    # Check if the provided profile works
    if AWS_PROFILE="$AWS_PROFILE" aws sts get-caller-identity &>/dev/null 2>&1; then
      echo "✅ Using AWS profile: $AWS_PROFILE"
      return
    else
      echo "❌ AWS profile '$AWS_PROFILE' is not valid or has expired credentials"
      AWS_PROFILE=""
    fi
  fi

  # No valid credentials found, check for available profiles
  local profiles
  # shellcheck disable=SC2207
  profiles=($(aws configure list-profiles 2>/dev/null || echo ""))

  if [ ${#profiles[@]} -eq 0 ]; then
    echo "❌ No AWS profiles found. Please run 'aws configure' to set up credentials."
    exit 1
  fi

  if [ "$NON_INTERACTIVE" = "true" ]; then
    echo "❌ Non-interactive mode: No valid AWS credentials available"
    echo "   Please specify --aws-profile=PROFILE or configure default credentials"
    exit 1
  fi

  echo "🔑 Select AWS profile for EKS deployment:"
  local i=1
  for profile in "${profiles[@]}"; do
    echo "  $i) $profile"
    ((i++))
  done
  echo

  while true; do
    read -r -p "Select profile (1-${#profiles[@]}): " choice

    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#profiles[@]}" ]; then
      AWS_PROFILE="${profiles[$((choice-1))]}"

      # Verify the selected profile works
      if AWS_PROFILE="$AWS_PROFILE" aws sts get-caller-identity &>/dev/null 2>&1; then
        echo "✅ Using AWS profile: $AWS_PROFILE"
        export AWS_PROFILE
        break
      else
        echo "❌ Profile '$AWS_PROFILE' has invalid or expired credentials"
        echo "   Please select another profile or fix the credentials"
        AWS_PROFILE=""
      fi
    else
      echo "❌ Invalid choice. Please try again."
    fi
  done
}

# Validate arguments
validate_arguments() {
  local errors=()

  if [ -n "$PROVIDER" ] && [ "$PROVIDER" != "gke" ] && [ "$PROVIDER" != "eks" ] && [ "$PROVIDER" != "aks" ] && [ "$PROVIDER" != "all" ]; then
    errors+=("Invalid provider: $PROVIDER. Must be gke, eks, aks, or all")
  fi

  if [ -n "$NODES" ] && { [ "$NODES" -lt 1 ] || [ "$NODES" -gt 10 ]; }; then
    errors+=("Invalid node count: $NODES. Must be between 1-10")
  fi

  if [ -n "$CLUSTER_NAME" ] && [[ ! "$CLUSTER_NAME" =~ ^[a-zA-Z0-9-]+$ ]]; then
    errors+=("Invalid cluster name: $CLUSTER_NAME. Must contain only alphanumeric characters and hyphens")
  fi

  if [ -n "$CLUSTER_NAME" ] && [[ "$CLUSTER_NAME" =~ ^- ]] || [[ "$CLUSTER_NAME" =~ -$ ]]; then
    errors+=("Invalid cluster name: $CLUSTER_NAME. Cannot start or end with a hyphen")
  fi

  if [ -n "$REGION" ] && [ -n "$PROVIDER" ] && [ "$PROVIDER" != "all" ]; then
    local valid_regions
    # shellcheck disable=SC2207
    valid_regions=($(parse_regions "$PROVIDER"))
    if ! printf '%s\n' "${valid_regions[@]}" | grep -q "^$REGION$"; then
      errors+=("Invalid region '$REGION' for provider '$PROVIDER'")
    fi
  fi

  if [ ${#errors[@]} -gt 0 ]; then
    echo "❌ Validation errors:"
    for error in "${errors[@]}"; do
      echo "  - $error"
    done
    exit 1
  fi
}

# Only validate if arguments were provided
if [ -n "$PROVIDER" ] || [ -n "$REGION" ] || [ -n "$ZONE" ] || [ -n "$NODES" ]; then
  validate_arguments
fi

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
  local cli_tool
  cli_tool=$(get_cli_tool "$provider")
  local cluster_name
  cluster_name=$(get_cluster_name_for_provider "$provider")

  if ! is_cli_available "$cli_tool"; then
    return 1
  fi

  case $provider in
    "gke")
      gcloud container clusters describe "$cluster_name" --zone="$zone" &>/dev/null
      ;;
    "eks")
      aws eks describe-cluster --name "$cluster_name" --region="$region" &>/dev/null
      ;;
    "aks")
      az aks show --resource-group "storm-surge-rg" --name "$cluster_name" &>/dev/null
      ;;
    *)
      return 1
      ;;
  esac
}

# Prompt user for action when cluster exists
handle_existing_cluster() {
  local provider=$1
  local cluster_name
  cluster_name=$(get_cluster_name_for_provider "$provider")

  if [ "$NON_INTERACTIVE" = "true" ]; then
    echo "🔍 Found existing $cluster_name cluster!"
    echo "🤖 Non-interactive mode: Using existing cluster"
    export STORM_SKIP_CLUSTER_CREATION="true"
    return 0
  fi

  echo "🔍 Found existing $cluster_name cluster!"
  echo
  echo "   What would you like to do?"
  echo "   1) Deploy workloads only (faster, uses existing cluster)"
  echo "   2) Delete and recreate cluster (slower, fresh start)"
  echo "   3) Cancel deployment"
  echo

  while true; do
    read -r -p "Select option (1-3): " choice
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
  local cluster_name
  cluster_name=$(get_cluster_name_for_provider "$provider")

  echo "🗑️  Deleting existing $cluster_name cluster..."
  case $provider in
    "gke")
      if gcloud container clusters delete "$cluster_name" --zone="$ZONE" --quiet; then
        echo "✅ GKE cluster deleted"
      else
        echo "❌ Failed to delete GKE cluster"
        exit 1
      fi
      ;;
    "eks")
      if eksctl delete cluster "$cluster_name" --region="$REGION"; then
        echo "✅ EKS cluster deleted"
      else
        echo "❌ Failed to delete EKS cluster"
        exit 1
      fi
      ;;
    "aks")
      if az aks delete --resource-group "storm-surge-rg" --name "$cluster_name" --yes; then
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

  if [ ! -f "$script" ]; then
    echo "❌ Deployment script for provider '$p' not found at: $script"
    exit 1
  fi

  local cli_tool
  cli_tool=$(get_cli_tool "$p")

  if ! is_cli_available "$cli_tool"; then
    echo "❌ CLI tool '$cli_tool' not found. Please install it first."
    case $cli_tool in
      "gcloud") echo "  Install: https://cloud.google.com/sdk/docs/install" ;;
      "aws") echo "  Install: https://aws.amazon.com/cli/" ;;
      "az") echo "  Install: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli" ;;
    esac
    exit 1
  fi

  echo "🚀 Running deployment script for $p..."
  echo "   Region: $REGION"
  if [ "$p" = "eks" ]; then
    echo "   Zones: $ZONE"
  else
    echo "   Zone: $ZONE"
  fi
  echo "   Nodes: $NODES"
  echo

  # Export variables for the provider script
  export STORM_REGION="$REGION"
  export STORM_ZONE="$ZONE"
  export STORM_NODES="$NODES"
  STORM_CLUSTER_NAME="$(get_cluster_name_for_provider "$p")"
  export STORM_CLUSTER_NAME

  # Export AWS profile if set
  if [ -n "$AWS_PROFILE" ]; then
    export AWS_PROFILE
  fi

  if ! bash "$script"; then
    echo "❌ Deployment failed for provider '$p'"
    exit 1
  fi

  echo "✅ Deployment completed successfully for provider '$p'"
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
      get_zone "$p" "$REGION"
    fi

    if [ -z "$NODES" ]; then
      get_node_count
    fi

    if [ -z "$CLUSTER_NAME" ]; then
      get_cluster_name $p
    fi

    # Get AWS profile for EKS
    if [ "$p" = "eks" ]; then
      get_aws_profile
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
    get_region "$PROVIDER"
  fi

  if [ -z "$ZONE" ]; then
    get_zone "$PROVIDER" "$REGION"
  fi

  if [ -z "$NODES" ]; then
    get_node_count
  fi

  if [ -z "$CLUSTER_NAME" ]; then
    get_cluster_name "$PROVIDER"
  fi

  # Get AWS profile for EKS
  if [ "$PROVIDER" = "eks" ]; then
    get_aws_profile
  fi

  # Check if cluster exists and handle accordingly
  if check_cluster_exists "$PROVIDER" "$REGION" "$ZONE"; then
    handle_existing_cluster "$PROVIDER"
  fi

  echo
  echo "🎯 Deployment Configuration:"
  echo "   Provider: $PROVIDER"
  echo "   Region: $REGION"
  if [ "$PROVIDER" = "eks" ]; then
    echo "   Zones: $ZONE"
  else
    echo "   Zone: $ZONE"
  fi
  echo "   Nodes: $NODES"
  echo "   Cluster Name: $(get_cluster_name_for_provider "$PROVIDER")"
  echo

  if [ "$NON_INTERACTIVE" = "true" ]; then
    echo "🤖 Non-interactive mode: Proceeding with deployment"
    run_provider "$PROVIDER"
  else
    read -r -p "Proceed with deployment? (y/N): " confirm
    case $confirm in
      [Yy]|[Yy][Ee][Ss])
        run_provider "$PROVIDER"
        ;;
      *)
        echo "❌ Deployment cancelled."
        exit 0
        ;;
    esac
  fi
fi

echo "✅ All deployments completed."
