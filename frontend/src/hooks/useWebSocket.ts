import { useEffect, useRef, useState } from 'react'
import { useQueryClient } from '@tanstack/react-query'
import io, { Socket } from 'socket.io-client'
import { toast } from 'react-hot-toast'
import type { WebSocketEvent } from '../types'

interface UseWebSocketOptions {
  url?: string
  autoConnect?: boolean
  onConnect?: () => void
  onDisconnect?: () => void
  onError?: (error: Error) => void
}

export function useWebSocket({
  url = '/socket.io',
  autoConnect = true,
  onConnect,
  onDisconnect,
  onError,
}: UseWebSocketOptions = {}) {
  const [isConnected, setIsConnected] = useState(false)
  const [connectionError, setConnectionError] = useState<string | null>(null)
  const socketRef = useRef<Socket | null>(null)
  const queryClient = useQueryClient()

  useEffect(() => {
    if (!autoConnect) return

    const token = localStorage.getItem('storm_surge_token')
    if (!token) return

    // Initialize socket connection
    const socket = io(url, {
      auth: {
        token,
      },
      transports: ['websocket', 'polling'],
    })

    socketRef.current = socket

    // Connection event handlers
    socket.on('connect', () => {
      setIsConnected(true)
      setConnectionError(null)
      onConnect?.()
      console.log('WebSocket connected')
    })

    socket.on('disconnect', (reason) => {
      setIsConnected(false)
      onDisconnect?.()
      console.log('WebSocket disconnected:', reason)

      if (reason === 'io server disconnect') {
        // Server disconnected, try to reconnect
        socket.connect()
      }
    })

    socket.on('connect_error', (error) => {
      setIsConnected(false)
      setConnectionError(error.message)
      onError?.(error)
      console.error('WebSocket connection error:', error)
    })

    // Real-time event handlers
    socket.on('flag_changed', (event: WebSocketEvent) => {
      // Invalidate flags cache to trigger refetch
      queryClient.invalidateQueries({ queryKey: ['flags'] })
      
      toast.success(`Feature flag "${event.data.flag_key}" was ${event.data.enabled ? 'enabled' : 'disabled'}`)
    })

    socket.on('cluster_scaled', (event: WebSocketEvent) => {
      // Invalidate clusters and scaling events cache
      queryClient.invalidateQueries({ queryKey: ['clusters'] })
      queryClient.invalidateQueries({ queryKey: ['scaling-events'] })
      
      const { cluster_id, event_type, success } = event.data
      
      if (success) {
        toast.success(`Cluster ${cluster_id} ${event_type.replace('_', ' ')} completed`)
      } else {
        toast.error(`Cluster ${cluster_id} ${event_type.replace('_', ' ')} failed`)
      }
    })

    socket.on('alert_triggered', (event: WebSocketEvent) => {
      const { alert_name, severity, message } = event.data
      
      switch (severity) {
        case 'critical':
          toast.error(`🚨 ${alert_name}: ${message}`, { duration: 8000 })
          break
        case 'warning':
          toast(`⚠️ ${alert_name}: ${message}`, { duration: 6000 })
          break
        default:
          toast(`ℹ️ ${alert_name}: ${message}`, { duration: 4000 })
      }
    })

    socket.on('system_health', (event: WebSocketEvent) => {
      // Invalidate system health cache
      queryClient.invalidateQueries({ queryKey: ['system-health'] })
      
      const { status, component } = event.data
      
      if (status === 'down' || status === 'degraded') {
        toast.error(`System component ${component} is ${status}`)
      }
    })

    socket.on('cost_alert', (event: WebSocketEvent) => {
      const { threshold_exceeded, current_cost, threshold } = event.data
      
      if (threshold_exceeded) {
        toast.error(`💰 Cost threshold exceeded: $${current_cost} > $${threshold}`, { 
          duration: 8000 
        })
      }
    })

    // Cleanup on unmount
    return () => {
      socket.disconnect()
      socketRef.current = null
    }
  }, [url, autoConnect, onConnect, onDisconnect, onError, queryClient])

  const disconnect = () => {
    socketRef.current?.disconnect()
    setIsConnected(false)
  }

  const reconnect = () => {
    socketRef.current?.connect()
  }

  const emit = (event: string, data?: any) => {
    socketRef.current?.emit(event, data)
  }

  return {
    isConnected,
    connectionError,
    disconnect,
    reconnect,
    emit,
    socket: socketRef.current,
  }
}