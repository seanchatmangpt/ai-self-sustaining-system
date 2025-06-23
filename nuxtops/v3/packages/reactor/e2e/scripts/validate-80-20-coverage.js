#!/usr/bin/env node

/**
 * 80/20 Coverage Validation Script
 * Validates that test coverage meets 80/20 principles and performance thresholds
 */

const fs = require('fs');
const path = require('path');
const postgres = require('postgres');
const chalk = require('chalk');
const ora = require('ora');
const { table } = require('table');

class Coverage8020Validator {
  constructor() {
    this.reportsDir = path.join(__dirname, '..', 'reports');
    this.outputFile = path.join(this.reportsDir, '80-20-validation-report.json');
    
    // 80/20 validation thresholds
    this.thresholds = {
      critical80: {
        minSuccessRate: 95,      // 95% success rate for critical paths
        maxAvgResponseTime: 100,  // 100ms average response time
        maxP95ResponseTime: 200,  // 200ms P95 response time
        maxMemoryUsage: 50,       // 50MB memory usage
        minThroughput: 100,       // 100 ops/sec throughput
        maxErrorRate: 1           // 1% error rate
      },
      edge20: {
        minSuccessRate: 70,       // 70% success rate for edge cases
        maxAvgResponseTime: 1000, // 1000ms average response time
        maxP95ResponseTime: 5000, // 5000ms P95 response time
        maxMemoryUsage: 200,      // 200MB memory usage
        minThroughput: 10,        // 10 ops/sec throughput
        maxErrorRate: 15          // 15% error rate
      },
      overall: {
        min8020Score: 80,         // Minimum 80% overall score
        minTestCoverage: 80,      // 80% test coverage
        maxFailedCritical: 2,     // Max 2 failed critical tests
        maxFailedEdge: 5          // Max 5 failed edge tests
      }
    };

    this.db = null;
  }

  async validate() {
    const spinner = ora('Validating 80/20 coverage compliance...').start();
    
    try {
      // Initialize database connection
      await this.initializeDatabase();
      
      // Load test results and metrics
      const data = await this.loadTestData();
      
      // Perform validation checks
      const validation = await this.performValidation(data);
      
      // Generate detailed report
      const report = {
        timestamp: new Date().toISOString(),
        overallCompliance: validation.overallCompliance,
        criticalPathValidation: validation.critical80,
        edgeCaseValidation: validation.edge20,
        detailedResults: validation.detailed,
        recommendations: validation.recommendations,
        thresholds: this.thresholds
      };
      
      // Save validation report
      await this.saveReport(report);
      
      // Display results
      spinner.succeed('80/20 coverage validation completed');
      this.displayResults(report);
      
      // Return exit code based on compliance
      return report.overallCompliance.passed ? 0 : 1;
      
    } catch (error) {
      spinner.fail(`Validation failed: ${error.message}`);
      throw error;
    } finally {
      if (this.db) {
        await this.db.end();
      }
    }
  }

  async initializeDatabase() {
    this.db = postgres({
      host: 'localhost',
      port: 5432,
      database: 'reactor_e2e',
      username: 'reactor_user',
      password: 'reactor_pass'
    });
  }

  async loadTestData() {
    const data = {
      testExecutions: [],
      reactorExecutions: [],
      metrics: [],
      scenarios: []
    };

    try {
      // Load test execution data
      data.testExecutions = await this.db`
        SELECT 
          te.*,
          ts.scenario_name,
          ts.coverage_category,
          ts.priority,
          ts.expected_outcome
        FROM test_executions te
        JOIN test_scenarios ts ON te.scenario_id = ts.id
        WHERE te.started_at >= NOW() - INTERVAL '24 hours'
        ORDER BY te.started_at DESC
      `;

      // Load reactor execution data
      data.reactorExecutions = await this.db`
        SELECT *
        FROM reactor_executions
        WHERE started_at >= NOW() - INTERVAL '24 hours'
        ORDER BY started_at DESC
      `;

      // Load performance metrics
      data.metrics = await this.db`
        SELECT 
          rm.*,
          re.reactor_id,
          re.state as execution_state
        FROM reactor_metrics rm
        JOIN reactor_executions re ON rm.execution_id = re.id
        WHERE rm.measured_at >= NOW() - INTERVAL '24 hours'
        ORDER BY rm.measured_at DESC
      `;

      // Load test scenarios
      data.scenarios = await this.db`
        SELECT *
        FROM test_scenarios
        ORDER BY coverage_category, priority
      `;

    } catch (error) {
      console.warn('Database query failed, using file-based fallback:', error.message);
      // Fallback to file-based data if database is unavailable
      data = await this.loadFileBasedData();
    }

    return data;
  }

  async loadFileBasedData() {
    const data = { testExecutions: [], reactorExecutions: [], metrics: [], scenarios: [] };
    
    // Try to load from report files
    const reportFiles = [
      'results.json',
      '80-20-coverage-report.json',
      'performance-profile.json'
    ];

    for (const file of reportFiles) {
      const filePath = path.join(this.reportsDir, file);
      if (fs.existsSync(filePath)) {
        try {
          const fileData = JSON.parse(fs.readFileSync(filePath, 'utf8'));
          // Parse and merge data based on file type
          this.mergeFileData(data, fileData, file);
        } catch (error) {
          console.warn(`Failed to load ${file}:`, error.message);
        }
      }
    }

    return data;
  }

  mergeFileData(data, fileData, fileName) {
    if (fileName === 'results.json' && fileData.suites) {
      // Parse Playwright results
      this.parsePlaywrightResults(data, fileData);
    } else if (fileName === '80-20-coverage-report.json') {
      // Parse coverage report
      this.parseCoverageReport(data, fileData);
    } else if (fileName === 'performance-profile.json') {
      // Parse performance profile
      this.parsePerformanceProfile(data, fileData);
    }
  }

  parsePlaywrightResults(data, playwrightData) {
    if (playwrightData.suites) {
      playwrightData.suites.forEach(suite => {
        this.extractTestExecutions(suite, data.testExecutions);
      });
    }
  }

  extractTestExecutions(suite, executions) {
    if (suite.specs) {
      suite.specs.forEach(spec => {
        spec.tests.forEach(test => {
          if (test.results && test.results[0]) {
            const result = test.results[0];
            executions.push({
              scenario_name: test.title,
              coverage_category: this.categorizeTest(test.title),
              status: result.status === 'passed' ? 'passed' : 'failed',
              execution_time_ms: result.duration || 0,
              memory_usage_mb: 0, // Not available from Playwright results
              performance_score: result.status === 'passed' ? 100 : 0,
              started_at: new Date().toISOString(),
              completed_at: new Date().toISOString()
            });
          }
        });
      });
    }

    if (suite.suites) {
      suite.suites.forEach(childSuite => {
        this.extractTestExecutions(childSuite, executions);
      });
    }
  }

  categorizeTest(title) {
    const lowerTitle = title.toLowerCase();
    if (lowerTitle.includes('critical') || lowerTitle.includes('basic') || lowerTitle.includes('core')) {
      return 'critical_80';
    }
    return 'edge_20';
  }

  async performValidation(data) {
    const validation = {
      critical80: await this.validateCritical80(data),
      edge20: await this.validateEdge20(data),
      overall: await this.validateOverall(data),
      detailed: {},
      recommendations: []
    };

    // Determine overall compliance
    validation.overallCompliance = {
      passed: validation.critical80.passed && validation.edge20.passed && validation.overall.passed,
      score: this.calculateOverallScore(validation),
      summary: this.generateComplianceSummary(validation)
    };

    // Generate recommendations
    validation.recommendations = this.generateRecommendations(validation);

    return validation;
  }

  async validateCritical80(data) {
    const critical80Data = data.testExecutions.filter(te => te.coverage_category === 'critical_80');
    const thresholds = this.thresholds.critical80;
    
    const validation = {
      totalTests: critical80Data.length,
      passedTests: critical80Data.filter(te => te.status === 'passed').length,
      failedTests: critical80Data.filter(te => te.status === 'failed').length,
      violations: [],
      metrics: {},
      passed: true
    };

    // Calculate success rate
    validation.successRate = validation.totalTests > 0 ? 
      (validation.passedTests / validation.totalTests) * 100 : 0;

    // Calculate performance metrics
    const passedTests = critical80Data.filter(te => te.status === 'passed');
    if (passedTests.length > 0) {
      const responseTimes = passedTests.map(te => te.execution_time_ms || 0);
      const memoryUsages = passedTests.map(te => te.memory_usage_mb || 0);

      validation.metrics = {
        avgResponseTime: responseTimes.reduce((a, b) => a + b, 0) / responseTimes.length,
        p95ResponseTime: this.percentile(responseTimes, 0.95),
        avgMemoryUsage: memoryUsages.reduce((a, b) => a + b, 0) / memoryUsages.length,
        errorRate: (validation.failedTests / validation.totalTests) * 100
      };

      // Check thresholds
      this.checkThreshold(validation, 'successRate', validation.successRate, thresholds.minSuccessRate, '>=');
      this.checkThreshold(validation, 'avgResponseTime', validation.metrics.avgResponseTime, thresholds.maxAvgResponseTime, '<=');
      this.checkThreshold(validation, 'p95ResponseTime', validation.metrics.p95ResponseTime, thresholds.maxP95ResponseTime, '<=');
      this.checkThreshold(validation, 'avgMemoryUsage', validation.metrics.avgMemoryUsage, thresholds.maxMemoryUsage, '<=');
      this.checkThreshold(validation, 'errorRate', validation.metrics.errorRate, thresholds.maxErrorRate, '<=');
    }

    validation.passed = validation.violations.length === 0;
    return validation;
  }

  async validateEdge20(data) {
    const edge20Data = data.testExecutions.filter(te => te.coverage_category === 'edge_20');
    const thresholds = this.thresholds.edge20;
    
    const validation = {
      totalTests: edge20Data.length,
      passedTests: edge20Data.filter(te => te.status === 'passed').length,
      failedTests: edge20Data.filter(te => te.status === 'failed').length,
      violations: [],
      metrics: {},
      passed: true
    };

    // Calculate success rate
    validation.successRate = validation.totalTests > 0 ? 
      (validation.passedTests / validation.totalTests) * 100 : 0;

    // Calculate performance metrics for edge cases
    const passedTests = edge20Data.filter(te => te.status === 'passed');
    if (passedTests.length > 0) {
      const responseTimes = passedTests.map(te => te.execution_time_ms || 0);
      const memoryUsages = passedTests.map(te => te.memory_usage_mb || 0);

      validation.metrics = {
        avgResponseTime: responseTimes.reduce((a, b) => a + b, 0) / responseTimes.length,
        p95ResponseTime: this.percentile(responseTimes, 0.95),
        avgMemoryUsage: memoryUsages.reduce((a, b) => a + b, 0) / memoryUsages.length,
        errorRate: (validation.failedTests / validation.totalTests) * 100
      };

      // Check thresholds (more lenient for edge cases)
      this.checkThreshold(validation, 'successRate', validation.successRate, thresholds.minSuccessRate, '>=');
      this.checkThreshold(validation, 'avgResponseTime', validation.metrics.avgResponseTime, thresholds.maxAvgResponseTime, '<=');
      this.checkThreshold(validation, 'p95ResponseTime', validation.metrics.p95ResponseTime, thresholds.maxP95ResponseTime, '<=');
      this.checkThreshold(validation, 'avgMemoryUsage', validation.metrics.avgMemoryUsage, thresholds.maxMemoryUsage, '<=');
      this.checkThreshold(validation, 'errorRate', validation.metrics.errorRate, thresholds.maxErrorRate, '<=');
    }

    validation.passed = validation.violations.length === 0;
    return validation;
  }

  async validateOverall(data) {
    const thresholds = this.thresholds.overall;
    const allTests = data.testExecutions;
    
    const validation = {
      violations: [],
      metrics: {},
      passed: true
    };

    // Calculate overall 80/20 score
    const critical80Tests = allTests.filter(te => te.coverage_category === 'critical_80');
    const edge20Tests = allTests.filter(te => te.coverage_category === 'edge_20');
    
    const critical80Success = critical80Tests.length > 0 ? 
      (critical80Tests.filter(te => te.status === 'passed').length / critical80Tests.length) : 0;
    const edge20Success = edge20Tests.length > 0 ?
      (edge20Tests.filter(te => te.status === 'passed').length / edge20Tests.length) : 0;
    
    // Weighted 80/20 score
    const overallScore = (critical80Success * 0.8) + (edge20Success * 0.2);
    validation.metrics.overallScore = overallScore * 100;

    // Test coverage metrics
    validation.metrics.totalTests = allTests.length;
    validation.metrics.critical80Count = critical80Tests.length;
    validation.metrics.edge20Count = edge20Tests.length;
    validation.metrics.failedCritical = critical80Tests.filter(te => te.status === 'failed').length;
    validation.metrics.failedEdge = edge20Tests.filter(te => te.status === 'failed').length;

    // Check overall thresholds
    this.checkThreshold(validation, 'overallScore', validation.metrics.overallScore, thresholds.min8020Score, '>=');
    this.checkThreshold(validation, 'failedCritical', validation.metrics.failedCritical, thresholds.maxFailedCritical, '<=');
    this.checkThreshold(validation, 'failedEdge', validation.metrics.failedEdge, thresholds.maxFailedEdge, '<=');

    validation.passed = validation.violations.length === 0;
    return validation;
  }

  checkThreshold(validation, metric, value, threshold, operator) {
    let violated = false;
    
    if (operator === '>=' && value < threshold) {
      violated = true;
    } else if (operator === '<=' && value > threshold) {
      violated = true;
    }

    if (violated) {
      validation.violations.push({
        metric,
        value: Number(value).toFixed(2),
        threshold,
        operator,
        severity: this.getViolationSeverity(metric, value, threshold)
      });
    }
  }

  getViolationSeverity(metric, value, threshold) {
    // Determine severity based on how far off the threshold we are
    const criticalMetrics = ['successRate', 'overallScore', 'failedCritical'];
    
    if (criticalMetrics.includes(metric)) {
      return 'high';
    }
    
    const deviation = Math.abs((value - threshold) / threshold);
    if (deviation > 0.5) return 'high';
    if (deviation > 0.2) return 'medium';
    return 'low';
  }

  percentile(values, p) {
    const sorted = [...values].sort((a, b) => a - b);
    const index = Math.ceil(sorted.length * p) - 1;
    return sorted[Math.max(0, index)] || 0;
  }

  calculateOverallScore(validation) {
    const weights = {
      critical80: 0.6,
      edge20: 0.2,
      overall: 0.2
    };

    let score = 0;
    if (validation.critical80.passed) score += weights.critical80 * 100;
    if (validation.edge20.passed) score += weights.edge20 * 100;
    if (validation.overall.passed) score += weights.overall * 100;

    return Math.round(score);
  }

  generateComplianceSummary(validation) {
    const summary = [];
    
    if (validation.critical80.passed) {
      summary.push('✅ Critical 80% paths meet thresholds');
    } else {
      summary.push(`❌ Critical 80% paths failed (${validation.critical80.violations.length} violations)`);
    }

    if (validation.edge20.passed) {
      summary.push('✅ Edge 20% cases within acceptable limits');
    } else {
      summary.push(`⚠️ Edge 20% cases exceeded limits (${validation.edge20.violations.length} violations)`);
    }

    if (validation.overall.passed) {
      summary.push('✅ Overall 80/20 score meets requirements');
    } else {
      summary.push(`❌ Overall 80/20 score below threshold (${validation.overall.violations.length} violations)`);
    }

    return summary;
  }

  generateRecommendations(validation) {
    const recommendations = [];

    // Critical path recommendations
    validation.critical80.violations.forEach(violation => {
      if (violation.severity === 'high') {
        recommendations.push({
          priority: 'high',
          category: 'critical-path',
          title: `Fix critical ${violation.metric}`,
          description: `${violation.metric} is ${violation.value} (${violation.operator} ${violation.threshold} required)`,
          action: `Optimize critical path performance to improve ${violation.metric}`,
          impact: 'Essential for production readiness'
        });
      }
    });

    // Edge case recommendations
    validation.edge20.violations.forEach(violation => {
      if (violation.severity === 'high' || violation.severity === 'medium') {
        recommendations.push({
          priority: violation.severity === 'high' ? 'high' : 'medium',
          category: 'edge-case',
          title: `Improve edge case ${violation.metric}`,
          description: `Edge case ${violation.metric} is ${violation.value} (${violation.operator} ${violation.threshold} recommended)`,
          action: `Review edge case handling to improve ${violation.metric}`,
          impact: 'Improves system resilience'
        });
      }
    });

    // Overall recommendations
    if (validation.overall.metrics.overallScore < 90) {
      recommendations.push({
        priority: 'medium',
        category: 'overall',
        title: 'Improve overall 80/20 coverage',
        description: `Overall score is ${validation.overall.metrics.overallScore}% (target: 90%+)`,
        action: 'Focus on critical path optimization and edge case stability',
        impact: 'Ensures comprehensive system validation'
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
    console.log(chalk.bold('\n🎯 80/20 Coverage Validation Results'));
    console.log('━'.repeat(60));
    
    // Overall compliance
    const complianceColor = report.overallCompliance.passed ? chalk.green : chalk.red;
    console.log(complianceColor(`Overall Compliance: ${report.overallCompliance.passed ? 'PASSED' : 'FAILED'}`));
    console.log(chalk.blue(`Compliance Score: ${report.overallCompliance.score}%`));
    
    // Summary
    console.log(chalk.bold('\n📋 Summary:'));
    report.overallCompliance.summary.forEach(item => {
      console.log(`  ${item}`);
    });

    // Critical 80% results
    console.log(chalk.bold('\n🔴 Critical 80% Validation:'));
    this.displayCategoryResults(report.criticalPathValidation);

    // Edge 20% results
    console.log(chalk.bold('\n🟡 Edge 20% Validation:'));
    this.displayCategoryResults(report.edgeCaseValidation);

    // Violations table
    const allViolations = [
      ...report.criticalPathValidation.violations.map(v => ({ ...v, category: 'Critical 80%' })),
      ...report.edgeCaseValidation.violations.map(v => ({ ...v, category: 'Edge 20%' })),
      ...report.overallCompliance.violations?.map(v => ({ ...v, category: 'Overall' })) || []
    ];

    if (allViolations.length > 0) {
      console.log(chalk.bold('\n🚨 Threshold Violations:'));
      const violationData = allViolations.map(v => [
        v.category,
        v.metric,
        v.value,
        `${v.operator} ${v.threshold}`,
        v.severity
      ]);
      
      const violationTable = table([
        ['Category', 'Metric', 'Value', 'Threshold', 'Severity'],
        ...violationData
      ]);
      console.log(violationTable);
    }

    // Top recommendations
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

  displayCategoryResults(results) {
    const statusColor = results.passed ? chalk.green : chalk.red;
    console.log(statusColor(`  Status: ${results.passed ? 'PASSED' : 'FAILED'}`));
    console.log(chalk.blue(`  Tests: ${results.passedTests}/${results.totalTests} passed (${results.successRate?.toFixed(1)}%)`));
    
    if (results.metrics && Object.keys(results.metrics).length > 0) {
      console.log(chalk.blue(`  Avg Response Time: ${results.metrics.avgResponseTime?.toFixed(2)}ms`));
      console.log(chalk.blue(`  P95 Response Time: ${results.metrics.p95ResponseTime?.toFixed(2)}ms`));
      console.log(chalk.blue(`  Avg Memory Usage: ${results.metrics.avgMemoryUsage?.toFixed(2)}MB`));
      console.log(chalk.blue(`  Error Rate: ${results.metrics.errorRate?.toFixed(2)}%`));
    }
    
    if (results.violations.length > 0) {
      console.log(chalk.red(`  Violations: ${results.violations.length}`));
    }
  }
}

// Run validation if called directly
if (require.main === module) {
  const validator = new Coverage8020Validator();
  validator.validate()
    .then(exitCode => process.exit(exitCode))
    .catch(error => {
      console.error(chalk.red('Validation failed:'), error);
      process.exit(1);
    });
}

module.exports = Coverage8020Validator;