# 🌀 Storm Surge – Changelog

## [Unreleased]

### 🧹 Code Quality & Shell Script Improvements - July 18, 2025

- **Pre-commit Configuration Updates**
  - Updated `.pre-commit-config.yaml` to resolve deprecation warnings
  - Updated `pre-commit-hooks` from v4.6.0 to v5.0.0 (removes deprecated stage names)
  - Updated `yamllint` from v1.35.1 to v1.37.1 for latest validation rules
  - Updated `markdownlint-cli` from v0.41.0 to v0.45.0 for improved markdown linting
  - All pre-commit hooks now run without warnings and support latest features

- **Security Context Enhancements**
  - Added comprehensive security contexts to all deployments in `manifests/base/storm-surge-app.yaml`
  - Implemented `runAsNonRoot: true` and `runAsUser: 65534` for all containers (product-catalog, shopping-cart, frontend)
  - Added pod-level security contexts with `fsGroup: 65534` for proper file permissions
  - Enhanced container security with `allowPrivilegeEscalation: false` and capability dropping
  - All deployments now run as non-root users meeting security best practices

- **Security Validation Script Improvements**
  - Fixed false positive detection in `tests/hooks/validate-security.sh` for non-deployment resources
  - Updated deployment detection logic to check first `kind:` field only: `first_kind=$(grep -m1 '^kind:' "$file" | awk '{print $2}')`
  - Prevents HPA, NetworkPolicy, and other resources from being incorrectly flagged as missing security contexts
  - Enhanced hardcoded secret detection to ignore dummy/example values (dummy, example, changeme, placeholder, test, sample, fake, mock)
  - Reduces false positives from development artifacts while maintaining detection of actual security issues
  - More precise validation reduces noise and focuses on actual deployment security issues
- **Trailing Whitespace Cleanup**
  - Removed trailing whitespace from all project files
  - Fixed `manifests/base/kustomization.yaml`, `tests/hooks/validate-deploy-scripts.sh`, and `git-storm-surge-create.sh`
  - Ensured all 70+ files end with a single newline character for consistent formatting

- **File Permissions Standardization**
  - Made `chaos-testing/lightning-strike.sh` executable with proper permissions
  - Fixed shebang executable status for chaos testing script

- **Offline Manifest Validation**
  - Enhanced `tests/hooks/validate-manifests.sh` to support offline validation
  - Updated `test-local.sh` to use standalone kustomize tool when available
  - Added connectivity detection before attempting server-side validation
  - Implemented graceful fallbacks: full validation → offline validation → basic YAML validation
  - Fixed API server dependency issues for offline environments

- **Comprehensive ShellCheck Compliance (19 Scripts Analyzed)**
  - **Variable Quoting & Safety**: Fixed 15+ variable quoting issues across all scripts
    - Fixed boolean variable tests in `scripts/cleanup/cluster-sweep.sh`
    - Quoted URL variables in curl commands (3 files: fix-repo-naming.sh, git-storm-surge-create.sh, load-test.sh)
    - Fixed function parameter quoting in deployment scripts
    - Enhanced command substitution quoting throughout codebase
  - **Array Operations**: Replaced unsafe array creation with robust methods
    - Used `mapfile -t` instead of `$(...)` arrays in `scripts/deploy.sh`
    - Implemented `read -ra` for safer array creation in `chaos-testing/lightning-strike.sh`
  - **Local Variable Declarations**: Separated 12+ local declarations from assignments
    - Fixed in `scripts/deploy.sh`, `tests/hooks/validate-deploy-scripts.sh`, `tests/test-suite.sh`
    - Prevents masking of return values and improves error detection
  - **Pipeline Subshell Issues**: Rewrote validation functions to avoid variable scope problems
    - Fixed all functions in `tests/hooks/validate-security.sh` using process substitution
    - Replaced pipelines with `< <(...)` pattern for proper variable scoping
  - **Find Command Safety**: Enhanced find operations for special characters
    - Replaced `find ... | xargs` with `find ... -exec ... +` in validation scripts
    - Added `-r` flag to xargs commands for empty input handling
  - **Trap Quoting**: Fixed trap command in `scripts/prod_deploy_preview.sh` (double quotes → single quotes)
  - **Read Command Safety**: Added `-r` flag to 15+ read commands to prevent backslash escaping
  - All critical ShellCheck warnings resolved across entire codebase

### 🧪 Test Coverage & Quality Improvements
- **Comprehensive Test Suite Expansion**
  - Added 24 comprehensive middleware tests covering Flask endpoints, webhook handling, and Spot API integration
  - Implemented 19 security tests for Kubernetes configurations, secrets management, and container security
  - Created 26 script validation tests for deployment scripts, provider scripts, and security compliance
  - Fixed missing dependencies in FinOps controller tests (43 tests now passing)
  - Added virtual environment setup for proper test isolation

### 🔧 FinOps Controller Fixes
- **Missing Manifest Resolution**
  - Created missing `manifests/finops/finops-controller.yaml` file
  - Fixed broken kustomization references in FinOps deployment
  - Added complete Kubernetes deployment manifest with security contexts
  - Integrated ConfigMaps for Python code and configuration
  - Established proper secret management for LaunchDarkly and Spot API credentials

### 🛡️ Security & Validation Enhancements
- **Enhanced Security Testing**
  - Implemented comprehensive security validation for Kubernetes manifests
  - Added container image security checks (no :latest tags, trusted registries)
  - Created script security validation (permissions, credentials, shebangs)
  - Added Dockerfile security practice validation
  - Implemented compliance checks for Pod Security Standards and CIS benchmarks

### 🔧 Script Improvements
- **Cleanup Script Array Matching Fix**
  - Fixed problematic regex-based array matching in `scripts/cleanup/cluster-sweep.sh`
  - Replaced `if [[ ! " ${PROTECTED_NAMESPACES[@]} " =~ " $ns " ]]` with proper loop-based matching
  - Improved reliability and eliminated potential edge cases with special characters
  - Enhanced code clarity and maintainability

- **Script Standards Compliance**
  - Added missing shebang (`#!/bin/bash`) to `scripts/lockitdown.sh`
  - Added `set -e` error handling to `scripts/load-test.sh` and `scripts/lockitdown.sh`
  - Verified all 10 scripts in `/scripts` directory have proper configuration:
    - ✅ All scripts have shebangs
    - ✅ All scripts have error handling (`set -e`)
    - ✅ All scripts are executable
    - ✅ All scripts have valid syntax

- **Python File Permissions Audit**
  - Fixed chmod attributes for middleware and test scripts with shebangs
  - Made executable all Python files with `if __name__ == "__main__"` blocks:
    - `manifests/middleware/main.py` (middleware entry point)
    - `finops/finops_controller.py` (FinOps controller entry point)
    - `finops/tests/test_basic.py`, `test_finops_controller.py`, `test_integration.py`
    - `tests/test_middleware.py`, `test_security.py`, `test_scripts.py`
  - Verified proper permissions: executable files have `rwxr-xr-x`, non-executable have `rw-r--r--`
  - All Python files with shebangs now have correct permissions based on functionality

- **Exit Code Handling Improvements**
  - Eliminated problematic `$?` usage in provider scripts
  - Fixed `retry_command` exit code checking in `scripts/providers/aks.sh`, `gke.sh`, and `eks.sh`
  - Changed from `retry_command ...; if [ $? -eq 0 ]` to `if retry_command ...; then` pattern
  - Improved `$?` usage in `tests/hooks/validate-security.sh` with immediate variable capture
  - All remaining `$?` usages now follow bash best practices for reliable error handling

- **Variable Expansion Security Improvements**
  - Fixed unquoted variables in test expressions in provider scripts
  - Updated `if [ $attempt -lt $max_attempts ]` to `if [ "$attempt" -lt "$max_attempts" ]` in all providers
  - Protected user input variables in error messages with proper quoting
  - Fixed potential command injection in echo statements: `echo "Unknown argument: \"$arg\"`
  - Enhanced bash script security by eliminating dangerous variable expansion patterns

### 📊 Test Results Summary
- **FinOps Tests**: 43/43 tests passing (100% success rate)
- **Middleware Tests**: 21/24 tests passing (87.5% success rate)
- **Security Tests**: 15/19 tests passing (78.9% success rate)
- **Script Tests**: 25/26 tests passing (96.2% success rate)
- **Total Test Coverage**: 104/112 tests passing (92.9% overall success rate)

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
