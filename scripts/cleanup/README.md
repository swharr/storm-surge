# Storm Surge Cleanup Scripts

This directory contains safe cleanup scripts for removing Storm Surge resources from cloud providers and Kubernetes clusters.

## Scripts Overview

### Master Cleanup Script
- **`cleanup.sh`** - Multi-cloud cleanup orchestrator with support for all providers

### Cloud-Specific Scripts  
- **`cleanup-aws.sh`** - AWS EKS cluster and resource cleanup
- **`cleanup-gcp.sh`** - Google Cloud GKE cluster and resource cleanup
- **`cleanup-azure.sh`** - Azure AKS cluster and resource cleanup

### Kubernetes Cleanup
- **`cluster-sweep.sh`** - Kubernetes namespace cleanup (preserves system namespaces)

## Safety Features

All cleanup scripts include comprehensive safety measures:

- **Dry-run mode** - See what would be deleted without making changes
- **Confirmation prompts** - Explicit confirmation before destructive operations
- **Protected resources** - System namespaces and critical resources are never deleted
- **Error handling** - Graceful handling of failures and missing resources
- **Logging** - Detailed logging of all operations
- **Prerequisites check** - Verify required tools are installed and configured

## Usage Examples

### Quick Start - Dry Run
```bash
# See what would be deleted without making changes
./cleanup.sh --provider=aws --dry-run
./cleanup.sh --provider=gcp --dry-run  
./cleanup.sh --provider=azure --dry-run
```

### Full Cleanup (Interactive)
```bash
# Clean up specific cloud provider with confirmation prompts
./cleanup.sh --provider=aws --cluster-name=my-cluster
./cleanup.sh --provider=gcp --project=my-project
./cleanup.sh --provider=azure --resource-group=my-rg
```

### Automated Cleanup
```bash
# Automated cleanup without prompts (use with caution)
./cleanup.sh --provider=aws --force
```

### Multi-Cloud Cleanup
```bash
# Clean up all cloud providers (with confirmation)
./cleanup.sh --provider=all --dry-run
./cleanup.sh --provider=all
```

### Kubernetes Namespace Cleanup Only
```bash
# Clean up application namespaces while preserving system namespaces
./cluster-sweep.sh --dry-run
./cluster-sweep.sh
```

## Protected Resources

### Protected Namespaces (Never Deleted)
- `kube-system` - Core Kubernetes system
- `default` - Default namespace  
- `kube-public` - Public cluster information
- `kube-node-lease` - Node heartbeat system
- `gatekeeper-system` - Policy enforcement
- `aws-observability` - AWS monitoring
- `azure-system` - Azure system components
- `gke-system` - Google Cloud system components
- `kube-flannel` - Flannel networking
- `metallb-system` - MetalLB load balancer
- `ingress-nginx` - Nginx ingress controller
- `cert-manager` - Certificate management
- `monitoring` - Monitoring stack
- `istio-system` - Istio service mesh

### Cleanup Process
1. **Kubernetes resources** are deleted first (namespaces, ingress, etc.)
2. **Cloud load balancers** are given time to clean up automatically
3. **Cluster infrastructure** is deleted (nodes, networking, etc.)
4. **Associated resources** are cleaned up (security groups, etc.)

## Script-Specific Options

### AWS Cleanup (`cleanup-aws.sh`)
```bash
--cluster-name=NAME     # EKS cluster name (default: storm-surge-prod)
--region=REGION        # AWS region (default: us-east-1)
--dry-run             # Show what would be deleted
--force               # Skip confirmations
```

### GCP Cleanup (`cleanup-gcp.sh`)  
```bash
--cluster-name=NAME     # GKE cluster name (default: storm-surge-prod)
--region=REGION        # GCP region (default: us-central1)
--project=PROJECT_ID   # GCP project ID
--dry-run             # Show what would be deleted
--force               # Skip confirmations
```

### Azure Cleanup (`cleanup-azure.sh`)
```bash
--cluster-name=NAME        # AKS cluster name (default: storm-surge-prod)
--resource-group=GROUP     # Resource group (default: storm-surge-prod-rg)
--dry-run                 # Show what would be deleted
--force                   # Skip confirmations
```

### Namespace Cleanup (`cluster-sweep.sh`)
```bash
--dry-run    # Show what would be deleted
--force      # Skip confirmations  
--help       # Show protected namespaces
```

## Prerequisites

### AWS
- `aws` CLI configured with appropriate permissions
- `eksctl` for EKS cluster management
- `kubectl` for Kubernetes operations

### Google Cloud
- `gcloud` CLI configured with appropriate permissions
- `kubectl` for Kubernetes operations

### Azure
- `az` CLI logged in with appropriate permissions  
- `kubectl` for Kubernetes operations

## Best Practices

1. **Always run dry-run first** to understand what will be deleted
2. **Use specific cluster names** to avoid deleting the wrong resources
3. **Check cloud console afterwards** to verify complete cleanup
4. **Review logs** if any cleanup operations fail
5. **Keep backups** of important data before cleanup
6. **Verify credentials** are for the correct environment

## Post-Cleanup Verification

After running cleanup scripts, verify in your cloud console:

- No orphaned load balancers or public IPs
- No remaining persistent volumes
- DNS records have been cleaned up  
- Custom IAM roles are removed if no longer needed
- SSL certificates are properly cleaned up

## Troubleshooting

### Common Issues

**Script can't find cluster:**
- Verify cluster name and region/project parameters
- Check cloud CLI authentication

**Permission denied:**
- Ensure cloud CLI has sufficient permissions
- For Kubernetes: check kubeconfig and RBAC permissions

**Resources still exist after cleanup:**
- Some resources may have deletion protection enabled
- Check cloud console for manual cleanup requirements
- Review script logs for specific error messages

**Cleanup hangs or times out:**
- Some resources (like load balancers) take time to delete
- Scripts include appropriate timeouts and retries
- Check cloud console for resource deletion status

For additional help, check the main Storm Surge documentation or cloud provider specific troubleshooting guides.