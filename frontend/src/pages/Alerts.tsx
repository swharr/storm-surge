
import { Bell } from 'lucide-react'

export default function Alerts() {
  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
      <div className="text-center py-12">
        <Bell className="mx-auto h-12 w-12 text-gray-400" />
        <h3 className="mt-2 text-lg font-medium text-gray-900">Alert Management</h3>
        <p className="mt-1 text-sm text-gray-500">
          Configure and manage alerts and notifications.
        </p>
      </div>
    </div>
  )
}