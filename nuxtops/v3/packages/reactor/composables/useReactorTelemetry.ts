/**
 * useReactorTelemetry - Composable for telemetry and observability
 */

import { ref, computed, type Ref } from 'vue';
import { TelemetryMiddleware } from '../middleware/telemetry-middleware';

export interface UseReactorTelemetryOptions {
  enableSpanCollection?: boolean;
  enableRealTimeMetrics?: boolean;
  spanEndCallback?: (span: any) => void;
}

export default function useReactorTelemetry(options: UseReactorTelemetryOptions = {}) {
  // Reactive state
  const telemetrySpans: Ref<any[]> = ref([]);
  const activeSpans: Ref<any[]> = ref([]);
  const telemetryMetrics: Ref<{
    totalSpans: number;
    errorRate: number;
    averageDuration: number;
    operationCounts: Record<string, number>;
    performanceDistribution: Record<string, number>;
  }> = ref({
    totalSpans: 0,
    errorRate: 0,
    averageDuration: 0,
    operationCounts: {},
    performanceDistribution: {}
  });

  const isCollecting = ref(false);
  const telemetryError: Ref<Error | null> = ref(null);

  // Create telemetry middleware instance
  const telemetryMiddleware = new TelemetryMiddleware({
    onSpanEnd: (span) => {
      if (options.enableSpanCollection) {
        telemetrySpans.value.push(span);
        
        // Keep only last 1000 spans to prevent memory issues
        if (telemetrySpans.value.length > 1000) {
          telemetrySpans.value = telemetrySpans.value.slice(-1000);
        }
      }

      updateMetrics();

      // Call custom callback if provided
      if (options.spanEndCallback) {
        try {
          options.spanEndCallback(span);
        } catch (error) {
          console.error('Telemetry callback error:', error);
        }
      }
    }
  });

  // Computed properties
  const recentSpans = computed(() => 
    telemetrySpans.value.slice(-50).reverse()
  );

  const errorSpans = computed(() => 
    telemetrySpans.value.filter(span => span.status === 'error')
  );

  const slowSpans = computed(() => 
    telemetrySpans.value.filter(span => span.duration > 5000) // > 5 seconds
  );

  const operationBreakdown = computed(() => {
    const breakdown: Record<string, { count: number; totalDuration: number; avgDuration: number }> = {};
    
    for (const span of telemetrySpans.value) {
      if (!breakdown[span.operationName]) {
        breakdown[span.operationName] = { count: 0, totalDuration: 0, avgDuration: 0 };
      }
      
      breakdown[span.operationName].count++;
      breakdown[span.operationName].totalDuration += span.duration || 0;
      breakdown[span.operationName].avgDuration = 
        breakdown[span.operationName].totalDuration / breakdown[span.operationName].count;
    }
    
    return breakdown;
  });

  const performanceInsights = computed(() => {
    const insights: string[] = [];
    const metrics = telemetryMetrics.value;
    
    if (metrics.errorRate > 0.05) {
      insights.push(`High error rate detected: ${(metrics.errorRate * 100).toFixed(1)}%`);
    }
    
    if (metrics.averageDuration > 2000) {
      insights.push(`High average latency: ${metrics.averageDuration.toFixed(0)}ms`);
    }
    
    const slowOperations = Object.entries(operationBreakdown.value)
      .filter(([_, data]) => data.avgDuration > 3000)
      .map(([name]) => name);
    
    if (slowOperations.length > 0) {
      insights.push(`Slow operations detected: ${slowOperations.join(', ')}`);
    }
    
    return insights;
  });

  // Telemetry management
  const startTelemetryCollection = () => {
    isCollecting.value = true;
    telemetryError.value = null;
    console.log('📊 Telemetry collection started');
  };

  const stopTelemetryCollection = () => {
    isCollecting.value = false;
    console.log('📊 Telemetry collection stopped');
  };

  const clearTelemetryData = () => {
    telemetrySpans.value = [];
    activeSpans.value = [];
    resetMetrics();
    console.log('🧹 Telemetry data cleared');
  };

  const resetMetrics = () => {
    telemetryMetrics.value = {
      totalSpans: 0,
      errorRate: 0,
      averageDuration: 0,
      operationCounts: {},
      performanceDistribution: {}
    };
  };

  // Metrics calculation
  const updateMetrics = () => {
    if (!options.enableRealTimeMetrics) return;

    const spans = telemetrySpans.value;
    const errorSpans = spans.filter(s => s.status === 'error');
    const completedSpans = spans.filter(s => s.duration !== undefined);

    telemetryMetrics.value = {
      totalSpans: spans.length,
      errorRate: spans.length > 0 ? errorSpans.length / spans.length : 0,
      averageDuration: completedSpans.length > 0 
        ? completedSpans.reduce((sum, s) => sum + (s.duration || 0), 0) / completedSpans.length 
        : 0,
      operationCounts: spans.reduce((counts, span) => {
        counts[span.operationName] = (counts[span.operationName] || 0) + 1;
        return counts;
      }, {} as Record<string, number>),
      performanceDistribution: calculatePerformanceDistribution(completedSpans)
    };
  };

  const calculatePerformanceDistribution = (spans: any[]) => {
    const distribution = { fast: 0, normal: 0, slow: 0, very_slow: 0 };
    
    for (const span of spans) {
      const duration = span.duration || 0;
      if (duration < 100) distribution.fast++;
      else if (duration < 1000) distribution.normal++;
      else if (duration < 5000) distribution.slow++;
      else distribution.very_slow++;
    }
    
    return distribution;
  };

  // Span management
  const getSpanById = (spanId: string) => {
    return telemetrySpans.value.find(span => span.spanId === spanId);
  };

  const getSpansByOperation = (operationName: string) => {
    return telemetrySpans.value.filter(span => span.operationName === operationName);
  };

  const getSpansByTraceId = (traceId: string) => {
    return telemetrySpans.value.filter(span => span.traceId === traceId);
  };

  // Analysis and reporting
  const generateTelemetryReport = (timeWindow?: number) => {
    const cutoff = timeWindow ? Date.now() - timeWindow : 0;
    const relevantSpans = telemetrySpans.value.filter(span => span.startTime >= cutoff);

    const report = {
      timeWindow: timeWindow || 'all-time',
      generatedAt: Date.now(),
      summary: {
        totalSpans: relevantSpans.length,
        errorSpans: relevantSpans.filter(s => s.status === 'error').length,
        averageDuration: relevantSpans.length > 0 
          ? relevantSpans.reduce((sum, s) => sum + (s.duration || 0), 0) / relevantSpans.length 
          : 0,
        operationsCount: new Set(relevantSpans.map(s => s.operationName)).size
      },
      operations: Object.entries(
        relevantSpans.reduce((ops, span) => {
          if (!ops[span.operationName]) {
            ops[span.operationName] = { count: 0, totalDuration: 0, errors: 0 };
          }
          ops[span.operationName].count++;
          ops[span.operationName].totalDuration += span.duration || 0;
          if (span.status === 'error') ops[span.operationName].errors++;
          return ops;
        }, {} as Record<string, any>)
      ).map(([name, data]) => ({
        name,
        count: data.count,
        averageDuration: data.count > 0 ? data.totalDuration / data.count : 0,
        errorRate: data.count > 0 ? data.errors / data.count : 0
      })),
      insights: performanceInsights.value
    };

    return report;
  };

  const exportSpansAsJSON = (filter?: (span: any) => boolean) => {
    const spansToExport = filter ? telemetrySpans.value.filter(filter) : telemetrySpans.value;
    return JSON.stringify(spansToExport, null, 2);
  };

  const exportSpansAsCSV = () => {
    if (telemetrySpans.value.length === 0) return '';

    const headers = ['traceId', 'spanId', 'operationName', 'startTime', 'duration', 'status'];
    const csvContent = [
      headers.join(','),
      ...telemetrySpans.value.map(span => 
        headers.map(header => span[header] || '').join(',')
      )
    ].join('\n');

    return csvContent;
  };

  // Real-time monitoring
  const createTraceTimeline = (traceId: string) => {
    const traceSpans = getSpansByTraceId(traceId);
    if (traceSpans.length === 0) return null;

    const sortedSpans = traceSpans.sort((a, b) => a.startTime - b.startTime);
    const startTime = sortedSpans[0].startTime;

    return {
      traceId,
      totalDuration: Math.max(...sortedSpans.map(s => (s.endTime || s.startTime) - startTime)),
      spans: sortedSpans.map(span => ({
        operationName: span.operationName,
        relativeStart: span.startTime - startTime,
        duration: span.duration || 0,
        status: span.status,
        attributes: span.attributes
      }))
    };
  };

  const findAnomalousSpans = (thresholds?: {
    durationThreshold?: number;
    errorPattern?: RegExp;
  }) => {
    const defaults = {
      durationThreshold: 5000, // 5 seconds
      errorPattern: /error|fail|exception/i
    };
    
    const config = { ...defaults, ...thresholds };
    
    return telemetrySpans.value.filter(span => {
      // Duration anomaly
      if (span.duration && span.duration > config.durationThreshold) return true;
      
      // Error pattern in operation name or attributes
      if (config.errorPattern.test(span.operationName)) return true;
      
      // Error status
      if (span.status === 'error') return true;
      
      return false;
    });
  };

  // Start collection if enabled
  if (options.enableSpanCollection || options.enableRealTimeMetrics) {
    startTelemetryCollection();
  }

  return {
    // State
    telemetrySpans: readonly(telemetrySpans),
    activeSpans: readonly(activeSpans),
    telemetryMetrics: readonly(telemetryMetrics),
    isCollecting: readonly(isCollecting),
    telemetryError: readonly(telemetryError),

    // Computed
    recentSpans,
    errorSpans,
    slowSpans,
    operationBreakdown,
    performanceInsights,

    // Collection control
    startTelemetryCollection,
    stopTelemetryCollection,
    clearTelemetryData,
    resetMetrics,

    // Data access
    getSpanById,
    getSpansByOperation,
    getSpansByTraceId,

    // Analysis
    generateTelemetryReport,
    createTraceTimeline,
    findAnomalousSpans,

    // Export
    exportSpansAsJSON,
    exportSpansAsCSV,

    // Middleware instance
    telemetryMiddleware
  };
}