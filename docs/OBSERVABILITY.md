# Storm Surge Observability with OpenTelemetry

This document describes the comprehensive observability setup for Storm Surge using OpenTelemetry, including traces, metrics, and logs collection.

## Architecture Overview

Storm Surge implements a complete observability stack using OpenTelemetry:

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Frontend      │    │   Middleware    │    │  Spot Ocean API │
│   (React)       │    │   (Flask)       │    │                 │
│                 │    │                 │    │                 │
│ • User traces   │    │ • API traces    │    │ • External calls│
│ • Page metrics  │    │ • Metrics       │    │                 │
│ • Error logs    │    │ • Structured    │    │                 │
│                 │    │   logs          │    │                 │
└─────────┬───────┘    └─────────┬───────┘    └─────────────────┘
          │                      │                              
          │ OTLP/HTTP            │ OTLP/gRPC                   
          │                      │                              
          └──────────────────────┼──────────────────────────────┘
                                 │                              
                    ┌─────────────▼───────────┐                
                    │ OpenTelemetry Collector │                
                    │                         │                
                    │ • Receives telemetry    │                
                    │ • Processes & enriches  │                
                    │ • Exports to backends   │                
                    └─────────────┬───────────┘                
                                  │                            
        ┌─────────────────────────┼─────────────────────────┐  
        │                         │                         │  
   ┌────▼─────┐              ┌────▼────┐              ┌─────▼────┐
   │  Jaeger  │              │Prometheus│              │   Logs   │
   │          │              │          │              │ (Files/  │
   │ • Traces │              │ • Metrics│              │  Cloud)  │
   │ • APM    │              │ • Alerts │              │          │
   └──────────┘              └──────────┘              └──────────┘
```

## Components

### 1. Frontend Telemetry (`frontend/src/telemetry.ts`)

**Purpose**: Captures user interactions, page performance, and API calls from the React frontend.

**Features**:
- **User Interaction Tracking**: Button clicks, form submissions, navigation
- **API Call Tracing**: HTTP requests to middleware and external APIs
- **Page Performance**: Load times, DOM ready, resource timing
- **Error Tracking**: JavaScript errors, failed API calls
- **Custom Events**: Feature usage, business metrics

**Configuration**:
```typescript
// Environment variables for frontend
VITE_OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4318/v1/traces
VITE_OTEL_ENABLE_OTLP=true
VITE_OTEL_ENABLE_CONSOLE=false
VITE_ENVIRONMENT=production
```

**Key Metrics**:
- `page_load_duration_ms`: Time to load pages
- `user_interaction_total`: Count of user interactions
- `api_request_duration_ms`: Frontend API call latency
- `javascript_errors_total`: Frontend error count

### 2. Middleware Telemetry (`manifests/middleware/telemetry.py`)

**Purpose**: Comprehensive instrumentation of the Flask middleware including webhooks, cluster operations, and feature flag evaluations.

**Features**:
- **Automatic Instrumentation**: Flask requests, database calls, HTTP clients
- **Custom Spans**: Webhook processing, cluster scaling, feature flag evaluation
- **Business Metrics**: Cost optimization events, scaling operations, flag changes
- **Structured Logging**: Correlated logs with trace context
- **Health Monitoring**: Application performance and resource usage

**Configuration**:
```python
# Environment variables for middleware
OTEL_EXPORTER_OTLP_ENDPOINT=http://otelcol:4317
OTEL_ENABLE_PROMETHEUS=true
OTEL_ENABLE_OTLP=true
OTEL_ENABLE_CONSOLE=false
ENVIRONMENT=production
```

**Key Metrics** (`manifests/middleware/metrics.py`):
- `storm_surge_flag_evaluations_total`: Feature flag evaluation count
- `storm_surge_webhook_requests_total`: Webhook processing count
- `storm_surge_cluster_scaling_requests_total`: Cluster scaling operations
- `storm_surge_cost_optimization_events_total`: Cost optimization events
- `storm_surge_estimated_cost_savings_usd`: Estimated cost savings

### 3. OpenTelemetry Collector (`manifests/observability/otelcol-deployment.yaml`)

**Purpose**: Central telemetry data processing and routing hub.

**Features**:
- **Multi-Protocol Support**: OTLP gRPC, OTLP HTTP, Prometheus scraping
- **Data Processing**: Batching, sampling, enrichment, filtering
- **Multiple Exporters**: Jaeger (traces), Prometheus (metrics), File (logs)
- **Health Monitoring**: Built-in health checks and self-monitoring
- **Kubernetes Integration**: Service discovery and metadata enrichment

**Endpoints**:
- `4317`: OTLP gRPC receiver
- `4318`: OTLP HTTP receiver  
- `8889`: Prometheus metrics exporter
- `13133`: Health check endpoint
- `55679`: zPages debugging interface

### 4. Jaeger (`manifests/observability/jaeger-deployment.yaml`)

**Purpose**: Distributed tracing storage and analysis.

**Features**:
- **Trace Storage**: In-memory (development) or persistent storage
- **Web UI**: Trace visualization and analysis
- **Service Map**: Dependency visualization
- **Performance Analysis**: Latency analysis, bottleneck identification

**Access**: 
- UI: `http://jaeger.storm-surge.local` or `http://localhost:30686`

### 5. Prometheus (`manifests/observability/prometheus-deployment.yaml`)

**Purpose**: Metrics collection, storage, and alerting.

**Features**:
- **Metrics Storage**: Time-series database with 7-day retention
- **Alerting Rules**: Custom alerts for Storm Surge components
- **Service Discovery**: Automatic Kubernetes service discovery
- **Dashboards**: Integration with Grafana (optional)

**Access**:
- UI: `http://prometheus.storm-surge.local` or `http://localhost:30090`

## Deployment

### Prerequisites

1. **Kubernetes Cluster**: Running cluster with ingress controller
2. **Namespace**: Create the storm-surge namespace
```bash
kubectl create namespace storm-surge
```

### 1. Deploy OpenTelemetry Collector

```bash
kubectl apply -f manifests/observability/otelcol-deployment.yaml
```

### 2. Deploy Jaeger

```bash
kubectl apply -f manifests/observability/jaeger-deployment.yaml
```

### 3. Deploy Prometheus

```bash
kubectl apply -f manifests/observability/prometheus-deployment.yaml
```

### 4. Configure DNS (Local Development)

Add to `/etc/hosts`:
```
127.0.0.1 jaeger.storm-surge.local
127.0.0.1 prometheus.storm-surge.local
```

### 5. Verify Deployment

```bash
# Check all observability components
kubectl get pods -n storm-surge -l component=observability

# Check services
kubectl get svc -n storm-surge

# Check ingresses
kubectl get ingress -n storm-surge
```

## Custom Metrics

### Feature Flag Metrics
- `storm_surge_flag_evaluations_total`: Total flag evaluations
- `storm_surge_flag_changes_total`: Total flag changes
- `storm_surge_flag_evaluation_duration_ms`: Flag evaluation latency

### Webhook Metrics
- `storm_surge_webhook_requests_total`: Total webhook requests
- `storm_surge_webhook_request_duration_ms`: Webhook processing time
- `storm_surge_webhook_errors_total`: Webhook processing errors

### Cluster Scaling Metrics
- `storm_surge_cluster_scaling_requests_total`: Scaling operations
- `storm_surge_cluster_scaling_duration_ms`: Scaling operation time
- `storm_surge_cluster_nodes_current`: Current cluster node count

### Cost Optimization Metrics
- `storm_surge_cost_optimization_events_total`: Cost optimization events
- `storm_surge_estimated_cost_savings_usd`: Estimated savings in USD

### Application Health Metrics
- `storm_surge_active_connections`: Active WebSocket connections
- `storm_surge_application_uptime_seconds`: Application uptime

## Alerting Rules

### Critical Alerts
- **ApplicationDown**: Middleware becomes unavailable
- **ClusterScalingFailures**: High cluster scaling failure rate

### Warning Alerts
- **HighFeatureFlagErrorRate**: Feature flag evaluation errors
- **WebhookProcessingFailures**: Webhook processing failures
- **ClusterScalingLatency**: High cluster scaling latency
- **HighMemoryUsage**: Application memory usage too high

### Info Alerts
- **CostOptimizationDisabled**: Cost optimization frequently disabled

## Monitoring Queries

### Useful Prometheus Queries

```promql
# Feature flag evaluation rate
rate(storm_surge_flag_evaluations_total[5m])

# Webhook success rate
rate(storm_surge_webhook_requests_total{success="true"}[5m]) / rate(storm_surge_webhook_requests_total[5m])

# Cluster scaling latency percentiles
histogram_quantile(0.95, rate(storm_surge_cluster_scaling_duration_ms_bucket[5m]))

# Cost savings over time
increase(storm_surge_estimated_cost_savings_usd[1h])

# Active connections
storm_surge_active_connections
```

### Jaeger Trace Analysis

1. **Webhook Processing Traces**: Search for service `storm-surge-middleware` and operation `webhook_processing`
2. **Cluster Scaling Traces**: Filter by operation `cluster_scaling`
3. **Feature Flag Traces**: Look for `flag_evaluation_processing` spans
4. **Error Analysis**: Filter traces with errors to identify failure patterns

## Troubleshooting

### Common Issues

1. **Missing Traces**: 
   - Check OTLP endpoints are reachable
   - Verify network policies allow communication
   - Check collector logs: `kubectl logs -n storm-surge deployment/otelcol`

2. **No Metrics in Prometheus**:
   - Verify Prometheus scrape targets: `http://prometheus.storm-surge.local/targets`
   - Check collector metrics endpoint: `http://otelcol:8889/metrics`
   - Review Prometheus config in ConfigMap

3. **High Memory Usage**:
   - Adjust collector memory limits
   - Tune batch processors and sampling rates
   - Review trace sampling configuration

4. **Missing Logs**:
   - Ensure OTEL logging instrumentation is enabled
   - Check log exporters in collector config
   - Verify log endpoints are accessible

### Log Analysis

```bash
# Check collector logs
kubectl logs -n storm-surge deployment/otelcol -f

# Check middleware logs  
kubectl logs -n storm-surge deployment/storm-surge-middleware -f

# Check Jaeger logs
kubectl logs -n storm-surge deployment/jaeger -f

# Check Prometheus logs
kubectl logs -n storm-surge deployment/prometheus -f
```

## Performance Tuning

### Sampling Configuration

For high-traffic environments, adjust sampling rates:

```yaml
# In otelcol-config.yaml
processors:
  probabilistic_sampler:
    sampling_percentage: 1.0  # Sample 1% of traces instead of 10%
```

### Batch Processing

Optimize batch sizes for better performance:

```yaml
processors:
  batch:
    timeout: 5s          # Increase timeout
    send_batch_size: 2048    # Increase batch size
    send_batch_max_size: 4096 # Increase max batch size
```

### Resource Limits

Adjust resource limits based on load:

```yaml
resources:
  requests:
    memory: 512Mi
    cpu: 200m
  limits:
    memory: 1Gi    # Increase memory
    cpu: 1000m     # Increase CPU
```

## Integration with External Services

### Cloud Providers

To export to cloud observability services, update the collector config:

```yaml
exporters:
  otlp/datadog:
    endpoint: https://api.datadoghq.com
    headers:
      DD-API-KEY: ${DD_API_KEY}
  
  otlp/newrelic:
    endpoint: https://otlp.nr-data.net:4317
    headers:
      api-key: ${NEW_RELIC_API_KEY}
```

### Custom Dashboards

Create Grafana dashboards using the exported Prometheus metrics for:
- Feature flag adoption rates
- Cluster scaling efficiency
- Cost optimization impact
- Application performance overview

## Security Considerations

1. **Network Policies**: Restrict access to observability components
2. **RBAC**: Use least-privilege service accounts
3. **Secrets Management**: Store API keys in Kubernetes secrets
4. **Data Retention**: Configure appropriate retention policies
5. **Access Control**: Secure observability UIs with authentication

This observability setup provides comprehensive monitoring and troubleshooting capabilities for Storm Surge, enabling proactive issue detection and performance optimization.