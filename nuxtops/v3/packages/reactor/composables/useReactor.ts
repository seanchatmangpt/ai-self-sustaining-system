/**
 * Vue Composable for Reactor Pattern
 * Provides reactive reactor execution with Nuxt integration
 */

import { ref, computed, type Ref } from 'vue';
import { useNuxtApp, useState, useAsyncData } from '#app';
import type { Reactor, ReactorResult, ReactorOptions, ReactorStep } from '../types';

export interface UseReactorOptions extends ReactorOptions {
  persist?: boolean;
  key?: string;
}

export interface UseReactorReturn {
  reactor: Ref<Reactor | null>;
  result: Ref<ReactorResult | null>;
  isExecuting: Ref<boolean>;
  error: Ref<Error | null>;
  progress: Ref<number>;
  execute: <T = any>(input?: T) => Promise<ReactorResult>;
  reset: () => void;
  addStep: (step: ReactorStep) => void;
}

export function useReactor(options?: UseReactorOptions): UseReactorReturn {
  const nuxtApp = useNuxtApp();
  const key = options?.key || 'reactor';
  
  // State management
  const reactor = ref<Reactor | null>(null);
  const result = options?.persist ? useState<ReactorResult | null>(`${key}:result`, () => null) : ref<ReactorResult | null>(null);
  const isExecuting = ref(false);
  const error = ref<Error | null>(null);
  const completedSteps = ref(0);
  
  // Create reactor instance
  if (!reactor.value) {
    reactor.value = nuxtApp.$reactor(options);
  }
  
  // Progress computation
  const progress = computed(() => {
    if (!reactor.value || reactor.value.steps.length === 0) return 0;
    return (completedSteps.value / reactor.value.steps.length) * 100;
  });
  
  // Execute reactor
  const execute = async <T = any>(input?: T): Promise<ReactorResult> => {
    isExecuting.value = true;
    error.value = null;
    completedSteps.value = 0;
    
    try {
      // Track progress through middleware
      reactor.value!.addMiddleware({
        name: 'progress-tracker',
        async afterStep() {
          completedSteps.value++;
        }
      });
      
      const execResult = await reactor.value!.execute(input);
      result.value = execResult;
      
      return execResult;
    } catch (err) {
      error.value = err as Error;
      throw err;
    } finally {
      isExecuting.value = false;
    }
  };
  
  // Reset reactor
  const reset = () => {
    if (nuxtApp.$reactor) {
      reactor.value = nuxtApp.$reactor(options);
    }
    result.value = null;
    error.value = null;
    completedSteps.value = 0;
  };
  
  // Add step helper
  const addStep = (step: ReactorStep) => {
    reactor.value?.addStep(step);
  };
  
  return {
    reactor: reactor as Ref<Reactor>,
    result,
    isExecuting,
    error,
    progress,
    execute,
    reset,
    addStep
  };
}

/**
 * Composable for server-side reactor execution with data fetching
 */
export function useAsyncReactor<T = any>(
  key: string,
  stepBuilder: () => ReactorStep[],
  options?: UseReactorOptions & { immediate?: boolean }
) {
  return useAsyncData(
    key,
    async () => {
      const nuxtApp = useNuxtApp();
      const reactor = nuxtApp.$reactor(options);
      
      // Add steps
      const steps = stepBuilder();
      steps.forEach(step => reactor.addStep(step));
      
      // Execute and return result
      const result = await reactor.execute();
      return result;
    },
    {
      immediate: options?.immediate ?? true
    }
  );
}

/**
 * Composable for reactive reactor state with Pinia integration
 */
export function useReactorStore() {
  const nuxtApp = useNuxtApp();
  
  // Get or create reactor store
  const store = nuxtApp.$pinia?.state.value.reactor || reactive({
    activeReactors: new Map<string, Reactor>(),
    results: new Map<string, ReactorResult>(),
    workClaims: []
  });
  
  return {
    // Get all active reactors
    reactors: computed(() => Array.from(store.activeReactors.values())),
    
    // Get all results
    results: computed(() => Array.from(store.results.values())),
    
    // Get work claims
    workClaims: computed(() => store.workClaims),
    
    // Register a reactor
    register(reactor: Reactor) {
      store.activeReactors.set(reactor.id, reactor);
    },
    
    // Store a result
    storeResult(result: ReactorResult) {
      store.results.set(result.id, result);
    },
    
    // Clear completed reactors
    clearCompleted() {
      store.activeReactors.forEach((reactor, id) => {
        if (reactor.state === 'completed' || reactor.state === 'failed') {
          store.activeReactors.delete(id);
        }
      });
    }
  };
}