#!/bin/bash
set -e

# Get the script directory and go to project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Change to project root directory
cd "$PROJECT_ROOT"

# Verify we're in the right place
if [ ! -d "manifests/middleware" ]; then
    echo "❌ Error: manifests/middleware directory not found in $PROJECT_ROOT"
    echo "This script must be run from a storm-surge repository"
    exit 1
fi

# Check if running in non-interactive mode
NON_INTERACTIVE=${STORM_NON_INTERACTIVE:-false}

# Function to get required secrets
collect_secrets() {
    echo "🔐 Feature Flag Middleware Configuration"
    echo "========================================"
    echo
    echo "The middleware requires API keys/tokens to function properly."
    echo "You can skip any field by pressing Enter (will use empty default)."
    echo
    
    # LaunchDarkly SDK Key
    if [ "$NON_INTERACTIVE" = "true" ]; then
        LAUNCHDARKLY_SDK_KEY=${LAUNCHDARKLY_SDK_KEY:-""}
        echo "🤖 Non-interactive mode: Using LAUNCHDARKLY_SDK_KEY from environment"
    else
        echo "📱 LaunchDarkly Configuration:"
        echo "   SDK Key format: sdk-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
        read -r -s -p "   Enter LaunchDarkly SDK Key (or press Enter to skip): " LAUNCHDARKLY_SDK_KEY
        echo
    fi
    
    # Spot API Token
    if [ "$NON_INTERACTIVE" = "true" ]; then
        SPOT_API_TOKEN=${SPOT_API_TOKEN:-""}
        echo "🤖 Non-interactive mode: Using SPOT_API_TOKEN from environment"
    else
        echo "🌊 Spot.io Configuration:"
        echo "   Token format: Bearer act-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
        read -r -s -p "   Enter Spot API Token (or press Enter to skip): " SPOT_API_TOKEN
        echo
    fi
    
    # Webhook Secret
    if [ "$NON_INTERACTIVE" = "true" ]; then
        WEBHOOK_SECRET=${WEBHOOK_SECRET:-"webhook-secret-$(date +%s)"}
        echo "🤖 Non-interactive mode: Using WEBHOOK_SECRET from environment"
    else
        echo "🔒 Webhook Security:"
        echo "   A secret key for securing webhook communications"
        read -r -s -p "   Enter Webhook Secret (or press Enter for auto-generated): " WEBHOOK_SECRET
        if [ -z "$WEBHOOK_SECRET" ]; then
            WEBHOOK_SECRET="webhook-secret-$(date +%s)"
            echo "   Generated webhook secret: ${WEBHOOK_SECRET:0:20}..."
        fi
        echo
    fi
    
    # Statsig Server Key (optional)
    if [ "$NON_INTERACTIVE" = "true" ]; then
        STATSIG_SERVER_KEY=${STATSIG_SERVER_KEY:-""}
        echo "🤖 Non-interactive mode: Using STATSIG_SERVER_KEY from environment"
    else
        echo "📊 Statsig Configuration (Optional):"
        echo "   Only needed if using Statsig as feature flag provider"
        read -r -s -p "   Enter Statsig Server Key (or press Enter to skip): " STATSIG_SERVER_KEY
        echo
    fi
    
    echo "✅ Configuration collected"
    echo
}

# Create Kubernetes secret with collected values
create_secret() {
    echo "🔐 Creating Kubernetes secret..."
    
    kubectl create secret generic feature-flag-secrets \
        --namespace=oceansurge \
        --from-literal=ld-sdk-key="${LAUNCHDARKLY_SDK_KEY}" \
        --from-literal=statsig-server-key="${STATSIG_SERVER_KEY}" \
        --from-literal=spot-api-token="${SPOT_API_TOKEN}" \
        --from-literal=webhook-secret="${WEBHOOK_SECRET}" \
        --dry-run=client -o yaml | kubectl apply -f -
    
    echo "✅ Secret created/updated"
}

# Main deployment process
echo "🚀 Deploying LaunchDarkly ↔ Spot Middleware..."

# Collect secrets if not already set
collect_secrets

# Create the secret
create_secret

# Deploy the middleware
kubectl apply -k manifests/middleware/

echo "✅ Middleware deployed in 'oceansurge' namespace"
echo
echo "🔍 Check deployment status:"
echo "   kubectl get pods -n oceansurge -l app.kubernetes.io/component=middleware"
echo "   kubectl logs -n oceansurge -l app.kubernetes.io/component=middleware"
echo
echo "📋 Next Steps:"
echo "  • To reconfigure feature flags: ./scripts/configure-feature-flags.sh"
echo "  • To test configuration: ./scripts/configure-feature-flags.sh --test"
