# 🌀 Storm Surge – Changelog

## [Unreleased]

## v0.1.4-alpha-poc – July 11, 2025

### 🛠️ Script Logic & Deployment Improvements
- **Enhanced Deploy Script Logic**
  - Improved region restrictions with comprehensive validation
  - Added robust retry logic for deployment operations with configurable timeouts
  - Implemented non-destructive re-deploy capabilities for existing clusters
  - Better error handling and recovery mechanisms throughout deployment process
  - Enhanced cloud region restrictions and security validation

### 🔒 Security & Validation Enhancements  
- **Advanced Security Controls**
  - Cloud region restrictions enforced across all providers
  - Enhanced error handling with detailed validation feedback
  - Improved security checks throughout deployment pipeline
  - Better validation of deployment parameters and configurations

### 📖 Documentation Updates
- **README and Documentation Improvements**
  - Updated feature status and clarity improvements
  - Enhanced documentation for deployment processes
  - Better organization of project information and usage examples

### 🔧 Infrastructure & Workflow
- **GitHub Release Workflow**
  - Added automated GitHub Release workflow for version tagging
  - Improved CI/CD pipeline with proper version management

### 🚀 Major Features
- **Enhanced Interactive Deployment Script**
  - Interactive provider selection (GKE, EKS, AKS, all)
  - Cloud-specific region and zone selection with validation
  - Node count configuration (1-10 nodes, default: 4)
  - Zone/region mismatch detection with helpful error messages
  - Support for both command-line and interactive modes
  - Complete deployment including base app + middleware + finops

### 🧪 Testing & Quality Assurance
- **Comprehensive Test Suite**
  - Local quick tests (`test-local.sh`) for rapid validation
  - Full minikube test suite (`tests/test-suite.sh`) with detailed reporting
  - Pre-commit hooks for automated validation on every commit
  - GitHub Actions CI/CD pipeline with multi-cloud validation
  - Security scanning with Trivy vulnerability detection
  
- **Test Coverage**
  - Script syntax validation
  - Parameter and zone/region validation
  - Kubernetes manifest validation
  - Health endpoint testing
  - Resource constraint validation
  - Security context verification
  - Hardcoded secrets detection

### 🛡️ Security Improvements
- **Container Security Hardening**
  - Migrated from `nginx:alpine` to `nginxinc/nginx-unprivileged:alpine`
  - All containers now run as non-root users
  - Proper security contexts with `runAsNonRoot: true`
  - Container ports changed from 80 to 8080 for unprivileged access
  - Resource limits and requests defined for all deployments

### 🔧 Infrastructure Enhancements
- **Provider Script Improvements**
  - GKE, EKS, and AKS scripts now use environment variables
  - Enhanced error handling and validation
  - Improved logging and status reporting
  - Authentication validation for all cloud providers
  - Better resource configuration and autoscaling settings

### 📚 Documentation & Developer Experience
- **Testing Documentation**
  - Comprehensive testing guide (`tests/README.md`)
  - Local development workflow documentation
  - Troubleshooting guide for common issues
  - Performance benchmarks and success criteria

### 🐛 Bug Fixes
- Fixed nginx permission issues in unprivileged containers
- Resolved middleware dependency installation problems
- Corrected health check endpoints in frontend deployment
- Fixed port binding issues for non-root containers

## v0.1.1-Alpha-POC – July 2025


## 📦 Storm Surge v0.1.1-Alpha-POC

_Released: July 2025_  
This release introduces the first working implementation of the FinOps Controller, early-stage testing harnesses, and updated documentation for extensibility and scaling experiments.

### 🚀 Highlights

- ✅ **Initial FinOps Controller prototype**  
  - `finops/finops_controller.py` includes a scheduled job framework using `schedule`, with stubbed methods for after-hours autoscaling disablement.
  - Placeholder logging and control structure for integrating LaunchDarkly feature flags and Spot Ocean APIs.
  - Prepares ground for real-time cost-aware infrastructure decisions.

- 🧪 **New test harnesses added**
  - `finops/tests/test_basic.py`: Sanity test coverage
  - `finops/tests/test_finops_controller.py`: Unit test skeletons for controller logic
  - `finops/tests/test_integration.py`: Placeholder for full integration tests (coming in v0.1.2)

- 📜 **Documentation Enhancements**
  - `docs/FINOPS.md`: Now includes environment setup, usage guide, and savings expectations across environments.
  - `docs/ARCHITECTURE.md`: Updated to reflect the FinOps Controller as an official component of the system.
  - `docs/REPOSITORY.md`: Clarified dual naming convention (OceanSurge repo, Storm Surge product), and added deploy + access examples.

- 🛠️ **New deployment and chaos tooling**
  - Added `scripts/deploy-finops.sh` to automate FinOps Controller deployment.
  - Introduced `chaos-testing/lightning-strike.sh` for simulating random disruptions (experimental).

- 🧹 **Structural & Naming Fixes**
  - Repo renaming script `fix-repo-naming.sh` included to enforce standard naming conventions across the project.
  - Git utility script `git-storm-surge-create.sh` added for rapid project creation and tagging.