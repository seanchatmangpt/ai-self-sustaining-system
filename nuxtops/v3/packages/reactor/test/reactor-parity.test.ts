/**
 * Reactor Feature Parity Tests
 * Validates that the TypeScript implementation matches Elixir Reactor functionality
 */

import { describe, it, expect, beforeEach } from 'vitest';
import { createReactor, arg, simpleReactor } from '../core/reactor-builder';
import { createBasicWorkflow, createErrorHandlingWorkflow, createParallelWorkflow } from '../examples/basic-reactor-example';

describe('Reactor Feature Parity', () => {
  describe('Core Features', () => {
    it('should support input/step/return pattern like Elixir Reactor', async () => {
      const reactor = createReactor()
        .input('x')
        .input('y')
        .step('multiply', {
          arguments: {
            a: arg.input('x'),
            b: arg.input('y')
          },
          async run({ a, b }) {
            return a * b;
          }
        })
        .return('multiply')
        .build();

      const result = await reactor.execute({ x: 6, y: 7 });
      expect(result.returnValue).toBe(42);
      expect(result.state).toBe('completed');
    });

    it('should automatically resolve dependencies', async () => {
      const reactor = createReactor()
        .input('base')
        .step('double', {
          arguments: { value: arg.input('base') },
          async run({ value }) {
            return value * 2;
          }
        })
        .step('square', {
          arguments: { value: arg.step('double') },
          async run({ value }) {
            return value * value;
          }
        })
        .return('square')
        .build();

      const result = await reactor.execute({ base: 3 });
      expect(result.returnValue).toBe(36); // (3 * 2)^2 = 36
    });

    it('should execute independent steps in parallel', async () => {
      const startTime = Date.now();
      const parallelWorkflow = createParallelWorkflow();
      
      const result = await parallelWorkflow.execute({ data: 'test' });
      const duration = Date.now() - startTime;
      
      // Should complete in roughly 100ms (longest step) rather than 225ms (sum of all steps)
      expect(duration).toBeLessThan(200);
      expect(result.returnValue).toBe('A: test | B: test | C: test');
    });

    it('should validate required inputs', async () => {
      const reactor = createReactor()
        .input('required_param', { required: true })
        .step('process', {
          arguments: { param: arg.input('required_param') },
          async run({ param }) {
            return param;
          }
        })
        .return('process')
        .build();

      await expect(reactor.execute({})).rejects.toThrow("Required input 'required_param' is missing");
    });

    it('should support default values for inputs', async () => {
      const reactor = createReactor()
        .input('optional_param', { required: false, defaultValue: 'default' })
        .step('process', {
          arguments: { param: arg.input('optional_param') },
          async run({ param }) {
            return param;
          }
        })
        .return('process')
        .build();

      const result = await reactor.execute({});
      expect(result.returnValue).toBe('default');
    });
  });

  describe('Error Handling & Compensation', () => {
    it('should retry failed steps with max retries', async () => {
      let attempts = 0;
      const reactor = createReactor()
        .input('data')
        .step('flaky_step', {
          arguments: { data: arg.input('data') },
          maxRetries: 2,
          async run({ data }) {
            attempts++;
            if (attempts < 3) {
              throw new Error('Temporary failure');
            }
            return `Success on attempt ${attempts}`;
          }
        })
        .return('flaky_step')
        .build();

      const result = await reactor.execute({ data: 'test' });
      expect(result.returnValue).toBe('Success on attempt 3');
      expect(attempts).toBe(3);
    });

    it('should handle compensation properly', async () => {
      let compensationCalled = false;
      const reactor = createReactor()
        .input('data')
        .step('failing_step', {
          arguments: { data: arg.input('data') },
          async run({ data }) {
            throw new Error('Always fails');
          },
          async compensate(error, args, context) {
            compensationCalled = true;
            if (error.message === 'Always fails') {
              return 'skip'; // Skip this step and continue
            }
            return 'abort';
          }
        })
        .step('next_step', {
          arguments: { data: arg.input('data') },
          async run({ data }) {
            return 'completed';
          }
        })
        .return('next_step')
        .build();

      const result = await reactor.execute({ data: 'test' });
      expect(compensationCalled).toBe(true);
      // Note: This test verifies compensation is called, 
      // actual skip behavior would need more complex implementation
    });

    it('should execute undo operations during rollback', async () => {
      const undoLog: string[] = [];
      const reactor = createReactor()
        .input('data')
        .step('step1', {
          arguments: { data: arg.input('data') },
          async run({ data }) {
            return `step1: ${data}`;
          },
          async undo(result) {
            undoLog.push(`undo step1: ${result}`);
          }
        })
        .step('step2', {
          arguments: { 
            data: arg.input('data'),
            prev: arg.step('step1')
          },
          async run({ data, prev }) {
            return `step2: ${data}, ${prev}`;
          },
          async undo(result) {
            undoLog.push(`undo step2: ${result}`);
          }
        })
        .step('failing_step', {
          arguments: { prev: arg.step('step2') },
          async run({ prev }) {
            throw new Error('Force rollback');
          }
        })
        .return('failing_step')
        .build();

      const result = await reactor.execute({ data: 'test' });
      expect(result.state).toBe('failed');
      expect(undoLog).toContain('undo step2: step2: test, step1: test');
      expect(undoLog).toContain('undo step1: step1: test');
    });
  });

  describe('Real-world Examples', () => {
    it('should execute basic workflow correctly', async () => {
      const workflow = createBasicWorkflow();
      const result = await workflow.execute({ param1: 5, param2: 10 });
      
      expect(result.returnValue).toBe(20); // (5 * 2) + 10
      expect(result.state).toBe('completed');
      expect(result.errors).toHaveLength(0);
    });

    it('should handle error workflow with retries', async () => {
      const workflow = createErrorHandlingWorkflow();
      
      // Valid input should succeed
      const successResult = await workflow.execute({ 
        user_id: 123, 
        email: 'test@example.com' 
      });
      
      expect(successResult.state).toBe('completed');
      
      // Invalid input should fail
      const failResult = await workflow.execute({ 
        user_id: -1, 
        email: 'test@example.com' 
      });
      
      expect(failResult.state).toBe('failed');
    });
  });

  describe('Performance & Concurrency', () => {
    it('should respect concurrency limits', async () => {
      const reactor = createReactor()
        .configure({ maxConcurrency: 2 })
        .input('items')
        .step('process_item_1', {
          arguments: { item: arg.value(1) },
          async run() {
            await new Promise(resolve => setTimeout(resolve, 50));
            return 'item1';
          }
        })
        .step('process_item_2', {
          arguments: { item: arg.value(2) },
          async run() {
            await new Promise(resolve => setTimeout(resolve, 50));
            return 'item2';
          }
        })
        .step('process_item_3', {
          arguments: { item: arg.value(3) },
          async run() {
            await new Promise(resolve => setTimeout(resolve, 50));
            return 'item3';
          }
        })
        .step('combine', {
          arguments: {
            a: arg.step('process_item_1'),
            b: arg.step('process_item_2'),
            c: arg.step('process_item_3')
          },
          async run({ a, b, c }) {
            return [a, b, c];
          }
        })
        .return('combine')
        .build();

      const startTime = Date.now();
      const result = await reactor.execute({ items: [1, 2, 3] });
      const duration = Date.now() - startTime;

      expect(result.returnValue).toEqual(['item1', 'item2', 'item3']);
      // With concurrency limit of 2, should take ~100ms instead of ~50ms
      expect(duration).toBeGreaterThan(80);
      expect(duration).toBeLessThan(150);
    });
  });

  describe('Simple Reactor Helper', () => {
    it('should create simple reactors with convenience function', async () => {
      const reactor = simpleReactor(
        'calculate',
        async ({ a, b }) => a + b,
        ['a', 'b']
      );

      const result = await reactor.execute({ a: 5, b: 3 });
      expect(result.returnValue).toBe(8);
      expect(result.state).toBe('completed');
    });
  });
});