# Storm Surge Core - File Manifest

## Overview

This document lists all files included in the Storm Surge Core branch, which provides a minimal, secure Kubernetes deployment stack.

## Root Files

- `README.md` - Core branch documentation
- `CHANGELOG.md` - Version history for core branch
- `LICENSE` - Project license
- `setup-minimal.sh` - Interactive setup script for core deployment

## Manifests

### Core Deployment (`manifests/core/`)
- `namespace.yaml` - Namespace with security labels
- `kustomization.yaml` - Kustomize configuration
- `security-patch.yaml` - Security hardening patches

### Middleware (`manifests/middleware/`)
- `main_minimal.py` - Minimal Flask application
- `configmap-minimal.yaml` - ConfigMap with embedded Python code
- `deployment-minimal.yaml` - Deployment with security contexts
- `service-minimal.yaml` - Service and LoadBalancer configuration
- `secrets-minimal.yaml` - Secret template

### Cloud Infrastructure (`manifests/cloud-infrastructure/`)
- `aws-infrastructure.yaml` - AWS-specific configurations
- `gcp-infrastructure.yaml` - GCP-specific configurations
- `azure-infrastructure.yaml` - Azure-specific configurations

### IAM Policies (`manifests/providerIAM/`)
- `aws/eks-admin-policy.json` - AWS EKS admin policy
- `gcp/gke-admin-role.yaml` - GCP GKE admin role
- `azure/aks-admin-role.json` - Azure AKS admin role
- `validate-permissions.sh` - Permission validation script

### Security (`manifests/security/`)
- `production-security-hardening.yaml` - Production security controls

### Documentation (`manifests/`)
- `CORE_SECURITY.md` - Security configuration guide

## Scripts

### Deployment (`scripts/`)
- `deploy-core.sh` - Core deployment script

### Cloud Providers (`scripts/providers/`)
- `eks.sh` - AWS EKS cluster creation
- `gke.sh` - Google GKE cluster creation
- `aks.sh` - Azure AKS cluster creation

### IAM Setup (`scripts/iam/`)
- `apply-aws-iam.sh` - Apply AWS IAM policies
- `apply-gcp-iam.sh` - Apply GCP IAM roles
- `apply-azure-iam.sh` - Apply Azure RBAC roles

### Cleanup (`scripts/cleanup/`)
- `cleanup-aws.sh` - AWS resource cleanup
- `cleanup-gcp.sh` - GCP resource cleanup
- `cleanup-azure.sh` - Azure resource cleanup
- `cluster-sweep.sh` - Multi-cloud cleanup utility

## GitHub Actions (`.github/workflows/`)
- `dev-validation.yml` - Development branch validation
- `test-suite.yml` - Test suite execution
- `security-scan.yml` - Security scanning
- `release.yaml` - Release automation

## What's NOT Included

The core branch specifically excludes:
- Frontend applications
- Database deployments (PostgreSQL, Redis)
- Message queuing (RabbitMQ)
- Monitoring stack (Prometheus, Grafana)
- Load testing tools
- Feature flag integrations
- Complex microservices
- Development/staging configurations

## Purpose

This minimal configuration provides:
- Basic Kubernetes deployment
- Multi-cloud support
- Security best practices
- Simple health monitoring
- Essential IAM policies

Perfect for teams that need a secure, minimal starting point for Kubernetes deployments.