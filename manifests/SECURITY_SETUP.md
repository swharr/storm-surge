# Security Setup Guide for Storm Surge / TrailForge

## 🔒 Important Security Notice

This repository has been sanitized to remove all sensitive credentials. Before deploying, you must configure your own secrets and API keys.

## 📋 Required Credentials

### 1. Spot Ocean Credentials
- **API Token**: Get from [Spot Console](https://console.spotinst.com/)
- **Account ID**: Found in your Spot account settings (format: `act-xxxxxxxx`)
- **Cluster ID**: Created when you connect your Kubernetes cluster (format: `o-xxxxxxxx`)

### 2. LaunchDarkly Credentials
- **SDK Key**: Get from LaunchDarkly project settings
- **API Key**: For API access (if needed)
- **Webhook Secret**: Generate using `openssl rand -hex 32`

### 3. Database Credentials
- **PostgreSQL Password**: Generate using `openssl rand -base64 32`
- **Redis Password**: Generate using `openssl rand -base64 32`

## 🚀 Setup Instructions

### Step 1: Copy Template Files
```bash
cp manifests/middleware/secret-template.yaml manifests/middleware/secret.yaml
```

### Step 2: Replace Placeholders
Edit `manifests/middleware/secret.yaml` and replace:
- `YOUR_SPOT_API_TOKEN_HERE` → Your actual Spot API token
- `YOUR_LAUNCHDARKLY_SDK_KEY_HERE` → Your LaunchDarkly SDK key
- `YOUR_WEBHOOK_SECRET_HERE` → Generated webhook secret
- `CHANGE_THIS_TO_A_STRONG_PASSWORD` → Strong PostgreSQL password

### Step 3: Update ConfigMaps
Edit the following files to add your IDs:
- `manifests/middleware/configmap.yaml`
  - Replace `REPLACE_WITH_YOUR_WEBHOOK_SECRET`
  - Replace `REPLACE_WITH_YOUR_LAUNCHDARKLY_SDK_KEY`
  - Update `SPOT_CLUSTER_ID` with your cluster ID
  
### Step 4: Update Account IDs in Code
In `manifests/middleware/configmap-fixed.yaml`, the code now reads:
```python
account_id = os.getenv('SPOT_ACCOUNT_ID', 'YOUR_SPOT_ACCOUNT_ID')
```

Add your Spot account ID to the environment variables or ConfigMap.

## 🛡️ Security Best Practices

### Never Commit Secrets
- Add `**/secret.yaml` to `.gitignore`
- Use environment variables or secret management tools
- Rotate credentials regularly

### Enable Webhook Signature Verification
The middleware currently has signature verification disabled for debugging. To enable:

1. Remove the debug warning in the webhook handler
2. Implement proper HMAC verification:
```python
def verify_signature(payload, signature, secret):
    expected = hmac.new(
        secret.encode(),
        payload,
        hashlib.sha256
    ).hexdigest()
    return hmac.compare_digest(expected, signature)
```

### Use Strong Passwords
Generate strong passwords using:
```bash
# For passwords
openssl rand -base64 32

# For secrets/tokens
openssl rand -hex 32
```

### Implement Network Policies
Create network policies to restrict pod-to-pod communication:
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-ingress
  namespace: oceansurge
spec:
  podSelector: {}
  policyTypes:
  - Ingress
```

### Add Authentication
Consider adding:
- API key authentication for the middleware
- OAuth2/JWT for frontend services
- Rate limiting to prevent abuse

## 📝 Credential Checklist

Before deploying, ensure you have:
- [ ] Spot API Token
- [ ] Spot Account ID
- [ ] Spot Cluster ID
- [ ] LaunchDarkly SDK Key
- [ ] Webhook Secret (generated)
- [ ] PostgreSQL Password (strong)
- [ ] Updated all placeholders in YAML files
- [ ] Enabled webhook signature verification
- [ ] Added secret files to .gitignore

## ⚠️ Security Warnings

1. **This is a demo application** - Additional security hardening needed for production
2. **All endpoints are public** - Add authentication before production use
3. **Secrets in ConfigMaps** - Use proper secret management in production
4. **No rate limiting** - Add rate limiting to prevent abuse
5. **Debug mode active** - Remove debug code before production

## 🔐 Recommended Production Security

1. Use Google Secret Manager or similar
2. Enable Pod Security Standards
3. Implement RBAC properly
4. Use private GKE clusters
4. Enable Binary Authorization
5. Implement proper logging and monitoring
6. Regular security scanning
7. Automated credential rotation

Remember: **Security is not optional!**