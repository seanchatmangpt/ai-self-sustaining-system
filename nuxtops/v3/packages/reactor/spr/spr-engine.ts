/**
 * SPR (Sparse PicoReactor) Engine
 * 80/20 Pattern Optimization for Reactor Workflows
 * 
 * Automatically identifies critical 20% of operations that provide 80% of value
 * and optimizes execution paths for maximum efficiency.
 */

import type { ReactorStep, ReactorContext, ReactorResult } from '../types';
import { ReactorEngine } from '../core/reactor-engine';

export interface SPRPattern {
  /** Unique pattern identifier */
  id: string;
  /** Pattern name */
  name: string;
  /** Performance weight (0-1, higher = more critical) */
  weight: number;
  /** Execution frequency */
  frequency: number;
  /** Average duration in ms */
  avgDuration: number;
  /** Success rate (0-1) */
  successRate: number;
  /** Dependencies that can be parallelized */
  parallelizable: string[];
  /** Steps that can be cached */
  cacheable: string[];
}

export interface SPRCompression {
  /** Original step count */
  originalSteps: number;
  /** Compressed step count */
  compressedSteps: number;
  /** Compression ratio */
  compressionRatio: number;
  /** Performance improvement estimate */
  performanceGain: number;
  /** Critical path steps (the 20%) */
  criticalPath: string[];
  /** Optimizable steps (the 80%) */
  optimizableSteps: string[];
}

export class SPREngine {
  private patterns: Map<string, SPRPattern> = new Map();
  private compressionCache: Map<string, SPRCompression> = new Map();
  private performanceHistory: Map<string, number[]> = new Map();
  
  /**
   * Analyze reactor workflow and identify 80/20 patterns
   */
  async analyzeWorkflow(reactor: ReactorEngine): Promise<SPRCompression> {
    const workflowId = this.getWorkflowId(reactor);
    
    // Check cache first
    if (this.compressionCache.has(workflowId)) {
      return this.compressionCache.get(workflowId)!;
    }
    
    const analysis = await this.performAnalysis(reactor);
    this.compressionCache.set(workflowId, analysis);
    
    return analysis;
  }
  
  /**
   * Apply SPR compression to optimize reactor workflow
   */
  async compressWorkflow(reactor: ReactorEngine): Promise<ReactorEngine> {
    const compression = await this.analyzeWorkflow(reactor);
    const optimizedReactor = new ReactorEngine({
      id: `spr_${reactor.id}`,
      maxConcurrency: Math.ceil(reactor['maxConcurrency'] * 1.5), // Increase concurrency
      timeout: reactor['timeout'],
      context: {
        ...reactor.context,
        sprCompression: compression,
        sprEnabled: true
      }
    });
    
    // Add optimized steps
    const optimizedSteps = await this.optimizeSteps(reactor.steps, compression);
    optimizedSteps.forEach(step => optimizedReactor.addStep(step));
    
    // Add SPR monitoring middleware
    optimizedReactor.addMiddleware(new SPRMonitoringMiddleware(this));
    
    return optimizedReactor;
  }
  
  /**
   * Update performance patterns based on execution results
   */
  updatePatterns(result: ReactorResult): void {
    result.results.forEach((stepResult, stepName) => {
      const pattern = this.patterns.get(stepName);
      if (pattern) {
        // Update frequency
        pattern.frequency += 1;
        
        // Update success rate
        const isSuccess = stepResult.success ? 1 : 0;
        pattern.successRate = (pattern.successRate + isSuccess) / 2;
        
        // Update performance history
        if (stepResult.success && typeof stepResult.data === 'object' && stepResult.data?.duration) {
          const history = this.performanceHistory.get(stepName) || [];
          history.push(stepResult.data.duration);
          if (history.length > 100) history.shift(); // Keep last 100 samples
          this.performanceHistory.set(stepName, history);
          
          // Update average duration
          pattern.avgDuration = history.reduce((a, b) => a + b, 0) / history.length;
        }
        
        // Recalculate weight based on Pareto principle
        pattern.weight = this.calculateParetoWeight(pattern);
        this.patterns.set(stepName, pattern);
      }
    });
  }
  
  /**
   * Get critical 20% of steps that provide 80% of value
   */
  getCriticalSteps(): SPRPattern[] {
    const sortedPatterns = Array.from(this.patterns.values())
      .sort((a, b) => b.weight - a.weight);
    
    const criticalCount = Math.ceil(sortedPatterns.length * 0.2);
    return sortedPatterns.slice(0, criticalCount);
  }
  
  /**
   * Get optimizable 80% of steps
   */
  getOptimizableSteps(): SPRPattern[] {
    const sortedPatterns = Array.from(this.patterns.values())
      .sort((a, b) => b.weight - a.weight);
    
    const criticalCount = Math.ceil(sortedPatterns.length * 0.2);
    return sortedPatterns.slice(criticalCount);
  }
  
  private async performAnalysis(reactor: ReactorEngine): Promise<SPRCompression> {
    const steps = reactor.steps;
    
    // Build patterns for each step
    for (const step of steps) {
      if (!this.patterns.has(step.name)) {
        this.patterns.set(step.name, this.createPattern(step));
      }
    }
    
    const criticalSteps = this.getCriticalSteps();
    const optimizableSteps = this.getOptimizableSteps();
    
    // Calculate compression metrics
    const originalSteps = steps.length;
    const compressedSteps = criticalSteps.length + Math.ceil(optimizableSteps.length * 0.3);
    const compressionRatio = compressedSteps / originalSteps;
    
    // Estimate performance gain based on critical path optimization
    const performanceGain = this.estimatePerformanceGain(criticalSteps, optimizableSteps);
    
    return {
      originalSteps,
      compressedSteps,
      compressionRatio,
      performanceGain,
      criticalPath: criticalSteps.map(p => p.id),
      optimizableSteps: optimizableSteps.map(p => p.id)
    };
  }
  
  private createPattern(step: ReactorStep): SPRPattern {
    return {
      id: step.name,
      name: step.name,
      weight: 0.5, // Initial neutral weight
      frequency: 1,
      avgDuration: step.timeout || 5000,
      successRate: 0.9, // Optimistic initial success rate
      parallelizable: step.dependencies || [],
      cacheable: this.identifyCacheableOperations(step)
    };
  }
  
  private identifyCacheableOperations(step: ReactorStep): string[] {
    const cacheable: string[] = [];
    
    // Heuristics for identifying cacheable operations
    if (step.description?.includes('fetch') || step.description?.includes('api')) {
      cacheable.push('api_response');
    }
    if (step.description?.includes('validation') || step.description?.includes('validate')) {
      cacheable.push('validation_result');
    }
    if (step.description?.includes('transform') || step.description?.includes('process')) {
      cacheable.push('transformation_result');
    }
    
    return cacheable;
  }
  
  private calculateParetoWeight(pattern: SPRPattern): number {
    // Weight based on multiple factors following Pareto principle
    const frequencyWeight = Math.min(pattern.frequency / 100, 1) * 0.3;
    const durationWeight = (1 / Math.max(pattern.avgDuration, 1)) * 0.3;
    const successWeight = pattern.successRate * 0.2;
    const parallelWeight = (pattern.parallelizable.length > 0 ? 0.1 : 0) * 0.1;
    const cacheWeight = (pattern.cacheable.length > 0 ? 0.1 : 0) * 0.1;
    
    return frequencyWeight + durationWeight + successWeight + parallelWeight + cacheWeight;
  }
  
  private estimatePerformanceGain(critical: SPRPattern[], optimizable: SPRPattern[]): number {
    const criticalTotalTime = critical.reduce((sum, p) => sum + p.avgDuration, 0);
    const optimizableTotalTime = optimizable.reduce((sum, p) => sum + p.avgDuration, 0);
    
    // Assume 50% improvement on optimizable steps through parallelization/caching
    const optimizedTime = optimizableTotalTime * 0.5;
    const totalOriginalTime = criticalTotalTime + optimizableTotalTime;
    const totalOptimizedTime = criticalTotalTime + optimizedTime;
    
    return (totalOriginalTime - totalOptimizedTime) / totalOriginalTime;
  }
  
  private async optimizeSteps(steps: ReactorStep[], compression: SPRCompression): Promise<ReactorStep[]> {
    const optimizedSteps: ReactorStep[] = [];
    
    for (const step of steps) {
      if (compression.criticalPath.includes(step.name)) {
        // Critical steps: keep as-is but optimize execution
        optimizedSteps.push(this.optimizeCriticalStep(step));
      } else if (compression.optimizableSteps.includes(step.name)) {
        // Optimizable steps: apply compression techniques
        const optimized = this.optimizeRegularStep(step);
        if (optimized) optimizedSteps.push(optimized);
      }
    }
    
    return optimizedSteps;
  }
  
  private optimizeCriticalStep(step: ReactorStep): ReactorStep {
    const pattern = this.patterns.get(step.name);
    
    return {
      ...step,
      // Reduce timeout for critical steps to fail fast
      timeout: Math.min(step.timeout || 30000, 10000),
      // Add caching if applicable
      run: pattern?.cacheable.length ? this.wrapWithCache(step.run.bind(step)) : step.run
    };
  }
  
  private optimizeRegularStep(step: ReactorStep): ReactorStep | null {
    const pattern = this.patterns.get(step.name);
    
    // Skip low-value steps entirely
    if (pattern && pattern.weight < 0.1) {
      return null;
    }
    
    return {
      ...step,
      // Increase timeout for non-critical steps to avoid failures
      timeout: (step.timeout || 30000) * 1.5,
      // Add batch processing if applicable
      run: this.wrapWithBatching(step.run.bind(step))
    };
  }
  
  private wrapWithCache(originalRun: Function) {
    const cache = new Map();
    
    return async function(input: unknown, context: ReactorContext) {
      const cacheKey = JSON.stringify({ input, contextId: context.id });
      
      if (cache.has(cacheKey)) {
        return cache.get(cacheKey);
      }
      
      const result = await originalRun(input, context);
      if (result.success) {
        cache.set(cacheKey, result);
      }
      
      return result;
    };
  }
  
  private wrapWithBatching(originalRun: Function) {
    return async function(input: unknown, context: ReactorContext) {
      // Simple batching: if input is array, process in chunks
      if (Array.isArray(input) && input.length > 10) {
        const chunks = [];
        for (let i = 0; i < input.length; i += 5) {
          chunks.push(input.slice(i, i + 5));
        }
        
        const results = await Promise.all(
          chunks.map(chunk => originalRun(chunk, context))
        );
        
        return {
          success: results.every(r => r.success),
          data: results.map(r => r.data).flat(),
          error: results.find(r => !r.success)?.error
        };
      }
      
      return await originalRun(input, context);
    };
  }
  
  private getWorkflowId(reactor: ReactorEngine): string {
    return `workflow_${reactor.id}_${reactor.steps.map(s => s.name).join('_')}`;
  }
  
  /**
   * Export SPR patterns for analysis
   */
  exportPatterns(): Record<string, SPRPattern> {
    const exported: Record<string, SPRPattern> = {};
    this.patterns.forEach((pattern, key) => {
      exported[key] = { ...pattern };
    });
    return exported;
  }
  
  /**
   * Import SPR patterns from previous sessions
   */
  importPatterns(patterns: Record<string, SPRPattern>): void {
    Object.entries(patterns).forEach(([key, pattern]) => {
      this.patterns.set(key, pattern);
    });
  }
}

/**
 * Middleware for monitoring SPR performance
 */
class SPRMonitoringMiddleware {
  name = 'spr-monitoring';
  
  constructor(private sprEngine: SPREngine) {}
  
  async afterReactor(context: ReactorContext, result: ReactorResult): Promise<void> {
    this.sprEngine.updatePatterns(result);
    
    if (context.sprEnabled && process.env.NODE_ENV === 'development') {
      console.log('🚀 SPR Performance Summary:', {
        compression: context.sprCompression,
        duration: result.duration,
        criticalSteps: this.sprEngine.getCriticalSteps().length,
        optimizableSteps: this.sprEngine.getOptimizableSteps().length
      });
    }
  }
}