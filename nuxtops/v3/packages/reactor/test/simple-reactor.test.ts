/**
 * Simple reactor test to verify basic functionality
 */

import { describe, it, expect, vi, beforeEach } from 'vitest';
import { ReactorEngine } from '../core/reactor-engine';

describe('Simple Reactor Test', () => {
  beforeEach(() => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date('2022-01-01'));
  });

  it('should execute a simple successful step', async () => {
    const reactor = new ReactorEngine({
      id: 'test-reactor',
      timeout: 5000
    });

    const simpleStep = {
      name: 'simple-step',
      description: 'A simple test step',
      
      async run(input: any, context: any) {
        return { 
          success: true, 
          data: { message: 'Hello from simple step', input } 
        };
      }
    };

    reactor.addStep(simpleStep);

    const result = await reactor.execute({ test: 'data' });

    expect(result.state).toBe('completed');
    expect(result.results.has('simple-step')).toBe(true);
    
    const stepResult = result.results.get('simple-step');
    expect(stepResult.success).toBe(true);
    expect(stepResult.data.message).toBe('Hello from simple step');
  });

  it('should handle step failure without compensation', async () => {
    const reactor = new ReactorEngine({
      id: 'test-reactor-fail',
      timeout: 5000
    });

    const failingStep = {
      name: 'failing-step',
      description: 'A step that fails',
      
      async run(input: any, context: any) {
        throw new Error('Test failure');
      }
    };

    reactor.addStep(failingStep);

    const result = await reactor.execute({ test: 'data' });

    expect(result.state).toBe('failed');
    expect(result.errors).toHaveLength(1);
    expect(result.errors[0].message).toBe('Test failure');
  });

  it('should handle step failure with compensation', async () => {
    const reactor = new ReactorEngine({
      id: 'test-reactor-compensate',
      timeout: 5000
    });

    const failingStep = {
      name: 'failing-step-with-compensation',
      description: 'A step that fails but has compensation',
      
      async run(input: any, context: any) {
        return { 
          success: false, 
          error: new Error('Test failure') 
        };
      },

      async compensate() {
        return 'abort';
      }
    };

    reactor.addStep(failingStep);

    const result = await reactor.execute({ test: 'data' });

    expect(result.state).toBe('failed');
    expect(result.errors).toHaveLength(1);
    expect(result.errors[0].message).toBe('Test failure');
  });
});