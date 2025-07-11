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

echo "🚀 Deploying LaunchDarkly ↔ Spot Middleware..."
kubectl apply -k manifests/middleware/
echo "✅ Middleware deployed in 'oceansurge' namespace"
