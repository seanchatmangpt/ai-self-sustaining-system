/**
 * Debug specific step execution
 */

import { describe, it, expect, vi, beforeEach } from 'vitest';
import { ReactorEngine } from '../core/reactor-engine';
import { setupTestEnvironment, generateMockSwarmTasks } from './advanced/test-fixtures';

describe('Debug Step Execution', () => {
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

  it('should execute a single Claude API step', async () => {
    const reactor = new ReactorEngine({
      id: `debug_test_${testEnv.timeProvider.now()}`,
      timeout: 5000
    });

    // Add a simple step that makes an API call
    const claudeStep = {
      name: 'claude-test',
      description: 'Test Claude API call',
      
      async run(input: any, context: any) {
        console.log('Step input:', input);
        console.log('testEnv.apiMock type:', typeof testEnv.apiMock);
        console.log('testEnv.apiMock.$fetch type:', typeof testEnv.apiMock.$fetch);
        
        try {
          const analysis = await testEnv.apiMock.$fetch('/api/claude/analyze-priorities', {
            method: 'POST',
            body: {
              tasks: input.tasks,
              context: {
                traceId: context.traceId,
                timestamp: testEnv.timeProvider.now()
              }
            }
          });
          
          console.log('API response:', analysis);
          
          return { 
            success: true, 
            data: {
              prioritizedTasks: analysis.priorities,
              confidenceScore: analysis.confidence
            }
          };
        } catch (error) {
          console.error('Step error:', error);
          return { success: false, error: error as Error };
        }
      }
    };

    reactor.addStep(claudeStep);

    const tasks = generateMockSwarmTasks(2);
    const result = await reactor.execute({ tasks });

    console.log('Reactor result:', result);
    console.log('Result state:', result.state);
    console.log('Result errors:', result.errors);

    expect(result.state).toBe('completed');
    expect(result.results.has('claude-test')).toBe(true);
    
    const stepResult = result.results.get('claude-test');
    expect(stepResult.success).toBe(true);
  });
});