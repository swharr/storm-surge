#!/bin/bash
set -e

IMAGE_NAME="storm-surge-frontend"
VERSION="${VERSION:-latest}"

echo "Building Storm Surge Frontend locally..."

# Build the Docker image locally
echo "Building Docker image: ${IMAGE_NAME}:${VERSION}"
docker build -t "${IMAGE_NAME}:${VERSION}" .

echo "✅ Local image built successfully!"
echo "Image: ${IMAGE_NAME}:${VERSION}"

# Load image into kind/minikube if available
if command -v kind &> /dev/null && kind get clusters &> /dev/null; then
    echo "Loading image into kind cluster..."
    kind load docker-image "${IMAGE_NAME}:${VERSION}"
    echo "✅ Image loaded into kind cluster"
elif command -v minikube &> /dev/null && minikube status &> /dev/null; then
    echo "Loading image into minikube..."
    minikube image load "${IMAGE_NAME}:${VERSION}"
    echo "✅ Image loaded into minikube"
else
    echo "ℹ️  No local Kubernetes cluster detected (kind/minikube)"
    echo "   If using a local cluster, manually load the image"
fi

# Update deployment to use local image
echo "Setting imagePullPolicy to Never for local development..."
sed -i.bak 's/imagePullPolicy: Always/imagePullPolicy: Never/' k8s/deployment.yaml
echo "✅ Updated deployment for local images"