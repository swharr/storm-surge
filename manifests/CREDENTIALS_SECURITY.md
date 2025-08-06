# Credentials and Security Management

## Security Overview

This document outlines the secure credential management practices implemented in Storm Surge to prevent exposure of sensitive information.

## Credential Management Strategy

All sensitive credentials use one of the following secure patterns:

### 1. Environment Variable Injection (Runtime)
```bash
# All passwords default to empty strings, requiring runtime injection
password=os.getenv('POSTGRES_PASSWORD', '')
```

### 2. Obvious Placeholder Values
```yaml
# Template values that are clearly placeholders
stringData:
  POSTGRES_PASSWORD: "REPLACE_WITH_SECURE_PASSWORD"
  REDIS_PASSWORD: "SET_VIA_ENVIRONMENT_VARIABLE"
```

### 3. Generated at Deployment Time
```bash
# Setup script generates secure random values
JWT_SECRET=$(openssl rand -base64 32)
DB_PASSWORD=$(openssl rand -base64 32)
```

## Security Implementation

### Database Credentials
- **PostgreSQL**: Template uses `REPLACE_WITH_SECURE_PASSWORD` placeholder
- **Redis**: Template uses `REPLACE_WITH_SECURE_PASSWORD` placeholder  
- **Application code**: Defaults to empty string, requires environment injection

### Authentication Secrets
- **JWT Secrets**: Generated with cryptographically secure random values
- **Admin Passwords**: Generated with secure random values  
- **Webhook Secrets**: Generated with secure random values

### API Keys and Tokens
- **LaunchDarkly**: Uses environment variable `LAUNCHDARKLY_SDK_KEY`
- **Spot API**: Uses environment variable `SPOT_API_TOKEN`
- **Custom API Keys**: Use placeholder pattern `REPLACE_WITH_YOUR_API_KEY`

## Deployment Security

### Setup Script (`setup.sh`)
The setup script automatically:
1. Generates cryptographically secure secrets
2. Creates Kubernetes secrets with proper values
3. Updates configuration templates with actual credentials
4. Stores credentials securely in `manifests/secrets/.env`

### Manual Deployment
For manual deployments, follow these steps:

```bash
# 1. Generate secure passwords
export POSTGRES_PASSWORD=$(openssl rand -base64 32)
export REDIS_PASSWORD=$(openssl rand -base64 32)
export JWT_SECRET=$(openssl rand -base64 64)
export ADMIN_PASSWORD=$(openssl rand -base64 16)

# 2. Create Kubernetes secrets
kubectl create secret generic postgresql-secret \
  --from-literal=POSTGRES_PASSWORD="$POSTGRES_PASSWORD"

kubectl create secret generic redis-secret \
  --from-literal=REDIS_PASSWORD="$REDIS_PASSWORD"

kubectl create secret generic app-secrets \
  --from-literal=JWT_SECRET="$JWT_SECRET" \
  --from-literal=ADMIN_PASSWORD="$ADMIN_PASSWORD"

# 3. Update configuration files
sed -i "s/REPLACE_WITH_SECURE_PASSWORD/$POSTGRES_PASSWORD/g" manifests/databases/postgresql.yaml
sed -i "s/REPLACE_WITH_SECURE_PASSWORD/$REDIS_PASSWORD/g" manifests/databases/redis.yaml
```

## GitHub Security Scanner Compliance

To prevent GitHub credential detection warnings:

### Safe Patterns
- Empty string defaults: `password=os.getenv('PASSWORD', '')`
- Clear placeholders: `REPLACE_WITH_SECURE_PASSWORD`
- Environment references: `$__file{/etc/secrets/password}`
- Command examples: `$(openssl rand -base64 32)` (in documentation)

### Avoided Patterns  
- Real-looking passwords: `admin123`, `password123`
- Base64 encoded real passwords
- Hardcoded API keys or tokens
- Default database passwords

## Security Validation

Run the following commands to verify no credentials are exposed:

```bash
# Check for hardcoded passwords
grep -r "password.*=" manifests/ --exclude="*.md" | grep -v "REPLACE_WITH\|os.getenv\|openssl rand"

# Check for hardcoded API keys  
grep -r "api.*key.*=" manifests/ --exclude="*.md" | grep -v "REPLACE_WITH\|os.getenv"

# Check for hardcoded secrets
grep -r "secret.*=" manifests/ --exclude="*.md" | grep -v "REPLACE_WITH\|os.getenv\|openssl rand"
```

## Production Deployment Checklist

Before deploying to production:

- [ ] All template placeholders have been replaced
- [ ] Environment variables are properly set
- [ ] Kubernetes secrets are created with secure values
- [ ] No hardcoded credentials remain in configuration files
- [ ] Credential rotation procedures are documented
- [ ] Access to credential storage is properly restricted

## Credential Rotation

For production environments, implement regular credential rotation:

1. **Database Passwords**: Rotate quarterly
2. **API Keys**: Rotate based on provider recommendations  
3. **JWT Secrets**: Rotate monthly
4. **SSL Certificates**: Auto-renewal configured

## Incident Response

If credentials are accidentally exposed:

1. **Immediate**: Rotate all affected credentials
2. **Audit**: Check access logs for unauthorized usage
3. **Update**: Deploy new credentials to all environments
4. **Review**: Update processes to prevent future exposure

This security framework ensures Storm Surge maintains enterprise-grade credential security while preventing false positives from automated security scanners.