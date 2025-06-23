/**
 * Telemetry Middleware for Nuxt Reactor
 * Provides OpenTelemetry integration for distributed tracing
 */

import type { ReactorMiddleware, ReactorContext, ReactorStep, StepResult, ReactorResult } from '../types';

interface TelemetrySpan {
  traceId: string;
  spanId: string;
  parentSpanId?: string;
  operationName: string;
  startTime: number;
  endTime?: number;
  duration?: number;
  status: 'ok' | 'error';
  attributes: Record<string, any>;
  events: Array<{
    name: string;
    timestamp: number;
    attributes?: Record<string, any>;
  }>;
}

export class TelemetryMiddleware implements ReactorMiddleware {
  name = 'telemetry';
  private spans: Map<string, TelemetrySpan> = new Map();
  private onSpanEnd?: (span: TelemetrySpan) => void;
  
  constructor(options?: { onSpanEnd?: (span: TelemetrySpan) => void }) {
    this.onSpanEnd = options?.onSpanEnd;
  }
  
  async beforeReactor(context: ReactorContext): Promise<void> {
    // Generate trace ID if not provided
    if (!context.traceId) {
      context.traceId = this.generateTraceId();
    }
    
    // Create root span for reactor
    const rootSpan: TelemetrySpan = {
      traceId: context.traceId,
      spanId: this.generateSpanId(),
      operationName: `reactor.${context.id}`,
      startTime: Date.now(),
      status: 'ok',
      attributes: {
        'reactor.id': context.id,
        'reactor.start_time': context.startTime,
        ...context.metadata
      },
      events: []
    };
    
    context.spanId = rootSpan.spanId;
    this.spans.set('root', rootSpan);
    
    // Add reactor start event
    rootSpan.events.push({
      name: 'reactor.started',
      timestamp: Date.now(),
      attributes: {
        'reactor.id': context.id
      }
    });
  }
  
  async beforeStep(step: ReactorStep, context: ReactorContext): Promise<void> {
    const parentSpanId = context.spanId;
    const stepSpan: TelemetrySpan = {
      traceId: context.traceId!,
      spanId: this.generateSpanId(),
      parentSpanId,
      operationName: `step.${step.name}`,
      startTime: Date.now(),
      status: 'ok',
      attributes: {
        'step.name': step.name,
        'step.description': step.description || '',
        'step.dependencies': (step.dependencies || []).join(','),
        'step.timeout': step.timeout || 0,
        'step.retries': step.retries || 0
      },
      events: []
    };
    
    this.spans.set(step.name, stepSpan);
    
    // Add step start event
    stepSpan.events.push({
      name: 'step.started',
      timestamp: Date.now(),
      attributes: {
        'step.name': step.name
      }
    });
  }
  
  async afterStep(step: ReactorStep, result: StepResult, context: ReactorContext): Promise<void> {
    const stepSpan = this.spans.get(step.name);
    if (!stepSpan) return;
    
    stepSpan.endTime = Date.now();
    stepSpan.duration = stepSpan.endTime - stepSpan.startTime;
    stepSpan.status = result.success ? 'ok' : 'error';
    
    // Add result attributes
    stepSpan.attributes['step.success'] = result.success;
    stepSpan.attributes['step.duration_ms'] = stepSpan.duration;
    
    if (result.success) {
      stepSpan.attributes['step.result_type'] = typeof result.data;
      
      // Add step completed event
      stepSpan.events.push({
        name: 'step.completed',
        timestamp: Date.now(),
        attributes: {
          'step.name': step.name,
          'step.duration_ms': stepSpan.duration
        }
      });
    } else {
      stepSpan.attributes['step.error'] = result.error.message;
      stepSpan.attributes['step.error_stack'] = result.error.stack;
      
      // Add step failed event
      stepSpan.events.push({
        name: 'step.failed',
        timestamp: Date.now(),
        attributes: {
          'step.name': step.name,
          'step.error': result.error.message
        }
      });
    }
    
    // Classify performance
    const performanceTier = this.classifyPerformance(stepSpan.duration);
    stepSpan.attributes['step.performance_tier'] = performanceTier;
    
    // Emit span
    if (this.onSpanEnd) {
      this.onSpanEnd(stepSpan);
    }
  }
  
  async afterReactor(context: ReactorContext, result: ReactorResult): Promise<void> {
    const rootSpan = this.spans.get('root');
    if (!rootSpan) return;
    
    rootSpan.endTime = Date.now();
    rootSpan.duration = rootSpan.endTime - rootSpan.startTime;
    rootSpan.status = result.state === 'completed' ? 'ok' : 'error';
    
    // Add result attributes
    rootSpan.attributes['reactor.state'] = result.state;
    rootSpan.attributes['reactor.duration_ms'] = result.duration;
    rootSpan.attributes['reactor.steps_count'] = result.results.size;
    rootSpan.attributes['reactor.errors_count'] = result.errors.length;
    
    // Add reactor completed event
    rootSpan.events.push({
      name: 'reactor.completed',
      timestamp: Date.now(),
      attributes: {
        'reactor.id': context.id,
        'reactor.state': result.state,
        'reactor.duration_ms': result.duration
      }
    });
    
    // Emit root span
    if (this.onSpanEnd) {
      this.onSpanEnd(rootSpan);
    }
  }
  
  async handleError(error: Error, context: ReactorContext): Promise<void> {
    const rootSpan = this.spans.get('root');
    if (!rootSpan) return;
    
    rootSpan.status = 'error';
    rootSpan.attributes['reactor.error'] = error.message;
    rootSpan.attributes['reactor.error_stack'] = error.stack;
    
    // Add error event
    rootSpan.events.push({
      name: 'reactor.error',
      timestamp: Date.now(),
      attributes: {
        'error.message': error.message,
        'error.type': error.constructor.name
      }
    });
  }
  
  private generateTraceId(): string {
    // Generate 128-bit trace ID (32 hex chars)
    return Array.from({ length: 32 }, () => 
      Math.floor(Math.random() * 16).toString(16)
    ).join('');
  }
  
  private generateSpanId(): string {
    // Generate 64-bit span ID (16 hex chars)
    return Array.from({ length: 16 }, () => 
      Math.floor(Math.random() * 16).toString(16)
    ).join('');
  }
  
  private classifyPerformance(durationMs: number): string {
    if (durationMs < 100) return 'fast';
    if (durationMs < 1000) return 'normal';
    if (durationMs < 5000) return 'slow';
    return 'very_slow';
  }
  
  getSpans(): TelemetrySpan[] {
    return Array.from(this.spans.values());
  }
  
  clearSpans(): void {
    this.spans.clear();
  }
}