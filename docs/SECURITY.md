# Storm Surge Security Guidelines

This document outlines security best practices for Storm Surge, with a focus on protecting sensitive configuration data and API keys.

## 🔒 API Key Security

### Why We Use Dummy Variables

Storm Surge uses obvious dummy variables throughout the codebase to prevent accidental exposure of sensitive information:

```typescript
// ✅ SECURE - Uses obvious dummy variable
const LAUNCHDARKLY_CLIENT_ID = import.meta.env.VITE_LAUNCHDARKLY_CLIENT_ID || 'CHANGEME_LAUNCHDARKLY_CLIENT_ID_123456789';

// ❌ INSECURE - Could accidentally expose real keys
const LAUNCHDARKLY_CLIENT_ID = import.meta.env.VITE_LAUNCHDARKLY_CLIENT_ID || '64f4c8a07e15b70c9d123456';
```

### Dummy Variable Patterns

All dummy variables in Storm Surge follow this pattern:
- `CHANGEME_[SERVICE]_[TYPE]_123456789`
- Examples:
  - `CHANGEME_LAUNCHDARKLY_CLIENT_ID_123456789`
  - `CHANGEME_STATSIG_CLIENT_KEY_123456789`
  - `CHANGEME_TRACKING_ID_123456789`
  - `CHANGEME_EVENT_NAME_123456789`

### Detection Mechanisms

The application automatically detects dummy variables and prevents initialization:

```typescript
// Frontend validation
if (!LAUNCHDARKLY_CLIENT_ID || LAUNCHDARKLY_CLIENT_ID.includes('CHANGEME')) {
  console.error('LaunchDarkly client ID not configured. Set VITE_LAUNCHDARKLY_CLIENT_ID environment variable.');
  return <div>Feature flag configuration error: LaunchDarkly client ID not set (using dummy value)</div>;
}
```

```python
# Backend validation
if not self.sdk_key:
    raise ValueError("LaunchDarkly SDK key is required")
```

## 🛡️ Environment Variable Security

### Secure Configuration Files

1. **Never commit real keys to version control**
2. **Use `.env.local` for local development**
3. **Use environment-specific files for deployment**

```bash
# ✅ SECURE - These files should be in .gitignore
.env.local
.env.production
.env.staging

# ✅ SECURE - These files contain only dummy values
.env.example
.env.local.example
```

### Environment Variable Hierarchy

Storm Surge follows this environment variable hierarchy:

1. **System environment variables** (highest priority)
2. **`.env.local`** (local development)
3. **`.env.[NODE_ENV]`** (environment-specific)
4. **`.env`** (defaults)
5. **Hardcoded dummy values** (lowest priority)

### Required Environment Variables

#### Frontend
```bash
# Feature Flag Provider
VITE_FEATURE_FLAG_PROVIDER=launchdarkly  # or 'statsig'

# LaunchDarkly (if using LaunchDarkly)
VITE_LAUNCHDARKLY_CLIENT_ID=your_actual_client_id_here

# Statsig (if using Statsig)
VITE_STATSIG_CLIENT_KEY=client-your_actual_key_here
```

#### Backend
```bash
# Feature Flag Provider
FEATURE_FLAG_PROVIDER=launchdarkly  # or 'statsig'

# LaunchDarkly (if using LaunchDarkly)
LAUNCHDARKLY_SDK_KEY=sdk-your_actual_sdk_key_here

# Statsig (if using Statsig)
STATSIG_SERVER_KEY=secret-your_actual_server_key_here

# Common
WEBHOOK_SECRET=your_webhook_secret_here
SPOT_API_TOKEN=your_spot_api_token_here
SPOT_CLUSTER_ID=your_cluster_id_here
```

## 🔧 Kubernetes Security

### Secret Management

Store sensitive data in Kubernetes Secrets:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: storm-surge-secrets
  namespace: storm-surge
type: Opaque
stringData:
  ld-sdk-key: "sdk-actual-key-here"
  statsig-server-key: "secret-actual-key-here"
  webhook-secret: "actual-webhook-secret-here"
  spot-api-token: "actual-spot-token-here"
```

### RBAC Configuration

Limit access to secrets with proper RBAC:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: storm-surge-secret-reader
rules:
- apiGroups: [""]
  resources: ["secrets"]
  resourceNames: ["storm-surge-secrets"]
  verbs: ["get", "list"]
```

## 🚨 Security Checklist

### Before Deployment

- [ ] **Environment Variables**: All dummy variables replaced with real values
- [ ] **Secrets**: Stored in secure secret management system
- [ ] **Network Policies**: Restrict communication between components
- [ ] **RBAC**: Proper permissions configured
- [ ] **TLS**: All communication encrypted
- [ ] **Webhooks**: Signature verification enabled

### Code Review Checklist

- [ ] **No hardcoded secrets** in source code
- [ ] **Dummy variables** used for all examples
- [ ] **Environment variable validation** implemented
- [ ] **Error messages** don't expose sensitive information
- [ ] **Logging** doesn't contain secrets or PII

### Monitoring and Alerting

- [ ] **Failed authentication** alerts configured
- [ ] **Unusual API usage** monitoring enabled
- [ ] **Secret rotation** procedures documented
- [ ] **Access logs** monitored for suspicious activity

## 🔄 Secret Rotation

### LaunchDarkly Keys

1. Generate new SDK key in LaunchDarkly dashboard
2. Update environment variables/secrets
3. Deploy new configuration
4. Verify connectivity
5. Revoke old key

### Statsig Keys

1. Generate new server key in Statsig console
2. Update environment variables/secrets
3. Deploy new configuration
4. Verify connectivity
5. Revoke old key

### Webhook Secrets

1. Generate new webhook secret
2. Update Storm Surge configuration
3. Update provider webhook configuration
4. Verify webhook processing
5. Remove old secret

## 🚫 What NOT to Do

### ❌ Never Do These Things

```typescript
// ❌ DON'T: Hardcode real API keys
const API_KEY = 'sdk-12345678-1234-1234-1234-123456789abc';

// ❌ DON'T: Use realistic-looking dummy data
const CLIENT_ID = '64f4c8a07e15b70c9d123456';

// ❌ DON'T: Log sensitive information
console.log('API Key:', process.env.API_KEY);

// ❌ DON'T: Expose keys in error messages
throw new Error(`Authentication failed with key: ${apiKey}`);

// ❌ DON'T: Store secrets in configuration files
const config = {
  apiKey: 'actual-secret-key-here'
};
```

### ✅ Do These Instead

```typescript
// ✅ DO: Use obvious dummy variables
const API_KEY = process.env.API_KEY || 'CHANGEME_API_KEY_123456789';

// ✅ DO: Validate configuration
if (!API_KEY || API_KEY.includes('CHANGEME')) {
  throw new Error('API key not configured');
}

// ✅ DO: Log safely
console.log('API Key configured:', !!process.env.API_KEY);

// ✅ DO: Use generic error messages
throw new Error('Authentication failed - check your API key configuration');

// ✅ DO: Load from environment
const config = {
  apiKey: process.env.API_KEY
};
```

## 📱 Development Workflow

### Local Development

1. **Copy environment template**:
   ```bash
   cp frontend/.env.local.example frontend/.env.local
   ```

2. **Update with real values**:
   ```bash
   # Edit .env.local with your actual keys
   VITE_LAUNCHDARKLY_CLIENT_ID=your_real_client_id
   ```

3. **Verify configuration**:
   ```bash
   npm run dev
   # Check console for proper initialization
   ```

### Staging/Production Deployment

1. **Use secret management**:
   ```bash
   kubectl create secret generic storm-surge-secrets \
     --from-literal=ld-sdk-key="your_real_sdk_key"
   ```

2. **Deploy with secrets**:
   ```bash
   kubectl apply -k manifests/middleware/
   ```

3. **Verify deployment**:
   ```bash
   kubectl logs deployment/storm-surge-middleware
   ```

## 🔍 Security Monitoring

### Log Analysis

Monitor logs for these security indicators:

```bash
# Failed authentications
grep "authentication failed" /var/log/storm-surge.log

# Dummy variable usage
grep "CHANGEME" /var/log/storm-surge.log

# Webhook signature failures
grep "Invalid webhook signature" /var/log/storm-surge.log
```

### Metrics to Monitor

- Authentication failure rates
- Unusual API request patterns
- Failed webhook verifications
- Configuration errors

## 📞 Incident Response

### If Keys Are Compromised

1. **Immediately revoke** compromised keys
2. **Generate new keys** in provider dashboards
3. **Update all deployments** with new keys
4. **Monitor for unauthorized usage**
5. **Document the incident**

### If Dummy Keys Are in Production

1. **Check application logs** for initialization errors
2. **Update environment configuration** immediately
3. **Restart affected services**
4. **Verify proper functionality**

## 📚 Additional Resources

- [LaunchDarkly Security Documentation](https://docs.launchdarkly.com/home/account-security)
- [Statsig Security Best Practices](https://docs.statsig.com/guides/security)
- [Kubernetes Secrets Documentation](https://kubernetes.io/docs/concepts/configuration/secret/)
- [OWASP API Security Top 10](https://owasp.org/www-project-api-security/)

---

**Remember**: Security is everyone's responsibility. When in doubt, use dummy variables and validate all configuration before deployment.