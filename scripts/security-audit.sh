#!/bin/bash
set -e

# Comprehensive Security Audit Script for Storm Surge
# Validates security configurations and identifies potential vulnerabilities

echo "🔒 Storm Surge Security Audit"
echo "============================="
echo

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Counters
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNING_CHECKS=0

# Configuration
COMPREHENSIVE=${1:-false}
NAMESPACE=${STORM_NAMESPACE:-"oceansurge"}
MONITORING_NS=${MONITORING_NAMESPACE:-"monitoring"}

# Check function
security_check() {
    local test_name="$1"
    local command="$2"
    local expected_result="$3"
    local severity="${4:-medium}"
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    # Set color based on severity
    case $severity in
        critical) color=$RED; symbol="🚨" ;;
        high) color=$YELLOW; symbol="⚠️" ;;
        medium) color=$BLUE; symbol="ℹ️" ;;
        low) color=$NC; symbol="📝" ;;
    esac
    
    printf "%-60s " "$test_name"
    
    if eval "$command" &>/dev/null; then
        if [ "$expected_result" = "success" ]; then
            echo -e "${GREEN}✅ SECURE${NC}"
            PASSED_CHECKS=$((PASSED_CHECKS + 1))
        else
            echo -e "${color}${symbol} VULNERABLE${NC}"
            FAILED_CHECKS=$((FAILED_CHECKS + 1))
        fi
    else
        if [ "$expected_result" = "success" ]; then
            echo -e "${color}${symbol} VULNERABLE${NC}"
            FAILED_CHECKS=$((FAILED_CHECKS + 1))
        else
            echo -e "${GREEN}✅ SECURE${NC}"
            PASSED_CHECKS=$((PASSED_CHECKS + 1))
        fi
    fi
}

security_warning() {
    local test_name="$1"
    local command="$2"
    local message="$3"
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    printf "%-60s " "$test_name"
    
    if eval "$command" &>/dev/null; then
        echo -e "${GREEN}✅ SECURE${NC}"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        echo -e "${YELLOW}⚠️ WARNING${NC} - $message"
        WARNING_CHECKS=$((WARNING_CHECKS + 1))
    fi
}

# Information gathering
get_cluster_info() {
    echo -e "${PURPLE}📋 CLUSTER INFORMATION${NC}"
    echo "======================"
    
    if kubectl cluster-info &>/dev/null; then
        echo "Kubernetes Version: $(kubectl version --short --client 2>/dev/null | grep -o 'v[0-9]*\.[0-9]*\.[0-9]*' || echo 'Unknown')"
        echo "Cluster Endpoint: $(kubectl cluster-info | grep 'Kubernetes control plane' | grep -o 'https://[^[:space:]]*' || echo 'Unknown')"
        echo "Current Context: $(kubectl config current-context 2>/dev/null || echo 'Unknown')"
        echo "Available Namespaces: $(kubectl get namespaces --no-headers 2>/dev/null | wc -l || echo '0')"
    else
        echo "⚠️  No Kubernetes cluster connection available"
        echo "   Some security checks will be performed on local manifests only"
    fi
    echo
}

# Check for common vulnerabilities
check_container_security() {
    echo -e "${PURPLE}🔒 CONTAINER SECURITY${NC}"
    echo "===================="
    
    security_check "All pods run as non-root user" \
        "! kubectl get pods -n $NAMESPACE -o jsonpath='{.items[*].spec.securityContext.runAsUser}' 2>/dev/null | grep -q '^0$'" \
        "success" "critical"
    
    security_check "No privileged containers" \
        "! kubectl get pods -n $NAMESPACE -o jsonpath='{.items[*].spec.containers[*].securityContext.privileged}' 2>/dev/null | grep -q 'true'" \
        "success" "critical"
    
    security_check "Privilege escalation disabled" \
        "! kubectl get pods -n $NAMESPACE -o jsonpath='{.items[*].spec.containers[*].securityContext.allowPrivilegeEscalation}' 2>/dev/null | grep -q 'true'" \
        "success" "high"
    
    security_check "Read-only root filesystem (where applicable)" \
        "kubectl get deployment frontend -n $NAMESPACE -o jsonpath='{.spec.template.spec.containers[0].securityContext.readOnlyRootFilesystem}' 2>/dev/null | grep -q 'true'" \
        "success" "medium"
    
    security_check "Capabilities dropped" \
        "kubectl get pods -n $NAMESPACE -o jsonpath='{.items[*].spec.containers[*].securityContext.capabilities.drop}' 2>/dev/null | grep -q 'ALL'" \
        "success" "high"
    
    security_check "Resource limits configured" \
        "kubectl get pods -n $NAMESPACE -o jsonpath='{.items[*].spec.containers[*].resources.limits}' 2>/dev/null | grep -q 'cpu'" \
        "success" "medium"
    
    security_check "No latest tags in use" \
        "! kubectl get pods -n $NAMESPACE -o jsonpath='{.items[*].spec.containers[*].image}' 2>/dev/null | grep -q ':latest'" \
        "success" "medium"
    
    echo
}

check_network_security() {
    echo -e "${PURPLE}🌐 NETWORK SECURITY${NC}"
    echo "=================="
    
    security_check "Network policies deployed" \
        "kubectl get networkpolicy -n $NAMESPACE | grep -q deny-all-default" \
        "success" "high"
    
    security_check "Default deny-all policy exists" \
        "kubectl get networkpolicy deny-all-default -n $NAMESPACE &>/dev/null" \
        "success" "high"
    
    security_check "Frontend network policy configured" \
        "kubectl get networkpolicy allow-frontend-ingress -n $NAMESPACE &>/dev/null" \
        "success" "medium"
    
    security_check "Backend network policy configured" \
        "kubectl get networkpolicy allow-backend-communication -n $NAMESPACE &>/dev/null" \
        "success" "medium"
    
    security_check "LoadBalancer services use proper annotations" \
        "kubectl get service frontend-service -n $NAMESPACE -o jsonpath='{.metadata.annotations}' 2>/dev/null | grep -q 'load-balancer'" \
        "success" "low"
    
    # Check for insecure ports
    security_check "No insecure kubelet ports exposed" \
        "! kubectl get pods --all-namespaces -o yaml 2>/dev/null | grep -q '10255'" \
        "success" "critical"
    
    security_check "No insecure etcd ports exposed" \
        "! kubectl get pods --all-namespaces -o yaml 2>/dev/null | grep -E '2379|2380'" \
        "success" "critical"
    
    echo
}

check_rbac_security() {
    echo -e "${PURPLE}👤 RBAC & ACCESS CONTROL${NC}"
    echo "======================="
    
    security_check "Service accounts configured" \
        "kubectl get serviceaccount finops-controller -n $NAMESPACE &>/dev/null" \
        "success" "medium"
    
    security_check "Service account tokens not auto-mounted" \
        "kubectl get serviceaccount default -n $NAMESPACE -o jsonpath='{.automountServiceAccountToken}' 2>/dev/null | grep -q 'false'" \
        "success" "medium"
    
    security_check "RBAC cluster roles configured" \
        "kubectl get clusterrole finops-controller &>/dev/null" \
        "success" "medium"
    
    security_check "RBAC bindings follow least privilege" \
        "kubectl describe clusterrole finops-controller 2>/dev/null | grep -E 'get|list|watch' | wc -l | awk '{print \$1 > 0}'" \
        "success" "high"
    
    # Check for overly permissive roles
    security_check "No cluster-admin bindings to default SA" \
        "! kubectl get clusterrolebinding -o jsonpath='{.items[?(@.subjects[0].name==\"default\")].metadata.name}' 2>/dev/null | grep -q cluster-admin" \
        "success" "critical"
    
    security_check "No wildcard permissions in roles" \
        "! kubectl get clusterrole --all-namespaces -o yaml 2>/dev/null | grep -q 'resources: \\[\\\"\\*\\\"\\]'" \
        "success" "high"
    
    echo
}

check_secrets_security() {
    echo -e "${PURPLE}🔐 SECRETS MANAGEMENT${NC}"
    echo "==================="
    
    # Check for base64 encoded secrets (should be using external secrets)
    security_warning "External secrets integration" \
        "kubectl get externalsecret -n $NAMESPACE &>/dev/null" \
        "Consider using external secrets management"
    
    security_check "No plain text secrets in configmaps" \
        "! kubectl get configmap -n $NAMESPACE -o yaml 2>/dev/null | grep -E 'password:|secret:|key:' | grep -v '{{'" \
        "success" "critical"
    
    security_check "Secrets properly scoped to namespaces" \
        "kubectl get secrets -n $NAMESPACE --field-selector type!=kubernetes.io/service-account-token 2>/dev/null | grep -q ." \
        "success" "medium"
    
    # Check for hardcoded secrets in code
    if [ "$COMPREHENSIVE" = "--comprehensive" ]; then
        security_check "No hardcoded secrets in manifests" \
            "! find manifests/ -name '*.yaml' -exec grep -l 'password.*:.*[^{]' {} \\; 2>/dev/null | head -1" \
            "success" "critical"
        
        security_check "No API keys in plain text" \
            "! find . -name '*.py' -o -name '*.js' -o -name '*.yaml' | xargs grep -l 'api.*key.*=' 2>/dev/null | head -1" \
            "success" "critical"
    fi
    
    echo
}

check_image_security() {
    echo -e "${PURPLE}📦 CONTAINER IMAGE SECURITY${NC}"
    echo "========================="
    
    security_check "Using official/trusted images" \
        "kubectl get pods -n $NAMESPACE -o jsonpath='{.items[*].spec.containers[*].image}' 2>/dev/null | grep -E '(nginxinc|python|node)'" \
        "success" "medium"
    
    security_check "No root user in Dockerfiles" \
        "! find . -name 'Dockerfile*' -exec grep -l '^USER root' {} \\; 2>/dev/null | head -1" \
        "success" "high"
    
    security_check "Images use specific tags" \
        "! kubectl get pods -n $NAMESPACE -o jsonpath='{.items[*].spec.containers[*].image}' 2>/dev/null | grep -E ':(latest|master|\$)'" \
        "success" "medium"
    
    if command -v trivy &> /dev/null && [ "$COMPREHENSIVE" = "--comprehensive" ]; then
        echo "🔍 Running vulnerability scan with Trivy..."
        if trivy fs --security-checks vuln --severity HIGH,CRITICAL . --quiet; then
            echo -e "${GREEN}✅ No high/critical vulnerabilities found${NC}"
            PASSED_CHECKS=$((PASSED_CHECKS + 1))
        else
            echo -e "${RED}❌ Vulnerabilities detected${NC}"
            FAILED_CHECKS=$((FAILED_CHECKS + 1))
        fi
        TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    else
        security_warning "Vulnerability scanning" \
            "command -v trivy &> /dev/null" \
            "Install Trivy for vulnerability scanning"
    fi
    
    echo
}

check_monitoring_security() {
    echo -e "${PURPLE}📊 MONITORING & OBSERVABILITY${NC}"
    echo "============================"
    
    security_check "Security monitoring deployed" \
        "kubectl get pods -n $MONITORING_NS | grep -q prometheus" \
        "success" "medium"
    
    security_check "Audit logging configured" \
        "kubectl get events --field-selector type=Warning -n $NAMESPACE 2>/dev/null | head -1" \
        "success" "low"
    
    security_check "Metrics endpoints secured" \
        "kubectl get service prometheus-service -n $MONITORING_NS -o jsonpath='{.spec.type}' 2>/dev/null | grep -q 'ClusterIP'" \
        "success" "medium"
    
    security_warning "Alerting rules configured" \
        "kubectl get prometheusrule -n $MONITORING_NS &>/dev/null" \
        "Configure security alerting rules"
    
    echo
}

check_configuration_security() {
    echo -e "${PURPLE}⚙️ CONFIGURATION SECURITY${NC}"
    echo "======================="
    
    security_check "Resource quotas enforced" \
        "kubectl get resourcequota -n $NAMESPACE &>/dev/null" \
        "success" "low"
    
    security_check "Pod disruption budgets configured" \
        "kubectl get poddisruptionbudget -n $NAMESPACE &>/dev/null" \
        "success" "low"
    
    security_check "Security contexts in all deployments" \
        "kubectl get deployment -n $NAMESPACE -o jsonpath='{.items[*].spec.template.spec.securityContext.runAsNonRoot}' 2>/dev/null | grep -q 'true'" \
        "success" "high"
    
    security_check "No debug/development settings in production" \
        "! kubectl get configmap -n $NAMESPACE -o yaml 2>/dev/null | grep -i 'debug.*true'" \
        "success" "medium"
    
    if [ "$COMPREHENSIVE" = "--comprehensive" ]; then
        security_check "Kustomize security best practices" \
            "find manifests/ -name 'kustomization.yaml' -exec grep -l 'commonLabels\\|commonAnnotations' {} \\;" \
            "success" "low"
    fi
    
    echo
}

# Additional comprehensive checks
comprehensive_checks() {
    if [ "$COMPREHENSIVE" = "--comprehensive" ]; then
        echo -e "${PURPLE}🔍 COMPREHENSIVE SECURITY ANALYSIS${NC}"
        echo "================================"
        
        # Static analysis of YAML files
        echo "📋 Static Analysis Results:"
        
        # Check for sensitive patterns
        echo -n "  Checking for sensitive patterns... "
        if find . -name '*.yaml' -o -name '*.py' | xargs grep -l -E '(password|secret|key|token).*[:=].*[^{]' 2>/dev/null | grep -q .; then
            echo -e "${YELLOW}⚠️ Found potential sensitive data${NC}"
        else
            echo -e "${GREEN}✅ Clean${NC}"
        fi
        
        # Security policy validation
        echo -n "  Validating Kubernetes security policies... "
        if kubectl apply --dry-run=client -k manifests/base/ &>/dev/null; then
            echo -e "${GREEN}✅ Valid${NC}"
        else
            echo -e "${RED}❌ Issues found${NC}"
        fi
        
        # Check for insecure configurations
        echo -n "  Checking for insecure configurations... "
        insecure_count=$(grep -r -E '(allowPrivilegeEscalation.*true|privileged.*true|runAsUser.*0)' manifests/ 2>/dev/null | wc -l)
        if [ "$insecure_count" -eq 0 ]; then
            echo -e "${GREEN}✅ None found${NC}"
        else
            echo -e "${YELLOW}⚠️ Found $insecure_count potential issues${NC}"
        fi
        
        echo
    fi
}

# Security recommendations
provide_recommendations() {
    echo -e "${PURPLE}💡 SECURITY RECOMMENDATIONS${NC}"
    echo "=========================="
    
    if [ $FAILED_CHECKS -gt 0 ]; then
        echo -e "${RED}Critical Actions Required:${NC}"
        if ! kubectl get networkpolicy -n $NAMESPACE &>/dev/null; then
            echo "  • Deploy network policies: kubectl apply -f manifests/base/network-policies.yaml"
        fi
        if kubectl get pods -n $NAMESPACE -o jsonpath='{.items[*].spec.securityContext.runAsUser}' 2>/dev/null | grep -q '^0$'; then
            echo "  • Fix containers running as root - use enhanced deployments"
        fi
        if kubectl get pods --all-namespaces -o yaml 2>/dev/null | grep -q '10255'; then
            echo "  • Critical: Insecure kubelet port detected - run ./scripts/lockitdown.sh"
        fi
        echo
    fi
    
    echo -e "${YELLOW}Recommended Improvements:${NC}"
    echo "  • Enable external secrets management for production"
    echo "  • Configure security monitoring and alerting"
    echo "  • Implement automated vulnerability scanning"
    echo "  • Set up audit logging with centralized collection"
    echo "  • Regular security assessments and penetration testing"
    echo
    
    echo -e "${GREEN}Security Hardening Commands:${NC}"
    echo "  # Deploy enhanced security configurations"
    echo "  kubectl apply -k manifests/demo/"
    echo
    echo "  # Run security lockdown script"
    echo "  ./scripts/lockitdown.sh"
    echo
    echo "  # Validate all security configurations"
    echo "  ./tests/hooks/validate-security.sh"
    echo
}

# Results summary
show_summary() {
    echo -e "${PURPLE}📈 SECURITY AUDIT SUMMARY${NC}"
    echo "========================"
    echo -e "Total Security Checks: $TOTAL_CHECKS"
    echo -e "${GREEN}Secure: $PASSED_CHECKS${NC}"
    echo -e "${YELLOW}Warnings: $WARNING_CHECKS${NC}"
    echo -e "${RED}Vulnerable: $FAILED_CHECKS${NC}"
    echo
    
    # Calculate security score
    if [ $TOTAL_CHECKS -eq 0 ]; then
        SCORE=0
    else
        SCORE=$(( (PASSED_CHECKS * 100) / TOTAL_CHECKS ))
    fi
    
    echo -e "Security Score: $SCORE%"
    
    # Security rating
    if [ $SCORE -ge 95 ] && [ $FAILED_CHECKS -eq 0 ]; then
        echo -e "${GREEN}🏆 EXCELLENT SECURITY POSTURE${NC}"
    elif [ $SCORE -ge 85 ] && [ $FAILED_CHECKS -le 2 ]; then
        echo -e "${GREEN}✅ GOOD SECURITY POSTURE${NC}"
    elif [ $SCORE -ge 70 ]; then
        echo -e "${YELLOW}⚠️ MODERATE SECURITY - Improvements Needed${NC}"
    else
        echo -e "${RED}❌ POOR SECURITY - Immediate Action Required${NC}"
    fi
    echo
    
    # Exit code based on results
    if [ $FAILED_CHECKS -gt 5 ]; then
        echo -e "${RED}🚨 Too many security issues detected${NC}"
        exit 1
    elif [ $FAILED_CHECKS -gt 0 ]; then
        echo -e "${YELLOW}⚠️ Security issues require attention${NC}"
        exit 2
    else
        echo -e "${GREEN}✅ Security audit passed${NC}"
        exit 0
    fi
}

# Main execution
echo "🔐 Starting comprehensive security audit..."
echo "Namespace: $NAMESPACE"
echo "Comprehensive mode: $([ \"$COMPREHENSIVE\" = \"--comprehensive\" ] && echo 'Enabled' || echo 'Disabled')"
echo

get_cluster_info
check_container_security
check_network_security  
check_rbac_security
check_secrets_security
check_image_security
check_monitoring_security
check_configuration_security
comprehensive_checks
provide_recommendations
show_summary