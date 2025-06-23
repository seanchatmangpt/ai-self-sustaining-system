/**
 * Error Boundary System for Nuxt Reactor
 * Comprehensive error handling, recovery, and circuit breaking
 */

import type { ReactorStep, ReactorContext, StepResult } from '../types';

export interface ErrorBoundaryOptions {
  /** Maximum retry attempts */
  maxRetries?: number;
  /** Retry delay in milliseconds */
  retryDelay?: number;
  /** Exponential backoff multiplier */
  backoffMultiplier?: number;
  /** Circuit breaker failure threshold */
  failureThreshold?: number;
  /** Circuit breaker timeout in milliseconds */
  circuitTimeout?: number;
  /** Enable automatic fallback execution */
  enableFallback?: boolean;
  /** Custom error classifier */
  errorClassifier?: (error: Error) => 'retry' | 'abort' | 'fallback';
  /** Error reporting callback */
  onError?: (error: Error, context: ErrorContext) => void;
}

export interface ErrorContext {
  stepName: string;
  reactorId: string;
  attemptCount: number;
  totalRetries: number;
  isCircuitOpen: boolean;
  timestamp: number;
  previousErrors: Error[];
}

export interface CircuitBreakerState {
  failures: number;
  lastFailure: number;
  state: 'closed' | 'open' | 'half-open';
  nextAttempt: number;
}

export class ReactorErrorBoundary {
  private options: Required<ErrorBoundaryOptions>;
  private circuitBreakers: Map<string, CircuitBreakerState> = new Map();
  private errorHistory: Map<string, Error[]> = new Map();
  private retryCounters: Map<string, number> = new Map();
  
  constructor(options: ErrorBoundaryOptions = {}) {
    this.options = {
      maxRetries: 3,
      retryDelay: 1000,
      backoffMultiplier: 2,
      failureThreshold: 5,
      circuitTimeout: 60000,
      enableFallback: true,
      errorClassifier: this.defaultErrorClassifier.bind(this),
      onError: () => {},
      ...options
    };
  }
  
  /**
   * Wrap a reactor step with error boundary protection
   */
  wrapStep(step: ReactorStep): ReactorStep {
    const originalRun = step.run.bind(step);
    const originalCompensate = step.compensate?.bind(step);
    const originalUndo = step.undo?.bind(step);
    
    return {
      ...step,
      run: async (input: unknown, context: ReactorContext): Promise<StepResult> => {
        const stepKey = `${context.id}_${step.name}`;
        
        // Check circuit breaker
        if (this.isCircuitOpen(stepKey)) {
          return this.handleCircuitOpen(step, input, context);
        }
        
        let lastError: Error | null = null;
        const maxAttempts = this.options.maxRetries + 1;
        
        for (let attempt = 1; attempt <= maxAttempts; attempt++) {
          try {
            // Add attempt delay (except for first attempt)
            if (attempt > 1) {
              const delay = this.calculateDelay(attempt - 1);
              await this.sleep(delay);
            }
            
            const result = await this.executeWithTimeout(
              originalRun(input, context),
              step.timeout || 30000
            );
            
            // Success - reset error tracking
            this.resetErrorTracking(stepKey);
            return result;
            
          } catch (error) {
            lastError = error as Error;
            
            // Record error
            this.recordError(stepKey, lastError);
            
            // Create error context
            const errorContext: ErrorContext = {
              stepName: step.name,
              reactorId: context.id,
              attemptCount: attempt,
              totalRetries: maxAttempts - 1,
              isCircuitOpen: this.isCircuitOpen(stepKey),
              timestamp: Date.now(),
              previousErrors: this.getErrorHistory(stepKey)
            };
            
            // Notify error handler
            this.options.onError(lastError, errorContext);
            
            // Classify error and determine action
            const action = this.options.errorClassifier(lastError);
            
            if (action === 'abort' || attempt === maxAttempts) {
              // Update circuit breaker on final failure
              this.updateCircuitBreaker(stepKey, false);
              
              if (action === 'fallback' && this.options.enableFallback) {
                return await this.executeFallback(step, input, context, lastError);
              }
              
              // Final failure
              return {
                success: false,
                error: new EnhancedError(lastError, errorContext)
              };
            } else if (action === 'fallback' && this.options.enableFallback) {
              return await this.executeFallback(step, input, context, lastError);
            }
            
            // Continue retrying
            console.warn(`Step ${step.name} failed (attempt ${attempt}/${maxAttempts}):`, lastError.message);
          }
        }
        
        // This should never be reached, but TypeScript needs it
        return {
          success: false,
          error: lastError || new Error('Unknown error occurred')
        };
      },
      
      compensate: originalCompensate ? async (error: Error, input: unknown, context: ReactorContext): Promise<'retry' | 'abort' | 'continue'> => {
        try {
          return await originalCompensate(error, input, context);
        } catch (compensationError) {
          console.error(`Compensation failed for step ${step.name}:`, compensationError);
          
          // Try fallback compensation
          if (this.options.enableFallback) {
            return 'abort'; // Safe fallback for compensation
          }
          
          throw compensationError;
        }
      } : undefined,
      
      undo: originalUndo ? async (result: unknown, input: unknown, context: ReactorContext): Promise<void> => {
        try {
          await originalUndo(result, input, context);
        } catch (undoError) {
          console.error(`Undo failed for step ${step.name}:`, undoError);
          
          // Record undo failure but don't throw - we're already in recovery mode
          this.options.onError(undoError as Error, {
            stepName: step.name,
            reactorId: context.id,
            attemptCount: 1,
            totalRetries: 0,
            isCircuitOpen: false,
            timestamp: Date.now(),
            previousErrors: []
          });
        }
      } : undefined
    };
  }
  
  /**
   * Check if circuit breaker is open for a step
   */
  private isCircuitOpen(stepKey: string): boolean {
    const circuit = this.circuitBreakers.get(stepKey);
    if (!circuit) return false;
    
    const now = Date.now();
    
    switch (circuit.state) {
      case 'open':
        if (now >= circuit.nextAttempt) {
          // Transition to half-open
          circuit.state = 'half-open';
          this.circuitBreakers.set(stepKey, circuit);
          return false;
        }
        return true;
        
      case 'half-open':
        return false;
        
      case 'closed':
      default:
        return false;
    }
  }
  
  /**
   * Handle execution when circuit is open
   */
  private async handleCircuitOpen(
    step: ReactorStep, 
    input: unknown, 
    context: ReactorContext
  ): Promise<StepResult> {
    if (this.options.enableFallback) {
      return await this.executeFallback(step, input, context, new Error('Circuit breaker is open'));
    }
    
    return {
      success: false,
      error: new Error(`Circuit breaker is open for step ${step.name}`)
    };
  }
  
  /**
   * Execute fallback strategy
   */
  private async executeFallback(
    step: ReactorStep,
    input: unknown,
    context: ReactorContext,
    originalError: Error
  ): Promise<StepResult> {
    // Try to find a fallback step or return a safe default
    if (step.name.includes('api') || step.name.includes('fetch')) {
      // For API calls, return cached data or safe default
      return {
        success: true,
        data: {
          fallback: true,
          message: 'Using fallback data due to API failure',
          originalError: originalError.message,
          timestamp: Date.now()
        }
      };
    }
    
    if (step.name.includes('validation') || step.name.includes('validate')) {
      // For validation, use permissive fallback
      return {
        success: true,
        data: {
          valid: true,
          fallback: true,
          message: 'Validation bypassed due to error',
          originalError: originalError.message
        }
      };
    }
    
    if (step.name.includes('transform') || step.name.includes('process')) {
      // For transformations, return input unchanged
      return {
        success: true,
        data: {
          result: input,
          fallback: true,
          message: 'Transformation skipped due to error',
          originalError: originalError.message
        }
      };
    }
    
    // Generic fallback
    return {
      success: true,
      data: {
        fallback: true,
        message: `Step ${step.name} failed, using fallback`,
        originalError: originalError.message,
        input
      }
    };
  }
  
  /**
   * Record error in history
   */
  private recordError(stepKey: string, error: Error): void {
    const history = this.errorHistory.get(stepKey) || [];
    history.push(error);
    
    // Keep only last 10 errors
    if (history.length > 10) {
      history.shift();
    }
    
    this.errorHistory.set(stepKey, history);
  }
  
  /**
   * Get error history for a step
   */
  private getErrorHistory(stepKey: string): Error[] {
    return this.errorHistory.get(stepKey) || [];
  }
  
  /**
   * Reset error tracking for a step
   */
  private resetErrorTracking(stepKey: string): void {
    this.errorHistory.delete(stepKey);
    this.retryCounters.delete(stepKey);
    
    // Reset circuit breaker on success
    this.updateCircuitBreaker(stepKey, true);
  }
  
  /**
   * Update circuit breaker state
   */
  private updateCircuitBreaker(stepKey: string, success: boolean): void {
    const circuit = this.circuitBreakers.get(stepKey) || {
      failures: 0,
      lastFailure: 0,
      state: 'closed' as const,
      nextAttempt: 0
    };
    
    const now = Date.now();
    
    if (success) {
      // Success - reset or close circuit
      if (circuit.state === 'half-open') {
        circuit.state = 'closed';
        circuit.failures = 0;
      } else if (circuit.state === 'closed') {
        circuit.failures = Math.max(0, circuit.failures - 1);
      }
    } else {
      // Failure - increment and possibly open circuit
      circuit.failures++;
      circuit.lastFailure = now;
      
      if (circuit.failures >= this.options.failureThreshold) {
        circuit.state = 'open';
        circuit.nextAttempt = now + this.options.circuitTimeout;
      }
    }
    
    this.circuitBreakers.set(stepKey, circuit);
  }
  
  /**
   * Calculate retry delay with exponential backoff
   */
  private calculateDelay(attempt: number): number {
    return this.options.retryDelay * Math.pow(this.options.backoffMultiplier, attempt - 1);
  }
  
  /**
   * Execute operation with timeout
   */
  private async executeWithTimeout<T>(promise: Promise<T>, timeout: number): Promise<T> {
    return Promise.race([
      promise,
      new Promise<T>((_, reject) => 
        setTimeout(() => reject(new Error(`Operation timed out after ${timeout}ms`)), timeout)
      )
    ]);
  }
  
  /**
   * Sleep for specified milliseconds
   */
  private sleep(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
  
  /**
   * Default error classifier
   */
  private defaultErrorClassifier(error: Error): 'retry' | 'abort' | 'fallback' {
    const message = error.message.toLowerCase();
    
    // Network errors - retry
    if (message.includes('network') || message.includes('timeout') || message.includes('connection')) {
      return 'retry';
    }
    
    // Validation errors - abort (don't retry invalid data)
    if (message.includes('validation') || message.includes('invalid') || message.includes('required')) {
      return 'abort';
    }
    
    // Rate limiting - retry with backoff
    if (message.includes('rate limit') || message.includes('too many requests')) {
      return 'retry';
    }
    
    // Authentication/authorization errors - abort
    if (message.includes('unauthorized') || message.includes('forbidden') || message.includes('auth')) {
      return 'abort';
    }
    
    // Server errors - fallback
    if (message.includes('internal server error') || message.includes('service unavailable')) {
      return 'fallback';
    }
    
    // Default to retry for unknown errors
    return 'retry';
  }
  
  /**
   * Get circuit breaker statistics
   */
  getCircuitBreakerStats(): Record<string, CircuitBreakerState> {
    const stats: Record<string, CircuitBreakerState> = {};
    this.circuitBreakers.forEach((state, key) => {
      stats[key] = { ...state };
    });
    return stats;
  }
  
  /**
   * Get error statistics
   */
  getErrorStats(): Record<string, { count: number; lastError: string; lastOccurrence: number }> {
    const stats: Record<string, { count: number; lastError: string; lastOccurrence: number }> = {};
    
    this.errorHistory.forEach((errors, key) => {
      if (errors.length > 0) {
        const lastError = errors[errors.length - 1];
        stats[key] = {
          count: errors.length,
          lastError: lastError.message,
          lastOccurrence: Date.now() // Approximate - we don't store timestamps for individual errors
        };
      }
    });
    
    return stats;
  }
  
  /**
   * Reset all circuit breakers
   */
  resetCircuitBreakers(): void {
    this.circuitBreakers.clear();
  }
  
  /**
   * Reset all error history
   */
  resetErrorHistory(): void {
    this.errorHistory.clear();
    this.retryCounters.clear();
  }
}

/**
 * Enhanced error with additional context
 */
export class EnhancedError extends Error {
  public readonly context: ErrorContext;
  public readonly originalError: Error;
  
  constructor(originalError: Error, context: ErrorContext) {
    super(`${originalError.message} (attempt ${context.attemptCount}/${context.totalRetries + 1})`);
    this.name = 'ReactorError';
    this.context = context;
    this.originalError = originalError;
    
    // Preserve stack trace
    if (Error.captureStackTrace) {
      Error.captureStackTrace(this, EnhancedError);
    }
  }
  
  toJSON() {
    return {
      name: this.name,
      message: this.message,
      context: this.context,
      originalError: {
        name: this.originalError.name,
        message: this.originalError.message,
        stack: this.originalError.stack
      },
      stack: this.stack
    };
  }
}

/**
 * Middleware for automatic error boundary integration
 */
export class ErrorBoundaryMiddleware {
  name = 'error-boundary';
  
  constructor(private boundary: ReactorErrorBoundary) {}
  
  async beforeStep(context: ReactorContext, step: ReactorStep): Promise<void> {
    // Steps are automatically wrapped when added to reactor with error boundary
    // This middleware just provides hooks for additional error handling
  }
  
  async handleError(context: ReactorContext, error: Error): Promise<void> {
    // Global error handler - could integrate with external error reporting
    console.error(`Reactor ${context.id} encountered unhandled error:`, error);
    
    // Could send to error reporting service here
    if (process.env.NODE_ENV === 'production') {
      // Example: Sentry, Bugsnag, etc.
    }
  }
}