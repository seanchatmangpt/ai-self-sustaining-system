/**
 * Reactor Middleware - All middleware exports
 */

export * from './telemetry-middleware';
export * from './coordination-middleware';

// Re-export classes for convenience
import { TelemetryMiddleware } from './telemetry-middleware';
import { CoordinationMiddleware } from './coordination-middleware';

export { TelemetryMiddleware, CoordinationMiddleware };

// Factory functions for common middleware configurations
export function createTelemetryMiddleware(options?: { onSpanEnd?: (span: any) => void }) {
  return new TelemetryMiddleware(options);
}

export function createCoordinationMiddleware(options?: {
  agentId?: string;
  onWorkClaim?: (claim: any) => void;
  onWorkComplete?: (claim: any) => void;
}) {
  return new CoordinationMiddleware(options);
}

// Pre-configured middleware stacks
export function createProductionMiddlewareStack() {
  return [
    createTelemetryMiddleware({
      onSpanEnd: (span) => {
        // Send to observability backend in production
        console.log('📊 Telemetry span:', span.operationName, `${span.duration}ms`);
      }
    }),
    createCoordinationMiddleware({
      onWorkClaim: (claim) => {
        console.log(`🎯 Work claimed: ${claim.stepName} by ${claim.agentId}`);
      },
      onWorkComplete: (claim) => {
        console.log(`✅ Work completed: ${claim.stepName} by ${claim.agentId}`);
      }
    })
  ];
}

export function createDevelopmentMiddlewareStack() {
  return [
    createTelemetryMiddleware({
      onSpanEnd: (span) => {
        console.log(`🔍 [${span.operationName}] ${span.duration}ms`, span.attributes);
      }
    }),
    createCoordinationMiddleware({
      onWorkClaim: (claim) => {
        console.log(`🤖 Agent ${claim.agentId} claiming ${claim.stepName}`);
      },
      onWorkComplete: (claim) => {
        console.log(`🎉 Agent ${claim.agentId} completed ${claim.stepName}`);
      }
    })
  ];
}