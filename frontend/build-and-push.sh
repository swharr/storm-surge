#!/bin/bash
set -e

# Configuration
REGISTRY="${DOCKER_REGISTRY:-docker.io}"
NAMESPACE="${DOCKER_NAMESPACE:-stormsurge}"
IMAGE_NAME="storm-surge-frontend"
VERSION="${VERSION:-$(git rev-parse --short HEAD 2>/dev/null || echo 'latest')}"
FULL_IMAGE="${REGISTRY}/${NAMESPACE}/${IMAGE_NAME}:${VERSION}"
LATEST_IMAGE="${REGISTRY}/${NAMESPACE}/${IMAGE_NAME}:latest"

echo "Building Storm Surge Frontend Docker image..."
echo "Registry: ${REGISTRY}"
echo "Image: ${FULL_IMAGE}"

# Build the image
echo "Building Docker image..."
docker build -t "${FULL_IMAGE}" -t "${LATEST_IMAGE}" .

# Push to registry
echo "Pushing to registry..."
docker push "${FULL_IMAGE}"
docker push "${LATEST_IMAGE}"

echo "✅ Image pushed successfully!"
echo "To deploy, update your Kubernetes manifests with:"
echo "  image: ${FULL_IMAGE}"

# Update kustomization.yaml with new image
if [ -f "k8s/kustomization.yaml" ]; then
    echo "Updating kustomization.yaml with new image tag..."
    sed -i.bak "s|newTag: .*|newTag: ${VERSION}|" k8s/kustomization.yaml
    echo "✅ Updated kustomization.yaml"
fi
