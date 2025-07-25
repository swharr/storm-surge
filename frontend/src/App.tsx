import { Routes, Route, Navigate } from 'react-router-dom'
import { useQuery } from '@tanstack/react-query'
import { useEffect } from 'react'
import Layout from './components/Layout'
import Login from './pages/Login'
import Dashboard from './pages/Dashboard'
import FeatureFlags from './pages/FeatureFlags'
import Clusters from './pages/Clusters'
import Analytics from './pages/Analytics'
import Alerts from './pages/Alerts'
import AuditLogs from './pages/AuditLogs'
import Settings from './pages/Settings'
import UserManagement from './pages/UserManagement'
import api from './services/api'
import LoadingSpinner from './components/LoadingSpinner'
import { useWebSocket } from './hooks/useWebSocket'
import { initializeTelemetry, trackCustomEvent } from './telemetry'
import { FeatureFlagProvider } from './providers/FeatureFlagProvider'

function App() {
  const token = localStorage.getItem('storm_surge_token')

  // Initialize OpenTelemetry on app startup
  useEffect(() => {
    initializeTelemetry()
    trackCustomEvent('app_initialized', {
      has_token: !!token,
      timestamp: Date.now()
    })
  }, [])

  const { data: user, isLoading, error } = useQuery({
    queryKey: ['user'],
    queryFn: api.getCurrentUser,
    enabled: !!token,
    retry: false,
    onSuccess: (userData) => {
      trackCustomEvent('user_authenticated', {
        user_role: userData?.role || 'unknown',
        user_id: userData?.id || 'unknown'
      })
    },
    onError: () => {
      trackCustomEvent('authentication_failed', {
        has_token: !!token
      })
    }
  })

  // Initialize WebSocket connection for authenticated users
  useWebSocket({
    autoConnect: !!token && !!user,
  })

  if (isLoading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <LoadingSpinner size="lg" />
      </div>
    )
  }

  if (!token || error) {
    return (
      <Routes>
        <Route path="/login" element={<Login />} />
        <Route path="*" element={<Navigate to="/login" replace />} />
      </Routes>
    )
  }

  return (
    <FeatureFlagProvider user={{
      id: user?.id || 'unknown',
      email: user?.email,
      name: user?.name,
      role: user?.role,
      custom: {
        organization: user?.organization || 'storm-surge',
        environment: import.meta.env.VITE_ENVIRONMENT || 'development'
      }
    }}>
      <Layout user={user}>
        <Routes>
          <Route path="/" element={<Navigate to="/dashboard" replace />} />
          <Route path="/dashboard" element={<Dashboard />} />
          <Route path="/flags" element={<FeatureFlags />} />
          <Route path="/clusters" element={<Clusters />} />
          <Route path="/analytics" element={<Analytics />} />
          <Route path="/alerts" element={<Alerts />} />
          <Route path="/audit" element={<AuditLogs />} />
          <Route path="/settings" element={<Settings />} />
          {user?.role === 'admin' && (
            <Route path="/users" element={<UserManagement />} />
          )}
          <Route path="*" element={<Navigate to="/dashboard" replace />} />
        </Routes>
      </Layout>
    </FeatureFlagProvider>
  )
}

export default App