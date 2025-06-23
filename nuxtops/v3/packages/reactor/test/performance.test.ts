/**
 * Performance and stress tests for reactor system
 */

import { describe, it, expect, vi, beforeEach } from 'vitest';
import { ReactorEngine } from '../core/reactor-engine';
import { TelemetryMiddleware } from '../middleware/telemetry-middleware';
import { createMockStep, createDelayedStep, delay, PerformanceTracker } from './setup';

describe('Performance Tests', () => {
  let performanceTracker: PerformanceTracker;

  beforeEach(() => {
    performanceTracker = new PerformanceTracker();
    vi.clearAllMocks();
  });

  describe('Execution Speed', () => {
    it('should execute 100 simple steps within time limit', async () => {
      const reactor = new ReactorEngine();
      
      for (let i = 0; i < 100; i++) {
        reactor.addStep(createMockStep(`step-${i}`));
      }
      
      performanceTracker.mark('start');
      const result = await reactor.execute();
      performanceTracker.mark('end');
      
      const duration = performanceTracker.measure('start', 'end');
      
      expect(result.state).toBe('completed');
      expect(result.results.size).toBe(100);
      expect(duration).toBeLessThan(1000); // Should complete in under 1 second
    });

    it('should handle deep dependency chains efficiently', async () => {
      const reactor = new ReactorEngine();
      
      // Create chain: step-0 -> step-1 -> step-2 -> ... -> step-49
      reactor.addStep(createMockStep('step-0'));
      
      for (let i = 1; i < 50; i++) {
        reactor.addStep(createMockStep(`step-${i}`, {
          dependencies: [`step-${i-1}`]
        }));
      }
      
      performanceTracker.mark('start');
      const result = await reactor.execute();
      performanceTracker.mark('end');
      
      const duration = performanceTracker.measure('start', 'end');
      
      expect(result.state).toBe('completed');
      expect(duration).toBeLessThan(500); // Should handle sequential execution efficiently
    });

    it('should optimize parallel execution with concurrency limits', async () => {
      const reactor = new ReactorEngine({ maxConcurrency: 10 });
      
      // Create 50 independent steps with 50ms delay each
      for (let i = 0; i < 50; i++) {
        reactor.addStep(createDelayedStep(`parallel-${i}`, 50));
      }
      
      performanceTracker.mark('start');
      const result = await reactor.execute();
      performanceTracker.mark('end');
      
      const duration = performanceTracker.measure('start', 'end');
      
      expect(result.state).toBe('completed');
      // With concurrency of 10, 50 steps should take ~250ms (5 batches)
      expect(duration).toBeGreaterThan(200);
      expect(duration).toBeLessThan(400);
    });
  });

  describe('Memory Efficiency', () => {
    it('should not leak memory with large number of steps', async () => {
      const reactor = new ReactorEngine();
      
      // Add many steps
      for (let i = 0; i < 1000; i++) {
        reactor.addStep(createMockStep(`memory-test-${i}`));
      }
      
      const initialMemory = process.memoryUsage();
      
      await reactor.execute();
      
      const finalMemory = process.memoryUsage();
      const memoryIncrease = finalMemory.heapUsed - initialMemory.heapUsed;
      
      // Memory increase should be reasonable (less than 50MB)
      expect(memoryIncrease).toBeLessThan(50 * 1024 * 1024);
    });

    it('should clean up resources after execution', async () => {
      const reactor = new ReactorEngine();
      
      reactor.addStep(createMockStep('cleanup-test'));
      
      await reactor.execute();
      
      // Results should be accessible but not consuming excessive memory
      expect(reactor.results.size).toBe(1);
      expect(reactor.undoStack.length).toBe(1);
      
      // Internal state should be reasonable
      expect(Object.keys(reactor.context).length).toBeLessThan(20);
    });
  });

  describe('Telemetry Performance', () => {
    it('should not significantly impact performance', async () => {
      const spans: any[] = [];
      const telemetryMiddleware = new TelemetryMiddleware({
        onSpanEnd: (span) => spans.push(span)
      });
      
      // Test without telemetry
      const reactorNoTelemetry = new ReactorEngine();
      for (let i = 0; i < 100; i++) {
        reactorNoTelemetry.addStep(createMockStep(`no-tel-${i}`));
      }
      
      performanceTracker.mark('no-telemetry-start');
      await reactorNoTelemetry.execute();
      performanceTracker.mark('no-telemetry-end');
      
      // Test with telemetry
      const reactorWithTelemetry = new ReactorEngine();
      reactorWithTelemetry.addMiddleware(telemetryMiddleware);
      for (let i = 0; i < 100; i++) {
        reactorWithTelemetry.addStep(createMockStep(`with-tel-${i}`));
      }
      
      performanceTracker.mark('with-telemetry-start');
      await reactorWithTelemetry.execute();
      performanceTracker.mark('with-telemetry-end');
      
      const noTelemetryDuration = performanceTracker.measure('no-telemetry-start', 'no-telemetry-end');
      const withTelemetryDuration = performanceTracker.measure('with-telemetry-start', 'with-telemetry-end');
      
      // Telemetry should add less than 50% overhead
      const overhead = (withTelemetryDuration - noTelemetryDuration) / noTelemetryDuration;
      expect(overhead).toBeLessThan(0.5);
      
      // Should have collected spans
      expect(spans.length).toBeGreaterThan(100); // 100 steps + 1 root
    });
  });

  describe('Stress Tests', () => {
    it('should handle rapid concurrent reactor creation', async () => {
      const reactorCount = 20;
      const reactors = Array.from({ length: reactorCount }, () => {
        const reactor = new ReactorEngine();
        reactor.addStep(createMockStep('concurrent-step'));
        return reactor;
      });
      
      performanceTracker.mark('concurrent-start');
      
      const results = await Promise.all(
        reactors.map(reactor => reactor.execute())
      );
      
      performanceTracker.mark('concurrent-end');
      
      const duration = performanceTracker.measure('concurrent-start', 'concurrent-end');
      
      expect(results.every(r => r.state === 'completed')).toBe(true);
      expect(duration).toBeLessThan(2000); // Should handle concurrent load
    });

    it('should maintain performance under error conditions', async () => {
      const reactor = new ReactorEngine();
      
      // Mix of successful and failing steps
      for (let i = 0; i < 50; i++) {
        if (i % 3 === 0) {
          reactor.addStep({
            name: `failing-${i}`,
            async run() {
              throw new Error('Simulated failure');
            },
            async compensate() {
              return 'skip';
            }
          });
        } else {
          reactor.addStep(createMockStep(`success-${i}`));
        }
      }
      
      performanceTracker.mark('error-handling-start');
      const result = await reactor.execute();
      performanceTracker.mark('error-handling-end');
      
      const duration = performanceTracker.measure('error-handling-start', 'error-handling-end');
      
      expect(result.state).toBe('failed');
      expect(duration).toBeLessThan(1000); // Should handle errors efficiently
    });

    it('should handle complex dependency graphs efficiently', async () => {
      const reactor = new ReactorEngine();
      
      // Create complex dependency pattern
      reactor.addStep(createMockStep('root'));
      
      // Level 1: 5 steps depending on root
      for (let i = 0; i < 5; i++) {
        reactor.addStep(createMockStep(`l1-${i}`, { dependencies: ['root'] }));
      }
      
      // Level 2: 10 steps depending on level 1 steps
      for (let i = 0; i < 10; i++) {
        const depIndex = i % 5;
        reactor.addStep(createMockStep(`l2-${i}`, { dependencies: [`l1-${depIndex}`] }));
      }
      
      // Level 3: 5 steps depending on multiple level 2 steps
      for (let i = 0; i < 5; i++) {
        const deps = [`l2-${i * 2}`, `l2-${i * 2 + 1}`];
        reactor.addStep(createMockStep(`l3-${i}`, { dependencies: deps }));
      }
      
      performanceTracker.mark('complex-graph-start');
      const result = await reactor.execute();
      performanceTracker.mark('complex-graph-end');
      
      const duration = performanceTracker.measure('complex-graph-start', 'complex-graph-end');
      
      expect(result.state).toBe('completed');
      expect(result.results.size).toBe(21); // 1 + 5 + 10 + 5
      expect(duration).toBeLessThan(1000); // Should resolve complex graphs efficiently
    });
  });

  describe('Scalability Tests', () => {
    it('should scale linearly with step count', async () => {
      const stepCounts = [10, 50, 100];
      const durations: number[] = [];
      
      for (const count of stepCounts) {
        const reactor = new ReactorEngine();
        
        for (let i = 0; i < count; i++) {
          reactor.addStep(createMockStep(`scale-${i}`));
        }
        
        performanceTracker.mark(`scale-${count}-start`);
        await reactor.execute();
        performanceTracker.mark(`scale-${count}-end`);
        
        const duration = performanceTracker.measure(`scale-${count}-start`, `scale-${count}-end`);
        durations.push(duration);
      }
      
      // Performance should scale reasonably (not exponentially)
      const ratio1 = durations[1] / durations[0]; // 50 vs 10
      const ratio2 = durations[2] / durations[1]; // 100 vs 50
      
      expect(ratio1).toBeLessThan(10); // Should not be 10x slower for 5x more steps
      expect(ratio2).toBeLessThan(5);  // Should not be 5x slower for 2x more steps
    });

    it('should handle deep nesting efficiently', async () => {
      const reactor = new ReactorEngine();
      
      // Create deeply nested dependencies
      reactor.addStep(createMockStep('depth-0'));
      
      for (let i = 1; i < 100; i++) {
        reactor.addStep(createMockStep(`depth-${i}`, {
          dependencies: [`depth-${i-1}`]
        }));
      }
      
      performanceTracker.mark('deep-nest-start');
      const result = await reactor.execute();
      performanceTracker.mark('deep-nest-end');
      
      const duration = performanceTracker.measure('deep-nest-start', 'deep-nest-end');
      
      expect(result.state).toBe('completed');
      expect(duration).toBeLessThan(2000); // Should handle deep nesting
    });
  });
});