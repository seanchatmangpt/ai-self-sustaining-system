/**
 * OpenTelemetry E2E Validation Test Suite
 * Comprehensive distributed tracing and telemetry verification
 */

import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { createReactor, arg } from '../core/reactor-builder';
import type { ReactorMiddleware } from '../types';

// Mock OpenTelemetry spans and traces
interface MockSpan {
  spanId: string;
  traceId: string;
  parentSpanId?: string;
  operationName: string;
  startTime: number;
  endTime?: number;
  status: 'ok' | 'error';
  attributes: Record<string, any>;
  events: Array<{ name: string; timestamp: number; attributes?: Record<string, any> }>;
}

interface MockTrace {
  traceId: string;
  spans: MockSpan[];
  startTime: number;
  endTime?: number;
  duration?: number;
}

class OpenTelemetryCollector {
  private spans: MockSpan[] = [];
  private traces: Map<string, MockTrace> = new Map();
  private activeSpans: Map<string, MockSpan> = new Map();

  startSpan(operationName: string, parentSpanId?: string): MockSpan {
    const spanId = `span_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
    const traceId = parentSpanId ? 
      this.findTraceIdBySpanId(parentSpanId) || `trace_${Date.now()}` : 
      `trace_${Date.now()}`;

    const span: MockSpan = {
      spanId,
      traceId,
      parentSpanId,
      operationName,
      startTime: Date.now(),
      status: 'ok',
      attributes: {},
      events: []
    };

    this.spans.push(span);
    this.activeSpans.set(spanId, span);

    // Update or create trace
    if (!this.traces.has(traceId)) {
      this.traces.set(traceId, {
        traceId,
        spans: [],
        startTime: Date.now()
      });
    }
    this.traces.get(traceId)!.spans.push(span);

    return span;
  }

  endSpan(spanId: string, status: 'ok' | 'error' = 'ok') {
    const span = this.activeSpans.get(spanId);
    if (span) {
      span.endTime = Date.now();
      span.status = status;
      this.activeSpans.delete(spanId);

      // Update trace end time
      const trace = this.traces.get(span.traceId);
      if (trace && trace.spans.every(s => s.endTime)) {
        trace.endTime = Math.max(...trace.spans.map(s => s.endTime!));
        trace.duration = trace.endTime - trace.startTime;
      }
    }
  }

  addSpanAttribute(spanId: string, key: string, value: any) {
    const span = this.activeSpans.get(spanId);
    if (span) {
      span.attributes[key] = value;
    }
  }

  addSpanEvent(spanId: string, eventName: string, attributes?: Record<string, any>) {
    const span = this.activeSpans.get(spanId);
    if (span) {
      span.events.push({
        name: eventName,
        timestamp: Date.now(),
        attributes
      });
    }
  }

  private findTraceIdBySpanId(spanId: string): string | undefined {
    const span = this.spans.find(s => s.spanId === spanId);
    return span?.traceId;
  }

  getSpans(): MockSpan[] {
    return [...this.spans];
  }

  getTraces(): MockTrace[] {
    return Array.from(this.traces.values());
  }

  getTraceById(traceId: string): MockTrace | undefined {
    return this.traces.get(traceId);
  }

  reset() {
    this.spans = [];
    this.traces.clear();
    this.activeSpans.clear();
  }

  // Validation methods
  validateTraceCompleteness(traceId: string): { isComplete: boolean; missingSpans: string[]; errors: string[] } {
    const trace = this.getTraceById(traceId);
    if (!trace) {
      return { isComplete: false, missingSpans: [], errors: ['Trace not found'] };
    }

    const errors: string[] = [];
    const missingSpans: string[] = [];

    // Check all spans have end times
    trace.spans.forEach(span => {
      if (!span.endTime) {
        missingSpans.push(span.spanId);
      }
      if (span.status === 'error') {
        errors.push(`Span ${span.spanId} has error status`);
      }
    });

    return {
      isComplete: missingSpans.length === 0 && errors.length === 0,
      missingSpans,
      errors
    };
  }

  validateSpanHierarchy(traceId: string): { isValid: boolean; errors: string[] } {
    const trace = this.getTraceById(traceId);
    if (!trace) {
      return { isValid: false, errors: ['Trace not found'] };
    }

    const errors: string[] = [];
    const spanMap = new Map(trace.spans.map(s => [s.spanId, s]));

    trace.spans.forEach(span => {
      if (span.parentSpanId) {
        const parent = spanMap.get(span.parentSpanId);
        if (!parent) {
          errors.push(`Span ${span.spanId} references non-existent parent ${span.parentSpanId}`);
        } else if (parent.startTime > span.startTime) {
          errors.push(`Span ${span.spanId} starts before its parent ${span.parentSpanId}`);
        } else if (parent.endTime && span.endTime && parent.endTime < span.endTime) {
          errors.push(`Span ${span.spanId} ends after its parent ${span.parentSpanId}`);
        }
      }
    });

    return { isValid: errors.length === 0, errors };
  }
}

// OpenTelemetry Middleware for Reactor
function createTelemetryMiddleware(collector: OpenTelemetryCollector): ReactorMiddleware {
  const spanStack: string[] = [];

  return {
    name: 'opentelemetry-middleware',

    async beforeReactor(context) {
      const rootSpan = collector.startSpan(`reactor.${context.id}`);
      collector.addSpanAttribute(rootSpan.spanId, 'reactor.id', context.id);
      collector.addSpanAttribute(rootSpan.spanId, 'reactor.startTime', context.startTime);
      spanStack.push(rootSpan.spanId);
      
      // Store span context for steps
      context.rootSpanId = rootSpan.spanId;
      context.traceId = rootSpan.traceId;
    },

    async beforeStep(step, context) {
      const parentSpanId = context.rootSpanId;
      const stepSpan = collector.startSpan(`step.${step.name}`, parentSpanId);
      
      collector.addSpanAttribute(stepSpan.spanId, 'step.name', step.name);
      collector.addSpanAttribute(stepSpan.spanId, 'step.description', step.description || '');
      collector.addSpanAttribute(stepSpan.spanId, 'step.timeout', step.timeout || 0);
      collector.addSpanAttribute(stepSpan.spanId, 'step.retries', step.retries || 0);
      
      if (step.dependencies) {
        collector.addSpanAttribute(stepSpan.spanId, 'step.dependencies', step.dependencies.join(','));
      }

      collector.addSpanEvent(stepSpan.spanId, 'step.started');
      context.currentStepSpanId = stepSpan.spanId;
    },

    async afterStep(step, result, context) {
      if (context.currentStepSpanId) {
        collector.addSpanAttribute(context.currentStepSpanId, 'step.success', result.success);
        
        if (result.success) {
          collector.addSpanEvent(context.currentStepSpanId, 'step.completed');
        } else {
          collector.addSpanAttribute(context.currentStepSpanId, 'step.error', result.error?.message || 'Unknown error');
          collector.addSpanEvent(context.currentStepSpanId, 'step.failed', {
            error: result.error?.message || 'Unknown error'
          });
        }

        collector.endSpan(context.currentStepSpanId, result.success ? 'ok' : 'error');
        delete context.currentStepSpanId;
      }
    },

    async afterReactor(context, result) {
      if (context.rootSpanId) {
        collector.addSpanAttribute(context.rootSpanId, 'reactor.state', result.state);
        collector.addSpanAttribute(context.rootSpanId, 'reactor.duration', result.duration);
        collector.addSpanAttribute(context.rootSpanId, 'reactor.errorCount', result.errors.length);
        
        if (result.errors.length > 0) {
          collector.addSpanEvent(context.rootSpanId, 'reactor.errors', {
            errorCount: result.errors.length,
            errors: result.errors.map(e => e.message).join(', ')
          });
        }

        collector.addSpanEvent(context.rootSpanId, 'reactor.completed');
        collector.endSpan(context.rootSpanId, result.state === 'completed' ? 'ok' : 'error');
        spanStack.pop();
      }
    },

    async handleError(error, context) {
      if (context.currentStepSpanId) {
        collector.addSpanEvent(context.currentStepSpanId, 'error.occurred', {
          error: error.message,
          stack: error.stack
        });
      }
      if (context.rootSpanId) {
        collector.addSpanEvent(context.rootSpanId, 'reactor.error', {
          error: error.message
        });
      }
    }
  };
}

describe('OpenTelemetry E2E Validation', () => {
  let collector: OpenTelemetryCollector;
  let telemetryMiddleware: ReactorMiddleware;

  beforeEach(() => {
    collector = new OpenTelemetryCollector();
    telemetryMiddleware = createTelemetryMiddleware(collector);
  });

  afterEach(() => {
    const traces = collector.getTraces();
    console.log(`\\n=== TELEMETRY SUMMARY ===`);
    console.log(`Total Traces: ${traces.length}`);
    console.log(`Total Spans: ${collector.getSpans().length}`);
    
    traces.forEach(trace => {
      const validation = collector.validateTraceCompleteness(trace.traceId);
      const hierarchy = collector.validateSpanHierarchy(trace.traceId);
      console.log(`Trace ${trace.traceId}: Complete=${validation.isComplete}, Valid=${hierarchy.isValid}, Duration=${trace.duration}ms`);
    });
  });

  describe('Distributed Tracing Validation', () => {
    it('OTEL-01: Should create complete trace for basic workflow', async () => {
      const reactor = createReactor()
        .use(telemetryMiddleware)
        .input('data')
        .step('process', {
          arguments: { input: arg.input('data') },
          async run({ input }) {
            return { processed: input.toUpperCase() };
          }
        })
        .return('process')
        .build();

      const result = await reactor.execute({ data: 'test' });
      
      expect(result.state).toBe('completed');
      
      const traces = collector.getTraces();
      expect(traces.length).toBe(1);
      
      const trace = traces[0];
      const validation = collector.validateTraceCompleteness(trace.traceId);
      const hierarchy = collector.validateSpanHierarchy(trace.traceId);
      
      expect(validation.isComplete).toBe(true);
      expect(hierarchy.isValid).toBe(true);
      expect(trace.spans.length).toBe(2); // reactor + step
      
      // Verify span attributes
      const reactorSpan = trace.spans.find(s => s.operationName.startsWith('reactor.'));
      const stepSpan = trace.spans.find(s => s.operationName === 'step.process');
      
      expect(reactorSpan).toBeDefined();
      expect(stepSpan).toBeDefined();
      expect(stepSpan!.parentSpanId).toBe(reactorSpan!.spanId);
      expect(stepSpan!.attributes['step.name']).toBe('process');
      expect(stepSpan!.attributes['step.success']).toBe(true);
    });

    it('OTEL-02: Should maintain trace context across parallel steps', async () => {
      const reactor = createReactor()
        .use(telemetryMiddleware)
        .input('data')
        .step('step1', {
          arguments: { data: arg.input('data') },
          async run({ data }) {
            await new Promise(resolve => setTimeout(resolve, 10));
            return { result: data + '_1' };
          }
        })
        .step('step2', {
          arguments: { data: arg.input('data') },
          async run({ data }) {
            await new Promise(resolve => setTimeout(resolve, 15));
            return { result: data + '_2' };
          }
        })
        .step('step3', {
          arguments: { data: arg.input('data') },
          async run({ data }) {
            await new Promise(resolve => setTimeout(resolve, 5));
            return { result: data + '_3' };
          }
        })
        .step('combine', {
          arguments: {
            r1: arg.step('step1'),
            r2: arg.step('step2'),
            r3: arg.step('step3')
          },
          async run({ r1, r2, r3 }) {
            return { combined: [r1.result, r2.result, r3.result] };
          }
        })
        .return('combine')
        .build();

      const result = await reactor.execute({ data: 'test' });
      
      expect(result.state).toBe('completed');
      
      const traces = collector.getTraces();
      expect(traces.length).toBe(1);
      
      const trace = traces[0];
      expect(trace.spans.length).toBe(5); // reactor + 4 steps
      
      // All spans should have the same trace ID
      const traceIds = new Set(trace.spans.map(s => s.traceId));
      expect(traceIds.size).toBe(1);
      
      // Verify parallel execution timing
      const step1Span = trace.spans.find(s => s.operationName === 'step.step1')!;
      const step2Span = trace.spans.find(s => s.operationName === 'step.step2')!;
      const step3Span = trace.spans.find(s => s.operationName === 'step.step3')!;
      
      // Steps 1, 2, 3 should start around the same time (parallel execution)
      const startTimes = [step1Span.startTime, step2Span.startTime, step3Span.startTime];
      const timeRange = Math.max(...startTimes) - Math.min(...startTimes);
      expect(timeRange).toBeLessThan(50); // Within 50ms of each other
    });

    it('OTEL-03: Should capture error traces and compensation flows', async () => {
      let compensationCalled = false;

      const reactor = createReactor()
        .use(telemetryMiddleware)
        .input('should_fail')
        .step('risky_step', {
          arguments: { fail: arg.input('should_fail') },
          async run({ fail }) {
            if (fail) {
              throw new Error('Intentional failure for testing');
            }
            return { success: true };
          },
          async compensate(error, args, context) {
            compensationCalled = true;
            return 'retry';
          }
        })
        .step('next_step', {
          arguments: { prev: arg.step('risky_step') },
          async run({ prev }) {
            return { final: prev.success };
          }
        })
        .return('next_step')
        .build();

      const result = await reactor.execute({ should_fail: true });
      
      expect(result.state).toBe('failed');
      expect(compensationCalled).toBe(true);
      
      const traces = collector.getTraces();
      expect(traces.length).toBe(1);
      
      const trace = traces[0];
      const riskyStepSpan = trace.spans.find(s => s.operationName === 'step.risky_step');
      
      expect(riskyStepSpan).toBeDefined();
      expect(riskyStepSpan!.status).toBe('error');
      expect(riskyStepSpan!.attributes['step.success']).toBe(false);
      expect(riskyStepSpan!.attributes['step.error']).toContain('Intentional failure');
      
      // Verify error events
      const errorEvents = riskyStepSpan!.events.filter(e => e.name.includes('error') || e.name.includes('failed'));
      expect(errorEvents.length).toBeGreaterThan(0);
    });

    it('OTEL-04: Should validate span timing and performance metrics', async () => {
      const reactor = createReactor()
        .use(telemetryMiddleware)
        .input('iterations')
        .step('cpu_intensive', {
          arguments: { count: arg.input('iterations') },
          async run({ count }) {
            // Simulate CPU work
            let sum = 0;
            for (let i = 0; i < count * 10000; i++) {
              sum += Math.sqrt(i);
            }
            return { sum: Math.floor(sum), iterations: count };
          }
        })
        .step('io_simulation', {
          arguments: { prev: arg.step('cpu_intensive') },
          async run({ prev }) {
            // Simulate I/O delay
            await new Promise(resolve => setTimeout(resolve, 50));
            return { delayed: true, previousSum: prev.sum };
          }
        })
        .return('io_simulation')
        .build();

      const result = await reactor.execute({ iterations: 100 });
      
      expect(result.state).toBe('completed');
      
      const traces = collector.getTraces();
      const trace = traces[0];
      
      const cpuSpan = trace.spans.find(s => s.operationName === 'step.cpu_intensive')!;
      const ioSpan = trace.spans.find(s => s.operationName === 'step.io_simulation')!;
      
      // Verify span timing
      expect(cpuSpan.endTime! - cpuSpan.startTime).toBeGreaterThan(0);
      expect(ioSpan.endTime! - ioSpan.startTime).toBeGreaterThanOrEqual(50);
      
      // Verify dependency timing (IO should start after CPU ends)
      expect(ioSpan.startTime).toBeGreaterThanOrEqual(cpuSpan.endTime!);
      
      // Verify total trace duration
      expect(trace.duration).toBeGreaterThan(50);
    });

    it('OTEL-05: Should handle high-volume span generation', async () => {
      const stepCount = 20;
      const reactor = createReactor()
        .use(telemetryMiddleware)
        .input('base_value');

      // Dynamically create a chain of steps
      for (let i = 0; i < stepCount; i++) {
        const isFirst = i === 0;
        reactor.step(`step_${i}`, {
          arguments: isFirst ? 
            { value: arg.input('base_value') } : 
            { prev: arg.step(`step_${i - 1}`) },
          async run(args) {
            const value = isFirst ? args.value : args.prev.value;
            return { value: value + 1, step: i };
          }
        });
      }

      reactor.return(`step_${stepCount - 1}`);
      const builtReactor = reactor.build();

      const result = await builtReactor.execute({ base_value: 0 });
      
      expect(result.state).toBe('completed');
      expect(result.returnValue.value).toBe(stepCount);
      
      const traces = collector.getTraces();
      const trace = traces[0];
      
      // Verify all spans are present
      expect(trace.spans.length).toBe(stepCount + 1); // steps + reactor
      
      // Verify trace completeness and hierarchy
      const validation = collector.validateTraceCompleteness(trace.traceId);
      const hierarchy = collector.validateSpanHierarchy(trace.traceId);
      
      expect(validation.isComplete).toBe(true);
      expect(hierarchy.isValid).toBe(true);
      
      // Verify sequential execution order
      const stepSpans = trace.spans
        .filter(s => s.operationName.startsWith('step.step_'))
        .sort((a, b) => a.startTime - b.startTime);
      
      for (let i = 1; i < stepSpans.length; i++) {
        expect(stepSpans[i].startTime).toBeGreaterThanOrEqual(stepSpans[i - 1].endTime!);
      }
    });
  });

  describe('Trace Correlation and Propagation', () => {
    it('OTEL-06: Should correlate traces across reactor boundaries', async () => {
      // Simulate distributed system with multiple reactors
      const reactor1 = createReactor()
        .use(telemetryMiddleware)
        .input('data')
        .step('prepare', {
          arguments: { data: arg.input('data') },
          async run({ data }) {
            return { prepared: data, timestamp: Date.now() };
          }
        })
        .return('prepare')
        .build();

      const reactor2 = createReactor()
        .use(telemetryMiddleware)
        .input('prepared_data')
        .step('process', {
          arguments: { data: arg.input('prepared_data') },
          async run({ data }) {
            return { processed: data.prepared.toUpperCase(), originalTimestamp: data.timestamp };
          }
        })
        .return('process')
        .build();

      // Execute first reactor
      const result1 = await reactor1.execute({ data: 'test' });
      expect(result1.state).toBe('completed');

      // Execute second reactor with result from first
      const result2 = await reactor2.execute({ prepared_data: result1.returnValue });
      expect(result2.state).toBe('completed');

      const traces = collector.getTraces();
      expect(traces.length).toBe(2);

      // Each trace should be complete and valid
      traces.forEach(trace => {
        const validation = collector.validateTraceCompleteness(trace.traceId);
        const hierarchy = collector.validateSpanHierarchy(trace.traceId);
        expect(validation.isComplete).toBe(true);
        expect(hierarchy.isValid).toBe(true);
      });
    });
  });
});