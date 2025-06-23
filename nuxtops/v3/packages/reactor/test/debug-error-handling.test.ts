/**
 * Debug Error Handling Test
 * Simple test to debug the retry mechanism
 */

import { describe, it, expect } from 'vitest';
import { createReactor, arg } from '../core/reactor-builder';

describe('Debug Error Handling', () => {
  it('Should debug retry mechanism', async () => {
    let attempts = 0;

    const reactor = createReactor()
      .input('message')
      .step('test_step', {
        arguments: { message: arg.input('message') },
        maxRetries: 2,
        async run({ message }) {
          attempts++;
          console.log(`Attempt ${attempts} for message: ${message}`);
          
          if (attempts < 3) {
            const error = new Error('Network timeout') as any;
            error.type = 'network_timeout';
            throw error;
          }
          
          const result = { sent: true, messageId: `msg_${attempts}`, attempts };
          console.log(`Success result:`, result);
          return result;
        },
        async compensate(error: any) {
          console.log(`Compensation called: ${error.message}`);
          console.log(`Error type: ${error.type}`);
          
          if (error.type === 'network_timeout') {
            console.log('Returning retry');
            return 'retry';
          }
          console.log('Returning abort');
          return 'abort';
        }
      })
      .return('test_step')
      .build();

    console.log('\\n=== STARTING REACTOR ===');
    const result = await reactor.execute({ message: 'test' });
    
    console.log('\\n=== REACTOR RESULT ===');
    console.log('State:', result.state);
    console.log('Return Value:', result.returnValue);
    console.log('Results Map:', Array.from(result.results.entries()));
    console.log('Errors:', result.errors);
    console.log('Attempts:', attempts);
    
    expect(attempts).toBe(3);
  });
});