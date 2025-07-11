# Storm Surge Test Suite

Comprehensive testing framework for validating Storm Surge deployments before production.

## 🧪 Test Components

### 1. Local Quick Tests (`test-local.sh`)
Fast validation for development workflow:
```bash
./test-local.sh
```

**Tests:**
- Script syntax validation
- Parameter validation
- Zone/region validation
- Kubernetes manifest validation
- Security configuration checks
- Hardcoded secrets detection

### 2. Full Test Suite (`tests/test-suite.sh`)
Complete minikube-based testing:
```bash
./tests/test-suite.sh
```

**Features:**
- Spins up local minikube cluster
- Deploys full application stack
- Tests health endpoints
- Validates resource constraints
- Checks security contexts
- Generates detailed reports

### 3. Pre-commit Hooks
Automated validation on every commit:
```bash
pip install pre-commit
pre-commit install
```

**Hooks:**
- Kubernetes manifest validation
- Deployment script validation
- Security validation
- Shell script linting (shellcheck)
- YAML validation
- Markdown linting

### 4. GitHub Actions CI/CD
Automated testing on push/PR:
- Pre-commit validation
- Minikube deployment tests
- Multi-cloud script validation
- Security scanning (Trivy)
- Documentation validation
- Release readiness checks

## 🚀 Quick Start

### Prerequisites
```bash
# Install required tools
brew install minikube kubectl
pip install pre-commit

# For security scanning
brew install trivy
```

### Run Tests

1. **Quick validation:**
   ```bash
   ./test-local.sh
   ```

2. **Full test suite:**
   ```bash
   ./tests/test-suite.sh
   ```

3. **Install pre-commit hooks:**
   ```bash
   pre-commit install
   pre-commit run --all-files
   ```

## 📊 Test Reports

Test results are saved in `test-logs/`:
- `test-report.md` - Summary report
- `minikube-start.log` - Cluster setup logs
- `base-deploy.log` - Base deployment logs
- `middleware-deploy.log` - Middleware deployment logs
- `*-health.log` - Health check results

## 🔧 Test Configuration

### Minikube Settings
```bash
# Default test cluster specs
MINIKUBE_PROFILE="storm-surge-test"
CPUS=4
MEMORY=8192MB
DISK=20GB
```

### Environment Variables
```bash
# Override test settings
export TEST_NAMESPACE="custom-test"
export TIMEOUT=600
export LOG_DIR="custom-logs"
```

## 🎯 Test Coverage

### ✅ Validated Components
- [x] Kubernetes manifests (syntax & deployment)
- [x] Deployment scripts (all cloud providers)
- [x] Security contexts (non-root, resource limits)
- [x] Health endpoints
- [x] Resource constraints
- [x] Zone/region validation
- [x] Parameter validation
- [x] Secret management

### 🔄 Continuous Integration
- [x] Pre-commit hooks
- [x] GitHub Actions workflow
- [x] Security scanning
- [x] Documentation validation
- [x] Multi-cloud validation
- [x] Release readiness checks

## 🛠️ Development Workflow

### Before Committing
```bash
# 1. Run quick tests
./test-local.sh

# 2. Run full test suite (optional)
./tests/test-suite.sh

# 3. Commit (pre-commit hooks will run automatically)
git add .
git commit -m "your message"
```

### Adding New Tests

1. **Add manifest validation:**
   ```bash
   # Edit tests/hooks/validate-manifests.sh
   ```

2. **Add script validation:**
   ```bash
   # Edit tests/hooks/validate-deploy-scripts.sh
   ```

3. **Add security checks:**
   ```bash
   # Edit tests/hooks/validate-security.sh
   ```

## 🔍 Troubleshooting

### Common Issues

**Minikube won't start:**
```bash
minikube delete -p storm-surge-test
minikube start -p storm-surge-test --cpus=2 --memory=4096
```

**kubectl context issues:**
```bash
kubectl config use-context storm-surge-test
```

**Pre-commit hook failures:**
```bash
# Skip hooks temporarily
git commit --no-verify -m "message"

# Fix and re-run
pre-commit run --all-files
```

### Test Debugging

**View test logs:**
```bash
ls test-logs/
cat test-logs/test-report.md
```

**Check pod status:**
```bash
kubectl get pods -n storm-surge-test
kubectl logs -n storm-surge-test <pod-name>
```

**Manual minikube testing:**
```bash
minikube profile storm-surge-test
minikube dashboard
```

## 📈 Performance Benchmarks

### Test Suite Timing
- Quick tests: ~30 seconds
- Full test suite: ~5-10 minutes
- Pre-commit hooks: ~1-2 minutes
- GitHub Actions: ~15-20 minutes

### Resource Usage
- Minikube cluster: 4 CPUs, 8GB RAM
- Test pods: ~200m CPU, ~1GB RAM total
- Disk usage: ~2GB for container images

## 🎉 Success Criteria

All tests must pass for production deployment:
- ✅ All scripts have valid syntax
- ✅ Parameter validation working
- ✅ Kubernetes manifests deploy successfully
- ✅ All pods reach ready state
- ✅ Health endpoints respond
- ✅ Security contexts configured properly
- ✅ No hardcoded secrets detected
- ✅ Resource limits defined

## 📚 Additional Resources

- [Minikube Documentation](https://minikube.sigs.k8s.io/docs/)
- [Pre-commit Documentation](https://pre-commit.com/)
- [Kubernetes Testing Best Practices](https://kubernetes.io/docs/concepts/cluster-administration/manage-deployment/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)