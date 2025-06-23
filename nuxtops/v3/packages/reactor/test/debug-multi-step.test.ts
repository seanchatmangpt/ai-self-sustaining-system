/**
 * Debug multi-step reactor like AI swarm
 */

import { describe, it, expect, vi, beforeEach } from 'vitest';
import { ReactorEngine } from '../core/reactor-engine';
import { setupTestEnvironment, generateMockSwarmTasks } from './advanced/test-fixtures';

describe('Debug Multi-Step Reactor', () => {
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

  it('should execute multi-step AI swarm reactor', async () => {
    const reactor = new ReactorEngine({
      id: `ai_swarm_${testEnv.timeProvider.now()}`,
      maxConcurrency: 10
    });

    // Step 1: Claude priority analysis
    const claudePriorityAnalysis = {
      name: 'claude-priority-analysis',
      description: 'AI-powered task prioritization with confidence scoring',
      
      async run(input: any, context: any) {
        console.log('Step 1 - Claude Priority Analysis');
        console.log('Input:', JSON.stringify(input, null, 2));
        
        try {
          const analysis = await testEnv.apiMock.$fetch('/api/claude/analyze-priorities', {
            method: 'POST',
            body: {
              tasks: input.tasks,
              context: {
                traceId: context.traceId,
                timestamp: testEnv.timeProvider.now(),
                agentCapabilities: context.metadata?.agentCapabilities
              }
            }
          });
          
          console.log('Step 1 API response:', analysis);
          
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
          console.error('Step 1 error:', error);
          return { success: false, error: error as Error };
        }
      },
      
      async compensate() {
        console.log('Step 1 compensation');
        return 'retry';
      }
    };

    // Step 2: Agent formation
    const agentFormation = {
      name: 'agent-formation',
      description: 'Spawn AI agents with nanosecond precision IDs',
      dependencies: ['claude-priority-analysis'],
      
      async run(input: any, context: any) {
        console.log('Step 2 - Agent Formation');
        
        try {
          const priorityResult = context.results?.get('claude-priority-analysis');
          if (!priorityResult?.data) {
            throw new Error('Priority analysis data not available');
          }
          
          const agentCount = priorityResult.data.recommendedAgentCount || 2;
          const agents = [];
          
          for (let i = 0; i < agentCount; i++) {
            const agentId = `agent_${testEnv.timeProvider.now()}${testEnv.platformProvider.getHighResolutionTime().toString().slice(-9)}`;
            
            const agent = {
              id: agentId,
              capabilities: {
                type: 'analysis',
                specialization: ['analysis', 'optimization'],
                concurrency: 2,
                efficiency: 0.8
              }
            };
            
            // Register agent
            await testEnv.apiMock.$fetch('/api/coordination/register-agent', {
              method: 'POST',
              body: {
                agentId,
                capabilities: agent.capabilities,
                parentReactorId: context.id,
                traceId: context.traceId
              }
            });
            
            agents.push(agent);
          }
          
          console.log('Step 2 - Created agents:', agents.length);
          
          return { 
            success: true, 
            data: { agents }
          };
        } catch (error) {
          console.error('Step 2 error:', error);
          return { success: false, error: error as Error };
        }
      }
    };

    reactor.addStep(claudePriorityAnalysis);
    reactor.addStep(agentFormation);

    const tasks = generateMockSwarmTasks(3);
    const result = await reactor.execute({ tasks });

    console.log('Final result state:', result.state);
    console.log('Final result errors:', result.errors);
    console.log('Results keys:', Array.from(result.results.keys()));
    
    result.results.forEach((stepResult, stepName) => {
      console.log(`${stepName}:`, stepResult.success ? 'SUCCESS' : 'FAILED');
      if (!stepResult.success) {
        console.log(`${stepName} error:`, stepResult.error);
      }
    });

    expect(result.state).toBe('completed');
    expect(result.results.has('claude-priority-analysis')).toBe(true);
    expect(result.results.has('agent-formation')).toBe(true);
  });
});