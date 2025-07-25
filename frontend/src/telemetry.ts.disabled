#!/usr/bin/env typescript
/**
 * OpenTelemetry configuration for Storm Surge Frontend
 * Handles web instrumentation for user interactions, API calls, and performance monitoring
 */

import { WebSDK } from '@opentelemetry/sdk-web';
import { getWebAutoInstrumentations } from '@opentelemetry/auto-instrumentations-web';
import { Resource } from '@opentelemetry/resources';
import { OTLPTraceExporter } from '@opentelemetry/exporter-otlp-http';
import { BatchSpanProcessor } from '@opentelemetry/sdk-web';
import { UserInteractionInstrumentation } from '@opentelemetry/instrumentation-user-interaction';
import { FetchInstrumentation } from '@opentelemetry/instrumentation-fetch';
import { XMLHttpRequestInstrumentation } from '@opentelemetry/instrumentation-xml-http-request';

class FrontendTelemetry {
  private sdk: WebSDK | null = null;
  private initialized = false;

  constructor() {
    this.serviceName = 'storm-surge-frontend';
    this.serviceVersion = import.meta.env.VITE_APP_VERSION || '1.1.0';
    this.environment = import.meta.env.VITE_ENVIRONMENT || 'development';
    
    // OTLP Collector endpoint (should point to your backend's OTLP collector)
    this.otlpEndpoint = import.meta.env.VITE_OTEL_EXPORTER_OTLP_ENDPOINT || 'http://localhost:4318/v1/traces';
    
    // Feature toggles
    this.enableOtlp = (import.meta.env.VITE_OTEL_ENABLE_OTLP || 'true').toLowerCase() === 'true';
    this.enableConsole = (import.meta.env.VITE_OTEL_ENABLE_CONSOLE || 'false').toLowerCase() === 'true';
  }

  private readonly serviceName: string;
  private readonly serviceVersion: string;
  private readonly environment: string;
  private readonly otlpEndpoint: string;
  private readonly enableOtlp: boolean;
  private readonly enableConsole: boolean;

  public initialize(): void {
    if (this.initialized) {
      console.warn('OpenTelemetry already initialized');
      return;
    }

    try {
      console.log('Initializing OpenTelemetry for frontend...');
      console.log(`Service: ${this.serviceName} v${this.serviceVersion}`);
      console.log(`Environment: ${this.environment}`);
      console.log(`OTLP Endpoint: ${this.otlpEndpoint}`);

      // Create resource with service information
      const resource = Resource.default().merge(new Resource({
        'service.name': this.serviceName,
        'service.version': this.serviceVersion,
        'service.namespace': 'storm-surge',
        'deployment.environment': this.environment,
        'telemetry.sdk.name': 'opentelemetry',
        'telemetry.sdk.language': 'webjs',
        'user.agent': navigator.userAgent,
        'browser.name': this.getBrowserName(),
        'page.url': window.location.href,
        'page.referrer': document.referrer || 'direct'
      }));

      // Configure exporters
      const spanProcessors = [];

      if (this.enableOtlp) {
        const otlpExporter = new OTLPTraceExporter({
          url: this.otlpEndpoint,
          headers: {
            'Content-Type': 'application/json'
          }
        });
        spanProcessors.push(new BatchSpanProcessor(otlpExporter));
        console.log('OTLP trace exporter configured');
      }

      if (this.enableConsole) {
        // Console exporter for debugging (would need to import if available)
        console.log('Console trace exporter configured');
      }

      // Configure instrumentations
      const instrumentations = [
        // Automatic web instrumentations
        getWebAutoInstrumentations({
          '@opentelemetry/instrumentation-document-load': {
            enabled: true,
          },
          '@opentelemetry/instrumentation-user-interaction': {
            enabled: true,
            eventNames: ['click', 'submit', 'keydown'],
          },
          '@opentelemetry/instrumentation-xml-http-request': {
            enabled: true,
            propagateTraceHeaderCorsUrls: [
              /http:\/\/localhost:8000.*/, // Backend API
              /https:\/\/api\.spotinst\.io.*/, // Spot API calls
            ],
          },
          '@opentelemetry/instrumentation-fetch': {
            enabled: true,
            propagateTraceHeaderCorsUrls: [
              /http:\/\/localhost:8000.*/, // Backend API
              /https:\/\/api\.spotinst\.io.*/, // Spot API calls
            ],
            clearTimingResources: true,
          },
        }),

        // Custom instrumentations for Storm Surge specific events
        new UserInteractionInstrumentation({
          eventNames: ['click', 'submit', 'change'],
          shouldPreventSpanCreation: (eventType, element) => {
            // Filter out noise from non-essential UI elements
            return element.tagName === 'DIV' && !element.dataset.track;
          },
        }),

        new FetchInstrumentation({
          propagateTraceHeaderCorsUrls: [
            /http:\/\/localhost:8000.*/, // Backend middleware
          ],
          requestHook: (span, request) => {
            // Add custom attributes to API requests
            if (request.url.includes('/api/')) {
              span.setAttributes({
                'http.api_type': 'storm_surge_api',
                'storm_surge.component': 'frontend',
              });
            }
          },
        }),
      ];

      // Initialize Web SDK
      this.sdk = new WebSDK({
        resource,
        spanProcessors,
        instrumentations,
      });

      // Start the SDK
      this.sdk.start();
      this.initialized = true;

      console.log('OpenTelemetry frontend initialization complete');

      // Track page load as a custom event
      this.trackPageLoad();

    } catch (error) {
      console.error('Failed to initialize OpenTelemetry:', error);
    }
  }

  private getBrowserName(): string {
    const userAgent = navigator.userAgent;
    if (userAgent.includes('Chrome')) return 'chrome';
    if (userAgent.includes('Firefox')) return 'firefox';
    if (userAgent.includes('Safari')) return 'safari';
    if (userAgent.includes('Edge')) return 'edge';
    return 'unknown';
  }

  private trackPageLoad(): void {
    // Record page load metrics
    const navigationTiming = performance.getEntriesByType('navigation')[0] as PerformanceNavigationTiming;
    
    if (navigationTiming) {
      const loadTime = navigationTiming.loadEventEnd - navigationTiming.fetchStart;
      const domContentLoaded = navigationTiming.domContentLoadedEventEnd - navigationTiming.fetchStart;
      
      console.log(`Page load time: ${loadTime}ms, DOM ready: ${domContentLoaded}ms`);
      
      // These would be sent as custom events/metrics if we had access to the tracer
      // For now, they're logged for debugging
    }
  }

  public trackCustomEvent(eventName: string, attributes: Record<string, string | number | boolean> = {}): void {
    if (!this.initialized) {
      console.warn('OpenTelemetry not initialized, cannot track custom event');
      return;
    }

    try {
      // For custom event tracking, we would need access to the tracer
      // This is a placeholder for custom event tracking
      console.log(`Custom event: ${eventName}`, attributes);
    } catch (error) {
      console.error('Failed to track custom event:', error);
    }
  }

  public shutdown(): void {
    if (this.sdk && this.initialized) {
      try {
        this.sdk.shutdown();
        this.initialized = false;
        console.log('OpenTelemetry frontend shutdown complete');
      } catch (error) {
        console.error('Error during OpenTelemetry shutdown:', error);
      }
    }
  }
}

// Global telemetry instance
const frontendTelemetry = new FrontendTelemetry();

// Auto-initialize if not in development mode or if explicitly enabled
if (import.meta.env.PROD || import.meta.env.VITE_OTEL_AUTO_INIT === 'true') {
  frontendTelemetry.initialize();
}

export default frontendTelemetry;

// Export individual methods for convenience
export const initializeTelemetry = () => frontendTelemetry.initialize();
export const trackCustomEvent = (eventName: string, attributes?: Record<string, string | number | boolean>) => 
  frontendTelemetry.trackCustomEvent(eventName, attributes);
export const shutdownTelemetry = () => frontendTelemetry.shutdown();