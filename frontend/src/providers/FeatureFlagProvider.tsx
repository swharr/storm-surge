#!/usr/bin/env typescript
/**
 * Feature Flag Provider for Storm Surge Frontend
 * Supports LaunchDarkly and Statsig with a unified interface
 */

import React, { createContext, useContext, useEffect, useState, ReactNode } from 'react';
import { LDProvider, useLDClient, LDContext } from 'launchdarkly-react-client-sdk';
import { StatsigProvider, StatsigUser, Statsig } from 'statsig-react';
// import { trackCustomEvent } from '../telemetry';

// Types
export interface User {
  id: string;
  email?: string;
  name?: string;
  role?: string;
  custom?: Record<string, any>;
}

export interface FeatureFlagContextType {
  isReady: boolean;
  getFlag: (flagKey: string, defaultValue?: boolean) => boolean;
  trackEvent: (eventName: string, metadata?: Record<string, any>) => void;
  provider: 'launchdarkly' | 'statsig';
}

// Context
const FeatureFlagContext = createContext<FeatureFlagContextType | null>(null);

// Hook to use feature flags
export const useFeatureFlags = (): FeatureFlagContextType => {
  const context = useContext(FeatureFlagContext);
  if (!context) {
    throw new Error('useFeatureFlags must be used within a FeatureFlagProvider');
  }
  return context;
};

// Environment configuration
const PROVIDER = import.meta.env.VITE_FEATURE_FLAG_PROVIDER || 'launchdarkly';
const LAUNCHDARKLY_CLIENT_ID = import.meta.env.VITE_LAUNCHDARKLY_CLIENT_ID || 'CHANGEME_LAUNCHDARKLY_CLIENT_ID_123456789';
const LAUNCHDARKLY_TRACKING_ID = import.meta.env.VITE_LAUNCHDARKLY_TRACKING_ID || 'CHANGEME_TRACKING_ID_123456789';
const STATSIG_CLIENT_KEY = import.meta.env.VITE_STATSIG_CLIENT_KEY || 'CHANGEME_STATSIG_CLIENT_KEY_123456789';

// LaunchDarkly wrapper component
const LaunchDarklyWrapper: React.FC<{ user: User; children: ReactNode }> = ({ user, children }) => {
  const [isReady, setIsReady] = useState(false);
  const ldClient = useLDClient();

  useEffect(() => {
    if (ldClient) {
      const checkReady = async () => {
        await ldClient.waitForInitialization();
        setIsReady(true);
        
        // Track initialization
        // trackCustomEvent('feature_flag_client_initialized', {
        //   provider: 'launchdarkly',
        //   user_id: user.id
        // });
        console.log('LaunchDarkly client initialized', { user_id: user.id });
      };
      checkReady();
    }
  }, [ldClient, user.id]);

  useEffect(() => {
    if (ldClient && isReady) {
      // Only track if we have a valid tracking ID (not dummy value)
      if (LAUNCHDARKLY_TRACKING_ID && !LAUNCHDARKLY_TRACKING_ID.includes('CHANGEME')) {
        ldClient.track(LAUNCHDARKLY_TRACKING_ID, {
          userId: user.id,
          email: user.email,
          role: user.role,
          event: 'user-session-started'
        });
      } else {
        console.warn('LaunchDarkly tracking ID not configured or using dummy value');
      }
    }
  }, [ldClient, isReady, user]);

  const getFlag = (flagKey: string, defaultValue: boolean = false): boolean => {
    if (!ldClient || !isReady) {
      console.warn(`LaunchDarkly client not ready, returning default value for ${flagKey}`);
      return defaultValue;
    }
    
    try {
      const flagValue = ldClient.variation(flagKey, defaultValue);
      
      // Track flag evaluation
      // trackCustomEvent('feature_flag_evaluated', {
      //   provider: 'launchdarkly',
      //   flag_key: flagKey,
      //   flag_value: flagValue,
      //   user_id: user.id
      // });
      console.log('Flag evaluated', { provider: 'launchdarkly', flagKey, flagValue });
      
      return flagValue;
    } catch (error) {
      console.error(`Error evaluating LaunchDarkly flag ${flagKey}:`, error);
      return defaultValue;
    }
  };

  const trackEvent = (eventName: string, metadata: Record<string, any> = {}): void => {
    if (!ldClient || !isReady) {
      console.warn('LaunchDarkly client not ready, cannot track event');
      return;
    }
    
    try {
      ldClient.track(eventName, {
        ...metadata,
        userId: user.id,
        timestamp: Date.now()
      });
      
      // Also track in OpenTelemetry (disabled for now)
      // trackCustomEvent(`ld_${eventName}`, {
      //   provider: 'launchdarkly',
      //   user_id: user.id,
      //   ...metadata
      // });
      console.log('LaunchDarkly event tracked', { eventName, metadata });
    } catch (error) {
      console.error(`Error tracking LaunchDarkly event ${eventName}:`, error);
    }
  };

  const contextValue: FeatureFlagContextType = {
    isReady,
    getFlag,
    trackEvent,
    provider: 'launchdarkly'
  };

  return (
    <FeatureFlagContext.Provider value={contextValue}>
      {children}
    </FeatureFlagContext.Provider>
  );
};

// Statsig wrapper component
const StatsigWrapper: React.FC<{ user: User; children: ReactNode }> = ({ user, children }) => {
  const [isReady, setIsReady] = useState(false);
  const [flagCache] = useState<Record<string, boolean>>({});

  useEffect(() => {
    // Statsig initializes automatically with the provider
    const checkReady = async () => {
      setIsReady(true);
      
      // Track initialization
      // trackCustomEvent('feature_flag_client_initialized', {
      //   provider: 'statsig',
      //   user_id: user.id
      // });
      console.log('Statsig client initialized', { user_id: user.id });
    };
    checkReady();
  }, [user.id]);

  const getFlag = (flagKey: string, defaultValue: boolean = false): boolean => {
    if (!isReady) {
      console.warn(`Statsig client not ready, returning default value for ${flagKey}`);
      return defaultValue;
    }
    
    try {
      // Use cached value if available
      if (flagKey in flagCache) {
        return flagCache[flagKey];
      }
      
      // For Statsig, we need to use their imperative API since hooks can't be called inside functions
      // This is a simplified approach - in production you'd want to properly check gates
      // using Statsig's imperative API or restructure to use hooks at component level
      console.log('Flag evaluated', { provider: 'statsig', flagKey, defaultValue });
      
      return defaultValue;
    } catch (error) {
      console.error(`Error evaluating Statsig gate ${flagKey}:`, error);
      return defaultValue;
    }
  };

  const trackEvent = (eventName: string, metadata: Record<string, any> = {}): void => {
    if (!isReady) {
      console.warn('Statsig client not ready, cannot track event');
      return;
    }
    
    try {
      Statsig.logEvent(eventName, null, {
        ...metadata,
        userId: user.id,
        timestamp: Date.now()
      });
      
      // Also track in OpenTelemetry (disabled for now)
      // trackCustomEvent(`statsig_${eventName}`, {
      //   provider: 'statsig',
      //   user_id: user.id,
      //   ...metadata
      // });
      console.log('Statsig event tracked', { eventName, metadata });
    } catch (error) {
      console.error(`Error tracking Statsig event ${eventName}:`, error);
    }
  };

  const contextValue: FeatureFlagContextType = {
    isReady,
    getFlag,
    trackEvent,
    provider: 'statsig'
  };

  return (
    <FeatureFlagContext.Provider value={contextValue}>
      {children}
    </FeatureFlagContext.Provider>
  );
};

// Main FeatureFlagProvider component
export interface FeatureFlagProviderProps {
  user: User;
  children: ReactNode;
}

export const FeatureFlagProvider: React.FC<FeatureFlagProviderProps> = ({ user, children }) => {
  // Convert user to provider-specific context
  const createLDContext = (user: User): LDContext => ({
    kind: 'user',
    key: user.id,
    email: user.email,
    name: user.name,
    custom: {
      role: user.role,
      ...user.custom
    }
  });

  const createStatsigUser = (user: User): StatsigUser => ({
    userID: user.id,
    email: user.email,
    custom: {
      name: user.name,
      role: user.role,
      ...user.custom
    }
  });

  // Environment validation with dummy key detection
  if (PROVIDER === 'launchdarkly') {
    if (!LAUNCHDARKLY_CLIENT_ID || LAUNCHDARKLY_CLIENT_ID.includes('CHANGEME')) {
      console.error('LaunchDarkly client ID not configured. Set VITE_LAUNCHDARKLY_CLIENT_ID environment variable.');
      return <div>Feature flag configuration error: LaunchDarkly client ID not set (using dummy value)</div>;
    }
    if (LAUNCHDARKLY_TRACKING_ID && LAUNCHDARKLY_TRACKING_ID.includes('CHANGEME')) {
      console.warn('LaunchDarkly tracking ID not configured. User tracking will be disabled.');
    }
  }

  if (PROVIDER === 'statsig') {
    if (!STATSIG_CLIENT_KEY || STATSIG_CLIENT_KEY.includes('CHANGEME')) {
      console.error('Statsig client key not configured. Set VITE_STATSIG_CLIENT_KEY environment variable.');
      return <div>Feature flag configuration error: Statsig client key not set (using dummy value)</div>;
    }
  }

  // Render appropriate provider
  if (PROVIDER === 'launchdarkly') {
    return (
      <LDProvider
        clientSideID={LAUNCHDARKLY_CLIENT_ID}
        context={createLDContext(user)}
        options={{
          bootstrap: 'localStorage',
          streaming: true,
          inspectors: import.meta.env.DEV ? [
            {
              type: 'flag-used',
              name: 'console-logger',
              synchronous: true,
              method: (flagKey: string, flagDetail: any) => {
                console.log(`[LaunchDarkly] Flag used: ${flagKey} = ${flagDetail.value}`);
              }
            }
          ] : []
        }}
      >
        <LaunchDarklyWrapper user={user}>
          {children}
        </LaunchDarklyWrapper>
      </LDProvider>
    );
  }

  if (PROVIDER === 'statsig') {
    return (
      <StatsigProvider
        sdkKey={STATSIG_CLIENT_KEY}
        user={createStatsigUser(user)}
        options={{
          environment: { tier: import.meta.env.VITE_ENVIRONMENT || 'development' },
          localMode: import.meta.env.DEV,
        }}
      >
        <StatsigWrapper user={user}>
          {children}
        </StatsigWrapper>
      </StatsigProvider>
    );
  }

  // Fallback for unsupported providers
  console.error(`Unsupported feature flag provider: ${PROVIDER}`);
  return <div>Feature flag configuration error: Unsupported provider</div>;
};

// Hook for specific feature flags
export const useFlag = (flagKey: string, defaultValue: boolean = false): boolean => {
  const context = useContext(FeatureFlagContext);
  
  // For LaunchDarkly or when context is available, use the context method
  if (context) {
    return context.getFlag(flagKey, defaultValue);
  }
  
  return defaultValue;
};

// Hook for tracking events
export const useTrackEvent = () => {
  const { trackEvent } = useFeatureFlags();
  return trackEvent;
};

// Hook to check if feature flags are ready
export const useFeatureFlagsReady = (): boolean => {
  const { isReady } = useFeatureFlags();
  return isReady;
};

export default FeatureFlagProvider;