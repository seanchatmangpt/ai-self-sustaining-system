/**
 * Nuxt Reactor Pattern - Core Type Definitions
 * Based on Ash Framework's reactor pattern with TypeScript adaptations
 */

export type ReactorState = 'pending' | 'executing' | 'completed' | 'failed' | 'compensating' | 'rolled_back';

export type StepResult<T = any> = {
  success: true;
  data: T;
} | {
  success: false;
  error: Error;
  compensate?: boolean;
};

export type CompensationResult = 'retry' | 'skip' | 'abort' | 'continue' | { continue: any };
export type ArgumentSource = { type: 'input'; name: string } | { type: 'step'; name: string } | { type: 'value'; value: any };

export interface ReactorContext {
  id: string;
  startTime: number;
  metadata: Record<string, any>;
  traceId?: string;
  spanId?: string;
  [key: string]: any;
}

export interface ReactorStep<TInput = any, TOutput = any> {
  name: string;
  description?: string;
  dependencies?: string[];
  timeout?: number;
  retries?: number;
  maxRetries?: number;
  arguments?: Record<string, ArgumentSource>;
  
  run(args: Record<string, any>, context: ReactorContext): Promise<StepResult<TOutput>>;
  compensate?(error: Error, args: Record<string, any>, context: ReactorContext): Promise<CompensationResult>;
  undo?(result: TOutput, args: Record<string, any>, context: ReactorContext): Promise<void>;
}

export interface ReactorMiddleware {
  name: string;
  
  beforeReactor?(context: ReactorContext): Promise<void>;
  beforeStep?(step: ReactorStep, context: ReactorContext): Promise<void>;
  afterStep?(step: ReactorStep, result: StepResult, context: ReactorContext): Promise<void>;
  afterReactor?(context: ReactorContext, result: ReactorResult): Promise<void>;
  handleError?(error: Error, context: ReactorContext): Promise<void>;
}

export interface ReactorPlan {
  steps: Map<string, ReactorStep>;
  dependencies: Map<string, Set<string>>;
  executionOrder: string[][];
}

export interface ReactorResult<T = any> {
  id: string;
  state: ReactorState;
  context: ReactorContext;
  results: Map<string, StepResult>;
  errors: Error[];
  duration: number;
  returnValue?: T;
}

export interface ReactorOptions {
  id?: string;
  middleware?: ReactorMiddleware[];
  maxConcurrency?: number;
  timeout?: number;
  context?: Partial<ReactorContext>;
}

export interface ReactorInput {
  name: string;
  description?: string;
  required?: boolean;
  defaultValue?: any;
}

export interface ReactorDefinition {
  inputs: ReactorInput[];
  steps: ReactorStep[];
  returnStep?: string;
  middleware?: ReactorMiddleware[];
  options?: ReactorOptions;
}

export interface Reactor {
  id: string;
  state: ReactorState;
  inputs: ReactorInput[];
  steps: ReactorStep[];
  middleware: ReactorMiddleware[];
  context: ReactorContext;
  plan: ReactorPlan | null;
  results: Map<string, StepResult>;
  undoStack: Array<{ step: ReactorStep; result: any }>;
  returnStep?: string;
  
  addInput(input: ReactorInput): void;
  addStep(step: ReactorStep): void;
  addMiddleware(middleware: ReactorMiddleware): void;
  setReturn(stepName: string): void;
  execute<T = any>(inputs: Record<string, any>): Promise<ReactorResult<T>>;
  compensate(): Promise<void>;
  rollback(): Promise<void>;
}