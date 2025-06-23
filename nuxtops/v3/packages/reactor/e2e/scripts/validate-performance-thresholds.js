#!/usr/bin/env node

/**
 * Performance Thresholds Validation Script
 * Validates reactor performance against 80/20 optimized thresholds
 */

const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');
const postgres = require('postgres');
const chalk = require('chalk');
const ora = require('ora');
const { table } = require('table');

class PerformanceThresholdValidator {
  constructor() {
    this.baseUrl = process.env.BASE_URL || 'http://localhost:3000';
    this.reportsDir = path.join(__dirname, '..', 'reports');
    this.outputFile = path.join(this.reportsDir, 'performance-validation-report.json');
    
    // Performance thresholds based on 80/20 analysis
    this.thresholds = {
      critical80: {
        responseTime: {
          p50: 50,    // 50ms median
          p95: 100,   // 100ms 95th percentile
          p99: 200    // 200ms 99th percentile
        },
        throughput: {
          min: 100,   // 100 requests/second minimum
          target: 500 // 500 requests/second target
        },
        memory: {
          baseline: 50,    // 50MB baseline
          peak: 100,       // 100MB peak
          leakRate: 1      // 1MB/hour leak rate
        },
        cpu: {
          average: 30,     // 30% average CPU
          peak: 70         // 70% peak CPU
        },
        errors: {
          rate: 0.1,       // 0.1% error rate
          timeout: 0.01    // 0.01% timeout rate
        }
      },
      edge20: {
        responseTime: {
          p50: 500,   // 500ms median
          p95: 2000,  // 2s 95th percentile
          p99: 5000   // 5s 99th percentile
        },
        throughput: {
          min: 10,    // 10 requests/second minimum
          target: 50  // 50 requests/second target
        },
        memory: {
          baseline: 100,   // 100MB baseline
          peak: 500,       // 500MB peak
          leakRate: 10     // 10MB/hour leak rate
        },
        cpu: {
          average: 60,     // 60% average CPU
          peak: 90         // 90% peak CPU
        },
        errors: {
          rate: 5,         // 5% error rate
          timeout: 1       // 1% timeout rate
        }
      }
    };

    this.db = null;
  }

  async validate() {
    const spinner = ora('Validating performance thresholds...').start();
    
    try {
      // Initialize connections
      await this.initializeDatabase();
      
      // Run performance tests
      const testResults = await this.runPerformanceTests();
      
      // Analyze results against thresholds
      const analysis = await this.analyzePerformance(testResults);
      
      // Generate validation report
      const report = {
        timestamp: new Date().toISOString(),
        testResults,
        analysis,
        thresholds: this.thresholds,
        recommendations: this.generateRecommendations(analysis),
        overallStatus: this.determineOverallStatus(analysis)
      };
      
      // Save report
      await this.saveReport(report);
      
      spinner.succeed('Performance validation completed');
      this.displayResults(report);
      
      return report.overallStatus.passed ? 0 : 1;
      
    } catch (error) {
      spinner.fail(`Performance validation failed: ${error.message}`);
      throw error;
    } finally {
      if (this.db) {
        await this.db.end();
      }
    }
  }

  async initializeDatabase() {
    try {
      this.db = postgres({
        host: 'localhost',
        port: 5432,
        database: 'reactor_e2e',
        username: 'reactor_user',
        password: 'reactor_pass'
      });
    } catch (error) {
      console.warn('Database connection failed, continuing without persistence:', error.message);
    }
  }

  async runPerformanceTests() {
    const browser = await chromium.launch({ headless: true });
    const context = await browser.newContext();
    const page = await context.newPage();

    const testResults = {
      critical80: await this.runCritical80Tests(page),
      edge20: await this.runEdge20Tests(page),
      baseline: await this.measureBaseline(page)
    };

    await browser.close();
    return testResults;
  }

  async runCritical80Tests(page) {
    const tests = [
      { name: 'basic-workflow', endpoint: '/api/reactor/examples/basic', iterations: 50 },
      { name: 'parallel-processing', endpoint: '/api/reactor/examples/parallel', iterations: 30 },
      { name: 'state-management', endpoint: '/api/reactor/examples/state-management', iterations: 40 },
      { name: 'api-integration', endpoint: '/api/reactor/examples/api-integration', iterations: 25 }
    ];

    const results = [];
    
    for (const test of tests) {
      console.log(`Running critical 80% test: ${test.name}`);
      const result = await this.runPerformanceTest(page, test);
      results.push(result);
    }

    return results;
  }

  async runEdge20Tests(page) {
    const tests = [
      { name: 'memory-stress', endpoint: '/api/reactor/examples/stress/memory', iterations: 10 },
      { name: 'cpu-intensive', endpoint: '/api/reactor/examples/stress/cpu', iterations: 15 },
      { name: 'high-concurrency', endpoint: '/api/reactor/examples/stress/concurrency', iterations: 20 },
      { name: 'error-recovery', endpoint: '/api/reactor/examples/error-recovery', iterations: 25 }
    ];

    const results = [];
    
    for (const test of tests) {
      console.log(`Running edge 20% test: ${test.name}`);
      const result = await this.runPerformanceTest(page, test);
      results.push(result);
    }

    return results;
  }

  async runPerformanceTest(page, test) {
    const measurements = [];
    let errorCount = 0;
    let timeoutCount = 0;

    for (let i = 0; i < test.iterations; i++) {
      try {
        const measurement = await this.performSingleMeasurement(page, test.endpoint);
        measurements.push(measurement);
        
        if (measurement.error) errorCount++;
        if (measurement.timeout) timeoutCount++;
        
      } catch (error) {
        errorCount++;
        measurements.push({
          responseTime: null,
          memoryUsage: null,
          cpuUsage: null,
          error: true,
          timeout: error.message.includes('timeout'),
          errorMessage: error.message
        });
      }

      // Brief pause between iterations
      await new Promise(resolve => setTimeout(resolve, 50));
    }

    return {
      testName: test.name,
      endpoint: test.endpoint,
      iterations: test.iterations,
      measurements,
      errorCount,
      timeoutCount,
      statistics: this.calculateStatistics(measurements),
      errorRate: (errorCount / test.iterations) * 100,
      timeoutRate: (timeoutCount / test.iterations) * 100
    };
  }

  async performSingleMeasurement(page, endpoint) {
    const startTime = performance.now();
    const startMemory = process.memoryUsage();
    const startCpu = process.cpuUsage();

    try {
      // Navigate to endpoint
      const response = await page.goto(`${this.baseUrl}${endpoint}`, {
        waitUntil: 'networkidle',
        timeout: 10000
      });

      const endTime = performance.now();
      const endMemory = process.memoryUsage();
      const endCpu = process.cpuUsage(startCpu);

      // Get browser memory usage
      const browserMemory = await page.evaluate(() => {
        return performance.memory ? {
          usedJSHeapSize: performance.memory.usedJSHeapSize,
          totalJSHeapSize: performance.memory.totalJSHeapSize
        } : null;
      });

      return {
        responseTime: endTime - startTime,
        memoryUsage: {
          node: {
            heapUsed: endMemory.heapUsed - startMemory.heapUsed,
            external: endMemory.external - startMemory.external
          },
          browser: browserMemory
        },
        cpuUsage: {
          user: endCpu.user / 1000, // Convert to milliseconds
          system: endCpu.system / 1000
        },
        statusCode: response?.status() || 0,
        success: response?.ok() || false,
        error: !response?.ok(),
        timeout: false
      };

    } catch (error) {
      const endTime = performance.now();
      
      return {
        responseTime: endTime - startTime,
        memoryUsage: null,
        cpuUsage: null,
        statusCode: 0,
        success: false,
        error: true,
        timeout: error.message.includes('timeout'),
        errorMessage: error.message
      };
    }
  }

  async measureBaseline(page) {
    console.log('Measuring baseline performance...');
    
    // Let the system settle
    await new Promise(resolve => setTimeout(resolve, 2000));
    
    const baselineStart = process.memoryUsage();
    const baselineCpuStart = process.cpuUsage();
    
    // Wait and measure again
    await new Promise(resolve => setTimeout(resolve, 5000));
    
    const baselineEnd = process.memoryUsage();
    const baselineCpuEnd = process.cpuUsage(baselineCpuStart);
    
    return {
      memory: {
        heapUsed: baselineEnd.heapUsed,
        heapTotal: baselineEnd.heapTotal,
        external: baselineEnd.external,
        rss: baselineEnd.rss
      },
      cpu: {
        user: baselineCpuEnd.user / 1000,
        system: baselineCpuEnd.system / 1000
      },
      timestamp: new Date().toISOString()
    };
  }

  calculateStatistics(measurements) {
    const validMeasurements = measurements.filter(m => !m.error && m.responseTime !== null);
    
    if (validMeasurements.length === 0) {
      return { responseTimes: null, memoryUsage: null, cpuUsage: null };
    }

    const responseTimes = validMeasurements.map(m => m.responseTime);
    const nodeMemoryUsages = validMeasurements
      .filter(m => m.memoryUsage && m.memoryUsage.node)
      .map(m => m.memoryUsage.node.heapUsed / 1024 / 1024); // Convert to MB
    const cpuUsages = validMeasurements
      .filter(m => m.cpuUsage)
      .map(m => m.cpuUsage.user + m.cpuUsage.system);

    return {
      responseTimes: {
        min: Math.min(...responseTimes),
        max: Math.max(...responseTimes),
        avg: responseTimes.reduce((a, b) => a + b, 0) / responseTimes.length,
        p50: this.percentile(responseTimes, 0.5),
        p95: this.percentile(responseTimes, 0.95),
        p99: this.percentile(responseTimes, 0.99)
      },
      memoryUsage: nodeMemoryUsages.length > 0 ? {
        min: Math.min(...nodeMemoryUsages),
        max: Math.max(...nodeMemoryUsages),
        avg: nodeMemoryUsages.reduce((a, b) => a + b, 0) / nodeMemoryUsages.length
      } : null,
      cpuUsage: cpuUsages.length > 0 ? {
        min: Math.min(...cpuUsages),
        max: Math.max(...cpuUsages),
        avg: cpuUsages.reduce((a, b) => a + b, 0) / cpuUsages.length
      } : null
    };
  }

  percentile(values, p) {
    const sorted = [...values].sort((a, b) => a - b);
    const index = Math.ceil(sorted.length * p) - 1;
    return sorted[Math.max(0, index)] || 0;
  }

  async analyzePerformance(testResults) {
    const analysis = {
      critical80: this.analyzeCategory(testResults.critical80, this.thresholds.critical80),
      edge20: this.analyzeCategory(testResults.edge20, this.thresholds.edge20),
      overall: this.analyzeOverall(testResults)
    };

    // Log to database if available
    if (this.db) {
      await this.logAnalysisToDatabase(analysis);
    }

    return analysis;
  }

  analyzeCategory(testResults, thresholds) {
    const analysis = {
      violations: [],
      passedTests: 0,
      totalTests: testResults.length,
      overallPassed: true,
      metrics: {}
    };

    // Aggregate metrics across all tests in category
    const allResponseTimes = [];
    const allErrorRates = [];
    const allTimeoutRates = [];

    testResults.forEach(test => {
      if (test.statistics.responseTimes) {
        allResponseTimes.push(...test.measurements.filter(m => !m.error).map(m => m.responseTime));
      }
      allErrorRates.push(test.errorRate);
      allTimeoutRates.push(test.timeoutRate);

      // Check individual test thresholds
      const testViolations = this.checkTestThresholds(test, thresholds);
      analysis.violations.push(...testViolations);
      
      if (testViolations.length === 0) {
        analysis.passedTests++;
      }
    });

    // Calculate category-wide metrics
    if (allResponseTimes.length > 0) {
      analysis.metrics.responseTimes = {
        p50: this.percentile(allResponseTimes, 0.5),
        p95: this.percentile(allResponseTimes, 0.95),
        p99: this.percentile(allResponseTimes, 0.99)
      };
    }

    analysis.metrics.errorRate = allErrorRates.reduce((a, b) => a + b, 0) / allErrorRates.length;
    analysis.metrics.timeoutRate = allTimeoutRates.reduce((a, b) => a + b, 0) / allTimeoutRates.length;

    // Check category-wide thresholds
    const categoryViolations = this.checkCategoryThresholds(analysis.metrics, thresholds);
    analysis.violations.push(...categoryViolations);

    analysis.overallPassed = analysis.violations.length === 0;
    return analysis;
  }

  checkTestThresholds(test, thresholds) {
    const violations = [];

    if (test.statistics.responseTimes) {
      const rt = test.statistics.responseTimes;
      
      if (rt.p50 > thresholds.responseTime.p50) {
        violations.push({
          test: test.testName,
          metric: 'responseTime.p50',
          value: rt.p50.toFixed(2),
          threshold: thresholds.responseTime.p50,
          severity: 'medium'
        });
      }

      if (rt.p95 > thresholds.responseTime.p95) {
        violations.push({
          test: test.testName,
          metric: 'responseTime.p95',
          value: rt.p95.toFixed(2),
          threshold: thresholds.responseTime.p95,
          severity: 'high'
        });
      }

      if (rt.p99 > thresholds.responseTime.p99) {
        violations.push({
          test: test.testName,
          metric: 'responseTime.p99',
          value: rt.p99.toFixed(2),
          threshold: thresholds.responseTime.p99,
          severity: 'high'
        });
      }
    }

    if (test.errorRate > thresholds.errors.rate) {
      violations.push({
        test: test.testName,
        metric: 'errorRate',
        value: test.errorRate.toFixed(2),
        threshold: thresholds.errors.rate,
        severity: 'high'
      });
    }

    if (test.timeoutRate > thresholds.errors.timeout) {
      violations.push({
        test: test.testName,
        metric: 'timeoutRate',
        value: test.timeoutRate.toFixed(2),
        threshold: thresholds.errors.timeout,
        severity: 'high'
      });
    }

    return violations;
  }

  checkCategoryThresholds(metrics, thresholds) {
    const violations = [];

    if (metrics.responseTimes) {
      if (metrics.responseTimes.p50 > thresholds.responseTime.p50) {
        violations.push({
          test: 'category-aggregate',
          metric: 'category.responseTime.p50',
          value: metrics.responseTimes.p50.toFixed(2),
          threshold: thresholds.responseTime.p50,
          severity: 'medium'
        });
      }

      if (metrics.responseTimes.p95 > thresholds.responseTime.p95) {
        violations.push({
          test: 'category-aggregate',
          metric: 'category.responseTime.p95',
          value: metrics.responseTimes.p95.toFixed(2),
          threshold: thresholds.responseTime.p95,
          severity: 'high'
        });
      }
    }

    if (metrics.errorRate > thresholds.errors.rate) {
      violations.push({
        test: 'category-aggregate',
        metric: 'category.errorRate',
        value: metrics.errorRate.toFixed(2),
        threshold: thresholds.errors.rate,
        severity: 'high'
      });
    }

    return violations;
  }

  analyzeOverall(testResults) {
    const critical80Results = testResults.critical80;
    const edge20Results = testResults.edge20;
    
    const overallAnalysis = {
      totalTests: critical80Results.length + edge20Results.length,
      criticalPassed: critical80Results.filter(t => t.errorCount === 0).length,
      edgePassed: edge20Results.filter(t => t.errorCount === 0).length,
      overallSuccessRate: 0,
      performanceScore: 0
    };

    // Calculate overall success rate
    const totalPassed = overallAnalysis.criticalPassed + overallAnalysis.edgePassed;
    overallAnalysis.overallSuccessRate = (totalPassed / overallAnalysis.totalTests) * 100;

    // Calculate weighted performance score (80/20 weighting)
    const criticalScore = (overallAnalysis.criticalPassed / critical80Results.length) * 100;
    const edgeScore = edge20Results.length > 0 ? (overallAnalysis.edgePassed / edge20Results.length) * 100 : 100;
    overallAnalysis.performanceScore = (criticalScore * 0.8) + (edgeScore * 0.2);

    return overallAnalysis;
  }

  async logAnalysisToDatabase(analysis) {
    try {
      const testRunId = `perf_validation_${Date.now()}`;
      
      // Insert performance validation record
      await this.db`
        INSERT INTO reactor_executions (reactor_id, execution_id, state, started_at, completed_at)
        VALUES ('performance-validation', ${testRunId}, 'completed', NOW(), NOW())
      `;

      // Log metrics
      const executionId = await this.db`
        SELECT id FROM reactor_executions WHERE execution_id = ${testRunId}
      `;

      if (executionId.length > 0) {
        const execId = executionId[0].id;
        
        await this.db`
          INSERT INTO reactor_metrics (execution_id, metric_name, metric_value, metric_unit, metric_tags)
          VALUES
            (${execId}, 'critical_80_passed', ${analysis.critical80.passedTests}, 'count', '{"category": "validation"}'),
            (${execId}, 'edge_20_passed', ${analysis.edge20.passedTests}, 'count', '{"category": "validation"}'),
            (${execId}, 'overall_success_rate', ${analysis.overall.overallSuccessRate}, 'percent', '{"category": "validation"}'),
            (${execId}, 'performance_score', ${analysis.overall.performanceScore}, 'score', '{"category": "validation"}')
        `;
      }
    } catch (error) {
      console.warn('Failed to log analysis to database:', error.message);
    }
  }

  determineOverallStatus(analysis) {
    const critical80Passed = analysis.critical80.overallPassed;
    const edge20Passed = analysis.edge20.overallPassed;
    const performanceScore = analysis.overall.performanceScore;

    return {
      passed: critical80Passed && edge20Passed && performanceScore >= 80,
      score: performanceScore,
      criticalPathStatus: critical80Passed ? 'passed' : 'failed',
      edgeCaseStatus: edge20Passed ? 'passed' : 'failed',
      summary: this.generateStatusSummary(analysis)
    };
  }

  generateStatusSummary(analysis) {
    const summary = [];
    
    if (analysis.critical80.overallPassed) {
      summary.push('✅ Critical 80% performance within thresholds');
    } else {
      summary.push(`❌ Critical 80% performance issues (${analysis.critical80.violations.length} violations)`);
    }

    if (analysis.edge20.overallPassed) {
      summary.push('✅ Edge 20% performance acceptable');
    } else {
      summary.push(`⚠️ Edge 20% performance issues (${analysis.edge20.violations.length} violations)`);
    }

    summary.push(`📊 Overall performance score: ${analysis.overall.performanceScore.toFixed(1)}%`);
    
    return summary;
  }

  generateRecommendations(analysis) {
    const recommendations = [];

    // Critical violations
    const criticalViolations = [
      ...analysis.critical80.violations.filter(v => v.severity === 'high'),
      ...analysis.edge20.violations.filter(v => v.severity === 'high')
    ];

    criticalViolations.forEach(violation => {
      recommendations.push({
        priority: 'high',
        category: 'performance',
        title: `Fix ${violation.metric} in ${violation.test}`,
        description: `${violation.metric} is ${violation.value} (threshold: ${violation.threshold})`,
        action: `Optimize ${violation.test} to reduce ${violation.metric}`,
        impact: 'Critical for system performance'
      });
    });

    // Performance score recommendations
    if (analysis.overall.performanceScore < 90) {
      recommendations.push({
        priority: 'medium',
        category: 'optimization',
        title: 'Improve overall performance score',
        description: `Current score: ${analysis.overall.performanceScore.toFixed(1)}% (target: 90%+)`,
        action: 'Focus on critical path optimization and error reduction',
        impact: 'Improves user experience and system efficiency'
      });
    }

    return recommendations.sort((a, b) => {
      const priorityOrder = { high: 1, medium: 2, low: 3 };
      return priorityOrder[a.priority] - priorityOrder[b.priority];
    });
  }

  async saveReport(report) {
    if (!fs.existsSync(this.reportsDir)) {
      fs.mkdirSync(this.reportsDir, { recursive: true });
    }
    
    fs.writeFileSync(this.outputFile, JSON.stringify(report, null, 2));
  }

  displayResults(report) {
    console.log(chalk.bold('\n⚡ Performance Threshold Validation Results'));
    console.log('━'.repeat(60));
    
    // Overall status
    const statusColor = report.overallStatus.passed ? chalk.green : chalk.red;
    console.log(statusColor(`Overall Status: ${report.overallStatus.passed ? 'PASSED' : 'FAILED'}`));
    console.log(chalk.blue(`Performance Score: ${report.overallStatus.score.toFixed(1)}%`));
    
    // Summary
    console.log(chalk.bold('\n📋 Summary:'));
    report.overallStatus.summary.forEach(item => {
      console.log(`  ${item}`);
    });

    // Critical 80% results
    console.log(chalk.bold('\n🔴 Critical 80% Performance:'));
    console.log(`  Tests Passed: ${report.analysis.critical80.passedTests}/${report.analysis.critical80.totalTests}`);
    console.log(`  Violations: ${report.analysis.critical80.violations.length}`);
    if (report.analysis.critical80.metrics.responseTimes) {
      const rt = report.analysis.critical80.metrics.responseTimes;
      console.log(`  Response Times: P50=${rt.p50.toFixed(1)}ms, P95=${rt.p95.toFixed(1)}ms, P99=${rt.p99.toFixed(1)}ms`);
    }

    // Edge 20% results
    console.log(chalk.bold('\n🟡 Edge 20% Performance:'));
    console.log(`  Tests Passed: ${report.analysis.edge20.passedTests}/${report.analysis.edge20.totalTests}`);
    console.log(`  Violations: ${report.analysis.edge20.violations.length}`);
    if (report.analysis.edge20.metrics.responseTimes) {
      const rt = report.analysis.edge20.metrics.responseTimes;
      console.log(`  Response Times: P50=${rt.p50.toFixed(1)}ms, P95=${rt.p95.toFixed(1)}ms, P99=${rt.p99.toFixed(1)}ms`);
    }

    // Violations table
    const allViolations = [
      ...report.analysis.critical80.violations.map(v => ({ ...v, category: 'Critical 80%' })),
      ...report.analysis.edge20.violations.map(v => ({ ...v, category: 'Edge 20%' }))
    ];

    if (allViolations.length > 0) {
      console.log(chalk.bold('\n🚨 Performance Violations:'));
      const violationData = allViolations.slice(0, 10).map(v => [
        v.category,
        v.test,
        v.metric,
        v.value,
        v.threshold.toString(),
        v.severity
      ]);
      
      const violationTable = table([
        ['Category', 'Test', 'Metric', 'Value', 'Threshold', 'Severity'],
        ...violationData
      ]);
      console.log(violationTable);
      
      if (allViolations.length > 10) {
        console.log(chalk.dim(`... and ${allViolations.length - 10} more violations`));
      }
    }

    // Recommendations
    if (report.recommendations.length > 0) {
      console.log(chalk.bold('\n🎯 Top Recommendations:'));
      report.recommendations.slice(0, 5).forEach((rec, index) => {
        const priorityColor = rec.priority === 'high' ? chalk.red : 
                             rec.priority === 'medium' ? chalk.yellow : chalk.green;
        console.log(priorityColor(`${index + 1}. [${rec.priority.toUpperCase()}] ${rec.title}`));
        console.log(chalk.gray(`   ${rec.description}`));
      });
    }

    console.log(chalk.dim(`\nDetailed report: ${this.outputFile}`));
  }
}

// Run validation if called directly
if (require.main === module) {
  const validator = new PerformanceThresholdValidator();
  validator.validate()
    .then(exitCode => process.exit(exitCode))
    .catch(error => {
      console.error(chalk.red('Performance validation failed:'), error);
      process.exit(1);
    });
}

module.exports = PerformanceThresholdValidator;