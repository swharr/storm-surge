#!/usr/bin/env python3
"""
OpenTelemetry configuration for Storm Surge Middleware
Handles metrics, traces, and logs export to OTLP collectors
"""

import os
import logging
from typing import Optional
from opentelemetry import trace, metrics
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.metrics.export import PeriodicExportingMetricReader
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.exporter.otlp.proto.grpc.metric_exporter import OTLPMetricExporter
from opentelemetry.exporter.prometheus import PrometheusMetricReader
from opentelemetry.instrumentation.flask import FlaskInstrumentor
from opentelemetry.instrumentation.requests import RequestsInstrumentor
from opentelemetry.instrumentation.logging import LoggingInstrumentor
from opentelemetry.sdk.resources import Resource
from opentelemetry._logs import set_logger_provider
from opentelemetry.sdk._logs import LoggerProvider, LoggingHandler
from opentelemetry.sdk._logs.export import BatchLogRecordProcessor
from opentelemetry.exporter.otlp.proto.grpc._log_exporter import OTLPLogExporter

logger = logging.getLogger(__name__)


class TelemetryManager:
    """Manages OpenTelemetry configuration and instrumentation"""
    
    def __init__(self):
        self.service_name = "storm-surge-middleware"
        self.service_version = os.getenv('APP_VERSION', 'beta-v1.1.0')
        self.environment = os.getenv('ENVIRONMENT', 'development')
        
        # OTLP Collector endpoints
        self.otlp_endpoint = os.getenv('OTEL_EXPORTER_OTLP_ENDPOINT', 'http://otelcol:4317')
        self.metrics_endpoint = os.getenv('OTEL_EXPORTER_OTLP_METRICS_ENDPOINT', f'{self.otlp_endpoint}')
        self.traces_endpoint = os.getenv('OTEL_EXPORTER_OTLP_TRACES_ENDPOINT', f'{self.otlp_endpoint}')
        self.logs_endpoint = os.getenv('OTEL_EXPORTER_OTLP_LOGS_ENDPOINT', f'{self.otlp_endpoint}')
        
        # Feature toggles
        self.enable_prometheus = os.getenv('OTEL_ENABLE_PROMETHEUS', 'true').lower() == 'true'
        self.enable_otlp = os.getenv('OTEL_ENABLE_OTLP', 'true').lower() == 'true'
        self.enable_console = os.getenv('OTEL_ENABLE_CONSOLE', 'false').lower() == 'true'
        
        # Resource attributes
        self.resource = Resource.create({
            "service.name": self.service_name,
            "service.version": self.service_version,
            "service.namespace": "storm-surge",
            "deployment.environment": self.environment,
            "k8s.namespace.name": os.getenv('K8S_NAMESPACE', 'storm-surge'),
            "k8s.pod.name": os.getenv('K8S_POD_NAME', 'unknown'),
            "k8s.node.name": os.getenv('K8S_NODE_NAME', 'unknown'),
            "cluster.name": os.getenv('CLUSTER_NAME', 'storm-surge-cluster'),
            "feature.flag.provider": os.getenv('FEATURE_FLAG_PROVIDER', 'unknown')
        })
        
        self.tracer_provider: Optional[TracerProvider] = None
        self.meter_provider: Optional[MeterProvider] = None
        self.logger_provider: Optional[LoggerProvider] = None
        
    def setup_tracing(self):
        """Configure distributed tracing"""
        try:
            self.tracer_provider = TracerProvider(resource=self.resource)
            trace.set_tracer_provider(self.tracer_provider)
            
            if self.enable_otlp:
                # OTLP exporter for traces
                otlp_exporter = OTLPSpanExporter(
                    endpoint=self.traces_endpoint,
                    insecure=True  # Use secure=False for development
                )
                span_processor = BatchSpanProcessor(otlp_exporter)
                self.tracer_provider.add_span_processor(span_processor)
                logger.info(f"OTLP trace exporter configured: {self.traces_endpoint}")
            
            if self.enable_console:
                # Console exporter for debugging
                from opentelemetry.sdk.trace.export import ConsoleSpanExporter
                console_exporter = ConsoleSpanExporter()
                console_processor = BatchSpanProcessor(console_exporter)
                self.tracer_provider.add_span_processor(console_processor)
                logger.info("Console trace exporter configured")
                
        except Exception as e:
            logger.error(f"Failed to setup tracing: {e}")
    
    def setup_metrics(self):
        """Configure metrics collection and export"""
        try:
            readers = []
            
            if self.enable_prometheus:
                # Prometheus metrics endpoint
                prometheus_reader = PrometheusMetricReader()
                readers.append(prometheus_reader)
                logger.info("Prometheus metrics reader configured")
            
            if self.enable_otlp:
                # OTLP exporter for metrics
                otlp_exporter = OTLPMetricExporter(
                    endpoint=self.metrics_endpoint,
                    insecure=True
                )
                otlp_reader = PeriodicExportingMetricReader(
                    exporter=otlp_exporter,
                    export_interval_millis=30000  # Export every 30 seconds
                )
                readers.append(otlp_reader)
                logger.info(f"OTLP metrics exporter configured: {self.metrics_endpoint}")
            
            if readers:
                self.meter_provider = MeterProvider(
                    resource=self.resource,
                    metric_readers=readers
                )
                metrics.set_meter_provider(self.meter_provider)
            else:
                logger.warning("No metrics readers configured")
                
        except Exception as e:
            logger.error(f"Failed to setup metrics: {e}")
    
    def setup_logging(self):
        """Configure structured logging with OpenTelemetry"""
        try:
            self.logger_provider = LoggerProvider(resource=self.resource)
            set_logger_provider(self.logger_provider)
            
            if self.enable_otlp:
                # OTLP exporter for logs
                otlp_exporter = OTLPLogExporter(
                    endpoint=self.logs_endpoint,
                    insecure=True
                )
                log_processor = BatchLogRecordProcessor(otlp_exporter)
                self.logger_provider.add_log_record_processor(log_processor)
                
                # Add OpenTelemetry logging handler
                handler = LoggingHandler(
                    level=logging.INFO,
                    logger_provider=self.logger_provider
                )
                
                # Configure root logger
                root_logger = logging.getLogger()
                root_logger.addHandler(handler)
                root_logger.setLevel(logging.INFO)
                
                logger.info(f"OTLP log exporter configured: {self.logs_endpoint}")
                
        except Exception as e:
            logger.error(f"Failed to setup logging: {e}")
    
    def setup_instrumentation(self, app=None):
        """Setup automatic instrumentation for common libraries"""
        try:
            # Flask instrumentation
            if app:
                FlaskInstrumentor().instrument_app(app)
                logger.info("Flask instrumentation enabled")
            
            # Requests instrumentation (for HTTP calls to Spot API, etc.)
            RequestsInstrumentor().instrument()
            logger.info("Requests instrumentation enabled")
            
            # Logging instrumentation
            LoggingInstrumentor().instrument(set_logging_format=True)
            logger.info("Logging instrumentation enabled")
            
        except Exception as e:
            logger.error(f"Failed to setup instrumentation: {e}")
    
    def initialize(self, app=None):
        """Initialize all OpenTelemetry components"""
        logger.info("Initializing OpenTelemetry...")
        logger.info(f"Service: {self.service_name} v{self.service_version}")
        logger.info(f"Environment: {self.environment}")
        logger.info(f"OTLP Endpoint: {self.otlp_endpoint}")
        
        self.setup_tracing()
        self.setup_metrics()
        self.setup_logging()
        self.setup_instrumentation(app)
        
        logger.info("OpenTelemetry initialization complete")
    
    def get_tracer(self, name: str = None):
        """Get a tracer instance"""
        tracer_name = name or self.service_name
        return trace.get_tracer(tracer_name, self.service_version)
    
    def get_meter(self, name: str = None):
        """Get a meter instance"""
        meter_name = name or self.service_name
        return metrics.get_meter(meter_name, self.service_version)
    
    def shutdown(self):
        """Gracefully shutdown OpenTelemetry components"""
        try:
            if self.tracer_provider:
                self.tracer_provider.shutdown()
            if self.meter_provider:
                self.meter_provider.shutdown()
            if self.logger_provider:
                self.logger_provider.shutdown()
            logger.info("OpenTelemetry shutdown complete")
        except Exception as e:
            logger.error(f"Error during OpenTelemetry shutdown: {e}")


# Global telemetry manager instance
telemetry_manager = TelemetryManager()


def initialize_telemetry(app=None):
    """Initialize OpenTelemetry for the application"""
    telemetry_manager.initialize(app)
    return telemetry_manager


def get_tracer(name: str = None):
    """Get a tracer instance"""
    return telemetry_manager.get_tracer(name)


def get_meter(name: str = None):
    """Get a meter instance"""
    return telemetry_manager.get_meter(name)


def shutdown_telemetry():
    """Shutdown OpenTelemetry components"""
    telemetry_manager.shutdown()