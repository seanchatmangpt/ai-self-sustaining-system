/**
 * Nuxt Reactor Engine - Core execution engine with DAG support
 */

import { nanoid } from 'nanoid';
import type { 
  Reactor, 
  ReactorStep, 
  ReactorMiddleware, 
  ReactorContext, 
  ReactorPlan, 
  ReactorResult, 
  ReactorOptions,
  ReactorState,
  StepResult,
  CompensationResult,
  ReactorInput,
  ArgumentSource
} from '../types';

export class ReactorEngine implements Reactor {
  id: string;
  state: ReactorState = 'pending';
  inputs: ReactorInput[] = [];
  steps: ReactorStep[] = [];
  middleware: ReactorMiddleware[] = [];
  context: ReactorContext;
  plan: ReactorPlan | null = null;
  results: Map<string, StepResult> = new Map();
  undoStack: Array<{ step: ReactorStep; result: any }> = [];
  returnStep?: string;
  
  private maxConcurrency: number;
  private timeout: number;
  private inputValues: Record<string, any> = {};
  
  constructor(options: ReactorOptions = {}) {
    this.id = options.id || `reactor_${Date.now()}${nanoid(9)}`;
    this.maxConcurrency = options.maxConcurrency || 5;
    this.timeout = options.timeout || 300000; // 5 minutes default
    
    this.context = {
      id: this.id,
      startTime: Date.now(),
      metadata: {},
      ...options.context
    };
    
    if (options.middleware) {
      this.middleware = options.middleware;
    }
  }
  
  addInput(input: ReactorInput): void {
    this.inputs.push(input);
  }
  
  addStep(step: ReactorStep): void {
    this.steps.push(step);
    this.plan = null; // Invalidate plan when adding new steps
  }
  
  setReturn(stepName: string): void {
    this.returnStep = stepName;
  }
  
  addMiddleware(middleware: ReactorMiddleware): void {
    this.middleware.push(middleware);
  }
  
  private async buildExecutionPlan(): Promise<ReactorPlan> {
    const steps = new Map<string, ReactorStep>();
    const dependencies = new Map<string, Set<string>>();
    
    // Build step map and dependency graph
    for (const step of this.steps) {
      steps.set(step.name, step);
      const stepDeps = new Set(step.dependencies || []);
      
      // Extract dependencies from arguments
      if (step.arguments) {
        for (const [_, argSource] of Object.entries(step.arguments)) {
          if (argSource.type === 'step') {
            stepDeps.add(argSource.name);
          }
        }
      }
      
      dependencies.set(step.name, stepDeps);
    }
    
    // Topological sort to determine execution order
    const executionOrder = this.topologicalSort(steps, dependencies);
    
    return {
      steps,
      dependencies,
      executionOrder
    };
  }
  
  private topologicalSort(
    steps: Map<string, ReactorStep>, 
    dependencies: Map<string, Set<string>>
  ): string[][] {
    const visited = new Set<string>();
    const visiting = new Set<string>();
    const sorted: string[] = [];
    
    const visit = (name: string) => {
      if (visited.has(name)) return;
      if (visiting.has(name)) {
        throw new Error(`Circular dependency detected: ${name}`);
      }
      
      visiting.add(name);
      
      const deps = dependencies.get(name) || new Set();
      for (const dep of deps) {
        visit(dep);
      }
      
      visiting.delete(name);
      visited.add(name);
      sorted.push(name);
    };
    
    for (const name of steps.keys()) {
      visit(name);
    }
    
    // Group steps that can run in parallel
    const levels: string[][] = [];
    const assigned = new Set<string>();
    
    while (assigned.size < sorted.length) {
      const level: string[] = [];
      
      for (const step of sorted) {
        if (assigned.has(step)) continue;
        
        const deps = dependencies.get(step) || new Set();
        const ready = Array.from(deps).every(dep => assigned.has(dep));
        
        if (ready) {
          level.push(step);
        }
      }
      
      if (level.length === 0) {
        throw new Error('Unable to resolve dependencies');
      }
      
      level.forEach(step => assigned.add(step));
      levels.push(level);
    }
    
    return levels;
  }
  
  async execute<T = any>(inputs: Record<string, any> = {}): Promise<ReactorResult<T>> {
    this.state = 'executing';
    const startTime = Date.now();
    
    try {
      // Run beforeReactor middleware
      await this.runMiddleware('beforeReactor');
      
      // Build execution plan if not already built
      if (!this.plan) {
        this.plan = await this.buildExecutionPlan();
      }
      
      // Store input values and validate required inputs
      this.inputValues = { ...inputs };
      try {
        this.validateInputs();
      } catch (error) {
        this.state = 'failed';
        throw error;
      }
      
      // Execute steps according to plan
      for (const level of this.plan.executionOrder) {
        await this.executeLevel(level);
      }
      
      this.state = 'completed';
      
      const returnResult = this.returnStep ? this.results.get(this.returnStep) : undefined;
      const returnValue = returnResult?.success ? returnResult.data : undefined;
      
      const result: ReactorResult<T> = {
        id: this.id,
        state: this.state,
        context: this.context,
        results: this.results,
        errors: [],
        duration: Date.now() - startTime,
        returnValue
      };
      
      // Run afterReactor middleware
      await this.runMiddleware('afterReactor', result);
      
      return result;
      
    } catch (error) {
      this.state = 'failed';
      
      // Run error handling middleware
      await this.runMiddleware('handleError', error);
      
      // Attempt compensation
      await this.compensate();
      
      // Reset state to failed after compensation
      this.state = 'failed';
      
      const result: ReactorResult<T> = {
        id: this.id,
        state: this.state,
        context: this.context,
        results: this.results,
        errors: [error as Error],
        duration: Date.now() - startTime
      };
      
      return result;
    }
  }
  
  private validateInputs(): void {
    for (const input of this.inputs) {
      if (!(input.name in this.inputValues)) {
        if (input.defaultValue !== undefined) {
          this.inputValues[input.name] = input.defaultValue;
        } else if (input.required !== false) {
          throw new Error(`Required input '${input.name}' is missing`);
        }
      }
    }
  }
  
  private resolveArguments(step: ReactorStep): Record<string, any> {
    const args: Record<string, any> = {};
    
    if (step.arguments) {
      for (const [argName, source] of Object.entries(step.arguments)) {
        switch (source.type) {
          case 'input':
            args[argName] = this.inputValues[source.name];
            break;
          case 'step':
            const stepResult = this.results.get(source.name);
            if (stepResult?.success) {
              args[argName] = stepResult.data;
            } else {
              throw new Error(`Failed to resolve argument '${argName}' from step '${source.name}'`);
            }
            break;
          case 'value':
            args[argName] = source.value;
            break;
        }
      }
    }
    
    return args;
  }
  
  private async executeLevel(level: string[]): Promise<void> {
    const promises = level.map(async (stepName) => {
      const step = this.plan!.steps.get(stepName)!;
      
      try {
        // Run beforeStep middleware
        await this.runMiddleware('beforeStep', step);
        
        // Resolve arguments for this step
        const args = this.resolveArguments(step);
        
        // For backward compatibility, if no arguments are defined, pass the full input
        const stepInput = step.arguments ? args : this.inputValues;
        
        // Create context with current results for step execution
        const stepContext = {
          ...this.context,
          results: this.results
        };
        
        // Execute step with timeout and retry logic
        const result = await this.executeStepWithRetry(step, stepInput, stepContext);
        
        this.results.set(stepName, result);
        
        if (result.success) {
          // Track successful steps for potential rollback
          this.undoStack.push({ step, result: result.data });
        }
        
        // Run afterStep middleware
        await this.runMiddleware('afterStep', step, result);
        
        if (!result.success) {
          throw result.error;
        }
        
      } catch (error) {
        // If we reach here, the step failed and couldn't be compensated
        throw error;
      }
    });
    
    // Execute steps with concurrency control
    await this.executeWithConcurrency(promises, this.maxConcurrency);
  }
  
  private async executeWithTimeout<T>(promise: Promise<T>, timeout: number): Promise<T> {
    return Promise.race([
      promise,
      new Promise<T>((_, reject) => 
        setTimeout(() => reject(new Error('Operation timed out')), timeout)
      )
    ]);
  }
  
  private async executeWithConcurrency<T>(
    promises: Promise<T>[], 
    maxConcurrency: number
  ): Promise<T[]> {
    if (maxConcurrency >= promises.length) {
      // If concurrency limit is higher than number of promises, execute all at once
      return Promise.all(promises);
    }
    
    const results: T[] = new Array(promises.length);
    let index = 0;
    
    const executeNext = async (): Promise<void> => {
      while (index < promises.length) {
        const currentIndex = index++;
        try {
          const result = await promises[currentIndex];
          results[currentIndex] = result;
        } catch (error) {
          // Re-throw to be handled by caller
          throw error;
        }
      }
    };
    
    // Create workers up to concurrency limit
    const workers: Promise<void>[] = [];
    for (let i = 0; i < Math.min(maxConcurrency, promises.length); i++) {
      workers.push(executeNext());
    }
    
    // Wait for all workers to complete
    await Promise.all(workers);
    return results;
  }
  
  private async executeStepWithRetry(
    step: ReactorStep, 
    args: Record<string, any>,
    context: ReactorContext
  ): Promise<StepResult> {
    const maxRetries = step.maxRetries || step.retries || 0;
    let attempts = 0;
    
    while (attempts <= maxRetries) {
      try {
        const result = await this.executeWithTimeout(
          step.run(args, context),
          step.timeout || this.timeout
        );
        
        // Wrap successful result as StepResult
        return { success: true, data: result };
        
      } catch (error) {
        attempts++;
        
        // Check if we should compensate
        if (step.compensate) {
          try {
            const compensationResult = await step.compensate(error as Error, args, context);
            // Track compensation decision in context for monitoring
            if (!this.context.compensationLog) {
              this.context.compensationLog = [];
            }
            this.context.compensationLog.push({
              stepName: step.name,
              error: error.message,
              result: compensationResult,
              timestamp: Date.now(),
              attempt: attempts
            });
            
            if (compensationResult === 'retry' && attempts <= maxRetries) {
              // Continue the retry loop
              await new Promise(resolve => setTimeout(resolve, Math.pow(2, attempts - 1) * 100));
              continue;
            } else if (compensationResult === 'skip') {
              return { success: true, data: null };
            } else if (compensationResult === 'continue') {
              return { success: true, data: null };
            } else if (typeof compensationResult === 'object' && 'continue' in compensationResult) {
              return { success: true, data: compensationResult.continue };
            } else if (compensationResult === 'abort') {
              return { success: false, error: error as Error };
            }
          } catch (compensationError) {
            // Track compensation failure in context
            if (!this.context.compensationLog) {
              this.context.compensationLog = [];
            }
            this.context.compensationLog.push({
              stepName: step.name,
              error: error.message,
              compensationError: (compensationError as Error).message,
              result: 'compensation_failed',
              timestamp: Date.now(),
              attempt: attempts
            });
            return { success: false, error: error as Error };
          }
        }
        
        if (attempts > maxRetries) {
          return { success: false, error: error as Error };
        }
        
        // Default backoff if no compensation
        await new Promise(resolve => setTimeout(resolve, Math.pow(2, attempts - 1) * 100));
      }
    }
    
    return { success: false, error: new Error(`Step ${step.name} failed after ${maxRetries} retries`) };
  }
  
  private async handleStepFailure(
    step: ReactorStep, 
    error: Error, 
    args: Record<string, any>,
    context: ReactorContext
  ): Promise<CompensationResult> {
    if (!step.compensate) {
      return 'abort';
    }
    
    try {
      const result = await step.compensate(error, args, context);
      
      // Log compensation action for debugging
      console.log(`Compensation for step '${step.name}' returned: ${result}`);
      
      return result;
    } catch (compensationError) {
      console.error(`Compensation failed for step ${step.name}:`, compensationError);
      return 'abort';
    }
  }
  
  async compensate(): Promise<void> {
    this.state = 'compensating';
    
    // Run undo operations in reverse order (LIFO)
    for (let i = this.undoStack.length - 1; i >= 0; i--) {
      const { step, result } = this.undoStack[i];
      
      if (step.undo) {
        try {
          // Track undo operation in context
          if (!this.context.undoLog) {
            this.context.undoLog = [];
          }
          this.context.undoLog.push({
            stepName: step.name,
            action: 'undo_started',
            timestamp: Date.now()
          });
          
          await step.undo(result, undefined, this.context);
          
          this.context.undoLog.push({
            stepName: step.name,
            action: 'undo_completed',
            timestamp: Date.now()
          });
        } catch (error) {
          // Track undo failure in context
          if (!this.context.undoLog) {
            this.context.undoLog = [];
          }
          this.context.undoLog.push({
            stepName: step.name,
            action: 'undo_failed',
            error: (error as Error).message,
            timestamp: Date.now()
          });
          // Continue with other undo operations even if one fails
        }
      }
    }
  }
  
  async rollback(): Promise<void> {
    await this.compensate();
    this.state = 'rolled_back';
  }
  
  private async runMiddleware(
    method: keyof ReactorMiddleware, 
    ...args: any[]
  ): Promise<void> {
    for (const mw of this.middleware) {
      const fn = mw[method] as Function;
      if (fn) {
        await fn.call(mw, this.context, ...args);
      }
    }
  }
}