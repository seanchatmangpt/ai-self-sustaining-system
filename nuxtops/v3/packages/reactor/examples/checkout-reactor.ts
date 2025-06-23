/**
 * E-commerce Checkout Reactor Example
 * Demonstrates a complex multi-step checkout process with compensation
 */

import { ReactorEngine } from '../core/reactor-engine';
import { TelemetryMiddleware } from '../middleware/telemetry-middleware';
import type { ReactorStep } from '../types';

interface CheckoutData {
  userId: string;
  cartItems: Array<{ id: string; quantity: number; price: number }>;
  shippingAddress: any;
  paymentMethod: any;
}

// Step 1: Validate cart items
const validateCart: ReactorStep<CheckoutData, any> = {
  name: 'validate-cart',
  description: 'Validate cart items are in stock',
  
  async run(input, context) {
    try {
      const validation = await $fetch('/api/cart/validate', {
        method: 'POST',
        body: {
          items: input.cartItems,
          userId: input.userId
        }
      });
      
      if (!validation.valid) {
        return { 
          success: false, 
          error: new Error(`Invalid cart items: ${validation.errors.join(', ')}`)
        };
      }
      
      return { success: true, data: validation };
    } catch (error) {
      return { success: false, error: error as Error };
    }
  }
};

// Step 2: Reserve inventory
const reserveInventory: ReactorStep<CheckoutData, any> = {
  name: 'reserve-inventory',
  description: 'Reserve items in inventory',
  dependencies: ['validate-cart'],
  timeout: 10000,
  
  async run(input, context) {
    try {
      const reservation = await $fetch('/api/inventory/reserve', {
        method: 'POST',
        body: {
          items: input.cartItems,
          userId: input.userId,
          reservationId: context.id
        }
      });
      
      return { success: true, data: reservation };
    } catch (error) {
      return { success: false, error: error as Error };
    }
  },
  
  async compensate(error, input, context) {
    // Retry once on failure
    return 'retry';
  },
  
  async undo(result, input, context) {
    // Release inventory reservation
    await $fetch('/api/inventory/release', {
      method: 'POST',
      body: {
        reservationId: result.reservationId
      }
    });
  }
};

// Step 3: Calculate pricing
const calculatePricing: ReactorStep<CheckoutData, any> = {
  name: 'calculate-pricing',
  description: 'Calculate final pricing with taxes and shipping',
  dependencies: ['validate-cart'],
  
  async run(input, context) {
    try {
      const pricing = await $fetch('/api/pricing/calculate', {
        method: 'POST',
        body: {
          items: input.cartItems,
          shippingAddress: input.shippingAddress,
          userId: input.userId
        }
      });
      
      return { success: true, data: pricing };
    } catch (error) {
      return { success: false, error: error as Error };
    }
  }
};

// Step 4: Process payment
const processPayment: ReactorStep<CheckoutData, any> = {
  name: 'process-payment',
  description: 'Process payment transaction',
  dependencies: ['reserve-inventory', 'calculate-pricing'],
  timeout: 30000,
  retries: 2,
  
  async run(input, context) {
    try {
      // Get pricing from previous step
      const pricingResult = context.results?.get('calculate-pricing');
      const totalAmount = pricingResult?.data?.total;
      
      const payment = await $fetch('/api/payment/process', {
        method: 'POST',
        body: {
          amount: totalAmount,
          paymentMethod: input.paymentMethod,
          userId: input.userId,
          orderId: context.id
        }
      });
      
      return { success: true, data: payment };
    } catch (error) {
      return { success: false, error: error as Error };
    }
  },
  
  async compensate(error, input, context) {
    // On payment failure, abort the entire process
    return 'abort';
  },
  
  async undo(result, input, context) {
    // Refund the payment
    await $fetch('/api/payment/refund', {
      method: 'POST',
      body: {
        transactionId: result.transactionId,
        reason: 'Order cancelled'
      }
    });
  }
};

// Step 5: Create order
const createOrder: ReactorStep<CheckoutData, any> = {
  name: 'create-order',
  description: 'Create order in database',
  dependencies: ['process-payment'],
  
  async run(input, context) {
    try {
      const order = await $fetch('/api/orders/create', {
        method: 'POST',
        body: {
          userId: input.userId,
          items: input.cartItems,
          shippingAddress: input.shippingAddress,
          paymentId: context.results?.get('process-payment')?.data?.transactionId,
          total: context.results?.get('calculate-pricing')?.data?.total
        }
      });
      
      return { success: true, data: order };
    } catch (error) {
      return { success: false, error: error as Error };
    }
  },
  
  async undo(result, input, context) {
    // Cancel the order
    await $fetch(`/api/orders/${result.orderId}/cancel`, {
      method: 'POST'
    });
  }
};

// Step 6: Send confirmation
const sendConfirmation: ReactorStep<CheckoutData, any> = {
  name: 'send-confirmation',
  description: 'Send order confirmation email',
  dependencies: ['create-order'],
  
  async run(input, context) {
    try {
      const orderResult = context.results?.get('create-order');
      
      await $fetch('/api/notifications/send', {
        method: 'POST',
        body: {
          type: 'order-confirmation',
          userId: input.userId,
          orderId: orderResult?.data?.orderId,
          email: input.userId // Assuming userId is email
        }
      });
      
      return { success: true, data: { sent: true } };
    } catch (error) {
      // Non-critical step, don't fail the entire process
      console.error('Failed to send confirmation:', error);
      return { success: true, data: { sent: false, error: error.message } };
    }
  }
};

/**
 * Create and configure checkout reactor
 */
export function createCheckoutReactor() {
  const reactor = new ReactorEngine({
    id: `checkout_${Date.now()}`,
    middleware: [
      new TelemetryMiddleware({
        onSpanEnd: (span) => {
          // Log checkout metrics
          if (span.operationName.includes('checkout')) {
            console.log('Checkout metric:', {
              step: span.operationName,
              duration: span.duration,
              status: span.status
            });
          }
        }
      })
    ]
  });
  
  // Add all steps
  reactor.addStep(validateCart);
  reactor.addStep(reserveInventory);
  reactor.addStep(calculatePricing);
  reactor.addStep(processPayment);
  reactor.addStep(createOrder);
  reactor.addStep(sendConfirmation);
  
  return reactor;
}

/**
 * Nitro task for background checkout processing
 */
export const checkoutTask = defineReactorTask('checkout', {
  validateCart: () => validateCart,
  reserveInventory: () => reserveInventory,
  calculatePricing: () => calculatePricing,
  processPayment: () => processPayment,
  createOrder: () => createOrder,
  sendConfirmation: () => sendConfirmation
});