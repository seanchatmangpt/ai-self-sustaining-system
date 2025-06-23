/**
 * Test Helpers and Utilities for Reactor E2E Tests
 * Provides common functionality for 80/20 coverage testing
 */

import { Page, Browser, BrowserContext } from '@playwright/test';
import { nanoid } from 'nanoid';
import postgres from 'postgres';

export interface TestContext {
  browser: Browser;
  context: BrowserContext;
  page: Page;
  testId: string;
  category: '80-critical' | '20-edge';
  startTime: number;
  metrics: TestMetrics;
}

export interface TestMetrics {
  responseTime: number;
  memoryUsage: number;
  networkRequests: number;
  errors: Error[];
  assertions: {
    passed: number;
    failed: number;
  };
}

export interface ReactorTestConfig {
  baseUrl: string;
  dbConnection: any;
  timeout: number;
  retries: number;
  screenshots: boolean;
  videos: boolean;
}

export class ReactorTestHelpers {
  private config: ReactorTestConfig;
  private db: any;

  constructor(config: ReactorTestConfig) {
    this.config = config;
    this.initializeDatabase();
  }

  private async initializeDatabase() {
    this.db = postgres({
      host: 'localhost',
      port: 5432,
      database: 'reactor_e2e',
      username: 'reactor_user',
      password: 'reactor_pass'
    });
  }

  /**
   * Creates a new test context with proper initialization
   */
  async createTestContext(
    browser: Browser, 
    category: '80-critical' | '20-edge' = '80-critical'
  ): Promise<TestContext> {
    const context = await browser.newContext({
      viewport: { width: 1280, height: 720 },
      recordVideo: this.config.videos ? { dir: 'test-results/videos' } : undefined,
      recordHar: { path: `test-results/har/${nanoid()}.har` }
    });

    const page = await context.newPage();
    const testId = nanoid();

    // Setup performance monitoring
    await this.setupPerformanceMonitoring(page);

    // Setup error tracking
    await this.setupErrorTracking(page);

    const testContext: TestContext = {
      browser,
      context,
      page,
      testId,
      category,
      startTime: Date.now(),
      metrics: {
        responseTime: 0,
        memoryUsage: 0,
        networkRequests: 0,
        errors: [],
        assertions: { passed: 0, failed: 0 }
      }
    };

    // Log test start
    await this.logTestStart(testContext);

    return testContext;
  }

  /**
   * Sets up performance monitoring for the page
   */
  private async setupPerformanceMonitoring(page: Page) {
    // Monitor network requests
    page.on('request', (request) => {
      console.log(`→ ${request.method()} ${request.url()}`);
    });

    page.on('response', (response) => {
      if (!response.ok()) {
        console.log(`← ${response.status()} ${response.url()}`);
      }
    });

    // Inject performance monitoring script
    await page.addInitScript(() => {
      window.__TEST_PERFORMANCE__ = {
        startTime: performance.now(),
        requests: 0,
        errors: []
      };

      // Track network requests
      const originalFetch = window.fetch;
      window.fetch = function(...args) {
        window.__TEST_PERFORMANCE__.requests++;
        return originalFetch.apply(this, args);
      };

      // Track errors
      window.addEventListener('error', (event) => {
        window.__TEST_PERFORMANCE__.errors.push({
          message: event.message,
          filename: event.filename,
          lineno: event.lineno,
          colno: event.colno,
          stack: event.error?.stack
        });
      });
    });
  }

  /**
   * Sets up error tracking for the page
   */
  private async setupErrorTracking(page: Page) {
    page.on('pageerror', (error) => {
      console.error('Page error:', error);
    });

    page.on('console', (message) => {
      if (message.type() === 'error') {
        console.error('Console error:', message.text());
      }
    });
  }

  /**
   * Executes a reactor test scenario with comprehensive monitoring
   */
  async executeReactorScenario(
    testContext: TestContext,
    scenario: {
      name: string;
      endpoint: string;
      input?: any;
      expectedOutput?: any;
      assertions?: (page: Page, result: any) => Promise<void>;
    }
  ): Promise<any> {
    const { page, testId } = testContext;
    const startTime = performance.now();

    try {
      // Navigate to the endpoint
      const url = `${this.config.baseUrl}${scenario.endpoint}`;
      const response = await page.goto(url, { 
        waitUntil: 'networkidle',
        timeout: this.config.timeout 
      });

      if (!response?.ok()) {
        throw new Error(`HTTP ${response?.status()}: ${response?.statusText()}`);
      }

      // Execute scenario-specific logic
      let result = null;
      if (scenario.input) {
        // Post input data if provided
        result = await page.evaluate(async (input) => {
          const response = await fetch(window.location.href, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(input)
          });
          return response.json();
        }, scenario.input);
      } else {
        // Get result from page
        result = await page.evaluate(() => {
          return window.__REACTOR_RESULT__ || document.body.textContent;
        });
      }

      // Run custom assertions
      if (scenario.assertions) {
        await scenario.assertions(page, result);
        testContext.metrics.assertions.passed++;
      }

      // Collect performance metrics
      const endTime = performance.now();
      testContext.metrics.responseTime = endTime - startTime;

      const performanceData = await page.evaluate(() => {
        return {
          memory: performance.memory ? {
            usedJSHeapSize: performance.memory.usedJSHeapSize,
            totalJSHeapSize: performance.memory.totalJSHeapSize
          } : null,
          requests: window.__TEST_PERFORMANCE__?.requests || 0,
          errors: window.__TEST_PERFORMANCE__?.errors || []
        };
      });

      testContext.metrics.memoryUsage = performanceData.memory?.usedJSHeapSize || 0;
      testContext.metrics.networkRequests = performanceData.requests;
      testContext.metrics.errors.push(...performanceData.errors.map(e => new Error(e.message)));

      // Log scenario execution
      await this.logScenarioExecution(testContext, scenario, result, 'success');

      return result;

    } catch (error) {
      testContext.metrics.assertions.failed++;
      testContext.metrics.errors.push(error as Error);

      // Log scenario failure
      await this.logScenarioExecution(testContext, scenario, null, 'failure', error as Error);

      throw error;
    }
  }

  /**
   * Validates 80/20 performance thresholds
   */
  validatePerformanceThresholds(
    testContext: TestContext,
    thresholds: {
      maxResponseTime: number;
      maxMemoryUsage: number;
      maxErrors: number;
    }
  ): boolean {
    const { metrics, category } = testContext;
    
    // Apply different thresholds based on category
    const adjustedThresholds = category === '80-critical' ? {
      maxResponseTime: thresholds.maxResponseTime,
      maxMemoryUsage: thresholds.maxMemoryUsage,
      maxErrors: thresholds.maxErrors
    } : {
      maxResponseTime: thresholds.maxResponseTime * 5,  // More lenient for edge cases
      maxMemoryUsage: thresholds.maxMemoryUsage * 3,
      maxErrors: thresholds.maxErrors * 2
    };

    const violations = [];

    if (metrics.responseTime > adjustedThresholds.maxResponseTime) {
      violations.push(`Response time ${metrics.responseTime}ms exceeds threshold ${adjustedThresholds.maxResponseTime}ms`);
    }

    if (metrics.memoryUsage > adjustedThresholds.maxMemoryUsage) {
      violations.push(`Memory usage ${metrics.memoryUsage} bytes exceeds threshold ${adjustedThresholds.maxMemoryUsage} bytes`);
    }

    if (metrics.errors.length > adjustedThresholds.maxErrors) {
      violations.push(`Error count ${metrics.errors.length} exceeds threshold ${adjustedThresholds.maxErrors}`);
    }

    if (violations.length > 0) {
      console.warn(`Performance threshold violations for ${testContext.testId}:`, violations);
      return false;
    }

    return true;
  }

  /**
   * Generates test data for reactor scenarios
   */
  generateTestData(scenario: string, size: 'small' | 'medium' | 'large' = 'medium'): any {
    const dataSizes = {
      small: { items: 10, complexity: 1 },
      medium: { items: 100, complexity: 5 },
      large: { items: 1000, complexity: 10 }
    };

    const config = dataSizes[size];

    switch (scenario) {
      case 'basic-workflow':
        return {
          input: 'test-data',
          processCount: config.complexity,
          items: Array.from({ length: config.items }, (_, i) => ({ id: i, value: Math.random() }))
        };

      case 'parallel-processing':
        return {
          datasets: Array.from({ length: config.complexity }, (_, i) => 
            Array.from({ length: config.items }, (_, j) => ({ batch: i, item: j, data: Math.random() }))
          )
        };

      case 'error-recovery':
        return {
          operations: Array.from({ length: config.items }, (_, i) => ({
            id: i,
            shouldFail: i % 10 === 0, // 10% failure rate
            retryCount: config.complexity
          }))
        };

      case 'memory-stress':
        return {
          largeArray: Array.from({ length: config.items * 100 }, (_, i) => ({
            id: i,
            data: new Array(config.complexity * 100).fill(Math.random()),
            metadata: { timestamp: Date.now(), random: Math.random() }
          }))
        };

      default:
        return { items: config.items, complexity: config.complexity };
    }
  }

  /**
   * Logs test execution to database
   */
  private async logTestStart(testContext: TestContext) {
    try {
      await this.db`
        INSERT INTO reactor_executions (reactor_id, execution_id, state, started_at)
        VALUES ('e2e-test', ${testContext.testId}, 'running', NOW())
      `;
    } catch (error) {
      console.warn('Failed to log test start:', error);
    }
  }

  /**
   * Logs scenario execution results
   */
  private async logScenarioExecution(
    testContext: TestContext,
    scenario: any,
    result: any,
    status: 'success' | 'failure',
    error?: Error
  ) {
    try {
      await this.db`
        INSERT INTO reactor_steps (
          execution_id, step_name, state, output_data, error_data, 
          duration_ms, completed_at
        )
        VALUES (
          (SELECT id FROM reactor_executions WHERE execution_id = ${testContext.testId}),
          ${scenario.name},
          ${status === 'success' ? 'completed' : 'failed'},
          ${result ? JSON.stringify(result) : null},
          ${error ? JSON.stringify({ message: error.message, stack: error.stack }) : null},
          ${testContext.metrics.responseTime},
          NOW()
        )
      `;
    } catch (dbError) {
      console.warn('Failed to log scenario execution:', dbError);
    }
  }

  /**
   * Finalizes test context and collects final metrics
   */
  async finalizeTestContext(testContext: TestContext): Promise<TestMetrics> {
    const { page, testId, startTime } = testContext;

    // Collect final performance data
    const finalPerformanceData = await page.evaluate(() => {
      return {
        memory: performance.memory ? {
          usedJSHeapSize: performance.memory.usedJSHeapSize,
          totalJSHeapSize: performance.memory.totalJSHeapSize
        } : null,
        timing: performance.now(),
        requests: window.__TEST_PERFORMANCE__?.requests || 0,
        errors: window.__TEST_PERFORMANCE__?.errors || []
      };
    });

    // Update final metrics
    testContext.metrics.memoryUsage = Math.max(
      testContext.metrics.memoryUsage,
      finalPerformanceData.memory?.usedJSHeapSize || 0
    );
    testContext.metrics.networkRequests = finalPerformanceData.requests;

    // Calculate total test duration
    const totalDuration = Date.now() - startTime;

    // Log test completion
    try {
      await this.db`
        UPDATE reactor_executions 
        SET state = 'completed', completed_at = NOW(), duration_ms = ${totalDuration}
        WHERE execution_id = ${testId}
      `;

      // Log final metrics
      await this.db`
        INSERT INTO reactor_metrics (
          execution_id, metric_name, metric_value, metric_unit, metric_tags
        )
        VALUES
          ((SELECT id FROM reactor_executions WHERE execution_id = ${testId}), 'response_time', ${testContext.metrics.responseTime}, 'ms', '{"category": "${testContext.category}"}'),
          ((SELECT id FROM reactor_executions WHERE execution_id = ${testId}), 'memory_usage', ${testContext.metrics.memoryUsage}, 'bytes', '{"category": "${testContext.category}"}'),
          ((SELECT id FROM reactor_executions WHERE execution_id = ${testId}), 'network_requests', ${testContext.metrics.networkRequests}, 'count', '{"category": "${testContext.category}"}'),
          ((SELECT id FROM reactor_executions WHERE execution_id = ${testId}), 'error_count', ${testContext.metrics.errors.length}, 'count', '{"category": "${testContext.category}"}')
      `;
    } catch (error) {
      console.warn('Failed to log test completion:', error);
    }

    // Cleanup
    await testContext.context.close();

    return testContext.metrics;
  }

  /**
   * Cleanup database connections
   */
  async cleanup() {
    if (this.db) {
      await this.db.end();
    }
  }
}