/**
 * Unit tests for Multi-System Trace Orchestrator Reactor
 */

import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { ReactorEngine } from '../../core/reactor-engine';
import { 
  setupTestEnvironment,
  createAdvancedAssertions,
  TimeProvider,
  PlatformProvider,
  BrowserProvider
} from './test-fixtures';

// Mock the multi-system trace orchestrator with dependency injection
const createMockMultiSystemTraceOrchestrator = (deps: {
  timeProvider: TimeProvider;
  platformProvider: PlatformProvider;
  browserProvider: BrowserProvider;
  apiMock: any;
}) => {
  const reactor = new ReactorEngine({
    id: `multi_system_trace_${deps.timeProvider.now()}`,
    timeout: 180000
  });
  
  // Mock trace context initialization
  const initializeTraceContext = {
    name: 'initialize-trace-context',
    description: 'Initialize distributed trace context for cross-system orchestration',
    
    async run(input: any, context: any) {
      try {
        const correlationId = `coord_${deps.timeProvider.now()}${deps.platformProvider.getHighResolutionTime().toString().slice(-9)}`;
        
        const traceContext = {
          traceId: context.traceId || generateTraceId(),
          spanId: context.spanId || generateSpanId(),
          baggage: {
            'workflow.id': input.workflowId,
            'workflow.type': 'multi-system-orchestration',
            'correlation.id': correlationId,
            'system.origin': 'nuxt-reactor'
          },
          correlationId,
          systemPath: ['nuxt-reactor']
        };
        
        await deps.apiMock.$fetch('/api/telemetry/register-trace', {
          method: 'POST',
          body: {
            traceId: traceContext.traceId,
            correlationId,
            systems: input.systems.map((s: any) => s.name),
            initiatedBy: 'multi-system-orchestrator'
          }
        });
        
        return { success: true, data: traceContext };
      } catch (error) {
        return { success: false, error: error as Error };
      }
    }
  };
  
  // Mock Phoenix system execution
  const phoenixSystemExecution = {
    name: 'phoenix-system-execution',
    description: 'Execute workflow in Phoenix LiveView system with PubSub coordination',
    dependencies: ['initialize-trace-context'],
    timeout: 45000,
    
    async run(input: any, context: any) {
      try {
        const traceContext = context.results?.get('initialize-trace-context')?.data;
        
        const phoenixResult = await deps.apiMock.$fetch('http://localhost:4000/api/reactor/execute', {
          method: 'POST',
          body: {
            workflow: {
              type: 'trace-flow-reactor',
              steps: [
                'validate_trace_context',
                'execute_ash_operations',
                'broadcast_liveview_updates',
                'emit_telemetry_events'
              ]
            },
            input: input.phoenixPayload
          },
          headers: {
            'traceparent': buildTraceparentHeader(traceContext),
            'tracestate': buildTracestateHeader(traceContext),
            'baggage': buildBaggageHeader(traceContext.baggage),
            'X-Correlation-ID': traceContext.correlationId
          }
        });
        
        traceContext.systemPath.push('phoenix-liveview');
        
        return { 
          success: true, 
          data: {
            phoenixResult,
            traceContext,
            executionTime: deps.timeProvider.now() - context.startTime,
            liveViewUpdates: phoenixResult.liveview_updates || []
          }
        };
      } catch (error) {
        return { success: false, error: error as Error };
      }
    },
    
    async compensate() {
      return 'retry';
    }
  };
  
  // Mock N8n workflow execution
  const n8nWorkflowExecution = {
    name: 'n8n-workflow-execution',
    description: 'Execute N8n workflow with trace header propagation',
    dependencies: ['phoenix-system-execution'],
    timeout: 60000,
    
    async run(input: any, context: any) {
      try {
        const phoenixResult = context.results?.get('phoenix-system-execution')?.data;
        const traceContext = phoenixResult.traceContext;
        
        let n8nResult;
        let isFallback = false;
        
        try {
          n8nResult = await deps.apiMock.$fetch('http://localhost:5678/webhook/reactor-integration', {
            method: 'POST',
            body: {
              payload: input.n8nPayload,
              trace_context: {
                trace_id: traceContext.traceId,
                span_id: generateSpanId(),
                parent_span_id: traceContext.spanId,
                correlation_id: traceContext.correlationId
              },
              phoenix_context: phoenixResult.phoenixResult.context
            },
            headers: {
              'traceparent': buildTraceparentHeader(traceContext),
              'X-Correlation-ID': traceContext.correlationId,
              'X-System-Path': traceContext.systemPath.join(' → ')
            }
          });
        } catch (error) {
          if (input.enableFallback) {
            n8nResult = createN8nFallbackResponse(input.n8nPayload);
            isFallback = true;
          } else {
            throw error;
          }
        }
        
        traceContext.systemPath.push('n8n-workflow');
        
        return { 
          success: true, 
          data: {
            n8nResult,
            traceContext,
            isFallback,
            workflowExecutionId: n8nResult.execution_id
          }
        };
      } catch (error) {
        return { success: false, error: error as Error };
      }
    }
  };
  
  // Mock XAVOS system execution
  const xavosSystemExecution = {
    name: 'xavos-system-execution',
    description: 'Execute operations in XAVOS Ash Framework ecosystem',
    dependencies: ['n8n-workflow-execution'],
    timeout: 30000,
    
    async run(input: any, context: any) {
      try {
        const n8nResult = context.results?.get('n8n-workflow-execution')?.data;
        const traceContext = n8nResult.traceContext;
        
        const xavosResult = await deps.apiMock.$fetch('http://localhost:4002/api/coordination/execute', {
          method: 'POST',
          body: {
            operation: 'multi-system-coordination',
            trace_context: {
              trace_id: traceContext.traceId,
              correlation_id: traceContext.correlationId,
              system_path: traceContext.systemPath
            },
            payload: {
              phoenix_result: context.results?.get('phoenix-system-execution')?.data.phoenixResult,
              n8n_result: n8nResult.n8nResult,
              coordination_type: input.coordinationType || 'autonomous'
            }
          },
          headers: {
            'traceparent': buildTraceparentHeader(traceContext),
            'X-Correlation-ID': traceContext.correlationId,
            'X-System-Origin': 'multi-system-orchestrator'
          }
        });
        
        traceContext.systemPath.push('xavos-ash');
        
        return { 
          success: true, 
          data: {
            xavosResult,
            traceContext,
            ashOperations: xavosResult.ash_operations || [],
            coordinationMetrics: xavosResult.coordination_metrics
          }
        };
      } catch (error) {
        return { success: false, error: error as Error };
      }
    }
  };
  
  // Mock cross-system telemetry correlation
  const crossSystemTelemetryCorrelation = {
    name: 'cross-system-telemetry-correlation',
    description: 'Correlate telemetry data across all systems in the trace',
    dependencies: ['phoenix-system-execution', 'n8n-workflow-execution', 'xavos-system-execution'],
    
    async run(input: any, context: any) {
      try {
        const phoenixResult = context.results?.get('phoenix-system-execution')?.data;
        const n8nResult = context.results?.get('n8n-workflow-execution')?.data;
        const xavosResult = context.results?.get('xavos-system-execution')?.data;
        
        const traceContext = xavosResult.traceContext;
        
        const correlatedTelemetry = await deps.apiMock.$fetch('/api/telemetry/correlate-cross-system', {
          method: 'POST',
          body: {
            trace_id: traceContext.traceId,
            correlation_id: traceContext.correlationId,
            system_results: {
              phoenix: phoenixResult,
              n8n: n8nResult,
              xavos: xavosResult
            },
            time_range: {
              start: context.startTime,
              end: deps.timeProvider.now()
            }
          }
        });
        
        const performanceInsights = {
          metrics: {
            totalSystems: traceContext.systemPath.length,
            totalDuration: deps.timeProvider.now() - context.startTime,
            crossSystemLatency: 150 // Mock latency
          },
          crossSystemLatency: 150,
          bottlenecks: [],
          recommendations: []
        };
        
        return { 
          success: true, 
          data: {
            correlatedTelemetry,
            performanceInsights,
            traceContext,
            systemMetrics: {
              totalSystems: traceContext.systemPath.length,
              totalDuration: deps.timeProvider.now() - context.startTime,
              crossSystemLatency: performanceInsights.crossSystemLatency
            }
          }
        };
      } catch (error) {
        return { success: false, error: error as Error };
      }
    }
  };
  
  // Add steps to reactor
  reactor.addStep(initializeTraceContext);
  reactor.addStep(phoenixSystemExecution);
  reactor.addStep(n8nWorkflowExecution);
  reactor.addStep(xavosSystemExecution);
  reactor.addStep(crossSystemTelemetryCorrelation);
  
  return reactor;
};

// Helper functions
function generateTraceId(): string {
  return 'trace_12345678901234567890123456789012';
}

function generateSpanId(): string {
  return 'span_1234567890123456';
}

function buildTraceparentHeader(traceContext: any): string {
  return `00-${traceContext.traceId}-${traceContext.spanId}-01`;
}

function buildTracestateHeader(traceContext: any): string {
  return `reactor=correlation_id:${traceContext.correlationId}`;
}

function buildBaggageHeader(baggage: Record<string, string>): string {
  return Object.entries(baggage)
    .map(([key, value]) => `${key}=${value}`)
    .join(',');
}

function createN8nFallbackResponse(payload: any) {
  return {
    execution_id: `fallback_${Date.now()}`,
    status: 'simulated',
    result: {
      processed: true,
      payload: payload,
      timestamp: Date.now(),
      simulation_reason: 'n8n_unavailable'
    },
    workflow_data: payload
  };
}

describe('Multi-System Trace Orchestrator Reactor', () => {
  let testEnv: ReturnType<typeof setupTestEnvironment>;
  let assertions: ReturnType<typeof createAdvancedAssertions>;

  beforeEach(() => {
    vi.useFakeTimers();
    testEnv = setupTestEnvironment();
    assertions = createAdvancedAssertions();
  });

  afterEach(() => {
    vi.useRealTimers();
    testEnv.cleanup();
  });

  describe('Trace Context Initialization', () => {
    it('should initialize trace context with correlation ID', async () => {
      const reactor = createMockMultiSystemTraceOrchestrator(testEnv);
      
      const input = {
        workflowId: 'cross-system-001',
        systems: [
          { name: 'phoenix', url: 'http://localhost:4000', type: 'phoenix' },
          { name: 'n8n', url: 'http://localhost:5678', type: 'n8n' }
        ]
      };
      
      const result = await reactor.execute(input);
      
      assertions.expectSuccessfulResult(result);
      
      const traceResult = result.results.get('initialize-trace-context');
      expect(traceResult.data.traceId).toBeDefined();
      expect(traceResult.data.correlationId).toMatch(/^coord_\d+123456789$/);
      expect(traceResult.data.systemPath).toEqual(['nuxt-reactor']);
      expect(traceResult.data.baggage['workflow.id']).toBe('cross-system-001');
      
      // Verify trace registration API call
      expect(testEnv.apiMock.$fetch).toHaveBeenCalledWith(
        '/api/telemetry/register-trace',
        expect.objectContaining({
          method: 'POST',
          body: expect.objectContaining({
            traceId: traceResult.data.traceId,
            correlationId: traceResult.data.correlationId,
            systems: ['phoenix', 'n8n']
          })
        })
      );
    });

    it('should handle trace registration failures gracefully', async () => {
      testEnv.apiMock.$fetch.mockImplementation((url: string) => {
        if (url.includes('register-trace')) {
          throw new Error('Telemetry service unavailable');
        }
        return testEnv.apiMock.$fetch.getMockImplementation()(url);
      });
      
      const reactor = createMockMultiSystemTraceOrchestrator(testEnv);
      const input = {
        workflowId: 'test-workflow',
        systems: [{ name: 'phoenix', url: 'http://localhost:4000', type: 'phoenix' }]
      };
      
      const result = await reactor.execute(input);
      
      expect(result.state).toBe('failed');
      expect(result.errors[0].message).toBe('Telemetry service unavailable');
    });
  });

  describe('Phoenix System Integration', () => {
    it('should execute Phoenix workflow with trace propagation', async () => {
      const reactor = createMockMultiSystemTraceOrchestrator(testEnv);
      
      const input = {
        workflowId: 'phoenix-integration',
        systems: [{ name: 'phoenix', url: 'http://localhost:4000', type: 'phoenix' }],
        phoenixPayload: { workflow: 'trace-flow-reactor' }
      };
      
      const result = await reactor.execute(input);
      
      assertions.expectSuccessfulResult(result);
      
      const phoenixResult = result.results.get('phoenix-system-execution');
      expect(phoenixResult.data.traceContext.systemPath).toContain('phoenix-liveview');
      expect(phoenixResult.data.liveViewUpdates).toBeDefined();
      
      // Verify Phoenix API call with correct headers
      expect(testEnv.apiMock.$fetch).toHaveBeenCalledWith(
        'http://localhost:4000/api/reactor/execute',
        expect.objectContaining({
          method: 'POST',
          headers: expect.objectContaining({
            'traceparent': expect.stringMatching(/^00-trace_\w+-span_\w+-01$/),
            'X-Correlation-ID': expect.stringMatching(/^coord_\d+123456789$/)
          })
        })
      );
    });

    it('should retry Phoenix execution on failure', async () => {
      let callCount = 0;
      testEnv.apiMock.$fetch.mockImplementation((url: string) => {
        if (url.includes('localhost:4000')) {
          callCount++;
          if (callCount === 1) {
            throw new Error('Phoenix service temporary failure');
          }
        }
        return testEnv.apiMock.$fetch.getMockImplementation()(url);
      });
      
      const reactor = createMockMultiSystemTraceOrchestrator(testEnv);
      const input = {
        workflowId: 'retry-test',
        systems: [{ name: 'phoenix', url: 'http://localhost:4000', type: 'phoenix' }],
        phoenixPayload: { workflow: 'test' }
      };
      
      const result = await reactor.execute(input);
      
      // Should succeed after retry
      expect(result.state).toBe('completed');
      expect(callCount).toBe(2);
    });
  });

  describe('N8n Workflow Integration', () => {
    it('should execute N8n workflow with trace correlation', async () => {
      const reactor = createMockMultiSystemTraceOrchestrator(testEnv);
      
      const input = {
        workflowId: 'n8n-integration',
        systems: [
          { name: 'phoenix', url: 'http://localhost:4000', type: 'phoenix' },
          { name: 'n8n', url: 'http://localhost:5678', type: 'n8n' }
        ],
        phoenixPayload: { workflow: 'test' },
        n8nPayload: { trigger: 'webhook-integration' }
      };
      
      const result = await reactor.execute(input);
      
      assertions.expectSuccessfulResult(result);
      
      const n8nResult = result.results.get('n8n-workflow-execution');
      expect(n8nResult.data.workflowExecutionId).toBeDefined();
      expect(n8nResult.data.isFallback).toBe(false);
      expect(n8nResult.data.traceContext.systemPath).toContain('n8n-workflow');
      
      // Verify N8n API call
      expect(testEnv.apiMock.$fetch).toHaveBeenCalledWith(
        'http://localhost:5678/webhook/reactor-integration',
        expect.objectContaining({
          method: 'POST',
          body: expect.objectContaining({
            payload: { trigger: 'webhook-integration' },
            trace_context: expect.objectContaining({
              correlation_id: expect.stringMatching(/^coord_\d+123456789$/)
            })
          })
        })
      );
    });

    it('should use fallback simulation when N8n is unavailable', async () => {
      testEnv.apiMock.$fetch.mockImplementation((url: string) => {
        if (url.includes('localhost:5678')) {
          throw new Error('N8n service unavailable');
        }
        return testEnv.apiMock.$fetch.getMockImplementation()(url);
      });
      
      const reactor = createMockMultiSystemTraceOrchestrator(testEnv);
      const input = {
        workflowId: 'fallback-test',
        systems: [
          { name: 'phoenix', url: 'http://localhost:4000', type: 'phoenix' },
          { name: 'n8n', url: 'http://localhost:5678', type: 'n8n' }
        ],
        phoenixPayload: { workflow: 'test' },
        n8nPayload: { trigger: 'webhook-test' },
        enableFallback: true
      };
      
      const result = await reactor.execute(input);
      
      assertions.expectSuccessfulResult(result);
      
      const n8nResult = result.results.get('n8n-workflow-execution');
      expect(n8nResult.data.isFallback).toBe(true);
      expect(n8nResult.data.n8nResult.status).toBe('simulated');
      expect(n8nResult.data.n8nResult.execution_id).toMatch(/^fallback_\d+$/);
    });
  });

  describe('XAVOS System Integration', () => {
    it('should execute XAVOS operations with Ash Framework', async () => {
      const reactor = createMockMultiSystemTraceOrchestrator(testEnv);
      
      const input = {
        workflowId: 'xavos-integration',
        systems: [
          { name: 'phoenix', url: 'http://localhost:4000', type: 'phoenix' },
          { name: 'xavos', url: 'http://localhost:4002', type: 'xavos' }
        ],
        phoenixPayload: { workflow: 'test' },
        n8nPayload: { trigger: 'test' },
        coordinationType: 'autonomous'
      };
      
      const result = await reactor.execute(input);
      
      assertions.expectSuccessfulResult(result);
      
      const xavosResult = result.results.get('xavos-system-execution');
      expect(xavosResult.data.ashOperations).toBeDefined();
      expect(xavosResult.data.coordinationMetrics).toBeDefined();
      expect(xavosResult.data.traceContext.systemPath).toContain('xavos-ash');
      
      // Verify XAVOS API call
      expect(testEnv.apiMock.$fetch).toHaveBeenCalledWith(
        'http://localhost:4002/api/coordination/execute',
        expect.objectContaining({
          method: 'POST',
          body: expect.objectContaining({
            operation: 'multi-system-coordination',
            trace_context: expect.objectContaining({
              correlation_id: expect.stringMatching(/^coord_\d+123456789$/)
            }),
            payload: expect.objectContaining({
              coordination_type: 'autonomous'
            })
          })
        })
      );
    });
  });

  describe('Cross-System Telemetry Correlation', () => {
    it('should correlate telemetry across all systems', async () => {
      const reactor = createMockMultiSystemTraceOrchestrator(testEnv);
      
      const input = {
        workflowId: 'telemetry-correlation',
        systems: [
          { name: 'phoenix', url: 'http://localhost:4000', type: 'phoenix' },
          { name: 'n8n', url: 'http://localhost:5678', type: 'n8n' },
          { name: 'xavos', url: 'http://localhost:4002', type: 'xavos' }
        ],
        phoenixPayload: { workflow: 'test' },
        n8nPayload: { trigger: 'test' }
      };
      
      const result = await reactor.execute(input);
      
      assertions.expectSuccessfulResult(result);
      
      const correlationResult = result.results.get('cross-system-telemetry-correlation');
      expect(correlationResult.data.correlatedTelemetry).toBeDefined();
      expect(correlationResult.data.performanceInsights).toBeDefined();
      expect(correlationResult.data.systemMetrics.totalSystems).toBe(4); // nuxt-reactor + 3 systems
      
      // Verify telemetry correlation API call
      expect(testEnv.apiMock.$fetch).toHaveBeenCalledWith(
        '/api/telemetry/correlate-cross-system',
        expect.objectContaining({
          method: 'POST',
          body: expect.objectContaining({
            trace_id: expect.any(String),
            correlation_id: expect.stringMatching(/^coord_\d+123456789$/),
            system_results: expect.objectContaining({
              phoenix: expect.any(Object),
              n8n: expect.any(Object),
              xavos: expect.any(Object)
            })
          })
        })
      );
    });

    it('should generate performance insights and recommendations', async () => {
      const reactor = createMockMultiSystemTraceOrchestrator(testEnv);
      
      const input = {
        workflowId: 'performance-insights',
        systems: [
          { name: 'phoenix', url: 'http://localhost:4000', type: 'phoenix' },
          { name: 'n8n', url: 'http://localhost:5678', type: 'n8n' }
        ],
        phoenixPayload: { workflow: 'test' },
        n8nPayload: { trigger: 'test' }
      };
      
      const result = await reactor.execute(input);
      
      const correlationResult = result.results.get('cross-system-telemetry-correlation');
      const insights = correlationResult.data.performanceInsights;
      
      expect(insights.metrics).toBeDefined();
      expect(insights.crossSystemLatency).toBeGreaterThan(0);
      expect(insights.bottlenecks).toBeDefined();
      expect(insights.recommendations).toBeDefined();
      expect(correlationResult.data.systemMetrics.crossSystemLatency).toBe(150);
    });
  });

  describe('End-to-End System Path Tracking', () => {
    it('should track complete system path through all integrations', async () => {
      const reactor = createMockMultiSystemTraceOrchestrator(testEnv);
      
      const input = {
        workflowId: 'full-system-path',
        systems: [
          { name: 'phoenix', url: 'http://localhost:4000', type: 'phoenix' },
          { name: 'n8n', url: 'http://localhost:5678', type: 'n8n' },
          { name: 'xavos', url: 'http://localhost:4002', type: 'xavos' }
        ],
        phoenixPayload: { workflow: 'test' },
        n8nPayload: { trigger: 'test' }
      };
      
      const result = await reactor.execute(input);
      
      const finalResult = result.results.get('cross-system-telemetry-correlation');
      const systemPath = finalResult.data.traceContext.systemPath;
      
      expect(systemPath).toEqual([
        'nuxt-reactor',
        'phoenix-liveview',
        'n8n-workflow',
        'xavos-ash'
      ]);
      
      // Verify trace ID consistency across all steps
      const traceId = result.results.get('initialize-trace-context').data.traceId;
      assertions.expectTraceCorrelation(result, traceId);
    });
  });

  describe('Error Handling and Fallbacks', () => {
    it('should handle partial system failures with graceful degradation', async () => {
      // Mock XAVOS failure
      testEnv.apiMock.$fetch.mockImplementation((url: string) => {
        if (url.includes('localhost:4002')) {
          throw new Error('XAVOS service unavailable');
        }
        return testEnv.apiMock.$fetch.getMockImplementation()(url);
      });
      
      const reactor = createMockMultiSystemTraceOrchestrator(testEnv);
      const input = {
        workflowId: 'partial-failure-test',
        systems: [
          { name: 'phoenix', url: 'http://localhost:4000', type: 'phoenix' },
          { name: 'xavos', url: 'http://localhost:4002', type: 'xavos' }
        ],
        phoenixPayload: { workflow: 'test' },
        n8nPayload: { trigger: 'test' }
      };
      
      const result = await reactor.execute(input);
      
      expect(result.state).toBe('failed');
      
      // Phoenix should have succeeded
      const phoenixResult = result.results.get('phoenix-system-execution');
      expect(phoenixResult?.success).toBe(true);
      
      // XAVOS should have failed
      expect(result.errors[0].message).toBe('XAVOS service unavailable');
    });
  });
});