/**
 * Test async workflow patterns equivalent to Elixir Reactor
 * Based on: https://hexdocs.pm/reactor/03-async-workflows.html
 */

import { describe, it, expect, vi, beforeEach } from 'vitest';
import { ReactorEngine } from '../core/reactor-engine';
import { ReactorStep } from '../types';

describe('Async Workflow Patterns', () => {
  beforeEach(() => {
    // Use real timers for async tests to avoid timeout issues
    vi.useRealTimers();
  });

  describe('Parallel Execution (Default Async Behavior)', () => {
    it('should run independent steps in parallel', async () => {
      const reactor = new ReactorEngine({
        id: 'parallel-test',
        maxConcurrency: 10
      });

      const executionOrder: string[] = [];
      const startTime = Date.now();

      // Three independent async steps that should run in parallel
      const stepA: ReactorStep = {
        name: 'fetch-user-profile',
        description: 'Fetch user profile data',
        async run(args, context) {
          executionOrder.push('A-start');
          await new Promise(resolve => setTimeout(resolve, 10));
          executionOrder.push('A-end');
          return { 
            success: true, 
            data: { profile: 'user-123', fetchTime: Date.now() - startTime } 
          };
        }
      };

      const stepB: ReactorStep = {
        name: 'fetch-user-preferences',
        description: 'Fetch user preferences',
        async run(args, context) {
          executionOrder.push('B-start');
          await new Promise(resolve => setTimeout(resolve, 10));
          executionOrder.push('B-end');
          return { 
            success: true, 
            data: { preferences: ['dark-mode'], fetchTime: Date.now() - startTime } 
          };
        }
      };

      const stepC: ReactorStep = {
        name: 'fetch-user-activity',
        description: 'Fetch user activity log',
        async run(args, context) {
          executionOrder.push('C-start');
          await new Promise(resolve => setTimeout(resolve, 10));
          executionOrder.push('C-end');
          return { 
            success: true, 
            data: { activities: ['login'], fetchTime: Date.now() - startTime } 
          };
        }
      };

      reactor.addStep(stepA);
      reactor.addStep(stepB);
      reactor.addStep(stepC);

      const result = await reactor.execute({ user_id: '123' });

      expect(result.state).toBe('completed');
      expect(result.results.size).toBe(3);

      // Verify all steps started before any completed (parallel execution)
      expect(executionOrder.slice(0, 3)).toEqual(['A-start', 'B-start', 'C-start']);
      
      // All steps should complete within roughly the same timeframe due to parallelism
      const profileResult = result.results.get('fetch-user-profile');
      const preferencesResult = result.results.get('fetch-user-preferences');
      const activityResult = result.results.get('fetch-user-activity');

      expect(profileResult.success).toBe(true);
      expect(preferencesResult.success).toBe(true);
      expect(activityResult.success).toBe(true);
    });

    it('should respect step dependencies for execution order', async () => {
      const reactor = new ReactorEngine({
        id: 'dependency-test',
        maxConcurrency: 10
      });

      const executionOrder: string[] = [];

      // Step 1: Independent data fetch
      const fetchUserStep: ReactorStep = {
        name: 'fetch-user',
        async run(args, context) {
          executionOrder.push('fetch-user');
          await new Promise(resolve => setTimeout(resolve, 5));
          return { 
            success: true, 
            data: { user: { id: args.user_id, name: 'John' } } 
          };
        }
      };

      // Step 2: Parallel data fetching (depends on user)
      const fetchProfileStep: ReactorStep = {
        name: 'fetch-profile',
        dependencies: ['fetch-user'],
        async run(args, context) {
          executionOrder.push('fetch-profile');
          const userResult = context.results.get('fetch-user');
          await new Promise(resolve => setTimeout(resolve, 50));
          return { 
            success: true, 
            data: { profile: `profile-${userResult.data.user.id}` } 
          };
        }
      };

      const fetchPreferencesStep: ReactorStep = {
        name: 'fetch-preferences',
        dependencies: ['fetch-user'],
        async run(args, context) {
          executionOrder.push('fetch-preferences');
          const userResult = context.results.get('fetch-user');
          await new Promise(resolve => setTimeout(resolve, 50));
          return { 
            success: true, 
            data: { preferences: [`pref-${userResult.data.user.id}`] } 
          };
        }
      };

      // Step 3: Aggregation (depends on all previous steps)
      const aggregateStep: ReactorStep = {
        name: 'aggregate-data',
        dependencies: ['fetch-profile', 'fetch-preferences'],
        async run(args, context) {
          executionOrder.push('aggregate-data');
          const profileResult = context.results.get('fetch-profile');
          const preferencesResult = context.results.get('fetch-preferences');
          return {
            success: true,
            data: {
              aggregated: {
                profile: profileResult.data.profile,
                preferences: preferencesResult.data.preferences
              }
            }
          };
        }
      };

      reactor.addStep(fetchUserStep);
      reactor.addStep(fetchProfileStep);
      reactor.addStep(fetchPreferencesStep);
      reactor.addStep(aggregateStep);

      const result = await reactor.execute({ user_id: '123' });

      expect(result.state).toBe('completed');
      expect(result.results.size).toBe(4);

      // Verify execution order respects dependencies
      expect(executionOrder[0]).toBe('fetch-user');
      expect(executionOrder.includes('fetch-profile')).toBe(true);
      expect(executionOrder.includes('fetch-preferences')).toBe(true);
      expect(executionOrder[3]).toBe('aggregate-data');

      // Verify final aggregated result
      const aggregateResult = result.results.get('aggregate-data');
      expect(aggregateResult.data.aggregated.profile).toBe('profile-123');
      expect(aggregateResult.data.aggregated.preferences).toEqual(['pref-123']);
    });
  });

  describe('Concurrency Control', () => {
    it('should respect maxConcurrency limits', async () => {
      const reactor = new ReactorEngine({
        id: 'concurrency-test',
        maxConcurrency: 2 // Limit to 2 concurrent operations
      });

      let currentlyRunning = 0;
      let maxConcurrentReached = 0;

      const createConcurrencyTestStep = (name: string): ReactorStep => ({
        name,
        async run(args, context) {
          currentlyRunning++;
          maxConcurrentReached = Math.max(maxConcurrentReached, currentlyRunning);
          
          await new Promise(resolve => setTimeout(resolve, 100));
          
          currentlyRunning--;
          return { 
            success: true, 
            data: { step: name } 
          };
        }
      });

      // Add 5 independent steps
      for (let i = 1; i <= 5; i++) {
        reactor.addStep(createConcurrencyTestStep(`step-${i}`));
      }

      const result = await reactor.execute({});

      expect(result.state).toBe('completed');
      expect(result.results.size).toBe(5);
      
      // Should never exceed maxConcurrency limit
      expect(maxConcurrentReached).toBeLessThanOrEqual(2);
      expect(maxConcurrentReached).toBe(2); // Should reach the limit
    });
  });

  describe('Error Handling and Compensation', () => {
    it('should handle step failures with compensation strategies', async () => {
      const reactor = new ReactorEngine({
        id: 'error-handling-test',
        maxConcurrency: 5
      });

      let compensationCalled = false;

      const successStep: ReactorStep = {
        name: 'success-step',
        async run(args, context) {
          return { 
            success: true, 
            data: { result: 'success' } 
          };
        }
      };

      const failingStep: ReactorStep = {
        name: 'failing-step',
        dependencies: ['success-step'],
        async run(args, context) {
          throw new Error('Simulated failure');
        },
        async compensate(error, args, context) {
          compensationCalled = true;
          return 'skip'; // Skip this step and continue
        }
      };

      const finalStep: ReactorStep = {
        name: 'final-step',
        dependencies: ['failing-step'],
        async run(args, context) {
          // Should still execute even though failing-step was skipped
          return { 
            success: true, 
            data: { final: 'completed' } 
          };
        }
      };

      reactor.addStep(successStep);
      reactor.addStep(failingStep);
      reactor.addStep(finalStep);

      const result = await reactor.execute({});

      expect(result.state).toBe('completed');
      expect(compensationCalled).toBe(true);
      
      // Success step should complete
      expect(result.results.get('success-step').success).toBe(true);
      
      // Failing step should be skipped (compensation result)
      expect(result.results.get('failing-step').success).toBe(true);
      expect(result.results.get('failing-step').data).toBe(null);
      
      // Final step should still execute
      expect(result.results.get('final-step').success).toBe(true);
    });

    it('should support retry compensation strategy', async () => {
      const reactor = new ReactorEngine({
        id: 'retry-test',
        maxConcurrency: 5
      });

      let attemptCount = 0;

      const retryStep: ReactorStep = {
        name: 'retry-step',
        retries: 2,
        async run(args, context) {
          attemptCount++;
          if (attemptCount < 3) {
            throw new Error(`Attempt ${attemptCount} failed`);
          }
          return { 
            success: true, 
            data: { attempts: attemptCount } 
          };
        },
        async compensate(error, args, context) {
          return 'retry';
        }
      };

      reactor.addStep(retryStep);

      const result = await reactor.execute({});

      expect(result.state).toBe('completed');
      expect(attemptCount).toBe(3); // Initial attempt + 2 retries
      expect(result.results.get('retry-step').success).toBe(true);
      expect(result.results.get('retry-step').data.attempts).toBe(3);
    });

    it('should support continue with value compensation strategy', async () => {
      const reactor = new ReactorEngine({
        id: 'continue-test',
        maxConcurrency: 5
      });

      const fallbackStep: ReactorStep = {
        name: 'fallback-step',
        async run(args, context) {
          throw new Error('Service unavailable');
        },
        async compensate(error, args, context) {
          // Provide fallback value
          return { continue: { fallback: true, reason: 'service-unavailable' } };
        }
      };

      const dependentStep: ReactorStep = {
        name: 'dependent-step',
        dependencies: ['fallback-step'],
        async run(args, context) {
          const fallbackResult = context.results.get('fallback-step');
          return { 
            success: true, 
            data: { 
              used_fallback: fallbackResult.data.fallback,
              reason: fallbackResult.data.reason
            } 
          };
        }
      };

      reactor.addStep(fallbackStep);
      reactor.addStep(dependentStep);

      const result = await reactor.execute({});

      expect(result.state).toBe('completed');
      
      // Fallback step should "succeed" with compensation value
      expect(result.results.get('fallback-step').success).toBe(true);
      expect(result.results.get('fallback-step').data.fallback).toBe(true);
      
      // Dependent step should use the fallback value
      expect(result.results.get('dependent-step').success).toBe(true);
      expect(result.results.get('dependent-step').data.used_fallback).toBe(true);
    });
  });

  describe('Performance and Timeout Handling', () => {
    it('should handle step timeouts appropriately', async () => {
      const reactor = new ReactorEngine({
        id: 'timeout-test',
        timeout: 5000 // Global timeout
      });

      const fastStep: ReactorStep = {
        name: 'fast-step',
        timeout: 100,
        async run(args, context) {
          await new Promise(resolve => setTimeout(resolve, 50));
          return { 
            success: true, 
            data: { completed: 'fast' } 
          };
        }
      };

      const slowStep: ReactorStep = {
        name: 'slow-step',
        timeout: 50, // Will timeout
        async run(args, context) {
          await new Promise(resolve => setTimeout(resolve, 200));
          return { 
            success: true, 
            data: { completed: 'slow' } 
          };
        },
        async compensate(error, args, context) {
          if (error.message.includes('timed out')) {
            return { continue: { timeout: true } };
          }
          return 'abort';
        }
      };

      reactor.addStep(fastStep);
      reactor.addStep(slowStep);

      const result = await reactor.execute({});

      expect(result.state).toBe('completed');
      
      // Fast step should complete normally
      expect(result.results.get('fast-step').success).toBe(true);
      expect(result.results.get('fast-step').data.completed).toBe('fast');
      
      // Slow step should timeout but compensate
      expect(result.results.get('slow-step').success).toBe(true);
      expect(result.results.get('slow-step').data.timeout).toBe(true);
    });
  });

  describe('Complex Async Workflow Patterns', () => {
    it('should handle complex multi-stage async pipeline', async () => {
      const reactor = new ReactorEngine({
        id: 'complex-pipeline',
        maxConcurrency: 8
      });

      // Stage 1: Parallel data ingestion
      const ingestA: ReactorStep = {
        name: 'ingest-source-a',
        async run(args, context) {
          await new Promise(resolve => setTimeout(resolve, 50));
          return { success: true, data: { source: 'A', records: 100 } };
        }
      };

      const ingestB: ReactorStep = {
        name: 'ingest-source-b',
        async run(args, context) {
          await new Promise(resolve => setTimeout(resolve, 75));
          return { success: true, data: { source: 'B', records: 150 } };
        }
      };

      const ingestC: ReactorStep = {
        name: 'ingest-source-c',
        async run(args, context) {
          await new Promise(resolve => setTimeout(resolve, 60));
          return { success: true, data: { source: 'C', records: 200 } };
        }
      };

      // Stage 2: Parallel processing
      const processA: ReactorStep = {
        name: 'process-a',
        dependencies: ['ingest-source-a'],
        async run(args, context) {
          const sourceData = context.results.get('ingest-source-a');
          await new Promise(resolve => setTimeout(resolve, 40));
          return { 
            success: true, 
            data: { 
              processed: sourceData.data.records * 2,
              source: sourceData.data.source 
            } 
          };
        }
      };

      const processB: ReactorStep = {
        name: 'process-b',
        dependencies: ['ingest-source-b'],
        async run(args, context) {
          const sourceData = context.results.get('ingest-source-b');
          await new Promise(resolve => setTimeout(resolve, 30));
          return { 
            success: true, 
            data: { 
              processed: sourceData.data.records * 1.5,
              source: sourceData.data.source 
            } 
          };
        }
      };

      const processC: ReactorStep = {
        name: 'process-c',
        dependencies: ['ingest-source-c'],
        async run(args, context) {
          const sourceData = context.results.get('ingest-source-c');
          await new Promise(resolve => setTimeout(resolve, 35));
          return { 
            success: true, 
            data: { 
              processed: sourceData.data.records * 1.8,
              source: sourceData.data.source 
            } 
          };
        }
      };

      // Stage 3: Aggregation
      const aggregate: ReactorStep = {
        name: 'aggregate-results',
        dependencies: ['process-a', 'process-b', 'process-c'],
        async run(args, context) {
          const resultA = context.results.get('process-a');
          const resultB = context.results.get('process-b');
          const resultC = context.results.get('process-c');
          
          await new Promise(resolve => setTimeout(resolve, 20));
          
          return {
            success: true,
            data: {
              total_processed: resultA.data.processed + resultB.data.processed + resultC.data.processed,
              sources: [resultA.data.source, resultB.data.source, resultC.data.source],
              pipeline_complete: true
            }
          };
        }
      };

      reactor.addStep(ingestA);
      reactor.addStep(ingestB);
      reactor.addStep(ingestC);
      reactor.addStep(processA);
      reactor.addStep(processB);
      reactor.addStep(processC);
      reactor.addStep(aggregate);

      reactor.setReturn('aggregate-results');

      const result = await reactor.execute({});

      expect(result.state).toBe('completed');
      expect(result.results.size).toBe(7);
      
      // Verify the pipeline completed correctly
      const aggregateResult = result.results.get('aggregate-results');
      expect(aggregateResult.success).toBe(true);
      expect(aggregateResult.data.pipeline_complete).toBe(true);
      expect(aggregateResult.data.total_processed).toBe(785); // 200 + 225 + 360
      expect(aggregateResult.data.sources).toEqual(['A', 'B', 'C']);
      
      // Verify return value
      expect(result.returnValue.pipeline_complete).toBe(true);
    });
  });
});