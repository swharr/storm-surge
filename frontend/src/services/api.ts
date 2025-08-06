import axios, { AxiosInstance, AxiosResponse } from 'axios'
import { toast } from 'react-hot-toast'
import type {
  User,
  FeatureFlag,
  ClusterMetrics,
  ScalingEvent,
  CostMetrics,
  AlertRule,
  AuditLogEntry,
  SystemHealth,
  PaginatedResponse,
  CreateFlagForm,
  ClusterConfigForm,
} from '../types'

class ApiService {
  private client: AxiosInstance

  constructor() {
    this.client = axios.create({
      baseURL: '/api',
      timeout: 10000,
      headers: {
        'Content-Type': 'application/json',
      },
    })

    this.setupInterceptors()
  }

  private setupInterceptors() {
    // Request interceptor
    this.client.interceptors.request.use(
      (config) => {
        const token = localStorage.getItem('storm_surge_token')
        if (token) {
          config.headers.Authorization = `Bearer ${token}`
        }
        return config
      },
      (error) => Promise.reject(error)
    )

    // Response interceptor
    this.client.interceptors.response.use(
      (response: AxiosResponse) => response,
      (error) => {
        if (error.response?.status === 401) {
          localStorage.removeItem('storm_surge_token')
          window.location.href = '/login'
        } else if (error.response?.status >= 500) {
          toast.error('Server error occurred. Please try again.')
        } else if (error.code === 'ECONNABORTED') {
          toast.error('Request timeout. Please check your connection.')
        }
        return Promise.reject(error)
      }
    )
  }

  // Auth endpoints
  async login(email: string, password: string): Promise<{ token: string; user: User }> {
    const response = await this.client.post('/auth/login', { email, password })
    
    if (response.data.token) {
      localStorage.setItem('storm_surge_token', response.data.token)
    }
    
    return response.data
  }

  async logout(): Promise<void> {
    await this.client.post('/auth/logout')
    localStorage.removeItem('storm_surge_token')
  }

  async getCurrentUser(): Promise<User> {
    const response = await this.client.get('/auth/me')
    return response.data
  }

  async register(userData: {
    email: string;
    password: string;
    name: string;
    role: string;
  }): Promise<{ message: string; user: User }> {
    const response = await this.client.post('/auth/register', userData)
    return response.data
  }

  async changePassword(currentPassword: string, newPassword: string): Promise<{ message: string }> {
    const response = await this.client.post('/auth/change-password', {
      current_password: currentPassword,
      new_password: newPassword
    })
    return response.data
  }

  // User management (admin only)
  async getUsers(): Promise<User[]> {
    const response = await this.client.get('/users')
    return response.data
  }

  async getUser(userId: string): Promise<User> {
    const response = await this.client.get(`/users/${userId}`)
    return response.data
  }

  async updateUser(userId: string, updates: Partial<User>): Promise<User> {
    const response = await this.client.put(`/users/${userId}`, updates)
    return response.data
  }

  async deleteUser(userId: string): Promise<{ message: string }> {
    const response = await this.client.delete(`/users/${userId}`)
    return response.data
  }

  async resetUserPassword(userId: string, newPassword: string): Promise<{ message: string }> {
    const response = await this.client.post(`/users/${userId}/reset-password`, {
      new_password: newPassword
    })
    return response.data
  }

  // Feature flags
  async getFeatureFlags(): Promise<FeatureFlag[]> {
    const response = await this.client.get('/flags')
    return response.data
  }

  async getFeatureFlag(key: string): Promise<FeatureFlag> {
    const response = await this.client.get(`/flags/${key}`)
    return response.data
  }

  async createFeatureFlag(flag: CreateFlagForm): Promise<FeatureFlag> {
    const response = await this.client.post('/flags', flag)
    return response.data
  }

  async updateFeatureFlag(key: string, updates: Partial<FeatureFlag>): Promise<FeatureFlag> {
    const response = await this.client.patch(`/flags/${key}`, updates)
    return response.data
  }

  async toggleFeatureFlag(key: string, enabled: boolean): Promise<FeatureFlag> {
    const response = await this.client.patch(`/flags/${key}/toggle`, { enabled })
    return response.data
  }

  async deleteFeatureFlag(key: string): Promise<void> {
    await this.client.delete(`/flags/${key}`)
  }

  // Clusters
  async getClusters(): Promise<ClusterMetrics[]> {
    const response = await this.client.get('/clusters')
    return response.data
  }

  async getCluster(clusterId: string): Promise<ClusterMetrics> {
    const response = await this.client.get(`/clusters/${clusterId}`)
    return response.data
  }

  async createCluster(cluster: ClusterConfigForm): Promise<ClusterMetrics> {
    const response = await this.client.post('/clusters', cluster)
    return response.data
  }

  async scaleCluster(clusterId: string, nodeCount: number): Promise<ScalingEvent> {
    const response = await this.client.post(`/clusters/${clusterId}/scale`, { nodeCount })
    return response.data
  }

  async deleteCluster(clusterId: string): Promise<void> {
    await this.client.delete(`/clusters/${clusterId}`)
  }

  // Scaling events
  async getScalingEvents(clusterId?: string, limit = 50): Promise<ScalingEvent[]> {
    const params = new URLSearchParams()
    if (clusterId) params.append('clusterId', clusterId)
    params.append('limit', limit.toString())
    
    const response = await this.client.get(`/scaling-events?${params}`)
    return response.data
  }

  // Cost metrics
  async getCostMetrics(timeRange = '24h'): Promise<CostMetrics> {
    const response = await this.client.get(`/costs/metrics?range=${timeRange}`)
    return response.data
  }

  async getCostHistory(timeRange = '7d'): Promise<Array<{ timestamp: string; cost: number; savings: number }>> {
    const response = await this.client.get(`/costs/history?range=${timeRange}`)
    return response.data
  }

  // Alerts
  async getAlertRules(): Promise<AlertRule[]> {
    const response = await this.client.get('/alerts/rules')
    return response.data
  }

  async createAlertRule(rule: Omit<AlertRule, 'id' | 'createdAt' | 'createdBy'>): Promise<AlertRule> {
    const response = await this.client.post('/alerts/rules', rule)
    return response.data
  }

  async updateAlertRule(id: string, updates: Partial<AlertRule>): Promise<AlertRule> {
    const response = await this.client.patch(`/alerts/rules/${id}`, updates)
    return response.data
  }

  async deleteAlertRule(id: string): Promise<void> {
    await this.client.delete(`/alerts/rules/${id}`)
  }

  async getAlertHistory(limit = 100): Promise<Array<{ id: string; ruleId: string; timestamp: string; message: string }>> {
    const response = await this.client.get(`/alerts/history?limit=${limit}`)
    return response.data
  }

  // Audit logs
  async getAuditLogs(
    page = 1,
    limit = 50,
    filters?: { userId?: string; action?: string; resource?: string }
  ): Promise<PaginatedResponse<AuditLogEntry>> {
    const params = new URLSearchParams()
    params.append('page', page.toString())
    params.append('limit', limit.toString())
    
    if (filters) {
      Object.entries(filters).forEach(([key, value]) => {
        if (value) params.append(key, value)
      })
    }

    const response = await this.client.get(`/audit-logs?${params}`)
    return response.data
  }

  // System health
  async getSystemHealth(): Promise<SystemHealth> {
    const response = await this.client.get('/health')
    return response.data
  }

  // Analytics
  async getAnalytics(type: 'cost' | 'usage' | 'performance', timeRange = '7d'): Promise<any> {
    const response = await this.client.get(`/analytics/${type}?range=${timeRange}`)
    return response.data
  }

  // Settings
  async getSettings(): Promise<Record<string, any>> {
    const response = await this.client.get('/settings')
    return response.data
  }

  async updateSettings(settings: Record<string, any>): Promise<Record<string, any>> {
    const response = await this.client.patch('/settings', settings)
    return response.data
  }

  // Test connections
  async testConnection(provider: 'launchdarkly' | 'statsig', credentials: Record<string, string>): Promise<{ success: boolean; message: string }> {
    const response = await this.client.post('/test-connection', { provider, credentials })
    return response.data
  }

  // Export data
  async exportData(type: 'audit_logs' | 'scaling_events' | 'cost_reports', format = 'csv'): Promise<Blob> {
    const response = await this.client.get(`/export/${type}?format=${format}`, {
      responseType: 'blob',
    })
    return response.data
  }
}

export const api = new ApiService()
export default api