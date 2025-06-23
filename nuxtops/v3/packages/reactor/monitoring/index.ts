/**
 * Performance Monitoring System
 * Main exports for the performance monitoring system
 */

export type {
  PerformanceMetric,
  SystemMetrics,
  ReactorPerformanceMetrics,
  PerformanceAlert,
  PerformanceThreshold,
  PerformanceConfiguration,
  PerformanceCollector,
  PerformanceMonitor,
  PerformanceQuery,
  PerformanceAnalysis,
  PerformanceReport,
  ReportOptions,
  BenchmarkResult,
  BenchmarkSuite,
  PerformanceMiddlewareOptions,
  PerformanceProfiler,
  PerformanceProfile
} from './types';

export { PerformanceMonitorImpl } from './performance-monitor';

// Re-export types for convenience
import type { 
  PerformanceMonitor, 
  PerformanceConfiguration,
  BenchmarkSuite,
  PerformanceProfiler,
  PerformanceProfile,
  BenchmarkResult
} from './types';
import { PerformanceMonitorImpl } from './performance-monitor';

// Factory functions
export function createPerformanceMonitor(config?: Partial<PerformanceConfiguration>): PerformanceMonitor {
  return new PerformanceMonitorImpl(config);
}

// Utility functions for common monitoring scenarios
export function createReactorMonitor(): PerformanceMonitor {
  return new PerformanceMonitorImpl({
    enabled: true,
    collectionInterval: 1000, // 1 second for detailed reactor monitoring
    alerting: {
      enabled: true,
      thresholds: [
        {
          id: 'high_cpu',
          metric: 'cpu.usage',
          operator: '>',
          value: 80,
          severity: 'high',
          enabled: true,
          cooldownPeriod: 30000,
          tags: { component: 'system' }
        },
        {
          id: 'high_memory',
          metric: 'memory.usage',
          operator: '>',
          value: 85,
          severity: 'critical',
          enabled: true,
          cooldownPeriod: 30000,
          tags: { component: 'system' }
        },
        {
          id: 'high_latency',
          metric: 'reactor.latency',
          operator: '>',
          value: 5000,
          severity: 'medium',
          enabled: true,
          cooldownPeriod: 60000,
          tags: { component: 'reactor' }
        }
      ],
      notificationChannels: ['console']
    }
  });
}

export function createProductionMonitor(): PerformanceMonitor {
  return new PerformanceMonitorImpl({
    enabled: true,
    collectionInterval: 5000, // 5 seconds for production
    retentionPeriod: 604800000, // 7 days
    metricsBuffer: 50000,
    alerting: {
      enabled: true,
      thresholds: [
        {
          id: 'critical_cpu',
          metric: 'cpu.usage',
          operator: '>',
          value: 90,
          severity: 'critical',
          enabled: true,
          cooldownPeriod: 60000,
          tags: { environment: 'production' }
        },
        {
          id: 'critical_memory',
          metric: 'memory.usage',
          operator: '>',
          value: 90,
          severity: 'critical',
          enabled: true,
          cooldownPeriod: 60000,
          tags: { environment: 'production' }
        },
        {
          id: 'error_rate',
          metric: 'reactor.error_rate',
          operator: '>',
          value: 0.05,
          severity: 'high',
          enabled: true,
          cooldownPeriod: 300000,
          tags: { environment: 'production' }
        }
      ],
      notificationChannels: ['webhook', 'email']
    },
    aggregation: {
      enabled: true,
      intervals: [60000, 300000, 3600000, 86400000], // 1min, 5min, 1hour, 1day
      functions: ['avg', 'min', 'max', 'count']
    }
  });
}

// Simple profiler implementation
export class SimpleProfiler implements PerformanceProfiler {
  private profiles: Map<string, PerformanceProfile> = new Map();
  private activeProfiles: Map<string, { startTime: number; startCpu: NodeJS.CpuUsage; startMem: NodeJS.MemoryUsage }> = new Map();

  startProfiling(name: string): string {
    const profileId = `${name}_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
    
    this.activeProfiles.set(profileId, {
      startTime: performance.now(),
      startCpu: process.cpuUsage(),
      startMem: process.memoryUsage()
    });

    return profileId;
  }

  endProfiling(profileId: string): PerformanceProfile {
    const active = this.activeProfiles.get(profileId);
    if (!active) {
      throw new Error(`Profile not found: ${profileId}`);
    }

    const endTime = performance.now();
    const endCpu = process.cpuUsage(active.startCpu);
    const endMem = process.memoryUsage();

    const profile: PerformanceProfile = {
      id: profileId,
      name: profileId.split('_')[0],
      startTime: active.startTime,
      endTime,
      duration: endTime - active.startTime,
      cpuUsage: endCpu,
      memoryUsage: {
        start: active.startMem,
        end: endMem,
        peak: {
          rss: Math.max(active.startMem.rss, endMem.rss),
          heapTotal: Math.max(active.startMem.heapTotal, endMem.heapTotal),
          heapUsed: Math.max(active.startMem.heapUsed, endMem.heapUsed),
          external: Math.max(active.startMem.external, endMem.external),
          arrayBuffers: Math.max(active.startMem.arrayBuffers, endMem.arrayBuffers)
        }
      },
      operations: 1,
      metadata: {}
    };

    this.profiles.set(profileId, profile);
    this.activeProfiles.delete(profileId);

    return profile;
  }

  async profileFunction<T>(name: string, fn: () => Promise<T>): Promise<T> {
    const profileId = this.startProfiling(name);
    
    try {
      const result = await fn();
      this.endProfiling(profileId);
      return result;
    } catch (error) {
      this.endProfiling(profileId);
      throw error;
    }
  }

  profileStep(stepName: string): { start: () => void; end: () => void } {
    let profileId: string;

    return {
      start: () => {
        profileId = this.startProfiling(stepName);
      },
      end: () => {
        if (profileId) {
          this.endProfiling(profileId);
        }
      }
    };
  }

  getProfiles(): PerformanceProfile[] {
    return Array.from(this.profiles.values());
  }

  getProfile(id: string): PerformanceProfile | undefined {
    return this.profiles.get(id);
  }

  clearProfiles(): void {
    this.profiles.clear();
  }
}

// Simple benchmark suite implementation
export class SimpleBenchmarkSuite implements BenchmarkSuite {
  name: string;
  description: string;
  benchmarks: Record<string, () => Promise<BenchmarkResult>>;
  setup?: () => Promise<void>;
  teardown?: () => Promise<void>;

  constructor(options: {
    name: string;
    description: string;
    benchmarks: Record<string, () => Promise<BenchmarkResult>>;
    setup?: () => Promise<void>;
    teardown?: () => Promise<void>;
  }) {
    this.name = options.name;
    this.description = options.description;
    this.benchmarks = options.benchmarks;
    this.setup = options.setup;
    this.teardown = options.teardown;
  }

  async run(): Promise<BenchmarkResult[]> {
    const results: BenchmarkResult[] = [];

    // Run setup
    if (this.setup) {
      await this.setup();
    }

    try {
      // Run benchmarks
      for (const [name, benchmark] of Object.entries(this.benchmarks)) {
        console.log(`🏃 Running benchmark: ${name}`);
        
        try {
          const result = await benchmark();
          results.push(result);
          console.log(`✅ Benchmark ${name} completed: ${result.operationsPerSecond.toFixed(2)} ops/sec`);
        } catch (error) {
          const failedResult: BenchmarkResult = {
            name,
            duration: 0,
            operations: 0,
            operationsPerSecond: 0,
            memoryUsage: { before: 0, after: 0, peak: 0 },
            cpuUsage: { user: 0, system: 0 },
            success: false,
            error: error instanceof Error ? error.message : 'Unknown error',
            metadata: {}
          };
          results.push(failedResult);
          console.error(`❌ Benchmark ${name} failed:`, error);
        }
      }
    } finally {
      // Run teardown
      if (this.teardown) {
        await this.teardown();
      }
    }

    return results;
  }
}

// Utility functions for creating benchmarks
export function createBenchmark(
  name: string,
  operation: () => Promise<void> | void,
  iterations: number = 1000
): () => Promise<BenchmarkResult> {
  return async (): Promise<BenchmarkResult> => {
    const startMem = process.memoryUsage();
    const startCpu = process.cpuUsage();
    const startTime = performance.now();

    let peakMem = startMem.heapUsed;
    let operationsCompleted = 0;

    try {
      for (let i = 0; i < iterations; i++) {
        await operation();
        operationsCompleted++;
        
        // Track peak memory
        const currentMem = process.memoryUsage().heapUsed;
        if (currentMem > peakMem) {
          peakMem = currentMem;
        }
      }

      const endTime = performance.now();
      const endMem = process.memoryUsage();
      const endCpu = process.cpuUsage(startCpu);
      
      const duration = endTime - startTime;
      const operationsPerSecond = (operationsCompleted / duration) * 1000;

      return {
        name,
        duration,
        operations: operationsCompleted,
        operationsPerSecond,
        memoryUsage: {
          before: startMem.heapUsed,
          after: endMem.heapUsed,
          peak: peakMem
        },
        cpuUsage: {
          user: endCpu.user / 1000000, // Convert to seconds
          system: endCpu.system / 1000000
        },
        success: true,
        metadata: {
          iterations,
          avgDurationPerOp: duration / operationsCompleted
        }
      };
    } catch (error) {
      return {
        name,
        duration: 0,
        operations: operationsCompleted,
        operationsPerSecond: 0,
        memoryUsage: { before: startMem.heapUsed, after: 0, peak: peakMem },
        cpuUsage: { user: 0, system: 0 },
        success: false,
        error: error instanceof Error ? error.message : 'Unknown error',
        metadata: { iterations, completedIterations: operationsCompleted }
      };
    }
  };
}

// Export factory for creating a complete monitoring setup
export function createCompleteMonitoringSetup(environment: 'development' | 'production' = 'development') {
  const monitor = environment === 'production' ? createProductionMonitor() : createReactorMonitor();
  const profiler = new SimpleProfiler();
  
  return {
    monitor,
    profiler,
    createBenchmarkSuite: (name: string, description: string) => 
      new SimpleBenchmarkSuite({ name, description, benchmarks: {} })
  };
}