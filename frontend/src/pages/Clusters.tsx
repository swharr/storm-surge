import { useQuery } from '@tanstack/react-query'
import { Server, Plus, Activity, TrendingUp, TrendingDown } from 'lucide-react'
import api from '../services/api'
import LoadingSpinner from '../components/LoadingSpinner'
import type { ClusterMetrics } from '../types'

export default function Clusters() {
  const { data: clusters, isLoading } = useQuery({
    queryKey: ['clusters'],
    queryFn: api.getClusters,
  })

  if (isLoading) {
    return (
      <div className="flex items-center justify-center h-64">
        <LoadingSpinner size="lg" />
      </div>
    )
  }

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
      {/* Header */}
      <div className="mb-8">
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-3xl font-bold text-gray-900">Clusters</h1>
            <p className="mt-2 text-gray-600">Monitor and manage your Kubernetes clusters</p>
          </div>
          <button className="btn-primary btn-md">
            <Plus className="w-4 h-4 mr-2" />
            Add Cluster
          </button>
        </div>
      </div>

      {/* Clusters Grid */}
      <div className="grid grid-cols-1 lg:grid-cols-2 xl:grid-cols-3 gap-6">
        {clusters?.map((cluster) => (
          <ClusterCard key={cluster.clusterId} cluster={cluster} />
        ))}
      </div>

      {(!clusters || clusters.length === 0) && (
        <div className="text-center py-12">
          <Server className="mx-auto h-12 w-12 text-gray-400" />
          <h3 className="mt-2 text-sm font-medium text-gray-900">No clusters</h3>
          <p className="mt-1 text-sm text-gray-500">
            Get started by adding your first cluster.
          </p>
          <div className="mt-6">
            <button className="btn-primary btn-md">
              <Plus className="w-4 h-4 mr-2" />
              Add Cluster
            </button>
          </div>
        </div>
      )}
    </div>
  )
}

function ClusterCard({ cluster }: { cluster: ClusterMetrics }) {
  const getStatusColor = (status: string) => {
    switch (status) {
      case 'healthy':
        return 'bg-success-100 text-success-800'
      case 'scaling':
        return 'bg-warning-100 text-warning-800'
      case 'error':
        return 'bg-danger-100 text-danger-800'
      case 'warning':
        return 'bg-warning-100 text-warning-800'
      default:
        return 'bg-gray-100 text-gray-800'
    }
  }

  const getProviderIcon = (provider: string) => {
    switch (provider) {
      case 'gcp':
        return '🟢'
      case 'aws':
        return '🟠'
      case 'azure':
        return '🔵'
      default:
        return '☁️'
    }
  }

  return (
    <div className="card">
      <div className="card-header">
        <div className="flex items-center justify-between">
          <div className="flex items-center space-x-3">
            <span className="text-2xl">{getProviderIcon(cluster.provider)}</span>
            <div>
              <h3 className="text-lg font-semibold text-gray-900">{cluster.clusterName}</h3>
              <p className="text-sm text-gray-500">{cluster.clusterId}</p>
            </div>
          </div>
          <span className={`badge ${getStatusColor(cluster.status)}`}>
            {cluster.status}
          </span>
        </div>
      </div>

      <div className="card-body space-y-4">
        {/* Node Information */}
        <div className="grid grid-cols-3 gap-4 text-center">
          <div>
            <div className="text-2xl font-bold text-gray-900">{cluster.currentNodes}</div>
            <div className="text-xs text-gray-500">Current</div>
          </div>
          <div>
            <div className="text-2xl font-bold text-primary-600">{cluster.targetNodes}</div>
            <div className="text-xs text-gray-500">Target</div>
          </div>
          <div>
            <div className="text-2xl font-bold text-gray-600">{cluster.maxNodes}</div>
            <div className="text-xs text-gray-500">Max</div>
          </div>
        </div>

        {/* Resource Utilization */}
        <div className="space-y-3">
          <div>
            <div className="flex justify-between text-sm mb-1">
              <span>CPU Utilization</span>
              <span>{cluster.cpuUtilization}%</span>
            </div>
            <div className="w-full bg-gray-200 rounded-full h-2">
              <div
                className="bg-primary-600 h-2 rounded-full"
                style={{ width: `${cluster.cpuUtilization}%` }}
              />
            </div>
          </div>

          <div>
            <div className="flex justify-between text-sm mb-1">
              <span>Memory Utilization</span>
              <span>{cluster.memoryUtilization}%</span>
            </div>
            <div className="w-full bg-gray-200 rounded-full h-2">
              <div
                className="bg-success-600 h-2 rounded-full"
                style={{ width: `${cluster.memoryUtilization}%` }}
              />
            </div>
          </div>
        </div>

        {/* Cost Information */}
        <div className="bg-gray-50 rounded-lg p-3">
          <div className="flex justify-between items-center">
            <div>
              <div className="text-sm text-gray-600">Cost per hour</div>
              <div className="text-lg font-semibold text-gray-900">
                ${cluster.costPerHour.toFixed(2)}
              </div>
            </div>
            <div className="text-right">
              <div className="text-sm text-gray-600">Monthly est.</div>
              <div className="text-lg font-semibold text-gray-900">
                ${cluster.estimatedMonthlyCost.toFixed(0)}
              </div>
            </div>
          </div>
        </div>

        {/* Last Scaling Event */}
        {cluster.lastScalingEvent && (
          <div className="border-t pt-3">
            <div className="flex items-center space-x-2">
              <Activity className="w-4 h-4 text-gray-400" />
              <span className="text-sm text-gray-600">Last scaling:</span>
              {cluster.lastScalingEvent.eventType === 'scale_up' ? (
                <TrendingUp className="w-4 h-4 text-success-500" />
              ) : (
                <TrendingDown className="w-4 h-4 text-warning-500" />
              )}
              <span className="text-sm text-gray-900">
                {new Date(cluster.lastScalingEvent.timestamp).toLocaleDateString()}
              </span>
            </div>
          </div>
        )}
      </div>

      <div className="card-footer">
        <div className="flex items-center justify-between">
          <span className="text-xs text-gray-500">
            Updated {new Date(cluster.lastUpdated).toLocaleTimeString()}
          </span>
          <div className="flex space-x-2">
            <button className="btn-secondary btn-sm">Details</button>
            <button className="btn-primary btn-sm">Scale</button>
          </div>
        </div>
      </div>
    </div>
  )
}