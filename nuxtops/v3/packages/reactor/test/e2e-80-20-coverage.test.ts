/**
 * 80/20 End-to-End Coverage Test Suite
 * Comprehensive validation of reactor system with performance benchmarks
 */

import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { createReactor, arg, simpleReactor } from '../core/reactor-builder';
import { performance } from 'perf_hooks';
import type { ReactorResult } from '../types';

// Performance tracking
interface BenchmarkResult {
  testName: string;
  duration: number;
  throughput: number;
  memoryUsage: number;
  success: boolean;
  errors: Error[];
}

class E2ETestFramework {
  private benchmarks: BenchmarkResult[] = [];
  private startTime: number = 0;
  private startMemory: number = 0;

  startBenchmark(testName: string) {
    this.startTime = performance.now();
    this.startMemory = process.memoryUsage().heapUsed;
  }

  endBenchmark(testName: string, result: ReactorResult, operations: number = 1): BenchmarkResult {
    const duration = performance.now() - this.startTime;
    const memoryUsage = process.memoryUsage().heapUsed - this.startMemory;
    const throughput = operations / (duration / 1000); // ops per second

    const benchmark: BenchmarkResult = {
      testName,
      duration,
      throughput,
      memoryUsage,
      success: result.state === 'completed',
      errors: result.errors
    };

    this.benchmarks.push(benchmark);
    return benchmark;
  }

  getBenchmarkSummary() {
    const total = this.benchmarks.length;
    const successful = this.benchmarks.filter(b => b.success).length;
    const avgDuration = this.benchmarks.reduce((sum, b) => sum + b.duration, 0) / total;
    const avgThroughput = this.benchmarks.reduce((sum, b) => sum + b.throughput, 0) / total;
    const totalMemory = this.benchmarks.reduce((sum, b) => sum + b.memoryUsage, 0);

    return {
      totalTests: total,
      successRate: (successful / total) * 100,
      avgDuration,
      avgThroughput,
      totalMemoryUsage: totalMemory,
      coverage: successful >= Math.ceil(total * 0.8) ? '80/20 ACHIEVED' : 'INSUFFICIENT COVERAGE',
      benchmarks: this.benchmarks
    };
  }
}

describe('80/20 End-to-End Coverage', () => {
  let framework: E2ETestFramework;

  beforeEach(() => {
    framework = new E2ETestFramework();
  });

  afterEach(() => {
    const summary = framework.getBenchmarkSummary();
    console.log('\\n=== BENCHMARK SUMMARY ===');
    console.log(`Coverage: ${summary.coverage}`);
    console.log(`Success Rate: ${summary.successRate.toFixed(2)}%`);
    console.log(`Average Duration: ${summary.avgDuration.toFixed(2)}ms`);
    console.log(`Average Throughput: ${summary.avgThroughput.toFixed(2)} ops/sec`);
    console.log(`Total Memory Usage: ${(summary.totalMemoryUsage / 1024 / 1024).toFixed(2)}MB`);
  });

  describe('Core 80% Coverage - Critical Path Scenarios', () => {
    it('E2E-01: Basic Input-Process-Output Workflow', async () => {
      framework.startBenchmark('Basic-IPO');
      
      const reactor = createReactor()
        .input('data', { description: 'Input data' })
        .step('validate', {
          arguments: { input: arg.input('data') },
          async run({ input }) {
            if (!input || typeof input !== 'string') {
              throw new Error('Invalid input');
            }
            return { validated: true, data: input };
          }
        })
        .step('process', {
          arguments: { validated: arg.step('validate') },
          async run({ validated }) {
            return {
              processed: true,
              result: validated.data.toUpperCase(),
              timestamp: Date.now()
            };
          }
        })
        .step('output', {
          arguments: { processed: arg.step('process') },
          async run({ processed }) {
            return {
              final: processed.result,
              metadata: { timestamp: processed.timestamp }
            };
          }
        })
        .return('output')
        .build();

      const result = await reactor.execute({ data: 'hello world' });
      const benchmark = framework.endBenchmark('Basic-IPO', result, 3);

      expect(result.state).toBe('completed');
      expect(result.returnValue.final).toBe('HELLO WORLD');
      expect(benchmark.duration).toBeLessThan(100);
    });

    it('E2E-02: Parallel Processing with Dependency Convergence', async () => {
      framework.startBenchmark('Parallel-Convergence');

      const reactor = createReactor()
        .input('dataset')
        .step('process_a', {
          arguments: { data: arg.input('dataset') },
          async run({ data }) {
            await new Promise(resolve => setTimeout(resolve, 50));
            return { result: data.map((x: number) => x * 2), type: 'doubled' };
          }
        })
        .step('process_b', {
          arguments: { data: arg.input('dataset') },
          async run({ data }) {
            await new Promise(resolve => setTimeout(resolve, 30));
            return { result: data.map((x: number) => x + 10), type: 'added' };
          }
        })
        .step('process_c', {
          arguments: { data: arg.input('dataset') },
          async run({ data }) {
            await new Promise(resolve => setTimeout(resolve, 40));
            return { result: data.filter((x: number) => x > 5), type: 'filtered' };
          }
        })
        .step('merge_results', {
          arguments: {
            a: arg.step('process_a'),
            b: arg.step('process_b'),
            c: arg.step('process_c')
          },
          async run({ a, b, c }) {
            return {
              combined: {
                doubled: a.result,
                added: b.result,
                filtered: c.result
              },
              summary: `Processed ${a.result.length + b.result.length + c.result.length} items`
            };
          }
        })
        .return('merge_results')
        .build();

      const result = await reactor.execute({ dataset: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10] });
      const benchmark = framework.endBenchmark('Parallel-Convergence', result, 4);

      expect(result.state).toBe('completed');
      expect(result.returnValue.combined.doubled).toEqual([2, 4, 6, 8, 10, 12, 14, 16, 18, 20]);
      expect(benchmark.duration).toBeLessThan(100); // Should be ~50ms due to parallelism
    });

    it('E2E-03: Error Recovery with Compensation', async () => {
      framework.startBenchmark('Error-Recovery');

      let compensationCalled = false;
      let retryCount = 0;

      const reactor = createReactor()
        .input('operation_type')
        .step('risky_operation', {
          arguments: { type: arg.input('operation_type') },
          maxRetries: 2,
          async run({ type }) {
            retryCount++;
            if (type === 'fail_first_attempt' && retryCount < 3) {
              throw new Error('Temporary failure');
            }
            return { success: true, attempts: retryCount };
          },
          async compensate(error, args, context) {
            compensationCalled = true;
            if (error.message.includes('Temporary')) {
              return 'retry';
            }
            return 'abort';
          }
        })
        .step('validate_result', {
          arguments: { operation: arg.step('risky_operation') },
          async run({ operation }) {
            return {
              validated: operation.success,
              totalAttempts: operation.attempts
            };
          }
        })
        .return('validate_result')
        .build();

      const result = await reactor.execute({ operation_type: 'fail_first_attempt' });
      const benchmark = framework.endBenchmark('Error-Recovery', result);

      expect(result.state).toBe('completed');
      expect(result.returnValue.validated).toBe(true);
      expect(compensationCalled).toBe(true);
      expect(retryCount).toBe(3);
    });

    it('E2E-04: High-Throughput Batch Processing', async () => {
      framework.startBenchmark('High-Throughput');

      const batchSize = 100;
      const batches = Array.from({ length: 5 }, (_, i) => ({
        id: i,
        data: Array.from({ length: batchSize }, (_, j) => i * batchSize + j)
      }));

      const reactor = createReactor()
        .input('batches')
        .step('process_batch_0', {
          arguments: { batch: arg.value(batches[0]) },
          async run({ batch }) {
            return { id: batch.id, processed: batch.data.length, sum: batch.data.reduce((a, b) => a + b, 0) };
          }
        })
        .step('process_batch_1', {
          arguments: { batch: arg.value(batches[1]) },
          async run({ batch }) {
            return { id: batch.id, processed: batch.data.length, sum: batch.data.reduce((a, b) => a + b, 0) };
          }
        })
        .step('process_batch_2', {
          arguments: { batch: arg.value(batches[2]) },
          async run({ batch }) {
            return { id: batch.id, processed: batch.data.length, sum: batch.data.reduce((a, b) => a + b, 0) };
          }
        })
        .step('process_batch_3', {
          arguments: { batch: arg.value(batches[3]) },
          async run({ batch }) {
            return { id: batch.id, processed: batch.data.length, sum: batch.data.reduce((a, b) => a + b, 0) };
          }
        })
        .step('process_batch_4', {
          arguments: { batch: arg.value(batches[4]) },
          async run({ batch }) {
            return { id: batch.id, processed: batch.data.length, sum: batch.data.reduce((a, b) => a + b, 0) };
          }
        })
        .step('aggregate_results', {
          arguments: {
            b0: arg.step('process_batch_0'),
            b1: arg.step('process_batch_1'),
            b2: arg.step('process_batch_2'),
            b3: arg.step('process_batch_3'),
            b4: arg.step('process_batch_4')
          },
          async run({ b0, b1, b2, b3, b4 }) {
            const results = [b0, b1, b2, b3, b4];
            return {
              totalBatches: results.length,
              totalItems: results.reduce((sum, r) => sum + r.processed, 0),
              totalSum: results.reduce((sum, r) => sum + r.sum, 0),
              throughput: results.length / (Date.now() / 1000)
            };
          }
        })
        .return('aggregate_results')
        .build();

      const result = await reactor.execute({ batches });
      const benchmark = framework.endBenchmark('High-Throughput', result, 500); // 500 total items processed

      expect(result.state).toBe('completed');
      expect(result.returnValue.totalItems).toBe(500);
      expect(benchmark.throughput).toBeGreaterThan(1000); // > 1000 ops/sec
    });

    it('E2E-05: Complex Workflow with Conditional Logic', async () => {
      framework.startBenchmark('Complex-Workflow');

      const reactor = createReactor()
        .input('user_data')
        .input('permissions')
        .step('authenticate', {
          arguments: { 
            user: arg.input('user_data'),
            perms: arg.input('permissions')
          },
          async run({ user, perms }) {
            if (!user.id || !perms.includes('read')) {
              throw new Error('Authentication failed');
            }
            return { authenticated: true, userId: user.id, level: perms.includes('admin') ? 'admin' : 'user' };
          }
        })
        .step('load_profile', {
          arguments: { auth: arg.step('authenticate') },
          async run({ auth }) {
            await new Promise(resolve => setTimeout(resolve, 10));
            return {
              profile: {
                id: auth.userId,
                name: `User ${auth.userId}`,
                level: auth.level,
                preferences: { theme: 'dark', lang: 'en' }
              }
            };
          }
        })
        .step('load_data', {
          arguments: { auth: arg.step('authenticate') },
          async run({ auth }) {
            await new Promise(resolve => setTimeout(resolve, 15));
            const dataSize = auth.level === 'admin' ? 1000 : 100;
            return {
              data: Array.from({ length: dataSize }, (_, i) => ({ id: i, value: Math.random() })),
              restricted: auth.level !== 'admin'
            };
          }
        })
        .step('prepare_response', {
          arguments: {
            profile: arg.step('load_profile'),
            data: arg.step('load_data'),
            auth: arg.step('authenticate')
          },
          async run({ profile, data, auth }) {
            return {
              user: profile.profile,
              items: data.data.slice(0, auth.level === 'admin' ? 1000 : 50),
              metadata: {
                total: data.data.length,
                restricted: data.restricted,
                timestamp: Date.now()
              }
            };
          }
        })
        .return('prepare_response')
        .build();

      const result = await reactor.execute({
        user_data: { id: 'user123' },
        permissions: ['read', 'admin']
      });
      const benchmark = framework.endBenchmark('Complex-Workflow', result, 4);

      expect(result.state).toBe('completed');
      expect(result.returnValue.user.level).toBe('admin');
      expect(result.returnValue.items.length).toBe(1000);
      expect(benchmark.duration).toBeLessThan(50);
    });
  });

  describe('Edge Case 20% Coverage - Stress & Failure Scenarios', () => {
    it('E2E-06: Memory Stress Test with Large Data', async () => {
      framework.startBenchmark('Memory-Stress');

      const largeDataset = Array.from({ length: 10000 }, (_, i) => ({
        id: i,
        data: Array.from({ length: 100 }, () => Math.random()),
        metadata: { timestamp: Date.now(), batch: Math.floor(i / 1000) }
      }));

      const reactor = createReactor()
        .configure({ maxConcurrency: 3 })
        .input('dataset')
        .step('chunk_data', {
          arguments: { data: arg.input('dataset') },
          async run({ data }) {
            const chunks = [];
            for (let i = 0; i < data.length; i += 2000) {
              chunks.push(data.slice(i, i + 2000));
            }
            return { chunks, totalChunks: chunks.length };
          }
        })
        .step('process_chunk_1', {
          arguments: { chunked: arg.step('chunk_data') },
          async run({ chunked }) {
            const chunk = chunked.chunks[0] || [];
            return { processed: chunk.length, sum: chunk.reduce((sum, item) => sum + item.data.length, 0) };
          }
        })
        .step('process_chunk_2', {
          arguments: { chunked: arg.step('chunk_data') },
          async run({ chunked }) {
            const chunk = chunked.chunks[1] || [];
            return { processed: chunk.length, sum: chunk.reduce((sum, item) => sum + item.data.length, 0) };
          }
        })
        .step('process_chunk_3', {
          arguments: { chunked: arg.step('chunk_data') },
          async run({ chunked }) {
            const chunk = chunked.chunks[2] || [];
            return { processed: chunk.length, sum: chunk.reduce((sum, item) => sum + item.data.length, 0) };
          }
        })
        .step('aggregate', {
          arguments: {
            c1: arg.step('process_chunk_1'),
            c2: arg.step('process_chunk_2'),
            c3: arg.step('process_chunk_3')
          },
          async run({ c1, c2, c3 }) {
            return {
              totalProcessed: c1.processed + c2.processed + c3.processed,
              totalDataPoints: c1.sum + c2.sum + c3.sum
            };
          }
        })
        .return('aggregate')
        .build();

      const result = await reactor.execute({ dataset: largeDataset });
      const benchmark = framework.endBenchmark('Memory-Stress', result, 10000);

      expect(result.state).toBe('completed');
      expect(result.returnValue.totalProcessed).toBeGreaterThan(0);
      expect(benchmark.memoryUsage).toBeLessThan(100 * 1024 * 1024); // < 100MB
    });

    it('E2E-07: Cascading Failure Recovery', async () => {
      framework.startBenchmark('Cascading-Failure');

      let undoLog: string[] = [];

      const reactor = createReactor()
        .input('failure_mode')
        .step('step1', {
          arguments: { mode: arg.input('failure_mode') },
          async run({ mode }) {
            return { completed: 'step1', mode };
          },
          async undo(result) {
            undoLog.push(`undo-${result.completed}`);
          }
        })
        .step('step2', {
          arguments: { prev: arg.step('step1') },
          async run({ prev }) {
            return { completed: 'step2', from: prev.completed };
          },
          async undo(result) {
            undoLog.push(`undo-${result.completed}`);
          }
        })
        .step('step3', {
          arguments: { prev: arg.step('step2') },
          async run({ prev }) {
            if (prev.from === 'step1') {
              throw new Error('Forced failure in step3');
            }
            return { completed: 'step3', from: prev.completed };
          },
          async undo(result) {
            undoLog.push(`undo-${result.completed}`);
          }
        })
        .return('step3')
        .build();

      const result = await reactor.execute({ failure_mode: 'cascade' });
      const benchmark = framework.endBenchmark('Cascading-Failure', result);

      expect(result.state).toBe('failed');
      expect(undoLog).toContain('undo-step2');
      expect(undoLog).toContain('undo-step1');
      expect(result.errors.length).toBeGreaterThan(0);
    });

    it('E2E-08: Timeout and Resource Exhaustion', async () => {
      framework.startBenchmark('Timeout-Exhaustion');

      const reactor = createReactor()
        .configure({ maxConcurrency: 2, timeout: 100 })
        .input('delay_config')
        .step('quick_task', {
          arguments: { config: arg.input('delay_config') },
          timeout: 50,
          async run({ config }) {
            await new Promise(resolve => setTimeout(resolve, config.quick || 10));
            return { completed: 'quick', duration: config.quick || 10 };
          }
        })
        .step('slow_task', {
          arguments: { config: arg.input('delay_config') },
          timeout: 30,
          async run({ config }) {
            await new Promise(resolve => setTimeout(resolve, config.slow || 500));
            return { completed: 'slow', duration: config.slow || 500 };
          }
        })
        .step('combine', {
          arguments: {
            quick: arg.step('quick_task'),
            slow: arg.step('slow_task')
          },
          async run({ quick, slow }) {
            return { both: [quick, slow] };
          }
        })
        .return('combine')
        .build();

      const result = await reactor.execute({ delay_config: { quick: 20, slow: 500 } });
      const benchmark = framework.endBenchmark('Timeout-Exhaustion', result);

      expect(result.state).toBe('failed');
      expect(result.errors.some(e => e.message.includes('timeout'))).toBe(true);
    });
  });

  describe('Performance & Telemetry Validation', () => {
    it('E2E-09: Telemetry and Monitoring Integration', async () => {
      framework.startBenchmark('Telemetry-Monitoring');

      const spans: any[] = [];
      const mockTelemetryMiddleware = {
        name: 'telemetry-test',
        async beforeReactor(context: any) {
          spans.push({ type: 'reactor-start', id: context.id, timestamp: Date.now() });
        },
        async beforeStep(step: any, context: any) {
          spans.push({ type: 'step-start', step: step.name, context: context.id, timestamp: Date.now() });
        },
        async afterStep(step: any, result: any, context: any) {
          spans.push({ type: 'step-end', step: step.name, success: result.success, timestamp: Date.now() });
        },
        async afterReactor(context: any, result: any) {
          spans.push({ type: 'reactor-end', state: result.state, duration: result.duration, timestamp: Date.now() });
        }
      };

      const reactor = createReactor()
        .use(mockTelemetryMiddleware)
        .input('operations')
        .step('op1', {
          arguments: { ops: arg.input('operations') },
          async run({ ops }) {
            return { result: ops.length };
          }
        })
        .step('op2', {
          arguments: { prev: arg.step('op1') },
          async run({ prev }) {
            return { doubled: prev.result * 2 };
          }
        })
        .return('op2')
        .build();

      const result = await reactor.execute({ operations: [1, 2, 3, 4, 5] });
      const benchmark = framework.endBenchmark('Telemetry-Monitoring', result);

      expect(result.state).toBe('completed');
      expect(spans.length).toBeGreaterThan(0);
      expect(spans.filter(s => s.type === 'step-start').length).toBe(2);
      expect(spans.filter(s => s.type === 'step-end').length).toBe(2);
    });

    it('E2E-10: End-to-End Performance Benchmark', async () => {
      framework.startBenchmark('E2E-Performance');

      const operations = 50;
      const reactor = createReactor()
        .configure({ maxConcurrency: 5 })
        .input('operation_count');

      // Dynamically add steps
      for (let i = 0; i < operations; i++) {
        reactor.step(`operation_${i}`, {
          arguments: { count: arg.input('operation_count') },
          async run({ count }) {
            // Simulate CPU work
            let sum = 0;
            for (let j = 0; j < count * 1000; j++) {
              sum += Math.sqrt(j);
            }
            return { id: i, sum: Math.floor(sum) };
          }
        });
      }

      reactor.step('final_aggregate', {
        arguments: Object.fromEntries(
          Array.from({ length: operations }, (_, i) => [`op${i}`, arg.step(`operation_${i}`)])
        ),
        async run(args) {
          const results = Object.values(args) as any[];
          return {
            totalOps: results.length,
            totalSum: results.reduce((sum: number, r: any) => sum + r.sum, 0),
            avgSum: results.reduce((sum: number, r: any) => sum + r.sum, 0) / results.length
          };
        }
      });

      reactor.return('final_aggregate');
      const builtReactor = reactor.build();

      const result = await builtReactor.execute({ operation_count: 10 });
      const benchmark = framework.endBenchmark('E2E-Performance', result, operations);

      expect(result.state).toBe('completed');
      expect(result.returnValue.totalOps).toBe(operations);
      expect(benchmark.throughput).toBeGreaterThan(10); // > 10 ops/sec
      expect(benchmark.duration).toBeLessThan(5000); // < 5 seconds
    });
  });
});