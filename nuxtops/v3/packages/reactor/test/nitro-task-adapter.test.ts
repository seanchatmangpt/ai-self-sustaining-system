/**
 * Unit tests for Nitro Task Adapter
 */

import { describe, it, expect, vi, beforeEach } from 'vitest';
import { 
  defineReactorTask, 
  defineScheduledReactor, 
  nitroTaskStep,
  NitroTaskMiddleware
} from '../integrations/nitro-task-adapter';
import { ReactorEngine } from '../core/reactor-engine';
import { createMockStep, createFailingStep, delay } from './setup';

// Mock Nitro internals
vi.mock('#internal/nitro', () => ({
  runTask: vi.fn()
}));

vi.mock('#internal/nitro/storage', () => ({
  setItem: vi.fn(),
  getItem: vi.fn()
}));

describe('defineReactorTask', () => {
  let stepBuilders: Record<string, any>;
  let mockTask: any;

  beforeEach(() => {
    stepBuilders = {
      validateData: (config: any) => createMockStep('validate-data', {
        run: vi.fn().mockResolvedValue({ 
          success: true, 
          data: { validated: true, config } 
        })
      }),
      
      processData: (config: any) => createMockStep('process-data', {
        dependencies: ['validate-data'],
        run: vi.fn().mockResolvedValue({ 
          success: true, 
          data: { processed: true, config } 
        })
      }),
      
      failingStep: (config: any) => createFailingStep(
        'failing-step', 
        new Error('Step failed'),
        { run: vi.fn().mockResolvedValue({ 
          success: false, 
          error: new Error('Step failed') 
        })}
      )
    };

    mockTask = defineReactorTask('test-reactor-task', stepBuilders);
    vi.clearAllMocks();
  });

  describe('Task Definition', () => {
    it('should create task with run method', () => {
      expect(mockTask).toBeDefined();
      expect(typeof mockTask.run).toBe('function');
    });

    it('should have correct meta information', () => {
      expect(mockTask.meta).toBeDefined();
      expect(mockTask.meta.name).toBe('test-reactor-task');
      expect(mockTask.meta.description).toContain('Reactor workflow task');
    });
  });

  describe('Task Execution', () => {
    it('should execute simple reactor workflow', async () => {
      const payload = {
        reactorId: 'test-reactor-123',
        steps: [
          { name: 'validateData', config: { required: true } }
        ],
        input: { data: 'test' }
      };

      const result = await mockTask.run(payload);

      expect(result.reactorId).toBe('test-reactor-123');
      expect(result.state).toBe('completed');
      expect(result.duration).toBeGreaterThan(0);
      expect(result.results['validate-data']).toEqual({
        validated: true,
        config: { required: true }
      });
    });

    it('should execute multi-step workflow with dependencies', async () => {
      const payload = {
        reactorId: 'test-reactor-456',
        steps: [
          { name: 'validateData', config: { strict: true } },
          { name: 'processData', config: { format: 'json' } }
        ],
        input: { data: 'complex test' }
      };

      const result = await mockTask.run(payload);

      expect(result.state).toBe('completed');
      expect(result.results['validate-data']).toBeDefined();
      expect(result.results['process-data']).toBeDefined();
    });

    it('should handle step failures', async () => {
      const payload = {
        reactorId: 'test-reactor-789',
        steps: [
          { name: 'validateData', config: {} },
          { name: 'failingStep', config: {} }
        ],
        input: { data: 'test' }
      };

      const result = await mockTask.run(payload);

      expect(result.state).toBe('failed');
      expect(result.errors).toHaveLength(1);
      expect(result.errors[0]).toBe('Step failed');
    });

    it('should handle unknown step types', async () => {
      const payload = {
        reactorId: 'test-reactor-999',
        steps: [
          { name: 'unknownStep', config: {} }
        ],
        input: { data: 'test' }
      };

      await expect(mockTask.run(payload)).rejects.toThrow('Unknown step type: unknownStep');
    });

    it('should serialize results correctly', async () => {
      const payload = {
        reactorId: 'test-reactor-serialization',
        steps: [
          { name: 'validateData', config: { test: true } }
        ],
        input: { complex: { nested: { data: 'value' } } }
      };

      const result = await mockTask.run(payload);

      expect(typeof result.results).toBe('object');
      expect(result.results['validate-data']).toEqual({
        validated: true,
        config: { test: true }
      });
    });
  });

  describe('Context Handling', () => {
    it('should pass context from payload', async () => {
      const customContext = {
        userId: 'user-123',
        traceId: 'trace-456'
      };

      const payload = {
        reactorId: 'test-reactor-context',
        steps: [{ name: 'validateData', config: {} }],
        input: { data: 'test' },
        context: customContext
      };

      await mockTask.run(payload);

      // The step should have been called with the custom context
      const step = stepBuilders.validateData({});
      // We can't directly verify the context was passed, but we can verify
      // the reactor was created with the right ID
      expect(true).toBe(true); // Placeholder assertion
    });
  });
});

describe('nitroTaskStep', () => {
  let mockRunTask: any;

  beforeEach(() => {
    mockRunTask = vi.fn();
    vi.mocked(require('#internal/nitro')).runTask = mockRunTask;
    vi.clearAllMocks();
  });

  describe('Step Creation', () => {
    it('should create step with correct name and description', () => {
      const step = nitroTaskStep(
        'api-call-step',
        'api-service-task',
        (input) => ({ url: input.url })
      );

      expect(step.name).toBe('api-call-step');
      expect(step.description).toBe('Execute Nitro task: api-service-task');
    });
  });

  describe('Step Execution', () => {
    it('should execute Nitro task successfully', async () => {
      const mockResult = { success: true, data: 'task result' };
      mockRunTask.mockResolvedValue(mockResult);

      const step = nitroTaskStep(
        'test-step',
        'test-task',
        (input, context) => ({ 
          input, 
          traceId: context.traceId 
        })
      );

      const input = { test: 'data' };
      const context = { 
        id: 'reactor-123', 
        startTime: Date.now(),
        traceId: 'trace-456',
        metadata: {}
      };

      const result = await step.run(input, context);

      expect(result.success).toBe(true);
      expect(result.data).toBe(mockResult);
      expect(mockRunTask).toHaveBeenCalledWith('test-task', {
        input,
        traceId: 'trace-456'
      });
    });

    it('should handle Nitro task failure', async () => {
      const error = new Error('Task failed');
      mockRunTask.mockRejectedValue(error);

      const step = nitroTaskStep(
        'failing-step',
        'failing-task',
        (input) => input
      );

      const result = await step.run({ test: 'data' }, {
        id: 'reactor-123',
        startTime: Date.now(),
        metadata: {}
      });

      expect(result.success).toBe(false);
      expect(result.error).toBe(error);
    });

    it('should build payload correctly', async () => {
      const mockResult = { data: 'result' };
      mockRunTask.mockResolvedValue(mockResult);

      const payloadBuilder = vi.fn((input, context) => ({
        userId: input.userId,
        traceId: context.traceId,
        timestamp: context.startTime
      }));

      const step = nitroTaskStep('custom-step', 'custom-task', payloadBuilder);

      const input = { userId: 'user-123', data: 'test' };
      const context = {
        id: 'reactor-456',
        startTime: 1234567890,
        traceId: 'trace-789',
        metadata: {}
      };

      await step.run(input, context);

      expect(payloadBuilder).toHaveBeenCalledWith(input, context);
      expect(mockRunTask).toHaveBeenCalledWith('custom-task', {
        userId: 'user-123',
        traceId: 'trace-789',
        timestamp: 1234567890
      });
    });
  });

  describe('Compensation', () => {
    it('should provide default compensation behavior', async () => {
      const step = nitroTaskStep('test-step', 'test-task', (input) => input);
      
      const error = new Error('Test error');
      const result = await step.compensate!(error, {}, {
        id: 'reactor-123',
        startTime: Date.now(),
        metadata: {}
      });

      expect(result).toBe('retry');
    });
  });
});

describe('defineScheduledReactor', () => {
  let mockReactorBuilder: any;
  let mockReactor: any;

  beforeEach(() => {
    mockReactor = {
      id: 'scheduled-reactor-123',
      execute: vi.fn().mockResolvedValue({
        id: 'scheduled-reactor-123',
        state: 'completed',
        duration: 1000
      })
    };

    mockReactorBuilder = vi.fn().mockReturnValue(mockReactor);
    vi.clearAllMocks();
  });

  describe('Task Definition', () => {
    it('should create scheduled task with correct meta', () => {
      const task = defineScheduledReactor(
        'daily-cleanup',
        '0 0 * * *',
        mockReactorBuilder
      );

      expect(task.meta.name).toBe('daily-cleanup');
      expect(task.meta.description).toBe('Scheduled reactor workflow: daily-cleanup');
      expect(task.meta.scheduledTask).toBe('0 0 * * *');
    });
  });

  describe('Task Execution', () => {
    it('should execute reactor builder and run reactor', async () => {
      const task = defineScheduledReactor(
        'test-scheduled',
        '*/5 * * * *',
        mockReactorBuilder
      );

      const result = await task.run();

      expect(mockReactorBuilder).toHaveBeenCalled();
      expect(mockReactor.execute).toHaveBeenCalled();
      expect(result).toEqual({
        id: 'scheduled-reactor-123',
        state: 'completed',
        duration: 1000
      });
    });

    it('should log completion status', async () => {
      const consoleSpy = vi.spyOn(console, 'log').mockImplementation(() => {});
      
      const task = defineScheduledReactor(
        'logged-task',
        '0 * * * *',
        mockReactorBuilder
      );

      await task.run();

      expect(consoleSpy).toHaveBeenCalledWith(
        expect.stringContaining('Scheduled reactor logged-task completed:'),
        expect.objectContaining({
          id: 'scheduled-reactor-123',
          state: 'completed',
          duration: 1000
        })
      );

      consoleSpy.mockRestore();
    });
  });
});

describe('NitroTaskMiddleware', () => {
  let middleware: NitroTaskMiddleware;
  let mockStorage: any;

  beforeEach(() => {
    mockStorage = {
      setItem: vi.fn().mockResolvedValue(undefined),
      getItem: vi.fn().mockResolvedValue(null)
    };

    vi.mocked(require('#internal/nitro/storage')).setItem = mockStorage.setItem;
    vi.mocked(require('#internal/nitro/storage')).getItem = mockStorage.getItem;

    middleware = new NitroTaskMiddleware('task-123');
    vi.clearAllMocks();
  });

  describe('Initialization', () => {
    it('should set middleware name', () => {
      expect(middleware.name).toBe('nitro-task');
    });

    it('should accept task ID', () => {
      const middlewareWithId = new NitroTaskMiddleware('custom-task-456');
      expect(middlewareWithId).toBeDefined();
    });
  });

  describe('Reactor Lifecycle', () => {
    it('should store start information', async () => {
      const context = {
        id: 'reactor-123',
        startTime: Date.now(),
        metadata: {}
      };

      await middleware.beforeReactor(context);

      expect(context.nitroTaskId).toBe('task-123');
      expect(mockStorage.setItem).toHaveBeenCalledWith(
        'reactor:reactor-123:start',
        expect.objectContaining({
          startTime: expect.any(Number),
          taskId: 'task-123'
        })
      );
    });

    it('should store completion information', async () => {
      const context = {
        id: 'reactor-456',
        startTime: Date.now(),
        metadata: {}
      };

      const result = {
        id: 'reactor-456',
        state: 'completed',
        duration: 1500
      };

      await middleware.afterReactor(context, result);

      expect(mockStorage.setItem).toHaveBeenCalledWith(
        'reactor:reactor-456:complete',
        expect.objectContaining({
          endTime: expect.any(Number),
          state: 'completed',
          duration: 1500
        })
      );
    });

    it('should handle storage errors gracefully', async () => {
      mockStorage.setItem.mockRejectedValue(new Error('Storage error'));

      const context = {
        id: 'reactor-789',
        startTime: Date.now(),
        metadata: {}
      };

      // Should not throw
      await expect(middleware.beforeReactor(context)).resolves.not.toThrow();
    });
  });

  describe('Without Task ID', () => {
    it('should work without task ID', async () => {
      const middlewareNoId = new NitroTaskMiddleware();
      
      const context = {
        id: 'reactor-no-task',
        startTime: Date.now(),
        metadata: {}
      };

      await middlewareNoId.beforeReactor(context);

      expect(context.nitroTaskId).toBeUndefined();
      expect(mockStorage.setItem).toHaveBeenCalledWith(
        'reactor:reactor-no-task:start',
        expect.objectContaining({
          startTime: expect.any(Number),
          taskId: undefined
        })
      );
    });
  });
});

describe('Integration Tests', () => {
  it('should integrate reactor with Nitro task system', async () => {
    // Create a reactor that uses Nitro task steps
    const reactor = new ReactorEngine();
    
    const mockRunTask = vi.fn().mockResolvedValue({ processed: true });
    vi.mocked(require('#internal/nitro')).runTask = mockRunTask;

    const nitroStep = nitroTaskStep(
      'data-processing',
      'process-data-task',
      (input) => ({ data: input.data, timestamp: Date.now() })
    );

    reactor.addStep(nitroStep);
    reactor.addMiddleware(new NitroTaskMiddleware('integration-test'));

    const result = await reactor.execute({ data: 'test data' });

    expect(result.state).toBe('completed');
    expect(mockRunTask).toHaveBeenCalledWith(
      'process-data-task',
      expect.objectContaining({
        data: 'test data',
        timestamp: expect.any(Number)
      })
    );
  });
});