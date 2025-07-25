#!/bin/bash
# Storm Surge Middleware Build Script
# Builds Docker image with the specified feature flag provider

set -e

# Default values
PROVIDER="launchdarkly"
IMAGE_NAME="storm-surge-middleware"
IMAGE_TAG="latest"
REGISTRY=""
PUSH=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -p|--provider)
      PROVIDER="$2"
      shift 2
      ;;
    -t|--tag)
      IMAGE_TAG="$2"
      shift 2
      ;;
    -n|--name)
      IMAGE_NAME="$2"
      shift 2
      ;;
    -r|--registry)
      REGISTRY="$2"
      shift 2
      ;;
    --push)
      PUSH=true
      shift
      ;;
    -h|--help)
      echo "Usage: $0 [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  -p, --provider    Feature flag provider (launchdarkly|statsig) [default: launchdarkly]"
      echo "  -t, --tag         Docker image tag [default: latest]"
      echo "  -n, --name        Docker image name [default: storm-surge-middleware]"
      echo "  -r, --registry    Docker registry prefix"
      echo "  --push            Push image to registry after build"
      echo "  -h, --help        Show this help message"
      echo ""
      echo "Examples:"
      echo "  $0 --provider statsig --tag v1.1.0"
      echo "  $0 --provider launchdarkly --registry myregistry.com --push"
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

# Construct full image name
FULL_IMAGE_NAME="$IMAGE_NAME:$IMAGE_TAG"
if [[ -n "$REGISTRY" ]]; then
  FULL_IMAGE_NAME="$REGISTRY/$FULL_IMAGE_NAME"
fi

echo "🌊 Storm Surge Middleware Build"
echo "================================"
echo "Provider: $PROVIDER"
echo "Image: $FULL_IMAGE_NAME"
echo "Push: $PUSH"
echo ""

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
  echo "❌ Error: Docker is not running"
  exit 1
fi

# Check if we're in the right directory
if [[ ! -f "manifests/middleware/Dockerfile" ]]; then
  echo "❌ Error: Please run this script from the storm-surge root directory"
  exit 1
fi

# Check if required files exist
REQUIRED_FILES=(
  "manifests/middleware/Dockerfile"
  "manifests/middleware/requirements.txt"
  "manifests/middleware/requirements-${PROVIDER}.txt"
  "manifests/middleware/main.py"
  "manifests/middleware/feature_flags.py"
)

for file in "${REQUIRED_FILES[@]}"; do
  if [[ ! -f "$file" ]]; then
    echo "❌ Error: Required file not found: $file"
    exit 1
  fi
done

echo "📦 Building Docker image..."
echo "   Context: manifests/middleware/"
echo "   Provider: $PROVIDER"

# Build the Docker image
docker build \
  --build-arg FEATURE_FLAG_PROVIDER="$PROVIDER" \
  --tag "$FULL_IMAGE_NAME" \
  --file manifests/middleware/Dockerfile \
  manifests/middleware/

if [[ $? -eq 0 ]]; then
  echo "✅ Docker image built successfully: $FULL_IMAGE_NAME"
else
  echo "❌ Docker build failed"
  exit 1
fi

# Push to registry if requested
if [[ "$PUSH" == true ]]; then
  if [[ -z "$REGISTRY" ]]; then
    echo "❌ Error: Cannot push without registry specified"
    exit 1
  fi
  
  echo "📤 Pushing image to registry..."
  docker push "$FULL_IMAGE_NAME"
  
  if [[ $? -eq 0 ]]; then
    echo "✅ Image pushed successfully: $FULL_IMAGE_NAME"
  else
    echo "❌ Push failed"
    exit 1
  fi
fi

echo ""
echo "🎉 Build completed successfully!"
echo ""
echo "Next steps:"
echo "1. Update your Kubernetes deployment to use: $FULL_IMAGE_NAME"
echo "2. Configure environment variables for $PROVIDER"
echo "3. Deploy: kubectl apply -k manifests/middleware/"
echo ""
echo "Environment variables needed:"
if [[ "$PROVIDER" == "launchdarkly" ]]; then
  echo "  - LAUNCHDARKLY_SDK_KEY"
elif [[ "$PROVIDER" == "statsig" ]]; then
  echo "  - STATSIG_SERVER_KEY"
fi
echo "  - SPOT_API_TOKEN"
echo "  - SPOT_CLUSTER_ID"
echo "  - WEBHOOK_SECRET (optional)"