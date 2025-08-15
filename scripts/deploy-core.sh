#!/bin/bash

# Storm Surge Core - Minimal Deployment Script
# Deploy only the core middleware with security hardening

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
NAMESPACE=${NAMESPACE:-storm-surge-prod}
TIMEOUT=${TIMEOUT:-300s}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    print_info "Checking prerequisites..."
    
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed"
        exit 1
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        print_error "No Kubernetes cluster connection"
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

# Deploy core components
deploy_core() {
    print_info "Deploying Storm Surge Core..."
    
    # Apply manifests using kustomize
    if command -v kustomize &> /dev/null; then
        print_info "Using kustomize to deploy..."
        kustomize build manifests/core | kubectl apply -f -
    else
        print_info "Deploying individual manifests..."
        kubectl apply -f manifests/core/namespace.yaml
        kubectl apply -f manifests/middleware/secrets-minimal.yaml
        kubectl apply -f manifests/middleware/configmap-minimal.yaml
        kubectl apply -f manifests/middleware/deployment-minimal.yaml
        kubectl apply -f manifests/middleware/service-minimal.yaml
        kubectl apply -f manifests/security/production-security-hardening.yaml
    fi
    
    print_success "Core components deployed"
}

# Wait for deployment
wait_for_deployment() {
    print_info "Waiting for deployment to be ready..."
    
    kubectl wait --for=condition=available --timeout=$TIMEOUT \
        deployment/storm-surge-middleware \
        --namespace=$NAMESPACE || {
        print_error "Deployment failed to become ready"
        kubectl describe deployment storm-surge-middleware -n $NAMESPACE
        exit 1
    }
    
    print_success "Deployment is ready"
}

# Get load balancer info
get_lb_info() {
    print_info "Getting load balancer information..."
    
    # Wait for external IP
    for i in {1..30}; do
        EXTERNAL_IP=$(kubectl get service storm-surge-lb \
            --namespace=$NAMESPACE \
            -o jsonpath='{.status.loadBalancer.ingress[0].ip}{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
        
        if [ -n "$EXTERNAL_IP" ]; then
            break
        fi
        
        echo -n "."
        sleep 10
    done
    echo
    
    if [ -n "$EXTERNAL_IP" ]; then
        print_success "Load balancer URL: http://$EXTERNAL_IP"
        print_info "Health check: http://$EXTERNAL_IP/health"
        print_info "API status: http://$EXTERNAL_IP/api/v1/status"
    else
        print_warning "Load balancer IP not yet available"
        print_info "Check with: kubectl get service storm-surge-lb -n $NAMESPACE"
    fi
}

# Main execution
main() {
    print_info "Storm Surge Core Deployment"
    echo
    
    check_prerequisites
    deploy_core
    wait_for_deployment
    get_lb_info
    
    echo
    print_success "Deployment complete!"
}

# Run main function
main "$@"