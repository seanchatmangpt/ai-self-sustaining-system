/**
 * Nuxt DevTools Plugin for Reactor
 * Provides debugging and monitoring interface in Nuxt DevTools
 */

import type { NuxtDevtoolsServerContext, ServerFunctions } from '@nuxt/devtools/types';
import type { ReactorResult, ReactorContext } from '../types';

export interface ReactorDevToolsState {
  reactors: Array<{
    id: string;
    state: string;
    startTime: number;
    duration?: number;
    steps: Array<{
      name: string;
      status: 'pending' | 'running' | 'completed' | 'failed';
      duration?: number;
      error?: string;
    }>;
    context: ReactorContext;
    result?: ReactorResult;
  }>;
  performance: {
    totalExecutions: number;
    averageDuration: number;
    successRate: number;
    lastExecution?: number;
  };
  alerts: Array<{
    id: string;
    type: 'info' | 'warning' | 'error';
    message: string;
    timestamp: number;
  }>;
}

export interface ReactorDevToolsServerFunctions extends ServerFunctions {
  getReactorState(): ReactorDevToolsState;
  clearReactorHistory(): void;
  exportReactorData(format: 'json' | 'csv'): string;
  simulateReactor(config: any): Promise<ReactorResult>;
  analyzePerformance(timeframe: number): any;
}

let globalState: ReactorDevToolsState = {
  reactors: [],
  performance: {
    totalExecutions: 0,
    averageDuration: 0,
    successRate: 0
  },
  alerts: []
};

export function setupReactorDevTools(ctx: NuxtDevtoolsServerContext) {
  // Register server functions
  ctx.extendServerRpc<ReactorDevToolsServerFunctions>('reactor', {
    getReactorState() {
      return globalState;
    },
    
    clearReactorHistory() {
      globalState.reactors = [];
      globalState.alerts = [];
      return;
    },
    
    exportReactorData(format = 'json') {
      if (format === 'csv') {
        const headers = ['id', 'state', 'duration', 'stepCount', 'success'];
        const rows = globalState.reactors.map(r => [
          r.id,
          r.state,
          r.duration || 0,
          r.steps.length,
          r.result?.state === 'completed' ? 'true' : 'false'
        ].join(','));
        return [headers.join(','), ...rows].join('\\n');
      }
      
      return JSON.stringify(globalState, null, 2);
    },
    
    async simulateReactor(config) {
      // Create a test reactor execution for debugging
      const { ReactorEngine } = await import('../core/reactor-engine');
      
      const reactor = new ReactorEngine({
        id: `devtools_test_${Date.now()}`,
        context: {
          id: `devtools_test_${Date.now()}`,
          startTime: Date.now(),
          metadata: { source: 'devtools-simulation' }
        }
      });
      
      // Add test steps based on config
      if (config.steps) {
        for (const stepConfig of config.steps) {
          reactor.addStep({
            name: stepConfig.name,
            description: stepConfig.description || 'DevTools test step',
            async run(input, context) {
              // Simulate work
              await new Promise(resolve => setTimeout(resolve, stepConfig.duration || 100));
              
              if (stepConfig.shouldFail) {
                return { success: false, error: new Error('Simulated failure') };
              }
              
              return { success: true, data: { result: 'success', timestamp: Date.now() } };
            }
          });
        }
      }
      
      const result = await reactor.execute(config.input);
      updateReactorState(reactor, result);
      
      return result;
    },
    
    analyzePerformance(timeframe = 60) {
      const cutoff = Date.now() - (timeframe * 60 * 1000);
      const recentReactors = globalState.reactors.filter(r => r.startTime >= cutoff);
      
      if (recentReactors.length === 0) {
        return {
          totalExecutions: 0,
          averageDuration: 0,
          successRate: 0,
          slowestSteps: [],
          errorPatterns: []
        };
      }
      
      const totalDuration = recentReactors.reduce((sum, r) => sum + (r.duration || 0), 0);
      const successCount = recentReactors.filter(r => r.result?.state === 'completed').length;
      
      // Find slowest steps
      const allSteps = recentReactors.flatMap(r => r.steps);
      const slowestSteps = allSteps
        .filter(s => s.duration)
        .sort((a, b) => (b.duration || 0) - (a.duration || 0))
        .slice(0, 5)
        .map(s => ({ name: s.name, duration: s.duration }));
      
      // Find error patterns
      const errorSteps = allSteps.filter(s => s.status === 'failed');
      const errorPatterns = errorSteps.reduce((acc, step) => {
        acc[step.name] = (acc[step.name] || 0) + 1;
        return acc;
      }, {} as Record<string, number>);
      
      return {
        totalExecutions: recentReactors.length,
        averageDuration: totalDuration / recentReactors.length,
        successRate: successCount / recentReactors.length,
        slowestSteps,
        errorPatterns: Object.entries(errorPatterns)
          .sort(([,a], [,b]) => b - a)
          .slice(0, 5)
          .map(([name, count]) => ({ name, count }))
      };
    }
  });
  
  // Register tab in DevTools
  ctx.addCustomTab({
    name: 'reactor',
    title: 'Reactor',
    icon: 'carbon:flow',
    category: 'modules',
    view: {
      type: 'iframe',
      src: '/__nuxt_devtools__/reactor'
    }
  });
  
  return globalState;
}

/**
 * Update reactor state for DevTools
 */
export function updateReactorState(reactor: any, result?: ReactorResult): void {
  const existing = globalState.reactors.find(r => r.id === reactor.id);
  
  if (existing) {
    existing.state = reactor.state;
    existing.duration = result?.duration;
    existing.result = result;
    
    // Update step statuses
    if (result?.results) {
      result.results.forEach((stepResult, stepName) => {
        const step = existing.steps.find(s => s.name === stepName);
        if (step) {
          step.status = stepResult.success ? 'completed' : 'failed';
          step.error = stepResult.error?.message;
        }
      });
    }
  } else {
    // New reactor
    globalState.reactors.push({
      id: reactor.id,
      state: reactor.state,
      startTime: reactor.context?.startTime || Date.now(),
      duration: result?.duration,
      steps: reactor.steps?.map((step: any) => ({
        name: step.name,
        status: 'pending' as const,
        duration: undefined,
        error: undefined
      })) || [],
      context: reactor.context,
      result
    });
  }
  
  // Update performance metrics
  updatePerformanceMetrics();
  
  // Trim old reactors (keep last 100)
  if (globalState.reactors.length > 100) {
    globalState.reactors = globalState.reactors.slice(-100);
  }
  
  // Add alerts for issues
  if (result?.errors.length) {
    globalState.alerts.push({
      id: `alert_${Date.now()}`,
      type: 'error',
      message: `Reactor ${reactor.id} failed: ${result.errors[0].message}`,
      timestamp: Date.now()
    });
  }
  
  if (result?.duration && result.duration > 30000) {
    globalState.alerts.push({
      id: `alert_${Date.now()}`,
      type: 'warning',
      message: `Reactor ${reactor.id} took ${result.duration}ms to complete`,
      timestamp: Date.now()
    });
  }
  
  // Trim old alerts (keep last 50)
  if (globalState.alerts.length > 50) {
    globalState.alerts = globalState.alerts.slice(-50);
  }
}

function updatePerformanceMetrics(): void {
  const completedReactors = globalState.reactors.filter(r => r.result);
  
  if (completedReactors.length === 0) return;
  
  const totalDuration = completedReactors.reduce((sum, r) => sum + (r.duration || 0), 0);
  const successCount = completedReactors.filter(r => r.result?.state === 'completed').length;
  const lastExecution = Math.max(...completedReactors.map(r => r.startTime));
  
  globalState.performance = {
    totalExecutions: completedReactors.length,
    averageDuration: totalDuration / completedReactors.length,
    successRate: successCount / completedReactors.length,
    lastExecution
  };
}

/**
 * Middleware to automatically track reactor executions in DevTools
 */
export class DevToolsMiddleware {
  name = 'devtools';
  
  async beforeReactor(context: ReactorContext): Promise<void> {
    // Initialize reactor in DevTools
    updateReactorState({ id: context.id, state: 'executing', context, steps: [] });
  }
  
  async beforeStep(context: ReactorContext, step: any): Promise<void> {
    // Update step status
    const reactor = globalState.reactors.find(r => r.id === context.id);
    if (reactor) {
      const reactorStep = reactor.steps.find(s => s.name === step.name);
      if (reactorStep) {
        reactorStep.status = 'running';
      }
    }
  }
  
  async afterStep(context: ReactorContext, step: any, result: any): Promise<void> {
    // Update step completion
    const reactor = globalState.reactors.find(r => r.id === context.id);
    if (reactor) {
      const reactorStep = reactor.steps.find(s => s.name === step.name);
      if (reactorStep) {
        reactorStep.status = result.success ? 'completed' : 'failed';
        reactorStep.duration = result.duration;
        reactorStep.error = result.error?.message;
      }
    }
  }
  
  async afterReactor(context: ReactorContext, result: ReactorResult): Promise<void> {
    // Final update with complete result
    updateReactorState({ id: context.id, state: result.state, context }, result);
  }
  
  async handleError(context: ReactorContext, error: Error): Promise<void> {
    // Track errors
    globalState.alerts.push({
      id: `error_${Date.now()}`,
      type: 'error',
      message: `Reactor ${context.id} error: ${error.message}`,
      timestamp: Date.now()
    });
  }
}