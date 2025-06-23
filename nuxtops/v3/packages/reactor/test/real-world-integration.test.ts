/**
 * Real-World Integration Test Scenarios
 * Production-like workflows with actual system integrations
 */

import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { createReactor, arg } from '../core/reactor-builder';
import { performance } from 'perf_hooks';

// Mock external services for realistic integration testing
class MockAPIClient {
  private latency: number;
  private failureRate: number;

  constructor(latency = 50, failureRate = 0.1) {
    this.latency = latency;
    this.failureRate = failureRate;
  }

  async fetchUserProfile(userId: string) {
    await this.simulateLatency();
    if (Math.random() < this.failureRate) {
      throw new Error('User service unavailable');
    }
    return {
      id: userId,
      name: `User ${userId}`,
      email: `user${userId}@example.com`,
      preferences: { theme: 'dark', notifications: true }
    };
  }

  async fetchUserOrders(userId: string) {
    await this.simulateLatency();
    if (Math.random() < this.failureRate) {
      throw new Error('Order service unavailable');
    }
    return Array.from({ length: 5 }, (_, i) => ({
      id: `order-${userId}-${i}`,
      amount: Math.floor(Math.random() * 100) + 10,
      status: ['pending', 'completed', 'shipped'][Math.floor(Math.random() * 3)]
    }));
  }

  async fetchRecommendations(userId: string, orderHistory: any[]) {
    await this.simulateLatency();
    if (Math.random() < this.failureRate) {
      throw new Error('Recommendation service unavailable');
    }
    return Array.from({ length: 3 }, (_, i) => ({
      id: `rec-${userId}-${i}`,
      title: `Recommended Product ${i + 1}`,
      price: Math.floor(Math.random() * 50) + 10,
      confidence: Math.random()
    }));
  }

  async sendNotification(userId: string, message: string) {
    await this.simulateLatency();
    if (Math.random() < this.failureRate) {
      throw new Error('Notification service unavailable');
    }
    return { sent: true, messageId: `msg-${Date.now()}`, userId };
  }

  private async simulateLatency() {
    await new Promise(resolve => setTimeout(resolve, this.latency));
  }
}

class MockDatabase {
  private data: Map<string, any> = new Map();
  private latency: number;

  constructor(latency = 10) {
    this.latency = latency;
  }

  async save(key: string, value: any) {
    await new Promise(resolve => setTimeout(resolve, this.latency));
    this.data.set(key, { ...value, updatedAt: Date.now() });
    return { saved: true, key };
  }

  async get(key: string) {
    await new Promise(resolve => setTimeout(resolve, this.latency));
    return this.data.get(key) || null;
  }

  async delete(key: string) {
    await new Promise(resolve => setTimeout(resolve, this.latency));
    const existed = this.data.has(key);
    this.data.delete(key);
    return { deleted: existed, key };
  }

  async query(predicate: (value: any) => boolean) {
    await new Promise(resolve => setTimeout(resolve, this.latency * 2));
    const results = Array.from(this.data.entries())
      .filter(([_, value]) => predicate(value))
      .map(([key, value]) => ({ key, ...value }));
    return results;
  }
}

class MockCacheService {
  private cache: Map<string, { value: any; expiry: number }> = new Map();
  private hits = 0;
  private misses = 0;

  async get(key: string) {
    await new Promise(resolve => setTimeout(resolve, 5)); // Very fast cache
    const entry = this.cache.get(key);
    if (entry && entry.expiry > Date.now()) {
      this.hits++;
      return entry.value;
    }
    this.misses++;
    return null;
  }

  async set(key: string, value: any, ttlMs = 60000) {
    await new Promise(resolve => setTimeout(resolve, 5));
    this.cache.set(key, { value, expiry: Date.now() + ttlMs });
    return true;
  }

  getStats() {
    return { hits: this.hits, misses: this.misses, hitRate: this.hits / (this.hits + this.misses) };
  }
}

describe('Real-World Integration Scenarios', () => {
  let apiClient: MockAPIClient;
  let database: MockDatabase;
  let cache: MockCacheService;

  beforeEach(() => {
    apiClient = new MockAPIClient(30, 0.05); // 30ms latency, 5% failure rate
    database = new MockDatabase(15);
    cache = new MockCacheService();
  });

  afterEach(() => {
    const cacheStats = cache.getStats();
    console.log(`\\n=== INTEGRATION STATS ===`);
    console.log(`Cache Hit Rate: ${(cacheStats.hitRate * 100).toFixed(2)}%`);
    console.log(`Cache Hits: ${cacheStats.hits}, Misses: ${cacheStats.misses}`);
  });

  describe('E-Commerce User Dashboard', () => {
    it('REAL-01: Complete user dashboard data aggregation', async () => {
      const dashboardReactor = createReactor()
        .input('user_id')
        .input('include_recommendations', { defaultValue: true })

        // Step 1: Check cache first
        .step('check_cache', {
          arguments: { userId: arg.input('user_id') },
          async run({ userId }) {
            const cacheKey = `dashboard:${userId}`;
            const cached = await cache.get(cacheKey);
            return { hit: !!cached, data: cached, key: cacheKey };
          }
        })

        // Step 2: Fetch user profile (parallel with orders)
        .step('fetch_profile', {
          arguments: { 
            userId: arg.input('user_id'),
            cache: arg.step('check_cache')
          },
          async run({ userId, cache }) {
            if (cache.hit) return cache.data.profile;
            return await apiClient.fetchUserProfile(userId);
          }
        })

        // Step 3: Fetch user orders (parallel with profile)
        .step('fetch_orders', {
          arguments: { 
            userId: arg.input('user_id'),
            cache: arg.step('check_cache')
          },
          async run({ userId, cache }) {
            if (cache.hit) return cache.data.orders;
            return await apiClient.fetchUserOrders(userId);
          }
        })

        // Step 4: Generate recommendations based on order history
        .step('generate_recommendations', {
          arguments: {
            userId: arg.input('user_id'),
            orders: arg.step('fetch_orders'),
            include: arg.input('include_recommendations'),
            cache: arg.step('check_cache')
          },
          async run({ userId, orders, include, cache }) {
            if (cache.hit) return cache.data.recommendations;
            if (!include) return [];
            return await apiClient.fetchRecommendations(userId, orders);
          }
        })

        // Step 5: Save aggregated data to database
        .step('save_dashboard_data', {
          arguments: {
            userId: arg.input('user_id'),
            profile: arg.step('fetch_profile'),
            orders: arg.step('fetch_orders'),
            recommendations: arg.step('generate_recommendations')
          },
          async run({ userId, profile, orders, recommendations }) {
            const dashboardData = {
              userId,
              profile,
              orders,
              recommendations,
              lastUpdated: Date.now()
            };
            return await database.save(`dashboard:${userId}`, dashboardData);
          }
        })

        // Step 6: Update cache
        .step('update_cache', {
          arguments: {
            cache: arg.step('check_cache'),
            profile: arg.step('fetch_profile'),
            orders: arg.step('fetch_orders'),
            recommendations: arg.step('generate_recommendations')
          },
          async run({ cache, profile, orders, recommendations }) {
            if (cache.hit) return { updated: false };
            const data = { profile, orders, recommendations };
            await cache.set(cache.key, data, 300000); // 5 minute TTL
            return { updated: true, key: cache.key };
          }
        })

        // Step 7: Format final response
        .step('format_dashboard', {
          arguments: {
            profile: arg.step('fetch_profile'),
            orders: arg.step('fetch_orders'),
            recommendations: arg.step('generate_recommendations'),
            saved: arg.step('save_dashboard_data'),
            cached: arg.step('update_cache')
          },
          async run({ profile, orders, recommendations, saved, cached }) {
            return {
              user: profile,
              orderSummary: {
                total: orders.length,
                pending: orders.filter((o: any) => o.status === 'pending').length,
                totalAmount: orders.reduce((sum: number, o: any) => sum + o.amount, 0)
              },
              recommendations: recommendations.slice(0, 3),
              metadata: {
                fromCache: !cached.updated,
                dataUpdated: saved.saved,
                generatedAt: Date.now()
              }
            };
          }
        })

        .return('format_dashboard')
        .build();

      const startTime = performance.now();
      const result = await dashboardReactor.execute({ user_id: 'user123' });
      const duration = performance.now() - startTime;

      expect(result.state).toBe('completed');
      expect(result.returnValue.user.id).toBe('user123');
      expect(result.returnValue.orderSummary.total).toBe(5);
      expect(result.returnValue.recommendations.length).toBeLessThanOrEqual(3);
      expect(duration).toBeLessThan(200); // Should complete in under 200ms due to parallelism
    });

    it('REAL-02: User dashboard with cache hit scenario', async () => {
      const userId = 'user456';
      
      // Pre-populate cache
      const cachedData = {
        profile: { id: userId, name: 'Cached User', email: 'cached@example.com' },
        orders: [{ id: 'cached-order', amount: 50, status: 'completed' }],
        recommendations: [{ id: 'cached-rec', title: 'Cached Product', price: 25 }]
      };
      await cache.set(`dashboard:${userId}`, cachedData);

      const dashboardReactor = createReactor()
        .input('user_id')
        .step('check_cache', {
          arguments: { userId: arg.input('user_id') },
          async run({ userId }) {
            const cacheKey = `dashboard:${userId}`;
            const cached = await cache.get(cacheKey);
            return { hit: !!cached, data: cached, key: cacheKey };
          }
        })
        .step('return_cached_or_fetch', {
          arguments: { cache: arg.step('check_cache') },
          async run({ cache }) {
            if (cache.hit) {
              return { 
                fromCache: true,
                ...cache.data
              };
            }
            // Would fetch from APIs if not cached
            throw new Error('Should have hit cache');
          }
        })
        .return('return_cached_or_fetch')
        .build();

      const startTime = performance.now();
      const result = await dashboardReactor.execute({ user_id: userId });
      const duration = performance.now() - startTime;

      expect(result.state).toBe('completed');
      expect(result.returnValue.fromCache).toBe(true);
      expect(result.returnValue.profile.name).toBe('Cached User');
      expect(duration).toBeLessThan(50); // Should be very fast from cache
    });
  });

  describe('Order Processing Pipeline', () => {
    it('REAL-03: Complete order fulfillment workflow', async () => {
      const orderProcessor = createReactor()
        .input('order_data')
        .input('customer_id')

        // Step 1: Validate order
        .step('validate_order', {
          arguments: { 
            order: arg.input('order_data'),
            customerId: arg.input('customer_id')
          },
          async run({ order, customerId }) {
            if (!order.items || order.items.length === 0) {
              throw new Error('Order must contain items');
            }
            if (!customerId) {
              throw new Error('Customer ID required');
            }
            return {
              orderId: `order-${Date.now()}`,
              validated: true,
              itemCount: order.items.length,
              totalAmount: order.items.reduce((sum: number, item: any) => sum + (item.price * item.quantity), 0)
            };
          }
        })

        // Step 2: Check inventory (parallel with payment)
        .step('check_inventory', {
          arguments: { order: arg.step('validate_order') },
          async run({ order }) {
            await new Promise(resolve => setTimeout(resolve, 25)); // Simulate inventory check
            const availability = order.itemCount <= 10; // Simulate inventory logic
            return {
              available: availability,
              reservedItems: availability ? order.itemCount : 0,
              reservationId: availability ? `res-${Date.now()}` : null
            };
          }
        })

        // Step 3: Process payment (parallel with inventory)
        .step('process_payment', {
          arguments: { 
            order: arg.step('validate_order'),
            customerId: arg.input('customer_id')
          },
          async run({ order, customerId }) {
            await new Promise(resolve => setTimeout(resolve, 40)); // Simulate payment processing
            const success = order.totalAmount < 1000; // Simulate payment logic
            return {
              success,
              transactionId: success ? `txn-${Date.now()}` : null,
              amount: order.totalAmount,
              customerId
            };
          },
          async compensate(error, args, context) {
            // Simulate payment rollback
            console.log(`Rolling back payment for customer ${args.customerId}`);
            return 'abort';
          },
          async undo(result, args, context) {
            if (result.success) {
              console.log(`Refunding transaction ${result.transactionId}`);
            }
          }
        })

        // Step 4: Create shipping label (depends on both inventory and payment)
        .step('create_shipping', {
          arguments: {
            order: arg.step('validate_order'),
            inventory: arg.step('check_inventory'),
            payment: arg.step('process_payment')
          },
          async run({ order, inventory, payment }) {
            if (!inventory.available) {
              throw new Error('Items not available for shipping');
            }
            if (!payment.success) {
              throw new Error('Payment failed, cannot ship');
            }

            await new Promise(resolve => setTimeout(resolve, 20)); // Simulate shipping label creation
            return {
              trackingNumber: `track-${Date.now()}`,
              shippingAddress: 'Mock Address',
              estimatedDelivery: new Date(Date.now() + 3 * 24 * 60 * 60 * 1000).toISOString()
            };
          }
        })

        // Step 5: Send confirmation notifications
        .step('send_notifications', {
          arguments: {
            customerId: arg.input('customer_id'),
            order: arg.step('validate_order'),
            shipping: arg.step('create_shipping'),
            payment: arg.step('process_payment')
          },
          async run({ customerId, order, shipping, payment }) {
            const message = `Order ${order.orderId} confirmed! Tracking: ${shipping.trackingNumber}`;
            const notification = await apiClient.sendNotification(customerId, message);
            return {
              notificationSent: notification.sent,
              messageId: notification.messageId
            };
          }
        })

        // Step 6: Save final order record
        .step('save_order_record', {
          arguments: {
            order: arg.step('validate_order'),
            inventory: arg.step('check_inventory'),
            payment: arg.step('process_payment'),
            shipping: arg.step('create_shipping'),
            notifications: arg.step('send_notifications')
          },
          async run({ order, inventory, payment, shipping, notifications }) {
            const orderRecord = {
              ...order,
              inventory,
              payment,
              shipping,
              notifications,
              status: 'confirmed',
              createdAt: Date.now()
            };
            return await database.save(`order:${order.orderId}`, orderRecord);
          }
        })

        .return('save_order_record')
        .build();

      const orderData = {
        items: [
          { id: 'item1', price: 25, quantity: 2 },
          { id: 'item2', price: 15, quantity: 1 }
        ]
      };

      const startTime = performance.now();
      const result = await orderProcessor.execute({ 
        order_data: orderData,
        customer_id: 'customer789'
      });
      const duration = performance.now() - startTime;

      expect(result.state).toBe('completed');
      expect(result.returnValue.saved).toBe(true);
      expect(duration).toBeLessThan(150); // Should complete efficiently due to parallelism
    });

    it('REAL-04: Order processing with payment failure and rollback', async () => {
      const orderProcessor = createReactor()
        .input('order_data')
        .input('customer_id')

        .step('validate_order', {
          arguments: { 
            order: arg.input('order_data'),
            customerId: arg.input('customer_id')
          },
          async run({ order, customerId }) {
            return {
              orderId: `order-${Date.now()}`,
              validated: true,
              itemCount: order.items.length,
              totalAmount: order.items.reduce((sum: number, item: any) => sum + (item.price * item.quantity), 0)
            };
          }
        })

        .step('reserve_inventory', {
          arguments: { order: arg.step('validate_order') },
          async run({ order }) {
            return {
              reserved: true,
              reservationId: `res-${Date.now()}`,
              items: order.itemCount
            };
          },
          async undo(result) {
            console.log(`Releasing inventory reservation ${result.reservationId}`);
          }
        })

        .step('process_payment', {
          arguments: { order: arg.step('validate_order') },
          async run({ order }) {
            // Force payment failure for large orders
            if (order.totalAmount > 50) {
              throw new Error('Payment declined - insufficient funds');
            }
            return { success: true, transactionId: `txn-${Date.now()}` };
          }
        })

        .return('process_payment')
        .build();

      const largeOrder = {
        items: [
          { id: 'expensive-item', price: 100, quantity: 1 }
        ]
      };

      const result = await orderProcessor.execute({
        order_data: largeOrder,
        customer_id: 'customer999'
      });

      expect(result.state).toBe('failed');
      expect(result.errors.some(e => e.message.includes('Payment declined'))).toBe(true);
      
      // Verify rollback occurred (would be visible in logs)
      // In a real implementation, we'd verify inventory was released
    });
  });

  describe('Data Analytics Pipeline', () => {
    it('REAL-05: Real-time analytics data processing', async () => {
      // Simulate real-time event data
      const generateEvents = (count: number) => 
        Array.from({ length: count }, (_, i) => ({
          id: `event-${i}`,
          type: ['page_view', 'click', 'purchase', 'signup'][Math.floor(Math.random() * 4)],
          userId: `user-${Math.floor(Math.random() * 100)}`,
          timestamp: Date.now() - Math.random() * 86400000, // Last 24 hours
          data: { value: Math.random() * 100 }
        }));

      const analyticsProcessor = createReactor()
        .input('events')
        .input('time_window', { defaultValue: 3600000 }) // 1 hour default

        // Step 1: Filter recent events
        .step('filter_recent_events', {
          arguments: { 
            events: arg.input('events'),
            window: arg.input('time_window')
          },
          async run({ events, window }) {
            const cutoff = Date.now() - window;
            const recent = events.filter((e: any) => e.timestamp > cutoff);
            return { events: recent, total: recent.length, filtered: events.length - recent.length };
          }
        })

        // Step 2: Group by event type (parallel processing)
        .step('group_by_type', {
          arguments: { filtered: arg.step('filter_recent_events') },
          async run({ filtered }) {
            const grouped = filtered.events.reduce((acc: any, event: any) => {
              acc[event.type] = acc[event.type] || [];
              acc[event.type].push(event);
              return acc;
            }, {});
            return { grouped, types: Object.keys(grouped) };
          }
        })

        // Step 3: Calculate user metrics (parallel)
        .step('calculate_user_metrics', {
          arguments: { filtered: arg.step('filter_recent_events') },
          async run({ filtered }) {
            const userEvents = filtered.events.reduce((acc: any, event: any) => {
              acc[event.userId] = acc[event.userId] || [];
              acc[event.userId].push(event);
              return acc;
            }, {});

            const metrics = {
              uniqueUsers: Object.keys(userEvents).length,
              avgEventsPerUser: filtered.total / Object.keys(userEvents).length,
              mostActiveUser: Object.entries(userEvents)
                .sort(([,a]: any, [,b]: any) => b.length - a.length)[0]?.[0]
            };

            return metrics;
          }
        })

        // Step 4: Calculate revenue metrics (parallel)
        .step('calculate_revenue_metrics', {
          arguments: { filtered: arg.step('filter_recent_events') },
          async run({ filtered }) {
            const purchases = filtered.events.filter((e: any) => e.type === 'purchase');
            const revenue = purchases.reduce((sum: number, p: any) => sum + p.data.value, 0);
            
            return {
              totalRevenue: revenue,
              totalPurchases: purchases.length,
              avgOrderValue: purchases.length > 0 ? revenue / purchases.length : 0
            };
          }
        })

        // Step 5: Generate insights (depends on all metrics)
        .step('generate_insights', {
          arguments: {
            grouped: arg.step('group_by_type'),
            userMetrics: arg.step('calculate_user_metrics'),
            revenueMetrics: arg.step('calculate_revenue_metrics')
          },
          async run({ grouped, userMetrics, revenueMetrics }) {
            const insights = {
              summary: {
                totalEvents: Object.values(grouped.grouped).flat().length,
                eventTypes: grouped.types,
                ...userMetrics,
                ...revenueMetrics
              },
              trends: {
                mostCommonEvent: grouped.types.reduce((a: string, b: string) => 
                  grouped.grouped[a].length > grouped.grouped[b].length ? a : b),
                conversionRate: userMetrics.uniqueUsers > 0 ? 
                  (revenueMetrics.totalPurchases / userMetrics.uniqueUsers) * 100 : 0
              },
              recommendations: []
            };

            // Generate recommendations based on data
            if (insights.trends.conversionRate < 5) {
              insights.recommendations.push('Low conversion rate - consider improving user experience');
            }
            if (revenueMetrics.avgOrderValue < 20) {
              insights.recommendations.push('Low average order value - consider upselling strategies');
            }

            return insights;
          }
        })

        // Step 6: Cache results
        .step('cache_analytics', {
          arguments: { insights: arg.step('generate_insights') },
          async run({ insights }) {
            const cacheKey = `analytics:${Math.floor(Date.now() / 300000) * 300000}`; // 5-min buckets
            await cache.set(cacheKey, insights, 300000);
            return { cached: true, key: cacheKey };
          }
        })

        .return('generate_insights')
        .build();

      const events = generateEvents(1000);
      const startTime = performance.now();
      const result = await analyticsProcessor.execute({ events });
      const duration = performance.now() - startTime;

      expect(result.state).toBe('completed');
      expect(result.returnValue.summary.totalEvents).toBeGreaterThan(0);
      expect(result.returnValue.summary.uniqueUsers).toBeGreaterThan(0);
      expect(result.returnValue.trends.conversionRate).toBeGreaterThanOrEqual(0);
      expect(duration).toBeLessThan(100); // Should process 1000 events quickly
    });
  });
});