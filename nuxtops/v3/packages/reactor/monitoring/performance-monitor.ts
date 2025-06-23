/**
 * Performance Monitor Implementation
 * Comprehensive system for tracking reactor and system performance
 */

import * as os from 'os';
import * as process from 'process';
import { performance } from 'perf_hooks';
import type {
  PerformanceMonitor,
  PerformanceMetric,
  SystemMetrics,
  ReactorPerformanceMetrics,
  PerformanceConfiguration,
  PerformanceQuery,
  PerformanceAlert,
  PerformanceThreshold,
  PerformanceAnalysis,
  PerformanceReport,
  ReportOptions,
  PerformanceCollector
} from './types';

const DEFAULT_CONFIG: PerformanceConfiguration = {
  enabled: true,
  collectionInterval: 5000, // 5 seconds
  retentionPeriod: 86400000, // 24 hours
  metricsBuffer: 10000,
  alerting: {
    enabled: true,
    thresholds: [],
    notificationChannels: []
  },
  storage: {
    type: 'memory',
    options: {}
  },
  aggregation: {
    enabled: true,
    intervals: [60000, 300000, 3600000], // 1min, 5min, 1hour
    functions: ['avg', 'min', 'max']
  }
};

export class PerformanceMonitorImpl implements PerformanceMonitor {
  private config: PerformanceConfiguration;
  private collectors: Map<string, PerformanceCollector> = new Map();
  private metrics: PerformanceMetric[] = [];
  private reactorMetrics: Map<string, ReactorPerformanceMetrics> = new Map();
  private thresholds: Map<string, PerformanceThreshold> = new Map();
  private alerts: PerformanceAlert[] = [];
  private isRunning = false;
  private collectionTimer?: NodeJS.Timeout;
  private lastSystemMetrics?: SystemMetrics;

  constructor(config: Partial<PerformanceConfiguration> = {}) {
    this.config = { ...DEFAULT_CONFIG, ...config };
    this.setupDefaultCollectors();
  }

  async start(): Promise<void> {
    if (this.isRunning) return;

    this.isRunning = true;
    console.log('🔍 Performance Monitor starting...');

    // Start all collectors
    for (const collector of this.collectors.values()) {
      if (collector.enabled) {
        await collector.start();
      }
    }

    // Start periodic collection
    this.collectionTimer = setInterval(
      () => this.performCollection(),
      this.config.collectionInterval
    );

    console.log('✅ Performance Monitor started');
  }

  async stop(): Promise<void> {
    if (!this.isRunning) return;

    console.log('🛑 Performance Monitor stopping...');
    this.isRunning = false;

    // Stop collection timer
    if (this.collectionTimer) {
      clearInterval(this.collectionTimer);
      this.collectionTimer = undefined;
    }

    // Stop all collectors
    for (const collector of this.collectors.values()) {
      await collector.stop();
    }

    console.log('✅ Performance Monitor stopped');
  }

  async collectMetric(metric: PerformanceMetric): Promise<void> {
    if (!this.config.enabled) return;

    // Add timestamp if not provided
    if (!metric.timestamp) {
      metric.timestamp = Date.now();
    }

    // Store metric
    this.metrics.push(metric);

    // Trim metrics buffer if needed
    if (this.metrics.length > this.config.metricsBuffer) {
      const cutoff = Date.now() - this.config.retentionPeriod;
      this.metrics = this.metrics.filter(m => m.timestamp > cutoff);
    }

    // Check alerts
    if (this.config.alerting.enabled) {
      await this.checkMetricAlerts(metric);
    }
  }

  async collectMetrics(metrics: PerformanceMetric[]): Promise<void> {
    for (const metric of metrics) {
      await this.collectMetric(metric);
    }
  }

  async getMetrics(query: PerformanceQuery): Promise<PerformanceMetric[]> {
    let results = [...this.metrics];

    // Apply filters
    if (query.metric) {
      results = results.filter(m => m.name === query.metric);
    }

    if (query.category) {
      results = results.filter(m => m.category === query.category);
    }

    if (query.tags) {
      results = results.filter(m => {
        return Object.entries(query.tags!).every(([key, value]) => m.tags[key] === value);
      });
    }

    if (query.startTime) {
      results = results.filter(m => m.timestamp >= query.startTime!);
    }

    if (query.endTime) {
      results = results.filter(m => m.timestamp <= query.endTime!);
    }

    // Apply aggregation if specified
    if (query.aggregation) {
      results = this.aggregateMetrics(results, query.aggregation);
    }

    // Apply limit
    if (query.limit) {
      results = results.slice(0, query.limit);
    }

    return results.sort((a, b) => b.timestamp - a.timestamp);
  }

  async getReactorMetrics(reactorId: string): Promise<ReactorPerformanceMetrics> {
    const existing = this.reactorMetrics.get(reactorId);
    if (existing) {
      return existing;
    }

    // Create default metrics if not found
    return {
      reactorId,
      executionTime: 0,
      stepsExecuted: 0,
      stepsSucceeded: 0,
      stepsFailed: 0,
      memoryUsage: { start: 0, end: 0, peak: 0 },
      cpuUsage: { user: 0, system: 0 },
      concurrency: { maxConcurrent: 0, averageConcurrent: 0 },
      throughput: { stepsPerSecond: 0, operationsPerSecond: 0 },
      latency: { min: 0, max: 0, avg: 0, p50: 0, p95: 0, p99: 0 },
      errors: { total: 0, byType: {}, rate: 0 }
    };
  }

  async getSystemMetrics(): Promise<SystemMetrics> {
    const memUsage = process.memoryUsage();
    const cpuUsage = process.cpuUsage();
    const loadAvg = os.loadavg();

    // Get system information
    const totalMem = os.totalmem();
    const freeMem = os.freemem();
    const usedMem = totalMem - freeMem;

    const metrics: SystemMetrics = {
      cpu: {
        usage: this.calculateCPUUsage(cpuUsage),
        loadAverage: loadAvg,
        cores: os.cpus().length
      },
      memory: {
        total: totalMem,
        used: usedMem,
        free: freeMem,
        usagePercent: (usedMem / totalMem) * 100,
        heapUsed: memUsage.heapUsed,
        heapTotal: memUsage.heapTotal
      },
      network: {
        bytesIn: 0, // Would need system information library for real data
        bytesOut: 0,
        connectionsActive: 0
      },
      disk: {
        total: 0, // Would need system information library for real data
        used: 0,
        free: 0,
        usagePercent: 0,
        readOps: 0,
        writeOps: 0
      },
      process: {
        pid: process.pid,
        uptime: process.uptime(),
        memoryUsage: memUsage,
        cpuUsage: cpuUsage
      }
    };

    this.lastSystemMetrics = metrics;
    return metrics;
  }

  async checkAlerts(): Promise<PerformanceAlert[]> {
    const newAlerts: PerformanceAlert[] = [];

    // Check threshold-based alerts
    for (const threshold of this.thresholds.values()) {
      if (!threshold.enabled) continue;

      const recentMetrics = this.metrics
        .filter(m => m.name === threshold.metric)
        .filter(m => m.timestamp > Date.now() - 60000) // Last minute
        .slice(-10); // Last 10 metrics

      if (recentMetrics.length === 0) continue;

      const latestMetric = recentMetrics[recentMetrics.length - 1];
      const breachesThreshold = this.checkThresholdBreach(latestMetric.value, threshold);

      if (breachesThreshold) {
        const alert: PerformanceAlert = {
          id: `alert_${Date.now()}_${threshold.id}`,
          type: 'threshold',
          severity: threshold.severity,
          message: `${threshold.metric} ${threshold.operator} ${threshold.value} (actual: ${latestMetric.value})`,
          metric: threshold.metric,
          threshold: threshold.value,
          actualValue: latestMetric.value,
          timestamp: Date.now(),
          tags: { ...threshold.tags, alertType: 'threshold' },
          metadata: { thresholdId: threshold.id }
        };

        newAlerts.push(alert);
        this.alerts.push(alert);
      }
    }

    // Trim old alerts
    const cutoff = Date.now() - this.config.retentionPeriod;
    this.alerts = this.alerts.filter(a => a.timestamp > cutoff);

    return newAlerts;
  }

  async addThreshold(threshold: PerformanceThreshold): Promise<void> {
    this.thresholds.set(threshold.id, threshold);
  }

  async removeThreshold(id: string): Promise<void> {
    this.thresholds.delete(id);
  }

  async analyzePerformance(timeWindow: number): Promise<PerformanceAnalysis> {
    const cutoff = Date.now() - timeWindow;
    const windowMetrics = this.metrics.filter(m => m.timestamp > cutoff);

    // Calculate summary
    const categoryCount: Record<string, number> = {};
    let totalLatency = 0;
    let latencyCount = 0;
    let errorCount = 0;

    for (const metric of windowMetrics) {
      categoryCount[metric.category] = (categoryCount[metric.category] || 0) + 1;
      
      if (metric.category === 'latency') {
        totalLatency += metric.value;
        latencyCount++;
      }
      
      if (metric.category === 'error' || metric.name.includes('error')) {
        errorCount++;
      }
    }

    const averageLatency = latencyCount > 0 ? totalLatency / latencyCount : 0;
    const errorRate = windowMetrics.length > 0 ? errorCount / windowMetrics.length : 0;
    const throughput = this.calculateThroughput(windowMetrics, timeWindow);

    // Detect trends
    const trends = this.detectTrends(windowMetrics);

    // Detect anomalies
    const anomalies = this.detectAnomalies(windowMetrics);

    // Generate recommendations
    const recommendations = this.generateRecommendations(windowMetrics, {
      averageLatency,
      errorRate,
      throughput
    });

    // Identify bottlenecks
    const bottlenecks = this.identifyBottlenecks(windowMetrics);

    return {
      timeWindow,
      summary: {
        totalMetrics: windowMetrics.length,
        categories: categoryCount as Record<PerformanceMetric['category'], number>,
        averageLatency,
        throughput,
        errorRate
      },
      trends,
      anomalies,
      recommendations,
      bottlenecks
    };
  }

  async generateReport(options: ReportOptions): Promise<PerformanceReport> {
    const timeRange = options.timeRange;
    const metrics = this.metrics.filter(
      m => m.timestamp >= timeRange.start && m.timestamp <= timeRange.end
    );

    const systemMetrics = await this.getSystemMetrics();
    const reactorMetrics = Array.from(this.reactorMetrics.values());

    const report: PerformanceReport = {
      id: `report_${Date.now()}`,
      generatedAt: Date.now(),
      timeRange,
      summary: {
        totalMetrics: metrics.length,
        reactorsMonitored: reactorMetrics.length,
        alertsGenerated: this.alerts.filter(
          a => a.timestamp >= timeRange.start && a.timestamp <= timeRange.end
        ).length,
        averagePerformance: this.calculateAveragePerformance(metrics)
      },
      sections: {
        systemOverview: systemMetrics,
        reactorPerformance: reactorMetrics,
        trends: options.includeTrends ? this.detectTrends(metrics) : [],
        anomalies: options.includeAnomalies ? this.detectAnomalies(metrics) : [],
        recommendations: options.includeRecommendations 
          ? this.generateRecommendations(metrics, { averageLatency: 0, errorRate: 0, throughput: 0 })
          : []
      }
    };

    if (options.includeCharts) {
      report.charts = this.generateCharts(metrics);
    }

    if (options.format === 'json') {
      report.rawData = metrics;
    }

    return report;
  }

  async updateConfiguration(config: Partial<PerformanceConfiguration>): Promise<void> {
    this.config = { ...this.config, ...config };
    
    // Restart if necessary
    if (this.isRunning) {
      await this.stop();
      await this.start();
    }
  }

  async getConfiguration(): Promise<PerformanceConfiguration> {
    return { ...this.config };
  }

  // Reactor-specific tracking methods
  startReactorTracking(reactorId: string): ReactorPerformanceMetrics {
    const metrics: ReactorPerformanceMetrics = {
      reactorId,
      executionTime: Date.now(),
      stepsExecuted: 0,
      stepsSucceeded: 0,
      stepsFailed: 0,
      memoryUsage: {
        start: process.memoryUsage().heapUsed,
        end: 0,
        peak: process.memoryUsage().heapUsed
      },
      cpuUsage: process.cpuUsage(),
      concurrency: { maxConcurrent: 0, averageConcurrent: 0 },
      throughput: { stepsPerSecond: 0, operationsPerSecond: 0 },
      latency: { min: Infinity, max: 0, avg: 0, p50: 0, p95: 0, p99: 0 },
      errors: { total: 0, byType: {}, rate: 0 }
    };

    this.reactorMetrics.set(reactorId, metrics);
    return metrics;
  }

  updateReactorMetrics(reactorId: string, update: Partial<ReactorPerformanceMetrics>): void {
    const existing = this.reactorMetrics.get(reactorId);
    if (existing) {
      Object.assign(existing, update);
    }
  }

  endReactorTracking(reactorId: string): ReactorPerformanceMetrics | null {
    const metrics = this.reactorMetrics.get(reactorId);
    if (!metrics) return null;

    // Finalize metrics
    metrics.executionTime = Date.now() - metrics.executionTime;
    metrics.memoryUsage.end = process.memoryUsage().heapUsed;
    
    // Calculate derived metrics
    if (metrics.executionTime > 0) {
      metrics.throughput.stepsPerSecond = (metrics.stepsExecuted / metrics.executionTime) * 1000;
      metrics.throughput.operationsPerSecond = metrics.throughput.stepsPerSecond;
    }

    if (metrics.stepsExecuted > 0) {
      metrics.errors.rate = metrics.stepsFailed / metrics.stepsExecuted;
    }

    return metrics;
  }

  // Private helper methods
  private setupDefaultCollectors(): void {
    // System metrics collector would be added here
    // For now, we'll use the periodic collection in performCollection()
  }

  private async performCollection(): Promise<void> {
    if (!this.config.enabled) return;

    try {
      // Collect system metrics
      const systemMetrics = await this.getSystemMetrics();
      
      // Convert system metrics to performance metrics
      const perfMetrics: PerformanceMetric[] = [
        {
          id: `cpu_usage_${Date.now()}`,
          name: 'cpu.usage',
          value: systemMetrics.cpu.usage,
          unit: 'percent',
          timestamp: Date.now(),
          category: 'cpu',
          tags: { component: 'system' },
          metadata: { cores: systemMetrics.cpu.cores }
        },
        {
          id: `memory_usage_${Date.now()}`,
          name: 'memory.usage',
          value: systemMetrics.memory.usagePercent,
          unit: 'percent',
          timestamp: Date.now(),
          category: 'memory',
          tags: { component: 'system' },
          metadata: { 
            total: systemMetrics.memory.total,
            used: systemMetrics.memory.used
          }
        },
        {
          id: `heap_usage_${Date.now()}`,
          name: 'heap.usage',
          value: systemMetrics.memory.heapUsed,
          unit: 'bytes',
          timestamp: Date.now(),
          category: 'memory',
          tags: { component: 'process' },
          metadata: { 
            heapTotal: systemMetrics.memory.heapTotal
          }
        }
      ];

      await this.collectMetrics(perfMetrics);

      // Run alert checks
      if (this.config.alerting.enabled) {
        await this.checkAlerts();
      }

    } catch (error) {
      console.error('Performance collection error:', error);
    }
  }

  private calculateCPUUsage(cpuUsage: NodeJS.CpuUsage): number {
    // This is a simplified calculation
    // In a real implementation, you'd track the delta over time
    return ((cpuUsage.user + cpuUsage.system) / 1000000) / os.cpus().length;
  }

  private checkThresholdBreach(value: number, threshold: PerformanceThreshold): boolean {
    switch (threshold.operator) {
      case '>': return value > threshold.value;
      case '<': return value < threshold.value;
      case '>=': return value >= threshold.value;
      case '<=': return value <= threshold.value;
      case '==': return value === threshold.value;
      case '!=': return value !== threshold.value;
      default: return false;
    }
  }

  private async checkMetricAlerts(metric: PerformanceMetric): Promise<void> {
    // This would check the metric against thresholds
    // Implementation details would depend on specific requirements
  }

  private aggregateMetrics(
    metrics: PerformanceMetric[], 
    aggregation: { function: string; interval: number }
  ): PerformanceMetric[] {
    // Group metrics by time intervals
    const groups: Map<number, PerformanceMetric[]> = new Map();
    
    for (const metric of metrics) {
      const intervalStart = Math.floor(metric.timestamp / aggregation.interval) * aggregation.interval;
      const group = groups.get(intervalStart) || [];
      group.push(metric);
      groups.set(intervalStart, group);
    }

    // Apply aggregation function to each group
    const aggregated: PerformanceMetric[] = [];
    
    for (const [intervalStart, groupMetrics] of groups.entries()) {
      if (groupMetrics.length === 0) continue;
      
      let aggregatedValue: number;
      
      switch (aggregation.function) {
        case 'avg':
          aggregatedValue = groupMetrics.reduce((sum, m) => sum + m.value, 0) / groupMetrics.length;
          break;
        case 'min':
          aggregatedValue = Math.min(...groupMetrics.map(m => m.value));
          break;
        case 'max':
          aggregatedValue = Math.max(...groupMetrics.map(m => m.value));
          break;
        case 'sum':
          aggregatedValue = groupMetrics.reduce((sum, m) => sum + m.value, 0);
          break;
        case 'count':
          aggregatedValue = groupMetrics.length;
          break;
        default:
          continue;
      }

      const firstMetric = groupMetrics[0];
      aggregated.push({
        ...firstMetric,
        id: `${firstMetric.id}_${aggregation.function}`,
        value: aggregatedValue,
        timestamp: intervalStart,
        metadata: {
          ...firstMetric.metadata,
          aggregation: aggregation.function,
          interval: aggregation.interval,
          samplesCount: groupMetrics.length
        }
      });
    }

    return aggregated;
  }

  private detectTrends(metrics: PerformanceMetric[]): any[] {
    // Simplified trend detection
    // Would implement proper statistical analysis in production
    return [];
  }

  private detectAnomalies(metrics: PerformanceMetric[]): any[] {
    // Simplified anomaly detection
    // Would implement proper statistical analysis in production
    return [];
  }

  private generateRecommendations(metrics: PerformanceMetric[], summary: any): string[] {
    const recommendations: string[] = [];
    
    if (summary.errorRate > 0.05) {
      recommendations.push('High error rate detected - review error handling and retry policies');
    }
    
    if (summary.averageLatency > 1000) {
      recommendations.push('High latency detected - consider optimizing slow operations');
    }
    
    const memoryMetrics = metrics.filter(m => m.category === 'memory');
    const highMemoryUsage = memoryMetrics.some(m => m.value > 80);
    
    if (highMemoryUsage) {
      recommendations.push('High memory usage detected - consider memory optimization strategies');
    }
    
    return recommendations;
  }

  private identifyBottlenecks(metrics: PerformanceMetric[]): any[] {
    // Simplified bottleneck identification
    return [];
  }

  private calculateThroughput(metrics: PerformanceMetric[], timeWindow: number): number {
    const throughputMetrics = metrics.filter(m => m.name.includes('throughput') || m.category === 'throughput');
    if (throughputMetrics.length === 0) return 0;
    
    return throughputMetrics.reduce((sum, m) => sum + m.value, 0) / throughputMetrics.length;
  }

  private calculateAveragePerformance(metrics: PerformanceMetric[]): number {
    if (metrics.length === 0) return 0;
    
    // Simplified performance score calculation
    const performanceMetrics = metrics.filter(m => 
      m.category === 'latency' || m.category === 'throughput' || m.category === 'cpu'
    );
    
    if (performanceMetrics.length === 0) return 50; // Default neutral score
    
    return performanceMetrics.reduce((sum, m) => sum + m.value, 0) / performanceMetrics.length;
  }

  private generateCharts(metrics: PerformanceMetric[]): any[] {
    // Would generate chart data structures
    return [];
  }
}