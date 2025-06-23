/**
 * Reactor Monitor
 * Comprehensive monitoring and observability for Nuxt Reactor workflows
 */

import type { ReactorResult, ReactorContext, ReactorStep } from '../types';

export interface MetricSnapshot {
  timestamp: number;
  reactorId: string;
  duration: number;
  stepCount: number;
  successRate: number;
  memoryUsage: number;
  cpuUsage?: number;
  errorCount: number;
  warnings: string[];
}

export interface HealthStatus {
  status: 'healthy' | 'degraded' | 'unhealthy';
  score: number; // 0-100
  issues: string[];
  recommendations: string[];
  lastCheck: number;
}

export interface PerformanceThresholds {
  maxDuration: number;
  maxMemoryMB: number;
  minSuccessRate: number;
  maxErrorRate: number;
  maxStepCount: number;
}

export interface AlertRule {
  id: string;
  name: string;
  condition: (metrics: MetricSnapshot[]) => boolean;
  severity: 'info' | 'warning' | 'error' | 'critical';
  cooldown: number; // minutes
  lastTriggered?: number;
}

export class ReactorMonitor {
  private metrics: MetricSnapshot[] = [];
  private alerts: AlertRule[] = [];
  private thresholds: PerformanceThresholds;
  private maxMetrics = 1000; // Keep last 1000 metrics
  
  constructor(thresholds?: Partial<PerformanceThresholds>) {
    this.thresholds = {
      maxDuration: 30000, // 30 seconds
      maxMemoryMB: 512,
      minSuccessRate: 0.95,
      maxErrorRate: 0.05,
      maxStepCount: 20,
      ...thresholds
    };
    
    this.setupDefaultAlerts();
  }
  
  /**
   * Record metrics from reactor execution
   */
  recordMetrics(result: ReactorResult): void {
    const snapshot: MetricSnapshot = {
      timestamp: Date.now(),
      reactorId: result.id,
      duration: result.duration,
      stepCount: result.results.size,
      successRate: this.calculateSuccessRate(result),
      memoryUsage: this.getMemoryUsage(),
      errorCount: result.errors.length,
      warnings: this.extractWarnings(result)
    };
    
    // Add CPU usage if available
    if (typeof performance !== 'undefined' && 'measureUserAgentSpecificMemory' in performance) {
      snapshot.cpuUsage = this.getCPUUsage();
    }
    
    this.metrics.push(snapshot);
    
    // Trim old metrics
    if (this.metrics.length > this.maxMetrics) {
      this.metrics = this.metrics.slice(-this.maxMetrics);
    }
    
    // Check alerts
    this.checkAlerts();
  }
  
  /**
   * Get current health status
   */
  getHealthStatus(): HealthStatus {
    if (this.metrics.length === 0) {
      return {
        status: 'healthy',
        score: 100,
        issues: [],
        recommendations: ['No metrics available yet'],
        lastCheck: Date.now()
      };
    }
    
    const recentMetrics = this.getRecentMetrics(5); // Last 5 minutes
    const issues: string[] = [];
    const recommendations: string[] = [];
    let score = 100;
    
    // Check performance thresholds
    const avgDuration = recentMetrics.reduce((sum, m) => sum + m.duration, 0) / recentMetrics.length;
    if (avgDuration > this.thresholds.maxDuration) {
      issues.push(`Average duration ${avgDuration}ms exceeds threshold ${this.thresholds.maxDuration}ms`);
      recommendations.push('Consider optimizing slow steps or using SPR compression');
      score -= 20;
    }
    
    const avgMemory = recentMetrics.reduce((sum, m) => sum + m.memoryUsage, 0) / recentMetrics.length;
    if (avgMemory > this.thresholds.maxMemoryMB) {
      issues.push(`Memory usage ${avgMemory}MB exceeds threshold ${this.thresholds.maxMemoryMB}MB`);
      recommendations.push('Review memory-intensive operations and add cleanup steps');
      score -= 15;
    }
    
    const avgSuccessRate = recentMetrics.reduce((sum, m) => sum + m.successRate, 0) / recentMetrics.length;
    if (avgSuccessRate < this.thresholds.minSuccessRate) {
      issues.push(`Success rate ${(avgSuccessRate * 100).toFixed(1)}% below threshold ${(this.thresholds.minSuccessRate * 100).toFixed(1)}%`);
      recommendations.push('Improve error handling and add retry mechanisms');
      score -= 25;
    }
    
    const errorRate = recentMetrics.reduce((sum, m) => sum + m.errorCount, 0) / recentMetrics.length;
    if (errorRate > this.thresholds.maxErrorRate) {
      issues.push(`Error rate ${(errorRate * 100).toFixed(1)}% exceeds threshold ${(this.thresholds.maxErrorRate * 100).toFixed(1)}%`);
      recommendations.push('Investigate and fix common error patterns');
      score -= 20;
    }
    
    // Determine status
    let status: HealthStatus['status'] = 'healthy';
    if (score < 80) status = 'degraded';
    if (score < 60) status = 'unhealthy';
    
    return {
      status,
      score: Math.max(0, score),
      issues,
      recommendations,
      lastCheck: Date.now()
    };
  }
  
  /**
   * Get performance summary
   */
  getPerformanceSummary(timeframeMinutes: number = 60): {
    totalExecutions: number;
    averageDuration: number;
    successRate: number;
    errorRate: number;
    throughput: number; // executions per minute
    trends: {
      duration: 'improving' | 'degrading' | 'stable';
      successRate: 'improving' | 'degrading' | 'stable';
      memory: 'improving' | 'degrading' | 'stable';
    };
  } {
    const metrics = this.getRecentMetrics(timeframeMinutes);
    
    if (metrics.length === 0) {
      return {
        totalExecutions: 0,
        averageDuration: 0,
        successRate: 0,
        errorRate: 0,
        throughput: 0,
        trends: { duration: 'stable', successRate: 'stable', memory: 'stable' }
      };
    }
    
    const totalExecutions = metrics.length;
    const averageDuration = metrics.reduce((sum, m) => sum + m.duration, 0) / totalExecutions;
    const successRate = metrics.reduce((sum, m) => sum + m.successRate, 0) / totalExecutions;
    const errorRate = metrics.reduce((sum, m) => sum + m.errorCount, 0) / totalExecutions;
    const throughput = totalExecutions / timeframeMinutes;
    
    return {
      totalExecutions,
      averageDuration,
      successRate,
      errorRate,
      throughput,
      trends: this.calculateTrends(metrics)
    };
  }
  
  /**
   * Get reactor execution timeline
   */
  getExecutionTimeline(timeframeMinutes: number = 60): Array<{
    timestamp: number;
    reactorId: string;
    duration: number;
    status: 'success' | 'error';
    stepCount: number;
  }> {
    return this.getRecentMetrics(timeframeMinutes).map(metric => ({
      timestamp: metric.timestamp,
      reactorId: metric.reactorId,
      duration: metric.duration,
      status: metric.errorCount > 0 ? 'error' : 'success',
      stepCount: metric.stepCount
    }));
  }
  
  /**
   * Add custom alert rule
   */
  addAlert(rule: AlertRule): void {
    this.alerts.push(rule);
  }
  
  /**
   * Get active alerts
   */
  getActiveAlerts(): AlertRule[] {
    const now = Date.now();
    return this.alerts.filter(alert => {
      if (!alert.lastTriggered) return false;
      const cooldownMs = alert.cooldown * 60 * 1000;
      return (now - alert.lastTriggered) < cooldownMs;
    });
  }
  
  /**
   * Export metrics for external systems
   */
  exportMetrics(format: 'json' | 'prometheus' | 'csv' = 'json'): string {
    switch (format) {
      case 'prometheus':
        return this.toPrometheusFormat();
      case 'csv':
        return this.toCsvFormat();
      default:
        return JSON.stringify(this.metrics, null, 2);
    }
  }
  
  /**
   * Clear all metrics
   */
  clear(): void {
    this.metrics = [];
  }
  
  private calculateSuccessRate(result: ReactorResult): number {
    if (result.results.size === 0) return 1;
    
    let successCount = 0;
    result.results.forEach(stepResult => {
      if (stepResult.success) successCount++;
    });
    
    return successCount / result.results.size;
  }
  
  private getMemoryUsage(): number {
    if (typeof performance !== 'undefined' && 'memory' in performance) {
      // Browser environment
      return (performance as any).memory.usedJSHeapSize / 1024 / 1024; // MB
    } else if (typeof process !== 'undefined' && process.memoryUsage) {
      // Node.js environment
      return process.memoryUsage().heapUsed / 1024 / 1024; // MB
    }
    return 0;
  }
  
  private getCPUUsage(): number {
    // Simplified CPU usage estimation
    if (typeof performance !== 'undefined') {
      const start = performance.now();
      let iterations = 0;
      const maxTime = 1; // 1ms sample
      
      while (performance.now() - start < maxTime) {
        iterations++;
      }
      
      // Normalize to 0-100 scale (rough approximation)
      return Math.min(100, iterations / 1000);
    }
    return 0;
  }
  
  private extractWarnings(result: ReactorResult): string[] {
    const warnings: string[] = [];
    
    // Check for slow steps
    result.results.forEach((stepResult, stepName) => {
      if (stepResult.success && stepResult.data?.duration > 10000) {
        warnings.push(`Step ${stepName} took ${stepResult.data.duration}ms`);
      }
    });
    
    // Check for memory issues
    const memoryUsage = this.getMemoryUsage();
    if (memoryUsage > this.thresholds.maxMemoryMB * 0.8) {
      warnings.push(`High memory usage: ${memoryUsage.toFixed(1)}MB`);
    }
    
    return warnings;
  }
  
  private getRecentMetrics(minutes: number): MetricSnapshot[] {
    const cutoff = Date.now() - (minutes * 60 * 1000);
    return this.metrics.filter(m => m.timestamp >= cutoff);
  }
  
  private calculateTrends(metrics: MetricSnapshot[]): {
    duration: 'improving' | 'degrading' | 'stable';
    successRate: 'improving' | 'degrading' | 'stable';
    memory: 'improving' | 'degrading' | 'stable';
  } {
    if (metrics.length < 2) {
      return { duration: 'stable', successRate: 'stable', memory: 'stable' };
    }
    
    const half = Math.floor(metrics.length / 2);
    const firstHalf = metrics.slice(0, half);
    const secondHalf = metrics.slice(half);
    
    const avgDuration1 = firstHalf.reduce((sum, m) => sum + m.duration, 0) / firstHalf.length;
    const avgDuration2 = secondHalf.reduce((sum, m) => sum + m.duration, 0) / secondHalf.length;
    
    const avgSuccess1 = firstHalf.reduce((sum, m) => sum + m.successRate, 0) / firstHalf.length;
    const avgSuccess2 = secondHalf.reduce((sum, m) => sum + m.successRate, 0) / secondHalf.length;
    
    const avgMemory1 = firstHalf.reduce((sum, m) => sum + m.memoryUsage, 0) / firstHalf.length;
    const avgMemory2 = secondHalf.reduce((sum, m) => sum + m.memoryUsage, 0) / secondHalf.length;
    
    const threshold = 0.05; // 5% change threshold
    
    return {
      duration: this.getTrend(avgDuration1, avgDuration2, threshold, true), // lower is better
      successRate: this.getTrend(avgSuccess1, avgSuccess2, threshold, false), // higher is better
      memory: this.getTrend(avgMemory1, avgMemory2, threshold, true) // lower is better
    };
  }
  
  private getTrend(
    value1: number, 
    value2: number, 
    threshold: number, 
    lowerIsBetter: boolean
  ): 'improving' | 'degrading' | 'stable' {
    const change = (value2 - value1) / value1;
    
    if (Math.abs(change) < threshold) return 'stable';
    
    if (lowerIsBetter) {
      return change < 0 ? 'improving' : 'degrading';
    } else {
      return change > 0 ? 'improving' : 'degrading';
    }
  }
  
  private setupDefaultAlerts(): void {
    this.alerts = [
      {
        id: 'high_duration',
        name: 'High Duration Alert',
        condition: (metrics) => {
          const recent = metrics.slice(-5);
          const avgDuration = recent.reduce((sum, m) => sum + m.duration, 0) / recent.length;
          return avgDuration > this.thresholds.maxDuration;
        },
        severity: 'warning',
        cooldown: 15
      },
      {
        id: 'low_success_rate',
        name: 'Low Success Rate Alert',
        condition: (metrics) => {
          const recent = metrics.slice(-10);
          const avgSuccess = recent.reduce((sum, m) => sum + m.successRate, 0) / recent.length;
          return avgSuccess < this.thresholds.minSuccessRate;
        },
        severity: 'error',
        cooldown: 10
      },
      {
        id: 'memory_leak',
        name: 'Memory Leak Alert',
        condition: (metrics) => {
          if (metrics.length < 10) return false;
          const recent = metrics.slice(-10);
          const trend = this.calculateTrends(recent);
          return trend.memory === 'degrading';
        },
        severity: 'critical',
        cooldown: 30
      }
    ];
  }
  
  private checkAlerts(): void {
    const now = Date.now();
    
    for (const alert of this.alerts) {
      // Check cooldown
      if (alert.lastTriggered && (now - alert.lastTriggered) < (alert.cooldown * 60 * 1000)) {
        continue;
      }
      
      if (alert.condition(this.metrics)) {
        alert.lastTriggered = now;
        this.triggerAlert(alert);
      }
    }
  }
  
  private triggerAlert(alert: AlertRule): void {
    if (process.env.NODE_ENV === 'development') {
      console.warn(`🚨 Reactor Alert [${alert.severity.toUpperCase()}]: ${alert.name}`);
    }
    
    // Could integrate with external alerting systems here
    // e.g., send to Slack, email, PagerDuty, etc.
  }
  
  private toPrometheusFormat(): string {
    const latest = this.metrics[this.metrics.length - 1];
    if (!latest) return '';
    
    return `
# HELP reactor_duration_seconds Duration of reactor execution
# TYPE reactor_duration_seconds gauge
reactor_duration_seconds{reactor_id="${latest.reactorId}"} ${latest.duration / 1000}

# HELP reactor_success_rate Success rate of reactor execution
# TYPE reactor_success_rate gauge
reactor_success_rate{reactor_id="${latest.reactorId}"} ${latest.successRate}

# HELP reactor_memory_bytes Memory usage in bytes
# TYPE reactor_memory_bytes gauge
reactor_memory_bytes{reactor_id="${latest.reactorId}"} ${latest.memoryUsage * 1024 * 1024}

# HELP reactor_step_count Number of steps in reactor
# TYPE reactor_step_count gauge
reactor_step_count{reactor_id="${latest.reactorId}"} ${latest.stepCount}
    `.trim();
  }
  
  private toCsvFormat(): string {
    const headers = ['timestamp', 'reactorId', 'duration', 'stepCount', 'successRate', 'memoryUsage', 'errorCount'];
    const rows = this.metrics.map(m => [
      m.timestamp,
      m.reactorId,
      m.duration,
      m.stepCount,
      m.successRate,
      m.memoryUsage,
      m.errorCount
    ].join(','));
    
    return [headers.join(','), ...rows].join('\n');
  }
}