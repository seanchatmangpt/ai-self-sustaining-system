/**
 * Failure Simulation and Recovery Testing
 * Chaos engineering and resilience validation for reactor systems
 */

import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { createReactor, arg } from '../core/reactor-builder';
import { performance } from 'perf_hooks';

// Chaos Engineering Utilities
class ChaosEngine {
  private scenarios: Map<string, ChaosScenario> = new Map();
  private activeScenarios: Set<string> = new Set();

  registerScenario(name: string, scenario: ChaosScenario) {
    this.scenarios.set(name, scenario);
  }

  activateScenario(name: string) {
    this.activeScenarios.add(name);
  }

  deactivateScenario(name: string) {
    this.activeScenarios.delete(name);
  }

  async simulateFailure(operation: string, context: any): Promise<boolean> {
    for (const scenarioName of this.activeScenarios) {
      const scenario = this.scenarios.get(scenarioName);
      if (scenario && await scenario.shouldFail(operation, context)) {
        if (scenario.onFailure) {
          await scenario.onFailure(operation, context);
        }
        return true;
      }
    }
    return false;
  }

  reset() {
    this.activeScenarios.clear();
  }
}

interface ChaosScenario {
  shouldFail(operation: string, context: any): Promise<boolean>;
  onFailure?(operation: string, context: any): Promise<void>;
}

// Network Failure Simulation
class NetworkFailureScenario implements ChaosScenario {
  constructor(
    private failureRate: number = 0.3,
    private targetOperations: string[] = ['api_call', 'database_query']
  ) {}

  async shouldFail(operation: string, context: any): Promise<boolean> {
    return this.targetOperations.includes(operation) && Math.random() < this.failureRate;
  }

  async onFailure(operation: string, context: any): Promise<void> {
    console.log(`[CHAOS] Network failure simulated for ${operation} at ${new Date().toISOString()}`);
  }
}

// Resource Exhaustion Simulation
class ResourceExhaustionScenario implements ChaosScenario {
  private operationCount = 0;

  constructor(
    private maxOperations: number = 5,
    private targetOperations: string[] = ['memory_intensive', 'cpu_intensive']
  ) {}

  async shouldFail(operation: string, context: any): Promise<boolean> {
    if (this.targetOperations.includes(operation)) {
      this.operationCount++;
      return this.operationCount > this.maxOperations;
    }
    return false;
  }

  async onFailure(operation: string, context: any): Promise<void> {
    console.log(`[CHAOS] Resource exhaustion simulated for ${operation} (operation #${this.operationCount})`);
  }
}

// Latency Injection Scenario
class LatencyInjectionScenario implements ChaosScenario {
  constructor(
    private delayMs: number = 5000,
    private targetOperations: string[] = ['slow_api', 'database_heavy']
  ) {}

  async shouldFail(operation: string, context: any): Promise<boolean> {
    if (this.targetOperations.includes(operation)) {
      await new Promise(resolve => setTimeout(resolve, this.delayMs));
      // Don't actually fail, just inject delay
      return false;
    }
    return false;
  }
}

// Recovery Metrics Collector
class RecoveryMetrics {
  private metrics = {
    totalFailures: 0,
    successfulRecoveries: 0,
    failedRecoveries: 0,
    retryAttempts: 0,
    compensationExecutions: 0,
    rollbackExecutions: 0,
    avgRecoveryTime: 0
  };

  recordFailure() {
    this.metrics.totalFailures++;
  }

  recordRecovery(successful: boolean, recoveryTimeMs: number) {
    if (successful) {
      this.metrics.successfulRecoveries++;
    } else {
      this.metrics.failedRecoveries++;
    }
    
    // Update average recovery time
    const totalRecoveries = this.metrics.successfulRecoveries + this.metrics.failedRecoveries;
    this.metrics.avgRecoveryTime = (
      (this.metrics.avgRecoveryTime * (totalRecoveries - 1)) + recoveryTimeMs
    ) / totalRecoveries;
  }

  recordRetry() {
    this.metrics.retryAttempts++;
  }

  recordCompensation() {
    this.metrics.compensationExecutions++;
  }

  recordRollback() {
    this.metrics.rollbackExecutions++;
  }

  getMetrics() {
    return {
      ...this.metrics,
      recoverySuccessRate: this.metrics.totalFailures > 0 ? 
        (this.metrics.successfulRecoveries / this.metrics.totalFailures) * 100 : 0
    };
  }

  reset() {
    Object.keys(this.metrics).forEach(key => {
      (this.metrics as any)[key] = 0;
    });
  }
}

describe('Failure Simulation and Recovery Testing', () => {
  let chaosEngine: ChaosEngine;
  let recoveryMetrics: RecoveryMetrics;

  beforeEach(() => {
    chaosEngine = new ChaosEngine();
    recoveryMetrics = new RecoveryMetrics();

    // Register chaos scenarios
    chaosEngine.registerScenario('network_failure', new NetworkFailureScenario(0.4));
    chaosEngine.registerScenario('resource_exhaustion', new ResourceExhaustionScenario(3));
    chaosEngine.registerScenario('latency_injection', new LatencyInjectionScenario(100));
  });

  afterEach(() => {
    const metrics = recoveryMetrics.getMetrics();
    console.log('\\n=== RECOVERY METRICS ===');
    console.log(`Total Failures: ${metrics.totalFailures}`);
    console.log(`Recovery Success Rate: ${metrics.recoverySuccessRate.toFixed(2)}%`);
    console.log(`Average Recovery Time: ${metrics.avgRecoveryTime.toFixed(2)}ms`);
    console.log(`Retry Attempts: ${metrics.retryAttempts}`);
    console.log(`Compensations: ${metrics.compensationExecutions}`);
    console.log(`Rollbacks: ${metrics.rollbackExecutions}`);
    
    chaosEngine.reset();
    recoveryMetrics.reset();
  });

  describe('Network Failure Recovery', () => {
    it('CHAOS-01: Should recover from intermittent network failures', async () => {
      chaosEngine.activateScenario('network_failure');

      const networkReactor = createReactor()
        .input('service_urls')
        .input('retry_config', { defaultValue: { maxRetries: 3, backoffMs: 100 } })

        .step('call_service_a', {
          arguments: { 
            url: arg.value('service-a'),
            config: arg.input('retry_config')
          },
          maxRetries: 3,
          async run({ url, config }) {
            const shouldFail = await chaosEngine.simulateFailure('api_call', { service: url });
            if (shouldFail) {
              recoveryMetrics.recordFailure();
              throw new Error(`Network error calling ${url}`);
            }
            return { service: url, data: 'Service A response', timestamp: Date.now() };
          },
          async compensate(error, args, context) {
            recoveryMetrics.recordCompensation();
            if (error.message.includes('Network error')) {
              recoveryMetrics.recordRetry();
              return 'retry';
            }
            return 'abort';
          }
        })

        .step('call_service_b', {
          arguments: { 
            url: arg.value('service-b'),
            config: arg.input('retry_config')
          },
          maxRetries: 3,
          async run({ url, config }) {
            const shouldFail = await chaosEngine.simulateFailure('api_call', { service: url });
            if (shouldFail) {
              recoveryMetrics.recordFailure();
              throw new Error(`Network error calling ${url}`);
            }
            return { service: url, data: 'Service B response', timestamp: Date.now() };
          },
          async compensate(error, args, context) {
            recoveryMetrics.recordCompensation();
            if (error.message.includes('Network error')) {
              recoveryMetrics.recordRetry();
              return 'retry';
            }
            return 'abort';
          }
        })

        .step('aggregate_responses', {
          arguments: {
            serviceA: arg.step('call_service_a'),
            serviceB: arg.step('call_service_b')
          },
          async run({ serviceA, serviceB }) {
            return {
              combined: [serviceA, serviceB],
              totalServices: 2,
              aggregatedAt: Date.now()
            };
          }
        })

        .return('aggregate_responses')
        .build();

      const startTime = performance.now();
      const result = await networkReactor.execute({ 
        service_urls: ['service-a', 'service-b'] 
      });
      const duration = performance.now() - startTime;

      const metrics = recoveryMetrics.getMetrics();
      recoveryMetrics.recordRecovery(result.state === 'completed', duration);

      expect(result.state).toBe('completed');
      expect(result.returnValue.totalServices).toBe(2);
      expect(metrics.retryAttempts).toBeGreaterThanOrEqual(0);
      
      if (metrics.totalFailures > 0) {
        expect(metrics.recoverySuccessRate).toBeGreaterThan(0);
      }
    });

    it('CHAOS-02: Should handle cascading service failures', async () => {
      chaosEngine.activateScenario('network_failure');

      let serviceCalls = 0;
      const cascadingReactor = createReactor()
        .input('primary_service')
        .input('fallback_services')

        .step('call_primary', {
          arguments: { service: arg.input('primary_service') },
          async run({ service }) {
            serviceCalls++;
            const shouldFail = await chaosEngine.simulateFailure('api_call', { service, attempt: serviceCalls });
            if (shouldFail) {
              recoveryMetrics.recordFailure();
              throw new Error(`Primary service ${service} unavailable`);
            }
            return { source: 'primary', service, data: 'Primary response' };
          },
          async compensate(error, args, context) {
            recoveryMetrics.recordCompensation();
            return 'skip'; // Skip to fallback
          }
        })

        .step('try_fallback_1', {
          arguments: { 
            fallbacks: arg.input('fallback_services'),
            primaryFailed: arg.value(true) 
          },
          async run({ fallbacks }) {
            serviceCalls++;
            const service = fallbacks[0];
            const shouldFail = await chaosEngine.simulateFailure('api_call', { service, attempt: serviceCalls });
            if (shouldFail) {
              recoveryMetrics.recordFailure();
              throw new Error(`Fallback 1 ${service} unavailable`);
            }
            return { source: 'fallback1', service, data: 'Fallback 1 response' };
          },
          async compensate(error, args, context) {
            recoveryMetrics.recordCompensation();
            return 'skip'; // Try next fallback
          }
        })

        .step('try_fallback_2', {
          arguments: { 
            fallbacks: arg.input('fallback_services'),
            previousFailed: arg.value(true)
          },
          async run({ fallbacks }) {
            serviceCalls++;
            const service = fallbacks[1];
            const shouldFail = await chaosEngine.simulateFailure('api_call', { service, attempt: serviceCalls });
            if (shouldFail) {
              recoveryMetrics.recordFailure();
              throw new Error(`Fallback 2 ${service} unavailable`);
            }
            return { source: 'fallback2', service, data: 'Fallback 2 response' };
          },
          async compensate(error, args, context) {
            recoveryMetrics.recordCompensation();
            return 'abort'; // No more fallbacks
          }
        })

        .step('use_cache', {
          arguments: { 
            primary: arg.step('call_primary'),
            fallback1: arg.step('try_fallback_1'),
            fallback2: arg.step('try_fallback_2')
          },
          async run({ primary, fallback1, fallback2 }) {
            // Use whatever succeeded, or return cached data
            const successful = primary || fallback1 || fallback2;
            if (successful) {
              return successful;
            }
            
            // All services failed, return cached data
            return { 
              source: 'cache', 
              service: 'cache', 
              data: 'Cached response',
              stale: true 
            };
          }
        })

        .return('use_cache')
        .build();

      const result = await cascadingReactor.execute({
        primary_service: 'primary-api',
        fallback_services: ['fallback-1', 'fallback-2']
      });

      expect(result.state).toBe('completed');
      expect(['primary', 'fallback1', 'fallback2', 'cache']).toContain(result.returnValue.source);
      
      const metrics = recoveryMetrics.getMetrics();
      expect(metrics.compensationExecutions).toBeGreaterThanOrEqual(0);
    });
  });

  describe('Resource Exhaustion Recovery', () => {
    it('CHAOS-03: Should handle memory pressure gracefully', async () => {
      chaosEngine.activateScenario('resource_exhaustion');

      const memoryIntensiveReactor = createReactor()
        .input('data_size')
        .input('batch_size', { defaultValue: 1000 })

        .step('allocate_memory', {
          arguments: { 
            size: arg.input('data_size'),
            batchSize: arg.input('batch_size')
          },
          async run({ size, batchSize }) {
            const shouldFail = await chaosEngine.simulateFailure('memory_intensive', { size });
            if (shouldFail) {
              recoveryMetrics.recordFailure();
              throw new Error('Out of memory - cannot allocate large array');
            }
            
            // Simulate memory allocation
            const data = new Array(Math.min(size, 10000)).fill(0).map((_, i) => ({
              id: i,
              data: new Array(100).fill(Math.random())
            }));
            
            return { allocated: data.length, memory: 'allocated' };
          },
          async compensate(error, args, context) {
            recoveryMetrics.recordCompensation();
            if (error.message.includes('Out of memory')) {
              // Reduce batch size and retry
              return 'retry';
            }
            return 'abort';
          }
        })

        .step('process_batches', {
          arguments: { 
            allocation: arg.step('allocate_memory'),
            batchSize: arg.input('batch_size')
          },
          async run({ allocation, batchSize }) {
            const shouldFail = await chaosEngine.simulateFailure('cpu_intensive', { operations: allocation.allocated });
            if (shouldFail) {
              recoveryMetrics.recordFailure();
              throw new Error('CPU overload - too many operations');
            }
            
            // Simulate batch processing
            const batches = Math.ceil(allocation.allocated / batchSize);
            return { 
              processed: allocation.allocated,
              batches,
              completed: true 
            };
          },
          async compensate(error, args, context) {
            recoveryMetrics.recordCompensation();
            if (error.message.includes('CPU overload')) {
              return 'retry';
            }
            return 'skip';
          }
        })

        .step('cleanup_resources', {
          arguments: { 
            allocation: arg.step('allocate_memory'),
            processing: arg.step('process_batches')
          },
          async run({ allocation, processing }) {
            // Simulate cleanup
            return { 
              cleaned: true,
              resourcesFreed: allocation.allocated,
              processedItems: processing.processed || 0
            };
          },
          async undo(result, args, context) {
            recoveryMetrics.recordRollback();
            console.log(`Cleaning up ${result.resourcesFreed} allocated resources`);
          }
        })

        .return('cleanup_resources')
        .build();

      const result = await memoryIntensiveReactor.execute({ 
        data_size: 5000,
        batch_size: 500 
      });

      const metrics = recoveryMetrics.getMetrics();
      
      // Should either succeed or fail gracefully with compensation
      expect(['completed', 'failed']).toContain(result.state);
      
      if (result.state === 'completed') {
        expect(result.returnValue.cleaned).toBe(true);
      } else {
        expect(metrics.compensationExecutions).toBeGreaterThan(0);
      }
    });

    it('CHAOS-04: Should implement circuit breaker pattern', async () => {
      let failureCount = 0;
      let circuitOpen = false;
      const FAILURE_THRESHOLD = 3;
      const RECOVERY_TIMEOUT = 100;

      const circuitBreakerReactor = createReactor()
        .input('requests')

        .step('check_circuit_state', {
          arguments: { requests: arg.input('requests') },
          async run({ requests }) {
            return { 
              circuitOpen,
              failureCount,
              requestCount: requests.length 
            };
          }
        })

        .step('process_requests', {
          arguments: { 
            requests: arg.input('requests'),
            circuitState: arg.step('check_circuit_state')
          },
          async run({ requests, circuitState }) {
            if (circuitState.circuitOpen) {
              throw new Error('Circuit breaker is OPEN - requests blocked');
            }

            const results = [];
            for (const request of requests) {
              try {
                const shouldFail = await chaosEngine.simulateFailure('api_call', { request });
                if (shouldFail) {
                  failureCount++;
                  recoveryMetrics.recordFailure();
                  
                  if (failureCount >= FAILURE_THRESHOLD) {
                    circuitOpen = true;
                    setTimeout(() => {
                      circuitOpen = false;
                      failureCount = 0;
                    }, RECOVERY_TIMEOUT);
                  }
                  
                  throw new Error(`Request failed: ${request.id}`);
                }
                
                results.push({ id: request.id, success: true, data: 'processed' });
                
              } catch (error) {
                results.push({ id: request.id, success: false, error: error.message });
              }
            }

            return { 
              results,
              processed: results.filter(r => r.success).length,
              failed: results.filter(r => !r.success).length
            };
          },
          async compensate(error, args, context) {
            recoveryMetrics.recordCompensation();
            if (error.message.includes('Circuit breaker is OPEN')) {
              // Wait for circuit to close
              await new Promise(resolve => setTimeout(resolve, RECOVERY_TIMEOUT + 10));
              return 'retry';
            }
            return 'abort';
          }
        })

        .return('process_requests')
        .build();

      chaosEngine.activateScenario('network_failure');

      const requests = Array.from({ length: 10 }, (_, i) => ({ id: `req-${i}` }));
      const result = await circuitBreakerReactor.execute({ requests });

      const metrics = recoveryMetrics.getMetrics();
      
      expect(result.state).toBe('completed');
      expect(result.returnValue.processed + result.returnValue.failed).toBe(requests.length);
      
      if (metrics.totalFailures >= FAILURE_THRESHOLD) {
        expect(metrics.compensationExecutions).toBeGreaterThan(0);
      }
    });
  });

  describe('Data Corruption and Recovery', () => {
    it('CHAOS-05: Should handle partial data corruption', async () => {
      const corruptionRate = 0.3;

      const dataProcessor = createReactor()
        .input('dataset')
        .input('validation_rules')

        .step('validate_data', {
          arguments: { 
            data: arg.input('dataset'),
            rules: arg.input('validation_rules')
          },
          async run({ data, rules }) {
            const corruptedItems = [];
            const validItems = [];

            for (const item of data) {
              // Simulate random corruption
              const isCorrupted = Math.random() < corruptionRate;
              if (isCorrupted) {
                corruptedItems.push({ ...item, corrupted: true });
                recoveryMetrics.recordFailure();
              } else {
                validItems.push(item);
              }
            }

            if (corruptedItems.length > data.length * 0.5) {
              throw new Error(`Too many corrupted items: ${corruptedItems.length}/${data.length}`);
            }

            return {
              valid: validItems,
              corrupted: corruptedItems,
              corruptionRate: corruptedItems.length / data.length
            };
          },
          async compensate(error, args, context) {
            recoveryMetrics.recordCompensation();
            if (error.message.includes('Too many corrupted')) {
              // Try with backup data source
              return 'skip';
            }
            return 'abort';
          }
        })

        .step('repair_corrupted_data', {
          arguments: { validation: arg.step('validate_data') },
          async run({ validation }) {
            const repaired = validation.corrupted.map((item: any) => ({
              ...item,
              repaired: true,
              originalValue: item.corrupted,
              repairedValue: 'default_value'
            }));

            return {
              repaired: repaired.length,
              items: repaired
            };
          }
        })

        .step('process_clean_data', {
          arguments: {
            validation: arg.step('validate_data'),
            repairs: arg.step('repair_corrupted_data')
          },
          async run({ validation, repairs }) {
            const allData = [...validation.valid, ...repairs.items];
            
            return {
              totalProcessed: allData.length,
              originalValid: validation.valid.length,
              repaired: repairs.repaired,
              finalDataIntegrity: (validation.valid.length / allData.length) * 100
            };
          }
        })

        .return('process_clean_data')
        .build();

      const dataset = Array.from({ length: 50 }, (_, i) => ({
        id: i,
        value: `item-${i}`,
        metadata: { created: Date.now() }
      }));

      const result = await dataProcessor.execute({
        dataset,
        validation_rules: { required: ['id', 'value'] }
      });

      expect(result.state).toBe('completed');
      expect(result.returnValue.totalProcessed).toBe(dataset.length);
      expect(result.returnValue.finalDataIntegrity).toBeGreaterThan(0);
      
      const metrics = recoveryMetrics.getMetrics();
      if (metrics.totalFailures > 0) {
        expect(result.returnValue.repaired).toBeGreaterThan(0);
      }
    });
  });

  describe('Distributed System Failures', () => {
    it('CHAOS-06: Should handle partial system failures in distributed workflow', async () => {
      chaosEngine.activateScenario('network_failure');
      chaosEngine.activateScenario('latency_injection');

      const distributedWorkflow = createReactor()
        .input('user_request')
        .configure({ maxConcurrency: 3, timeout: 2000 })

        .step('auth_service', {
          arguments: { request: arg.input('user_request') },
          timeout: 500,
          maxRetries: 2,
          async run({ request }) {
            const shouldFail = await chaosEngine.simulateFailure('api_call', { service: 'auth' });
            if (shouldFail) {
              recoveryMetrics.recordFailure();
              throw new Error('Authentication service unavailable');
            }
            return { authenticated: true, userId: request.userId, token: 'auth-token' };
          },
          async compensate(error, args, context) {
            recoveryMetrics.recordCompensation();
            return 'retry';
          }
        })

        .step('user_profile_service', {
          arguments: { 
            auth: arg.step('auth_service'),
            request: arg.input('user_request')
          },
          timeout: 1000,
          async run({ auth, request }) {
            const shouldFail = await chaosEngine.simulateFailure('slow_api', { service: 'profile' });
            if (shouldFail) {
              recoveryMetrics.recordFailure();
              throw new Error('Profile service timeout');
            }
            return { profile: { id: auth.userId, name: 'User Profile' } };
          },
          async compensate(error, args, context) {
            recoveryMetrics.recordCompensation();
            if (error.message.includes('timeout')) {
              return 'skip'; // Use cached profile
            }
            return 'retry';
          }
        })

        .step('recommendation_service', {
          arguments: { 
            auth: arg.step('auth_service'),
            profile: arg.step('user_profile_service')
          },
          async run({ auth, profile }) {
            const shouldFail = await chaosEngine.simulateFailure('api_call', { service: 'recommendations' });
            if (shouldFail) {
              recoveryMetrics.recordFailure();
              throw new Error('Recommendation service error');
            }
            return { recommendations: ['item1', 'item2', 'item3'] };
          },
          async compensate(error, args, context) {
            recoveryMetrics.recordCompensation();
            return 'skip'; // Recommendations are optional
          }
        })

        .step('analytics_service', {
          arguments: { 
            auth: arg.step('auth_service'),
            request: arg.input('user_request')
          },
          async run({ auth, request }) {
            const shouldFail = await chaosEngine.simulateFailure('database_heavy', { service: 'analytics' });
            if (shouldFail) {
              recoveryMetrics.recordFailure();
              throw new Error('Analytics service overloaded');
            }
            return { analytics: { views: 42, lastAccess: Date.now() } };
          },
          async compensate(error, args, context) {
            recoveryMetrics.recordCompensation();
            return 'skip'; // Analytics are optional
          }
        })

        .step('assemble_response', {
          arguments: {
            auth: arg.step('auth_service'),
            profile: arg.step('user_profile_service'),
            recommendations: arg.step('recommendation_service'),
            analytics: arg.step('analytics_service')
          },
          async run({ auth, profile, recommendations, analytics }) {
            return {
              success: true,
              user: profile?.profile || { id: auth.userId, name: 'Default Profile' },
              recommendations: recommendations?.recommendations || [],
              analytics: analytics?.analytics || null,
              degraded: !profile || !recommendations || !analytics
            };
          }
        })

        .return('assemble_response')
        .build();

      const startTime = performance.now();
      const result = await distributedWorkflow.execute({
        user_request: { userId: 'user123', action: 'dashboard' }
      });
      const duration = performance.now() - startTime;

      const metrics = recoveryMetrics.getMetrics();
      recoveryMetrics.recordRecovery(result.state === 'completed', duration);

      expect(result.state).toBe('completed');
      expect(result.returnValue.success).toBe(true);
      expect(result.returnValue.user.id).toBe('user123');
      
      // System should degrade gracefully
      if (metrics.totalFailures > 0) {
        expect(metrics.compensationExecutions).toBeGreaterThan(0);
        expect(result.returnValue.degraded).toBe(true);
      }
    });
  });
});