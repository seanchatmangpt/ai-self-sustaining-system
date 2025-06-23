#!/usr/bin/env node

/**
 * 80/20 Coverage Analysis Script
 * Analyzes test results to identify critical paths and performance bottlenecks
 * Following the Pareto Principle: 80% of effects come from 20% of causes
 */

const fs = require('fs');
const path = require('path');
const { createObjectCsvWriter } = require('csv-writer');
const chalk = require('chalk');
const ora = require('ora');

class Coverage8020Analyzer {
  constructor() {
    this.reportsDir = path.join(__dirname, '..', 'reports');
    this.resultsFile = path.join(this.reportsDir, 'results.json');
    this.coverageFile = path.join(this.reportsDir, '80-20-coverage-report.json');
    this.outputFile = path.join(this.reportsDir, '80-20-analysis.json');
    this.csvFile = path.join(this.reportsDir, '80-20-analysis.csv');
  }

  async analyze() {
    const spinner = ora('Analyzing 80/20 coverage patterns...').start();
    
    try {
      // Load test results
      const results = await this.loadTestResults();
      
      // Perform 80/20 analysis
      const analysis = await this.perform8020Analysis(results);
      
      // Generate recommendations
      const recommendations = this.generateRecommendations(analysis);
      
      // Create final report
      const report = {
        timestamp: new Date().toISOString(),
        summary: analysis.summary,
        criticalPaths: analysis.criticalPaths,
        performanceBottlenecks: analysis.performanceBottlenecks,
        recommendations: recommendations,
        detailed: analysis.detailed
      };
      
      // Save results
      await this.saveReport(report);
      await this.generateCsvReport(report);
      
      spinner.succeed('80/20 coverage analysis completed');
      this.printSummary(report);
      
      return report;
      
    } catch (error) {
      spinner.fail(`Analysis failed: ${error.message}`);
      throw error;
    }
  }

  async loadTestResults() {
    const results = { playwright: null, coverage: null };
    
    // Load Playwright results
    if (fs.existsSync(this.resultsFile)) {
      results.playwright = JSON.parse(fs.readFileSync(this.resultsFile, 'utf8'));
    }
    
    // Load coverage data
    if (fs.existsSync(this.coverageFile)) {
      results.coverage = JSON.parse(fs.readFileSync(this.coverageFile, 'utf8'));
    }
    
    return results;
  }

  async perform8020Analysis(results) {
    const analysis = {
      summary: {},
      criticalPaths: [],
      performanceBottlenecks: [],
      detailed: {}
    };

    // Analyze Playwright test results
    if (results.playwright) {
      analysis.detailed.playwright = this.analyzePlaywrightResults(results.playwright);
    }

    // Analyze coverage data
    if (results.coverage) {
      analysis.detailed.coverage = this.analyzeCoverageData(results.coverage);
    }

    // Identify critical paths (20% of code handling 80% of functionality)
    analysis.criticalPaths = this.identifyCriticalPaths(analysis.detailed);

    // Find performance bottlenecks
    analysis.performanceBottlenecks = this.identifyPerformanceBottlenecks(analysis.detailed);

    // Generate summary
    analysis.summary = this.generateSummary(analysis);

    return analysis;
  }

  analyzePlaywrightResults(playwrightData) {
    const analysis = {
      totalTests: 0,
      passed: 0,
      failed: 0,
      duration: 0,
      byCategory: {
        'critical-80': { tests: 0, passed: 0, avgDuration: 0, failures: [] },
        'edge-20': { tests: 0, passed: 0, avgDuration: 0, failures: [] }
      }
    };

    if (playwrightData.suites) {
      playwrightData.suites.forEach(suite => {
        this.analyzeSuite(suite, analysis);
      });
    }

    // Calculate percentages and averages
    Object.keys(analysis.byCategory).forEach(category => {
      const cat = analysis.byCategory[category];
      if (cat.tests > 0) {
        cat.successRate = (cat.passed / cat.tests) * 100;
        cat.avgDuration = cat.avgDuration / cat.tests;
      }
    });

    return analysis;
  }

  analyzeSuite(suite, analysis) {
    if (suite.specs) {
      suite.specs.forEach(spec => {
        spec.tests.forEach(test => {
          analysis.totalTests++;
          
          // Determine category from test title or metadata
          const category = this.categorizeTest(test);
          const categoryData = analysis.byCategory[category] || analysis.byCategory['critical-80'];
          
          categoryData.tests++;
          
          if (test.results && test.results[0]) {
            const result = test.results[0];
            analysis.duration += result.duration || 0;
            categoryData.avgDuration += result.duration || 0;
            
            if (result.status === 'passed') {
              analysis.passed++;
              categoryData.passed++;
            } else {
              analysis.failed++;
              categoryData.failures.push({
                title: test.title,
                error: result.error?.message || 'Unknown error',
                duration: result.duration || 0
              });
            }
          }
        });
      });
    }

    if (suite.suites) {
      suite.suites.forEach(childSuite => {
        this.analyzeSuite(childSuite, analysis);
      });
    }
  }

  categorizeTest(test) {
    const title = test.title.toLowerCase();
    
    // Critical 80% patterns
    const criticalPatterns = [
      'basic', 'core', 'essential', 'critical', 'primary',
      'input-output', 'workflow', 'process', 'api'
    ];
    
    // Edge 20% patterns
    const edgePatterns = [
      'stress', 'edge', 'failure', 'timeout', 'memory',
      'concurrency', 'cascade', 'exhaustion', 'compatibility'
    ];
    
    if (edgePatterns.some(pattern => title.includes(pattern))) {
      return 'edge-20';
    }
    
    if (criticalPatterns.some(pattern => title.includes(pattern))) {
      return 'critical-80';
    }
    
    // Default to critical if unclear
    return 'critical-80';
  }

  analyzeCoverageData(coverageData) {
    const analysis = {
      overallScore: coverageData.overallScore || 0,
      threshold: coverageData.threshold || 80,
      passed: coverageData.passed || false,
      scenarios: {
        critical80: [],
        edge20: []
      }
    };

    if (coverageData.coverageData) {
      coverageData.coverageData.forEach(scenario => {
        const scenarioAnalysis = {
          name: scenario.scenario_name,
          category: scenario.coverage_category,
          priority: scenario.priority,
          totalRuns: scenario.total_runs || 0,
          passedRuns: scenario.passed_runs || 0,
          successRate: scenario.success_rate || 0,
          avgExecutionTime: scenario.avg_execution_time || 0,
          avgMemoryUsage: scenario.avg_memory_usage || 0,
          performanceScore: scenario.avg_performance_score || 0
        };

        if (scenario.coverage_category === 'critical_80') {
          analysis.scenarios.critical80.push(scenarioAnalysis);
        } else {
          analysis.scenarios.edge20.push(scenarioAnalysis);
        }
      });
    }

    return analysis;
  }

  identifyCriticalPaths(detailed) {
    const criticalPaths = [];

    // From Playwright data
    if (detailed.playwright && detailed.playwright.byCategory['critical-80']) {
      const critical = detailed.playwright.byCategory['critical-80'];
      if (critical.successRate < 90) {
        criticalPaths.push({
          type: 'functional',
          path: 'Critical E2E Tests',
          issue: `Success rate ${critical.successRate.toFixed(1)}% below 90% threshold`,
          impact: 'high',
          priority: 1,
          failures: critical.failures
        });
      }
    }

    // From coverage data
    if (detailed.coverage && detailed.coverage.scenarios.critical80) {
      detailed.coverage.scenarios.critical80.forEach(scenario => {
        if (scenario.successRate < 80) {
          criticalPaths.push({
            type: 'scenario',
            path: scenario.name,
            issue: `Success rate ${scenario.successRate}% below 80% threshold`,
            impact: scenario.priority === 'high' ? 'high' : 'medium',
            priority: scenario.priority === 'high' ? 1 : 2,
            metrics: {
              successRate: scenario.successRate,
              avgExecutionTime: scenario.avgExecutionTime,
              avgMemoryUsage: scenario.avgMemoryUsage
            }
          });
        }
      });
    }

    return criticalPaths.sort((a, b) => a.priority - b.priority);
  }

  identifyPerformanceBottlenecks(detailed) {
    const bottlenecks = [];

    // Performance thresholds
    const thresholds = {
      maxAvgDuration: 1000, // 1 second
      maxMemoryUsage: 100,  // 100 MB
      minSuccessRate: 80    // 80%
    };

    // Analyze from coverage scenarios
    if (detailed.coverage && detailed.coverage.scenarios) {
      [...detailed.coverage.scenarios.critical80, ...detailed.coverage.scenarios.edge20]
        .forEach(scenario => {
          if (scenario.avgExecutionTime > thresholds.maxAvgDuration) {
            bottlenecks.push({
              type: 'latency',
              component: scenario.name,
              metric: 'avgExecutionTime',
              value: scenario.avgExecutionTime,
              threshold: thresholds.maxAvgDuration,
              severity: scenario.avgExecutionTime > thresholds.maxAvgDuration * 2 ? 'high' : 'medium'
            });
          }

          if (scenario.avgMemoryUsage > thresholds.maxMemoryUsage) {
            bottlenecks.push({
              type: 'memory',
              component: scenario.name,
              metric: 'avgMemoryUsage',
              value: scenario.avgMemoryUsage,
              threshold: thresholds.maxMemoryUsage,
              severity: scenario.avgMemoryUsage > thresholds.maxMemoryUsage * 2 ? 'high' : 'medium'
            });
          }
        });
    }

    return bottlenecks.sort((a, b) => {
      const severityOrder = { high: 1, medium: 2, low: 3 };
      return severityOrder[a.severity] - severityOrder[b.severity];
    });
  }

  generateSummary(analysis) {
    const summary = {
      overallScore: 0,
      criticalPathHealth: 'unknown',
      performanceHealth: 'unknown',
      recommendations: 0,
      testCoverage: {
        total: 0,
        critical80: 0,
        edge20: 0,
        successRate: 0
      }
    };

    // Calculate overall score
    if (analysis.detailed.coverage) {
      summary.overallScore = analysis.detailed.coverage.overallScore;
    }

    // Test coverage summary
    if (analysis.detailed.playwright) {
      const p = analysis.detailed.playwright;
      summary.testCoverage.total = p.totalTests;
      summary.testCoverage.critical80 = p.byCategory['critical-80']?.tests || 0;
      summary.testCoverage.edge20 = p.byCategory['edge-20']?.tests || 0;
      summary.testCoverage.successRate = p.totalTests > 0 ? (p.passed / p.totalTests) * 100 : 0;
    }

    // Health assessments
    summary.criticalPathHealth = analysis.criticalPaths.length === 0 ? 'healthy' : 
                                analysis.criticalPaths.filter(p => p.impact === 'high').length > 0 ? 'critical' : 'warning';

    summary.performanceHealth = analysis.performanceBottlenecks.length === 0 ? 'healthy' :
                               analysis.performanceBottlenecks.filter(b => b.severity === 'high').length > 0 ? 'critical' : 'warning';

    return summary;
  }

  generateRecommendations(analysis) {
    const recommendations = [];

    // Critical path recommendations
    analysis.criticalPaths.forEach(path => {
      if (path.impact === 'high') {
        recommendations.push({
          priority: 'high',
          category: 'reliability',
          title: `Fix critical path: ${path.path}`,
          description: path.issue,
          action: 'Investigate and fix failing critical tests immediately',
          impact: 'Prevents production failures'
        });
      }
    });

    // Performance recommendations
    analysis.performanceBottlenecks.forEach(bottleneck => {
      if (bottleneck.severity === 'high') {
        recommendations.push({
          priority: 'high',
          category: 'performance',
          title: `Optimize ${bottleneck.type}: ${bottleneck.component}`,
          description: `${bottleneck.metric} is ${bottleneck.value} (threshold: ${bottleneck.threshold})`,
          action: `Optimize ${bottleneck.component} to reduce ${bottleneck.type}`,
          impact: 'Improves user experience and system efficiency'
        });
      }
    });

    // 80/20 coverage recommendations
    if (analysis.summary.overallScore < 80) {
      recommendations.push({
        priority: 'medium',
        category: 'coverage',
        title: 'Improve 80/20 coverage score',
        description: `Current score: ${analysis.summary.overallScore}% (target: 80%+)`,
        action: 'Focus on critical path test scenarios and reduce edge case failures',
        impact: 'Ensures core functionality is properly validated'
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

  async generateCsvReport(report) {
    const csvData = [];

    // Add critical paths
    report.criticalPaths.forEach(path => {
      csvData.push({
        type: 'critical_path',
        component: path.path,
        issue: path.issue,
        impact: path.impact,
        priority: path.priority,
        category: path.type,
        value: '',
        threshold: '',
        recommendation: `Fix ${path.type} issues in ${path.path}`
      });
    });

    // Add performance bottlenecks
    report.performanceBottlenecks.forEach(bottleneck => {
      csvData.push({
        type: 'performance_bottleneck',
        component: bottleneck.component,
        issue: `${bottleneck.metric} exceeds threshold`,
        impact: bottleneck.severity,
        priority: bottleneck.severity === 'high' ? 1 : 2,
        category: bottleneck.type,
        value: bottleneck.value,
        threshold: bottleneck.threshold,
        recommendation: `Optimize ${bottleneck.component} ${bottleneck.type}`
      });
    });

    const csvWriter = createObjectCsvWriter({
      path: this.csvFile,
      header: [
        { id: 'type', title: 'Type' },
        { id: 'component', title: 'Component' },
        { id: 'issue', title: 'Issue' },
        { id: 'impact', title: 'Impact' },
        { id: 'priority', title: 'Priority' },
        { id: 'category', title: 'Category' },
        { id: 'value', title: 'Value' },
        { id: 'threshold', title: 'Threshold' },
        { id: 'recommendation', title: 'Recommendation' }
      ]
    });

    await csvWriter.writeRecords(csvData);
  }

  printSummary(report) {
    console.log(chalk.bold('\n📊 80/20 Coverage Analysis Summary'));
    console.log('━'.repeat(50));
    
    console.log(chalk.blue(`Overall Score: ${report.summary.overallScore}%`));
    console.log(chalk.blue(`Test Coverage: ${report.summary.testCoverage.total} tests (${report.summary.testCoverage.successRate.toFixed(1)}% success)`));
    console.log(chalk.blue(`Critical 80%: ${report.summary.testCoverage.critical80} tests`));
    console.log(chalk.blue(`Edge 20%: ${report.summary.testCoverage.edge20} tests`));
    
    // Health status
    const healthColor = report.summary.criticalPathHealth === 'healthy' ? chalk.green : 
                       report.summary.criticalPathHealth === 'warning' ? chalk.yellow : chalk.red;
    console.log(healthColor(`Critical Path Health: ${report.summary.criticalPathHealth}`));
    
    const perfColor = report.summary.performanceHealth === 'healthy' ? chalk.green :
                     report.summary.performanceHealth === 'warning' ? chalk.yellow : chalk.red;
    console.log(perfColor(`Performance Health: ${report.summary.performanceHealth}`));
    
    // Top recommendations
    if (report.recommendations.length > 0) {
      console.log(chalk.bold('\n🎯 Top Recommendations:'));
      report.recommendations.slice(0, 3).forEach((rec, index) => {
        const priorityColor = rec.priority === 'high' ? chalk.red : rec.priority === 'medium' ? chalk.yellow : chalk.green;
        console.log(priorityColor(`${index + 1}. [${rec.priority.toUpperCase()}] ${rec.title}`));
        console.log(chalk.gray(`   ${rec.description}`));
      });
    }
    
    console.log(chalk.dim(`\nDetailed report saved to: ${this.outputFile}`));
    console.log(chalk.dim(`CSV report saved to: ${this.csvFile}`));
  }
}

// Run analysis if called directly
if (require.main === module) {
  const analyzer = new Coverage8020Analyzer();
  analyzer.analyze()
    .then(() => process.exit(0))
    .catch(error => {
      console.error(chalk.red('Analysis failed:'), error);
      process.exit(1);
    });
}

module.exports = Coverage8020Analyzer;