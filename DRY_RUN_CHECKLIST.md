# Storm Surge Dry Run Checklist

## ✅ Completed Setup Tasks

1. **SDK Installation Structure**
   - Created separate requirements files for LaunchDarkly and Statsig
   - Updated Dockerfile for conditional SDK installation based on build args
   - Fixed all SDK dependencies and version conflicts

2. **Frontend SDK Integration**
   - Implemented complete FeatureFlagProvider with both LaunchDarkly and Statsig support
   - Added proper tracking ID configuration for LaunchDarkly
   - Implemented security-first dummy variables (CHANGEME_*_123456789 pattern)
   - Fixed all TypeScript compilation errors
   - Successfully built frontend (npm run build passes)

3. **Backend SDK Integration**
   - Rewrote feature_flags.py with actual SDK integration (not just webhook parsing)
   - Added proper SDK initialization, flag evaluation, and resource cleanup
   - Implemented conditional imports with error handling

4. **Setup Scripts**
   - Created interactive-frontend-setup.sh for guided configuration
   - Created setup-middleware.sh for backend configuration
   - Added build-middleware.sh with provider-specific Docker builds
   - All scripts tested and working with dummy values

5. **Security Implementation**
   - All dummy variables use obvious CHANGEME_*_123456789 pattern
   - Environment validation detects and warns about dummy values
   - Proper .env.local file generation with security warnings

## 🚀 Ready for Dry Run

### Frontend Test Steps:
1. The frontend dev server is already running at http://localhost:3000
2. Open browser console and look for:
   - "LaunchDarkly client initialized" or "Statsig client initialized"
   - Warning about tracking ID if using dummy values
   - No critical errors

### Backend Test Steps:
1. Start Docker Desktop
2. Build middleware: `./build-middleware.sh --provider launchdarkly`
3. Run setup: `./setup-middleware.sh launchdarkly YOUR_SDK_KEY YOUR_WEBHOOK_SECRET`

### GKE Deployment Steps:
1. Clean existing environment if desired:
   ```bash
   kubectl delete namespace storm-surge
   ```

2. Create secrets with real values:
   ```bash
   kubectl create namespace storm-surge
   kubectl -n storm-surge create secret generic storm-surge-feature-flags \
     --from-literal=provider=launchdarkly \
     --from-literal=launchdarkly_sdk_key=YOUR_REAL_SDK_KEY \
     --from-literal=launchdarkly_webhook_secret=YOUR_REAL_WEBHOOK_SECRET
   ```

3. Deploy Storm Surge:
   ```bash
   # Build and push images
   ./build-middleware.sh --provider launchdarkly --registry YOUR_REGISTRY --push
   cd frontend && ./build-and-push.sh YOUR_REGISTRY
   
   # Deploy to GKE
   kubectl apply -k manifests/base
   kubectl apply -k manifests/middleware
   ```

4. Verify deployment:
   ```bash
   kubectl -n storm-surge get pods
   kubectl -n storm-surge logs deployment/storm-surge-middleware
   ```

## 🔍 What to Look For

### Success Indicators:
- Feature flag client initializes without errors
- No "CHANGEME" warnings in production logs
- Webhook endpoints respond correctly
- Feature flags can be toggled and changes propagate

### Common Issues to Check:
- SDK keys are valid and not dummy values
- Provider selection matches between frontend and backend
- Webhook secrets match between provider dashboard and deployment
- CORS settings allow frontend to communicate with backend

## 📝 Test Feature Flags

1. **LaunchDarkly**: Create flag named `enable-cost-optimizer`
2. **Statsig**: Create gate named `enable_cost_optimizer`
3. Toggle the flag and verify changes propagate to the application

## 🔐 Security Checklist

- [ ] Replace all CHANGEME_*_123456789 values with real keys
- [ ] Never commit .env.local files
- [ ] Use different keys for dev/staging/prod
- [ ] Enable webhook signature validation
- [ ] Review RBAC permissions in Kubernetes