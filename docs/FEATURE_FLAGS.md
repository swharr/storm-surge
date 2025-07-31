# Feature Flag Configuration

This document explains how to configure feature flag integrations with Storm Surge's middleware layer.

## Overview

Storm Surge supports integration with feature flag providers to trigger cost optimization actions based on feature flag changes. Currently supported providers:

- **LaunchDarkly** - Enterprise feature management platform
- **Statsig** - Feature flagging and experimentation platform

## Quick Start

### 1. Deploy Base Application First

```bash
# Deploy the base Storm Surge application
kubectl apply -k manifests/base/
```

### 2. Configure Feature Flags

Use the standalone configuration script to set up your feature flag integration:

```bash
# Interactive configuration
./scripts/configure-feature-flags.sh

# Or configure LaunchDarkly with command-line arguments
./scripts/configure-feature-flags.sh \
    --provider=launchdarkly \
    --ld-sdk-key="sdk-your-key-here" \
    --spot-token="Bearer act-your-token-here" \
    --yes
```

### 3. Test Configuration

```bash
# Test the current configuration
./scripts/configure-feature-flags.sh --test
```

## Configuration Options

### Interactive Mode

Run the script without arguments for guided setup:

```bash
./scripts/configure-feature-flags.sh
```

This will prompt you for:
- Feature flag provider selection (LaunchDarkly, Statsig, or both)
- API keys and tokens
- Webhook security settings

### Command Line Mode

Available options:

- `--provider=PROVIDER` - Choose `launchdarkly`, `statsig`, or `both`
- `--ld-sdk-key=KEY` - LaunchDarkly SDK key
- `--statsig-key=KEY` - Statsig server secret key
- `--spot-token=TOKEN` - Spot.io API token
- `--webhook-secret=SECRET` - Custom webhook secret
- `--test` - Test current configuration
- `--yes` - Skip confirmation prompts

### Examples

```bash
# Configure LaunchDarkly only
./scripts/configure-feature-flags.sh \
    --provider=launchdarkly \
    --ld-sdk-key="sdk-12345678-1234-1234-1234-123456789012" \
    --spot-token="Bearer act-your-spot-token-here"

# Configure both providers
./scripts/configure-feature-flags.sh \
    --provider=both \
    --ld-sdk-key="sdk-your-ld-key-here" \
    --statsig-key="secret-your-statsig-key-here" \
    --spot-token="Bearer act-your-spot-token-here"

# Test existing configuration
./scripts/configure-feature-flags.sh --test
```

## Finding Your API Keys

### LaunchDarkly SDK Key

1. Log in to [LaunchDarkly](https://app.launchdarkly.com)
2. Go to **Settings** → **Projects**
3. Select your project
4. Copy the **SDK key** for your environment
5. Format: `sdk-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`

### Statsig Server Key

1. Log in to [Statsig Console](https://console.statsig.com)
2. Go to **Settings** → **API Keys**
3. Copy your **Server Secret Key**
4. Format: `secret-xxxxxxxxxxxxxxxxxxxxxxxxxxxxx`

### Spot.io API Token

1. Log in to [Spot Console](https://console.spotinst.com)
2. Go to **Settings** → **API** → **Tokens**
3. Create or copy an existing token
4. Format: `Bearer act-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`

## Webhook Configuration

After configuring the integration, you'll need to set up webhooks in your feature flag provider:

### LaunchDarkly Webhooks

1. In LaunchDarkly, go to **Settings** → **Integrations** → **Webhooks**
2. Create a new webhook with:
   - **URL**: `http://your-load-balancer/webhook/launchdarkly`
   - **Secret**: Use the webhook secret from your configuration
   - **Events**: Select flag change events you want to monitor

### Statsig Webhooks

1. In Statsig, go to **Settings** → **Webhooks**
2. Create a new webhook with:
   - **URL**: `http://your-load-balancer/webhook/statsig`
   - **Secret**: Use the webhook secret from your configuration
   - **Events**: Select the events you want to monitor

## Troubleshooting

### Check Pod Status

```bash
kubectl get pods -n oceansurge -l app=feature-flag-middleware
```

### View Logs

```bash
kubectl logs -n oceansurge -l app=feature-flag-middleware -f
```

### Test Health Endpoint

```bash
kubectl port-forward -n oceansurge svc/feature-flag-middleware 8080:80
curl http://localhost:8080/health
```

### Reconfigure

You can reconfigure at any time by running the configuration script again:

```bash
./scripts/configure-feature-flags.sh
```

This will update the existing configuration without disrupting other services.

## Integration with Deployment

The configuration script is separate from the main deployment process, allowing you to:

1. Deploy Storm Surge without feature flag configuration
2. Configure feature flags later when ready
3. Reconfigure or switch providers without redeploying
4. Test configurations independently

## Security Notes

- API keys and tokens are stored as Kubernetes secrets
- Webhook secrets provide additional security for incoming requests
- All sensitive values are masked in logs and output
- Use strong, unique webhook secrets for production deployments