// Core types for Storm Surge Dashboard
export interface User {
  id: string
  email: string
  name: string
  role: 'admin' | 'operator' | 'viewer'
  avatar?: string
  lastLogin?: string
  createdAt: string
  // Backend fields for compatibility
  is_active?: boolean
  last_login?: string  // Backend uses snake_case
}

export interface FeatureFlag {
  key: string
  name: string
  description: string
  enabled: boolean
  provider: 'launchdarkly' | 'statsig'
  environments: string[]
  lastModified: string
  modifiedBy: string
  tags: string[]
  rules?: FlagRule[]
}

export interface FlagRule {
  id: string
  name: string
  conditions: Condition[]
  actions: Action[]
  enabled: boolean
}

export interface Condition {
  attribute: string
  operator: 'equals' | 'contains' | 'greater_than' | 'less_than'
  value: string | number | boolean
}

export interface Action {
  type: 'serve_variation' | 'track_event'
  value: any
}

export interface ClusterMetrics {
  clusterId: string
  clusterName: string
  provider: 'gcp' | 'aws' | 'azure'
  currentNodes: number
  targetNodes: number
  minNodes: number
  maxNodes: number
  cpuUtilization: number
  memoryUtilization: number
  costPerHour: number
  estimatedMonthlyCost: number
  lastScalingEvent?: ScalingEvent
  status: 'healthy' | 'scaling' | 'error' | 'warning'
  lastUpdated: string
}

export interface ScalingEvent {
  id: string
  clusterId: string
  eventType: 'scale_up' | 'scale_down' | 'cost_optimization' | 'manual'
  oldNodeCount: number
  newNodeCount: number
  reason: string
  triggeredBy: string
  timestamp: string
  success: boolean
  duration: number
  costImpact?: number
}

export interface CostMetrics {
  currentHourly: number
  projectedDaily: number
  projectedMonthly: number
  savingsToday: number
  savingsThisMonth: number
  optimizationPercentage: number
  lastOptimization?: string
}

export interface AlertRule {
  id: string
  name: string
  type: 'cost_threshold' | 'scaling_failure' | 'flag_change' | 'cluster_health'
  condition: {
    metric: string
    operator: 'greater_than' | 'less_than' | 'equals'
    threshold: number
    duration: number
  }
  actions: {
    email?: string[]
    webhook?: string
    slack?: string
  }
  enabled: boolean
  lastTriggered?: string
  createdBy: string
  createdAt: string
}

export interface AuditLogEntry {
  id: string
  timestamp: string
  userId: string
  userName: string
  action: string
  resource: string
  resourceId: string
  details: Record<string, any>
  ipAddress?: string
  userAgent?: string
}

export interface SystemHealth {
  status: 'healthy' | 'degraded' | 'down'
  components: {
    api: 'up' | 'down'
    database: 'up' | 'down'
    flagProvider: 'up' | 'down'
    clusters: 'up' | 'down'
  }
  uptime: number
  lastHealthCheck: string
  version: string
}

export interface NotificationSettings {
  email: boolean
  inApp: boolean
  slack: boolean
  webhooks: string[]
  quietHours: {
    enabled: boolean
    start: string
    end: string
    timezone: string
  }
}

export interface DashboardConfig {
  refreshInterval: number
  defaultTimeRange: '1h' | '6h' | '24h' | '7d' | '30d'
  theme: 'light' | 'dark' | 'system'
  layout: 'compact' | 'comfortable'
  widgets: {
    id: string
    type: string
    position: { x: number; y: number }
    size: { width: number; height: number }
    config: Record<string, any>
  }[]
}

// API Response types
export interface ApiResponse<T> {
  data: T
  success: boolean
  message?: string
  timestamp: string
}

export interface PaginatedResponse<T> {
  data: T[]
  pagination: {
    page: number
    limit: number
    total: number
    totalPages: number
  }
}

// WebSocket event types
export interface WebSocketEvent {
  type: 'flag_changed' | 'cluster_scaled' | 'alert_triggered' | 'system_health'
  data: any
  timestamp: string
}

// Form types
export interface CreateFlagForm {
  key: string
  name: string
  description: string
  provider: 'launchdarkly' | 'statsig'
  environments: string[]
  tags: string[]
}

export interface ClusterConfigForm {
  name: string
  provider: 'gcp' | 'aws' | 'azure'
  region: string
  minNodes: number
  maxNodes: number
  nodeType: string
  autoScaling: boolean
  costOptimization: boolean
}
