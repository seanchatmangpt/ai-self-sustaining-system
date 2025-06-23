/**
 * Performance Monitoring System Types
 * Comprehensive performance tracking for reactor operations
 */

export interface PerformanceMetric {
  id: string;
  name: string;
  value: number;
  unit: string;
  timestamp: number;
  category: 'memory' | 'cpu' | 'network' | 'disk' | 'latency' | 'throughput' | 'custom';
  tags: Record<string, string>;
  metadata: Record<string, any>;
}

export interface SystemMetrics {
  cpu: {
    usage: number;
    loadAverage: number[];
    cores: number;
  };
  memory: {
    total: number;
    used: number;
    free: number;
    usagePercent: number;
    heapUsed: number;
    heapTotal: number;
  };
  network: {
    bytesIn: number;
    bytesOut: number;
    connectionsActive: number;
  };
  disk: {
    total: number;
    used: number;
    free: number;
    usagePercent: number;
    readOps: number;
    writeOps: number;
  };
  process: {
    pid: number;
    uptime: number;
    memoryUsage: NodeJS.MemoryUsage;
    cpuUsage: NodeJS.CpuUsage;
  };
}

export interface ReactorPerformanceMetrics {
  reactorId: string;
  executionTime: number;
  stepsExecuted: number;
  stepsSucceeded: number;
  stepsFailed: number;
  memoryUsage: {
    start: number;
    end: number;
    peak: number;
  };
  cpuUsage: {
    user: number;
    system: number;
  };
  concurrency: {
    maxConcurrent: number;
    averageConcurrent: number;
  };
  throughput: {
    stepsPerSecond: number;
    operationsPerSecond: number;
  };
  latency: {
    min: number;
    max: number;
    avg: number;
    p50: number;
    p95: number;
    p99: number;
  };
  errors: {
    total: number;
    byType: Record<string, number>;
    rate: number;
  };
}

export interface PerformanceAlert {
  id: string;
  type: 'threshold' | 'anomaly' | 'trend' | 'error_rate';
  severity: 'low' | 'medium' | 'high' | 'critical';
  message: string;
  metric: string;
  threshold?: number;
  actualValue: number;
  timestamp: number;
  reactorId?: string;
  agentId?: string;
  tags: Record<string, string>;
  metadata: Record<string, any>;
}

export interface PerformanceThreshold {
  id: string;
  metric: string;
  operator: '>' | '<' | '>=' | '<=' | '==' | '!=';
  value: number;
  severity: PerformanceAlert['severity'];
  enabled: boolean;
  cooldownPeriod: number;
  tags: Record<string, string>;
}

export interface PerformanceConfiguration {
  enabled: boolean;
  collectionInterval: number;
  retentionPeriod: number;
  metricsBuffer: number;
  alerting: {
    enabled: boolean;
    thresholds: PerformanceThreshold[];
    notificationChannels: string[];
  };
  storage: {
    type: 'memory' | 'file' | 'database';
    options: Record<string, any>;
  };
  aggregation: {
    enabled: boolean;
    intervals: number[];
    functions: ('avg' | 'min' | 'max' | 'sum' | 'count')[];
  };
}

export interface PerformanceCollector {
  id: string;
  name: string;
  enabled: boolean;
  collectInterval: number;
  collect(): Promise<PerformanceMetric[]>;
  configure(options: Record<string, any>): void;
  start(): Promise<void>;
  stop(): Promise<void>;
}

export interface PerformanceMonitor {
  start(): Promise<void>;
  stop(): Promise<void>;
  
  // Metric collection
  collectMetric(metric: PerformanceMetric): Promise<void>;
  collectMetrics(metrics: PerformanceMetric[]): Promise<void>;
  
  // Querying
  getMetrics(query: PerformanceQuery): Promise<PerformanceMetric[]>;
  getReactorMetrics(reactorId: string): Promise<ReactorPerformanceMetrics>;
  getSystemMetrics(): Promise<SystemMetrics>;
  
  // Alerting
  checkAlerts(): Promise<PerformanceAlert[]>;
  addThreshold(threshold: PerformanceThreshold): Promise<void>;
  removeThreshold(id: string): Promise<void>;
  
  // Analysis
  analyzePerformance(timeWindow: number): Promise<PerformanceAnalysis>;
  generateReport(options: ReportOptions): Promise<PerformanceReport>;
  
  // Configuration
  updateConfiguration(config: Partial<PerformanceConfiguration>): Promise<void>;
  getConfiguration(): Promise<PerformanceConfiguration>;
}

export interface PerformanceQuery {
  metric?: string;
  category?: PerformanceMetric['category'];
  tags?: Record<string, string>;
  startTime?: number;
  endTime?: number;
  limit?: number;
  aggregation?: {
    function: 'avg' | 'min' | 'max' | 'sum' | 'count';
    interval: number;
  };
}

export interface PerformanceAnalysis {
  timeWindow: number;
  summary: {
    totalMetrics: number;
    categories: Record<PerformanceMetric['category'], number>;
    averageLatency: number;
    throughput: number;
    errorRate: number;
  };
  trends: {
    metric: string;
    direction: 'increasing' | 'decreasing' | 'stable';
    rate: number;
    confidence: number;
  }[];
  anomalies: {
    metric: string;
    timestamp: number;
    value: number;
    expectedValue: number;
    deviation: number;
  }[];
  recommendations: string[];
  bottlenecks: {
    component: string;
    metric: string;
    impact: 'low' | 'medium' | 'high';
    suggestion: string;
  }[];
}

export interface ReportOptions {
  format: 'json' | 'html' | 'csv' | 'pdf';
  timeRange: {
    start: number;
    end: number;
  };
  includeCharts: boolean;
  includeTrends: boolean;
  includeAnomalies: boolean;
  includeRecommendations: boolean;
  groupBy?: string[];
  filters?: Record<string, any>;
}

export interface PerformanceReport {
  id: string;
  generatedAt: number;
  timeRange: {
    start: number;
    end: number;
  };
  summary: {
    totalMetrics: number;
    reactorsMonitored: number;
    alertsGenerated: number;
    averagePerformance: number;
  };
  sections: {
    systemOverview: SystemMetrics;
    reactorPerformance: ReactorPerformanceMetrics[];
    trends: any[];
    anomalies: any[];
    recommendations: string[];
  };
  charts?: any[];
  rawData?: PerformanceMetric[];
}

export interface BenchmarkResult {
  name: string;
  duration: number;
  operations: number;
  operationsPerSecond: number;
  memoryUsage: {
    before: number;
    after: number;
    peak: number;
  };
  cpuUsage: {
    user: number;
    system: number;
  };
  success: boolean;
  error?: string;
  metadata: Record<string, any>;
}

export interface BenchmarkSuite {
  name: string;
  description: string;
  benchmarks: Record<string, () => Promise<BenchmarkResult>>;
  setup?: () => Promise<void>;
  teardown?: () => Promise<void>;
  run(): Promise<BenchmarkResult[]>;
}

export interface PerformanceMiddlewareOptions {
  enabled: boolean;
  collectSystemMetrics: boolean;
  collectReactorMetrics: boolean;
  alerting: boolean;
  monitor?: PerformanceMonitor;
}

export interface PerformanceProfiler {
  startProfiling(name: string): string;
  endProfiling(profileId: string): PerformanceProfile;
  profileFunction<T>(name: string, fn: () => Promise<T>): Promise<T>;
  profileStep(stepName: string): { start: () => void; end: () => void };
}

export interface PerformanceProfile {
  id: string;
  name: string;
  startTime: number;
  endTime: number;
  duration: number;
  cpuUsage: NodeJS.CpuUsage;
  memoryUsage: {
    start: NodeJS.MemoryUsage;
    end: NodeJS.MemoryUsage;
    peak: NodeJS.MemoryUsage;
  };
  operations: number;
  callStack?: string[];
  metadata: Record<string, any>;
}