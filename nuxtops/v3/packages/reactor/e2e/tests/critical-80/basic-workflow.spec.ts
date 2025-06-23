/**
 * Critical 80% Test: Basic Workflow
 * Tests the core input-process-output workflow that handles 80% of use cases
 */

import { test, expect, Browser } from '@playwright/test';
import { ReactorTestHelpers } from '../../utils/test-helpers';

const testHelpers = new ReactorTestHelpers({
  baseUrl: process.env.BASE_URL || 'http://localhost:3000',
  dbConnection: null,
  timeout: 30000,
  retries: 2,
  screenshots: true,
  videos: false
});

test.describe('Critical 80% - Basic Workflow', () => {
  let browser: Browser;

  test.beforeAll(async ({ browser: b }) => {
    browser = b;
  });

  test.afterAll(async () => {
    await testHelpers.cleanup();
  });

  test('E2E-Critical-01: Basic Input-Process-Output Flow', async () => {
    const testContext = await testHelpers.createTestContext(browser, '80-critical');
    
    try {
      // Test basic reactor execution
      const result = await testHelpers.executeReactorScenario(testContext, {
        name: 'basic-input-output',
        endpoint: '/api/reactor/examples/basic',
        input: { data: 'test-input', type: 'string' },
        expectedOutput: { processed: true, result: 'TEST-INPUT' },
        assertions: async (page, result) => {
          expect(result).toBeDefined();
          expect(result.state).toBe('completed');
          expect(result.returnValue).toBeDefined();
          expect(result.returnValue.final).toBe('TEST-INPUT');
          expect(result.duration).toBeLessThan(100);
        }
      });

      // Validate performance thresholds
      const performanceValid = testHelpers.validatePerformanceThresholds(testContext, {
        maxResponseTime: 100,
        maxMemoryUsage: 10 * 1024 * 1024, // 10MB
        maxErrors: 0
      });

      expect(performanceValid).toBe(true);

      // Verify reactor state consistency
      expect(result.state).toBe('completed');
      expect(result.errors).toHaveLength(0);
      expect(result.steps).toBeGreaterThan(0);

    } finally {
      await testHelpers.finalizeTestContext(testContext);
    }
  });

  test('E2E-Critical-02: Multi-Step Sequential Processing', async () => {
    const testContext = await testHelpers.createTestContext(browser, '80-critical');
    
    try {
      const testData = testHelpers.generateTestData('basic-workflow', 'medium');
      
      const result = await testHelpers.executeReactorScenario(testContext, {
        name: 'multi-step-sequential',
        endpoint: '/api/reactor/examples/sequential',
        input: testData,
        assertions: async (page, result) => {
          expect(result.state).toBe('completed');
          expect(result.returnValue).toBeDefined();
          
          // Verify step execution order
          const stepOrder = result.stepExecutionOrder || [];
          expect(stepOrder).toContain('validate');
          expect(stepOrder).toContain('process');
          expect(stepOrder).toContain('output');
          
          // Verify data transformation
          expect(result.returnValue.processed).toBe(true);
          expect(result.returnValue.items).toHaveLength(testData.items.length);
        }
      });

      // Critical path performance validation
      const performanceValid = testHelpers.validatePerformanceThresholds(testContext, {
        maxResponseTime: 200, // Slightly higher for multi-step
        maxMemoryUsage: 20 * 1024 * 1024, // 20MB
        maxErrors: 0
      });

      expect(performanceValid).toBe(true);

    } finally {
      await testHelpers.finalizeTestContext(testContext);
    }
  });

  test('E2E-Critical-03: Data Validation and Transformation', async () => {
    const testContext = await testHelpers.createTestContext(browser, '80-critical');
    
    try {
      // Test with various data types and validation scenarios
      const testCases = [
        { input: { data: 'valid-string' }, shouldPass: true },
        { input: { data: 123 }, shouldPass: true },
        { input: { data: { nested: 'object' } }, shouldPass: true },
        { input: { data: null }, shouldPass: false },
        { input: {}, shouldPass: false }
      ];

      for (const testCase of testCases) {
        const result = await testHelpers.executeReactorScenario(testContext, {
          name: `validation-${JSON.stringify(testCase.input)}`,
          endpoint: '/api/reactor/examples/validation',
          input: testCase.input,
          assertions: async (page, result) => {
            if (testCase.shouldPass) {
              expect(result.state).toBe('completed');
              expect(result.returnValue.validated).toBe(true);
            } else {
              expect(result.state).toBe('failed');
              expect(result.errors).not.toHaveLength(0);
            }
          }
        });

        // Even failed validations should be fast
        expect(testContext.metrics.responseTime).toBeLessThan(50);
      }

    } finally {
      await testHelpers.finalizeTestContext(testContext);
    }
  });

  test('E2E-Critical-04: State Management and Consistency', async () => {
    const testContext = await testHelpers.createTestContext(browser, '80-critical');
    
    try {
      const result = await testHelpers.executeReactorScenario(testContext, {
        name: 'state-consistency',
        endpoint: '/api/reactor/examples/state-management',
        input: { 
          initialState: { counter: 0, items: [] },
          operations: [
            { type: 'increment', amount: 5 },
            { type: 'add-item', item: 'test' },
            { type: 'increment', amount: 3 },
            { type: 'add-item', item: 'test2' }
          ]
        },
        assertions: async (page, result) => {
          expect(result.state).toBe('completed');
          expect(result.returnValue.finalState).toBeDefined();
          expect(result.returnValue.finalState.counter).toBe(8);
          expect(result.returnValue.finalState.items).toHaveLength(2);
          
          // Verify state transitions were tracked
          expect(result.returnValue.stateHistory).toBeDefined();
          expect(result.returnValue.stateHistory).toHaveLength(4);
        }
      });

      // State consistency is critical for data integrity
      const performanceValid = testHelpers.validatePerformanceThresholds(testContext, {
        maxResponseTime: 150,
        maxMemoryUsage: 15 * 1024 * 1024, // 15MB
        maxErrors: 0
      });

      expect(performanceValid).toBe(true);

    } finally {
      await testHelpers.finalizeTestContext(testContext);
    }
  });

  test('E2E-Critical-05: API Integration and External Calls', async () => {
    const testContext = await testHelpers.createTestContext(browser, '80-critical');
    
    try {
      const result = await testHelpers.executeReactorScenario(testContext, {
        name: 'api-integration',
        endpoint: '/api/reactor/examples/api-integration',
        input: { 
          endpoints: [
            'http://localhost:3100/api/health',
            'http://localhost:3100/api/data/process'
          ],
          timeout: 5000
        },
        assertions: async (page, result) => {
          expect(result.state).toBe('completed');
          expect(result.returnValue.apiResults).toBeDefined();
          expect(result.returnValue.apiResults).toHaveLength(2);
          
          // Verify all API calls succeeded
          result.returnValue.apiResults.forEach((apiResult: any) => {
            expect(apiResult.success).toBe(true);
            expect(apiResult.responseTime).toBeLessThan(1000);
          });
        }
      });

      // API integration should handle network latency gracefully
      const performanceValid = testHelpers.validatePerformanceThresholds(testContext, {
        maxResponseTime: 2000, // Higher threshold for network calls
        maxMemoryUsage: 25 * 1024 * 1024, // 25MB
        maxErrors: 0
      });

      expect(performanceValid).toBe(true);

    } finally {
      await testHelpers.finalizeTestContext(testContext);
    }
  });

  test('E2E-Critical-06: Performance Under Normal Load', async () => {
    const testContext = await testHelpers.createTestContext(browser, '80-critical');
    
    try {
      // Test performance with typical production load
      const concurrentRequests = 10;
      const results = [];

      for (let i = 0; i < concurrentRequests; i++) {
        const testData = testHelpers.generateTestData('basic-workflow', 'medium');
        
        const result = await testHelpers.executeReactorScenario(testContext, {
          name: `concurrent-load-${i}`,
          endpoint: '/api/reactor/examples/concurrent-load',
          input: { 
            ...testData,
            requestId: i,
            simulateLoad: true
          },
          assertions: async (page, result) => {
            expect(result.state).toBe('completed');
            expect(result.returnValue.processed).toBe(true);
            expect(result.returnValue.requestId).toBe(i);
          }
        });

        results.push(result);
      }

      // Verify consistent performance across all requests
      const avgResponseTime = testContext.metrics.responseTime / concurrentRequests;
      expect(avgResponseTime).toBeLessThan(200);

      // Memory usage should be stable
      const finalMetrics = await testHelpers.finalizeTestContext(testContext);
      expect(finalMetrics.memoryUsage).toBeLessThan(50 * 1024 * 1024); // 50MB

    } finally {
      // Context already finalized above
    }
  });
});