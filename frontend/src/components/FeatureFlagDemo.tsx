#!/usr/bin/env typescript
/**
 * Feature Flag Demo Component
 * Demonstrates how to use feature flags in Storm Surge frontend components
 */

import React from 'react';
import { useFlag, useFeatureFlags, useTrackEvent } from '../providers/FeatureFlagProvider';

export const FeatureFlagDemo: React.FC = () => {
  const { provider, isReady } = useFeatureFlags();
  const trackEvent = useTrackEvent();
  
  // Example feature flags
  const enableCostOptimizer = useFlag('enable-cost-optimizer', false);
  const enableAdvancedAnalytics = useFlag('enable-advanced-analytics', false);
  const enableBetaFeatures = useFlag('enable-beta-features', false);
  const enableDarkMode = useFlag('enable-dark-mode', false);
  
  const handleOptimizationToggle = () => {
    trackEvent('CHANGEME_EVENT_NAME_123456789', {
      enabled: !enableCostOptimizer,
      source: 'frontend-demo',
      timestamp: Date.now(),
      actualEvent: 'cost-optimization-toggled'
    });
  };

  if (!isReady) {
    return (
      <div className="p-4 bg-yellow-50 border border-yellow-200 rounded-lg">
        <p className="text-yellow-800">🔄 Loading feature flags from {provider}...</p>
      </div>
    );
  }

  return (
    <div className="p-6 bg-white rounded-lg shadow-md">
      <h3 className="text-lg font-semibold mb-4">
        🏳️ Feature Flags Demo ({provider})
      </h3>
      
      <div className="space-y-4">
        {/* Cost Optimizer Flag */}
        <div className="flex items-center justify-between p-3 bg-gray-50 rounded">
          <div>
            <span className="font-medium">Cost Optimizer</span>
            <p className="text-sm text-gray-600">
              Enable automatic cluster cost optimization
            </p>
          </div>
          <div className="flex items-center space-x-2">
            <span className={`px-2 py-1 rounded text-xs font-medium ${
              enableCostOptimizer 
                ? 'bg-green-100 text-green-800' 
                : 'bg-red-100 text-red-800'
            }`}>
              {enableCostOptimizer ? 'ON' : 'OFF'}
            </span>
            <button
              onClick={handleOptimizationToggle}
              className="px-3 py-1 bg-blue-500 text-white rounded text-xs hover:bg-blue-600"
            >
              Track Toggle
            </button>
          </div>
        </div>

        {/* Advanced Analytics Flag */}
        <div className="flex items-center justify-between p-3 bg-gray-50 rounded">
          <div>
            <span className="font-medium">Advanced Analytics</span>
            <p className="text-sm text-gray-600">
              Show detailed analytics and insights
            </p>
          </div>
          <span className={`px-2 py-1 rounded text-xs font-medium ${
            enableAdvancedAnalytics 
              ? 'bg-green-100 text-green-800' 
              : 'bg-red-100 text-red-800'
          }`}>
            {enableAdvancedAnalytics ? 'ON' : 'OFF'}
          </span>
        </div>

        {/* Beta Features Flag */}
        <div className="flex items-center justify-between p-3 bg-gray-50 rounded">
          <div>
            <span className="font-medium">Beta Features</span>
            <p className="text-sm text-gray-600">
              Access to experimental features
            </p>
          </div>
          <span className={`px-2 py-1 rounded text-xs font-medium ${
            enableBetaFeatures 
              ? 'bg-green-100 text-green-800' 
              : 'bg-red-100 text-red-800'
          }`}>
            {enableBetaFeatures ? 'ON' : 'OFF'}
          </span>
        </div>

        {/* Dark Mode Flag */}
        <div className="flex items-center justify-between p-3 bg-gray-50 rounded">
          <div>
            <span className="font-medium">Dark Mode</span>
            <p className="text-sm text-gray-600">
              Enable dark theme interface
            </p>
          </div>
          <span className={`px-2 py-1 rounded text-xs font-medium ${
            enableDarkMode 
              ? 'bg-green-100 text-green-800' 
              : 'bg-red-100 text-red-800'
          }`}>
            {enableDarkMode ? 'ON' : 'OFF'}
          </span>
        </div>
      </div>

      {/* Conditional Feature Rendering */}
      {enableBetaFeatures && (
        <div className="mt-4 p-3 bg-purple-50 border border-purple-200 rounded">
          <h4 className="text-purple-800 font-medium">🧪 Beta Features Enabled</h4>
          <p className="text-purple-600 text-sm mt-1">
            You have access to experimental features! This section only appears when the beta features flag is enabled.
          </p>
          <button 
            onClick={() => trackEvent('CHANGEME_BETA_EVENT_123456789', { 
              feature: 'demo-section',
              actualEvent: 'beta-feature-accessed'
            })}
            className="mt-2 px-3 py-1 bg-purple-500 text-white rounded text-xs hover:bg-purple-600"
          >
            Track Beta Access
          </button>
        </div>
      )}

      {/* Advanced Analytics Section */}
      {enableAdvancedAnalytics && (
        <div className="mt-4 p-3 bg-blue-50 border border-blue-200 rounded">
          <h4 className="text-blue-800 font-medium">📊 Advanced Analytics</h4>
          <div className="grid grid-cols-3 gap-4 mt-2">
            <div className="text-center">
              <div className="text-2xl font-bold text-blue-600">87%</div>
              <div className="text-xs text-blue-600">Efficiency</div>
            </div>
            <div className="text-center">
              <div className="text-2xl font-bold text-green-600">$1.2k</div>
              <div className="text-xs text-green-600">Saved</div>
            </div>
            <div className="text-center">
              <div className="text-2xl font-bold text-purple-600">24/7</div>
              <div className="text-xs text-purple-600">Uptime</div>
            </div>
          </div>
        </div>
      )}

      {/* Provider Info */}
      <div className="mt-4 p-2 bg-gray-100 rounded text-sm">
        <span className="font-medium">Provider:</span> {provider} | 
        <span className="font-medium"> Status:</span> {isReady ? '✅ Ready' : '⏳ Loading'}
      </div>
    </div>
  );
};

export default FeatureFlagDemo;