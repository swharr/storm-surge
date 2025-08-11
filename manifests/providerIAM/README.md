# Cloud Provider IAM Policies

This directory contains Identity and Access Management (IAM) policies for each cloud provider to enable full administrative access for Kubernetes cluster management.

## Overview

Storm Surge requires comprehensive permissions to create, manage, and scale Kubernetes clusters across multiple cloud providers. Each subdirectory contains the necessary IAM policies and instructions for:

- **AWS**: EKS cluster management with associated services
- **GCP**: GKE cluster management with Google Cloud resources  
- **Azure**: AKS cluster management with Azure resources

## Directory Structure

```
providerIAM/
├── aws/
│   ├── eks-admin-policy.json    # IAM policy for EKS administration
│   └── README.md                 # AWS-specific setup instructions
├── gcp/
│   ├── gke-admin-role.yaml      # Custom role for GKE administration
│   └── README.md                 # GCP-specific setup instructions
└── azure/
    ├── aks-admin-role.json       # RBAC role for AKS administration
    └── README.md                 # Azure-specific setup instructions
```

## Quick Start

### AWS
```bash
cd aws/
# Create IAM user with policy
aws iam create-user --user-name storm-surge-admin
aws iam put-user-policy --user-name storm-surge-admin \
  --policy-name StormSurgeEKSAdminPolicy \
  --policy-document file://eks-admin-policy.json
```

### GCP
```bash
cd gcp/
# Create custom role and service account
gcloud iam roles create stormSurgeGKEAdmin \
  --project=PROJECT_ID --file=gke-admin-role.yaml
gcloud iam service-accounts create storm-surge-gke-admin
```

### Azure
```bash
cd azure/
# Create custom role and service principal
az role definition create --role-definition aks-admin-role.json
az ad sp create-for-rbac --name "storm-surge-aks-admin" \
  --role "Storm Surge AKS Administrator"
```

## Permissions Overview

### Core Permissions Required

All cloud providers need permissions for:
1. **Cluster Management**: Create, update, delete Kubernetes clusters
2. **Compute Resources**: Manage VMs, instance groups, and scaling
3. **Networking**: Configure VPCs, subnets, load balancers, and firewall rules
4. **Identity & Access**: Create service accounts and manage role bindings
5. **Storage**: Manage persistent volumes and object storage
6. **Security**: Key management, secrets, and certificates
7. **Monitoring**: Logs, metrics, and diagnostics

### Additional Permissions

Each provider requires specific permissions for:
- **AWS**: CloudFormation, Auto Scaling Groups, ELB/ALB, Route53
- **GCP**: Cloud DNS, Cloud Armor, Cloud CDN
- **Azure**: Application Gateway, Traffic Manager, Azure DNS

## Security Considerations

### Best Practices

1. **Principle of Least Privilege**: These policies provide full admin access. For production:
   - Review and remove unnecessary permissions
   - Create separate roles for different environments
   - Use conditions to restrict resource access

2. **Credential Management**:
   - Never commit credentials to version control
   - Use cloud provider secret management services
   - Rotate credentials regularly
   - Enable MFA where possible

3. **Auditing**:
   - Enable cloud audit logs
   - Monitor IAM changes
   - Set up alerts for privilege escalations

4. **Identity Types**:
   - **Development**: User accounts or service principals
   - **Production**: Managed identities (Azure), Workload Identity (GCP), IRSA (AWS)

### Recommended Approach

1. Start with these comprehensive policies for initial setup
2. Deploy and test Storm Surge functionality
3. Analyze actual permission usage through audit logs
4. Create minimal custom policies based on actual needs
5. Implement additional security controls (MFA, IP restrictions, etc.)

## Integration with Storm Surge

The setup script will prompt for cloud provider credentials. Ensure you have:

1. Created the appropriate IAM entities (users, service accounts, principals)
2. Applied the policies from this directory
3. Generated and securely stored credentials
4. Set appropriate environment variables or credential files

Example environment setup:
```bash
# AWS
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"

# GCP
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/key.json"

# Azure
export AZURE_CLIENT_ID="your-client-id"
export AZURE_CLIENT_SECRET="your-client-secret"
export AZURE_TENANT_ID="your-tenant-id"
```

## Troubleshooting

### Common Issues

1. **Insufficient Permissions**: Check audit logs for denied actions
2. **API Not Enabled**: Ensure all required cloud APIs/services are enabled
3. **Quota Limits**: Request quota increases for compute resources
4. **Region Restrictions**: Ensure IAM entities have access to target regions

### Validation

Test permissions before running Storm Surge:
```bash
# AWS
aws eks list-clusters

# GCP  
gcloud container clusters list

# Azure
az aks list
```

## Contributing

When adding new features that require additional permissions:
1. Document the specific permissions needed
2. Update the relevant IAM policy files
3. Test with minimal permissions first
4. Update this documentation