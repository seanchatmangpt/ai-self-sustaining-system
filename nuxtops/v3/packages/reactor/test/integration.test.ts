/**
 * Integration tests for example workflows and end-to-end scenarios
 */

import { describe, it, expect, vi, beforeEach } from 'vitest';
import { createCheckoutReactor } from '../examples/checkout-reactor';
import { ReactorEngine } from '../core/reactor-engine';
import { TelemetryMiddleware } from '../middleware/telemetry-middleware';
import { CoordinationMiddleware } from '../middleware/coordination-middleware';
import { generateCheckoutData, delay, PerformanceTracker } from './setup';

// Mock $fetch for API calls
global.$fetch = vi.fn();

describe('Checkout Reactor Integration', () => {
  let checkoutData: any;
  let performanceTracker: PerformanceTracker;

  beforeEach(() => {
    checkoutData = generateCheckoutData();
    performanceTracker = new PerformanceTracker();
    
    // Reset all mocks
    vi.clearAllMocks();
    
    // Setup default successful API responses
    (global.$fetch as any).mockImplementation((url: string, options: any) => {
      switch (url) {
        case '/api/cart/validate':
          return Promise.resolve({ valid: true, errors: [] });
        
        case '/api/inventory/reserve':
          return Promise.resolve({ 
            reservationId: 'res-123',
            items: checkoutData.cartItems,
            expiresAt: Date.now() + 600000 // 10 minutes
          });
        
        case '/api/pricing/calculate':
          return Promise.resolve({
            subtotal: 79.98,
            tax: 7.20,
            shipping: 9.99,
            total: 97.17
          });
        
        case '/api/payment/process':
          return Promise.resolve({
            transactionId: 'txn-456',
            status: 'completed',
            amount: 97.17
          });
        
        case '/api/orders/create':
          return Promise.resolve({
            orderId: 'order-789',
            status: 'confirmed',
            estimatedDelivery: '2024-01-15'
          });
        
        case '/api/notifications/send':
          return Promise.resolve({ sent: true, messageId: 'msg-123' });
        
        default:
          return Promise.reject(new Error(`Unmocked API call: ${url}`));
      }
    });
  });

  describe('Successful Checkout Flow', () => {
    it('should complete full checkout process successfully', async () => {
      const reactor = createCheckoutReactor();
      
      performanceTracker.mark('checkout-start');
      const result = await reactor.execute(checkoutData);
      performanceTracker.mark('checkout-end');
      
      const duration = performanceTracker.measure('checkout-start', 'checkout-end');
      
      expect(result.state).toBe('completed');
      expect(result.results.size).toBe(6); // All 6 steps
      expect(result.errors).toHaveLength(0);
      expect(duration).toBeLessThan(5000); // Should complete in under 5 seconds
      
      // Verify all API calls were made
      expect(global.$fetch).toHaveBeenCalledWith('/api/cart/validate', expect.any(Object));
      expect(global.$fetch).toHaveBeenCalledWith('/api/inventory/reserve', expect.any(Object));
      expect(global.$fetch).toHaveBeenCalledWith('/api/pricing/calculate', expect.any(Object));
      expect(global.$fetch).toHaveBeenCalledWith('/api/payment/process', expect.any(Object));
      expect(global.$fetch).toHaveBeenCalledWith('/api/orders/create', expect.any(Object));
      expect(global.$fetch).toHaveBeenCalledWith('/api/notifications/send', expect.any(Object));
    });

    it('should pass correct data between steps', async () => {
      const reactor = createCheckoutReactor();
      const result = await reactor.execute(checkoutData);
      
      // Verify payment processing received pricing data
      const paymentCall = (global.$fetch as any).mock.calls.find(
        call => call[0] === '/api/payment/process'
      );
      expect(paymentCall[1].body.amount).toBe(97.17);
      
      // Verify order creation received payment ID
      const orderCall = (global.$fetch as any).mock.calls.find(
        call => call[0] === '/api/orders/create'
      );
      expect(orderCall[1].body.paymentId).toBe('txn-456');
      expect(orderCall[1].body.total).toBe(97.17);
    });

    it('should execute independent steps in parallel', async () => {
      const reactor = createCheckoutReactor();
      
      // Mock delays to test parallelism
      (global.$fetch as any).mockImplementation(async (url: string) => {
        if (url === '/api/cart/validate') {
          await delay(100);
          return { valid: true, errors: [] };
        }
        if (url === '/api/pricing/calculate') {
          await delay(100);
          return { subtotal: 79.98, tax: 7.20, shipping: 9.99, total: 97.17 };
        }
        // Other calls return immediately
        return { success: true };
      });
      
      performanceTracker.mark('parallel-start');
      await reactor.execute(checkoutData);
      performanceTracker.mark('parallel-end');
      
      const duration = performanceTracker.measure('parallel-start', 'parallel-end');
      
      // Pricing and validation should run in parallel, so total time should be ~100ms, not ~200ms
      expect(duration).toBeLessThan(300);
    });
  });

  describe('Failure Scenarios and Compensation', () => {
    it('should handle cart validation failure', async () => {
      (global.$fetch as any).mockImplementation((url: string) => {
        if (url === '/api/cart/validate') {
          return Promise.resolve({ 
            valid: false, 
            errors: ['Item out of stock: item-1'] 
          });
        }
        return Promise.resolve({ success: true });
      });
      
      const reactor = createCheckoutReactor();
      const result = await reactor.execute(checkoutData);
      
      expect(result.state).toBe('failed');
      expect(result.errors).toHaveLength(1);
      expect(result.errors[0].message).toContain('Invalid cart items');
      
      // Should not proceed to other steps
      expect(global.$fetch).not.toHaveBeenCalledWith('/api/inventory/reserve', expect.any(Object));
    });

    it('should rollback inventory on payment failure', async () => {
      (global.$fetch as any).mockImplementation((url: string, options: any) => {
        if (url === '/api/payment/process') {
          return Promise.reject(new Error('Payment declined'));
        }
        if (url === '/api/inventory/release') {
          return Promise.resolve({ released: true });
        }
        // Other calls succeed
        return Promise.resolve({
          valid: true,
          reservationId: 'res-123',
          subtotal: 79.98,
          tax: 7.20,
          shipping: 9.99,
          total: 97.17
        });
      });
      
      const reactor = createCheckoutReactor();
      const result = await reactor.execute(checkoutData);
      
      expect(result.state).toBe('failed');
      
      // Should have called inventory release during rollback
      expect(global.$fetch).toHaveBeenCalledWith('/api/inventory/release', {
        method: 'POST',
        body: { reservationId: 'res-123' }
      });
    });

    it('should handle timeout on slow operations', async () => {
      (global.$fetch as any).mockImplementation(async (url: string) => {
        if (url === '/api/payment/process') {
          // Simulate slow payment processing (35 seconds)
          await delay(35000);
          return { transactionId: 'txn-456' };
        }
        return Promise.resolve({ success: true });
      });
      
      const reactor = createCheckoutReactor();
      const result = await reactor.execute(checkoutData);
      
      expect(result.state).toBe('failed');
      expect(result.errors[0].message).toContain('timeout');
    }, 40000); // Increase test timeout
  });

  describe('Performance Characteristics', () => {
    it('should complete normal checkout within performance budget', async () => {
      const reactor = createCheckoutReactor();
      
      // Add realistic delays to API calls
      (global.$fetch as any).mockImplementation(async (url: string) => {
        await delay(Math.random() * 100 + 50); // 50-150ms per call
        return { success: true, data: 'mock response' };
      });
      
      performanceTracker.mark('perf-start');
      await reactor.execute(checkoutData);
      performanceTracker.mark('perf-end');
      
      const duration = performanceTracker.measure('perf-start', 'perf-end');
      
      // Should complete within 2 seconds with realistic API delays
      expect(duration).toBeLessThan(2000);
    });

    it('should handle high load scenarios', async () => {
      const concurrentCheckouts = 10;
      const reactors = Array.from({ length: concurrentCheckouts }, () => 
        createCheckoutReactor()
      );
      
      performanceTracker.mark('concurrent-start');
      
      const results = await Promise.all(
        reactors.map(reactor => reactor.execute(checkoutData))
      );
      
      performanceTracker.mark('concurrent-end');
      
      const duration = performanceTracker.measure('concurrent-start', 'concurrent-end');
      
      // All should complete successfully
      expect(results.every(r => r.state === 'completed')).toBe(true);
      
      // Should handle concurrent load efficiently
      expect(duration).toBeLessThan(5000);
    });
  });

  describe('Telemetry and Observability', () => {
    it('should generate telemetry spans for all operations', async () => {
      const spans: any[] = [];
      const telemetryMiddleware = new TelemetryMiddleware({
        onSpanEnd: (span) => spans.push(span)
      });
      
      const reactor = new ReactorEngine();
      reactor.addMiddleware(telemetryMiddleware);
      
      // Add a few test steps
      reactor.addStep({
        name: 'test-step-1',
        async run() {
          await delay(50);
          return { success: true, data: 'result1' };
        }
      });
      
      reactor.addStep({
        name: 'test-step-2',
        dependencies: ['test-step-1'],
        async run() {
          await delay(30);
          return { success: true, data: 'result2' };
        }
      });
      
      await reactor.execute();
      
      expect(spans).toHaveLength(3); // root + 2 steps
      
      const rootSpan = spans.find(s => s.operationName.includes('reactor'));
      const step1Span = spans.find(s => s.operationName === 'step.test-step-1');
      const step2Span = spans.find(s => s.operationName === 'step.test-step-2');
      
      expect(rootSpan).toBeDefined();
      expect(step1Span).toBeDefined();
      expect(step2Span).toBeDefined();
      
      // Verify parent-child relationships
      expect(step1Span.parentSpanId).toBe(rootSpan.spanId);
      expect(step2Span.parentSpanId).toBe(rootSpan.spanId);
      
      // Verify all spans have same trace ID
      expect(step1Span.traceId).toBe(rootSpan.traceId);
      expect(step2Span.traceId).toBe(rootSpan.traceId);
    });

    it('should track coordination metrics', async () => {
      const workClaims: any[] = [];
      const coordinationMiddleware = new CoordinationMiddleware({
        onWorkClaim: (claim) => workClaims.push(claim),
        onWorkComplete: (claim) => workClaims.push(claim)
      });
      
      const reactor = new ReactorEngine();
      reactor.addMiddleware(coordinationMiddleware);
      
      reactor.addStep({
        name: 'coordinated-step',
        async run() {
          await delay(100);
          return { success: true, data: 'coordinated' };
        }
      });
      
      await reactor.execute();
      
      expect(workClaims).toHaveLength(2); // claim + complete
      expect(workClaims[0].stepName).toBe('coordinated-step');
      expect(workClaims[0].status).toBe('in_progress');
      expect(workClaims[1].status).toBe('completed');
    });
  });

  describe('Edge Cases', () => {
    it('should handle partial API failures gracefully', async () => {
      (global.$fetch as any).mockImplementation((url: string) => {
        if (url === '/api/notifications/send') {
          // Non-critical notification fails
          return Promise.reject(new Error('Email service unavailable'));
        }
        return Promise.resolve({ success: true, data: 'mock' });
      });
      
      const reactor = createCheckoutReactor();
      const result = await reactor.execute(checkoutData);
      
      // Should still complete successfully despite notification failure
      expect(result.state).toBe('completed');
      
      // Notification step should have handled the error gracefully
      const notificationResult = result.results.get('send-confirmation');
      expect(notificationResult.success).toBe(true);
      expect(notificationResult.data.sent).toBe(false);
    });

    it('should handle network timeouts appropriately', async () => {
      (global.$fetch as any).mockImplementation(async (url: string) => {
        if (url === '/api/cart/validate') {
          await delay(15000); // 15 second delay
          return { valid: true };
        }
        return Promise.resolve({ success: true });
      });
      
      const reactor = createCheckoutReactor();
      const result = await reactor.execute(checkoutData);
      
      expect(result.state).toBe('failed');
      expect(result.errors[0].message).toContain('timeout');
    }, 20000);

    it('should handle malformed API responses', async () => {
      (global.$fetch as any).mockImplementation((url: string) => {
        if (url === '/api/pricing/calculate') {
          // Return malformed response
          return Promise.resolve({ invalid: 'response' });
        }
        return Promise.resolve({ success: true });
      });
      
      const reactor = createCheckoutReactor();
      const result = await reactor.execute(checkoutData);
      
      // Should handle the malformed response and fail gracefully
      expect(result.state).toBe('failed');
    });
  });

  describe('Data Flow Validation', () => {
    it('should maintain data integrity throughout the workflow', async () => {
      const reactor = createCheckoutReactor();
      const result = await reactor.execute(checkoutData);
      
      expect(result.state).toBe('completed');
      
      // Verify each step received the correct input
      const apiCalls = (global.$fetch as any).mock.calls;
      
      // Cart validation should receive cart items
      const cartValidation = apiCalls.find(call => call[0] === '/api/cart/validate');
      expect(cartValidation[1].body.items).toEqual(checkoutData.cartItems);
      expect(cartValidation[1].body.userId).toBe(checkoutData.userId);
      
      // Inventory reservation should receive cart items
      const inventoryReservation = apiCalls.find(call => call[0] === '/api/inventory/reserve');
      expect(inventoryReservation[1].body.items).toEqual(checkoutData.cartItems);
      
      // Pricing should receive shipping address
      const pricingCalculation = apiCalls.find(call => call[0] === '/api/pricing/calculate');
      expect(pricingCalculation[1].body.shippingAddress).toEqual(checkoutData.shippingAddress);
      
      // Payment should receive payment method
      const paymentProcessing = apiCalls.find(call => call[0] === '/api/payment/process');
      expect(paymentProcessing[1].body.paymentMethod).toEqual(checkoutData.paymentMethod);
    });
  });
});

describe('Complex Workflow Scenarios', () => {
  it('should handle diamond dependency pattern', async () => {
    const reactor = new ReactorEngine();
    
    const executionOrder: string[] = [];
    
    // Create diamond pattern: A -> B, A -> C, B -> D, C -> D
    reactor.addStep({
      name: 'A',
      async run() {
        executionOrder.push('A');
        await delay(50);
        return { success: true, data: 'A-result' };
      }
    });
    
    reactor.addStep({
      name: 'B',
      dependencies: ['A'],
      async run() {
        executionOrder.push('B');
        await delay(30);
        return { success: true, data: 'B-result' };
      }
    });
    
    reactor.addStep({
      name: 'C',
      dependencies: ['A'],
      async run() {
        executionOrder.push('C');
        await delay(40);
        return { success: true, data: 'C-result' };
      }
    });
    
    reactor.addStep({
      name: 'D',
      dependencies: ['B', 'C'],
      async run() {
        executionOrder.push('D');
        await delay(20);
        return { success: true, data: 'D-result' };
      }
    });
    
    const result = await reactor.execute();
    
    expect(result.state).toBe('completed');
    expect(executionOrder[0]).toBe('A'); // A must be first
    expect(executionOrder[3]).toBe('D'); // D must be last
    expect(executionOrder.slice(1, 3)).toContain('B'); // B and C can be in any order
    expect(executionOrder.slice(1, 3)).toContain('C');
  });

  it('should handle large-scale parallel execution', async () => {
    const reactor = new ReactorEngine({ maxConcurrency: 5 });
    
    // Create 20 independent steps
    for (let i = 0; i < 20; i++) {
      reactor.addStep({
        name: `parallel-step-${i}`,
        async run() {
          await delay(100);
          return { success: true, data: `result-${i}` };
        }
      });
    }
    
    performanceTracker.mark('large-parallel-start');
    const result = await reactor.execute();
    performanceTracker.mark('large-parallel-end');
    
    const duration = performanceTracker.measure('large-parallel-start', 'large-parallel-end');
    
    expect(result.state).toBe('completed');
    expect(result.results.size).toBe(20);
    
    // With concurrency limit of 5, 20 steps should take ~400ms (4 batches of 100ms each)
    expect(duration).toBeGreaterThan(350);
    expect(duration).toBeLessThan(600);
  });
});