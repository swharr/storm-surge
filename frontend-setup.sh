#!/bin/bash
# Storm Surge Frontend Setup Script
# Configures the React frontend with the appropriate feature flag provider

set -e

# Default values
PROVIDER="launchdarkly"
CLIENT_ID=""
TRACKING_ID=""
INSTALL_DEPS=true
CREATE_ENV=true

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -p|--provider)
      PROVIDER="$2"
      shift 2
      ;;
    -c|--client-id)
      CLIENT_ID="$2"
      shift 2
      ;;
    -t|--tracking-id)
      TRACKING_ID="$2"
      shift 2
      ;;
    --no-install)
      INSTALL_DEPS=false
      shift
      ;;
    --no-env)
      CREATE_ENV=false
      shift
      ;;
    -h|--help)
      echo "Usage: $0 [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  -p, --provider     Feature flag provider (launchdarkly|statsig) [default: launchdarkly]"
      echo "  -c, --client-id    Client ID/key for the provider"
      echo "  -t, --tracking-id  LaunchDarkly tracking ID (for LaunchDarkly provider only)"
      echo "  --no-install       Skip npm dependency installation"
      echo "  --no-env           Skip .env.local file creation"
      echo "  -h, --help         Show this help message"
      echo ""
      echo "Examples:"
      echo "  $0 --provider launchdarkly --client-id 64f4c8a07e15b70c9d123456 --tracking-id 686c039bd635a90948e06ed9"
      echo "  $0 --provider statsig --client-id client-abcdefghijklmnopqrstuvwxyz"
      exit 0
      ;;
    *)
      echo "Unknown option $1"
      exit 1
      ;;
  esac
done

# Validate provider
if [[ "$PROVIDER" != "launchdarkly" && "$PROVIDER" != "statsig" ]]; then
  echo "❌ Error: Provider must be 'launchdarkly' or 'statsig'"
  exit 1
fi

# Check if we're in the right directory
if [[ ! -f "frontend/package.json" ]]; then
  echo "❌ Error: Please run this script from the storm-surge root directory"
  exit 1
fi

echo "🌊 Storm Surge Frontend Setup"
echo "=============================="
echo "Provider: $PROVIDER"
echo "Client ID: ${CLIENT_ID:-(will use dummy value)}"
if [[ "$PROVIDER" == "launchdarkly" ]]; then
  echo "Tracking ID: ${TRACKING_ID:-(will use dummy value)}"
fi
echo "Install Dependencies: $INSTALL_DEPS"
echo "Create Environment: $CREATE_ENV"
echo ""

# Navigate to frontend directory
cd frontend

# Install dependencies if requested
if [[ "$INSTALL_DEPS" == true ]]; then
  echo "📦 Installing npm dependencies..."
  
  # Check if npm is available
  if ! command -v npm &> /dev/null; then
    echo "❌ Error: npm is not installed"
    exit 1
  fi
  
  npm install
  
  if [[ $? -eq 0 ]]; then
    echo "✅ Dependencies installed successfully"
  else
    echo "❌ Failed to install dependencies"
    exit 1
  fi
fi

# Create .env.local file if requested
if [[ "$CREATE_ENV" == true ]]; then
  echo "📝 Creating .env.local file..."
  
  ENV_FILE=".env.local"
  
  # Backup existing .env.local if it exists
  if [[ -f "$ENV_FILE" ]]; then
    BACKUP_FILE="${ENV_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$ENV_FILE" "$BACKUP_FILE"
    echo "   Backed up existing .env.local to $BACKUP_FILE"
  fi
  
  # Create new .env.local file
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
    if [[ -n "$CLIENT_ID" ]]; then
      echo "VITE_LAUNCHDARKLY_CLIENT_ID=$CLIENT_ID" >> "$ENV_FILE"
    else
      echo "VITE_LAUNCHDARKLY_CLIENT_ID=CHANGEME_LAUNCHDARKLY_CLIENT_ID_123456789" >> "$ENV_FILE"
    fi
    
    # Add tracking ID for LaunchDarkly
    if [[ -n "$TRACKING_ID" ]]; then
      echo "VITE_LAUNCHDARKLY_TRACKING_ID=$TRACKING_ID" >> "$ENV_FILE"
    else
      echo "VITE_LAUNCHDARKLY_TRACKING_ID=CHANGEME_TRACKING_ID_123456789" >> "$ENV_FILE"
    fi
    
    echo "" >> "$ENV_FILE"
    echo "# Statsig Configuration (not used)" >> "$ENV_FILE"
    echo "# VITE_STATSIG_CLIENT_KEY=CHANGEME_STATSIG_CLIENT_KEY_123456789" >> "$ENV_FILE"
  elif [[ "$PROVIDER" == "statsig" ]]; then
    if [[ -n "$CLIENT_ID" ]]; then
      echo "VITE_STATSIG_CLIENT_KEY=$CLIENT_ID" >> "$ENV_FILE"
    else
      echo "VITE_STATSIG_CLIENT_KEY=CHANGEME_STATSIG_CLIENT_KEY_123456789" >> "$ENV_FILE"
    fi
    echo "" >> "$ENV_FILE"
    echo "# LaunchDarkly Configuration (not used)" >> "$ENV_FILE"
    echo "# VITE_LAUNCHDARKLY_CLIENT_ID=CHANGEME_LAUNCHDARKLY_CLIENT_ID_123456789" >> "$ENV_FILE"
    echo "# VITE_LAUNCHDARKLY_TRACKING_ID=CHANGEME_TRACKING_ID_123456789" >> "$ENV_FILE"
  fi

  # Add OpenTelemetry configuration
  cat >> "$ENV_FILE" << EOF

# OpenTelemetry Configuration
VITE_OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4318/v1/traces
VITE_OTEL_ENABLE_OTLP=true
VITE_OTEL_ENABLE_CONSOLE=true
VITE_OTEL_AUTO_INIT=false
EOF

  echo "✅ Created $ENV_FILE"
fi

# Verify TypeScript compilation
echo "🔍 Verifying TypeScript configuration..."
if command -v npx &> /dev/null; then
  npx tsc --noEmit --skipLibCheck
  
  if [[ $? -eq 0 ]]; then
    echo "✅ TypeScript verification passed"
  else
    echo "⚠️  TypeScript verification failed (this may be due to missing dependencies)"
  fi
else
  echo "⚠️  npx not available, skipping TypeScript verification"
fi

echo ""
echo "🎉 Frontend setup completed!"
echo ""
echo "Next steps:"
echo "1. Update your .env.local file with the correct client ID/key"

if [[ "$PROVIDER" == "launchdarkly" ]]; then
  echo "   - Get your LaunchDarkly Client-side ID from:"
  echo "     https://app.launchdarkly.com → Account Settings → Projects → Environments"
  echo "   - Get your LaunchDarkly Tracking ID (optional, for user tracking)"
  echo "   - Create a feature flag named 'enable-cost-optimizer'"
elif [[ "$PROVIDER" == "statsig" ]]; then
  echo "   - Get your Statsig Client Key from:"
  echo "     https://console.statsig.com → Settings → Keys & Environments"
  echo "   - Create a feature gate named 'enable_cost_optimizer'"
fi

echo "2. Start the development server:"
echo "   cd frontend && npm run dev"
echo "3. Open http://localhost:3000 in your browser"
echo "4. Check the browser console for feature flag initialization messages"
echo ""

if [[ -z "$CLIENT_ID" || "$CLIENT_ID" == *"your-"* ]]; then
  echo "⚠️  Remember to update your client ID in .env.local before running the application!"
fi

echo "🔧 Environment variables that need to be set:"
if [[ "$PROVIDER" == "launchdarkly" ]]; then
  echo "   VITE_LAUNCHDARKLY_CLIENT_ID=your-actual-client-side-id"
  echo "   VITE_LAUNCHDARKLY_TRACKING_ID=your-actual-tracking-id (optional)"
elif [[ "$PROVIDER" == "statsig" ]]; then
  echo "   VITE_STATSIG_CLIENT_KEY=client-your-actual-client-key"
fi

echo ""
echo "💡 Pro tip: Use the interactive setup script for guided configuration:"
echo "   ./interactive-frontend-setup.sh"