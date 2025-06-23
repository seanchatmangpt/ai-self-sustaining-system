/**
 * useReactorPerformance - Composable for performance monitoring and optimization
 */

import { ref, computed, type Ref } from 'vue';
import { 
  createPerformanceMonitor, 
  SimpleProfiler, 
  SimpleBenchmarkSuite,
  createBenchmark,
  type PerformanceMonitor,
  type PerformanceMetric,
  type ReactorPerformanceMetrics,
  type PerformanceAlert,
  type BenchmarkResult
} from '../monitoring';

export interface UseReactorPerformanceOptions {
  enableMonitoring?: boolean;
  enableProfiling?: boolean;
  enableBenchmarking?: boolean;
  collectionInterval?: number;
  alertThresholds?: Array<{
    metric: string;
    operator: '>' | '<' | '>=' | '<=' | '==' | '!=';
    value: number;
    severity: 'low' | 'medium' | 'high' | 'critical';
  }>;
}

export default function useReactorPerformance(options: UseReactorPerformanceOptions = {}) {
  // Initialize monitoring components
  const performanceMonitor = options.enableMonitoring 
    ? createPerformanceMonitor({
        enabled: true,
        collectionInterval: options.collectionInterval || 5000,
        alerting: {
          enabled: true,
          thresholds: options.alertThresholds?.map(t => ({
            id: `threshold_${t.metric}`,
            metric: t.metric,
            operator: t.operator,
            value: t.value,
            severity: t.severity,
            enabled: true,
            cooldownPeriod: 30000,
            tags: {}
          })) || [],
          notificationChannels: ['console']
        }
      })
    : null;

  const profiler = options.enableProfiling ? new SimpleProfiler() : null;

  // Reactive state
  const isMonitoring = ref(false);
  const isProfiling = ref(false);
  const isBenchmarking = ref(false);
  const performanceError: Ref<Error | null> = ref(null);

  const metrics: Ref<PerformanceMetric[]> = ref([]);
  const reactorMetrics: Ref<Map<string, ReactorPerformanceMetrics>> = ref(new Map());
  const alerts: Ref<PerformanceAlert[]> = ref([]);
  const profiles: Ref<any[]> = ref([]);
  const benchmarkResults: Ref<BenchmarkResult[]> = ref([]);

  const systemMetrics: Ref<{
    cpu: number;
    memory: number;
    heap: number;
    uptime: number;
  }> = ref({
    cpu: 0,
    memory: 0,
    heap: 0,
    uptime: 0
  });

  // Computed properties
  const averageLatency = computed(() => {
    const latencyMetrics = metrics.value.filter(m => m.category === 'latency');
    if (latencyMetrics.length === 0) return 0;
    
    return latencyMetrics.reduce((sum, m) => sum + m.value, 0) / latencyMetrics.length;
  });

  const throughput = computed(() => {
    const throughputMetrics = metrics.value.filter(m => m.category === 'throughput');
    if (throughputMetrics.length === 0) return 0;
    
    const recent = throughputMetrics.slice(-10);
    return recent.reduce((sum, m) => sum + m.value, 0) / recent.length;
  });

  const errorRate = computed(() => {
    const totalMetrics = metrics.value.length;
    if (totalMetrics === 0) return 0;
    
    const errorMetrics = metrics.value.filter(m => 
      m.name.includes('error') || m.category === 'error'
    );
    
    return errorMetrics.length / totalMetrics;
  });

  const performanceScore = computed(() => {
    // Calculate overall performance score (0-100)
    let score = 100;
    
    // Deduct for high latency
    if (averageLatency.value > 1000) score -= 20;
    else if (averageLatency.value > 500) score -= 10;
    
    // Deduct for low throughput
    if (throughput.value < 10) score -= 20;
    else if (throughput.value < 50) score -= 10;
    
    // Deduct for high error rate
    if (errorRate.value > 0.05) score -= 30;
    else if (errorRate.value > 0.01) score -= 15;
    
    // Deduct for high system resource usage
    if (systemMetrics.value.cpu > 80) score -= 15;
    if (systemMetrics.value.memory > 85) score -= 15;
    
    return Math.max(0, Math.min(100, score));
  });

  const criticalAlerts = computed(() => 
    alerts.value.filter(a => a.severity === 'critical')
  );

  const recentMetrics = computed(() => 
    metrics.value.slice(-100).reverse()
  );

  // Monitoring control
  const startMonitoring = async () => {
    if (!performanceMonitor) {
      throw new Error('Performance monitoring not enabled');
    }

    try {
      isMonitoring.value = true;
      performanceError.value = null;
      
      await performanceMonitor.start();
      
      // Start periodic data collection
      const collectionInterval = setInterval(async () => {
        try {
          await collectPerformanceData();
        } catch (error) {
          console.error('Performance data collection error:', error);
        }
      }, 5000);

      console.log('📈 Performance monitoring started');
      return collectionInterval;
    } catch (error) {
      performanceError.value = error as Error;
      isMonitoring.value = false;
      throw error;
    }
  };

  const stopMonitoring = async () => {
    if (!performanceMonitor) return;

    try {
      await performanceMonitor.stop();
      isMonitoring.value = false;
      console.log('📈 Performance monitoring stopped');
    } catch (error) {
      performanceError.value = error as Error;
      throw error;
    }
  };

  const collectPerformanceData = async () => {
    if (!performanceMonitor || !isMonitoring.value) return;

    try {
      // Get system metrics
      const sysMetrics = await performanceMonitor.getSystemMetrics();
      systemMetrics.value = {
        cpu: sysMetrics.cpu.usage,
        memory: sysMetrics.memory.usagePercent,
        heap: (sysMetrics.memory.heapUsed / sysMetrics.memory.heapTotal) * 100,
        uptime: sysMetrics.process.uptime
      };

      // Get recent performance metrics
      const recentMetrics = await performanceMonitor.getMetrics({
        startTime: Date.now() - 60000, // Last minute
        limit: 100
      });
      
      metrics.value = [...metrics.value, ...recentMetrics].slice(-1000); // Keep last 1000

      // Check for alerts
      const newAlerts = await performanceMonitor.checkAlerts();
      alerts.value = [...alerts.value, ...newAlerts].slice(-100); // Keep last 100

    } catch (error) {
      console.error('Performance data collection failed:', error);
    }
  };

  // Profiling
  const startProfiling = (name: string) => {
    if (!profiler) {
      throw new Error('Profiling not enabled');
    }

    isProfiling.value = true;
    return profiler.startProfiling(name);
  };

  const endProfiling = (profileId: string) => {
    if (!profiler) return null;

    const profile = profiler.endProfiling(profileId);
    profiles.value.push(profile);
    isProfiling.value = false;
    
    return profile;
  };

  const profileFunction = async <T>(name: string, fn: () => Promise<T>): Promise<T> => {
    if (!profiler) {
      return await fn();
    }

    return await profiler.profileFunction(name, fn);
  };

  const clearProfiles = () => {
    if (profiler) {
      profiler.clearProfiles();
    }
    profiles.value = [];
  };

  // Benchmarking
  const createReactorBenchmark = (
    name: string,
    reactorFactory: () => any,
    inputData: any = {},
    iterations: number = 100
  ) => {
    return createBenchmark(
      name,
      async () => {
        const reactor = reactorFactory();
        await reactor.execute(inputData);
      },
      iterations
    );
  };

  const runBenchmarkSuite = async (
    suiteName: string,
    benchmarks: Record<string, () => Promise<BenchmarkResult>>
  ) => {
    try {
      isBenchmarking.value = true;
      performanceError.value = null;

      const suite = new SimpleBenchmarkSuite({
        name: suiteName,
        description: `Reactor performance benchmarks: ${suiteName}`,
        benchmarks
      });

      const results = await suite.run();
      benchmarkResults.value = [...benchmarkResults.value, ...results];

      console.log(`🏃 Benchmark suite completed: ${suiteName}`);
      return results;
    } catch (error) {
      performanceError.value = error as Error;
      throw error;
    } finally {
      isBenchmarking.value = false;
    }
  };

  const compareBenchmarks = (benchmark1: string, benchmark2: string) => {
    const results1 = benchmarkResults.value.filter(r => r.name === benchmark1);
    const results2 = benchmarkResults.value.filter(r => r.name === benchmark2);

    if (results1.length === 0 || results2.length === 0) {
      return null;
    }

    const avg1 = results1.reduce((sum, r) => sum + r.operationsPerSecond, 0) / results1.length;
    const avg2 = results2.reduce((sum, r) => sum + r.operationsPerSecond, 0) / results2.length;

    return {
      benchmark1: { name: benchmark1, avgOpsPerSec: avg1 },
      benchmark2: { name: benchmark2, avgOpsPerSec: avg2 },
      performance: {
        faster: avg1 > avg2 ? benchmark1 : benchmark2,
        improvement: Math.abs((avg1 - avg2) / Math.min(avg1, avg2)) * 100,
        ratio: avg1 / avg2
      }
    };
  };

  // Reactor-specific tracking
  const trackReactor = (reactorId: string) => {
    if (!performanceMonitor) return null;

    const metrics = (performanceMonitor as any).startReactorTracking(reactorId);
    reactorMetrics.value.set(reactorId, metrics);
    
    return {
      updateMetrics: (updates: Partial<ReactorPerformanceMetrics>) => {
        (performanceMonitor as any).updateReactorMetrics(reactorId, updates);
      },
      endTracking: () => {
        const finalMetrics = (performanceMonitor as any).endReactorTracking(reactorId);
        if (finalMetrics) {
          reactorMetrics.value.set(reactorId, finalMetrics);
        }
        return finalMetrics;
      }
    };
  };

  const getReactorMetrics = (reactorId: string) => {
    return reactorMetrics.value.get(reactorId);
  };

  // Analysis and reporting
  const generatePerformanceReport = async (timeWindow: number = 3600000) => {
    if (!performanceMonitor) {
      throw new Error('Performance monitoring not enabled');
    }

    const analysis = await performanceMonitor.analyzePerformance(timeWindow);
    
    return {
      ...analysis,
      currentScore: performanceScore.value,
      systemHealth: {
        cpu: systemMetrics.value.cpu,
        memory: systemMetrics.value.memory,
        heap: systemMetrics.value.heap
      },
      reactorMetrics: Object.fromEntries(reactorMetrics.value),
      recentAlerts: alerts.value.slice(-10),
      benchmarkSummary: {
        totalBenchmarks: benchmarkResults.value.length,
        averageOpsPerSec: benchmarkResults.value.length > 0
          ? benchmarkResults.value.reduce((sum, r) => sum + r.operationsPerSecond, 0) / benchmarkResults.value.length
          : 0
      }
    };
  };

  const exportMetricsAsJSON = () => {
    return JSON.stringify({
      metrics: metrics.value,
      systemMetrics: systemMetrics.value,
      reactorMetrics: Object.fromEntries(reactorMetrics.value),
      alerts: alerts.value,
      profiles: profiles.value,
      benchmarks: benchmarkResults.value,
      timestamp: Date.now()
    }, null, 2);
  };

  const getPerformanceInsights = () => {
    const insights: string[] = [];
    
    if (performanceScore.value < 70) {
      insights.push(`Overall performance is below optimal (${performanceScore.value}/100)`);
    }
    
    if (averageLatency.value > 1000) {
      insights.push(`High average latency detected: ${averageLatency.value.toFixed(0)}ms`);
    }
    
    if (errorRate.value > 0.05) {
      insights.push(`High error rate: ${(errorRate.value * 100).toFixed(1)}%`);
    }
    
    if (systemMetrics.value.cpu > 80) {
      insights.push(`High CPU usage: ${systemMetrics.value.cpu.toFixed(1)}%`);
    }
    
    if (systemMetrics.value.memory > 85) {
      insights.push(`High memory usage: ${systemMetrics.value.memory.toFixed(1)}%`);
    }
    
    const slowProfiles = profiles.value.filter(p => p.duration > 5000);
    if (slowProfiles.length > 0) {
      insights.push(`${slowProfiles.length} slow operations detected in profiling`);
    }
    
    return insights;
  };

  // Optimization suggestions
  const getOptimizationSuggestions = () => {
    const suggestions: string[] = [];
    
    if (averageLatency.value > 1000) {
      suggestions.push('Consider implementing caching or optimizing slow operations');
    }
    
    if (errorRate.value > 0.01) {
      suggestions.push('Review error handling and implement retry mechanisms');
    }
    
    if (throughput.value < 50) {
      suggestions.push('Consider increasing concurrency or optimizing step execution');
    }
    
    if (systemMetrics.value.memory > 80) {
      suggestions.push('Implement memory optimization or increase available memory');
    }
    
    const highVarianceProfiles = profiles.value.filter(p => p.duration > averageLatency.value * 2);
    if (highVarianceProfiles.length > 0) {
      suggestions.push('Investigate and optimize high-variance operations');
    }
    
    return suggestions;
  };

  return {
    // State
    isMonitoring: readonly(isMonitoring),
    isProfiling: readonly(isProfiling),
    isBenchmarking: readonly(isBenchmarking),
    performanceError: readonly(performanceError),
    metrics: readonly(metrics),
    reactorMetrics: readonly(reactorMetrics),
    alerts: readonly(alerts),
    profiles: readonly(profiles),
    benchmarkResults: readonly(benchmarkResults),
    systemMetrics: readonly(systemMetrics),

    // Computed
    averageLatency,
    throughput,
    errorRate,
    performanceScore,
    criticalAlerts,
    recentMetrics,

    // Monitoring
    startMonitoring,
    stopMonitoring,
    collectPerformanceData,

    // Profiling
    startProfiling,
    endProfiling,
    profileFunction,
    clearProfiles,

    // Benchmarking
    createReactorBenchmark,
    runBenchmarkSuite,
    compareBenchmarks,

    // Reactor tracking
    trackReactor,
    getReactorMetrics,

    // Analysis
    generatePerformanceReport,
    exportMetricsAsJSON,
    getPerformanceInsights,
    getOptimizationSuggestions,

    // Direct monitor access
    performanceMonitor,
    profiler
  };
}