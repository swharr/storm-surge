# Storm Surge Test Suite Guide

## Table of Contents
1. [Overview](#overview)
2. [Test Suite Architecture](#test-suite-architecture)
3. [Test Jobs and Their Purposes](#test-jobs-and-their-purposes)
4. [Prerequisites and Dependencies](#prerequisites-and-dependencies)
5. [Getting Started](#getting-started)
6. [Technical Implementation Details](#technical-implementation-details)
7. [Troubleshooting Common Issues](#troubleshooting-common-issues)
8. [Limitations and Considerations](#limitations-and-considerations)
9. [Advanced Configuration](#advanced-configuration)

---

## Overview

The Storm Surge Test Suite is a comprehensive CI/CD testing framework that validates multi-cloud Kubernetes deployments across Google Cloud Platform (GKE), Amazon Web Services (EKS), and Microsoft Azure (AKS). The test suite ensures code quality, security compliance, and deployment readiness before production releases.

### Purpose

- **Quality Assurance**: Validates all components work together before deployment
- **Security Validation**: Ensures IAM policies and security configurations are correct
- **Multi-Cloud Compatibility**: Tests deployment scripts across all three major cloud providers
- **Deployment Readiness**: Confirms infrastructure can be deployed without manual intervention

---

## Test Suite Architecture

The test suite follows a parallel execution model with dependency chains:

```
pre-commit (foundation)
    ├── frontend-test (depends on pre-commit)
    ├── script-validation (depends on pre-commit)
    ├── security-scan (depends on pre-commit)
    ├── iam-validation (depends on pre-commit)
    └── docs-validation (independent)

minikube-test (depends on pre-commit + frontend-test)

release-check (main branch only, depends on ALL tests)
```

---

## Test Jobs and Their Purposes

### 1. Pre-commit Validation (`pre-commit`)
**Purpose**: Foundation validation of code quality and syntax

**What it does**:
- Installs Python 3.11, Node.js 20, kubectl, and kustomize
- Runs Python syntax checks on core scripts
- Validates frontend TypeScript compilation
- Executes pre-commit hooks for code formatting and linting

**Key validations**:
```bash
# Python syntax validation
python -m py_compile feature_flag_configure.py
python -m py_compile manifests/middleware/*.py
python -m py_compile tests/*.py

# Frontend TypeScript check
cd frontend && npx tsc --noEmit --skipLibCheck

# Pre-commit hooks (formatting, linting, etc.)
pre-commit run --all-files
```

### 2. Frontend Tests (`frontend-test`)
**Purpose**: Validates React frontend components and build process

**What it tests**:
- Frontend directory structure and essential files
- TypeScript configuration and compilation
- ESLint code quality checks
- Build process functionality
- Integration points with backend services

**Key components tested**:
- React component structure (`Dashboard.tsx`, `Login.tsx`, etc.)
- TypeScript type definitions
- API service configuration
- WebSocket hooks
- Docker configuration and nginx setup
- Kubernetes manifests

### 3. Minikube Deployment Test (`minikube-test`)
**Purpose**: Full integration testing on local Kubernetes cluster

**Test environment**:
- **CPU**: 4 cores
- **Memory**: 8192MB
- **Disk**: 20GB
- **Driver**: Docker

**What it validates**:
- Kubernetes manifest syntax and deployment
- Pod health and readiness
- Resource constraints (CPU/memory requests and limits)
- Security contexts (non-root users, security policies)
- Health endpoint functionality
- Network connectivity between services

**Test flow**:
1. Starts fresh minikube cluster
2. Validates all Kubernetes manifests
3. Deploys base, middleware, and frontend components
4. Tests health endpoints via port-forwarding
5. Validates security configurations
6. Generates comprehensive test report

### 4. Multi-Cloud Script Validation (`script-validation`)
**Purpose**: Tests deployment scripts for all cloud providers

**Matrix testing**: Tests scripts for `[gke, eks, aks]` in parallel

**What it validates**:
- **Script syntax**: Ensures all bash scripts are syntactically correct
- **Cloud CLI installation**: Verifies gcloud, aws, and az tools
- **Input validation**: Tests script parameter validation logic
- **Error handling**: Confirms scripts fail appropriately with invalid inputs

**Validation example**:
```bash
# Tests zone/region mismatch validation
export STORM_REGION="us-central1"
export STORM_ZONE="us-west-2-a"  # Intentionally mismatched
# Script should fail with validation error
```

### 5. Security Scan (`security-scan`)
**Purpose**: Identifies security vulnerabilities in codebase

**Tool**: Trivy vulnerability scanner
- Scans filesystem for known vulnerabilities
- Outputs results in SARIF format
- Uploads findings to GitHub Security tab
- Covers container images, dependencies, and configuration files

### 6. IAM Policy Validation (`iam-validation`)
**Purpose**: Validates cloud provider IAM policies and permissions

**Multi-tiered testing approach**:
1. **Quick validation**: Basic syntax and structure checks
2. **Shell-based tests**: Uses `jq` for JSON policy validation
3. **Python-based tests**: Deep policy analysis with PyYAML
4. **Script syntax validation**: Ensures all IAM scripts are executable

**Validates**:
- AWS IAM policies (`eks-admin-policy.json`)
- Azure role definitions (`aks-admin-role.json`)
- GCP IAM roles (`gke-admin-role.yaml`)
- Permission validation scripts

### 7. Documentation Validation (`docs-validation`)
**Purpose**: Ensures documentation quality and completeness

**What it checks**:
- **Link validation**: Tests all markdown links are accessible
- **Required documents**: Validates presence of essential documentation
- **Content quality**: Ensures documentation follows standards

**Required documentation**:
- `README.md`
- `docs/ARCHITECTURE.md`
- `CHANGELOG.md`
- `LICENSE`

### 8. Release Readiness Check (`release-check`)
**Purpose**: Final validation for production deployments (main branch only)

**Execution conditions**:
- Only runs on `main` branch
- Requires ALL other tests to pass
- Creates comprehensive release summary

**What it validates**:
- Git tag presence for releases
- CHANGELOG.md completeness
- All test suite completion
- Creates deployment summary in GitHub

---

## Prerequisites and Dependencies

### System Requirements
- **Ubuntu Latest** (GitHub Actions runner)
- **Docker** (for minikube driver)
- **4+ CPU cores** and **8GB+ RAM** (for minikube testing)

### Required Tools (auto-installed by test suite)
- **kubectl** (latest version)
- **kustomize** (latest version)
- **Python 3.11** with PyYAML
- **Node.js 20** with npm
- **Cloud CLIs**: gcloud, aws, az (latest versions)
- **pre-commit** framework

### Environment Variables
Required for full functionality:

```bash
# Feature flags (LaunchDarkly)
LAUNCHDARKLY_SDK_KEY=your-sdk-key
WEBHOOK_SECRET=your-webhook-secret

# Cloud provider credentials (for live testing)
# AWS
AWS_ACCESS_KEY_ID=your-aws-key
AWS_SECRET_ACCESS_KEY=your-aws-secret

# GCP
GOOGLE_APPLICATION_CREDENTIALS=path-to-service-account.json

# Azure
AZURE_CLIENT_ID=your-azure-client-id
AZURE_CLIENT_SECRET=your-azure-client-secret
AZURE_TENANT_ID=your-azure-tenant-id

# Spot.io integration
SPOT_API_TOKEN=your-spot-token
SPOT_CLUSTER_ID=your-cluster-id
```

---

## Getting Started

### For Kubernetes Practitioners

**Quick validation run**:
```bash
# Clone and enter the repository
git clone <repository-url>
cd storm-surge

# Run pre-commit checks locally
pip install pre-commit PyYAML
pre-commit run --all-files

# Validate Kubernetes manifests
kubectl apply --dry-run=client -k manifests/core/
kubectl apply --dry-run=client -k manifests/middleware/
```

### For Cloud Managed Kubernetes Newcomers

**Understanding the test structure**:

1. **Start with documentation**: Read `README.md` and `docs/ARCHITECTURE.md`
2. **Examine manifests**: Look at `manifests/` directory structure
3. **Review cloud scripts**: Check `scripts/providers/` for deployment patterns
4. **Study IAM policies**: Understand `manifests/providerIAM/` requirements

**Learning path**:
```bash
# 1. Understand the project structure
ls -la manifests/
ls -la scripts/providers/

# 2. Review cloud-specific configurations
cat manifests/providerIAM/gcp/gke-admin-role.yaml
cat manifests/providerIAM/aws/eks-admin-policy.json
cat manifests/providerIAM/azure/aks-admin-role.json

# 3. Examine test configurations
cat .github/workflows/test-suite.yml
```

### Running Local Tests

**Prerequisites check**:
```bash
# Verify tools are installed
command -v docker && echo "Docker: ✅" || echo "Docker: ❌"
command -v kubectl && echo "kubectl: ✅" || echo "kubectl: ❌"
command -v python3 && echo "Python: ✅" || echo "Python: ❌"
command -v node && echo "Node.js: ✅" || echo "Node.js: ❌"
```

**Run individual test components**:
```bash
# Frontend tests
cd frontend && npm install && npm run build

# Python component tests
python3 tests/test_middleware.py
python3 tests/test_frontend.py

# IAM validation tests
./tests/run-iam-tests.sh

# Local minikube test (requires minikube)
./tests/test-suite.sh
```

---

## Technical Implementation Details

### Test Execution Flow

1. **Parallel Foundation Testing**:
   - Pre-commit validation establishes code quality baseline
   - Security scanning runs independently
   - Documentation validation runs independently

2. **Dependent Component Testing**:
   - Frontend tests depend on pre-commit passing
   - Script validation tests depend on pre-commit passing
   - IAM validation depends on pre-commit passing

3. **Integration Testing**:
   - Minikube test requires both pre-commit and frontend-test success
   - Provides full deployment validation in isolated environment

4. **Release Validation** (main branch only):
   - Requires ALL tests to pass
   - Creates comprehensive release readiness report

### Minikube Test Suite Details

**Test suite script**: `/tests/test-suite.sh`

**Key testing phases**:

1. **Environment Setup**:
   ```bash
   # Configurable parameters
   TEST_NAMESPACE="storm-surge-test"
   MINIKUBE_PROFILE="storm-surge-test"
   TIMEOUT=300
   LOG_DIR="test-logs"
   ```

2. **Cluster Provisioning**:
   ```bash
   minikube start \
     --profile="storm-surge-test" \
     --cpus=4 \
     --memory=8192 \
     --disk-size=20g \
     --driver=docker
   ```

3. **Deployment Testing**:
   - Validates manifest syntax with `--dry-run=client`
   - Deploys to test namespace
   - Waits for deployment readiness
   - Tests health endpoints via port-forwarding

4. **Security Validation**:
   ```bash
   # Checks each pod for security contexts
   kubectl get pod "$pod" -o jsonpath='{.spec.containers[0].securityContext.runAsUser}'
   kubectl get pod "$pod" -o jsonpath='{.spec.containers[0].securityContext.runAsNonRoot}'
   ```

5. **Resource Constraint Testing**:
   ```bash
   # Validates resource requests and limits
   kubectl get pod "$pod" -o jsonpath='{.spec.containers[0].resources}'
   ```

### Multi-Cloud Script Validation

**Test matrix implementation**:
```yaml
strategy:
  matrix:
    provider: [gke, eks, aks]
```

**Validation methodology**:
- **Syntax testing**: `bash -n script.sh`
- **Parameter validation**: Tests with intentionally invalid inputs
- **CLI tool verification**: Ensures cloud tools are available and updated
- **Error handling**: Confirms scripts fail gracefully with appropriate messages

### Frontend Testing Architecture

**Component testing levels**:

1. **Structure validation**: Ensures required files and directories exist
2. **Configuration testing**: Validates TypeScript, ESLint, and build configs
3. **Dependency analysis**: Checks for essential React and integration libraries
4. **Docker validation**: Tests container configuration and scripts
5. **Kubernetes integration**: Validates k8s manifests and kustomization
6. **API integration**: Tests service connections and WebSocket configurations

---

## Troubleshooting Common Issues

### Minikube Test Failures

**Issue**: Minikube fails to start
```
Error: Failed to start minikube cluster
```

**Solutions**:
1. **Resource constraints**: Increase GitHub Actions runner resources
2. **Driver issues**: Verify Docker is available and running
3. **Profile conflicts**: Clean up existing minikube profiles

**Debugging commands**:
```bash
# Check minikube status
minikube status -p storm-surge-test

# View minikube logs
minikube logs -p storm-surge-test

# Clean up and restart
minikube delete -p storm-surge-test
```

### Cloud CLI Installation Failures

**Issue**: Cloud CLI tools fail to install or update
```
Error: Package 'google-cloud-cli' has no installation candidate
```

**Solutions**:
1. **Repository updates**: Ensure apt repositories are current
2. **Network connectivity**: Check for download failures
3. **Version conflicts**: Use specific version pinning

**Manual verification**:
```bash
# Test CLI installations
gcloud version
aws --version  
az --version
```

### Frontend Build Failures

**Issue**: TypeScript compilation or build failures
```
Error: Cannot find module '@types/react'
```

**Solutions**:
1. **Dependency installation**: Ensure `npm ci` completed successfully
2. **Node version**: Verify Node.js 20 is being used
3. **Cache issues**: Clear npm cache and reinstall

**Debugging approach**:
```bash
# Clear and reinstall
cd frontend
rm -rf node_modules package-lock.json
npm install

# Check TypeScript separately
npx tsc --noEmit
```

### IAM Permission Test Failures

**Issue**: IAM validation fails with policy syntax errors
```
Error: Invalid JSON in policy file
```

**Solutions**:
1. **JSON validation**: Use `jq` to validate policy syntax
2. **Schema compliance**: Ensure policies match cloud provider schemas
3. **Permission scope**: Verify required permissions are included

**Manual validation**:
```bash
# Validate JSON policy files
jq . manifests/providerIAM/aws/eks-admin-policy.json
jq . manifests/providerIAM/azure/aks-admin-role.json

# Validate YAML files
python3 -c "import yaml; yaml.safe_load(open('manifests/providerIAM/gcp/gke-admin-role.yaml'))"
```

### Security Scan Issues

**Issue**: Trivy scanner fails or reports false positives
```
Error: Failed to scan filesystem
```

**Solutions**:
1. **Update scanner**: Ensure Trivy is using latest vulnerability database
2. **Scope adjustment**: Exclude non-critical paths if needed
3. **Threshold adjustment**: Configure severity levels appropriately

**Scanner configuration**:
```yaml
# Custom Trivy configuration
scan-type: 'fs'
scan-ref: '.'
format: 'sarif'
severity: 'HIGH,CRITICAL'  # Focus on critical issues
```

---

## Limitations and Considerations

### Test Environment Constraints

1. **Resource Limitations**:
   - GitHub Actions runners have limited CPU and memory
   - Minikube testing may timeout with complex deployments
   - Network bandwidth constraints for large image pulls

2. **Time Constraints**:
   - Maximum job runtime: 6 hours (GitHub Actions limit)
   - Minikube tests timeout after 5 minutes per deployment
   - Cloud CLI installation can take 2-3 minutes per provider

3. **Cloud Provider Limitations**:
   - No actual cloud resource provisioning (cost and complexity)
   - Limited to syntax and configuration validation
   - Cannot test real cloud networking and IAM integration

### Security Considerations

1. **Credential Management**:
   - Use GitHub Secrets for sensitive configuration
   - Rotate credentials regularly
   - Limit scope of service accounts and API keys

2. **Test Data**:
   - Use test namespaces for isolation
   - Avoid production-like data in test configurations
   - Clean up test resources after each run

3. **Vulnerability Scanning**:
   - False positives may occur with aggressive scanning
   - Regularly update vulnerability databases
   - Review security findings in context

### Compatibility Requirements

1. **Kubernetes Versions**:
   - Tests use latest kubectl version
   - May not catch compatibility issues with older K8s versions
   - Consider testing against multiple Kubernetes versions

2. **Cloud Provider API Changes**:
   - CLI tools auto-update to latest versions
   - Breaking changes in cloud APIs may affect tests
   - Monitor cloud provider changelogs for impacts

3. **Frontend Dependencies**:
   - Node.js and npm version constraints
   - React and TypeScript compatibility requirements
   - Browser compatibility not tested in CI

---

## Advanced Configuration

### Custom Test Configurations

**Environment-specific testing**:
```bash
# Override default test parameters
export TEST_NAMESPACE="custom-test-ns"
export MINIKUBE_PROFILE="custom-profile"
export TIMEOUT=600  # 10 minutes

# Run with custom settings
./tests/test-suite.sh
```

**Cloud-specific testing**:
```bash
# Test specific cloud provider only
export STORM_REGION="us-west-2"
export STORM_ZONE="us-west-2a"
export STORM_NODES="5"

# Validate provider-specific script
bash -n scripts/providers/eks.sh
```

### Pro Tips for Advanced Users

1. **Parallel Testing Optimization**:
   - Use GitHub Actions matrix strategy for multiple environment testing
   - Implement test result caching for faster subsequent runs
   - Consider self-hosted runners for more resources

2. **Security Hardening**:
   - Implement branch protection rules requiring all tests to pass
   - Use signed commits for additional security
   - Enable dependency vulnerability scanning

3. **Monitoring and Alerting**:
   - Set up GitHub notifications for test failures
   - Integrate with external monitoring systems
   - Track test duration trends for performance optimization

4. **Custom Test Extensions**:
   ```bash
   # Add custom validation steps
   custom_validation() {
       log "Running custom validation..."
       
       # Your custom tests here
       validate_custom_configs
       test_integration_endpoints
       verify_performance_metrics
       
       success "Custom validation completed"
   }
   
   # Add to main test flow
   main() {
       # ... existing tests ...
       custom_validation
       # ... continue with existing tests ...
   }
   ```

5. **Performance Optimization**:
   - Cache Docker images between test runs
   - Use multi-stage builds to reduce build times
   - Implement test result artifacts for debugging

---

## Conclusion

The Storm Surge Test Suite provides comprehensive validation for multi-cloud Kubernetes deployments. By following this guide, both experienced practitioners and newcomers can understand, execute, and troubleshoot the testing pipeline effectively.

**Key takeaways**:
- Tests run in parallel with smart dependency management
- Comprehensive validation covers security, functionality, and integration
- Designed for both local development and CI/CD environments
- Supports all three major cloud providers (GCP, AWS, Azure)
- Extensive troubleshooting and configuration options available

For additional support, refer to the project's issue tracker and documentation in the `/docs` directory.