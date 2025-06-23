/**
 * Unit tests for ReactorEngine core functionality
 */

import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { ReactorEngine } from '../core/reactor-engine';
import {
  createMockStep,
  createFailingStep,
  createDelayedStep,
  createConditionalStep,
  createStepWithUndo,
  createStepWithCompensation,
  createMockMiddleware,
  expectStepCalled,
  expectStepNotCalled,
  expectUndoCalled,
  expectCompensateCalled,
  delay,
  PerformanceTracker
} from './setup';

describe('ReactorEngine', () => {
  let reactor: ReactorEngine;
  let performanceTracker: PerformanceTracker;

  beforeEach(() => {
    reactor = new ReactorEngine();
    performanceTracker = new PerformanceTracker();
    vi.clearAllMocks();
  });

  afterEach(() => {
    performanceTracker.clear();
  });

  describe('Basic Functionality', () => {
    it('should create reactor with unique ID', () => {
      expect(reactor.id).toBeDefined();
      expect(reactor.id).toMatch(/^reactor_\d+/);
    });

    it('should initialize with correct default state', () => {
      expect(reactor.state).toBe('pending');
      expect(reactor.steps).toEqual([]);
      expect(reactor.middleware).toEqual([]);
      expect(reactor.results.size).toBe(0);
    });

    it('should allow adding steps', () => {
      const step = createMockStep('test-step');
      reactor.addStep(step);
      
      expect(reactor.steps).toHaveLength(1);
      expect(reactor.steps[0]).toBe(step);
    });

    it('should allow adding middleware', () => {
      const middleware = createMockMiddleware('test-middleware');
      reactor.addMiddleware(middleware);
      
      expect(reactor.middleware).toHaveLength(1);
      expect(reactor.middleware[0]).toBe(middleware);
    });
  });

  describe('Step Execution', () => {
    it('should execute single step successfully', async () => {
      const step = createMockStep('single-step');
      reactor.addStep(step);
      
      const result = await reactor.execute({ test: 'input' });
      
      expect(result.state).toBe('completed');
      expect(result.duration).toBeGreaterThan(0);
      expectStepCalled(step);
    });

    it('should execute multiple independent steps in parallel', async () => {
      const step1 = createDelayedStep('step-1', 100);
      const step2 = createDelayedStep('step-2', 100);
      const step3 = createDelayedStep('step-3', 100);
      
      reactor.addStep(step1);
      reactor.addStep(step2);
      reactor.addStep(step3);
      
      performanceTracker.mark('start');
      await reactor.execute();
      performanceTracker.mark('end');
      
      const duration = performanceTracker.measure('start', 'end');
      
      // Should execute in parallel, so total time should be ~100ms, not ~300ms
      expect(duration).toBeLessThan(200);
      expectStepCalled(step1);
      expectStepCalled(step2);
      expectStepCalled(step3);
    });

    it('should respect step dependencies', async () => {
      const step1 = createMockStep('step-1');
      const step2 = createMockStep('step-2', { dependencies: ['step-1'] });
      const step3 = createMockStep('step-3', { dependencies: ['step-2'] });
      
      reactor.addStep(step1);
      reactor.addStep(step2);
      reactor.addStep(step3);
      
      const result = await reactor.execute();
      
      expect(result.state).toBe('completed');
      expectStepCalled(step1);
      expectStepCalled(step2);
      expectStepCalled(step3);
      
      // Verify execution order
      const step1CallTime = (step1.run as any).mock.invocationCallOrder[0];
      const step2CallTime = (step2.run as any).mock.invocationCallOrder[0];
      const step3CallTime = (step3.run as any).mock.invocationCallOrder[0];
      
      expect(step1CallTime).toBeLessThan(step2CallTime);
      expect(step2CallTime).toBeLessThan(step3CallTime);
    });

    it('should handle circular dependencies', async () => {
      const step1 = createMockStep('step-1', { dependencies: ['step-2'] });
      const step2 = createMockStep('step-2', { dependencies: ['step-1'] });
      
      reactor.addStep(step1);
      reactor.addStep(step2);
      
      await expect(reactor.execute()).rejects.toThrow('Circular dependency detected');
    });

    it('should pass input and context to steps', async () => {
      const input = { test: 'data' };
      const step = createMockStep('test-step');
      
      reactor.addStep(step);
      await reactor.execute(input);
      
      expect(step.run).toHaveBeenCalledWith(
        input,
        expect.objectContaining({
          id: reactor.id,
          startTime: expect.any(Number)
        })
      );
    });

    it('should store step results', async () => {
      const step = createMockStep('test-step');
      reactor.addStep(step);
      
      const result = await reactor.execute();
      
      expect(result.results.has('test-step')).toBe(true);
      expect(result.results.get('test-step')).toEqual({
        success: true,
        data: { name: 'test-step' }
      });
    });
  });

  describe('Error Handling', () => {
    it('should handle step failure', async () => {
      const error = new Error('Step failed');
      const failingStep = createFailingStep('failing-step', error);
      
      reactor.addStep(failingStep);
      
      const result = await reactor.execute();
      
      expect(result.state).toBe('failed');
      expect(result.errors).toHaveLength(1);
      expect(result.errors[0]).toBe(error);
    });

    it('should call compensation on step failure', async () => {
      const step = createStepWithCompensation('failing-step', 'retry');
      reactor.addStep(step);
      
      await reactor.execute();
      
      expectCompensateCalled(step);
    });

    it('should handle timeout', async () => {
      const step = createDelayedStep('slow-step', 2000, { timeout: 100 });
      reactor.addStep(step);
      
      const result = await reactor.execute();
      
      expect(result.state).toBe('failed');
      expect(result.errors[0].message).toContain('timeout');
    });

    it('should respect concurrency limits', async () => {
      const concurrencyLimit = 2;
      reactor = new ReactorEngine({ maxConcurrency: concurrencyLimit });
      
      const steps = Array.from({ length: 5 }, (_, i) => 
        createDelayedStep(`step-${i}`, 100)
      );
      
      steps.forEach(step => reactor.addStep(step));
      
      performanceTracker.mark('start');
      await reactor.execute();
      performanceTracker.mark('end');
      
      const duration = performanceTracker.measure('start', 'end');
      
      // With concurrency limit of 2, 5 steps should take ~300ms (3 batches)
      expect(duration).toBeGreaterThan(250);
      expect(duration).toBeLessThan(400);
    });
  });

  describe('Compensation and Rollback', () => {
    it('should call undo on successful steps when reactor fails', async () => {
      const successStep = createStepWithUndo('success-step');
      const failingStep = createFailingStep('failing-step', new Error('Failed'));
      
      // Make failing step depend on success step
      failingStep.dependencies = ['success-step'];
      
      reactor.addStep(successStep);
      reactor.addStep(failingStep);
      
      await reactor.execute();
      
      expectUndoCalled(successStep);
    });

    it('should handle compensation strategies', async () => {
      const retryStep = createStepWithCompensation('retry-step', 'retry');
      const skipStep = createStepWithCompensation('skip-step', 'skip');
      const abortStep = createStepWithCompensation('abort-step', 'abort');
      
      reactor.addStep(retryStep);
      await reactor.execute();
      expect(reactor.state).toBe('failed'); // Retry still fails
      
      reactor = new ReactorEngine();
      reactor.addStep(skipStep);
      await reactor.execute();
      expect(reactor.state).toBe('failed'); // Skip continues but overall failed
      
      reactor = new ReactorEngine();
      reactor.addStep(abortStep);
      await reactor.execute();
      expect(reactor.state).toBe('failed'); // Abort stops execution
    });

    it('should execute rollback manually', async () => {
      const step = createStepWithUndo('test-step');
      reactor.addStep(step);
      
      await reactor.execute();
      await reactor.rollback();
      
      expect(reactor.state).toBe('rolled_back');
      expectUndoCalled(step);
    });
  });

  describe('DAG Resolution', () => {
    it('should build correct execution plan', async () => {
      const stepA = createMockStep('A');
      const stepB = createMockStep('B', { dependencies: ['A'] });
      const stepC = createMockStep('C', { dependencies: ['A'] });
      const stepD = createMockStep('D', { dependencies: ['B', 'C'] });
      
      reactor.addStep(stepA);
      reactor.addStep(stepB);
      reactor.addStep(stepC);
      reactor.addStep(stepD);
      
      const result = await reactor.execute();
      
      expect(result.state).toBe('completed');
      
      // Verify execution order: A first, then B and C in parallel, then D
      const callOrder = [stepA, stepB, stepC, stepD].map(step => 
        (step.run as any).mock.invocationCallOrder[0]
      );
      
      expect(callOrder[0]).toBeLessThan(callOrder[1]); // A before B
      expect(callOrder[0]).toBeLessThan(callOrder[2]); // A before C
      expect(callOrder[1]).toBeLessThan(callOrder[3]); // B before D
      expect(callOrder[2]).toBeLessThan(callOrder[3]); // C before D
    });

    it('should handle complex dependency graph', async () => {
      // Create a diamond dependency pattern
      const root = createMockStep('root');
      const left = createMockStep('left', { dependencies: ['root'] });
      const right = createMockStep('right', { dependencies: ['root'] });
      const merge = createMockStep('merge', { dependencies: ['left', 'right'] });
      
      reactor.addStep(root);
      reactor.addStep(left);
      reactor.addStep(right);
      reactor.addStep(merge);
      
      const result = await reactor.execute();
      expect(result.state).toBe('completed');
      
      // All steps should be called
      expectStepCalled(root);
      expectStepCalled(left);
      expectStepCalled(right);
      expectStepCalled(merge);
    });
  });

  describe('Middleware Integration', () => {
    it('should call middleware hooks in correct order', async () => {
      const middleware = createMockMiddleware('test-middleware');
      const step = createMockStep('test-step');
      
      reactor.addMiddleware(middleware);
      reactor.addStep(step);
      
      const result = await reactor.execute();
      
      expect(middleware.beforeReactor).toHaveBeenCalledBefore(middleware.beforeStep as any);
      expect(middleware.beforeStep).toHaveBeenCalledBefore(middleware.afterStep as any);
      expect(middleware.afterStep).toHaveBeenCalledBefore(middleware.afterReactor as any);
      
      expect(middleware.beforeReactor).toHaveBeenCalledWith(
        expect.objectContaining({ id: reactor.id })
      );
      expect(middleware.afterReactor).toHaveBeenCalledWith(
        expect.objectContaining({ id: reactor.id }),
        result
      );
    });

    it('should call error handler on failure', async () => {
      const middleware = createMockMiddleware('test-middleware');
      const error = new Error('Test error');
      const failingStep = createFailingStep('failing-step', error);
      
      reactor.addMiddleware(middleware);
      reactor.addStep(failingStep);
      
      await reactor.execute();
      
      expect(middleware.handleError).toHaveBeenCalledWith(
        error,
        expect.objectContaining({ id: reactor.id })
      );
    });
  });

  describe('Performance', () => {
    it('should complete simple workflow within reasonable time', async () => {
      const steps = Array.from({ length: 10 }, (_, i) => 
        createMockStep(`step-${i}`)
      );
      steps.forEach(step => reactor.addStep(step));
      
      performanceTracker.mark('start');
      const result = await reactor.execute();
      performanceTracker.mark('end');
      
      const duration = performanceTracker.measure('start', 'end');
      
      expect(result.state).toBe('completed');
      expect(duration).toBeLessThan(100); // Should complete in under 100ms
    });

    it('should handle large number of steps efficiently', async () => {
      const stepCount = 100;
      const steps = Array.from({ length: stepCount }, (_, i) => 
        createMockStep(`step-${i}`)
      );
      steps.forEach(step => reactor.addStep(step));
      
      performanceTracker.mark('start');
      const result = await reactor.execute();
      performanceTracker.mark('end');
      
      const duration = performanceTracker.measure('start', 'end');
      
      expect(result.state).toBe('completed');
      expect(result.results.size).toBe(stepCount);
      expect(duration).toBeLessThan(1000); // Should complete in under 1 second
    });
  });

  describe('Edge Cases', () => {
    it('should handle empty reactor execution', async () => {
      const result = await reactor.execute();
      
      expect(result.state).toBe('completed');
      expect(result.results.size).toBe(0);
    });

    it('should handle missing dependencies gracefully', async () => {
      const step = createMockStep('dependent-step', { 
        dependencies: ['non-existent-step'] 
      });
      reactor.addStep(step);
      
      await expect(reactor.execute()).rejects.toThrow();
    });

    it('should handle step with no run method', async () => {
      const invalidStep = { name: 'invalid-step' } as any;
      reactor.addStep(invalidStep);
      
      await expect(reactor.execute()).rejects.toThrow();
    });

    it('should handle middleware throwing errors', async () => {
      const faultyMiddleware = {
        name: 'faulty',
        beforeReactor: vi.fn().mockRejectedValue(new Error('Middleware error'))
      };
      
      reactor.addMiddleware(faultyMiddleware);
      reactor.addStep(createMockStep('test-step'));
      
      const result = await reactor.execute();
      expect(result.state).toBe('failed');
    });
  });
});