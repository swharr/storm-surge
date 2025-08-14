import { useQuery } from '@tanstack/react-query'
import { Card, CardContent, CardHeader, CardTitle } from '../components/ui/card'
import LoadingSpinner from '../components/LoadingSpinner'

function Dashboard() {
  const { data: status, isLoading } = useQuery({
    queryKey: ['status'],
    queryFn: async () => {
      const response = await fetch('/api/v1/status')
      if (!response.ok) throw new Error('Failed to fetch status')
      return response.json()
    },
    refetchInterval: 5000,
  })

  const { data: metrics } = useQuery({
    queryKey: ['metrics'],
    queryFn: async () => {
      const response = await fetch('/api/v1/metrics')
      if (!response.ok) throw new Error('Failed to fetch metrics')
      return response.json()
    },
    refetchInterval: 10000,
  })

  if (isLoading) {
    return (
      <div className="flex items-center justify-center h-64">
        <LoadingSpinner size="lg" />
      </div>
    )
  }

  return (
    <div className="p-6 space-y-6">
      <h1 className="text-2xl font-bold">Storm Surge Core Dashboard</h1>
      
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        <Card>
          <CardHeader>
            <CardTitle>Application Status</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="space-y-2">
              <div className="flex justify-between">
                <span className="text-gray-600">Status:</span>
                <span className="font-medium text-green-600">
                  {status?.status || 'Unknown'}
                </span>
              </div>
              <div className="flex justify-between">
                <span className="text-gray-600">Version:</span>
                <span className="font-mono text-sm">{status?.application || 'N/A'}</span>
              </div>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Environment</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="space-y-2">
              <div className="flex justify-between">
                <span className="text-gray-600">Namespace:</span>
                <span className="font-mono text-sm">
                  {status?.environment?.namespace || 'N/A'}
                </span>
              </div>
              <div className="flex justify-between">
                <span className="text-gray-600">Cluster:</span>
                <span className="font-mono text-sm">
                  {status?.environment?.cluster || 'N/A'}
                </span>
              </div>
              <div className="flex justify-between">
                <span className="text-gray-600">Pod:</span>
                <span className="font-mono text-sm truncate max-w-[150px]" title={status?.environment?.pod_name}>
                  {status?.environment?.pod_name || 'N/A'}
                </span>
              </div>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Metrics</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="space-y-2">
              <div className="flex justify-between">
                <span className="text-gray-600">Uptime:</span>
                <span className="font-medium">
                  {metrics?.uptime ? formatUptime(metrics.uptime) : 'N/A'}
                </span>
              </div>
              <div className="flex justify-between">
                <span className="text-gray-600">Requests:</span>
                <span className="font-medium">
                  {metrics?.requests_total?.toLocaleString() || '0'}
                </span>
              </div>
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  )
}

function formatUptime(seconds: number): string {
  const days = Math.floor(seconds / 86400)
  const hours = Math.floor((seconds % 86400) / 3600)
  const minutes = Math.floor((seconds % 3600) / 60)
  
  if (days > 0) {
    return `${days}d ${hours}h ${minutes}m`
  } else if (hours > 0) {
    return `${hours}h ${minutes}m`
  } else {
    return `${minutes}m`
  }
}

export default Dashboard