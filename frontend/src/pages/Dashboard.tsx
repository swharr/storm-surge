import { useQuery } from '@tanstack/react-query'
import {
  DollarSign,
  Server,
  Flag,
  TrendingUp,
  TrendingDown,
  Activity,
  Clock,
  CheckCircle,
  XCircle
} from 'lucide-react'
import {
  AreaChart,
  Area,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  PieChart,
  Pie,
  Cell,
} from 'recharts'
import api from '../services/api'
import LoadingSpinner from '../components/LoadingSpinner'
import type { ScalingEvent } from '../types'

export default function Dashboard() {
  const { data: clusters, isLoading: clustersLoading } = useQuery({
    queryKey: ['clusters'],
    queryFn: api.getClusters,
  })

  const { data: flags, isLoading: flagsLoading } = useQuery({
    queryKey: ['flags'],
    queryFn: api.getFeatureFlags,
  })

  const { data: costMetrics, isLoading: costLoading } = useQuery({
    queryKey: ['cost-metrics'],
    queryFn: () => api.getCostMetrics('24h'),
  })

  const { data: costHistory, isLoading: costHistoryLoading } = useQuery({
    queryKey: ['cost-history'],
    queryFn: () => api.getCostHistory('7d'),
  })

  const { data: recentEvents, isLoading: eventsLoading } = useQuery({
    queryKey: ['scaling-events'],
    queryFn: () => api.getScalingEvents(undefined, 10),
  })

  const { data: systemHealth } = useQuery({
    queryKey: ['system-health'],
    queryFn: api.getSystemHealth,
    refetchInterval: 30000,
  })

  const isLoading = clustersLoading || flagsLoading || costLoading

  if (isLoading) {
    return (
      <div className="flex items-center justify-center h-64">
        <LoadingSpinner size="lg" />
      </div>
    )
  }

  const totalClusters = clusters?.length || 0
  const activeClusters = clusters?.filter(c => c.status === 'healthy').length || 0
  const totalFlags = flags?.length || 0
  const activeFlags = flags?.filter(f => f.enabled).length || 0

  const clusterStatusData = clusters?.reduce((acc, cluster) => {
    acc[cluster.status] = (acc[cluster.status] || 0) + 1
    return acc
  }, {} as Record<string, number>) || {}

  const statusColors = {
    healthy: '#22c55e',
    scaling: '#f59e0b',
    error: '#ef4444',
    warning: '#f97316',
  }

  const pieData = Object.entries(clusterStatusData).map(([status, count]) => ({
    name: status,
    value: count,
    color: statusColors[status as keyof typeof statusColors] || '#6b7280',
  }))

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
      {/* Header */}
      <div className="mb-8">
        <h1 className="text-3xl font-bold text-gray-900">Dashboard</h1>
        <p className="mt-2 text-gray-600">Monitor your feature flags and cluster performance</p>
      </div>

      {/* Stats Overview */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
        <StatCard
          title="Total Cost Today"
          value={`$${costMetrics?.currentHourly ? (costMetrics.currentHourly * 24).toFixed(2) : '0.00'}`}
          change={costMetrics?.savingsToday || 0}
          changeType="savings"
          icon={DollarSign}
          color="green"
        />
        <StatCard
          title="Active Clusters"
          value={`${activeClusters}/${totalClusters}`}
          change={((activeClusters / totalClusters) * 100) || 0}
          changeType="percentage"
          icon={Server}
          color="blue"
        />
        <StatCard
          title="Feature Flags"
          value={`${activeFlags}/${totalFlags}`}
          change={((activeFlags / totalFlags) * 100) || 0}
          changeType="percentage"
          icon={Flag}
          color="purple"
        />
        <StatCard
          title="Cost Optimization"
          value={`${costMetrics?.optimizationPercentage?.toFixed(1) || '0.0'}%`}
          change={costMetrics?.optimizationPercentage || 0}
          changeType="percentage"
          icon={TrendingUp}
          color="green"
        />
      </div>

      {/* Charts Section */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-8">
        {/* Cost Trends */}
        <div className="card">
          <div className="card-header">
            <h3 className="text-lg font-semibold text-gray-900">Cost Trends (7 days)</h3>
          </div>
          <div className="card-body">
            {costHistoryLoading ? (
              <div className="flex items-center justify-center h-64">
                <LoadingSpinner />
              </div>
            ) : (
              <ResponsiveContainer width="100%" height={300}>
                <AreaChart data={costHistory}>
                  <CartesianGrid strokeDasharray="3 3" />
                  <XAxis
                    dataKey="timestamp"
                    tickFormatter={(value) => new Date(value).toLocaleDateString()}
                  />
                  <YAxis tickFormatter={(value) => `$${value}`} />
                  <Tooltip
                    labelFormatter={(value) => new Date(value).toLocaleDateString()}
                    formatter={(value: number, name: string) => [
                      `$${value.toFixed(2)}`,
                      name === 'cost' ? 'Cost' : 'Savings'
                    ]}
                  />
                  <Area
                    type="monotone"
                    dataKey="cost"
                    stackId="1"
                    stroke="#ef4444"
                    fill="#fecaca"
                  />
                  <Area
                    type="monotone"
                    dataKey="savings"
                    stackId="1"
                    stroke="#22c55e"
                    fill="#bbf7d0"
                  />
                </AreaChart>
              </ResponsiveContainer>
            )}
          </div>
        </div>

        {/* Cluster Status Distribution */}
        <div className="card">
          <div className="card-header">
            <h3 className="text-lg font-semibold text-gray-900">Cluster Status</h3>
          </div>
          <div className="card-body">
            <ResponsiveContainer width="100%" height={300}>
              <PieChart>
                <Pie
                  data={pieData}
                  cx="50%"
                  cy="50%"
                  labelLine={false}
                  label={({ name, value }) => `${name}: ${value}`}
                  outerRadius={80}
                  fill="#8884d8"
                  dataKey="value"
                >
                  {pieData.map((entry, index) => (
                    <Cell key={`cell-${index}`} fill={entry.color} />
                  ))}
                </Pie>
                <Tooltip />
              </PieChart>
            </ResponsiveContainer>
          </div>
        </div>
      </div>

      {/* Recent Activity */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Recent Scaling Events */}
        <div className="card">
          <div className="card-header">
            <h3 className="text-lg font-semibold text-gray-900 flex items-center">
              <Activity className="w-5 h-5 mr-2" />
              Recent Scaling Events
            </h3>
          </div>
          <div className="card-body">
            {eventsLoading ? (
              <div className="flex items-center justify-center h-32">
                <LoadingSpinner />
              </div>
            ) : (
              <div className="space-y-4">
                {recentEvents?.slice(0, 5).map((event) => (
                  <ScalingEventItem key={event.id} event={event} />
                )) || (
                  <p className="text-gray-500 text-center py-4">No recent scaling events</p>
                )}
              </div>
            )}
          </div>
        </div>

        {/* System Health */}
        <div className="card">
          <div className="card-header">
            <h3 className="text-lg font-semibold text-gray-900">System Health</h3>
          </div>
          <div className="card-body">
            {systemHealth ? (
              <div className="space-y-4">
                <div className="flex items-center justify-between">
                  <span className="text-gray-600">Overall Status</span>
                  <StatusBadge status={systemHealth.status} />
                </div>
                <div className="space-y-2">
                  {Object.entries(systemHealth.components).map(([component, status]) => (
                    <div key={component} className="flex items-center justify-between">
                      <span className="text-sm text-gray-600 capitalize">{component}</span>
                      <div className="flex items-center space-x-2">
                        {status === 'up' ? (
                          <CheckCircle className="w-4 h-4 text-success-500" />
                        ) : (
                          <XCircle className="w-4 h-4 text-danger-500" />
                        )}
                        <span className="text-sm capitalize">{status}</span>
                      </div>
                    </div>
                  ))}
                </div>
                <div className="pt-4 border-t border-gray-200">
                  <div className="text-sm text-gray-500">
                    <div>Version: {systemHealth.version}</div>
                    <div>Uptime: {Math.floor(systemHealth.uptime / 3600)}h {Math.floor((systemHealth.uptime % 3600) / 60)}m</div>
                    <div>Last Check: {new Date(systemHealth.lastHealthCheck).toLocaleTimeString()}</div>
                  </div>
                </div>
              </div>
            ) : (
              <div className="flex items-center justify-center h-32">
                <LoadingSpinner />
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  )
}

interface StatCardProps {
  title: string
  value: string
  change: number
  changeType: 'savings' | 'percentage' | 'value'
  icon: React.ComponentType<any>
  color: 'green' | 'blue' | 'purple' | 'red'
}

function StatCard({ title, value, change, changeType, icon: Icon, color }: StatCardProps) {
  const colorClasses = {
    green: 'text-success-600 bg-success-100',
    blue: 'text-primary-600 bg-primary-100',
    purple: 'text-purple-600 bg-purple-100',
    red: 'text-danger-600 bg-danger-100',
  }

  const getChangeDisplay = () => {
    if (changeType === 'savings') {
      return change > 0 ? `+$${change.toFixed(2)} saved` : 'No savings'
    } else if (changeType === 'percentage') {
      return `${change.toFixed(1)}%`
    } else {
      return `${change > 0 ? '+' : ''}${change}`
    }
  }

  const getChangeColor = () => {
    if (changeType === 'savings') {
      return change > 0 ? 'text-success-600' : 'text-gray-500'
    } else {
      return change > 0 ? 'text-success-600' : 'text-danger-600'
    }
  }

  return (
    <div className="stat-card">
      <div className="flex items-center">
        <div className={`flex-shrink-0 p-3 rounded-lg ${colorClasses[color]}`}>
          <Icon className="w-6 h-6" />
        </div>
        <div className="ml-4 flex-1">
          <div className="stat-label">{title}</div>
          <div className="flex items-baseline">
            <div className="stat-value">{value}</div>
            <div className={`ml-2 text-sm font-medium ${getChangeColor()}`}>
              {getChangeDisplay()}
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}

interface ScalingEventItemProps {
  event: ScalingEvent
}

function ScalingEventItem({ event }: ScalingEventItemProps) {
  const getEventIcon = () => {
    if (!event.success) return <XCircle className="w-4 h-4 text-danger-500" />
    if (event.eventType === 'scale_up') return <TrendingUp className="w-4 h-4 text-success-500" />
    if (event.eventType === 'scale_down') return <TrendingDown className="w-4 h-4 text-warning-500" />
    return <Activity className="w-4 h-4 text-primary-500" />
  }

  return (
    <div className="flex items-start space-x-3">
      <div className="flex-shrink-0 mt-1">
        {getEventIcon()}
      </div>
      <div className="flex-1 min-w-0">
        <div className="text-sm font-medium text-gray-900">
          {event.clusterId} scaled {event.eventType.replace('_', ' ')}
        </div>
        <div className="text-sm text-gray-500">
          {event.oldNodeCount} → {event.newNodeCount} nodes
        </div>
        <div className="text-xs text-gray-400 flex items-center space-x-4">
          <span className="flex items-center">
            <Clock className="w-3 h-3 mr-1" />
            {new Date(event.timestamp).toLocaleTimeString()}
          </span>
          <span>{event.duration}ms</span>
        </div>
      </div>
    </div>
  )
}

function StatusBadge({ status }: { status: string }) {
  const statusConfig = {
    healthy: { label: 'Healthy', className: 'badge-success' },
    degraded: { label: 'Degraded', className: 'badge-warning' },
    down: { label: 'Down', className: 'badge-danger' },
  }

  const config = statusConfig[status as keyof typeof statusConfig] || {
    label: status,
    className: 'badge-gray'
  }

  return (
    <span className={`badge ${config.className}`}>
      {config.label}
    </span>
  )
}
