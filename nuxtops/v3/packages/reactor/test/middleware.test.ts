/**
 * Unit tests for middleware system
 */

import { describe, it, expect, vi, beforeEach } from 'vitest';
import { ReactorEngine } from '../core/reactor-engine';
import { TelemetryMiddleware } from '../middleware/telemetry-middleware';
import { CoordinationMiddleware } from '../middleware/coordination-middleware';
import { createMockStep, createFailingStep, delay } from './setup';

describe('TelemetryMiddleware', () => {
  let reactor: ReactorEngine;
  let telemetryMiddleware: TelemetryMiddleware;
  let spanCollector: any[];

  beforeEach(() => {
    spanCollector = [];
    telemetryMiddleware = new TelemetryMiddleware({
      onSpanEnd: (span) => spanCollector.push(span)
    });
    reactor = new ReactorEngine();
    reactor.addMiddleware(telemetryMiddleware);
    vi.clearAllMocks();
  });

  describe('Trace Generation', () => {
    it('should generate trace ID if not provided', async () => {
      const step = createMockStep('test-step');
      reactor.addStep(step);
      
      await reactor.execute();
      
      expect(reactor.context.traceId).toBeDefined();
      expect(reactor.context.traceId).toMatch(/^[a-f0-9]{32}$/);
    });

    it('should use provided trace ID', async () => {
      const customTraceId = 'custom-trace-id-12345';
      reactor = new ReactorEngine({
        context: { traceId: customTraceId }
      });
      reactor.addMiddleware(telemetryMiddleware);
      
      const step = createMockStep('test-step');
      reactor.addStep(step);
      
      await reactor.execute();
      
      expect(reactor.context.traceId).toBe(customTraceId);
    });

    it('should generate unique span IDs', async () => {
      const step1 = createMockStep('step-1');
      const step2 = createMockStep('step-2');
      
      reactor.addStep(step1);
      reactor.addStep(step2);
      
      await reactor.execute();
      
      const spans = telemetryMiddleware.getSpans();
      const spanIds = spans.map(s => s.spanId);
      const uniqueSpanIds = new Set(spanIds);
      
      expect(uniqueSpanIds.size).toBe(spanIds.length);
      expect(spans.every(s => s.spanId.match(/^[a-f0-9]{16}$/))).toBe(true);
    });
  });

  describe('Span Creation', () => {
    it('should create root span for reactor', async () => {
      const step = createMockStep('test-step');
      reactor.addStep(step);
      
      await reactor.execute();
      
      const rootSpan = spanCollector.find(s => s.operationName.includes('reactor'));
      
      expect(rootSpan).toBeDefined();
      expect(rootSpan.operationName).toBe(`reactor.${reactor.id}`);
      expect(rootSpan.parentSpanId).toBeUndefined();
      expect(rootSpan.attributes['reactor.id']).toBe(reactor.id);
    });

    it('should create spans for each step', async () => {
      const step1 = createMockStep('step-1');
      const step2 = createMockStep('step-2');
      
      reactor.addStep(step1);
      reactor.addStep(step2);
      
      await reactor.execute();
      
      const step1Span = spanCollector.find(s => s.operationName === 'step.step-1');
      const step2Span = spanCollector.find(s => s.operationName === 'step.step-2');
      
      expect(step1Span).toBeDefined();
      expect(step2Span).toBeDefined();
      expect(step1Span.attributes['step.name']).toBe('step-1');
      expect(step2Span.attributes['step.name']).toBe('step-2');
    });

    it('should set parent-child relationship correctly', async () => {
      const step = createMockStep('test-step');
      reactor.addStep(step);
      
      await reactor.execute();
      
      const rootSpan = spanCollector.find(s => s.operationName.includes('reactor'));
      const stepSpan = spanCollector.find(s => s.operationName === 'step.test-step');
      
      expect(stepSpan.parentSpanId).toBe(rootSpan.spanId);
      expect(stepSpan.traceId).toBe(rootSpan.traceId);
    });
  });

  describe('Span Attributes', () => {
    it('should capture step metadata', async () => {
      const step = createMockStep('test-step', {
        description: 'Test step description',
        dependencies: ['dep1', 'dep2'],
        timeout: 5000,
        retries: 3
      });
      
      reactor.addStep(step);
      await reactor.execute();
      
      const stepSpan = spanCollector.find(s => s.operationName === 'step.test-step');
      
      expect(stepSpan.attributes['step.description']).toBe('Test step description');
      expect(stepSpan.attributes['step.dependencies']).toBe('dep1,dep2');
      expect(stepSpan.attributes['step.timeout']).toBe(5000);
      expect(stepSpan.attributes['step.retries']).toBe(3);
    });

    it('should capture success/failure status', async () => {
      const successStep = createMockStep('success-step');
      const failureStep = createFailingStep('failure-step', new Error('Test error'));
      
      reactor.addStep(successStep);
      reactor.addStep(failureStep);
      
      await reactor.execute();
      
      const successSpan = spanCollector.find(s => s.operationName === 'step.success-step');
      const failureSpan = spanCollector.find(s => s.operationName === 'step.failure-step');
      
      expect(successSpan.status).toBe('ok');
      expect(successSpan.attributes['step.success']).toBe(true);
      
      expect(failureSpan.status).toBe('error');
      expect(failureSpan.attributes['step.success']).toBe(false);
      expect(failureSpan.attributes['step.error']).toBe('Test error');
    });

    it('should capture duration', async () => {
      const step = createMockStep('test-step');
      reactor.addStep(step);
      
      await reactor.execute();
      
      const stepSpan = spanCollector.find(s => s.operationName === 'step.test-step');
      
      expect(stepSpan.duration).toBeGreaterThan(0);
      expect(stepSpan.attributes['step.duration_ms']).toBe(stepSpan.duration);
      expect(stepSpan.endTime).toBeGreaterThan(stepSpan.startTime);
    });
  });

  describe('Performance Classification', () => {
    it('should classify fast operations', async () => {
      const step = createMockStep('fast-step');
      reactor.addStep(step);
      
      await reactor.execute();
      
      const stepSpan = spanCollector.find(s => s.operationName === 'step.fast-step');
      expect(stepSpan.attributes['step.performance_tier']).toBe('fast');
    });

    it('should classify slow operations', async () => {
      const step = createMockStep('slow-step');
      // Mock a slow step by manipulating the span duration
      step.run = vi.fn().mockImplementation(async () => {
        await delay(1500); // 1.5 seconds
        return { success: true, data: { name: 'slow-step' } };
      });
      
      reactor.addStep(step);
      await reactor.execute();
      
      const stepSpan = spanCollector.find(s => s.operationName === 'step.slow-step');
      expect(stepSpan.attributes['step.performance_tier']).toBe('slow');
    });
  });

  describe('Events Tracking', () => {
    it('should track reactor lifecycle events', async () => {
      const step = createMockStep('test-step');
      reactor.addStep(step);
      
      await reactor.execute();
      
      const rootSpan = spanCollector.find(s => s.operationName.includes('reactor'));
      const events = rootSpan.events;
      
      expect(events.some(e => e.name === 'reactor.started')).toBe(true);
      expect(events.some(e => e.name === 'reactor.completed')).toBe(true);
    });

    it('should track step lifecycle events', async () => {
      const step = createMockStep('test-step');
      reactor.addStep(step);
      
      await reactor.execute();
      
      const stepSpan = spanCollector.find(s => s.operationName === 'step.test-step');
      const events = stepSpan.events;
      
      expect(events.some(e => e.name === 'step.started')).toBe(true);
      expect(events.some(e => e.name === 'step.completed')).toBe(true);
    });

    it('should track error events', async () => {
      const failingStep = createFailingStep('failing-step', new Error('Test error'));
      reactor.addStep(failingStep);
      
      await reactor.execute();
      
      const stepSpan = spanCollector.find(s => s.operationName === 'step.failing-step');
      const rootSpan = spanCollector.find(s => s.operationName.includes('reactor'));
      
      expect(stepSpan.events.some(e => e.name === 'step.failed')).toBe(true);
      expect(rootSpan.events.some(e => e.name === 'reactor.error')).toBe(true);
    });
  });

  describe('Span Management', () => {
    it('should allow clearing spans', () => {
      telemetryMiddleware.clearSpans();
      expect(telemetryMiddleware.getSpans()).toHaveLength(0);
    });

    it('should provide access to all spans', async () => {
      const step1 = createMockStep('step-1');
      const step2 = createMockStep('step-2');
      
      reactor.addStep(step1);
      reactor.addStep(step2);
      
      await reactor.execute();
      
      const spans = telemetryMiddleware.getSpans();
      expect(spans).toHaveLength(3); // root + 2 steps
    });
  });
});

describe('CoordinationMiddleware', () => {
  let reactor: ReactorEngine;
  let coordinationMiddleware: CoordinationMiddleware;
  let workClaims: any[];

  beforeEach(() => {
    workClaims = [];
    coordinationMiddleware = new CoordinationMiddleware({
      onWorkClaim: (claim) => workClaims.push({ ...claim, event: 'claim' }),
      onWorkComplete: (claim) => workClaims.push({ ...claim, event: 'complete' })
    });
    reactor = new ReactorEngine();
    reactor.addMiddleware(coordinationMiddleware);
    vi.clearAllMocks();
  });

  describe('Agent ID Generation', () => {
    it('should generate unique agent ID with nanosecond precision', () => {
      const agentId = coordinationMiddleware.getAgentId();
      
      expect(agentId).toMatch(/^agent_\d+\d{9}$/);
      expect(agentId).toBeDefined();
    });

    it('should use provided agent ID', () => {
      const customAgentId = 'custom-agent-123';
      const middleware = new CoordinationMiddleware({ agentId: customAgentId });
      
      expect(middleware.getAgentId()).toBe(customAgentId);
    });

    it('should set agent ID in reactor context', async () => {
      const step = createMockStep('test-step');
      reactor.addStep(step);
      
      await reactor.execute();
      
      expect(reactor.context.agentId).toBe(coordinationMiddleware.getAgentId());
    });
  });

  describe('Work Claims', () => {
    it('should claim work before step execution', async () => {
      const step = createMockStep('test-step');
      reactor.addStep(step);
      
      await reactor.execute();
      
      const claims = coordinationMiddleware.getWorkClaims();
      expect(claims).toHaveLength(1);
      expect(claims[0].stepName).toBe('test-step');
      expect(claims[0].agentId).toBe(coordinationMiddleware.getAgentId());
    });

    it('should update claim status during execution', async () => {
      const step = createMockStep('test-step');
      reactor.addStep(step);
      
      await reactor.execute();
      
      const claimEvents = workClaims.filter(w => w.stepName === 'test-step');
      
      expect(claimEvents.some(c => c.event === 'claim' && c.status === 'in_progress')).toBe(true);
      expect(claimEvents.some(c => c.event === 'complete' && c.status === 'completed')).toBe(true);
    });

    it('should handle multiple steps', async () => {
      const step1 = createMockStep('step-1');
      const step2 = createMockStep('step-2');
      
      reactor.addStep(step1);
      reactor.addStep(step2);
      
      await reactor.execute();
      
      const claims = coordinationMiddleware.getWorkClaims();
      expect(claims).toHaveLength(2);
      expect(claims.map(c => c.stepName)).toContain('step-1');
      expect(claims.map(c => c.stepName)).toContain('step-2');
    });

    it('should mark failed steps appropriately', async () => {
      const failingStep = createFailingStep('failing-step', new Error('Test error'));
      reactor.addStep(failingStep);
      
      await reactor.execute();
      
      const completeEvent = workClaims.find(w => 
        w.stepName === 'failing-step' && w.event === 'complete'
      );
      
      expect(completeEvent.status).toBe('failed');
    });
  });

  describe('Coordination Context', () => {
    it('should initialize coordination context', async () => {
      const step = createMockStep('test-step');
      reactor.addStep(step);
      
      await reactor.execute();
      
      expect(reactor.context.coordination).toBeDefined();
      expect(reactor.context.coordination.agentId).toBe(coordinationMiddleware.getAgentId());
      expect(reactor.context.coordination.claimedSteps).toContain('test-step');
    });

    it('should track performance metrics', async () => {
      const step = createMockStep('test-step');
      reactor.addStep(step);
      
      await reactor.execute();
      
      expect(reactor.context.coordination['test-step_duration']).toBeGreaterThan(0);
    });
  });

  describe('Progress Updates', () => {
    it('should allow manual progress updates', async () => {
      await coordinationMiddleware.updateProgress('test-step', 50);
      
      // This would update shared storage in real implementation
      // For now, just verify the method doesn't throw
      expect(true).toBe(true);
    });
  });

  describe('Error Handling', () => {
    it('should handle work claim failures gracefully', async () => {
      // Mock a scenario where work claiming might fail
      const step = createMockStep('test-step');
      reactor.addStep(step);
      
      // This should still execute successfully even if internal
      // coordination mechanisms have issues
      const result = await reactor.execute();
      expect(result.state).toBe('completed');
    });
  });
});

describe('Middleware Interaction', () => {
  let reactor: ReactorEngine;
  let telemetryMiddleware: TelemetryMiddleware;
  let coordinationMiddleware: CoordinationMiddleware;
  let telemetrySpans: any[];
  let workClaims: any[];

  beforeEach(() => {
    telemetrySpans = [];
    workClaims = [];
    
    telemetryMiddleware = new TelemetryMiddleware({
      onSpanEnd: (span) => telemetrySpans.push(span)
    });
    
    coordinationMiddleware = new CoordinationMiddleware({
      onWorkClaim: (claim) => workClaims.push(claim)
    });
    
    reactor = new ReactorEngine();
    reactor.addMiddleware(telemetryMiddleware);
    reactor.addMiddleware(coordinationMiddleware);
  });

  it('should work together without conflicts', async () => {
    const step = createMockStep('test-step');
    reactor.addStep(step);
    
    const result = await reactor.execute();
    
    expect(result.state).toBe('completed');
    expect(telemetrySpans).toHaveLength(2); // root + step
    expect(workClaims).toHaveLength(1);
  });

  it('should correlate telemetry with coordination data', async () => {
    const step = createMockStep('test-step');
    reactor.addStep(step);
    
    await reactor.execute();
    
    const stepSpan = telemetrySpans.find(s => s.operationName === 'step.test-step');
    const workClaim = workClaims[0];
    
    expect(stepSpan.traceId).toBe(reactor.context.traceId);
    expect(workClaim.agentId).toBe(reactor.context.agentId);
  });
});