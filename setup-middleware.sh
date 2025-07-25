#!/bin/bash

# Storm Surge Middleware Setup Script
# Configures feature flag providers and dependencies

set -e

# Colors for output
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Default values
PROVIDER=${1:-launchdarkly}
SDK_KEY=${2:-"CHANGEME_SDK_KEY_123456789"}
WEBHOOK_SECRET=${3:-"CHANGEME_WEBHOOK_SECRET_123456789"}

echo -e "${BLUE}🌊 Storm Surge Middleware Setup${NC}"
echo "================================"
echo

# Validate provider
if [[ "$PROVIDER" != "launchdarkly" && "$PROVIDER" != "statsig" ]]; then
    echo -e "${RED}❌ Invalid provider: $PROVIDER${NC}"
    echo "Usage: $0 [launchdarkly|statsig] [sdk_key] [webhook_secret]"
    exit 1
fi

echo -e "${GREEN}✅ Selected provider: $PROVIDER${NC}"

# Navigate to middleware directory
cd manifests/middleware

# Install base dependencies
echo
echo "Installing base dependencies..."
pip install -r requirements.txt

# Install provider-specific dependencies
echo
echo "Installing $PROVIDER dependencies..."
if [ "$PROVIDER" = "launchdarkly" ]; then
    pip install -r requirements-launchdarkly.txt
else
    pip install -r requirements-statsig.txt
fi

# Create local configuration
echo
echo "Creating local configuration..."
cat > .env.local << EOF
# Storm Surge Middleware Configuration
# Generated on $(date)

# Feature Flag Provider
FEATURE_FLAG_PROVIDER=$PROVIDER

# Provider SDK Configuration
EOF

if [ "$PROVIDER" = "launchdarkly" ]; then
    cat >> .env.local << EOF
LAUNCHDARKLY_SDK_KEY=$SDK_KEY
LAUNCHDARKLY_WEBHOOK_SECRET=$WEBHOOK_SECRET
EOF
else
    cat >> .env.local << EOF
STATSIG_SERVER_SECRET_KEY=$SDK_KEY
STATSIG_WEBHOOK_SECRET=$WEBHOOK_SECRET
EOF
fi

# Verify SDK installation
echo
echo "Verifying SDK installation..."
python3 -c "
import sys
provider = '$PROVIDER'
try:
    if provider == 'launchdarkly':
        import ldclient
        print('✅ LaunchDarkly SDK installed successfully')
    else:
        import statsig
        print('✅ Statsig SDK installed successfully')
except ImportError as e:
    print(f'❌ Failed to import {provider} SDK: {e}')
    sys.exit(1)
"

# Test feature flag module
echo
echo "Testing feature flag module..."
python3 -c "
import os
os.environ['FEATURE_FLAG_PROVIDER'] = '$PROVIDER'
os.environ['${PROVIDER^^}_SDK_KEY'] = '$SDK_KEY'
try:
    from feature_flags import FeatureFlagProvider
    print('✅ Feature flag module imported successfully')
except Exception as e:
    print(f'❌ Failed to import feature flag module: {e}')
"

echo
echo -e "${GREEN}✅ Middleware setup completed!${NC}"
echo
echo "Next steps:"
echo "1. Update your Kubernetes secret with real values:"
echo "   kubectl create secret generic storm-surge-feature-flags \\"
echo "     --from-literal=provider=$PROVIDER \\"
echo "     --from-literal=${PROVIDER}_sdk_key=YOUR_REAL_SDK_KEY \\"
echo "     --from-literal=${PROVIDER}_webhook_secret=YOUR_REAL_WEBHOOK_SECRET"
echo
echo "2. Build and deploy the middleware:"
echo "   ./build-middleware.sh $PROVIDER"
echo "   kubectl apply -k manifests/middleware"
echo
if [[ "$SDK_KEY" == *"CHANGEME"* ]]; then
    echo -e "${YELLOW}⚠️  Warning: Using dummy SDK key. Replace with real key before deployment.${NC}"
fi