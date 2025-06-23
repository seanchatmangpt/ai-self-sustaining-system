/**
 * Reactor Builder - Factory pattern for creating Reactors with declarative API
 * Mimics Elixir's `use Reactor` pattern with TypeScript adaptations
 */

import { ReactorEngine } from './reactor-engine';
import type { 
  ReactorInput, 
  ReactorStep, 
  ReactorMiddleware, 
  ReactorOptions, 
  ArgumentSource,
  Reactor
} from '../types';

export class ReactorBuilder {
  private inputs: ReactorInput[] = [];
  private steps: ReactorStep[] = [];
  private middleware: ReactorMiddleware[] = [];
  private returnStep?: string;
  private options: ReactorOptions = {};

  /**
   * Define an input parameter for the reactor
   */
  input(name: string, options: Partial<ReactorInput> = {}): ReactorBuilder {
    this.inputs.push({
      name,
      required: true,
      ...options
    });
    return this;
  }

  /**
   * Define a step in the reactor workflow
   */
  step(name: string, config: {
    description?: string;
    timeout?: number;
    retries?: number;
    maxRetries?: number;
    arguments?: Record<string, ArgumentSource>;
    run: (args: Record<string, any>, context: any) => Promise<any>;
    compensate?: (error: Error, args: Record<string, any>, context: any) => Promise<string>;
    undo?: (result: any, args: Record<string, any>, context: any) => Promise<void>;
  }): ReactorBuilder {
    const step: ReactorStep = {
      name,
      description: config.description,
      timeout: config.timeout,
      retries: config.retries,
      maxRetries: config.maxRetries,
      arguments: config.arguments,
      async run(args, context) {
        // Let errors bubble up to the executeStepWithRetry function
        // which will handle compensation and retry logic
        return await config.run(args, context);
      },
      compensate: config.compensate ? async (error, args, context) => {
        const result = await config.compensate!(error, args, context);
        return result as any;
      } : undefined,
      undo: config.undo
    };

    this.steps.push(step);
    return this;
  }

  /**
   * Add middleware to the reactor
   */
  use(middleware: ReactorMiddleware): ReactorBuilder {
    this.middleware.push(middleware);
    return this;
  }

  /**
   * Set the return value of the reactor (which step's result to return)
   */
  return(stepName: string): ReactorBuilder {
    this.returnStep = stepName;
    return this;
  }

  /**
   * Set reactor options
   */
  configure(options: ReactorOptions): ReactorBuilder {
    this.options = { ...this.options, ...options };
    return this;
  }

  /**
   * Build the reactor
   */
  build(): Reactor {
    const reactor = new ReactorEngine(this.options);
    
    // Add inputs
    this.inputs.forEach(input => reactor.addInput(input));
    
    // Add steps
    this.steps.forEach(step => reactor.addStep(step));
    
    // Add middleware
    this.middleware.forEach(mw => reactor.addMiddleware(mw));
    
    // Set return step
    if (this.returnStep) {
      reactor.setReturn(this.returnStep);
    }
    
    return reactor;
  }
}

/**
 * Helper functions for creating argument sources
 */
export const arg = {
  /**
   * Reference an input parameter
   */
  input: (name: string): ArgumentSource => ({ type: 'input', name }),
  
  /**
   * Reference another step's result
   */
  step: (name: string): ArgumentSource => ({ type: 'step', name }),
  
  /**
   * Use a literal value
   */
  value: (value: any): ArgumentSource => ({ type: 'value', value })
};

/**
 * Factory function to create a new reactor builder
 */
export function createReactor(): ReactorBuilder {
  return new ReactorBuilder();
}

/**
 * Convenience function for common reactor patterns
 */
export function simpleReactor<T = any>(
  name: string,
  fn: (inputs: Record<string, any>) => Promise<T>,
  inputNames: string[] = []
): Reactor {
  const builder = createReactor();
  
  // Add inputs
  inputNames.forEach(inputName => {
    builder.input(inputName);
  });
  
  // Add single step
  builder.step(name, {
    description: `Execute ${name}`,
    async run(args) {
      return await fn(args);
    }
  });
  
  // Return the step result
  builder.return(name);
  
  return builder.build();
}