# FinOps Controller

The FinOps Controller is a Python-based service that integrates LaunchDarkly feature flags with Spot Ocean API for automated cost optimization and cluster scaling.

## 🎯 Overview

The FinOps Controller automates cost optimization decisions by:
- Monitoring LaunchDarkly feature flags for cost optimization signals
- Automatically scaling Spot Ocean clusters based on business hours and demand
- Providing scheduled optimization for after-hours and weekend cost savings
- Integrating with the OceanSurge middleware for real-time webhook processing

## 📁 Structure

```
finops/
├── finops_controller.py          # Main controller implementation
├── requirements.txt              # Python dependencies
├── examples/                     # Usage examples
├── tests/                        # Test suite
│   ├── __init__.py
│   ├── test_basic.py            # Basic functionality tests
│   ├── test_finops_controller.py # Unit tests
│   ├── test_integration.py      # Integration tests
│   ├── conftest.py              # Pytest configuration
│   ├── requirements.txt         # Test dependencies
│   └── run_tests.sh             # Test runner script
└── README.md                    # This file
```

## 🚀 Current Status

**Status**: Placeholder Implementation  
**Version**: v0.1.1-rebase

The current implementation is a placeholder that demonstrates the structure and interfaces for full LaunchDarkly and Spot Ocean integration. It includes:

- ✅ **Basic Controller Structure**: Main class with placeholder methods
- ✅ **Scheduling Framework**: Time-based automation with schedule library
- ✅ **Logging Integration**: Structured logging for monitoring
- ✅ **Test Suite**: Comprehensive tests for validation
- ⚠️ **API Integration**: Placeholder - requires full implementation

## 🔧 Dependencies

### Runtime Dependencies
```bash
# Install from requirements.txt
pip install -r requirements.txt
```

**Main Dependencies:**
- `launchdarkly-server-sdk==8.2.1` - LaunchDarkly integration
- `requests==2.31.0` - HTTP API calls
- `schedule==1.2.0` - Task scheduling
- `pytz==2023.3` - Timezone handling
- `python-dotenv==1.0.0` - Environment configuration

### Test Dependencies
```bash
# Install test dependencies
pip install -r tests/requirements.txt
```

## 🧪 Testing

The FinOps Controller includes a comprehensive test suite with multiple test categories:

### Running Tests

```bash
# Run all tests
cd finops/tests
./run_tests.sh

# Run specific test files
python3 test_basic.py
python3 test_finops_controller.py
python3 test_integration.py

# Run with pytest (requires pytest installation)
pytest -v
pytest -m integration  # Integration tests only
pytest -m api          # API tests only
```

### Test Categories

1. **Basic Tests** (`test_basic.py`)
   - Structure validation
   - Import checking
   - File existence
   - No external dependencies

2. **Unit Tests** (`test_finops_controller.py`)
   - Controller functionality
   - Method behavior
   - Error handling
   - Time-based logic

3. **Integration Tests** (`test_integration.py`)
   - LaunchDarkly API integration
   - Spot Ocean API integration
   - End-to-end scenarios
   - Failure recovery

### Test Results

Current test status:
- ✅ **Structure Tests**: All pass
- ⚠️ **Functional Tests**: Skip due to missing dependencies
- ✅ **File Organization**: All pass
- ✅ **Import Paths**: All pass

## 🔑 Configuration

### Environment Variables

The controller uses these environment variables:

```bash
# LaunchDarkly Configuration
LAUNCHDARKLY_SDK_KEY="sdk-12345678-1234-1234-1234-123456789012"

# Spot Ocean Configuration
SPOT_API_TOKEN="your-spot-api-token"
SPOT_CLUSTER_ID="ocn-12345678"

# Optional Configuration
WEBHOOK_SECRET="your-webhook-secret"
LOG_LEVEL="INFO"
BUSINESS_HOURS_START="06:00"
BUSINESS_HOURS_END="18:00"
TIMEZONE="UTC"
```

### Scheduling Configuration

The controller runs scheduled tasks:
- **18:00 UTC**: Disable autoscaling (after-hours optimization)
- **06:00 UTC**: Enable autoscaling (business hours)

## 🔗 Integration Points

### LaunchDarkly Integration
- **Feature Flag**: `enable-cost-optimizer`
- **Webhook Processing**: Real-time flag change handling
- **SDK Integration**: Server-side SDK for flag evaluation

### Spot Ocean Integration
- **Cluster Scaling**: Automatic capacity adjustment
- **Cost Optimization**: After-hours scaling policies
- **API Calls**: GET cluster info, PUT scaling updates

### OceanSurge Middleware Integration
- **Webhook Handler**: Processes LaunchDarkly webhooks
- **API Endpoints**: Provides status and control endpoints
- **Shared Configuration**: Common environment variables

## 📊 Monitoring

The controller provides:
- **Structured Logging**: JSON format with timestamps
- **Health Checks**: Status endpoint for monitoring
- **Metrics**: Cost savings and scaling metrics
- **Error Handling**: Graceful degradation and retry logic

## 🔮 Future Implementation

The current placeholder implementation should be enhanced with:

1. **Full LaunchDarkly Integration**
   - Real SDK initialization
   - Feature flag evaluation
   - Webhook signature verification

2. **Complete Spot Ocean API Integration**
   - Cluster information retrieval
   - Scaling operations
   - Policy management

3. **Advanced Cost Optimization**
   - Business hours detection
   - Weekend optimization
   - Custom scaling policies

4. **Enhanced Monitoring**
   - Prometheus metrics
   - Cost savings calculation
   - Performance tracking

## 🚦 Usage

### Basic Usage
```python
from finops_controller import StormSurgeFinOpsController

# Initialize controller
controller = StormSurgeFinOpsController()

# Manual operations
controller.disable_autoscaling_after_hours()
controller.enable_autoscaling_business_hours()
```

### Scheduled Operation
```bash
# Run with scheduling
python3 finops_controller.py
```

### Integration with OceanSurge
The controller integrates with the OceanSurge middleware for webhook processing and real-time flag changes.

## 🤝 Contributing

1. **Install Dependencies**: `pip install -r requirements.txt`
2. **Run Tests**: `./tests/run_tests.sh`
3. **Implement Features**: Replace placeholder methods with full implementation
4. **Add Tests**: Update test suite for new functionality
5. **Update Documentation**: Keep README current with changes

## 📝 Notes

- The controller is designed to run as a standalone service or integrate with the OceanSurge middleware
- All API integrations are currently placeholder implementations
- The test suite provides comprehensive coverage for future implementation
- Environment variable configuration supports both development and production deployment

---

**Status**: Ready for full implementation  
**Integration**: OceanSurge v0.1.1-rebase  
**License**: Same as parent OceanSurge project
