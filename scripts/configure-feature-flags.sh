#!/bin/bash
set -e

# Get the script directory and go to project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Change to project root directory
cd "$PROJECT_ROOT"

show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Configure feature flag provider integration for Storm Surge middleware"
    echo
    echo "OPTIONS:"
    echo "  --provider=PROVIDER       Feature flag provider (launchdarkly|statsig|both)"
    echo "  --ld-sdk-key=KEY         LaunchDarkly SDK key"
    echo "  --statsig-key=KEY        Statsig server key"
    echo "  --spot-token=TOKEN       Spot.io API token"
    echo "  --webhook-secret=SECRET  Webhook security secret"
    echo "  --test                   Test the configuration after setup"
    echo "  --yes                    Skip confirmation prompts"
    echo "  --help, -h               Show this help message"
    echo
    echo "EXAMPLES:"
    echo "  # Interactive configuration"
    echo "  $0"
    echo
    echo "  # Configure LaunchDarkly only"
    echo "  $0 --provider=launchdarkly --ld-sdk-key=sdk-xxx --spot-token=Bearer-xxx"
    echo
    echo "  # Configure both providers"
    echo "  $0 --provider=both --ld-sdk-key=sdk-xxx --statsig-key=secret-xxx"
    echo
    echo "  # Test existing configuration"
    echo "  $0 --test"
    echo
    exit 0
}

# Parse command line arguments
PROVIDER=""
LAUNCHDARKLY_SDK_KEY=""
STATSIG_SERVER_KEY=""
SPOT_API_TOKEN=""
WEBHOOK_SECRET=""
TEST_CONFIG=false
SKIP_CONFIRMATION=false

for arg in "$@"; do
    case $arg in
        --provider=*)
            PROVIDER="${arg#*=}"
            shift
            ;;
        --ld-sdk-key=*)
            LAUNCHDARKLY_SDK_KEY="${arg#*=}"
            shift
            ;;
        --statsig-key=*)
            STATSIG_SERVER_KEY="${arg#*=}"
            shift
            ;;
        --spot-token=*)
            SPOT_API_TOKEN="${arg#*=}"
            shift
            ;;
        --webhook-secret=*)
            WEBHOOK_SECRET="${arg#*=}"
            shift
            ;;
        --test)
            TEST_CONFIG=true
            shift
            ;;
        --yes)
            SKIP_CONFIRMATION=true
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

# Verify we're in the right place
if [ ! -d "manifests/middleware" ]; then
    echo "❌ Error: manifests/middleware directory not found in $PROJECT_ROOT"
    echo "This script must be run from a storm-surge repository"
    exit 1
fi

# Check if kubectl is available and cluster is accessible
check_kubernetes() {
    if ! command -v kubectl &> /dev/null; then
        echo "❌ kubectl not found. Please install kubectl first."
        exit 1
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        echo "❌ Cannot connect to Kubernetes cluster. Please ensure kubectl is configured."
        exit 1
    fi
    
    # Check if oceansurge namespace exists
    if ! kubectl get namespace oceansurge &> /dev/null; then
        echo "❌ oceansurge namespace not found. Please deploy the base application first."
        echo "   Run: kubectl apply -k manifests/base/"
        exit 1
    fi
}

# Validate provider selection
validate_provider() {
    local provider=$1
    case $provider in
        "launchdarkly"|"statsig"|"both")
            return 0
            ;;
        *)
            echo "❌ Invalid provider: $provider. Must be 'launchdarkly', 'statsig', or 'both'"
            return 1
            ;;
    esac
}

# Interactive provider selection
select_provider() {
    if [ -n "$PROVIDER" ]; then
        if validate_provider "$PROVIDER"; then
            return 0
        else
            exit 1
        fi
    fi
    
    echo "📋 Select feature flag provider:"
    echo "  1) LaunchDarkly only"
    echo "  2) Statsig only"
    echo "  3) Both LaunchDarkly and Statsig"
    echo
    
    while true; do
        read -r -p "Select provider (1-3): " choice
        case $choice in
            1) PROVIDER="launchdarkly"; break ;;
            2) PROVIDER="statsig"; break ;;
            3) PROVIDER="both"; break ;;
            *) echo "❌ Invalid choice. Please enter 1, 2, or 3." ;;
        esac
    done
}

# Collect configuration interactively
collect_configuration() {
    echo "🔐 Feature Flag Provider Configuration"
    echo "====================================="
    echo
    
    # LaunchDarkly configuration
    if [ "$PROVIDER" = "launchdarkly" ] || [ "$PROVIDER" = "both" ]; then
        if [ -z "$LAUNCHDARKLY_SDK_KEY" ]; then
            echo "📱 LaunchDarkly Configuration:"
            echo "   SDK Key format: sdk-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
            echo "   Find your SDK key at: https://app.launchdarkly.com/settings/projects"
            echo
            while true; do
                read -r -s -p "   Enter LaunchDarkly SDK Key: " LAUNCHDARKLY_SDK_KEY
                echo
                if [ -n "$LAUNCHDARKLY_SDK_KEY" ]; then
                    break
                else
                    echo "   ❌ SDK Key cannot be empty for LaunchDarkly"
                fi
            done
        fi
    fi
    
    # Statsig configuration
    if [ "$PROVIDER" = "statsig" ] || [ "$PROVIDER" = "both" ]; then
        if [ -z "$STATSIG_SERVER_KEY" ]; then
            echo "📊 Statsig Configuration:"
            echo "   Server Secret Key format: secret-xxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
            echo "   Find your server key at: https://console.statsig.com/api_keys"
            echo
            while true; do
                read -r -s -p "   Enter Statsig Server Key: " STATSIG_SERVER_KEY
                echo
                if [ -n "$STATSIG_SERVER_KEY" ]; then
                    break
                else
                    echo "   ❌ Server Key cannot be empty for Statsig"
                fi
            done
        fi
    fi
    
    # Spot API Token
    if [ -z "$SPOT_API_TOKEN" ]; then
        echo "🌊 Spot.io Configuration:"
        echo "   API Token format: Bearer act-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
        echo "   Find your token at: https://console.spotinst.com/settings/tokens"
        echo
        read -r -s -p "   Enter Spot API Token (or press Enter to skip): " SPOT_API_TOKEN
        echo
    fi
    
    # Webhook Secret
    if [ -z "$WEBHOOK_SECRET" ]; then
        echo "🔒 Webhook Security:"
        echo "   A secret key for securing webhook communications"
        echo
        read -r -s -p "   Enter Webhook Secret (or press Enter for auto-generated): " WEBHOOK_SECRET
        if [ -z "$WEBHOOK_SECRET" ]; then
            WEBHOOK_SECRET="webhook-secret-$(date +%s)-$(openssl rand -hex 8)"
            echo "   Generated webhook secret"
        fi
        echo
    fi
}

# Display configuration summary
show_configuration_summary() {
    echo "📋 Configuration Summary:"
    echo "========================"
    echo "   Provider: $PROVIDER"
    
    if [ "$PROVIDER" = "launchdarkly" ] || [ "$PROVIDER" = "both" ]; then
        if [ -n "$LAUNCHDARKLY_SDK_KEY" ]; then
            echo "   LaunchDarkly SDK Key: ${LAUNCHDARKLY_SDK_KEY:0:20}...${LAUNCHDARKLY_SDK_KEY: -4}"
        else
            echo "   LaunchDarkly SDK Key: (not provided)"
        fi
    fi
    
    if [ "$PROVIDER" = "statsig" ] || [ "$PROVIDER" = "both" ]; then
        if [ -n "$STATSIG_SERVER_KEY" ]; then
            echo "   Statsig Server Key: ${STATSIG_SERVER_KEY:0:20}...${STATSIG_SERVER_KEY: -4}"
        else
            echo "   Statsig Server Key: (not provided)"
        fi
    fi
    
    if [ -n "$SPOT_API_TOKEN" ]; then
        echo "   Spot API Token: ${SPOT_API_TOKEN:0:20}...${SPOT_API_TOKEN: -4}"
    else
        echo "   Spot API Token: (not provided)"
    fi
    
    if [ -n "$WEBHOOK_SECRET" ]; then
        echo "   Webhook Secret: ${WEBHOOK_SECRET:0:20}..."
    else
        echo "   Webhook Secret: (not provided)"
    fi
    echo
}

# Update configuration in Kubernetes
update_kubernetes_config() {
    echo "🔧 Updating Kubernetes configuration..."
    
    # Update the feature flag provider in configmap
    kubectl patch configmap feature-flag-config -n oceansurge --type='merge' -p="{\"data\":{\"FEATURE_FLAG_PROVIDER\":\"$PROVIDER\"}}"
    
    # Create or update the secrets
    kubectl create secret generic feature-flag-secrets \
        --namespace=oceansurge \
        --from-literal=ld-sdk-key="${LAUNCHDARKLY_SDK_KEY}" \
        --from-literal=statsig-server-key="${STATSIG_SERVER_KEY}" \
        --from-literal=spot-api-token="${SPOT_API_TOKEN}" \
        --from-literal=webhook-secret="${WEBHOOK_SECRET}" \
        --dry-run=client -o yaml | kubectl apply -f -
    
    echo "✅ Configuration updated in Kubernetes"
}

# Restart middleware deployment
restart_middleware() {
    echo "🔄 Restarting middleware deployment..."
    
    if kubectl get deployment feature-flag-middleware -n oceansurge &> /dev/null; then
        kubectl rollout restart deployment/feature-flag-middleware -n oceansurge
        echo "⏳ Waiting for deployment to be ready..."
        kubectl rollout status deployment/feature-flag-middleware -n oceansurge --timeout=120s
        echo "✅ Middleware deployment restarted successfully"
    else
        echo "⚠️  Middleware deployment not found. You may need to deploy it first:"
        echo "   Run: ./scripts/deploy-middleware.sh"
    fi
}

# Test the configuration
test_configuration() {
    echo "🧪 Testing configuration..."
    
    # Check if middleware pod is running
    if ! kubectl get pods -n oceansurge -l app=feature-flag-middleware --field-selector=status.phase=Running &> /dev/null; then
        echo "❌ Middleware pod is not running"
        return 1
    fi
    
    # Get pod name
    POD_NAME=$(kubectl get pods -n oceansurge -l app=feature-flag-middleware --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}')
    
    if [ -z "$POD_NAME" ]; then
        echo "❌ No running middleware pod found"
        return 1
    fi
    
    echo "📋 Pod Status:"
    kubectl get pod "$POD_NAME" -n oceansurge
    echo
    
    echo "📊 Recent Logs:"
    kubectl logs "$POD_NAME" -n oceansurge --tail=10
    echo
    
    # Test health endpoint
    echo "🏥 Testing health endpoint..."
    
    # Check if the health endpoint is responding via readiness probe status
    READY_STATUS=$(kubectl get pod "$POD_NAME" -n oceansurge -o jsonpath='{.status.containerStatuses[?(@.name=="middleware")].ready}')
    
    if [ "$READY_STATUS" = "true" ]; then
        echo "✅ Health check passed (readiness probe successful)"
        HEALTH_OK=true
    else
        echo "❌ Health check failed (readiness probe failing)"
        HEALTH_OK=false
        
        # Show more details about the pod
        echo "📋 Pod conditions:"
        kubectl get pod "$POD_NAME" -n oceansurge -o jsonpath='{.status.conditions[*].type}: {.status.conditions[*].status}' | tr ' ' '\n'
    fi
    
    # Show service information
    echo "🌐 Service Information:"
    kubectl get svc feature-flag-middleware -n oceansurge
    
    # Get external URL if available
    EXTERNAL_IP=$(kubectl get svc feature-flag-middleware -n oceansurge -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
    if [ -n "$EXTERNAL_IP" ]; then
        echo
        echo "🔗 External Access URLs:"
        echo "   Health: http://$EXTERNAL_IP/health"
        echo "   Webhook: http://$EXTERNAL_IP/webhook/$PROVIDER"
        echo "   API: http://$EXTERNAL_IP/api/cluster/status"
    fi
    
    echo
    echo "✅ Configuration test completed successfully"
}

# Main execution
main() {
    echo "🚀 Storm Surge Feature Flag Configuration"
    echo "========================================="
    echo
    
    # Check prerequisites
    check_kubernetes
    
    # Handle test-only mode
    if [ "$TEST_CONFIG" = "true" ]; then
        test_configuration
        exit 0
    fi
    
    # Select provider
    select_provider
    
    # Collect configuration
    collect_configuration
    
    # Show summary
    show_configuration_summary
    
    # Confirm before applying
    if [ "$SKIP_CONFIRMATION" = "false" ]; then
        read -r -p "Apply this configuration? (y/N): " confirm
        case $confirm in
            [Yy]|[Yy][Ee][Ss])
                echo "Proceeding with configuration..."
                ;;
            *)
                echo "❌ Configuration cancelled"
                exit 0
                ;;
        esac
    fi
    
    # Apply configuration
    update_kubernetes_config
    restart_middleware
    
    echo
    echo "✅ Feature flag integration configured successfully!"
    echo
    echo "🔍 Next Steps:"
    echo "  1. Test the configuration: $0 --test"
    echo "  2. Configure webhooks in your feature flag provider"
    echo "  3. Monitor logs: kubectl logs -n oceansurge -l app=feature-flag-middleware -f"
    echo
    
    if [ -n "$EXTERNAL_IP" ]; then
        echo "📋 Webhook Configuration:"
        case $PROVIDER in
            "launchdarkly")
                echo "   LaunchDarkly webhook URL: http://$EXTERNAL_IP/webhook/launchdarkly"
                ;;
            "statsig")
                echo "   Statsig webhook URL: http://$EXTERNAL_IP/webhook/statsig"
                ;;
            "both")
                echo "   LaunchDarkly webhook URL: http://$EXTERNAL_IP/webhook/launchdarkly"
                echo "   Statsig webhook URL: http://$EXTERNAL_IP/webhook/statsig"
                ;;
        esac
    fi
}

# Run main function
main "$@"