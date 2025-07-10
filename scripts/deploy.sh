#!/bin/bash
set -e

# Load .env if it exists
if [ -f .env ]; then
    echo "📥 Loading environment from .env"
    set -a
    source .env
    set +a
fi

show_usage() {
  echo "Usage: $0 [--provider=gke|eks|aks|all]"
  exit 1
}

# Parse arguments
PROVIDER=""
for arg in "$@"; do
  case $arg in
    --provider=*)
      PROVIDER="${arg#*=}"
      shift
      ;;
    --all)
      PROVIDER="all"
      shift
      ;;
    *)
      show_usage
      ;;
  esac
done

echo "🌩️ Deploying Storm Surge via deploy.sh"
echo "======================================"

if [ -z "$PROVIDER" ]; then
  echo "❓ No provider specified."
  read -p "Which provider do you want to deploy to? (gke/eks/aks/all): " PROVIDER
fi

SCRIPTS_DIR=$(dirname "$0")/providers

run_provider() {
  local p=$1
  local script="${SCRIPTS_DIR}/${p}.sh"
  if [ -f "$script" ]; then
    echo "🚀 Running deployment script for $p..."
    bash "$script"
  else
    echo "❌ Deployment script for provider '$p' not found."
    exit 1
  fi
}

if [ "$PROVIDER" = "all" ]; then
  for p in gke eks aks; do
    run_provider $p
  done
else
  run_provider $PROVIDER
fi

echo "✅ All deployments completed."