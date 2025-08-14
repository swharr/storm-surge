# Changelog - Storm Surge Core

All notable changes to the Storm Surge Core branch will be documented in this file.

## [core-v1.0.0] - 2024-01-13

### Added
- Initial core release with minimal Kubernetes stack
- Multi-cloud support for AWS EKS, Google GKE, and Azure AKS
- Basic middleware service with health checks and metrics
- Cloud-native load balancer configuration
- Comprehensive IAM policies for all cloud providers
- Production security hardening
- Minimal setup script focused on core functionality

### Changed
- Simplified architecture removing all third-party integrations
- Reduced dependencies to essential components only
- Streamlined deployment process
- Updated all scripts to use professional language

### Removed
- Spot Ocean integration
- LaunchDarkly feature flag support
- Statsig analytics integration
- Complex frontend with multiple pages
- WebSocket functionality
- External service dependencies

### Security
- Implemented Pod Security Standards (restricted)
- Added security contexts for all containers
- Removed all hardcoded credentials
- Enhanced secret management
- Added network policies
- Configured minimal container capabilities

### Technical Details
- Base image: python:3.11-slim
- Framework: Flask with Gunicorn
- Resource limits: 128Mi-256Mi memory, 100m-500m CPU
- Replicas: 2 (configurable)
- Health check intervals: 5s readiness, 10s liveness