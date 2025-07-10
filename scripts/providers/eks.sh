#!/bin/bash
set -e
echo "🛠️  Provisioning EKS Cluster..."
if ! command -v eksctl &> /dev/null; then
    echo "❌ eksctl not installed" >&2
    exit 1
fi

eksctl create cluster \
  --name storm-surge-eks \
  --region us-west-2 \
  --nodes 2 2>&1 | tee -a logs/eks-deploy.log

aws eks update-kubeconfig --name storm-surge-eks --region us-west-2
echo "✅ EKS cluster ready"