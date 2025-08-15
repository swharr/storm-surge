# Storm Surge Core - Security Validation

## Overview

This document describes the security validation processes in place for the Storm Surge Core branch.

## GitHub Actions Security Workflows

### 1. Core Branch Validation (`core-validation.yml`)
- Validates minimal footprint (no unnecessary components)
- Checks for hardcoded secrets
- Validates Kubernetes manifests
- Verifies security contexts
- Validates IAM policies

### 2. Security Scanning (`security-scan.yml`)
- Runs Trivy vulnerability scanner
- Performs Semgrep security analysis
- Checks for secrets with TruffleHog
- Uploads results to GitHub Security tab

### 3. Development Validation (`dev-validation.yml`)
- Comprehensive credential scanning
- API key detection
- Secret detection
- Security architecture validation

## Local Security Checks

### Pre-Commit Script
Run before committing:
```bash
./scripts/security-check.sh
```

This script validates:
- No hardcoded credentials
- No API keys exposed
- No secret files (.pem, .key, .pfx)
- Security contexts configured
- Resource limits set
- Pod Security Standards enforced
- No :latest image tags
- Valid YAML syntax

### Manual Validation
```bash
# Validate Kubernetes manifests
kubectl apply --dry-run=client -k manifests/core/

# Check for secrets
grep -r "password\|secret\|key" manifests/ --include="*.yaml"

# Verify permissions
find . -type f -name "*.sh" -exec ls -l {} \;
```

## Security Controls

### Container Security
- Non-root user (UID 1000)
- Read-only root filesystem where possible
- Minimal capabilities (NET_BIND_SERVICE only)
- Security contexts at pod and container level

### Kubernetes Security
- Pod Security Standards (Restricted)
- Network policies
- RBAC configured
- Resource quotas and limits

### Secret Management
- No hardcoded credentials
- Secrets in Kubernetes Secret objects
- Environment variable injection
- Secure secret generation

## Compliance

The core branch adheres to:
- CIS Kubernetes Benchmark
- OWASP Security Guidelines
- Pod Security Standards
- Cloud provider security best practices

## Continuous Monitoring

GitHub Actions run on:
- Every push to core branch
- Every pull request to core branch
- Scheduled security scans (if configured)

Results are:
- Displayed in GitHub Actions
- Uploaded to Security tab (SARIF format)
- Blocking for critical issues

## Before Committing Checklist

1. ✅ Run `./scripts/security-check.sh`
2. ✅ Verify no new files with secrets
3. ✅ Check GitHub Actions are passing
4. ✅ Review security scan results
5. ✅ Ensure minimal footprint maintained