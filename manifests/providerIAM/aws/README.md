# AWS IAM Policies for Storm Surge

This directory contains IAM policies required for managing EKS clusters and associated resources.

## Policies

### eks-admin-policy.json
Comprehensive IAM policy that grants full administrative access to create and manage EKS clusters, including:
- Full EKS cluster management
- VPC and networking resources
- EC2 instances and auto-scaling groups
- IAM roles and policies for service accounts
- Load balancers (ALB/NLB)
- CloudWatch logs
- KMS for encryption
- ACM for SSL certificates
- Route53 for DNS management

## Usage

### Create IAM User with Policy

```bash
# Create IAM user
aws iam create-user --user-name storm-surge-admin

# Attach the policy (after creating it)
aws iam put-user-policy \
  --user-name storm-surge-admin \
  --policy-name StormSurgeEKSAdminPolicy \
  --policy-document file://eks-admin-policy.json

# Create access keys
aws iam create-access-key --user-name storm-surge-admin
```

### Create IAM Role with Policy

```bash
# Create trust policy
cat > trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::ACCOUNT_ID:root"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# Create role
aws iam create-role \
  --role-name StormSurgeEKSAdminRole \
  --assume-role-policy-document file://trust-policy.json

# Attach policy to role
aws iam put-role-policy \
  --role-name StormSurgeEKSAdminRole \
  --policy-name StormSurgeEKSAdminPolicy \
  --policy-document file://eks-admin-policy.json
```

### Using with AWS CLI

```bash
# Configure AWS CLI with the created credentials
aws configure --profile storm-surge

# Test access
aws eks list-clusters --profile storm-surge
```

## Security Considerations

1. **Principle of Least Privilege**: This policy grants full administrative access. For production use, consider creating more restrictive policies based on specific needs.

2. **Resource Restrictions**: Consider adding resource ARN restrictions to limit access to specific regions or resource naming patterns.

3. **MFA Requirement**: For production, add MFA requirements to sensitive actions.

4. **Regular Review**: Periodically review and audit IAM permissions.

## Required for Storm Surge Features

- **Cluster Creation**: eks:CreateCluster, ec2:*, iam:*
- **Auto-scaling**: autoscaling:*, eks:UpdateNodegroupConfig
- **Load Balancing**: elasticloadbalancing:*
- **SSL/TLS**: acm:*, route53:*
- **Monitoring**: logs:*, cloudwatch:*
- **Encryption**: kms:*