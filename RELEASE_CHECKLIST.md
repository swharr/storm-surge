# Storm Surge Release Checklist

## Pre-Release Verification

### Code Quality
- [ ] All tests passing (`./tests/test-local.sh`)
- [ ] No hardcoded credentials
- [ ] Security scan clean (GitHub Actions)
- [ ] Version consistency across files

### Documentation
- [ ] README.md updated with latest features
- [ ] CHANGELOG.md updated with release notes
- [ ] API documentation current
- [ ] Deployment guide reviewed

### Infrastructure
- [ ] AWS IAM policies tested
- [ ] GCP IAM policies tested
- [ ] Azure RBAC policies tested
- [ ] Multi-cloud deployments verified

### New Features (v1.2.0)
- [ ] pstats.sh platform status script tested
- [ ] Cost tracking functionality verified
- [ ] Professional documentation standards met
- [ ] Security hardening applied

## Release Process

1. **Version Update**
   ```bash
   ./scripts/package-release.sh dev-v1.2.0-internal
   ```

2. **Final Testing**
   - Deploy to test environment
   - Run full test suite
   - Verify all cloud providers

3. **Git Operations**
   ```bash
   git add -A
   git commit -m "Release dev-v1.2.0-internal"
   git push origin dev
   ```

4. **Create Release**
   - Push tag: `git push origin dev-v1.2.0-internal`
   - Create GitHub release
   - Upload archives from `dist/`

5. **Post-Release**
   - [ ] Announce release
   - [ ] Update documentation site
   - [ ] Monitor for issues

## Distribution Contents

### Core Components
- Kubernetes manifests (base, dev, production)
- Multi-cloud infrastructure configs
- Security policies and hardening
- IAM/RBAC policies

### Tools & Scripts
- setup.sh - Interactive deployment
- pstats.sh - Platform status monitoring
- cleanup scripts - Resource management
- package-release.sh - Release packaging

### Documentation
- README.md - Project overview
- DEPLOYMENT_GUIDE.md - Deployment instructions
- CREDENTIALS_SECURITY.md - Security guidelines
- CHANGELOG.md - Version history

## Security Considerations
- No secrets in repository
- Runtime secret generation
- Secure defaults everywhere
- Professional enterprise standards

---
Last Updated: $(date '+%Y-%m-%d')