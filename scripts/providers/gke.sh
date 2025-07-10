#!/bin/bash
set -e
echo "🛠️  Provisioning GKE Cluster..."
if ! command -v gcloud &> /dev/null; then
    echo "❌ gcloud CLI not installed" >&2
    exit 1
fi

gcloud container clusters create storm-surge-gke \
  --zone=us-central1-c \
  --num-nodes=2 --quiet 2>&1 | tee -a logs/gke-deploy.log

gcloud container clusters get-credentials storm-surge-gke --zone=us-central1-c
echo "✅ GKE cluster ready"