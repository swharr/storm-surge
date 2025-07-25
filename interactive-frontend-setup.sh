#!/bin/bash
# Storm Surge Interactive Frontend Setup Script
# Prompts for all necessary configuration values

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
print_header() {
    echo -e "${BLUE}🌊 $1${NC}"
    echo "=========================="
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check if we're in the right directory
if [[ ! -f "frontend/package.json" ]]; then
    print_error "Please run this script from the storm-surge root directory"
    exit 1
fi

print_header "Storm Surge Frontend Interactive Setup"
echo ""
echo "This script will help you configure your feature flag provider"
echo "for the Storm Surge frontend application."
echo ""

# Step 1: Choose provider
echo "Step 1: Choose your feature flag provider"
echo "----------------------------------------"
echo "1. LaunchDarkly"
echo "2. Statsig"
echo ""

while true; do
    read -p "Enter your choice (1 or 2): " provider_choice
    case $provider_choice in
        1)
            PROVIDER="launchdarkly"
            break
            ;;
        2)
            PROVIDER="statsig"
            break
            ;;
        *)
            print_error "Invalid choice. Please enter 1 or 2."
            ;;
    esac
done

print_success "Selected provider: $PROVIDER"
echo ""

# Step 2: Get provider-specific configuration
if [[ "$PROVIDER" == "launchdarkly" ]]; then
    echo "Step 2: LaunchDarkly Configuration"
    echo "----------------------------------"
    echo ""
    echo "You will need the following from your LaunchDarkly dashboard:"
    echo "1. Client-side ID (from Account Settings → Projects → Environments)"
    echo "2. Tracking ID (optional - for user tracking events)"
    echo ""
    
    # Get Client-side ID
    while true; do
        read -p "Enter your LaunchDarkly Client-side ID: " ld_client_id
        if [[ -n "$ld_client_id" && ! "$ld_client_id" =~ ^CHANGEME ]]; then
            break
        else
            print_error "Please enter a valid LaunchDarkly Client-side ID"
        fi
    done
    
    # Get Tracking ID (optional)
    echo ""
    echo "The tracking ID is used for user session tracking (optional)."
    echo "This is typically the same as your member ID in LaunchDarkly."
    read -p "Enter your LaunchDarkly Tracking ID (or press Enter to skip): " ld_tracking_id
    
    if [[ -z "$ld_tracking_id" ]]; then
        ld_tracking_id="CHANGEME_TRACKING_ID_123456789"
        print_warning "Tracking ID not provided. User tracking will be disabled."
    fi
    
elif [[ "$PROVIDER" == "statsig" ]]; then
    echo "Step 2: Statsig Configuration"
    echo "-----------------------------"
    echo ""
    echo "You will need your Client Key from the Statsig console:"
    echo "(Console → Settings → Keys & Environments → Client Key)"
    echo ""
    
    # Get Client Key
    while true; do
        read -p "Enter your Statsig Client Key: " statsig_client_key
        if [[ -n "$statsig_client_key" && ! "$statsig_client_key" =~ ^CHANGEME ]]; then
            break
        else
            print_error "Please enter a valid Statsig Client Key"
        fi
    done
fi

echo ""

# Step 3: Install dependencies
echo "Step 3: Install Dependencies"
echo "----------------------------"
read -p "Install npm dependencies? (y/n) [default: y]: " install_deps
install_deps=${install_deps:-y}

if [[ "$install_deps" =~ ^[Yy] ]]; then
    cd frontend
    print_success "Installing dependencies..."
    npm install
    if [[ $? -eq 0 ]]; then
        print_success "Dependencies installed successfully"
    else
        print_error "Failed to install dependencies"
        exit 1
    fi
    cd ..
fi

# Step 4: Create environment file
echo ""
echo "Step 4: Create Environment Configuration"
echo "---------------------------------------"

ENV_FILE="frontend/.env.local"

# Backup existing file
if [[ -f "$ENV_FILE" ]]; then
    BACKUP_FILE="${ENV_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$ENV_FILE" "$BACKUP_FILE"
    print_warning "Backed up existing .env.local to $(basename $BACKUP_FILE)"
fi

# Create new environment file
cat > "$ENV_FILE" << EOF
# Storm Surge Frontend Configuration
# Generated on $(date)

# Application Configuration
VITE_APP_VERSION=beta-v1.1.0
VITE_ENVIRONMENT=development

# API Configuration
VITE_API_BASE_URL=http://localhost:8000
VITE_WS_URL=ws://localhost:8000

# Feature Flag Configuration
VITE_FEATURE_FLAG_PROVIDER=$PROVIDER
EOF

# Add provider-specific configuration
if [[ "$PROVIDER" == "launchdarkly" ]]; then
    cat >> "$ENV_FILE" << EOF
VITE_LAUNCHDARKLY_CLIENT_ID=$ld_client_id
VITE_LAUNCHDARKLY_TRACKING_ID=$ld_tracking_id

# Statsig Configuration (not used)
# VITE_STATSIG_CLIENT_KEY=CHANGEME_STATSIG_CLIENT_KEY_123456789
EOF
elif [[ "$PROVIDER" == "statsig" ]]; then
    cat >> "$ENV_FILE" << EOF
VITE_STATSIG_CLIENT_KEY=$statsig_client_key

# LaunchDarkly Configuration (not used)
# VITE_LAUNCHDARKLY_CLIENT_ID=CHANGEME_LAUNCHDARKLY_CLIENT_ID_123456789
# VITE_LAUNCHDARKLY_TRACKING_ID=CHANGEME_TRACKING_ID_123456789
EOF
fi

# Add OpenTelemetry configuration
cat >> "$ENV_FILE" << EOF

# OpenTelemetry Configuration
VITE_OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4318/v1/traces
VITE_OTEL_ENABLE_OTLP=true
VITE_OTEL_ENABLE_CONSOLE=true
VITE_OTEL_AUTO_INIT=false
EOF

print_success "Created frontend/.env.local"

# Step 5: Provider setup instructions
echo ""
echo "Step 5: Provider Setup Instructions"
echo "-----------------------------------"

if [[ "$PROVIDER" == "launchdarkly" ]]; then
    echo "To complete your LaunchDarkly setup:"
    echo "1. Create a feature flag named 'enable-cost-optimizer' in your LaunchDarkly dashboard"
    echo "2. Set it as a boolean flag with appropriate targeting rules"
    echo "3. Configure webhooks pointing to your Storm Surge middleware:"
    echo "   - URL: https://your-domain.com/webhook/launchdarkly"
    echo "   - Events: Flag changes"
elif [[ "$PROVIDER" == "statsig" ]]; then
    echo "To complete your Statsig setup:"
    echo "1. Create a feature gate named 'enable_cost_optimizer' in your Statsig console"
    echo "2. Configure targeting rules as needed"
    echo "3. Configure webhooks pointing to your Storm Surge middleware:"
    echo "   - URL: https://your-domain.com/webhook/statsig"
    echo "   - Events: Gate config changes"
fi

echo ""

# Step 6: Verification
echo "Step 6: Verification"
echo "-------------------"
print_success "Setup completed successfully!"
echo ""
echo "Next steps:"
echo "1. Start the development server:"
echo "   cd frontend && npm run dev"
echo "2. Open http://localhost:3000 in your browser"
echo "3. Check the browser console for feature flag initialization messages"
echo "4. Look for these success indicators:"
echo "   - 'Feature flag client initialized'"
echo "   - No 'CHANGEME' warnings in console"
echo "   - Feature flags loading correctly"
echo ""

# Show configuration summary
echo "Configuration Summary:"
echo "====================="
echo "Provider: $PROVIDER"
if [[ "$PROVIDER" == "launchdarkly" ]]; then
    echo "Client ID: ${ld_client_id:0:20}..." 
    if [[ "$ld_tracking_id" != "CHANGEME_TRACKING_ID_123456789" ]]; then
        echo "Tracking ID: ${ld_tracking_id:0:20}..."
    else
        echo "Tracking ID: Not configured (tracking disabled)"
    fi
elif [[ "$PROVIDER" == "statsig" ]]; then
    echo "Client Key: ${statsig_client_key:0:20}..."
fi
echo "Environment file: frontend/.env.local"
echo ""

print_warning "Important Security Notes:"
echo "- Never commit .env.local to version control"
echo "- Keep your API keys secure and rotate them regularly"
echo "- Use different keys for development, staging, and production"
echo ""

echo "🎉 Happy feature flagging with Storm Surge!"