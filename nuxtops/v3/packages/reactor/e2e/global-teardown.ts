import { FullConfig } from '@playwright/test';
import postgres from 'postgres';
import { writeFileSync } from 'fs';
import { join } from 'path';

/**
 * Global teardown for E2E tests
 * Collects final metrics and generates 80/20 coverage report
 */
export default async function globalTeardown(config: FullConfig) {
  console.log('🏁 Starting Reactor E2E Global Teardown...');
  
  try {
    // 1. Finalize database metrics
    await finalizeMetrics();
    
    // 2. Generate coverage report
    await generateCoverageReport();
    
    // 3. Validate 80/20 thresholds
    await validate8020Thresholds();
    
    // 4. Export telemetry data
    await exportTelemetryData();
    
    // 5. Cleanup test artifacts
    await cleanupTestArtifacts();
    
    console.log('✅ Global teardown completed successfully');
    
  } catch (error) {
    console.error('❌ Global teardown failed:', error);
  }
}

async function finalizeMetrics() {
  console.log('📊 Finalizing test metrics...');
  
  try {
    const sql = postgres({
      host: 'localhost',
      port: 5432,
      database: 'reactor_e2e',
      username: 'reactor_user',
      password: 'reactor_pass'
    });
    
    const testRunId = process.env.TEST_RUN_ID;
    if (!testRunId) {
      console.log('  ⚠️  No test run ID found, skipping metrics finalization');
      return;
    }
    
    // Update test run completion
    await sql`
      UPDATE reactor_executions 
      SET state = 'completed', completed_at = NOW(), duration_ms = EXTRACT(EPOCH FROM (NOW() - started_at)) * 1000
      WHERE execution_id = ${testRunId}
    `;
    
    // Get final metrics
    const metrics = await sql`
      SELECT 
        COUNT(*) as total_executions,
        COUNT(CASE WHEN state = 'completed' THEN 1 END) as successful_executions,
        COUNT(CASE WHEN state = 'failed' THEN 1 END) as failed_executions,
        AVG(duration_ms) as avg_duration,
        MAX(duration_ms) as max_duration,
        MIN(duration_ms) as min_duration
      FROM reactor_executions 
      WHERE started_at >= NOW() - INTERVAL '1 hour'
    `;
    
    console.log('  ✓ Final metrics:', metrics[0]);
    
    // Store metrics for reporting
    process.env.FINAL_METRICS = JSON.stringify(metrics[0]);
    
    await sql.end();
    
  } catch (error) {
    console.log(`  ⚠️  Metrics finalization failed: ${error.message}`);
  }
}

async function generateCoverageReport() {
  console.log('📋 Generating 80/20 coverage report...');
  
  try {
    const sql = postgres({
      host: 'localhost',
      port: 5432,
      database: 'reactor_e2e',
      username: 'reactor_user',
      password: 'reactor_pass'
    });
    
    // Get coverage data
    const coverageData = await sql`
      SELECT 
        ts.coverage_category,
        ts.scenario_name,
        ts.priority,
        COUNT(te.id) as total_runs,
        COUNT(CASE WHEN te.status = 'passed' THEN 1 END) as passed_runs,
        ROUND((COUNT(CASE WHEN te.status = 'passed' THEN 1 END)::numeric / COUNT(te.id) * 100), 2) as success_rate,
        AVG(te.execution_time_ms) as avg_execution_time,
        AVG(te.memory_usage_mb) as avg_memory_usage,
        AVG(te.performance_score) as avg_performance_score
      FROM test_scenarios ts
      LEFT JOIN test_executions te ON ts.id = te.scenario_id
      WHERE te.started_at >= NOW() - INTERVAL '1 hour'
      GROUP BY ts.coverage_category, ts.scenario_name, ts.priority
      ORDER BY ts.coverage_category, success_rate DESC
    `;
    
    // Calculate overall 80/20 score
    const testRunId = process.env.TEST_RUN_ID;
    let overallScore = 0;
    
    if (testRunId) {
      const scoreResult = await sql`SELECT calculate_coverage_score(${testRunId}) as score`;
      overallScore = scoreResult[0]?.score || 0;
    }
    
    const report = {
      timestamp: new Date().toISOString(),
      testRunId: testRunId,
      overallScore: overallScore,
      threshold: 80,
      passed: overallScore >= 80,
      coverageData: coverageData,
      summary: {
        critical80: coverageData.filter(d => d.coverage_category === 'critical_80'),
        edge20: coverageData.filter(d => d.coverage_category === 'edge_20')
      }
    };
    
    // Write report to file
    const reportPath = join(__dirname, 'reports', '80-20-coverage-report.json');
    writeFileSync(reportPath, JSON.stringify(report, null, 2));
    
    console.log(`  ✓ Coverage report generated: ${reportPath}`);
    console.log(`  📊 Overall 80/20 Score: ${overallScore}%`);
    
    await sql.end();
    
  } catch (error) {
    console.log(`  ⚠️  Coverage report generation failed: ${error.message}`);
  }
}

async function validate8020Thresholds() {
  console.log('🎯 Validating 80/20 thresholds...');
  
  try {
    const finalMetrics = process.env.FINAL_METRICS;
    if (!finalMetrics) {
      console.log('  ⚠️  No metrics available for validation');
      return;
    }
    
    const metrics = JSON.parse(finalMetrics);
    const successRate = (metrics.successful_executions / metrics.total_executions) * 100;
    
    const thresholds = {
      minSuccessRate: 80,
      maxAvgDuration: 1000, // 1 second
      maxMaxDuration: 5000   // 5 seconds
    };
    
    const validation = {
      successRate: {
        value: successRate,
        threshold: thresholds.minSuccessRate,
        passed: successRate >= thresholds.minSuccessRate
      },
      avgDuration: {
        value: metrics.avg_duration,
        threshold: thresholds.maxAvgDuration,
        passed: metrics.avg_duration <= thresholds.maxAvgDuration
      },
      maxDuration: {
        value: metrics.max_duration,
        threshold: thresholds.maxMaxDuration,
        passed: metrics.max_duration <= thresholds.maxMaxDuration
      }
    };
    
    const allPassed = Object.values(validation).every(v => v.passed);
    
    console.log(`  📊 Success Rate: ${successRate.toFixed(2)}% (>= ${thresholds.minSuccessRate}%) ${validation.successRate.passed ? '✅' : '❌'}`);
    console.log(`  ⏱️  Avg Duration: ${metrics.avg_duration.toFixed(2)}ms (<= ${thresholds.maxAvgDuration}ms) ${validation.avgDuration.passed ? '✅' : '❌'}`);
    console.log(`  🔥 Max Duration: ${metrics.max_duration.toFixed(2)}ms (<= ${thresholds.maxMaxDuration}ms) ${validation.maxDuration.passed ? '✅' : '❌'}`);
    
    if (allPassed) {
      console.log('  ✅ All 80/20 thresholds passed');
    } else {
      console.log('  ❌ Some thresholds failed - review performance');
    }
    
    // Write validation results
    const validationPath = join(__dirname, 'reports', 'threshold-validation.json');
    writeFileSync(validationPath, JSON.stringify(validation, null, 2));
    
  } catch (error) {
    console.log(`  ⚠️  Threshold validation failed: ${error.message}`);
  }
}

async function exportTelemetryData() {
  console.log('📡 Exporting telemetry data...');
  
  try {
    const spanId = process.env.TELEMETRY_SPAN_ID;
    if (!spanId) {
      console.log('  ⚠️  No telemetry span ID found');
      return;
    }
    
    // Export telemetry summary
    const telemetryData = {
      spanId: spanId,
      testRunId: process.env.TEST_RUN_ID,
      exportTime: new Date().toISOString(),
      jaegerUrl: `http://localhost:16686/search?service=reactor-e2e&tags=span_id%3D${spanId}`,
      prometheusUrl: 'http://localhost:9090/graph'
    };
    
    const telemetryPath = join(__dirname, 'reports', 'telemetry-export.json');
    writeFileSync(telemetryPath, JSON.stringify(telemetryData, null, 2));
    
    console.log('  ✓ Telemetry data exported');
    console.log(`  🔍 View traces: ${telemetryData.jaegerUrl}`);
    
  } catch (error) {
    console.log(`  ⚠️  Telemetry export failed: ${error.message}`);
  }
}

async function cleanupTestArtifacts() {
  console.log('🧹 Cleaning up test artifacts...');
  
  try {
    // Clean up environment variables
    delete process.env.TEST_RUN_ID;
    delete process.env.TELEMETRY_SPAN_ID;
    delete process.env.PERFORMANCE_BASELINE;
    delete process.env.FINAL_METRICS;
    
    console.log('  ✓ Test artifacts cleaned up');
    
  } catch (error) {
    console.log(`  ⚠️  Cleanup failed: ${error.message}`);
  }
}