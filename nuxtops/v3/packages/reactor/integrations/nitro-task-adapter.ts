/**
 * Nitro Task Adapter for Nuxt Reactor
 * Integrates reactor pattern with Nitro's task system for background processing
 */

import type { NitroTask, NitroTaskMeta, NitroTaskPayload } from 'nitropack';
import type { ReactorStep, StepResult, ReactorContext } from '../types';
import { ReactorEngine } from '../core/reactor-engine';

export interface ReactorTaskPayload extends NitroTaskPayload {
  reactorId: string;
  steps: Array<{
    name: string;
    config: any;
  }>;
  input?: any;
  context?: Partial<ReactorContext>;
}

export interface ReactorTaskResult {
  reactorId: string;
  state: string;
  duration: number;
  results: Record<string, any>;
  errors: string[];
}

/**
 * Creates a Nitro task that executes a reactor workflow
 */
export function defineReactorTask(
  name: string,
  stepBuilders: Record<string, (config: any) => ReactorStep>
): NitroTask {
  return {
    async run(payload: ReactorTaskPayload): Promise<ReactorTaskResult> {
      // Create reactor instance
      const reactor = new ReactorEngine({
        id: payload.reactorId,
        context: payload.context
      });
      
      // Build and add steps from payload
      for (const stepConfig of payload.steps) {
        const builder = stepBuilders[stepConfig.name];
        if (!builder) {
          throw new Error(`Unknown step type: ${stepConfig.name}`);
        }
        
        const step = builder(stepConfig.config);
        reactor.addStep(step);
      }
      
      // Execute reactor
      const result = await reactor.execute(payload.input);
      
      // Convert results to serializable format
      const serializedResults: Record<string, any> = {};
      result.results.forEach((value, key) => {
        serializedResults[key] = value.success ? value.data : { error: value.error.message };
      });
      
      return {
        reactorId: result.id,
        state: result.state,
        duration: result.duration,
        results: serializedResults,
        errors: result.errors.map(e => e.message)
      };
    },
    
    meta: {
      name,
      description: `Reactor workflow task: ${name}`
    }
  };
}

/**
 * Step builder that delegates to a Nitro task
 */
export function nitroTaskStep(
  stepName: string,
  taskName: string,
  payloadBuilder: (input: any, context: ReactorContext) => any
): ReactorStep {
  return {
    name: stepName,
    description: `Execute Nitro task: ${taskName}`,
    
    async run(input, context) {
      try {
        // Import Nitro's runTask dynamically
        const { runTask } = await import('#internal/nitro');
        
        // Build task payload
        const payload = payloadBuilder(input, context);
        
        // Run the task
        const result = await runTask(taskName, payload);
        
        return { success: true, data: result };
      } catch (error) {
        return { success: false, error: error as Error };
      }
    },
    
    async compensate(error, input, context) {
      // Tasks might have their own compensation logic
      console.error(`Nitro task ${taskName} failed:`, error);
      return 'retry';
    }
  };
}

/**
 * Creates a scheduled reactor workflow using Nitro's scheduled tasks
 */
export function defineScheduledReactor(
  name: string,
  cron: string,
  reactorBuilder: () => ReactorEngine
): NitroTask {
  return {
    async run() {
      const reactor = reactorBuilder();
      const result = await reactor.execute();
      
      // Log or store results
      console.log(`Scheduled reactor ${name} completed:`, {
        id: result.id,
        state: result.state,
        duration: result.duration
      });
      
      return result;
    },
    
    meta: {
      name,
      description: `Scheduled reactor workflow: ${name}`,
      scheduledTask: cron
    }
  };
}

/**
 * Middleware to track reactor execution in Nitro tasks
 */
export class NitroTaskMiddleware {
  name = 'nitro-task';
  private taskId?: string;
  
  constructor(taskId?: string) {
    this.taskId = taskId;
  }
  
  async beforeReactor(context: ReactorContext): Promise<void> {
    // Add task context
    if (this.taskId) {
      context.nitroTaskId = this.taskId;
    }
    
    // Track in Nitro storage if available
    try {
      const storage = await import('#internal/nitro/storage');
      await storage.setItem(`reactor:${context.id}:start`, {
        startTime: Date.now(),
        taskId: this.taskId
      });
    } catch (e) {
      // Storage might not be available in all contexts
    }
  }
  
  async afterReactor(context: ReactorContext, result: any): Promise<void> {
    // Update completion status
    try {
      const storage = await import('#internal/nitro/storage');
      await storage.setItem(`reactor:${context.id}:complete`, {
        endTime: Date.now(),
        state: result.state,
        duration: result.duration
      });
    } catch (e) {
      // Storage might not be available
    }
  }
}