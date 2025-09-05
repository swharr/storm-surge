import { Routes, Route, Navigate } from 'react-router-dom'
import { useQuery } from '@tanstack/react-query'
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

function App() {
  const { data: user, isLoading, error } = useQuery({
    queryKey: ['user'],
    queryFn: api.getCurrentUser,
    retry: false,
  })

  // Initialize WebSocket connection for authenticated users
  useWebSocket({ autoConnect: !!user })

  if (isLoading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <LoadingSpinner size="lg" />
      </div>
    )
  }

  if (error) {
    return (
      <Routes>
        <Route path="/login" element={<Login />} />
        <Route path="*" element={<Navigate to="/login" replace />} />
      </Routes>
    )
  }

  return (
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
  )
}

export default App
