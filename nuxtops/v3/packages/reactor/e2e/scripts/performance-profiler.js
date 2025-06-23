#!/usr/bin/env node

/**
 * Performance Profiler for Reactor E2E Tests
 * Analyzes performance metrics and identifies bottlenecks using 80/20 principles
 */

const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');
const chalk = require('chalk');
const ora = require('ora');
const { table } = require('table');

class ReactorPerformanceProfiler {
  constructor() {
    this.baseUrl = process.env.BASE_URL || 'http://localhost:3000';
    this.reportsDir = path.join(__dirname, '..', 'reports');
    this.profilesDir = path.join(this.reportsDir, 'profiles');
    this.resultsFile = path.join(this.reportsDir, 'performance-profile.json');
    
    // Performance thresholds (based on 80/20 principle)
    this.thresholds = {
      critical80: {
        responseTime: 100,    // 100ms for critical paths
        memoryUsage: 50,      // 50MB for critical operations
        cpuUsage: 30,         // 30% CPU for critical operations
        throughput: 100       // 100 ops/sec minimum
      },
      edge20: {
        responseTime: 1000,   // 1000ms for edge cases
        memoryUsage: 200,     // 200MB for edge cases
        cpuUsage: 70,         // 70% CPU for edge cases
        throughput: 10        // 10 ops/sec minimum
      }
    };
  }

  async profile() {
    const spinner = ora('Starting performance profiling...').start();
    
    try {
      // Ensure directories exist
      this.ensureDirectories();
      
      // Initialize browser
      const browser = await chromium.launch({
        headless: true,
        args: ['--enable-precise-memory-info']
      });
      
      const context = await browser.newContext();
      const page = await context.newPage();
      
      // Enable performance monitoring
      await page.coverage.startJSCoverage();
      await page.coverage.startCSSCoverage();
      
      // Run profiling scenarios
      const profiles = await this.runProfilingScenarios(page);
      
      // Analyze results
      const analysis = this.analyzeProfiles(profiles);
      
      // Generate report
      const report = {
        timestamp: new Date().toISOString(),
        profiles: profiles,
        analysis: analysis,
        recommendations: this.generateRecommendations(analysis),
        thresholds: this.thresholds
      };
      
      // Save results
      await this.saveReport(report);
      
      // Cleanup
      await browser.close();
      
      spinner.succeed('Performance profiling completed');
      this.printSummary(report);
      
      return report;
      
    } catch (error) {
      spinner.fail(`Profiling failed: ${error.message}`);
      throw error;
    }
  }

  ensureDirectories() {
    [this.reportsDir, this.profilesDir].forEach(dir => {
      if (!fs.existsSync(dir)) {
        fs.mkdirSync(dir, { recursive: true });
      }
    });
  }

  async runProfilingScenarios(page) {
    const scenarios = [
      {
        name: 'basic_reactor_execution',
        category: 'critical-80',
        description: 'Basic reactor input-process-output workflow',
        endpoint: '/api/reactor/examples/basic',
        iterations: 20
      },
      {
        name: 'parallel_processing',
        category: 'critical-80',
        description: 'Parallel step execution with convergence',
        endpoint: '/api/reactor/examples/parallel',
        iterations: 15
      },
      {
        name: 'error_recovery',
        category: 'critical-80',
        description: 'Error handling and compensation',
        endpoint: '/api/reactor/examples/error-recovery',
        iterations: 10
      },
      {
        name: 'memory_stress',
        category: 'edge-20',
        description: 'Large dataset processing',
        endpoint: '/api/reactor/examples/stress/memory',
        iterations: 5
      },
      {
        name: 'high_concurrency',
        category: 'edge-20',
        description: 'Multiple concurrent reactors',
        endpoint: '/api/reactor/examples/stress/concurrency',
        iterations: 3
      }
    ];

    const profiles = [];
    
    for (const scenario of scenarios) {
      const profile = await this.profileScenario(page, scenario);
      profiles.push(profile);
    }
    
    return profiles;
  }

  async profileScenario(page, scenario) {
    const profile = {
      scenario: scenario.name,
      category: scenario.category,
      description: scenario.description,
      iterations: scenario.iterations,
      metrics: [],
      summary: {}
    };

    for (let i = 0; i < scenario.iterations; i++) {
      const iteration = await this.profileIteration(page, scenario, i);
      profile.metrics.push(iteration);
    }

    // Calculate summary statistics
    profile.summary = this.calculateSummaryStats(profile.metrics);
    
    return profile;
  }

  async profileIteration(page, scenario, iteration) {
    const startTime = Date.now();
    
    // Start performance tracking
    const startMetrics = await page.evaluate(() => {
      return {
        memory: performance.memory ? {
          usedJSHeapSize: performance.memory.usedJSHeapSize,
          totalJSHeapSize: performance.memory.totalJSHeapSize,
          jsHeapSizeLimit: performance.memory.jsHeapSizeLimit
        } : null,
        timing: performance.now()
      };
    });

    try {
      // Execute the scenario
      const response = await page.goto(`${this.baseUrl}${scenario.endpoint}`, {
        waitUntil: 'networkidle',
        timeout: 30000
      });

      // Wait for any async operations
      await page.waitForTimeout(100);

      // Get end metrics
      const endMetrics = await page.evaluate(() => {
        return {
          memory: performance.memory ? {
            usedJSHeapSize: performance.memory.usedJSHeapSize,
            totalJSHeapSize: performance.memory.totalJSHeapSize,
            jsHeapSizeLimit: performance.memory.jsHeapSizeLimit
          } : null,
          timing: performance.now()
        };
      });

      const endTime = Date.now();

      // Calculate metrics
      const iteration_metrics = {
        iteration: iteration,
        success: response.ok(),
        responseTime: endTime - startTime,
        statusCode: response.status(),
        memoryUsage: endMetrics.memory ? {
          used: endMetrics.memory.usedJSHeapSize - startMetrics.memory.usedJSHeapSize,
          total: endMetrics.memory.totalJSHeapSize,
          limit: endMetrics.memory.jsHeapSizeLimit
        } : null,
        performanceTiming: endMetrics.timing - startMetrics.timing,
        timestamp: new Date().toISOString()
      };

      return iteration_metrics;

    } catch (error) {
      return {
        iteration: iteration,
        success: false,
        error: error.message,
        responseTime: Date.now() - startTime,
        timestamp: new Date().toISOString()
      };
    }
  }

  calculateSummaryStats(metrics) {
    const successful = metrics.filter(m => m.success);
    const responseTimes = successful.map(m => m.responseTime);
    const memoryUsages = successful
      .filter(m => m.memoryUsage)
      .map(m => m.memoryUsage.used / 1024 / 1024); // Convert to MB

    return {
      totalIterations: metrics.length,
      successfulIterations: successful.length,
      successRate: (successful.length / metrics.length) * 100,
      responseTime: {
        min: Math.min(...responseTimes),
        max: Math.max(...responseTimes),
        avg: responseTimes.reduce((a, b) => a + b, 0) / responseTimes.length,
        p50: this.percentile(responseTimes, 0.5),
        p90: this.percentile(responseTimes, 0.9),
        p95: this.percentile(responseTimes, 0.95),
        p99: this.percentile(responseTimes, 0.99)
      },
      memoryUsage: memoryUsages.length > 0 ? {
        min: Math.min(...memoryUsages),
        max: Math.max(...memoryUsages),
        avg: memoryUsages.reduce((a, b) => a + b, 0) / memoryUsages.length,
        p95: this.percentile(memoryUsages, 0.95)
      } : null,
      throughput: successful.length / (Math.max(...responseTimes) / 1000), // ops/sec
      errors: metrics.filter(m => !m.success).map(m => m.error)
    };
  }

  percentile(values, p) {
    const sorted = values.sort((a, b) => a - b);
    const index = Math.ceil(sorted.length * p) - 1;
    return sorted[index];
  }

  analyzeProfiles(profiles) {
    const analysis = {
      overall: {
        totalScenarios: profiles.length,
        criticalScenarios: profiles.filter(p => p.category === 'critical-80').length,
        edgeScenarios: profiles.filter(p => p.category === 'edge-20').length,
        overallSuccessRate: 0
      },
      violations: [],
      bottlenecks: [],
      trends: {}
    };

    // Calculate overall success rate
    const totalIterations = profiles.reduce((sum, p) => sum + p.summary.totalIterations, 0);
    const totalSuccessful = profiles.reduce((sum, p) => sum + p.summary.successfulIterations, 0);
    analysis.overall.overallSuccessRate = (totalSuccessful / totalIterations) * 100;

    // Check threshold violations
    profiles.forEach(profile => {
      const thresholds = this.thresholds[profile.category.replace('-', '')];
      const violations = this.checkThresholdViolations(profile, thresholds);
      analysis.violations.push(...violations);
    });

    // Identify bottlenecks
    analysis.bottlenecks = this.identifyBottlenecks(profiles);

    // Analyze trends
    analysis.trends = this.analyzeTrends(profiles);

    return analysis;
  }

  checkThresholdViolations(profile, thresholds) {
    const violations = [];
    const summary = profile.summary;

    if (summary.responseTime.avg > thresholds.responseTime) {
      violations.push({
        scenario: profile.scenario,
        category: profile.category,
        type: 'responseTime',
        metric: 'average',
        value: summary.responseTime.avg,
        threshold: thresholds.responseTime,
        severity: summary.responseTime.avg > thresholds.responseTime * 2 ? 'high' : 'medium'
      });
    }

    if (summary.responseTime.p95 > thresholds.responseTime * 2) {
      violations.push({
        scenario: profile.scenario,
        category: profile.category,
        type: 'responseTime',
        metric: 'p95',
        value: summary.responseTime.p95,
        threshold: thresholds.responseTime * 2,
        severity: 'high'
      });
    }

    if (summary.memoryUsage && summary.memoryUsage.avg > thresholds.memoryUsage) {
      violations.push({
        scenario: profile.scenario,
        category: profile.category,
        type: 'memoryUsage',
        metric: 'average',
        value: summary.memoryUsage.avg,
        threshold: thresholds.memoryUsage,
        severity: summary.memoryUsage.avg > thresholds.memoryUsage * 2 ? 'high' : 'medium'
      });
    }

    if (summary.throughput < thresholds.throughput) {
      violations.push({
        scenario: profile.scenario,
        category: profile.category,
        type: 'throughput',
        metric: 'average',
        value: summary.throughput,
        threshold: thresholds.throughput,
        severity: summary.throughput < thresholds.throughput * 0.5 ? 'high' : 'medium'
      });
    }

    return violations;
  }

  identifyBottlenecks(profiles) {
    const bottlenecks = [];

    // Sort profiles by performance metrics
    const byResponseTime = [...profiles].sort((a, b) => b.summary.responseTime.avg - a.summary.responseTime.avg);
    const byMemoryUsage = [...profiles]
      .filter(p => p.summary.memoryUsage)
      .sort((a, b) => b.summary.memoryUsage.avg - a.summary.memoryUsage.avg);

    // Top response time bottlenecks
    byResponseTime.slice(0, 3).forEach((profile, index) => {
      bottlenecks.push({
        rank: index + 1,
        type: 'responseTime',
        scenario: profile.scenario,
        category: profile.category,
        value: profile.summary.responseTime.avg,
        impact: profile.category === 'critical-80' ? 'high' : 'medium',
        description: `${profile.scenario} has high response time (${profile.summary.responseTime.avg.toFixed(2)}ms)`
      });
    });

    // Top memory usage bottlenecks
    byMemoryUsage.slice(0, 3).forEach((profile, index) => {
      bottlenecks.push({
        rank: index + 1,
        type: 'memoryUsage',
        scenario: profile.scenario,
        category: profile.category,
        value: profile.summary.memoryUsage.avg,
        impact: profile.category === 'critical-80' ? 'high' : 'medium',
        description: `${profile.scenario} has high memory usage (${profile.summary.memoryUsage.avg.toFixed(2)}MB)`
      });
    });

    return bottlenecks;
  }

  analyzeTrends(profiles) {
    const trends = {};

    profiles.forEach(profile => {
      // Analyze response time trends within iterations
      const responseTimes = profile.metrics.filter(m => m.success).map(m => m.responseTime);
      if (responseTimes.length > 1) {
        const slope = this.calculateSlope(responseTimes);
        trends[profile.scenario] = {
          responseTimeSlope: slope,
          trend: slope > 0.1 ? 'increasing' : slope < -0.1 ? 'decreasing' : 'stable'
        };
      }
    });

    return trends;
  }

  calculateSlope(values) {
    const n = values.length;
    const sumX = (n * (n - 1)) / 2;
    const sumY = values.reduce((a, b) => a + b, 0);
    const sumXY = values.reduce((sum, y, x) => sum + x * y, 0);
    const sumXX = values.reduce((sum, _, x) => sum + x * x, 0);

    return (n * sumXY - sumX * sumY) / (n * sumXX - sumX * sumX);
  }

  generateRecommendations(analysis) {
    const recommendations = [];

    // High severity violations
    const highSeverityViolations = analysis.violations.filter(v => v.severity === 'high');
    highSeverityViolations.forEach(violation => {
      recommendations.push({
        priority: 'high',
        category: 'performance',
        title: `Optimize ${violation.type} in ${violation.scenario}`,
        description: `${violation.metric} ${violation.type} is ${violation.value.toFixed(2)} (threshold: ${violation.threshold})`,
        action: `Investigate and optimize ${violation.scenario} ${violation.type}`,
        impact: violation.category === 'critical-80' ? 'Critical path performance' : 'Edge case performance'
      });
    });

    // Top bottlenecks
    const topBottlenecks = analysis.bottlenecks
      .filter(b => b.impact === 'high')
      .slice(0, 3);

    topBottlenecks.forEach(bottleneck => {
      recommendations.push({
        priority: 'medium',
        category: 'optimization',
        title: `Address ${bottleneck.type} bottleneck`,
        description: bottleneck.description,
        action: `Profile and optimize ${bottleneck.scenario}`,
        impact: 'Improves overall system performance'
      });
    });

    // Trending issues
    Object.entries(analysis.trends).forEach(([scenario, trend]) => {
      if (trend.trend === 'increasing') {
        recommendations.push({
          priority: 'medium',
          category: 'monitoring',
          title: `Monitor performance degradation in ${scenario}`,
          description: `Response time is trending upward`,
          action: `Investigate performance degradation in ${scenario}`,
          impact: 'Prevents future performance issues'
        });
      }
    });

    return recommendations.sort((a, b) => {
      const priorityOrder = { high: 1, medium: 2, low: 3 };
      return priorityOrder[a.priority] - priorityOrder[b.priority];
    });
  }

  async saveReport(report) {
    fs.writeFileSync(this.resultsFile, JSON.stringify(report, null, 2));
    
    // Save individual profile data
    report.profiles.forEach(profile => {
      const profileFile = path.join(this.profilesDir, `${profile.scenario}.json`);
      fs.writeFileSync(profileFile, JSON.stringify(profile, null, 2));
    });
  }

  printSummary(report) {
    console.log(chalk.bold('\n⚡ Performance Profiling Summary'));
    console.log('━'.repeat(50));
    
    // Overall statistics
    console.log(chalk.blue(`Total Scenarios: ${report.analysis.overall.totalScenarios}`));
    console.log(chalk.blue(`Critical 80%: ${report.analysis.overall.criticalScenarios}`));
    console.log(chalk.blue(`Edge 20%: ${report.analysis.overall.edgeScenarios}`));
    console.log(chalk.blue(`Overall Success Rate: ${report.analysis.overall.overallSuccessRate.toFixed(1)}%`));
    
    // Violations
    if (report.analysis.violations.length > 0) {
      console.log(chalk.bold('\n🚨 Threshold Violations:'));
      const violationData = report.analysis.violations.map(v => [
        v.scenario,
        v.type,
        v.metric,
        v.value.toFixed(2),
        v.threshold.toString(),
        v.severity
      ]);
      
      const violationTable = table([
        ['Scenario', 'Type', 'Metric', 'Value', 'Threshold', 'Severity'],
        ...violationData
      ]);
      console.log(violationTable);
    }
    
    // Top bottlenecks
    if (report.analysis.bottlenecks.length > 0) {
      console.log(chalk.bold('\n🔴 Top Performance Bottlenecks:'));
      report.analysis.bottlenecks
        .filter(b => b.impact === 'high')
        .slice(0, 5)
        .forEach((bottleneck, index) => {
          console.log(chalk.red(`${index + 1}. ${bottleneck.description}`));
        });
    }
    
    // Recommendations
    if (report.recommendations.length > 0) {
      console.log(chalk.bold('\n🎯 Top Recommendations:'));
      report.recommendations.slice(0, 3).forEach((rec, index) => {
        const priorityColor = rec.priority === 'high' ? chalk.red : chalk.yellow;
        console.log(priorityColor(`${index + 1}. [${rec.priority.toUpperCase()}] ${rec.title}`));
        console.log(chalk.gray(`   ${rec.description}`));
      });
    }
    
    console.log(chalk.dim(`\nDetailed report saved to: ${this.resultsFile}`));
    console.log(chalk.dim(`Profile data saved to: ${this.profilesDir}`));
  }
}

// Run profiling if called directly
if (require.main === module) {
  const profiler = new ReactorPerformanceProfiler();
  profiler.profile()
    .then(() => process.exit(0))
    .catch(error => {
      console.error(chalk.red('Profiling failed:'), error);
      process.exit(1);
    });
}

module.exports = ReactorPerformanceProfiler;