#!/usr/bin/env typescript
/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_APP_VERSION: string
  readonly VITE_ENVIRONMENT: string
  readonly VITE_API_BASE_URL: string
  readonly VITE_WS_URL: string
  readonly VITE_FEATURE_FLAG_PROVIDER: string
  readonly VITE_LAUNCHDARKLY_CLIENT_ID: string
  readonly VITE_LAUNCHDARKLY_TRACKING_ID: string
  readonly VITE_STATSIG_CLIENT_KEY: string
  readonly VITE_OTEL_EXPORTER_OTLP_ENDPOINT: string
  readonly VITE_OTEL_ENABLE_OTLP: string
  readonly VITE_OTEL_ENABLE_CONSOLE: string
  readonly VITE_OTEL_AUTO_INIT: string
}

interface ImportMeta {
  readonly env: ImportMetaEnv
}