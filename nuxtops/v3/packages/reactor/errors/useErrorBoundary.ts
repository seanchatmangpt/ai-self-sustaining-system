/**
 * Error Boundary Composable
 * Vue composable for error boundary management in Nuxt applications
 */

import { ref, reactive, computed } from 'vue';
import { useNuxtApp } from '#app';
import { ReactorErrorBoundary, type ErrorBoundaryOptions, type ErrorContext, type CircuitBreakerState } from './error-boundary';
import type { ReactorStep } from '../types';

export interface ErrorBoundaryStats {
  totalErrors: number;
  totalRetries: number;
  circuitBreakersOpen: number;
  averageRetryCount: number;
  mostFrequentErrors: Array<{
    message: string;
    count: number;
    lastOccurrence: number;
  }>;
  recentErrors: Array<{
    stepName: string;
    message: string;
    timestamp: number;
    attemptCount: number;
  }>;
}

export function useErrorBoundary(options: ErrorBoundaryOptions = {}) {
  const nuxtApp = useNuxtApp();
  
  // Create error boundary instance
  const boundary = new ReactorErrorBoundary({
    ...options,
    onError: (error: Error, context: ErrorContext) => {
      // Record error in reactive state
      recordError(error, context);
      
      // Call user-provided error handler
      options.onError?.(error, context);
    }
  });
  
  // Reactive state
  const errors = ref<Array<{ error: Error; context: ErrorContext }>>([]);
  const circuitBreakers = reactive<Record<string, CircuitBreakerState>>({});
  const isEnabled = ref(true);
  
  // Computed stats
  const stats = computed<ErrorBoundaryStats>(() => {
    const errorStats = boundary.getErrorStats();
    const circuitStats = boundary.getCircuitBreakerStats();
    
    const totalErrors = errors.value.length;
    const totalRetries = errors.value.reduce((sum, { context }) => sum + context.attemptCount - 1, 0);
    const circuitBreakersOpen = Object.values(circuitStats).filter(cb => cb.state === 'open').length;
    const averageRetryCount = totalErrors > 0 ? totalRetries / totalErrors : 0;
    
    // Most frequent errors
    const errorCounts = new Map<string, number>();
    const errorTimestamps = new Map<string, number>();
    
    errors.value.forEach(({ error, context }) => {
      const message = error.message;
      errorCounts.set(message, (errorCounts.get(message) || 0) + 1);
      errorTimestamps.set(message, Math.max(errorTimestamps.get(message) || 0, context.timestamp));
    });
    
    const mostFrequentErrors = Array.from(errorCounts.entries())
      .map(([message, count]) => ({
        message,
        count,
        lastOccurrence: errorTimestamps.get(message) || 0
      }))
      .sort((a, b) => b.count - a.count)
      .slice(0, 10);
    
    // Recent errors (last 20)
    const recentErrors = errors.value
      .slice(-20)
      .map(({ error, context }) => ({
        stepName: context.stepName,
        message: error.message,
        timestamp: context.timestamp,
        attemptCount: context.attemptCount
      }));
    
    return {
      totalErrors,
      totalRetries,
      circuitBreakersOpen,
      averageRetryCount,
      mostFrequentErrors,
      recentErrors
    };
  });
  
  const hasRecentErrors = computed(() => {
    const fiveMinutesAgo = Date.now() - 5 * 60 * 1000;
    return errors.value.some(({ context }) => context.timestamp > fiveMinutesAgo);
  });
  
  const healthScore = computed(() => {
    const recent = errors.value.filter(({ context }) => 
      context.timestamp > Date.now() - 10 * 60 * 1000 // Last 10 minutes
    );
    
    if (recent.length === 0) return 100;
    
    const failureRate = recent.length / Math.max(1, recent.length + 10); // Assume some successes
    const retryRate = recent.reduce((sum, { context }) => sum + context.attemptCount, 0) / recent.length;
    const circuitBreakerPenalty = stats.value.circuitBreakersOpen * 10;
    
    return Math.max(0, 100 - (failureRate * 50) - (retryRate * 10) - circuitBreakerPenalty);
  });
  
  /**
   * Wrap a reactor step with error boundary protection
   */
  const wrapStep = (step: ReactorStep): ReactorStep => {
    if (!isEnabled.value) return step;
    return boundary.wrapStep(step);
  };
  
  /**
   * Record error in reactive state
   */
  const recordError = (error: Error, context: ErrorContext): void => {
    errors.value.push({ error, context });
    
    // Update circuit breaker state
    Object.assign(circuitBreakers, boundary.getCircuitBreakerStats());
    
    // Trim old errors (keep last 100)
    if (errors.value.length > 100) {
      errors.value = errors.value.slice(-100);
    }
  };
  
  /**
   * Enable error boundary protection
   */
  const enable = (): void => {
    isEnabled.value = true;
  };
  
  /**
   * Disable error boundary protection
   */
  const disable = (): void => {
    isEnabled.value = false;
  };
  
  /**
   * Clear all error history
   */
  const clearErrors = (): void => {
    errors.value = [];
    boundary.resetErrorHistory();
    Object.keys(circuitBreakers).forEach(key => delete circuitBreakers[key]);
  };
  
  /**
   * Reset all circuit breakers
   */
  const resetCircuitBreakers = (): void => {
    boundary.resetCircuitBreakers();
    Object.keys(circuitBreakers).forEach(key => delete circuitBreakers[key]);
  };
  
  /**
   * Get error insights and recommendations
   */
  const getInsights = (): {
    issues: string[];
    recommendations: string[];
    patterns: string[];
  } => {
    const insights = {
      issues: [] as string[],
      recommendations: [] as string[],
      patterns: [] as string[]
    };
    
    const recentStats = stats.value;
    
    // Identify issues
    if (recentStats.circuitBreakersOpen > 0) {
      insights.issues.push(`${recentStats.circuitBreakersOpen} circuit breaker(s) are open`);
      insights.recommendations.push('Investigate failing steps and fix underlying issues');
    }
    
    if (recentStats.averageRetryCount > 2) {
      insights.issues.push(`High average retry count: ${recentStats.averageRetryCount.toFixed(1)}`);
      insights.recommendations.push('Review error handling and consider improving fallback strategies');
    }
    
    if (healthScore.value < 70) {
      insights.issues.push(`Low health score: ${healthScore.value.toFixed(0)}/100`);
      insights.recommendations.push('Address recent errors and improve system reliability');
    }
    
    // Identify patterns
    const frequentErrors = recentStats.mostFrequentErrors.slice(0, 3);
    frequentErrors.forEach(error => {
      if (error.count > 3) {
        insights.patterns.push(`Recurring error: "${error.message}" (${error.count} times)`);
        
        if (error.message.includes('timeout')) {
          insights.recommendations.push('Consider increasing timeouts or optimizing slow operations');
        } else if (error.message.includes('network')) {
          insights.recommendations.push('Implement better network error handling and retries');
        } else if (error.message.includes('rate limit')) {
          insights.recommendations.push('Implement exponential backoff for rate-limited operations');
        }
      }
    });
    
    return insights;
  };
  
  /**
   * Configure error boundary options
   */
  const configure = (newOptions: Partial<ErrorBoundaryOptions>): void => {
    // Create new boundary with updated options
    Object.assign(boundary['options'], newOptions);
  };
  
  /**
   * Get detailed circuit breaker information
   */
  const getCircuitBreakerInfo = (stepKey?: string): CircuitBreakerState[] | CircuitBreakerState | null => {
    const allCircuits = boundary.getCircuitBreakerStats();
    
    if (stepKey) {
      return allCircuits[stepKey] || null;
    }
    
    return Object.entries(allCircuits).map(([key, state]) => ({
      ...state,
      stepKey: key
    }));
  };
  
  /**
   * Manually trigger circuit breaker for testing
   */
  const triggerCircuitBreaker = (stepKey: string): void => {
    // Force circuit breaker to open by simulating failures
    const circuit = boundary['circuitBreakers'].get(stepKey) || {
      failures: 0,
      lastFailure: 0,
      state: 'closed' as const,
      nextAttempt: 0
    };
    
    circuit.failures = boundary['options'].failureThreshold;
    circuit.state = 'open';
    circuit.lastFailure = Date.now();
    circuit.nextAttempt = Date.now() + boundary['options'].circuitTimeout;
    
    boundary['circuitBreakers'].set(stepKey, circuit);
    Object.assign(circuitBreakers, boundary.getCircuitBreakerStats());
  };
  
  /**
   * Export error data for analysis
   */
  const exportErrorData = (): {
    timestamp: number;
    stats: ErrorBoundaryStats;
    errors: Array<{ error: Error; context: ErrorContext }>;
    circuitBreakers: Record<string, CircuitBreakerState>;
    config: ErrorBoundaryOptions;
  } => {
    return {
      timestamp: Date.now(),
      stats: stats.value,
      errors: errors.value,
      circuitBreakers: { ...circuitBreakers },
      config: boundary['options']
    };
  };
  
  // Provide error boundary globally
  nuxtApp.provide('errorBoundary', {
    wrapStep,
    getStats: () => stats.value,
    getHealthScore: () => healthScore.value,
    clearErrors,
    resetCircuitBreakers
  });
  
  return {
    // State
    isEnabled: readonly(isEnabled),
    errors: readonly(errors),
    stats: readonly(stats),
    hasRecentErrors: readonly(hasRecentErrors),
    healthScore: readonly(healthScore),
    circuitBreakers: readonly(circuitBreakers),
    
    // Methods
    wrapStep,
    enable,
    disable,
    clearErrors,
    resetCircuitBreakers,
    getInsights,
    configure,
    getCircuitBreakerInfo,
    triggerCircuitBreaker,
    exportErrorData
  };
}