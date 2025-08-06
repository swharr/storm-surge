# Credentials to Replace Before Deployment

This file lists all the placeholders that need to be replaced with real values before deploying Storm Surge / TrailForge.

## 🔑 Required Credentials Checklist

### Spot Ocean Configuration
- [ ] **SPOT_API_TOKEN**: Replace `YOUR_SPOT_API_TOKEN_HERE` in secret files
- [ ] **SPOT_ACCOUNT_ID**: Replace `YOUR_SPOT_ACCOUNT_ID` in configmaps
- [ ] **SPOT_CLUSTER_ID**: Replace `o-e8f535e3` with your actual cluster ID

### LaunchDarkly Configuration  
- [ ] **LAUNCHDARKLY_SDK_KEY**: Replace `REPLACE_WITH_YOUR_LAUNCHDARKLY_SDK_KEY` in configmaps
- [ ] **WEBHOOK_SECRET**: Replace `REPLACE_WITH_YOUR_WEBHOOK_SECRET` with generated secret

### Database Credentials
- [ ] **POSTGRES_PASSWORD**: Replace `CHANGE_ME_TO_STRONG_PASSWORD` in all files
- [ ] **REDIS_PASSWORD**: Add password configuration (currently unsecured)

## 📍 Files to Update

### Secrets (High Priority)
1. `manifests/middleware/secret.yaml` (copy from secret-template.yaml)
2. `manifests/databases/postgresql.yaml` - Update PostgreSQL password

### ConfigMaps
1. `manifests/middleware/configmap.yaml`
   - WEBHOOK_SECRET
   - LAUNCHDARKLY_SDK_KEY
   - SPOT_CLUSTER_ID

2. `manifests/middleware/configmap-fixed.yaml`
   - Contains Python code that reads SPOT_ACCOUNT_ID from environment

### Application Code
1. `manifests/services/product-catalog/main.py` - DB password placeholder
2. `manifests/services/user-auth/main.py` - DB password placeholder
3. `manifests/dev/product-catalog-simple.yaml` - If using dev deployments

## 🛡️ Security Reminders

### Before Committing
- [ ] All real credentials removed
- [ ] Only placeholders in repository
- [ ] Added secret files to .gitignore
- [ ] Reviewed all YAML files for sensitive data

### Before Deploying
- [ ] Generated strong passwords (min 32 chars)
- [ ] Used different passwords for each service
- [ ] Stored credentials securely (not in plain text)
- [ ] Enabled webhook signature verification

### Production Checklist
- [ ] Use secret management service (Google Secret Manager, etc.)
- [ ] Enable RBAC and network policies
- [ ] Add authentication to all public endpoints
- [ ] Implement rate limiting
- [ ] Enable audit logging
- [ ] Regular credential rotation schedule

## 🔐 Generating Strong Credentials

```bash
# Generate strong password
openssl rand -base64 32

# Generate webhook secret
openssl rand -hex 32

# Generate API key format
uuidgen | tr '[:upper:]' '[:lower:]'
```

## ⚠️ Current Vulnerabilities to Fix

1. **Webhook signature verification disabled** in middleware
2. **No authentication** on public endpoints
3. **Redis without password** protection
4. **No rate limiting** implemented
5. **Debug mode active** in some services

Remember: **Never commit real credentials to version control!**