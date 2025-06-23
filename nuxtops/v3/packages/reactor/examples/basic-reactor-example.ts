/**
 * Basic Reactor Example - Demonstrates feature parity with Elixir Reactor
 * Based on the getting started guide from hexdocs.pm/reactor
 */

import { createReactor, arg } from '../core/reactor-builder';

/**
 * Example 1: Basic workflow with inputs and steps
 * Equivalent to the Elixir example from the getting started guide
 */
export function createBasicWorkflow() {
  return createReactor()
    // Define inputs (like Elixir's `input :param1`)
    .input('param1', { description: 'First parameter' })
    .input('param2', { description: 'Second parameter' })
    
    // Define step with arguments (like Elixir's step with argument)
    .step('process_param1', {
      description: 'Process the first parameter',
      arguments: {
        value: arg.input('param1') // Reference input
      },
      async run({ value }) {
        return value * 2;
      }
    })
    
    .step('combine_params', {
      description: 'Combine both parameters',
      arguments: {
        processed: arg.step('process_param1'), // Reference step result
        param2: arg.input('param2')
      },
      async run({ processed, param2 }) {
        return processed + param2;
      }
    })
    
    // Set return value (like Elixir's `return :step_name`)
    .return('combine_params')
    .build();
}

/**
 * Example 2: Error handling and compensation
 */
export function createErrorHandlingWorkflow() {
  return createReactor()
    .input('user_id')
    .input('email')
    
    .step('validate_user', {
      description: 'Validate user exists',
      arguments: {
        userId: arg.input('user_id')
      },
      maxRetries: 3,
      async run({ userId }) {
        if (!userId || userId < 1) {
          throw new Error('Invalid user ID');
        }
        return { userId, validated: true };
      },
      async compensate(error, args, context) {
        if (error.message.includes('Invalid')) {
          return 'abort'; // Don't retry for validation errors
        }
        return 'retry'; // Retry for other errors
      }
    })
    
    .step('send_email', {
      description: 'Send email to user',
      arguments: {
        user: arg.step('validate_user'),
        email: arg.input('email')
      },
      async run({ user, email }) {
        // Simulate email sending
        if (Math.random() < 0.3) {
          throw new Error('Email service unavailable');
        }
        return { sent: true, to: email, userId: user.userId };
      },
      async compensate(error) {
        if (error.message.includes('unavailable')) {
          return 'retry'; // Retry for service errors
        }
        return 'abort';
      },
      async undo(result) {
        // Compensate by logging the failed email
        console.log(`Rolling back email send to user ${result.userId}`);
      }
    })
    
    .return('send_email')
    .build();
}

/**
 * Example 3: Parallel execution
 */
export function createParallelWorkflow() {
  return createReactor()
    .input('data')
    
    // These steps can run in parallel since they don't depend on each other
    .step('process_a', {
      arguments: { data: arg.input('data') },
      async run({ data }) {
        await new Promise(resolve => setTimeout(resolve, 100));
        return `A: ${data}`;
      }
    })
    
    .step('process_b', {
      arguments: { data: arg.input('data') },
      async run({ data }) {
        await new Promise(resolve => setTimeout(resolve, 50));
        return `B: ${data}`;
      }
    })
    
    .step('process_c', {
      arguments: { data: arg.input('data') },
      async run({ data }) {
        await new Promise(resolve => setTimeout(resolve, 75));
        return `C: ${data}`;
      }
    })
    
    // This step depends on all previous steps
    .step('combine_results', {
      arguments: {
        a: arg.step('process_a'),
        b: arg.step('process_b'),
        c: arg.step('process_c')
      },
      async run({ a, b, c }) {
        return [a, b, c].join(' | ');
      }
    })
    
    .return('combine_results')
    .build();
}

/**
 * Usage examples
 */
export async function runExamples() {
  console.log('=== Basic Workflow ===');
  const basicWorkflow = createBasicWorkflow();
  const basicResult = await basicWorkflow.execute({ param1: 5, param2: 10 });
  console.log('Result:', basicResult.returnValue); // Should be 20 (5*2 + 10)
  
  console.log('\\n=== Error Handling Workflow ===');
  const errorWorkflow = createErrorHandlingWorkflow();
  const errorResult = await errorWorkflow.execute({ 
    user_id: 123, 
    email: 'test@example.com' 
  });
  console.log('Result:', errorResult.returnValue);
  
  console.log('\\n=== Parallel Workflow ===');
  const parallelWorkflow = createParallelWorkflow();
  const parallelResult = await parallelWorkflow.execute({ data: 'test' });
  console.log('Result:', parallelResult.returnValue);
}