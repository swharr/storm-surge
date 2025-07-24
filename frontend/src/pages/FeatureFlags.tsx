import React, { useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { Flag, Plus, MoreHorizontal, Eye, Edit, Trash2 } from 'lucide-react'
import api from '../services/api'
import LoadingSpinner from '../components/LoadingSpinner'
import type { FeatureFlag } from '../types'

export default function FeatureFlags() {
  const [searchTerm, setSearchTerm] = useState('')
  const [selectedProvider, setSelectedProvider] = useState<'all' | 'launchdarkly' | 'statsig'>('all')

  const { data: flags, isLoading } = useQuery({
    queryKey: ['flags'],
    queryFn: api.getFeatureFlags,
  })

  const filteredFlags = flags?.filter(flag => {
    const matchesSearch = flag.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
                         flag.key.toLowerCase().includes(searchTerm.toLowerCase())
    const matchesProvider = selectedProvider === 'all' || flag.provider === selectedProvider
    return matchesSearch && matchesProvider
  }) || []

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
            <h1 className="text-3xl font-bold text-gray-900">Feature Flags</h1>
            <p className="mt-2 text-gray-600">Manage and monitor your feature flags</p>
          </div>
          <button className="btn-primary btn-md">
            <Plus className="w-4 h-4 mr-2" />
            New Flag
          </button>
        </div>
      </div>

      {/* Filters */}
      <div className="mb-6 flex flex-col sm:flex-row gap-4">
        <div className="flex-1">
          <input
            type="text"
            placeholder="Search flags..."
            className="input"
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
          />
        </div>
        <div>
          <select
            className="input"
            value={selectedProvider}
            onChange={(e) => setSelectedProvider(e.target.value as any)}
          >
            <option value="all">All Providers</option>
            <option value="launchdarkly">LaunchDarkly</option>
            <option value="statsig">Statsig</option>
          </select>
        </div>
      </div>

      {/* Flags List */}
      <div className="card">
        <div className="overflow-hidden">
          <table className="min-w-full divide-y divide-gray-200">
            <thead className="bg-gray-50">
              <tr>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Flag
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Status
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Provider
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Environments
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Last Modified
                </th>
                <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Actions
                </th>
              </tr>
            </thead>
            <tbody className="bg-white divide-y divide-gray-200">
              {filteredFlags.map((flag) => (
                <FlagRow key={flag.key} flag={flag} />
              ))}
            </tbody>
          </table>

          {filteredFlags.length === 0 && (
            <div className="text-center py-12">
              <Flag className="mx-auto h-12 w-12 text-gray-400" />
              <h3 className="mt-2 text-sm font-medium text-gray-900">No feature flags</h3>
              <p className="mt-1 text-sm text-gray-500">
                Get started by creating a new feature flag.
              </p>
              <div className="mt-6">
                <button className="btn-primary btn-md">
                  <Plus className="w-4 h-4 mr-2" />
                  New Flag
                </button>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  )
}

function FlagRow({ flag }: { flag: FeatureFlag }) {
  return (
    <tr className="hover:bg-gray-50">
      <td className="px-6 py-4 whitespace-nowrap">
        <div>
          <div className="text-sm font-medium text-gray-900">{flag.name}</div>
          <div className="text-sm text-gray-500 font-mono">{flag.key}</div>
        </div>
      </td>
      <td className="px-6 py-4 whitespace-nowrap">
        <span className={`badge ${flag.enabled ? 'badge-success' : 'badge-gray'}`}>
          {flag.enabled ? 'Enabled' : 'Disabled'}
        </span>
      </td>
      <td className="px-6 py-4 whitespace-nowrap">
        <span className="badge badge-info capitalize">{flag.provider}</span>
      </td>
      <td className="px-6 py-4 whitespace-nowrap">
        <div className="flex flex-wrap gap-1">
          {flag.environments.map((env) => (
            <span key={env} className="badge badge-gray text-xs">
              {env}
            </span>
          ))}
        </div>
      </td>
      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
        <div>{new Date(flag.lastModified).toLocaleDateString()}</div>
        <div className="text-xs text-gray-400">by {flag.modifiedBy}</div>
      </td>
      <td className="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
        <div className="flex items-center justify-end space-x-2">
          <button className="text-gray-400 hover:text-gray-600">
            <Eye className="w-4 h-4" />
          </button>
          <button className="text-gray-400 hover:text-gray-600">
            <Edit className="w-4 h-4" />
          </button>
          <button className="text-gray-400 hover:text-red-600">
            <Trash2 className="w-4 h-4" />
          </button>
          <button className="text-gray-400 hover:text-gray-600">
            <MoreHorizontal className="w-4 h-4" />
          </button>
        </div>
      </td>
    </tr>
  )
}