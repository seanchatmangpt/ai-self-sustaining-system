/**
 * Debug closure-based step creation (like AI swarm test)
 */

import { describe, it, expect, vi, beforeEach } from 'vitest';
import { ReactorEngine } from '../core/reactor-engine';
import { setupTestEnvironment, generateMockSwarmTasks } from './advanced/test-fixtures';

describe('Debug Closure Step', () => {
  let testEnv: ReturnType<typeof setupTestEnvironment>;

  beforeEach(() => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date('2022-01-01'));
    testEnv = setupTestEnvironment();
  });

  afterEach(() => {
    vi.useRealTimers();
    testEnv.cleanup();
  });

  it('should work with closure-based step creation', async () => {
    // Mimic the exact structure from AI swarm test
    const createTestReactor = (deps: any) => {
      const reactor = new ReactorEngine({
        id: `test_${deps.timeProvider.now()}`,
        timeout: 5000
      });

      const claudeStep = {
        name: 'claude-priority-analysis',
        description: 'AI-powered task prioritization with confidence scoring',
        
        async run(input: any, context: any) {
          console.log('Closure step input:', input);
          console.log('deps.apiMock type:', typeof deps.apiMock);
          console.log('deps.apiMock.$fetch type:', typeof deps.apiMock.$fetch);
          
          try {
            const analysis = await deps.apiMock.$fetch('/api/claude/analyze-priorities', {
              method: 'POST',
              body: {
                tasks: input.tasks,
                context: {
                  traceId: context.traceId,
                  timestamp: deps.timeProvider.now(),
                  agentCapabilities: context.metadata?.agentCapabilities
                }
              }
            });
            
            console.log('Closure API response:', analysis);
            
            return { 
              success: true, 
              data: {
                prioritizedTasks: analysis.priorities,
                confidenceScore: analysis.confidence,
                reasoning: analysis.reasoning,
                recommendedAgentCount: analysis.recommended_agents
              }
            };
          } catch (error) {
            console.error('Closure step error:', error);
            return { success: false, error: error as Error };
          }
        },
        
        async compensate() {
          return 'retry';
        }
      };

      reactor.addStep(claudeStep);
      return reactor;
    };

    const reactor = createTestReactor(testEnv);
    const tasks = generateMockSwarmTasks(3);
    
    const result = await reactor.execute({ tasks });

    console.log('Closure reactor result state:', result.state);
    console.log('Closure reactor errors:', result.errors);

    expect(result.state).toBe('completed');
    expect(result.results.has('claude-priority-analysis')).toBe(true);
    
    const stepResult = result.results.get('claude-priority-analysis');
    expect(stepResult.success).toBe(true);
  });
});