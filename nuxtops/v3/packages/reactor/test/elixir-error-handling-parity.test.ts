/**
 * Elixir Reactor Error Handling Parity Tests
 * Direct translation of hexdocs.pm/reactor/02-error-handling.html patterns
 */

import { describe, it, expect, beforeEach } from 'vitest';
import { createReactor, arg } from '../core/reactor-builder';
import type { CompensationResult, ReactorContext } from '../types';

// Enhanced error types matching Elixir patterns
interface NetworkTimeoutError extends Error {
  type: 'network_timeout';
  retryable: boolean;
}

interface ValidationError extends Error {
  type: 'validation_error';
  retryable: boolean;
}

interface ServiceUnavailableError extends Error {
  type: 'service_unavailable';
  retryable: boolean;
}

// Helper to create typed errors
function createNetworkTimeoutError(message: string): NetworkTimeoutError {
  const error = new Error(message) as NetworkTimeoutError;
  error.type = 'network_timeout';
  error.retryable = true;
  return error;
}

function createValidationError(message: string): ValidationError {
  const error = new Error(message) as ValidationError;
  error.type = 'validation_error';
  error.retryable = false;
  return error;
}

function createServiceUnavailableError(message: string): ServiceUnavailableError {
  const error = new Error(message) as ServiceUnavailableError;
  error.type = 'service_unavailable';
  error.retryable = true;
  return error;
}

describe('Elixir Reactor Error Handling Parity', () => {
  let compensationLog: string[] = [];
  let undoLog: string[] = [];

  beforeEach(() => {
    compensationLog = [];
    undoLog = [];
  });

  describe('Compensation Patterns (Direct Elixir Translation)', () => {
    it('ELIXIR-01: Basic compensation with retry strategy', async () => {
      let attemptCount = 0;

      const reactor = createReactor()
        .input('message')
        .step('send_email', {
          arguments: { message: arg.input('message') },
          maxRetries: 3,
          async run({ message }) {
            attemptCount++;
            if (attemptCount < 3) {
              throw createNetworkTimeoutError('SMTP server timeout');
            }
            return { 
              message_id: `email_${Date.now()}`,
              sent: true,
              recipient: message.to,
              attempt: attemptCount
            };
          },
          // Direct translation of Elixir compensation pattern
          async compensate(error: any, args, context): Promise<CompensationResult> {
            compensationLog.push(`Compensation called for: ${error.message}`);
            
            // Match Elixir pattern: case error do
            switch (error.type) {
              case 'network_timeout':
                compensationLog.push('Network timeout detected - retrying');
                return 'retry'; // Elixir: :retry
              case 'validation_error':
                compensationLog.push('Validation error - not retryable');
                return 'abort'; // Elixir: {:error, reason}
              default:
                compensationLog.push('Unknown error - triggering rollback');
                return 'skip'; // Elixir: :ok (triggers rollback)
            }
          }
        })
        .return('send_email')
        .build();

      const result = await reactor.execute({ 
        message: { to: 'test@example.com', body: 'Test message' }
      });

      expect(result.state).toBe('completed');
      expect(result.returnValue.sent).toBe(true);
      expect(result.returnValue.attempt).toBe(3);
      expect(attemptCount).toBe(3);
      expect(compensationLog).toContain('Compensation called for: SMTP server timeout');
      expect(compensationLog).toContain('Network timeout detected - retrying');
    });

    it('ELIXIR-02: Compensation with continue strategy', async () => {
      const reactor = createReactor()
        .input('user_data')
        .step('validate_user', {
          arguments: { user: arg.input('user_data') },
          async run({ user }) {
            if (!user.email) {
              throw createValidationError('Email is required');
            }
            return { validated: true, user_id: user.id };
          },
          async compensate(error: any, args, context): Promise<CompensationResult> {
            compensationLog.push(`Validation failed: ${error.message}`);
            
            if (error.type === 'validation_error') {
              // Elixir: {:continue, default_value}
              // In our implementation, we'll skip and provide default in next step
              compensationLog.push('Using default validation');
              return 'skip';
            }
            return 'abort';
          }
        })
        .step('process_user', {
          arguments: { validation: arg.step('validate_user') },
          async run({ validation }) {
            // Handle case where validation was skipped
            if (!validation) {
              return { 
                processed: true, 
                user_id: 'default_user',
                from_compensation: true 
              };
            }
            return { 
              processed: true, 
              user_id: validation.user_id,
              from_compensation: false 
            };
          }
        })
        .return('process_user')
        .build();

      const result = await reactor.execute({ 
        user_data: { id: 'user123' } // Missing email
      });

      expect(result.state).toBe('completed');
      expect(result.returnValue.from_compensation).toBe(true);
      expect(result.returnValue.user_id).toBe('default_user');
      expect(compensationLog).toContain('Validation failed: Email is required');
    });

    it('ELIXIR-03: Service availability compensation pattern', async () => {
      let serviceCallCount = 0;

      const reactor = createReactor()
        .input('api_request')
        .step('call_primary_service', {
          arguments: { request: arg.input('api_request') },
          async run({ request }) {
            serviceCallCount++;
            throw createServiceUnavailableError('Primary service is down');
          },
          async compensate(error: any, args, context): Promise<CompensationResult> {
            compensationLog.push(`Primary service compensation: ${error.message}`);
            
            if (error.type === 'service_unavailable') {
              compensationLog.push('Primary service down - will try fallback');
              return 'skip'; // Skip to fallback service
            }
            return 'abort';
          }
        })
        .step('call_fallback_service', {
          arguments: { request: arg.input('api_request') },
          async run({ request }) {
            // This runs when primary service is skipped due to compensation
            return {
              data: 'Fallback service response',
              source: 'fallback',
              request_id: request.id
            };
          }
        })
        .step('aggregate_responses', {
          arguments: {
            primary: arg.step('call_primary_service'),
            fallback: arg.step('call_fallback_service')
          },
          async run({ primary, fallback }) {
            // Handle the case where primary failed and fallback succeeded
            if (!primary && fallback) {
              return {
                response: fallback.data,
                source: fallback.source,
                degraded_mode: true
              };
            }
            
            return {
              response: primary?.data || fallback?.data,
              source: primary ? 'primary' : 'fallback',
              degraded_mode: !primary
            };
          }
        })
        .return('aggregate_responses')
        .build();

      const result = await reactor.execute({ 
        api_request: { id: 'req123', data: 'test' }
      });

      expect(result.state).toBe('completed');
      expect(result.returnValue.source).toBe('fallback');
      expect(result.returnValue.degraded_mode).toBe(true);
      expect(compensationLog).toContain('Primary service down - will try fallback');
    });
  });

  describe('Undo Patterns (Direct Elixir Translation)', () => {
    it('ELIXIR-04: Basic undo with rollback on failure', async () => {
      let emailsSent: string[] = [];
      let paymentsProcessed: string[] = [];

      const reactor = createReactor()
        .input('order_data')
        .step('send_confirmation_email', {
          arguments: { order: arg.input('order_data') },
          async run({ order }) {
            const messageId = `email_${Date.now()}`;
            emailsSent.push(messageId);
            return { 
              message_id: messageId,
              sent: true,
              recipient: order.customer_email 
            };
          },
          // Direct translation of Elixir undo pattern
          async undo(result, args, context) {
            undoLog.push(`Canceling email message ${result.message_id}`);
            // Remove from sent emails (simulate cancellation)
            const index = emailsSent.indexOf(result.message_id);
            if (index > -1) {
              emailsSent.splice(index, 1);
            }
            // Elixir: :ok (successful undo)
          }
        })
        .step('process_payment', {
          arguments: { 
            order: arg.input('order_data'),
            email: arg.step('send_confirmation_email')
          },
          async run({ order, email }) {
            const transactionId = `txn_${Date.now()}`;
            paymentsProcessed.push(transactionId);
            return {
              transaction_id: transactionId,
              amount: order.amount,
              processed: true
            };
          },
          async undo(result, args, context) {
            undoLog.push(`Refunding transaction ${result.transaction_id}`);
            // Remove from processed payments (simulate refund)
            const index = paymentsProcessed.indexOf(result.transaction_id);
            if (index > -1) {
              paymentsProcessed.splice(index, 1);
            }
          }
        })
        .step('ship_order', {
          arguments: { 
            order: arg.input('order_data'),
            payment: arg.step('process_payment')
          },
          async run({ order, payment }) {
            // Force failure to trigger rollback
            throw new Error('Shipping service unavailable');
          },
          async undo(result, args, context) {
            undoLog.push('Canceling shipping label');
          }
        })
        .return('ship_order')
        .build();

      const result = await reactor.execute({
        order_data: {
          id: 'order123',
          customer_email: 'customer@example.com',
          amount: 99.99
        }
      });

      expect(result.state).toBe('failed');
      
      // Verify rollback occurred (undo operations were called)
      expect(undoLog).toContain('Refunding transaction txn_');
      expect(undoLog.some(log => log.includes('Canceling email message email_'))).toBe(true);
      
      // Verify side effects were rolled back
      expect(emailsSent).toHaveLength(0); // Email was "cancelled"
      expect(paymentsProcessed).toHaveLength(0); // Payment was "refunded"
    });

    it('ELIXIR-05: Idempotent undo operations', async () => {
      let resourcesAllocated: string[] = [];
      let undoCallCount = 0;

      const reactor = createReactor()
        .input('resource_request')
        .step('allocate_resources', {
          arguments: { request: arg.input('resource_request') },
          async run({ request }) {
            const resourceId = `resource_${Date.now()}`;
            resourcesAllocated.push(resourceId);
            return { 
              resource_id: resourceId,
              allocated: true,
              type: request.type 
            };
          },
          // Idempotent undo - safe to call multiple times
          async undo(result, args, context) {
            undoCallCount++;
            undoLog.push(`Releasing resource ${result.resource_id} (call #${undoCallCount})`);
            
            // Idempotent operation - only remove if it exists
            const index = resourcesAllocated.indexOf(result.resource_id);
            if (index > -1) {
              resourcesAllocated.splice(index, 1);
              undoLog.push(`Resource ${result.resource_id} actually released`);
            } else {
              undoLog.push(`Resource ${result.resource_id} already released (idempotent)`);
            }
          }
        })
        .step('configure_resource', {
          arguments: { allocation: arg.step('allocate_resources') },
          async run({ allocation }) {
            // Force failure to trigger undo
            throw new Error('Configuration failed');
          }
        })
        .return('configure_resource')
        .build();

      const result = await reactor.execute({
        resource_request: { type: 'compute', size: 'large' }
      });

      expect(result.state).toBe('failed');
      expect(undoCallCount).toBeGreaterThan(0);
      expect(resourcesAllocated).toHaveLength(0); // Resource was released
      expect(undoLog.some(log => log.includes('actually released'))).toBe(true);
    });

    it('ELIXIR-06: Undo failure handling', async () => {
      let criticalResourcesAllocated: string[] = [];

      const reactor = createReactor()
        .input('critical_operation')
        .step('allocate_critical_resource', {
          arguments: { operation: arg.input('critical_operation') },
          async run({ operation }) {
            const resourceId = `critical_${Date.now()}`;
            criticalResourcesAllocated.push(resourceId);
            return { 
              resource_id: resourceId,
              critical: true 
            };
          },
          async undo(result, args, context) {
            undoLog.push(`Attempting to release critical resource ${result.resource_id}`);
            
            // Simulate undo failure for critical resources
            if (result.critical) {
              undoLog.push(`Failed to release critical resource ${result.resource_id}`);
              throw new Error(`Cannot release critical resource ${result.resource_id}`);
            }
            
            // Normal undo logic
            const index = criticalResourcesAllocated.indexOf(result.resource_id);
            if (index > -1) {
              criticalResourcesAllocated.splice(index, 1);
            }
          }
        })
        .step('process_with_resource', {
          arguments: { resource: arg.step('allocate_critical_resource') },
          async run({ resource }) {
            // Force failure to trigger undo
            throw new Error('Processing failed');
          }
        })
        .return('process_with_resource')
        .build();

      const result = await reactor.execute({
        critical_operation: { type: 'critical_process' }
      });

      expect(result.state).toBe('failed');
      expect(undoLog).toContain('Failed to release critical resource critical_');
      
      // Critical resource should still be allocated due to undo failure
      expect(criticalResourcesAllocated).toHaveLength(1);
    });
  });

  describe('Advanced Error Handling Patterns', () => {
    it('ELIXIR-07: Max retries with exponential backoff', async () => {
      let attemptTimes: number[] = [];
      let backoffDelays: number[] = [];

      const reactor = createReactor()
        .input('api_endpoint')
        .step('api_call_with_backoff', {
          arguments: { endpoint: arg.input('api_endpoint') },
          maxRetries: 3,
          async run({ endpoint }) {
            const currentTime = Date.now();
            attemptTimes.push(currentTime);
            
            // Calculate backoff delay if this is a retry
            if (attemptTimes.length > 1) {
              const delay = currentTime - attemptTimes[attemptTimes.length - 2];
              backoffDelays.push(delay);
            }
            
            if (attemptTimes.length < 4) {
              throw createNetworkTimeoutError(`API call failed (attempt ${attemptTimes.length})`);
            }
            
            return { 
              success: true,
              attempts: attemptTimes.length,
              endpoint 
            };
          },
          async compensate(error: any, args, context): Promise<CompensationResult> {
            compensationLog.push(`Retry compensation for attempt ${attemptTimes.length}`);
            
            if (error.type === 'network_timeout' && attemptTimes.length <= 3) {
              // Implement exponential backoff
              const backoffMs = Math.pow(2, attemptTimes.length - 1) * 100;
              compensationLog.push(`Backing off for ${backoffMs}ms`);
              
              await new Promise(resolve => setTimeout(resolve, backoffMs));
              return 'retry';
            }
            
            return 'abort';
          }
        })
        .return('api_call_with_backoff')
        .build();

      const startTime = Date.now();
      const result = await reactor.execute({
        api_endpoint: 'https://api.example.com/data'
      });
      const totalTime = Date.now() - startTime;

      expect(result.state).toBe('completed');
      expect(result.returnValue.attempts).toBe(4);
      expect(attemptTimes).toHaveLength(4);
      
      // Verify exponential backoff occurred
      expect(backoffDelays.length).toBe(3);
      expect(backoffDelays[1]).toBeGreaterThan(backoffDelays[0]); // Second delay > first delay
      expect(backoffDelays[2]).toBeGreaterThan(backoffDelays[1]); // Third delay > second delay
      
      // Should take at least 700ms due to backoff (100 + 200 + 400)
      expect(totalTime).toBeGreaterThan(600);
    });

    it('ELIXIR-08: Context-aware error handling', async () => {
      const reactor = createReactor()
        .input('user_context')
        .input('operation_data')
        .step('context_aware_operation', {
          arguments: { 
            user: arg.input('user_context'),
            data: arg.input('operation_data')
          },
          async run({ user, data }) {
            if (data.requires_premium && !user.is_premium) {
              throw createValidationError('Premium subscription required');
            }
            
            if (data.requires_admin && user.role !== 'admin') {
              throw createValidationError('Admin privileges required');
            }
            
            return { 
              processed: true,
              user_id: user.id,
              operation: data.type 
            };
          },
          async compensate(error: any, args, context): Promise<CompensationResult> {
            const { user, data } = args;
            
            compensationLog.push(`Error for user ${user.id}: ${error.message}`);
            
            if (error.type === 'validation_error') {
              if (error.message.includes('Premium')) {
                compensationLog.push(`Offering free trial to user ${user.id}`);
                // In real implementation, could trigger upgrade flow
                return 'skip'; // Continue with limited functionality
              }
              
              if (error.message.includes('Admin')) {
                compensationLog.push(`Logging unauthorized access attempt by ${user.id}`);
                // In real implementation, could log security event
                return 'abort'; // Security violation - fail completely
              }
            }
            
            return 'abort';
          }
        })
        .step('handle_compensation_result', {
          arguments: { 
            operation: arg.step('context_aware_operation'),
            user: arg.input('user_context')
          },
          async run({ operation, user }) {
            if (!operation) {
              // Operation was compensated/skipped
              return {
                result: 'limited_access',
                user_id: user.id,
                compensation_applied: true
              };
            }
            
            return {
              result: 'full_access',
              user_id: user.id,
              compensation_applied: false
            };
          }
        })
        .return('handle_compensation_result')
        .build();

      // Test premium requirement compensation
      const premiumResult = await reactor.execute({
        user_context: { id: 'user123', is_premium: false, role: 'user' },
        operation_data: { type: 'analytics', requires_premium: true }
      });

      expect(premiumResult.state).toBe('completed');
      expect(premiumResult.returnValue.result).toBe('limited_access');
      expect(compensationLog).toContain('Offering free trial to user user123');

      // Reset for next test
      compensationLog = [];

      // Test admin requirement (should abort)
      const adminResult = await reactor.execute({
        user_context: { id: 'user456', is_premium: true, role: 'user' },
        operation_data: { type: 'admin_panel', requires_admin: true }
      });

      expect(adminResult.state).toBe('failed');
      expect(compensationLog).toContain('Logging unauthorized access attempt by user456');
    });
  });

  describe('Error Handling Integration', () => {
    it('ELIXIR-09: Complex workflow with multiple error strategies', async () => {
      let emailQueue: Array<{ id: string; status: 'sent' | 'cancelled' }> = [];
      let inventoryReservations: Array<{ id: string; item: string; status: 'reserved' | 'released' }> = [];

      const reactor = createReactor()
        .input('order')
        .step('reserve_inventory', {
          arguments: { order: arg.input('order') },
          maxRetries: 2,
          async run({ order }) {
            const reservationId = `res_${Date.now()}`;
            
            // Simulate occasional inventory service failure
            if (Math.random() < 0.3) {
              throw createServiceUnavailableError('Inventory service temporarily unavailable');
            }
            
            inventoryReservations.push({
              id: reservationId,
              item: order.item_id,
              status: 'reserved'
            });
            
            return {
              reservation_id: reservationId,
              item_id: order.item_id,
              quantity: order.quantity
            };
          },
          async compensate(error: any, args, context): Promise<CompensationResult> {
            compensationLog.push(`Inventory reservation failed: ${error.message}`);
            
            if (error.type === 'service_unavailable') {
              compensationLog.push('Retrying inventory reservation');
              return 'retry';
            }
            
            return 'abort';
          },
          async undo(result, args, context) {
            undoLog.push(`Releasing inventory reservation ${result.reservation_id}`);
            
            const reservation = inventoryReservations.find(r => r.id === result.reservation_id);
            if (reservation) {
              reservation.status = 'released';
            }
          }
        })
        .step('send_order_confirmation', {
          arguments: { 
            order: arg.input('order'),
            reservation: arg.step('reserve_inventory')
          },
          async run({ order, reservation }) {
            const emailId = `email_${Date.now()}`;
            
            emailQueue.push({
              id: emailId,
              status: 'sent'
            });
            
            return {
              email_id: emailId,
              recipient: order.customer_email,
              order_id: order.id
            };
          },
          async undo(result, args, context) {
            undoLog.push(`Cancelling order confirmation email ${result.email_id}`);
            
            const email = emailQueue.find(e => e.id === result.email_id);
            if (email) {
              email.status = 'cancelled';
            }
          }
        })
        .step('process_payment', {
          arguments: {
            order: arg.input('order'),
            reservation: arg.step('reserve_inventory'),
            email: arg.step('send_order_confirmation')
          },
          async run({ order, reservation, email }) {
            // Force payment failure to test rollback
            if (order.test_payment_failure) {
              throw new Error('Payment processing failed');
            }
            
            return {
              transaction_id: `txn_${Date.now()}`,
              amount: order.total,
              status: 'completed'
            };
          }
        })
        .return('process_payment')
        .build();

      // Test successful flow
      const successResult = await reactor.execute({
        order: {
          id: 'order123',
          item_id: 'item456',
          quantity: 2,
          total: 99.99,
          customer_email: 'customer@example.com',
          test_payment_failure: false
        }
      });

      expect(successResult.state).toBe('completed');
      expect(inventoryReservations.some(r => r.status === 'reserved')).toBe(true);
      expect(emailQueue.some(e => e.status === 'sent')).toBe(true);

      // Reset for failure test
      inventoryReservations = [];
      emailQueue = [];
      compensationLog = [];
      undoLog = [];

      // Test payment failure with rollback
      const failureResult = await reactor.execute({
        order: {
          id: 'order456',
          item_id: 'item789',
          quantity: 1,
          total: 49.99,
          customer_email: 'customer2@example.com',
          test_payment_failure: true
        }
      });

      expect(failureResult.state).toBe('failed');
      
      // Verify rollback occurred
      expect(undoLog.some(log => log.includes('Releasing inventory reservation'))).toBe(true);
      expect(undoLog.some(log => log.includes('Cancelling order confirmation email'))).toBe(true);
      
      // Verify side effects were rolled back
      expect(inventoryReservations.every(r => r.status === 'released')).toBe(true);
      expect(emailQueue.every(e => e.status === 'cancelled')).toBe(true);
    });
  });
});