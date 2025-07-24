import React, { useState } from 'react'
import { NavLink, useLocation } from 'react-router-dom'
import { 
  LayoutDashboard, 
  Flag, 
  Server, 
  BarChart3, 
  Bell, 
  FileText, 
  Settings, 
  LogOut, 
  Menu, 
  X,
  Zap,
  User,
  Users
} from 'lucide-react'
import { useQuery } from '@tanstack/react-query'
import api from '../services/api'
import type { User, SystemHealth } from '../types'

interface LayoutProps {
  user: User
  children: React.ReactNode
}

const getNavigation = (userRole: string) => {
  const baseNavigation = [
    { name: 'Dashboard', href: '/dashboard', icon: LayoutDashboard },
    { name: 'Feature Flags', href: '/flags', icon: Flag },
    { name: 'Clusters', href: '/clusters', icon: Server },
    { name: 'Analytics', href: '/analytics', icon: BarChart3 },
    { name: 'Alerts', href: '/alerts', icon: Bell },
    { name: 'Audit Logs', href: '/audit', icon: FileText },
    { name: 'Settings', href: '/settings', icon: Settings },
  ]

  // Add user management for admins
  if (userRole === 'admin') {
    baseNavigation.splice(-1, 0, { name: 'User Management', href: '/users', icon: Users })
  }

  return baseNavigation
}

export default function Layout({ user, children }: LayoutProps) {
  const [sidebarOpen, setSidebarOpen] = useState(false)
  const location = useLocation()
  const navigation = getNavigation(user.role)

  const { data: systemHealth } = useQuery({
    queryKey: ['system-health'],
    queryFn: api.getSystemHealth,
    refetchInterval: 30000, // Refresh every 30 seconds
  })

  const handleLogout = async () => {
    try {
      await api.logout()
      window.location.href = '/login'
    } catch (error) {
      // Force logout even if API call fails
      localStorage.removeItem('storm_surge_token')
      window.location.href = '/login'
    }
  }

  const getHealthColor = (status: string) => {
    switch (status) {
      case 'healthy':
        return 'text-success-500'
      case 'degraded':
        return 'text-warning-500'
      case 'down':
        return 'text-danger-500'
      default:
        return 'text-gray-500'
    }
  }

  return (
    <div className="h-screen flex overflow-hidden bg-gray-100">
      {/* Mobile sidebar overlay */}
      {sidebarOpen && (
        <div className="fixed inset-0 flex z-40 md:hidden">
          <div
            className="fixed inset-0 bg-gray-600 bg-opacity-75"
            onClick={() => setSidebarOpen(false)}
          />
          <div className="relative flex-1 flex flex-col max-w-xs w-full bg-white">
            <div className="absolute top-0 right-0 -mr-12 pt-2">
              <button
                type="button"
                className="ml-1 flex items-center justify-center h-10 w-10 rounded-full focus:outline-none focus:ring-2 focus:ring-inset focus:ring-white"
                onClick={() => setSidebarOpen(false)}
              >
                <X className="h-6 w-6 text-white" />
              </button>
            </div>
            <SidebarContent 
              navigation={navigation} 
              location={location} 
              systemHealth={systemHealth} 
              user={user}
              onLogout={handleLogout}
            />
          </div>
        </div>
      )}

      {/* Desktop sidebar */}
      <div className="hidden md:flex md:flex-shrink-0">
        <div className="flex flex-col w-64">
          <SidebarContent 
            navigation={navigation} 
            location={location} 
            systemHealth={systemHealth} 
            user={user}
            onLogout={handleLogout}
          />
        </div>
      </div>

      {/* Main content */}
      <div className="flex flex-col w-0 flex-1 overflow-hidden">
        {/* Top bar */}
        <div className="relative z-10 flex-shrink-0 flex h-16 bg-white shadow">
          <button
            type="button"
            className="px-4 border-r border-gray-200 text-gray-500 focus:outline-none focus:ring-2 focus:ring-inset focus:ring-primary-500 md:hidden"
            onClick={() => setSidebarOpen(true)}
          >
            <Menu className="h-6 w-6" />
          </button>
          
          <div className="flex-1 px-4 flex justify-between items-center">
            <div className="flex-1 flex">
              <h1 className="text-2xl font-semibold text-gray-900">
                {navigation.find(item => item.href === location.pathname)?.name || 'Storm Surge'}
              </h1>
            </div>
            
            <div className="ml-4 flex items-center md:ml-6 space-x-4">
              {/* System health indicator */}
              {systemHealth && (
                <div className="flex items-center space-x-2">
                  <div className={`w-2 h-2 rounded-full ${getHealthColor(systemHealth.status) === 'text-success-500' ? 'bg-success-500' : getHealthColor(systemHealth.status) === 'text-warning-500' ? 'bg-warning-500' : 'bg-danger-500'}`} />
                  <span className="text-sm text-gray-600 capitalize">{systemHealth.status}</span>
                </div>
              )}
              
              {/* User menu */}
              <div className="flex items-center space-x-3">
                <div className="flex items-center space-x-2">
                  <div className="w-8 h-8 bg-primary-100 rounded-full flex items-center justify-center">
                    <User className="w-4 h-4 text-primary-600" />
                  </div>
                  <div className="hidden md:block">
                    <div className="text-sm font-medium text-gray-900">{user.name}</div>
                    <div className="text-xs text-gray-500">{user.role}</div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* Page content */}
        <main className="flex-1 relative overflow-y-auto focus:outline-none">
          <div className="py-6">
            {children}
          </div>
        </main>
      </div>
    </div>
  )
}

interface SidebarContentProps {
  navigation: typeof navigation
  location: { pathname: string }
  systemHealth?: SystemHealth
  user: User
  onLogout: () => void
}

function SidebarContent({ navigation, location, systemHealth, user, onLogout }: SidebarContentProps) {
  return (
    <div className="flex flex-col h-0 flex-1 border-r border-gray-200 bg-white">
      {/* Logo */}
      <div className="flex-1 flex flex-col pt-5 pb-4 overflow-y-auto">
        <div className="flex items-center flex-shrink-0 px-4">
          <div className="flex items-center space-x-3">
            <div className="w-8 h-8 bg-primary-600 rounded-lg flex items-center justify-center">
              <Zap className="w-5 h-5 text-white" />
            </div>
            <h1 className="text-xl font-bold text-gray-900">Storm Surge</h1>
          </div>
        </div>
        
        {/* Navigation */}
        <nav className="mt-8 flex-1 px-2 space-y-1">
          {navigation.map((item) => {
            const isActive = location.pathname === item.href
            return (
              <NavLink
                key={item.name}
                to={item.href}
                className={`group flex items-center px-2 py-2 text-sm font-medium rounded-md transition-colors ${
                  isActive
                    ? 'bg-primary-100 text-primary-700'
                    : 'text-gray-600 hover:bg-gray-50 hover:text-gray-900'
                }`}
              >
                <item.icon
                  className={`mr-3 flex-shrink-0 h-5 w-5 ${
                    isActive ? 'text-primary-500' : 'text-gray-400 group-hover:text-gray-500'
                  }`}
                />
                {item.name}
              </NavLink>
            )
          })}
        </nav>
      </div>
      
      {/* System status */}
      {systemHealth && (
        <div className="flex-shrink-0 border-t border-gray-200 p-4">
          <div className="text-xs text-gray-500 space-y-1">
            <div>Version {systemHealth.version}</div>
            <div>Uptime: {Math.floor(systemHealth.uptime / 3600)}h</div>
          </div>
        </div>
      )}
      
      {/* User section */}
      <div className="flex-shrink-0 border-t border-gray-200 p-4">
        <div className="flex items-center justify-between">
          <div className="flex items-center space-x-3">
            <div className="w-8 h-8 bg-primary-100 rounded-full flex items-center justify-center">
              <User className="w-4 h-4 text-primary-600" />
            </div>
            <div className="flex-1 min-w-0">
              <div className="text-sm font-medium text-gray-900 truncate">{user.name}</div>
              <div className="text-xs text-gray-500">{user.role}</div>
            </div>
          </div>
          <button
            onClick={onLogout}
            className="flex-shrink-0 p-1 text-gray-400 hover:text-gray-500 focus:outline-none focus:ring-2 focus:ring-primary-500"
            title="Logout"
          >
            <LogOut className="h-4 w-4" />
          </button>
        </div>
      </div>
    </div>
  )
}