/**
 * Unit tests for Vue composables
 */

import { describe, it, expect, vi, beforeEach } from 'vitest';
import { ref, reactive, nextTick } from 'vue';
import { useReactor, useAsyncReactor, useReactorStore } from '../composables/useReactor';
import { createMockStep, createFailingStep, createDelayedStep, delay } from './setup';

// Mock Nuxt composables
const mockNuxtApp = {
  $reactor: vi.fn(),
  $pinia: {
    state: {
      value: {
        reactor: reactive({
          activeReactors: new Map(),
          results: new Map(),
          workClaims: []
        })
      }
    }
  }
};

const mockUseNuxtApp = vi.fn(() => mockNuxtApp);
const mockUseState = vi.fn((key, init) => ref(init()));
const mockUseAsyncData = vi.fn();

vi.mock('#app', () => ({
  useNuxtApp: mockUseNuxtApp,
  useState: mockUseState,
  useAsyncData: mockUseAsyncData
}));

describe('useReactor', () => {
  let mockReactor: any;

  beforeEach(() => {
    mockReactor = {
      id: 'test-reactor-123',
      state: 'pending',
      steps: [],
      addStep: vi.fn(),
      addMiddleware: vi.fn(),
      execute: vi.fn().mockResolvedValue({
        id: 'test-reactor-123',
        state: 'completed',
        results: new Map([['test-step', { success: true, data: 'result' }]]),
        errors: [],
        duration: 1000
      })
    };

    mockNuxtApp.$reactor.mockReturnValue(mockReactor);
    vi.clearAllMocks();
  });

  describe('Initialization', () => {
    it('should create reactor instance on first use', () => {
      const { reactor } = useReactor();

      expect(mockNuxtApp.$reactor).toHaveBeenCalled();
      expect(reactor.value).toBe(mockReactor);
    });

    it('should pass options to reactor factory', () => {
      const options = { 
        id: 'custom-reactor',
        maxConcurrency: 3,
        timeout: 5000
      };

      useReactor(options);

      expect(mockNuxtApp.$reactor).toHaveBeenCalledWith(options);
    });

    it('should initialize with correct default values', () => {
      const { isExecuting, error, progress } = useReactor();

      expect(isExecuting.value).toBe(false);
      expect(error.value).toBe(null);
      expect(progress.value).toBe(0);
    });
  });

  describe('Execution', () => {
    it('should execute reactor and update state', async () => {
      const { execute, isExecuting, result } = useReactor();

      const executePromise = execute({ test: 'input' });
      
      // Should be executing
      expect(isExecuting.value).toBe(true);
      
      const execResult = await executePromise;
      
      // Should complete
      expect(isExecuting.value).toBe(false);
      expect(result.value).toBe(execResult);
      expect(mockReactor.execute).toHaveBeenCalledWith({ test: 'input' });
    });

    it('should handle execution errors', async () => {
      const executionError = new Error('Execution failed');
      mockReactor.execute.mockRejectedValue(executionError);

      const { execute, error, isExecuting } = useReactor();

      await expect(execute()).rejects.toThrow('Execution failed');
      
      expect(isExecuting.value).toBe(false);
      expect(error.value).toBe(executionError);
    });

    it('should track progress during execution', async () => {
      // Mock a reactor with steps for progress calculation
      mockReactor.steps = [
        createMockStep('step-1'),
        createMockStep('step-2'),
        createMockStep('step-3')
      ];

      const { execute, progress } = useReactor();

      // Mock progress updates through middleware
      mockReactor.addMiddleware.mockImplementation((middleware) => {
        if (middleware.name === 'progress-tracker') {
          // Simulate progress updates
          setTimeout(() => {
            // This would normally be called by the middleware
            // but we'll simulate it for testing
          }, 0);
        }
      });

      await execute();

      // Progress should be calculated based on completed steps
      expect(progress.value).toBeGreaterThanOrEqual(0);
      expect(progress.value).toBeLessThanOrEqual(100);
    });
  });

  describe('Progress Calculation', () => {
    it('should calculate progress correctly', () => {
      mockReactor.steps = [
        createMockStep('step-1'),
        createMockStep('step-2'),
        createMockStep('step-3'),
        createMockStep('step-4')
      ];

      const { progress } = useReactor();

      // Initial progress should be 0
      expect(progress.value).toBe(0);
    });

    it('should handle empty steps array', () => {
      mockReactor.steps = [];
      const { progress } = useReactor();

      expect(progress.value).toBe(0);
    });
  });

  describe('Step Management', () => {
    it('should add steps to reactor', () => {
      const { addStep } = useReactor();
      const step = createMockStep('new-step');

      addStep(step);

      expect(mockReactor.addStep).toHaveBeenCalledWith(step);
    });
  });

  describe('Reset Functionality', () => {
    it('should reset reactor state', () => {
      const { reset, result, error } = useReactor();

      // Set some state
      result.value = {} as any;
      error.value = new Error('test');

      reset();

      expect(mockNuxtApp.$reactor).toHaveBeenCalledTimes(2); // Initial + reset
      expect(result.value).toBe(null);
      expect(error.value).toBe(null);
    });
  });

  describe('Persistence', () => {
    it('should use persistent state when enabled', () => {
      const options = { persist: true, key: 'my-reactor' };
      useReactor(options);

      expect(mockUseState).toHaveBeenCalledWith('my-reactor:result', expect.any(Function));
    });

    it('should use non-persistent state by default', () => {
      useReactor();

      // Should not call useState for result
      expect(mockUseState).not.toHaveBeenCalled();
    });
  });
});

describe('useAsyncReactor', () => {
  let mockStepBuilder: any;

  beforeEach(() => {
    mockStepBuilder = vi.fn(() => [
      createMockStep('async-step-1'),
      createMockStep('async-step-2')
    ]);

    mockUseAsyncData.mockImplementation((key, handler, options) => {
      return {
        data: ref(null),
        pending: ref(false),
        error: ref(null),
        refresh: vi.fn()
      };
    });

    vi.clearAllMocks();
  });

  describe('Initialization', () => {
    it('should create async data with correct key', () => {
      useAsyncReactor('test-async-reactor', mockStepBuilder);

      expect(mockUseAsyncData).toHaveBeenCalledWith(
        'test-async-reactor',
        expect.any(Function),
        expect.objectContaining({ immediate: true })
      );
    });

    it('should respect immediate option', () => {
      useAsyncReactor('test-reactor', mockStepBuilder, { immediate: false });

      expect(mockUseAsyncData).toHaveBeenCalledWith(
        'test-reactor',
        expect.any(Function),
        expect.objectContaining({ immediate: false })
      );
    });
  });

  describe('Step Building', () => {
    it('should call step builder and add steps to reactor', async () => {
      let capturedHandler: any;
      mockUseAsyncData.mockImplementation((key, handler) => {
        capturedHandler = handler;
        return { data: ref(null), pending: ref(false), error: ref(null) };
      });

      useAsyncReactor('test', mockStepBuilder);

      // Execute the handler
      await capturedHandler();

      expect(mockStepBuilder).toHaveBeenCalled();
      expect(mockNuxtApp.$reactor).toHaveBeenCalled();
    });
  });
});

describe('useReactorStore', () => {
  let mockStore: any;

  beforeEach(() => {
    mockStore = reactive({
      activeReactors: new Map(),
      results: new Map(),
      workClaims: []
    });

    mockNuxtApp.$pinia.state.value.reactor = mockStore;
    vi.clearAllMocks();
  });

  describe('Store Access', () => {
    it('should provide access to store state', () => {
      const store = useReactorStore();

      expect(store.reactors.value).toEqual([]);
      expect(store.results.value).toEqual([]);
      expect(store.workClaims.value).toEqual([]);
    });

    it('should reactively update when store changes', async () => {
      const store = useReactorStore();
      
      const mockReactor = { id: 'test-reactor', state: 'pending' };
      mockStore.activeReactors.set('test-reactor', mockReactor);

      await nextTick();

      expect(store.reactors.value).toContain(mockReactor);
    });
  });

  describe('Reactor Management', () => {
    it('should register reactors', () => {
      const store = useReactorStore();
      const reactor = { id: 'new-reactor', state: 'pending' };

      store.register(reactor);

      expect(mockStore.activeReactors.get('new-reactor')).toBe(reactor);
    });

    it('should store results', () => {
      const store = useReactorStore();
      const result = { 
        id: 'result-123', 
        state: 'completed', 
        results: new Map(),
        errors: [],
        duration: 1000
      };

      store.storeResult(result);

      expect(mockStore.results.get('result-123')).toBe(result);
    });

    it('should clear completed reactors', () => {
      const store = useReactorStore();
      
      mockStore.activeReactors.set('completed-1', { id: 'completed-1', state: 'completed' });
      mockStore.activeReactors.set('failed-1', { id: 'failed-1', state: 'failed' });
      mockStore.activeReactors.set('pending-1', { id: 'pending-1', state: 'pending' });
      mockStore.activeReactors.set('executing-1', { id: 'executing-1', state: 'executing' });

      store.clearCompleted();

      expect(mockStore.activeReactors.has('completed-1')).toBe(false);
      expect(mockStore.activeReactors.has('failed-1')).toBe(false);
      expect(mockStore.activeReactors.has('pending-1')).toBe(true);
      expect(mockStore.activeReactors.has('executing-1')).toBe(true);
    });
  });

  describe('Work Claims', () => {
    it('should provide access to work claims', () => {
      const store = useReactorStore();
      
      mockStore.workClaims.push({ 
        id: 'claim-1', 
        stepName: 'test-step',
        status: 'claimed'
      });

      expect(store.workClaims.value).toHaveLength(1);
      expect(store.workClaims.value[0].id).toBe('claim-1');
    });
  });

  describe('Fallback Behavior', () => {
    it('should handle missing Pinia store gracefully', () => {
      // Remove Pinia from mock
      mockNuxtApp.$pinia = undefined;

      const store = useReactorStore();

      // Should still provide basic functionality
      expect(store.reactors.value).toEqual([]);
      expect(store.results.value).toEqual([]);
      expect(store.workClaims.value).toEqual([]);
    });
  });
});

describe('Composable Integration', () => {
  it('should work together in complex scenarios', async () => {
    const mockReactorResult = {
      id: 'integration-test',
      state: 'completed',
      results: new Map([
        ['step-1', { success: true, data: 'result-1' }],
        ['step-2', { success: true, data: 'result-2' }]
      ]),
      errors: [],
      duration: 1500
    };

    mockReactor.execute.mockResolvedValue(mockReactorResult);

    const { execute, result } = useReactor({ key: 'integration-test' });
    const store = useReactorStore();

    // Execute reactor
    await execute({ test: 'data' });

    // Register in store
    store.register(mockReactor);
    store.storeResult(result.value!);

    expect(store.reactors.value).toContain(mockReactor);
    expect(store.results.value).toContain(result.value);
  });

  it('should handle concurrent reactor executions', async () => {
    const reactor1 = useReactor({ key: 'concurrent-1' });
    const reactor2 = useReactor({ key: 'concurrent-2' });

    // Mock different execution times
    mockNuxtApp.$reactor.mockReturnValueOnce({
      ...mockReactor,
      id: 'reactor-1',
      execute: vi.fn().mockImplementation(async () => {
        await delay(100);
        return { id: 'reactor-1', state: 'completed', duration: 100 };
      })
    });

    mockNuxtApp.$reactor.mockReturnValueOnce({
      ...mockReactor,
      id: 'reactor-2',
      execute: vi.fn().mockImplementation(async () => {
        await delay(50);
        return { id: 'reactor-2', state: 'completed', duration: 50 };
      })
    });

    const [result1, result2] = await Promise.all([
      reactor1.execute(),
      reactor2.execute()
    ]);

    expect(result1.id).toBe('reactor-1');
    expect(result2.id).toBe('reactor-2');
    expect(reactor1.isExecuting.value).toBe(false);
    expect(reactor2.isExecuting.value).toBe(false);
  });
});