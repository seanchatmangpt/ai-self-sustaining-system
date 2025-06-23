/**
 * SPR (Sparse Priming Representation) Compression Pipeline
 * Main exports for the SPR compression system
 */

export type {
  SPRPattern,
  SPRCompressionOptions,
  SPRCompressionResult,
  SPRDecompressionResult,
  SPRContext,
  SPRCompressionEngine,
  SPRPatternRegistry,
  SPRMiddlewareOptions,
  SPRMetrics
} from './types';

export { SPRCompressionEngineImpl } from './compression-engine';
export { InMemoryPatternRegistry } from './pattern-registry';

// Re-export types for convenience
import type { SPRCompressionEngine, SPRPatternRegistry, SPRContext } from './types';
import { SPRCompressionEngineImpl } from './compression-engine';
import { InMemoryPatternRegistry } from './pattern-registry';

// Factory functions for common configurations
export function createSPREngine(patternRegistry?: SPRPatternRegistry): SPRCompressionEngine {
  return new SPRCompressionEngineImpl(patternRegistry);
}

export function createPatternRegistry(): SPRPatternRegistry {
  return new InMemoryPatternRegistry();
}

// Utility functions
export function createSPRContext(options: {
  domain: string;
  agentId?: string;
  sessionId?: string;
  traceId?: string;
  priority?: 'low' | 'medium' | 'high';
  metadata?: Record<string, any>;
}): SPRContext {
  return {
    domain: options.domain,
    agentId: options.agentId,
    sessionId: options.sessionId,
    traceId: options.traceId,
    priority: options.priority || 'medium',
    metadata: options.metadata || {}
  };
}

// Pre-configured engines for common use cases
export function createCoordinationSPREngine(): SPRCompressionEngine {
  const registry = new InMemoryPatternRegistry();
  return new SPRCompressionEngineImpl(registry);
}

export function createTelemetrySPREngine(): SPRCompressionEngine {
  const registry = new InMemoryPatternRegistry();
  return new SPRCompressionEngineImpl(registry);
}

export function createPerformanceSPREngine(): SPRCompressionEngine {
  const registry = new InMemoryPatternRegistry();
  return new SPRCompressionEngineImpl(registry);
}