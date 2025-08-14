import { useQuery } from '@tanstack/react-query'
import { Card, CardContent, CardHeader, CardTitle } from '../components/ui/card'
import LoadingSpinner from '../components/LoadingSpinner'

function Status() {
  const { data: health, isLoading: healthLoading } = useQuery({
    queryKey: ['health'],
    queryFn: async () => {
      const response = await fetch('/health')
      if (!response.ok) throw new Error('Health check failed')
      return response.json()
    },
    refetchInterval: 5000,
  })

  const isHealthy = health?.status === 'healthy'

  return (
    <div className="p-6 space-y-6">
      <h1 className="text-2xl font-bold">System Status</h1>
      
      <Card>
        <CardHeader>
          <CardTitle>Health Check</CardTitle>
        </CardHeader>
        <CardContent>
          {healthLoading ? (
            <LoadingSpinner />
          ) : (
            <div className="space-y-4">
              <div className="flex items-center gap-3">
                <div className={`w-4 h-4 rounded-full ${
                  isHealthy ? 'bg-green-500' : 'bg-red-500'
                }`} />
                <span className="text-lg font-medium">
                  {isHealthy ? 'System Healthy' : 'System Unhealthy'}
                </span>
              </div>
              
              {health && (
                <div className="mt-4 p-4 bg-gray-100 rounded-md">
                  <pre className="text-sm font-mono">
                    {JSON.stringify(health, null, 2)}
                  </pre>
                </div>
              )}
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  )
}

export default Status