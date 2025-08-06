# Storm Surge FinOps Guide

Storm Surge integrates LaunchDarkly feature flags with Spot Ocean for dynamic cost optimization.

## Key Features

- **After-hours shutdown**: Disable autoscaling 18:00-06:00 for dev clusters
- **Feature flag control**: Dynamic cost optimization parameters
- **Multi-timezone support**: Respects cluster local times
- **Production protection**: Never affects business-critical workloads

## Setup

1. Set environment variables:
   ```bash
   export SPOT_API_TOKEN="your-token"
   export LAUNCHDARKLY_SDK_KEY="your-key"
   ```

2. Deploy FinOps controller:
   ```bash
   ./scripts/deploy-finops.sh
   ```

3. Configure LaunchDarkly flags (see configs/launchdarkly/)

## Expected Savings

- Development clusters: 70-80% cost reduction
- Staging clusters: 50-60% cost reduction
- Production clusters: 10-20% optimization through right-sizing

Copy the full implementation from the provided artifacts for production use.
