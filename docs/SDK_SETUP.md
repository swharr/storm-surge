# Storm Surge SDK Setup Guide

This guide covers the proper installation and configuration of LaunchDarkly and Statsig SDKs for Storm Surge.

## Overview

Storm Surge supports both LaunchDarkly and Statsig as feature flag providers. The setup has been designed to:

1. **Conditionally install SDKs** - Only install the SDK for your chosen provider
2. **Proper error handling** - Graceful fallbacks when SDKs are not available
3. **Docker optimization** - Provider-specific Docker builds to minimize image size
4. **Easy switching** - Simple configuration to change providers

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                Storm Surge Setup                       │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌─────────────────┐    ┌─────────────────────────────┐ │
│  │  Configuration  │    │     Provider Selection      │ │
│  │     Script      │────►                             │ │
│  │                 │    │  ┌─────────────────────────┐ │ │
│  └─────────────────┘    │  │     LaunchDarkly        │ │ │
│           │              │  │                         │ │ │
│           │              │  │ • Install LD SDK        │ │ │
│           ▼              │  │ • Configure client      │ │ │
│  ┌─────────────────┐    │  │ • Set up webhooks       │ │ │
│  │   Dependencies  │    │  └─────────────────────────┘ │ │
│  │   Installation  │    │                             │ │
│  │                 │    │  ┌─────────────────────────┐ │ │
│  │ • Base packages │    │  │       Statsig           │ │ │
│  │ • Provider SDK  │    │  │                         │ │ │
│  │ • Verification  │    │  │ • Install Statsig SDK   │ │ │
│  └─────────────────┘    │  │ • Configure client      │ │ │
│           │              │  │ • Set up webhooks       │ │ │
│           │              │  └─────────────────────────┘ │ │
│           ▼              └─────────────────────────────┘ │
│  ┌─────────────────┐                                    │
│  │ Docker Build    │                                    │
│  │                 │                                    │
│  │ • Provider arg  │                                    │
│  │ • Optimized     │                                    │
│  │ • Ready to run  │                                    │
│  └─────────────────┘                                    │
└─────────────────────────────────────────────────────────┘
```

## Quick Start

### 1. Interactive Setup

Run the configuration script for guided setup:

```bash
python feature_flag_configure.py
```

This will:
- Prompt you to choose between LaunchDarkly and Statsig
- Install the appropriate SDK dependencies
- Configure Kubernetes manifests
- Verify the installation

### 2. Manual Setup

If you prefer manual setup:

#### For LaunchDarkly:
```bash
# Install dependencies
pip install -r manifests/middleware/requirements.txt
pip install -r manifests/middleware/requirements-launchdarkly.txt

# Set environment variables
export FEATURE_FLAG_PROVIDER=launchdarkly
export LAUNCHDARKLY_SDK_KEY=your_sdk_key_here
export WEBHOOK_SECRET=your_webhook_secret

# Build Docker image
./build-middleware.sh --provider launchdarkly --tag v1.1.0
```

#### For Statsig:
```bash
# Install dependencies
pip install -r manifests/middleware/requirements.txt
pip install -r manifests/middleware/requirements-statsig.txt

# Set environment variables
export FEATURE_FLAG_PROVIDER=statsig
export STATSIG_SERVER_KEY=your_server_key_here
export WEBHOOK_SECRET=your_webhook_secret

# Build Docker image
./build-middleware.sh --provider statsig --tag v1.1.0
```

## File Structure

```
manifests/middleware/
├── requirements.txt                    # Base dependencies
├── requirements-launchdarkly.txt      # LaunchDarkly SDK
├── requirements-statsig.txt           # Statsig SDK
├── feature_flags.py                   # Provider abstraction
├── main.py                           # Main application
└── Dockerfile                        # Multi-provider build
```

## Requirements Files

### Base Requirements (`requirements.txt`)
Contains core dependencies needed by all deployments:
- Flask and related packages
- OpenTelemetry instrumentation
- HTTP libraries
- Utilities

### Provider-Specific Requirements

**LaunchDarkly** (`requirements-launchdarkly.txt`):
```
launchdarkly-server-sdk==8.2.1
certifi>=2021.10.8
urllib3>=1.26.0
```

**Statsig** (`requirements-statsig.txt`):
```
statsig==1.20.0
requests>=2.28.0
```

## Docker Build Process

The Dockerfile supports conditional SDK installation:

```dockerfile
# Install base dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Install provider-specific dependencies based on build argument
ARG FEATURE_FLAG_PROVIDER=launchdarkly
RUN if [ "$FEATURE_FLAG_PROVIDER" = "launchdarkly" ]; then \
        pip install --no-cache-dir -r requirements-launchdarkly.txt; \
    elif [ "$FEATURE_FLAG_PROVIDER" = "statsig" ]; then \
        pip install --no-cache-dir -r requirements-statsig.txt; \
    fi
```

### Building Images

Use the provided build script:

```bash
# LaunchDarkly build
./build-middleware.sh --provider launchdarkly --tag v1.1.0-ld

# Statsig build  
./build-middleware.sh --provider statsig --tag v1.1.0-statsig

# With registry push
./build-middleware.sh --provider launchdarkly --registry myregistry.com --push
```

## Provider Configuration

### LaunchDarkly Setup

1. **Create SDK Key**:
   - Go to your LaunchDarkly dashboard
   - Navigate to Account Settings → Projects → [Your Project] → Environments
   - Copy the SDK key for your environment

2. **Create Feature Flag**:
   - Create a flag named `enable-cost-optimizer`
   - Set it as a boolean flag
   - Configure targeting rules as needed

3. **Configure Webhook**:
   - Go to Integrations → Webhooks
   - Create a webhook pointing to: `https://your-domain.com/webhook/launchdarkly`
   - Set the secret (optional but recommended)

4. **Environment Variables**:
   ```bash
   FEATURE_FLAG_PROVIDER=launchdarkly
   LAUNCHDARKLY_SDK_KEY=sdk-12345678-1234-1234-1234-123456789abc
   WEBHOOK_SECRET=your-webhook-secret
   ```

### Statsig Setup

1. **Create Server Key**:
   - Go to your Statsig console
   - Navigate to Settings → Keys & Environments
   - Copy the Server Secret Key

2. **Create Feature Gate**:
   - Create a gate named `enable_cost_optimizer`
   - Configure rules and targeting as needed

3. **Configure Webhook**:
   - Go to Integrations → Webhooks
   - Create a webhook pointing to: `https://your-domain.com/webhook/statsig`
   - Set the secret key

4. **Environment Variables**:
   ```bash
   FEATURE_FLAG_PROVIDER=statsig
   STATSIG_SERVER_KEY=secret-your-server-key-here
   WEBHOOK_SECRET=your-webhook-secret
   ```

## Code Structure

### Feature Flag Provider Abstraction

The `feature_flags.py` module provides a unified interface:

```python
class FeatureFlagProvider(ABC):
    def initialize(self) -> bool: pass
    def evaluate_flag(self, flag_key: str, user_context: Dict[str, Any] = None, default_value: bool = False) -> bool: pass
    def verify_webhook_signature(self, payload: bytes, signature: str) -> bool: pass
    def parse_webhook_payload(self, payload: Dict[str, Any]) -> Optional[Dict[str, Any]]: pass
    def close(self): pass
```

### Conditional Imports

SDKs are imported conditionally to avoid import errors:

```python
try:
    from ldclient import LDClient, Config, Context
    LAUNCHDARKLY_AVAILABLE = True
except ImportError:
    LAUNCHDARKLY_AVAILABLE = False

try:
    from statsig import statsig
    STATSIG_AVAILABLE = True
except ImportError:
    STATSIG_AVAILABLE = False
```

### SDK Initialization

Each provider implements proper SDK initialization:

**LaunchDarkly**:
```python
def initialize(self) -> bool:
    config = Config(
        sdk_key=self.sdk_key,
        send_events=True,
        stream=True,
        application={'id': 'storm-surge', 'version': 'beta-v1.1.0'}
    )
    self.client = LDClient(config=config)
    return self.client.is_initialized()
```

**Statsig**:
```python
def initialize(self) -> bool:
    statsig.initialize(
        self.server_key,
        options={
            'environment': {'tier': os.getenv('ENVIRONMENT', 'development')},
            'disable_diagnostics': False
        }
    )
    return True
```

## Kubernetes Deployment

### ConfigMap Configuration

Update the ConfigMap with your provider choice:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: storm-surge-config
data:
  FEATURE_FLAG_PROVIDER: "launchdarkly"  # or "statsig"
  WEBHOOK_ENDPOINT: "/webhook/launchdarkly"  # or "/webhook/statsig"
```

### Secret Configuration

Store sensitive keys in Kubernetes secrets:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: storm-surge-secrets
stringData:
  ld-sdk-key: "sdk-12345678-1234-1234-1234-123456789abc"  # LaunchDarkly
  # OR
  statsig-server-key: "secret-your-server-key-here"       # Statsig
  webhook-secret: "your-webhook-secret"
  spot-api-token: "your-spot-api-token"
```

### Deployment with Correct Image

Update your deployment to use the provider-specific image:

```yaml
apiVersion: apps/v1
kind: Deployment
spec:
  template:
    spec:
      containers:
      - name: middleware
        image: storm-surge-middleware:v1.1.0-launchdarkly  # or v1.1.0-statsig
```

## Verification

### 1. Check Logs

After deployment, check the logs for successful initialization:

```bash
kubectl logs deployment/storm-surge-middleware -n storm-surge
```

Look for:
- `LaunchDarkly SDK imported successfully` or `Statsig SDK imported successfully`
- `LaunchDarkly client initialized successfully` or `Statsig client initialized successfully` 
- `Feature flag manager initialized with [provider]`

### 2. Test Health Endpoint

```bash
curl http://your-domain.com/health
```

Should return:
```json
{
  "status": "healthy",
  "timestamp": 1234567890,
  "version": "beta-v1.1.0"
}
```

### 3. Test Webhook

Trigger a flag change in your provider and check that the webhook is received and processed.

### 4. Verify Flag Evaluation

The application should properly evaluate flags and trigger cluster scaling based on the `enable-cost-optimizer` flag.

## Troubleshooting

### Common Issues

1. **Import Errors**:
   ```
   ModuleNotFoundError: No module named 'ldclient'
   ```
   **Solution**: Install the provider-specific requirements file
   ```bash
   pip install -r manifests/middleware/requirements-launchdarkly.txt
   ```

2. **SDK Initialization Failed**:
   ```
   LaunchDarkly client failed to initialize
   ```
   **Solution**: 
   - Check that your SDK key is correct
   - Verify network connectivity
   - Ensure the key has proper permissions

3. **Webhook Signature Verification Failed**:
   ```
   Invalid webhook signature
   ```
   **Solution**:
   - Verify webhook secret matches between provider and application
   - Check webhook URL is correct
   - Ensure payload is not modified in transit

4. **Wrong Provider Endpoint**:
   ```
   Wrong provider endpoint. Expected launchdarkly
   ```
   **Solution**: Make sure webhook URL matches your configured provider

### Debug Commands

```bash
# Check installed packages
pip list | grep -E "(launchdarkly|statsig)"

# Verify Python imports
python -c "import ldclient; print('LaunchDarkly OK')"
python -c "import statsig; print('Statsig OK')"

# Check environment variables
env | grep -E "(LAUNCHDARKLY|STATSIG|FEATURE_FLAG)"

# Test Docker build
docker build --build-arg FEATURE_FLAG_PROVIDER=launchdarkly -t test -f manifests/middleware/Dockerfile manifests/middleware/
```

## Best Practices

1. **Use Virtual Environments**: Always install dependencies in a virtual environment
2. **Provider-Specific Images**: Build separate Docker images for each provider to minimize size
3. **Secure Secrets**: Never commit SDK keys to version control
4. **Monitor Initialization**: Always check that SDKs initialize successfully
5. **Graceful Degradation**: Handle cases where SDKs fail to initialize
6. **Version Pinning**: Pin SDK versions for consistent builds
7. **Testing**: Test flag evaluation and webhook processing in non-production environments

## Migration Between Providers

To switch from one provider to another:

1. **Update Configuration**:
   ```bash
   python feature_flag_configure.py
   ```

2. **Rebuild Images**:
   ```bash
   ./build-middleware.sh --provider statsig --tag v1.1.0-statsig
   ```

3. **Update Kubernetes**:
   - Update ConfigMap with new provider
   - Update Secret with new SDK key
   - Update Deployment with new image

4. **Update Provider Configuration**:
   - Set up new webhooks
   - Create corresponding feature flags
   - Test integration

This setup ensures that Storm Surge can reliably work with either LaunchDarkly or Statsig while maintaining clean separation of concerns and proper error handling.