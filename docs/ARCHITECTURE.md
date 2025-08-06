# Storm Surge Architecture

Storm Surge is a production-ready platform for testing Kubernetes elasticity and demonstrating enterprise-grade cloud-native deployment patterns.

## Components

- **Frontend**: Load balancer entry point
- **Shopping Cart**: CPU-intensive service for scaling tests
- **Product Catalog**: Baseline service
- **FinOps Controller**: Cost optimization with LaunchDarkly
- **Chaos Testing**: Resilience validation

## Scaling Strategy

1. Shopping Cart scales based on CPU usage (70% threshold)
2. Ocean provides intelligent node provisioning
3. FinOps optimizes costs during off-hours
4. Chaos testing validates resilience

See the main README for deployment instructions.
