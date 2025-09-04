#!/bin/bash
set -e

# Conference Demo Validation Script
# Validates well-architected framework compliance and demo readiness

echo "🎯 Storm Surge Conference Demo Validation"
echo "=========================================="
echo

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNING_CHECKS=0

# Check function
check_status() {
    local test_name="$1"
    local command="$2"
    local expected_result="$3"
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    printf "%-50s " "$test_name"
    
    if eval "$command" &>/dev/null; then
        if [ "$expected_result" = "success" ]; then
            echo -e "${GREEN}✅ PASS${NC}"
            PASSED_CHECKS=$((PASSED_CHECKS + 1))
        else
            echo -e "${RED}❌ FAIL${NC}"
            FAILED_CHECKS=$((FAILED_CHECKS + 1))
        fi
    else
        if [ "$expected_result" = "success" ]; then
            echo -e "${RED}❌ FAIL${NC}"
            FAILED_CHECKS=$((FAILED_CHECKS + 1))
        else
            echo -e "${GREEN}✅ PASS${NC}"
            PASSED_CHECKS=$((PASSED_CHECKS + 1))
        fi
    fi
}

check_warning() {
    local test_name="$1"
    local command="$2"
    local message="$3"
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    printf "%-50s " "$test_name"
    
    if eval "$command" &>/dev/null; then
        echo -e "${GREEN}✅ PASS${NC}"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        echo -e "${YELLOW}⚠️ WARN${NC} - $message"
        WARNING_CHECKS=$((WARNING_CHECKS + 1))
    fi
}

echo "🔍 1. CLUSTER CONNECTIVITY & BASICS"
echo "--------------------------------"

check_status "Kubernetes cluster accessible" "kubectl cluster-info" "success"
check_status "oceansurge namespace exists" "kubectl get namespace oceansurge" "success"
check_status "monitoring namespace exists" "kubectl get namespace monitoring" "success"

echo
echo "🏗️  2. WORKLOAD DEPLOYMENT STATUS"
echo "--------------------------------"

check_status "Frontend deployment ready" "kubectl get deployment frontend -n oceansurge -o jsonpath='{.status.readyReplicas}' | grep -q '[1-9]'" "success"
check_status "Product catalog deployment ready" "kubectl get deployment product-catalog -n oceansurge -o jsonpath='{.status.readyReplicas}' | grep -q '[1-9]'" "success"
check_status "Shopping cart deployment ready" "kubectl get deployment shopping-cart -n oceansurge -o jsonpath='{.status.readyReplicas}' | grep -q '[1-9]'" "success"
check_status "FinOps controller deployment ready" "kubectl get deployment finops-controller -n oceansurge -o jsonpath='{.status.readyReplicas}' | grep -q '[1-9]'" "success"

echo
echo "🌐 3. SERVICE & NETWORKING"
echo "------------------------"

check_status "Frontend service exists" "kubectl get service frontend-service -n oceansurge" "success"
check_status "LoadBalancer service configured" "kubectl get service frontend-service -n oceansurge -o jsonpath='{.spec.type}' | grep -q 'LoadBalancer'" "success"
check_warning "LoadBalancer external IP assigned" "kubectl get service frontend-service -n oceansurge -o jsonpath='{.status.loadBalancer.ingress[0].ip}' | grep -v '^$'" "May take 2-3 minutes for cloud provider"

echo
echo "📊 4. HORIZONTAL POD AUTOSCALERS"
echo "-------------------------------"

check_status "Shopping cart HPA exists" "kubectl get hpa shopping-cart-hpa -n oceansurge" "success"
check_status "Frontend HPA exists" "kubectl get hpa frontend-hpa -n oceansurge" "success"
check_status "Product catalog HPA exists" "kubectl get hpa product-catalog-hpa -n oceansurge" "success"
check_status "HPA metrics available" "kubectl top pods -n oceansurge | grep -q CPU" "success"

echo
echo "🔒 5. SECURITY CONTROLS"
echo "---------------------"

check_status "Network policies deployed" "kubectl get networkpolicy -n oceansurge | grep -q deny-all-default" "success"
check_status "Pod disruption budgets exist" "kubectl get pdb -n oceansurge | grep -q frontend-pdb" "success"
check_status "Resource quotas configured" "kubectl get resourcequota -n oceansurge | grep -q oceansurge-compute-quota" "success"
check_status "Security contexts non-root" "kubectl get pods -n oceansurge -o jsonpath='{.items[*].spec.securityContext.runAsNonRoot}' | grep -q true" "success"

echo
echo "📈 6. MONITORING & OBSERVABILITY"
echo "-------------------------------"

check_status "Prometheus deployment ready" "kubectl get deployment prometheus -n monitoring -o jsonpath='{.status.readyReplicas}' | grep -q '[1-9]'" "success"
check_status "Grafana deployment ready" "kubectl get deployment grafana -n monitoring -o jsonpath='{.status.readyReplicas}' | grep -q '[1-9]'" "success"
check_status "FinOps metrics endpoint accessible" "kubectl get pods -n oceansurge -l app.kubernetes.io/component=finops -o name | head -1 | xargs kubectl exec -n oceansurge -- curl -f http://localhost:8080/health" "success"

echo
echo "💰 7. FINOPS INTEGRATION"
echo "-----------------------"

check_status "FinOps controller healthy" "kubectl get pods -n oceansurge -l app.kubernetes.io/component=finops | grep -q Running" "success"
check_status "FinOps service account exists" "kubectl get serviceaccount finops-controller -n oceansurge" "success"
check_status "FinOps RBAC configured" "kubectl get clusterrole finops-controller" "success"
check_warning "Feature flag provider configured" "kubectl get configmap finops-config -n oceansurge -o jsonpath='{.data.cluster-id}' | grep -v '^demo-cluster-id$'" "Using demo configuration"

echo
echo "🎭 8. DEMO-SPECIFIC FEATURES"
echo "---------------------------"

check_status "Demo mode enabled" "kubectl get configmap demo-config -n oceansurge -o jsonpath='{.data.DEMO_MODE}' | grep -q true" "success"
check_status "Load simulation configured" "kubectl get deployment shopping-cart -n oceansurge -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name==\"CPU_LOAD_SIMULATION\")].value}' | grep -q true" "success"
check_status "Enhanced deployments active" "kubectl get deployment frontend -n oceansurge -o jsonpath='{.metadata.labels.storm-surge\.io/demo}' | grep -q conference" "success"

echo
echo "⚡ 9. PERFORMANCE & SCALING"
echo "-------------------------"

FRONTEND_REPLICAS=$(kubectl get deployment frontend -n oceansurge -o jsonpath='{.spec.replicas}')
CART_REPLICAS=$(kubectl get deployment shopping-cart -n oceansurge -o jsonpath='{.spec.replicas}')

check_status "Frontend has multiple replicas (≥2)" "[ $FRONTEND_REPLICAS -ge 2 ]" "success"
check_status "Shopping cart ready for scaling" "[ $CART_REPLICAS -ge 2 ]" "success"
check_status "Resource limits configured" "kubectl get pods -n oceansurge -o jsonpath='{.items[*].spec.containers[*].resources.limits}' | grep -q cpu" "success"

echo
echo "🔧 10. WELL-ARCHITECTED COMPLIANCE"
echo "---------------------------------"

# Security Pillar
check_status "Non-root containers (Security)" "! kubectl get pods -n oceansurge -o jsonpath='{.items[*].spec.securityContext.runAsUser}' | grep -q '^0$'" "success"
check_status "Read-only root filesystem (Security)" "kubectl get deployment frontend -n oceansurge -o jsonpath='{.spec.template.spec.containers[0].securityContext.readOnlyRootFilesystem}' | grep -q true" "success"

# Reliability Pillar  
check_status "Pod anti-affinity rules (Reliability)" "kubectl get deployment frontend -n oceansurge -o jsonpath='{.spec.template.spec.affinity}' | grep -q podAntiAffinity" "success"
check_status "Health checks configured (Reliability)" "kubectl get deployment frontend -n oceansurge -o jsonpath='{.spec.template.spec.containers[0].readinessProbe}' | grep -q httpGet" "success"

# Performance Pillar
check_status "Resource requests set (Performance)" "kubectl get pods -n oceansurge -o jsonpath='{.items[*].spec.containers[*].resources.requests}' | grep -q cpu" "success"
check_status "HPA scaling policies (Performance)" "kubectl get hpa shopping-cart-hpa -n oceansurge -o jsonpath='{.spec.behavior}' | grep -q scaleUp" "success"

# Cost Optimization Pillar
check_status "FinOps automation active (Cost)" "kubectl logs deployment/finops-controller -n oceansurge --tail=10 | grep -q 'optimization check'" "success"
check_status "Resource quotas enforced (Cost)" "kubectl describe resourcequota oceansurge-compute-quota -n oceansurge | grep -q 'Used:'" "success"

# Operational Excellence Pillar
check_status "Monitoring stack deployed (Operations)" "kubectl get pods -n monitoring | grep -q prometheus" "success"
check_status "Structured logging enabled (Operations)" "kubectl logs deployment/finops-controller -n oceansurge --tail=5 | grep -q 'INFO'" "success"

echo
echo "📋 VALIDATION SUMMARY"
echo "====================" 
echo -e "Total Checks: $TOTAL_CHECKS"
echo -e "${GREEN}Passed: $PASSED_CHECKS${NC}"
echo -e "${YELLOW}Warnings: $WARNING_CHECKS${NC}"
echo -e "${RED}Failed: $FAILED_CHECKS${NC}"
echo

# Calculate score
if [ $TOTAL_CHECKS -eq 0 ]; then
    SCORE=0
else
    SCORE=$(( (PASSED_CHECKS * 100) / TOTAL_CHECKS ))
fi

if [ $FAILED_CHECKS -eq 0 ] && [ $SCORE -ge 90 ]; then
    echo -e "${GREEN}🎉 DEMO READY! Score: ${SCORE}%${NC}"
    echo "✅ Platform is ready for conference demonstration"
elif [ $FAILED_CHECKS -le 2 ] && [ $SCORE -ge 80 ]; then
    echo -e "${YELLOW}⚠️  MOSTLY READY. Score: ${SCORE}%${NC}"
    echo "🔧 Address failing checks for optimal demo experience"
else
    echo -e "${RED}❌ NOT READY. Score: ${SCORE}%${NC}"
    echo "🚨 Critical issues must be resolved before demo"
fi

echo
echo "🔍 Next Steps:"
if [ $WARNING_CHECKS -gt 0 ]; then
    echo "   • Review warnings - they may indicate demo limitations"
fi
if [ $FAILED_CHECKS -gt 0 ]; then
    echo "   • Fix failed checks before proceeding with demo"
fi
echo "   • Run './scripts/demo-load-test.sh' to test scaling behavior"
echo "   • Access Grafana: kubectl port-forward svc/grafana-service 3000:3000 -n monitoring"
echo "   • Monitor logs: kubectl logs -f deployment/finops-controller -n oceansurge"

# Exit with appropriate code
if [ $FAILED_CHECKS -gt 2 ]; then
    exit 1
else
    exit 0
fi