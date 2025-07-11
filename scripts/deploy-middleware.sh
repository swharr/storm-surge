#!/bin/bash
set -e

echo "🚀 Deploying LaunchDarkly ↔ Spot Middleware..."
kubectl apply -k manifests/middleware/
echo "✅ Middleware deployed in 'oceansurge' namespace"
