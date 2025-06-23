/**
 * Monitoring Composable
 * Vue composable for Nuxt Reactor monitoring and observability
 */

import { ref, computed, reactive, onUnmounted } from 'vue';
import { useNuxtApp } from '#app';
import { ReactorMonitor, type MetricSnapshot, type HealthStatus, type PerformanceThresholds } from './reactor-monitor';
import type { ReactorResult } from '../types';

export interface MonitoringOptions {
  /** Performance thresholds */
  thresholds?: Partial<PerformanceThresholds>;
  /** Auto-export interval in minutes */
  autoExportInterval?: number;
  /** Maximum metrics to keep in memory */
  maxMetrics?: number;
  /** Enable real-time updates */
  realtime?: boolean;
}

export function useMonitoring(options: MonitoringOptions = {}) {
  const nuxtApp = useNuxtApp();
  
  // Create monitor instance
  const monitor = new ReactorMonitor(options.thresholds);
  
  // Reactive state
  const isMonitoring = ref(false);
  const metrics = ref<MetricSnapshot[]>([]);
  const healthStatus = ref<HealthStatus>({
    status: 'healthy',
    score: 100,
    issues: [],
    recommendations: [],
    lastCheck: Date.now()
  });
  
  // Auto-update intervals
  let healthCheckInterval: NodeJS.Timeout | null = null;
  let metricsUpdateInterval: NodeJS.Timeout | null = null;
  let autoExportInterval: NodeJS.Timeout | null = null;
  
  // Computed values
  const performanceSummary = computed(() => {
    return monitor.getPerformanceSummary(60); // Last hour
  });
  
  const activeAlerts = computed(() => {
    return monitor.getActiveAlerts();
  });
  
  const hasIssues = computed(() => {
    return healthStatus.value.issues.length > 0 || activeAlerts.value.length > 0;
  });
  
  const executionTimeline = computed(() => {
    return monitor.getExecutionTimeline(60); // Last hour
  });
  
  /**
   * Start monitoring
   */
  const startMonitoring = (): void => {
    if (isMonitoring.value) return;
    
    isMonitoring.value = true;
    
    // Update health status every 30 seconds
    healthCheckInterval = setInterval(() => {
      healthStatus.value = monitor.getHealthStatus();
    }, 30000);
    
    // Update metrics display every 10 seconds if realtime enabled
    if (options.realtime) {
      metricsUpdateInterval = setInterval(() => {
        metrics.value = monitor['metrics'].slice(-100); // Last 100 metrics
      }, 10000);
    }
    
    // Auto-export if configured
    if (options.autoExportInterval) {
      autoExportInterval = setInterval(() => {
        exportMetrics('json');
      }, options.autoExportInterval * 60 * 1000);
    }
    
    console.log('🔍 Reactor monitoring started');
  };
  
  /**
   * Stop monitoring
   */
  const stopMonitoring = (): void => {
    if (!isMonitoring.value) return;
    
    isMonitoring.value = false;
    
    if (healthCheckInterval) {
      clearInterval(healthCheckInterval);
      healthCheckInterval = null;
    }
    
    if (metricsUpdateInterval) {
      clearInterval(metricsUpdateInterval);
      metricsUpdateInterval = null;
    }
    
    if (autoExportInterval) {
      clearInterval(autoExportInterval);
      autoExportInterval = null;
    }
    
    console.log('🔍 Reactor monitoring stopped');
  };
  
  /**
   * Record metrics from reactor execution
   */
  const recordExecution = (result: ReactorResult): void => {
    monitor.recordMetrics(result);
    
    // Update reactive state
    if (options.realtime) {
      metrics.value = monitor['metrics'].slice(-100);
    }
    healthStatus.value = monitor.getHealthStatus();
  };
  
  /**
   * Get performance insights
   */
  const getInsights = (): {
    topIssues: string[];
    recommendations: string[];
    trends: string[];
    achievements: string[];
  } => {
    const summary = performanceSummary.value;
    const health = healthStatus.value;
    
    const insights = {
      topIssues: [...health.issues],
      recommendations: [...health.recommendations],
      trends: [] as string[],
      achievements: [] as string[]
    };
    
    // Add trend insights
    if (summary.trends.duration === 'improving') {
      insights.achievements.push('Performance is improving over time');
    } else if (summary.trends.duration === 'degrading') {
      insights.topIssues.push('Performance is degrading over time');
      insights.recommendations.push('Review recent changes and optimize slow operations');
    }
    
    if (summary.trends.successRate === 'improving') {
      insights.achievements.push('Success rate is improving');
    } else if (summary.trends.successRate === 'degrading') {
      insights.topIssues.push('Success rate is declining');
      insights.recommendations.push('Investigate and fix error patterns');
    }
    
    if (summary.trends.memory === 'degrading') {
      insights.topIssues.push('Memory usage is increasing');
      insights.recommendations.push('Check for memory leaks and optimize resource usage');
    }
    
    // Add performance achievements
    if (summary.successRate > 0.99) {
      insights.achievements.push('Excellent success rate (>99%)');
    }
    
    if (summary.averageDuration < 1000) {
      insights.achievements.push('Fast execution times (<1s average)');
    }
    
    if (summary.throughput > 10) {
      insights.achievements.push('High throughput (>10 executions/min)');
    }
    
    return insights;
  };
  
  /**
   * Export metrics in various formats
   */
  const exportMetrics = (format: 'json' | 'prometheus' | 'csv' = 'json'): string => {
    const exported = monitor.exportMetrics(format);
    
    // Auto-save to localStorage in browser
    if (process.client && format === 'json') {
      localStorage.setItem('reactor_metrics_export', exported);
      localStorage.setItem('reactor_metrics_export_timestamp', Date.now().toString());
    }
    
    return exported;
  };
  
  /**
   * Clear all metrics
   */
  const clearMetrics = (): void => {
    monitor.clear();
    metrics.value = [];
    healthStatus.value = {
      status: 'healthy',
      score: 100,
      issues: [],
      recommendations: [],
      lastCheck: Date.now()
    };
  };
  
  /**
   * Add custom alert rule
   */
  const addCustomAlert = (rule: {
    id: string;
    name: string;
    condition: (metrics: MetricSnapshot[]) => boolean;
    severity: 'info' | 'warning' | 'error' | 'critical';
    cooldown: number;
  }): void => {
    monitor.addAlert(rule);
  };
  
  /**
   * Get dashboard data for visualization
   */
  const getDashboardData = () => {
    const summary = performanceSummary.value;
    const health = healthStatus.value;
    const timeline = executionTimeline.value;
    
    return {
      overview: {
        totalExecutions: summary.totalExecutions,
        averageDuration: summary.averageDuration,
        successRate: summary.successRate,
        throughput: summary.throughput,
        healthScore: health.score,
        status: health.status
      },
      timeline: timeline.slice(-20), // Last 20 executions
      trends: summary.trends,
      alerts: activeAlerts.value,
      issues: health.issues,
      recommendations: health.recommendations,
      insights: getInsights()
    };
  };
  
  /**
   * Create performance report
   */
  const generateReport = (timeframeMinutes: number = 60): {
    summary: string;
    metrics: any;
    recommendations: string[];
    exportedData: string;
  } => {
    const summary = monitor.getPerformanceSummary(timeframeMinutes);
    const health = monitor.getHealthStatus();
    const insights = getInsights();
    
    const reportSummary = `
Reactor Performance Report (${timeframeMinutes} minutes)
========================================

Overview:
- Total Executions: ${summary.totalExecutions}
- Average Duration: ${summary.averageDuration.toFixed(2)}ms
- Success Rate: ${(summary.successRate * 100).toFixed(1)}%
- Throughput: ${summary.throughput.toFixed(1)} executions/min
- Health Score: ${health.score}/100 (${health.status})

Trends:
- Duration: ${summary.trends.duration}
- Success Rate: ${summary.trends.successRate}
- Memory: ${summary.trends.memory}

Issues: ${health.issues.length}
${health.issues.map(issue => `- ${issue}`).join('\n')}

Achievements: ${insights.achievements.length}
${insights.achievements.map(achievement => `- ${achievement}`).join('\n')}
    `.trim();
    
    return {
      summary: reportSummary,
      metrics: summary,
      recommendations: [...health.recommendations, ...insights.recommendations],
      exportedData: exportMetrics('json')
    };
  };
  
  // Auto-start monitoring if in development mode
  if (process.env.NODE_ENV === 'development') {
    startMonitoring();
  }
  
  // Cleanup on unmount
  onUnmounted(() => {
    stopMonitoring();
  });
  
  // Provide global access via Nuxt app
  nuxtApp.provide('reactorMonitoring', {
    recordExecution,
    getHealthStatus: () => healthStatus.value,
    getPerformanceSummary: () => performanceSummary.value
  });
  
  return {
    // State
    isMonitoring: readonly(isMonitoring),
    metrics: readonly(metrics),
    healthStatus: readonly(healthStatus),
    performanceSummary: readonly(performanceSummary),
    activeAlerts: readonly(activeAlerts),
    hasIssues: readonly(hasIssues),
    executionTimeline: readonly(executionTimeline),
    
    // Methods
    startMonitoring,
    stopMonitoring,
    recordExecution,
    getInsights,
    exportMetrics,
    clearMetrics,
    addCustomAlert,
    getDashboardData,
    generateReport
  };
}