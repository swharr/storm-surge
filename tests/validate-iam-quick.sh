#!/bin/bash
# Quick IAM validation test

echo "=== Quick IAM Validation Test ==="
echo

# Check AWS policy
echo -n "AWS Policy: "
if [ -f "manifests/providerIAM/aws/eks-admin-policy.json" ] && jq empty manifests/providerIAM/aws/eks-admin-policy.json 2>/dev/null; then
    echo "✓ Valid"
else
    echo "✗ Invalid"
    exit 1
fi

# Check GCP role
echo -n "GCP Role: "
if [ -f "manifests/providerIAM/gcp/gke-admin-role.yaml" ]; then
    echo "✓ Exists"
else
    echo "✗ Missing"
    exit 1
fi

# Check Azure role  
echo -n "Azure Role: "
if [ -f "manifests/providerIAM/azure/aks-admin-role.json" ] && jq empty manifests/providerIAM/azure/aks-admin-role.json 2>/dev/null; then
    echo "✓ Valid"
else
    echo "✗ Invalid"
    exit 1
fi

# Check scripts
echo -n "IAM Scripts: "
if [ -x "scripts/iam/apply-aws-iam.sh" ] && [ -x "scripts/iam/apply-gcp-iam.sh" ] && [ -x "scripts/iam/apply-azure-iam.sh" ]; then
    echo "✓ Executable"
else
    echo "✗ Not executable"
    exit 1
fi

echo
echo "All IAM files validated successfully!"