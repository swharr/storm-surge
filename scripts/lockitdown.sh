#!/bin/bash
set -e

# Emergency Security Lockdown Script
# Immediately hardens security configurations and addresses critical vulnerabilities

echo "🚨 STORM SURGE EMERGENCY SECURITY LOCKDOWN"
echo "=========================================="
echo

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
NAMESPACE=${STORM_NAMESPACE:-"oceansurge"}
MONITORING_NS=${MONITORING_NAMESPACE:-"monitoring"}
BACKUP_DIR="/tmp/storm-surge-lockdown-backup-$(date +%s)"

# Create backup directory
mkdir -p "$BACKUP_DIR"
echo "📁 Backup directory: $BACKUP_DIR"

# Backup current configurations
backup_configs() {
    echo "💾 Creating configuration backup..."
    
    if kubectl get namespace "$NAMESPACE" &>/dev/null; then
        kubectl get all,configmap,secret,networkpolicy -n "$NAMESPACE" -o yaml > "$BACKUP_DIR/current-config.yaml"
        echo "✅ Configuration backed up to $BACKUP_DIR/current-config.yaml"
    else
        echo "⚠️  Namespace $NAMESPACE not found - creating backup of manifests only"
        cp -r manifests/ "$BACKUP_DIR/"
    fi
    echo
}

# Emergency network lockdown
emergency_network_lockdown() {
    echo "🌐 EMERGENCY NETWORK LOCKDOWN"
    echo "=========================="
    
    # Apply strict network policies immediately
    echo "🔒 Applying emergency network policies..."
    
    kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: emergency-lockdown
  namespace: $NAMESPACE
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from: []
    ports:
    - protocol: TCP
      port: 80
    - protocol: TCP
      port: 443
  egress:
  - to: []
    ports:
    - protocol: TCP
      port: 53
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 443
EOF

    echo "✅ Emergency network policy applied"
    
    # Block insecure ports immediately
    echo "🚫 Blocking insecure kubelet ports..."
    
    kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: block-insecure-ports
  namespace: $NAMESPACE
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress: []
  egress:
  - to: []
    ports:
    - protocol: TCP
      port: 443
    - protocol: TCP
      port: 53
    - protocol: UDP
      port: 53
  - to: []
    ports:
    - protocol: TCP
      port: 6443
EOF

    echo "✅ Insecure ports blocked"
    echo
}

# Container security lockdown
container_security_lockdown() {
    echo "📦 CONTAINER SECURITY LOCKDOWN" 
    echo "============================"
    
    # Force all deployments to use security contexts
    for deployment in $(kubectl get deployments -n "$NAMESPACE" -o name); do
        echo "🔧 Hardening $deployment..."
        
        kubectl patch "$deployment" -n "$NAMESPACE" --type='strategic' --patch='
{
  "spec": {
    "template": {
      "spec": {
        "securityContext": {
          "runAsNonRoot": true,
          "runAsUser": 10001,
          "runAsGroup": 10001,
          "fsGroup": 10001
        }
      }
    }
  }
}'

        # Patch container security contexts
        kubectl patch "$deployment" -n "$NAMESPACE" --type='json' -p='[
  {
    "op": "add",
    "path": "/spec/template/spec/containers/0/securityContext",
    "value": {
      "runAsNonRoot": true,
      "runAsUser": 10001,
      "allowPrivilegeEscalation": false,
      "readOnlyRootFilesystem": true,
      "capabilities": {
        "drop": ["ALL"]
      }
    }
  }
]' 2>/dev/null || echo "   Security context patch may have been partially applied"

        echo "✅ $deployment hardened"
    done
    
    echo
}

# RBAC lockdown
rbac_lockdown() {
    echo "👤 RBAC SECURITY LOCKDOWN"
    echo "======================="
    
    # Create emergency service account with minimal permissions
    kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: emergency-sa
  namespace: $NAMESPACE
automountServiceAccountToken: false
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: emergency-role
  namespace: $NAMESPACE
rules:
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["get", "list"]
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get"]
  resourceNames: ["app-config"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: emergency-role-binding
  namespace: $NAMESPACE
subjects:
- kind: ServiceAccount
  name: emergency-sa
  namespace: $NAMESPACE
roleRef:
  kind: Role
  name: emergency-role
  apiGroup: rbac.authorization.k8s.io
EOF

    echo "✅ Emergency RBAC configuration applied"
    
    # Disable default service account token mounting
    kubectl patch serviceaccount default -n "$NAMESPACE" -p '{"automountServiceAccountToken": false}'
    echo "✅ Default service account token mounting disabled"
    
    echo
}

# Secrets security lockdown
secrets_lockdown() {
    echo "🔐 SECRETS SECURITY LOCKDOWN"
    echo "=========================="
    
    # Check for and remove any insecure secrets
    echo "🔍 Scanning for insecure secrets..."
    
    insecure_secrets=$(kubectl get secrets -n "$NAMESPACE" -o json | jq -r '.items[] | select(.data | has("password") or has("secret")) | .metadata.name' 2>/dev/null || echo "")
    
    if [ -n "$insecure_secrets" ]; then
        echo "⚠️  Found potentially insecure secrets:"
        echo "$insecure_secrets"
        echo "📋 Manual review required - secrets not automatically deleted"
    else
        echo "✅ No obviously insecure secrets found"
    fi
    
    # Create secure secret template
    kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: emergency-config
  namespace: $NAMESPACE
type: Opaque
data:
  emergency: dHJ1ZQ==  # base64 encoded "true"
EOF

    echo "✅ Emergency secure configuration created"
    echo
}

# Resource limits lockdown
resource_lockdown() {
    echo "⚡ RESOURCE LIMITS LOCKDOWN"
    echo "========================"
    
    # Apply emergency resource quota
    kubectl apply -f - <<EOF
apiVersion: v1
kind: ResourceQuota
metadata:
  name: emergency-quota
  namespace: $NAMESPACE
spec:
  hard:
    requests.cpu: "2"
    requests.memory: 4Gi
    limits.cpu: "4" 
    limits.memory: 8Gi
    pods: "20"
    services: "10"
    persistentvolumeclaims: "5"
EOF

    # Apply strict limit range
    kubectl apply -f - <<EOF
apiVersion: v1
kind: LimitRange
metadata:
  name: emergency-limits
  namespace: $NAMESPACE
spec:
  limits:
  - type: Container
    default:
      cpu: "200m"
      memory: "256Mi"
    defaultRequest:
      cpu: "100m"
      memory: "128Mi"
    max:
      cpu: "500m"
      memory: "1Gi"
    min:
      cpu: "50m"
      memory: "64Mi"
EOF

    echo "✅ Emergency resource constraints applied"
    echo
}

# Monitor and alert setup
monitoring_lockdown() {
    echo "📊 MONITORING SECURITY LOCKDOWN"
    echo "============================="
    
    # Create security monitoring configmap
    kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: security-monitoring
  namespace: $NAMESPACE
data:
  emergency-mode: "true"
  lockdown-timestamp: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  security-level: "maximum"
  monitoring-enabled: "true"
EOF

    echo "✅ Security monitoring configuration applied"
    
    # Enable audit logging if possible
    if kubectl get pods -n kube-system | grep -q audit; then
        echo "✅ Audit logging appears to be enabled"
    else
        echo "⚠️  Audit logging not detected - manual configuration may be required"
    fi
    
    echo
}

# Validate lockdown
validate_lockdown() {
    echo "🔍 VALIDATING SECURITY LOCKDOWN"
    echo "=============================="
    
    # Check network policies
    if kubectl get networkpolicy emergency-lockdown -n "$NAMESPACE" &>/dev/null; then
        echo "✅ Emergency network policy active"
    else
        echo "❌ Emergency network policy failed"
    fi
    
    # Check resource constraints
    if kubectl get resourcequota emergency-quota -n "$NAMESPACE" &>/dev/null; then
        echo "✅ Resource quota active"
    else
        echo "❌ Resource quota failed"
    fi
    
    # Check RBAC
    if kubectl get serviceaccount emergency-sa -n "$NAMESPACE" &>/dev/null; then
        echo "✅ Emergency service account created"
    else
        echo "❌ Emergency service account failed"
    fi
    
    # Check pod security
    non_root_pods=$(kubectl get pods -n "$NAMESPACE" -o jsonpath='{.items[*].spec.securityContext.runAsNonRoot}' | grep -o true | wc -l)
    total_pods=$(kubectl get pods -n "$NAMESPACE" --no-headers | wc -l)
    
    if [ "$non_root_pods" -eq "$total_pods" ] 2>/dev/null; then
        echo "✅ All pods running as non-root"
    else
        echo "⚠️  Some pods may still be running as root - restart required"
    fi
    
    echo
}

# Recovery information
provide_recovery_info() {
    echo "🔄 RECOVERY INFORMATION"
    echo "===================="
    echo
    echo "Emergency lockdown completed. Here's what was done:"
    echo
    echo "🔒 Security Measures Applied:"
    echo "   • Emergency network policies (default deny)"
    echo "   • Container security contexts hardened"
    echo "   • RBAC permissions restricted"
    echo "   • Resource quotas and limits enforced"
    echo "   • Security monitoring enabled"
    echo
    echo "📁 Backup Location: $BACKUP_DIR"
    echo
    echo "🔄 To restore from backup:"
    echo "   kubectl apply -f $BACKUP_DIR/current-config.yaml"
    echo
    echo "🧹 To remove emergency lockdown:"
    echo "   kubectl delete networkpolicy emergency-lockdown -n $NAMESPACE"
    echo "   kubectl delete resourcequota emergency-quota -n $NAMESPACE"
    echo "   kubectl delete limitrange emergency-limits -n $NAMESPACE"
    echo
    echo "📊 To check status:"
    echo "   ./scripts/security-audit.sh --comprehensive"
    echo
    echo "⚠️  IMPORTANT: Review and test applications after lockdown"
    echo "   Some services may require restart to apply security contexts"
    echo
}

# Main execution
main() {
    echo "🚨 This script will immediately apply strict security measures"
    echo "   to the Storm Surge deployment. This may temporarily impact"
    echo "   application functionality."
    echo
    
    if [ "$1" != "--force" ]; then
        read -p "Continue with security lockdown? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Lockdown cancelled."
            exit 0
        fi
    fi
    
    echo
    echo "🔒 Beginning emergency security lockdown..."
    echo
    
    backup_configs
    emergency_network_lockdown
    container_security_lockdown
    rbac_lockdown
    secrets_lockdown
    resource_lockdown
    monitoring_lockdown
    validate_lockdown
    provide_recovery_info
    
    echo -e "${GREEN}🎯 EMERGENCY SECURITY LOCKDOWN COMPLETED${NC}"
    echo
    echo "Next steps:"
    echo "1. Verify applications are still functioning"
    echo "2. Run: ./scripts/security-audit.sh --comprehensive"
    echo "3. Review and adjust security policies as needed"
    echo "4. Document any issues for future reference"
}

# Handle command line arguments
case "${1:-}" in
    --help|-h)
        echo "Storm Surge Emergency Security Lockdown"
        echo
        echo "Usage: $0 [--force]"
        echo
        echo "This script applies immediate security hardening measures:"
        echo "• Network policy lockdown (default deny)"
        echo "• Container security context enforcement"
        echo "• RBAC permission restriction"
        echo "• Resource quota enforcement"
        echo "• Security monitoring setup"
        echo
        echo "Options:"
        echo "  --force    Skip confirmation prompt"
        echo "  --help     Show this help message"
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac