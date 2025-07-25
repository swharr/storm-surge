#!/usr/bin/env python3
"""
Custom metrics for Storm Surge Middleware
Defines application-specific metrics for monitoring feature flag usage, cluster scaling, and business KPIs
"""

import time
import logging
from typing import Dict, Any, Optional
from opentelemetry import metrics
from opentelemetry.metrics import Counter, Histogram, UpDownCounter, Gauge
from telemetry import get_meter

logger = logging.getLogger(__name__)


class StormSurgeMetrics:
    """Custom metrics collector for Storm Surge application"""
    
    def __init__(self):
        self.meter = get_meter("storm-surge-metrics")
        self._initialize_metrics()
        
    def _initialize_metrics(self):
        """Initialize all custom metrics"""
        try:
            # Feature Flag Metrics
            self.flag_evaluations_total = self.meter.create_counter(
                name="storm_surge_flag_evaluations_total",
                description="Total number of feature flag evaluations",
                unit="1"
            )
            
            self.flag_evaluation_duration = self.meter.create_histogram(
                name="storm_surge_flag_evaluation_duration_ms",
                description="Duration of feature flag evaluations in milliseconds",
                unit="ms"
            )
            
            self.flag_changes_total = self.meter.create_counter(
                name="storm_surge_flag_changes_total",
                description="Total number of feature flag changes",
                unit="1"
            )
            
            # Webhook Metrics
            self.webhook_requests_total = self.meter.create_counter(
                name="storm_surge_webhook_requests_total",
                description="Total number of webhook requests received",
                unit="1"
            )
            
            self.webhook_request_duration = self.meter.create_histogram(
                name="storm_surge_webhook_request_duration_ms",
                description="Duration of webhook request processing in milliseconds",
                unit="ms"
            )
            
            self.webhook_errors_total = self.meter.create_counter(
                name="storm_surge_webhook_errors_total",
                description="Total number of webhook processing errors",
                unit="1"
            )
            
            # Cluster Scaling Metrics
            self.cluster_scaling_requests_total = self.meter.create_counter(
                name="storm_surge_cluster_scaling_requests_total",
                description="Total number of cluster scaling requests",
                unit="1"
            )
            
            self.cluster_scaling_duration = self.meter.create_histogram(
                name="storm_surge_cluster_scaling_duration_ms",
                description="Duration of cluster scaling operations in milliseconds",
                unit="ms"
            )
            
            self.cluster_scaling_errors_total = self.meter.create_counter(
                name="storm_surge_cluster_scaling_errors_total",
                description="Total number of cluster scaling errors",
                unit="1"
            )
            
            self.cluster_nodes_current = self.meter.create_up_down_counter(
                name="storm_surge_cluster_nodes_current",
                description="Current number of nodes in the cluster",
                unit="1"
            )
            
            # Cost Optimization Metrics
            self.cost_optimization_events_total = self.meter.create_counter(
                name="storm_surge_cost_optimization_events_total",
                description="Total number of cost optimization events",
                unit="1"
            )
            
            self.estimated_cost_savings = self.meter.create_counter(
                name="storm_surge_estimated_cost_savings_usd",
                description="Estimated cost savings from optimization events in USD",
                unit="USD"
            )
            
            # Application Health Metrics
            self.application_uptime_seconds = self.meter.create_counter(
                name="storm_surge_application_uptime_seconds",
                description="Application uptime in seconds",
                unit="s"
            )
            
            self.active_connections = self.meter.create_up_down_counter(
                name="storm_surge_active_connections",
                description="Number of active WebSocket connections",
                unit="1"
            )
            
            # Business KPI Metrics
            self.feature_adoption_rate = self.meter.create_histogram(
                name="storm_surge_feature_adoption_rate",
                description="Feature adoption rate as a percentage",
                unit="percent"
            )
            
            self.infrastructure_efficiency = self.meter.create_histogram(
                name="storm_surge_infrastructure_efficiency",
                description="Infrastructure efficiency score",
                unit="score"
            )
            
            logger.info("Storm Surge custom metrics initialized")
            
        except Exception as e:
            logger.error(f"Failed to initialize metrics: {e}")
    
    def record_flag_evaluation(self, flag_key: str, flag_value: bool, provider: str, 
                              duration_ms: float, metadata: Dict[str, Any] = None):
        """Record a feature flag evaluation"""
        try:
            attributes = {
                "flag_key": flag_key,
                "flag_value": str(flag_value),
                "provider": provider,
                "source": metadata.get("source", "unknown") if metadata else "unknown"
            }
            
            self.flag_evaluations_total.add(1, attributes)
            self.flag_evaluation_duration.record(duration_ms, attributes)
            
            logger.debug(f"Recorded flag evaluation: {flag_key}={flag_value}")
            
        except Exception as e:
            logger.error(f"Failed to record flag evaluation: {e}")
    
    def record_flag_change(self, flag_key: str, old_value: bool, new_value: bool, 
                          provider: str, metadata: Dict[str, Any] = None):
        """Record a feature flag change"""
        try:
            attributes = {
                "flag_key": flag_key,
                "old_value": str(old_value),
                "new_value": str(new_value),
                "provider": provider,
                "source": metadata.get("source", "webhook") if metadata else "webhook"
            }
            
            self.flag_changes_total.add(1, attributes)
            
            logger.debug(f"Recorded flag change: {flag_key} {old_value} -> {new_value}")
            
        except Exception as e:
            logger.error(f"Failed to record flag change: {e}")
    
    def record_webhook_request(self, provider: str, endpoint: str, status_code: int, 
                              duration_ms: float, error: str = None):
        """Record webhook request metrics"""
        try:
            attributes = {
                "provider": provider,
                "endpoint": endpoint,
                "status_code": str(status_code),
                "success": str(status_code < 400)
            }
            
            self.webhook_requests_total.add(1, attributes)
            self.webhook_request_duration.record(duration_ms, attributes)
            
            if error or status_code >= 400:
                error_attributes = attributes.copy()
                if error:
                    error_attributes["error_type"] = error
                self.webhook_errors_total.add(1, error_attributes)
                
            logger.debug(f"Recorded webhook request: {provider} {endpoint} {status_code}")
            
        except Exception as e:
            logger.error(f"Failed to record webhook request: {e}")
    
    def record_cluster_scaling(self, cluster_id: str, action: str, success: bool, 
                              duration_ms: float, old_nodes: int = None, new_nodes: int = None,
                              error: str = None):
        """Record cluster scaling operation"""
        try:
            attributes = {
                "cluster_id": cluster_id,
                "action": action,
                "success": str(success)
            }
            
            self.cluster_scaling_requests_total.add(1, attributes)
            self.cluster_scaling_duration.record(duration_ms, attributes)
            
            if not success and error:
                error_attributes = attributes.copy()
                error_attributes["error_type"] = error
                self.cluster_scaling_errors_total.add(1, error_attributes)
            
            # Update current node count if successful
            if success and new_nodes is not None:
                node_attributes = {"cluster_id": cluster_id}
                if old_nodes is not None:
                    self.cluster_nodes_current.add(new_nodes - old_nodes, node_attributes)
                
            logger.debug(f"Recorded cluster scaling: {action} {cluster_id} success={success}")
            
        except Exception as e:
            logger.error(f"Failed to record cluster scaling: {e}")
    
    def record_cost_optimization(self, action: str, cluster_id: str, estimated_savings: float = None,
                               node_change: int = None):
        """Record cost optimization events"""
        try:
            attributes = {
                "action": action,
                "cluster_id": cluster_id
            }
            
            self.cost_optimization_events_total.add(1, attributes)
            
            if estimated_savings is not None and estimated_savings > 0:
                self.estimated_cost_savings.add(estimated_savings, attributes)
                
            logger.debug(f"Recorded cost optimization: {action} savings=${estimated_savings}")
            
        except Exception as e:
            logger.error(f"Failed to record cost optimization: {e}")
    
    def record_connection_change(self, change: int):
        """Record WebSocket connection changes"""
        try:
            self.active_connections.add(change)
            logger.debug(f"Recorded connection change: {change}")
        except Exception as e:
            logger.error(f"Failed to record connection change: {e}")
    
    def record_feature_adoption(self, feature_name: str, adoption_rate: float):
        """Record feature adoption metrics"""
        try:
            attributes = {"feature_name": feature_name}
            self.feature_adoption_rate.record(adoption_rate, attributes)
            logger.debug(f"Recorded feature adoption: {feature_name} {adoption_rate}%")
        except Exception as e:
            logger.error(f"Failed to record feature adoption: {e}")
    
    def record_infrastructure_efficiency(self, cluster_id: str, efficiency_score: float):
        """Record infrastructure efficiency metrics"""
        try:
            attributes = {"cluster_id": cluster_id}
            self.infrastructure_efficiency.record(efficiency_score, attributes)
            logger.debug(f"Recorded infrastructure efficiency: {cluster_id} {efficiency_score}")
        except Exception as e:
            logger.error(f"Failed to record infrastructure efficiency: {e}")
    
    def increment_uptime(self, seconds: float = 1.0):
        """Increment application uptime counter"""
        try:
            self.application_uptime_seconds.add(seconds)
        except Exception as e:
            logger.error(f"Failed to increment uptime: {e}")


# Global metrics instance
storm_surge_metrics = StormSurgeMetrics()


def get_metrics() -> StormSurgeMetrics:
    """Get the global metrics instance"""
    return storm_surge_metrics