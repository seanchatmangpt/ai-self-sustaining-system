/**
 * Focused Elixir Error Handling Pattern Tests
 * Simplified tests to verify exact Elixir reactor error handling behavior
 */

import { describe, it, expect, beforeEach } from 'vitest';
import { createReactor, arg } from '../core/reactor-builder';
import type { CompensationResult } from '../types';

describe('Elixir Error Handling Patterns - Focused', () => {
  let logs: string[] = [];

  beforeEach(() => {
    logs = [];
  });

  describe('Basic Compensation Patterns', () => {
    it('RETRY: Should retry on network timeout (Elixir :retry)', async () => {
      let attempts = 0;

      const reactor = createReactor()
        .input('message')
        .step('send_email', {
          arguments: { message: arg.input('message') },
          maxRetries: 2,
          async run({ message }) {
            attempts++;
            logs.push(`Attempt ${attempts}`);
            
            if (attempts < 3) {
              const error = new Error('Network timeout') as any;
              error.type = 'network_timeout';
              throw error;
            }
            
            return { sent: true, messageId: `msg_${attempts}` };
          },
          async compensate(error: any): Promise<CompensationResult> {
            logs.push(`Compensation called: ${error.message}`);
            
            if (error.type === 'network_timeout') {
              logs.push('Returning retry');
              return 'retry'; // Elixir: :retry
            }
            return 'abort';
          }
        })
        .return('send_email')
        .build();

      const result = await reactor.execute({ message: 'test' });

      expect(result.state).toBe('completed');
      expect(result.returnValue?.sent).toBe(true);
      expect(attempts).toBe(3);
      expect(logs).toContain('Returning retry');
    });

    it('SKIP: Should skip step and continue (Elixir :ok)', async () => {
      const reactor = createReactor()
        .input('user_data')
        .step('validate_email', {
          arguments: { user: arg.input('user_data') },
          async run({ user }) {
            if (!user.email) {
              throw new Error('Email required');
            }
            return { validated: true, email: user.email };
          },
          async compensate(error: any): Promise<CompensationResult> {
            logs.push(`Email validation failed: ${error.message}`);
            logs.push('Skipping email validation');
            return 'skip'; // Elixir: :ok (triggers skip)
          }
        })
        .step('process_user', {
          arguments: { validation: arg.step('validate_email') },
          async run({ validation }) {
            logs.push(`Processing with validation: ${JSON.stringify(validation)}`);
            return { 
              processed: true,
              hasEmail: validation !== null && validation.validated 
            };
          }
        })
        .return('process_user')
        .build();

      const result = await reactor.execute({ 
        user_data: { id: 'user123' } // Missing email
      });

      expect(result.state).toBe('completed');
      expect(result.returnValue?.processed).toBe(true);
      expect(result.returnValue?.hasEmail).toBe(false);
      expect(logs).toContain('Skipping email validation');
    });

    it('CONTINUE with VALUE: Should continue with provided value', async () => {
      const reactor = createReactor()
        .input('api_url')
        .step('fetch_data', {
          arguments: { url: arg.input('api_url') },
          async run({ url }) {
            if (url.includes('broken')) {
              throw new Error('Service unavailable');
            }
            return { data: 'real_data', source: 'api' };
          },
          async compensate(error: any): Promise<CompensationResult> {
            logs.push(`API failed: ${error.message}`);
            logs.push('Providing cached data');
            return { continue: { data: 'cached_data', source: 'cache' } };
          }
        })
        .step('process_data', {
          arguments: { fetchResult: arg.step('fetch_data') },
          async run({ fetchResult }) {
            logs.push(`Processing data from: ${fetchResult.source}`);
            return { 
              processed: true,
              dataSource: fetchResult.source,
              data: fetchResult.data 
            };
          }
        })
        .return('process_data')
        .build();

      const result = await reactor.execute({ 
        api_url: 'https://broken-api.com/data' 
      });

      expect(result.state).toBe('completed');
      expect(result.returnValue?.dataSource).toBe('cache');
      expect(result.returnValue?.data).toBe('cached_data');
      expect(logs).toContain('Providing cached data');
    });
  });

  describe('Undo/Rollback Patterns', () => {
    it('UNDO: Should rollback successful steps on failure', async () => {
      let allocatedResources: string[] = [];
      let sentEmails: string[] = [];

      const reactor = createReactor()
        .input('order')
        .step('allocate_inventory', {
          arguments: { order: arg.input('order') },
          async run({ order }) {
            const resourceId = `inv_${Date.now()}`;
            allocatedResources.push(resourceId);
            logs.push(`Allocated inventory: ${resourceId}`);
            return { resourceId, itemId: order.itemId };
          },
          async undo(result) {
            logs.push(`Releasing inventory: ${result.resourceId}`);
            const index = allocatedResources.indexOf(result.resourceId);
            if (index > -1) {
              allocatedResources.splice(index, 1);
            }
          }
        })
        .step('send_confirmation', {
          arguments: { 
            order: arg.input('order'),
            inventory: arg.step('allocate_inventory')
          },
          async run({ order, inventory }) {
            const emailId = `email_${Date.now()}`;
            sentEmails.push(emailId);
            logs.push(`Sent confirmation: ${emailId}`);
            return { emailId, orderId: order.id };
          },
          async undo(result) {
            logs.push(`Cancelling email: ${result.emailId}`);
            const index = sentEmails.indexOf(result.emailId);
            if (index > -1) {
              sentEmails.splice(index, 1);
            }
          }
        })
        .step('charge_payment', {
          arguments: { 
            order: arg.input('order'),
            inventory: arg.step('allocate_inventory'),
            confirmation: arg.step('send_confirmation')
          },
          async run({ order }) {
            // Force payment failure to trigger rollback
            throw new Error('Payment declined');
          }
        })
        .return('charge_payment')
        .build();

      const result = await reactor.execute({
        order: { id: 'order123', itemId: 'item456', amount: 99.99 }
      });

      expect(result.state).toBe('failed');
      
      // Verify rollback occurred
      expect(logs.some(log => log.includes('Releasing inventory:'))).toBe(true);
      expect(logs.some(log => log.includes('Cancelling email:'))).toBe(true);
      
      // Verify side effects were undone
      expect(allocatedResources).toHaveLength(0);
      expect(sentEmails).toHaveLength(0);
    });

    it('IDEMPOTENT UNDO: Should handle multiple undo calls safely', async () => {
      let resources: string[] = [];
      let undoCalls = 0;

      const reactor = createReactor()
        .input('resource_type')
        .step('create_resource', {
          arguments: { type: arg.input('resource_type') },
          async run({ type }) {
            const resourceId = `${type}_${Date.now()}`;
            resources.push(resourceId);
            logs.push(`Created resource: ${resourceId}`);
            return { resourceId, type };
          },
          async undo(result) {
            undoCalls++;
            logs.push(`Undo call #${undoCalls} for resource: ${result.resourceId}`);
            
            // Idempotent operation - only remove if it exists
            const index = resources.indexOf(result.resourceId);
            if (index > -1) {
              resources.splice(index, 1);
              logs.push(`Actually released: ${result.resourceId}`);
            } else {
              logs.push(`Already released: ${result.resourceId} (idempotent)`);
            }
          }
        })
        .step('configure_resource', {
          arguments: { resource: arg.step('create_resource') },
          async run({ resource }) {
            // Force failure to trigger undo
            throw new Error('Configuration failed');
          }
        })
        .return('configure_resource')
        .build();

      const result = await reactor.execute({ resource_type: 'compute' });

      expect(result.state).toBe('failed');
      expect(undoCalls).toBeGreaterThan(0);
      expect(resources).toHaveLength(0); // Resource was cleaned up
      expect(logs.some(log => log.includes('Actually released:'))).toBe(true);
    });
  });

  describe('Error Type Differentiation', () => {
    it('Should handle different error types with appropriate strategies', async () => {
      const reactor = createReactor()
        .input('operation_type')
        .step('risky_operation', {
          arguments: { type: arg.input('operation_type') },
          async run({ type }) {
            switch (type) {
              case 'network_error':
                const networkError = new Error('Connection timeout') as any;
                networkError.type = 'network_timeout';
                networkError.retryable = true;
                throw networkError;
              
              case 'validation_error':
                const validationError = new Error('Invalid input') as any;
                validationError.type = 'validation_error';
                validationError.retryable = false;
                throw validationError;
              
              case 'service_error':
                const serviceError = new Error('Service unavailable') as any;
                serviceError.type = 'service_unavailable';
                serviceError.retryable = true;
                throw serviceError;
              
              default:
                return { success: true, type };
            }
          },
          async compensate(error: any): Promise<CompensationResult> {
            logs.push(`Handling ${error.type}: ${error.message}`);
            
            // Match Elixir pattern matching
            switch (error.type) {
              case 'network_timeout':
                logs.push('Network error - retrying');
                return 'retry';
              
              case 'validation_error':
                logs.push('Validation error - aborting');
                return 'abort';
              
              case 'service_unavailable':
                logs.push('Service error - skipping');
                return 'skip';
              
              default:
                logs.push('Unknown error - aborting');
                return 'abort';
            }
          }
        })
        .step('handle_result', {
          arguments: { operation: arg.step('risky_operation') },
          async run({ operation }) {
            if (operation === null) {
              return { handled: true, source: 'compensation' };
            }
            return { handled: true, source: 'normal', ...operation };
          }
        })
        .return('handle_result')
        .build();

      // Test network error (should fail after retries)
      const networkResult = await reactor.execute({ operation_type: 'network_error' });
      expect(networkResult.state).toBe('failed');
      expect(logs).toContain('Network error - retrying');

      // Reset logs
      logs = [];

      // Test service error (should skip and continue)
      const serviceResult = await reactor.execute({ operation_type: 'service_error' });
      expect(serviceResult.state).toBe('completed');
      expect(serviceResult.returnValue?.source).toBe('compensation');
      expect(logs).toContain('Service error - skipping');

      // Reset logs
      logs = [];

      // Test validation error (should abort immediately)
      const validationResult = await reactor.execute({ operation_type: 'validation_error' });
      expect(validationResult.state).toBe('failed');
      expect(logs).toContain('Validation error - aborting');
    });
  });

  describe('Performance Validation', () => {
    it('Should demonstrate error handling performance metrics', async () => {
      let operationCount = 0;
      const startTime = Date.now();

      const reactor = createReactor()
        .input('batch_size')
        .step('batch_operations', {
          arguments: { size: arg.input('batch_size') },
          maxRetries: 1,
          async run({ size }) {
            const operations = [];
            for (let i = 0; i < size; i++) {
              operationCount++;
              if (i % 10 === 0 && operationCount < 50) {
                // Simulate occasional failures
                const error = new Error(`Operation ${i} failed`) as any;
                error.type = 'transient_error';
                throw error;
              }
              operations.push({ id: i, result: `result_${i}` });
            }
            return { operations, count: operations.length };
          },
          async compensate(error: any): Promise<CompensationResult> {
            if (error.type === 'transient_error') {
              return 'retry';
            }
            return 'abort';
          }
        })
        .return('batch_operations')
        .build();

      const result = await reactor.execute({ batch_size: 100 });
      const duration = Date.now() - startTime;
      const throughput = operationCount / (duration / 1000);

      console.log('\\n=== ERROR HANDLING PERFORMANCE ===');
      console.log(`Total Operations: ${operationCount}`);
      console.log(`Duration: ${duration}ms`);
      console.log(`Throughput: ${throughput.toFixed(2)} ops/sec`);
      console.log(`State: ${result.state}`);
      console.log(`Result Count: ${result.returnValue?.count || 0}`);

      expect(result.state).toBe('completed');
      expect(result.returnValue?.count).toBe(100);
      expect(throughput).toBeGreaterThan(100); // Should be reasonably fast
      expect(duration).toBeLessThan(1000); // Should complete quickly
    });
  });
});