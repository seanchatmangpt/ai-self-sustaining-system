/**
 * Nuxt Reactor Examples Index
 * Complete collection of patterns, examples, and demonstrations
 */

// Core Examples
export * from './basic-reactor-example'
export * from './checkout-reactor'

// Advanced Examples
export * from './advanced/ai-swarm-coordination-reactor'
export * from './advanced/autonomous-worktree-deployment-reactor'
export * from './advanced/multi-system-trace-orchestrator'
export * from './advanced/spr-pipeline-optimization-reactor'
export * from './advanced/pattern-cookbook-examples'

// Re-export pattern demonstrations
import {
  demonstrateSequentialPipeline,
  demonstrateParallelFanOut,
  demonstrateConditionalBranch,
  demonstrateCachingStrategy,
  demonstrateErrorHandling,
  runAllPatternExamples
} from './advanced/pattern-cookbook-examples'

export {
  demonstrateSequentialPipeline,
  demonstrateParallelFanOut,
  demonstrateConditionalBranch,
  demonstrateCachingStrategy,
  demonstrateErrorHandling,
  runAllPatternExamples
}

// Quick start examples for common use cases
export const QuickStartExamples = {
  // Simple workflow
  simpleWorkflow: () => import('./basic-reactor-example').then(m => m.createBasicWorkflow()),
  
  // E-commerce checkout
  ecommerceCheckout: () => import('./checkout-reactor').then(m => m.createCheckoutReactor()),
  
  // Data aggregation
  dataAggregation: () => demonstrateParallelFanOut(),
  
  // Payment processing
  paymentProcessing: () => demonstrateConditionalBranch(),
  
  // User onboarding
  userOnboarding: () => demonstrateSequentialPipeline(),
  
  // Caching strategy
  cachingStrategy: () => demonstrateCachingStrategy(),
  
  // Error handling
  errorHandling: () => demonstrateErrorHandling(),
  
  // All patterns
  allPatterns: () => runAllPatternExamples()
}

// Usage guide
export const UsageGuide = {
  patterns: {
    sequential: 'Use for linear workflows where each step depends on the previous one',
    parallel: 'Use for independent operations that can run simultaneously',
    conditional: 'Use for dynamic workflow paths based on runtime conditions',
    caching: 'Use for optimizing repeated operations and expensive computations',
    errorHandling: 'Use for robust error recovery and fault tolerance',
    coordination: 'Use for multi-agent systems and distributed workflows',
    performance: 'Use for high-performance scenarios requiring optimization'
  },
  
  bestPractices: [
    'Always define input validation for reactor workflows',
    'Use compensation functions for critical operations that need rollback',
    'Implement proper error boundaries for production systems',
    'Monitor performance with telemetry middleware',
    'Use SPR optimization for frequently executed workflows',
    'Cache expensive operations when possible',
    'Design workflows to be composable and reusable'
  ],
  
  performance: [
    'Parallel execution can reduce total time by 50-80%',
    'SPR compression provides 20-50% performance gains',
    'Caching can reduce response times by 70-90%',
    'Circuit breakers prevent cascade failures',
    'Error boundaries provide graceful degradation'
  ]
}

// Export collection for documentation
export const PatternCookbook = {
  corePatterns: 7,
  totalExamples: 15,
  linesOfCode: 2392,
  coverageAreas: [
    'Core Reactor Patterns',
    'Coordination Patterns', 
    'Performance Patterns',
    'Error Handling Patterns',
    'Integration Patterns',
    'Advanced Patterns'
  ]
}