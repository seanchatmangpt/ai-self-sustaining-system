/**
 * Meaningful Work Validation Tests
 * Demonstrates actual in-memory state management and operations
 */

import { describe, it, expect, beforeEach } from 'vitest';
import { createReactor, arg } from '../core/reactor-builder';
import type { CompensationResult } from '../types';

// Simple Resource Manager
class ResourceManager {
  private resources = new Map<string, { id: string; type: string; status: 'active' | 'released'; created: number }>();
  private allocatedCount = 0;
  private releasedCount = 0;

  allocate(type: string): string {
    const id = `${type}_${Date.now()}_${Math.random().toString(36).substr(2, 5)}`;
    this.resources.set(id, {
      id,
      type,
      status: 'active',
      created: Date.now()
    });
    this.allocatedCount++;
    return id;
  }

  release(id: string): boolean {
    const resource = this.resources.get(id);
    if (resource && resource.status === 'active') {
      resource.status = 'released';
      this.releasedCount++;
      return true;
    }
    return false;
  }

  getStats() {
    const active = Array.from(this.resources.values()).filter(r => r.status === 'active');
    return {
      allocated: this.allocatedCount,
      released: this.releasedCount,
      active: active.length,
      total: this.resources.size
    };
  }

  getActiveResources() {
    return Array.from(this.resources.values()).filter(r => r.status === 'active');
  }
}

// Event Tracker
class EventTracker {
  private events: Array<{ type: string; data: any; timestamp: number }> = [];

  emit(type: string, data: any) {
    this.events.push({ type, data, timestamp: Date.now() });
  }

  getEvents(type?: string) {
    return type ? this.events.filter(e => e.type === type) : [...this.events];
  }

  getEventCount(type?: string) {
    return type ? this.events.filter(e => e.type === type).length : this.events.length;
  }

  clear() {
    this.events = [];
  }
}

// Data Store
class DataStore {
  private data = new Map<string, any>();
  private writeCount = 0;
  private readCount = 0;

  write(key: string, value: any) {
    this.data.set(key, { value, timestamp: Date.now() });
    this.writeCount++;
  }

  read(key: string) {
    this.readCount++;
    const entry = this.data.get(key);
    return entry ? entry.value : null;
  }

  delete(key: string) {
    return this.data.delete(key);
  }

  getStats() {
    return {
      size: this.data.size,
      writes: this.writeCount,
      reads: this.readCount
    };
  }

  clear() {
    this.data.clear();
    this.writeCount = 0;
    this.readCount = 0;
  }
}

describe('Meaningful Work Validation', () => {
  let resourceManager: ResourceManager;
  let eventTracker: EventTracker;
  let dataStore: DataStore;

  beforeEach(() => {
    resourceManager = new ResourceManager();
    eventTracker = new EventTracker();
    dataStore = new DataStore();
  });

  describe('Resource Management with Retry', () => {
    it('Should allocate and manage resources with retry logic', async () => {
      let attemptCount = 0;
      const allocatedResources: string[] = [];

      const reactor = createReactor()
        .input('resource_type')
        .input('count')
        .step('allocate_resources', {
          arguments: { 
            type: arg.input('resource_type'),
            count: arg.input('count')
          },
          maxRetries: 2,
          async run({ type, count }) {
            attemptCount++;
            eventTracker.emit('allocation_attempt', { attempt: attemptCount, type, count });
            
            // Simulate resource exhaustion on first attempts
            if (attemptCount < 3) {
              const error = new Error('Resources temporarily unavailable') as any;
              error.type = 'resource_exhaustion';
              throw error;
            }
            
            // Successful allocation
            const resources = [];
            for (let i = 0; i < count; i++) {
              const resourceId = resourceManager.allocate(type);
              allocatedResources.push(resourceId);
              resources.push({ id: resourceId, type });
              eventTracker.emit('resource_allocated', { resourceId, type });
              dataStore.write(`resource:${resourceId}`, { id: resourceId, type, status: 'allocated' });
            }
            
            return { resources, count: resources.length, attempt: attemptCount };
          },
          async compensate(error: any): Promise<CompensationResult> {
            eventTracker.emit('allocation_compensation', { 
              error: error.message,
              type: error.type,
              attempt: attemptCount
            });
            
            if (error.type === 'resource_exhaustion' && attemptCount <= 3) {
              return 'retry';
            }
            return 'abort';
          },
          async undo(result) {
            // Release all allocated resources
            let releasedCount = 0;
            for (const resource of result.resources) {
              if (resourceManager.release(resource.id)) {
                releasedCount++;
                eventTracker.emit('resource_released', { resourceId: resource.id });
                dataStore.delete(`resource:${resource.id}`);
              }
            }
            eventTracker.emit('resource_cleanup', { released: releasedCount });
          }
        })
        .return('allocate_resources')
        .build();

      const result = await reactor.execute({ resource_type: 'compute', count: 3 });

      // Verify successful execution
      expect(result.state).toBe('completed');
      expect(result.returnValue.count).toBe(3);
      expect(attemptCount).toBe(3);

      // Verify resource management
      const stats = resourceManager.getStats();
      expect(stats.allocated).toBe(3);
      expect(stats.active).toBe(3);
      expect(stats.released).toBe(0);

      // Verify event tracking
      expect(eventTracker.getEventCount('allocation_attempt')).toBe(3);
      expect(eventTracker.getEventCount('allocation_compensation')).toBe(2);
      expect(eventTracker.getEventCount('resource_allocated')).toBe(3);

      // Verify data store
      const dataStats = dataStore.getStats();
      expect(dataStats.writes).toBe(3);
      expect(dataStats.size).toBe(3);

      // Verify compensation tracking in reactor context
      expect(result.context.compensationLog).toBeDefined();
      expect(result.context.compensationLog).toHaveLength(2);
      expect(result.context.compensationLog[0].result).toBe('retry');
    });

    it('Should perform rollback cleanup on failure', async () => {
      const allocatedResources: string[] = [];

      const reactor = createReactor()
        .input('count')
        .step('allocate_memory', {
          arguments: { count: arg.input('count') },
          async run({ count }) {
            for (let i = 0; i < count; i++) {
              const resourceId = resourceManager.allocate('memory');
              allocatedResources.push(resourceId);
              eventTracker.emit('memory_allocated', { resourceId, index: i });
              dataStore.write(`memory:${resourceId}`, { id: resourceId, size: 1024 });
            }
            return { allocated: count, resources: allocatedResources.map(id => ({ id })) };
          },
          async undo(result) {
            let cleanedUp = 0;
            for (const resource of result.resources) {
              if (resourceManager.release(resource.id)) {
                cleanedUp++;
                eventTracker.emit('memory_released', { resourceId: resource.id });
                dataStore.delete(`memory:${resource.id}`);
              }
            }
            eventTracker.emit('cleanup_completed', { cleaned: cleanedUp });
          }
        })
        .step('process_data', {
          arguments: { allocation: arg.step('allocate_memory') },
          async run({ allocation }) {
            // Force failure to trigger rollback
            throw new Error('Processing failed - insufficient CPU');
          }
        })
        .return('process_data')
        .build();

      const result = await reactor.execute({ count: 5 });

      // Verify failure and rollback
      expect(result.state).toBe('failed');

      // Verify all resources were cleaned up
      const stats = resourceManager.getStats();
      expect(stats.allocated).toBe(5);
      expect(stats.released).toBe(5);
      expect(stats.active).toBe(0);

      // Verify rollback events
      expect(eventTracker.getEventCount('memory_allocated')).toBe(5);
      expect(eventTracker.getEventCount('memory_released')).toBe(5);
      expect(eventTracker.getEventCount('cleanup_completed')).toBe(1);

      // Verify data store cleanup
      const dataStats = dataStore.getStats();
      expect(dataStats.size).toBe(0); // All data cleaned up

      // Verify undo tracking in reactor context
      expect(result.context.undoLog).toBeDefined();
      expect(result.context.undoLog.filter(log => log.action === 'undo_completed')).toHaveLength(1);
    });
  });

  describe('Skip and Continue Strategies', () => {
    it('Should skip failed service and continue with fallback', async () => {
      let serviceCallCount = 0;

      const reactor = createReactor()
        .input('request_data')
        .step('call_primary_service', {
          arguments: { data: arg.input('request_data') },
          async run({ data }) {
            serviceCallCount++;
            eventTracker.emit('service_call', { service: 'primary', attempt: serviceCallCount });
            
            // Always fail primary service
            const error = new Error('Primary service is down') as any;
            error.type = 'service_unavailable';
            throw error;
          },
          async compensate(error: any): Promise<CompensationResult> {
            eventTracker.emit('service_compensation', { 
              service: 'primary',
              error: error.type,
              decision: 'skip'
            });
            
            if (error.type === 'service_unavailable') {
              return 'skip'; // Skip and continue with fallback
            }
            return 'abort';
          }
        })
        .step('process_result', {
          arguments: { 
            primaryResult: arg.step('call_primary_service'),
            requestData: arg.input('request_data')
          },
          async run({ primaryResult, requestData }) {
            // Handle skipped primary service
            if (primaryResult === null) {
              // Use fallback data
              const fallbackData = dataStore.read('fallback_data') || { source: 'fallback', processed: true };
              eventTracker.emit('fallback_used', { reason: 'primary_service_skipped' });
              return { 
                result: fallbackData,
                source: 'fallback',
                primarySkipped: true
              };
            }
            
            // Normal processing
            return { 
              result: primaryResult,
              source: 'primary',
              primarySkipped: false
            };
          }
        })
        .return('process_result')
        .build();

      // Set up fallback data
      dataStore.write('fallback_data', { source: 'fallback', processed: true });

      const result = await reactor.execute({ request_data: { id: 'test123' } });

      // Verify successful completion with fallback
      expect(result.state).toBe('completed');
      expect(result.returnValue.source).toBe('fallback');
      expect(result.returnValue.primarySkipped).toBe(true);

      // Verify service call and compensation
      expect(serviceCallCount).toBe(1);
      expect(eventTracker.getEventCount('service_call')).toBe(1);
      expect(eventTracker.getEventCount('service_compensation')).toBe(1);
      expect(eventTracker.getEventCount('fallback_used')).toBe(1);

      // Verify compensation was logged
      expect(result.context.compensationLog).toBeDefined();
      expect(result.context.compensationLog[0].result).toBe('skip');
    });

    it('Should continue with provided value on API failure', async () => {
      const reactor = createReactor()
        .input('api_endpoint')
        .step('fetch_api_data', {
          arguments: { endpoint: arg.input('api_endpoint') },
          async run({ endpoint }) {
            eventTracker.emit('api_call', { endpoint });
            
            // Simulate API failure
            const error = new Error('API rate limit exceeded') as any;
            error.type = 'rate_limit';
            throw error;
          },
          async compensate(error: any): Promise<CompensationResult> {
            eventTracker.emit('api_compensation', { 
              error: error.type,
              decision: 'continue_with_cache'
            });
            
            if (error.type === 'rate_limit') {
              // Return cached/default data
              const cachedData = dataStore.read('cached_api_data') || { 
                data: 'default_data',
                source: 'cache',
                timestamp: Date.now()
              };
              return { continue: cachedData };
            }
            return 'abort';
          }
        })
        .step('process_api_result', {
          arguments: { apiData: arg.step('fetch_api_data') },
          async run({ apiData }) {
            eventTracker.emit('data_processed', { 
              source: apiData.source || 'api',
              hasData: !!apiData
            });
            
            // Store processed result
            const processedData = {
              ...apiData,
              processed: true,
              processedAt: Date.now()
            };
            dataStore.write('processed_result', processedData);
            
            return processedData;
          }
        })
        .return('process_api_result')
        .build();

      // Set up cached data
      dataStore.write('cached_api_data', { data: 'cached_data', source: 'cache' });

      const result = await reactor.execute({ api_endpoint: 'https://api.example.com/data' });

      // Verify successful completion with cached data
      expect(result.state).toBe('completed');
      expect(result.returnValue.source).toBe('cache');
      expect(result.returnValue.processed).toBe(true);

      // Verify events
      expect(eventTracker.getEventCount('api_call')).toBe(1);
      expect(eventTracker.getEventCount('api_compensation')).toBe(1);
      expect(eventTracker.getEventCount('data_processed')).toBe(1);

      // Verify data was processed and stored
      const processedResult = dataStore.read('processed_result');
      expect(processedResult.source).toBe('cache');
      expect(processedResult.processed).toBe(true);

      // Verify compensation provided value
      expect(result.context.compensationLog[0].result).toEqual({ continue: expect.any(Object) });
    });
  });

  describe('Performance and State Tracking', () => {
    it('Should track comprehensive metrics and state', async () => {
      let operationCount = 0;

      const reactor = createReactor()
        .input('batch_size')
        .step('process_batch', {
          arguments: { size: arg.input('batch_size') },
          maxRetries: 1,
          async run({ size }) {
            operationCount++;
            eventTracker.emit('batch_start', { size, attempt: operationCount });
            
            const resources = [];
            const results = [];
            
            for (let i = 0; i < size; i++) {
              // Allocate resource for each operation
              const resourceId = resourceManager.allocate('worker');
              resources.push(resourceId);
              
              // Process item
              const result = {
                id: i,
                resourceId,
                data: `processed_item_${i}`,
                timestamp: Date.now()
              };
              results.push(result);
              
              // Store result
              dataStore.write(`result:${i}`, result);
              eventTracker.emit('item_processed', { itemId: i, resourceId });
            }
            
            eventTracker.emit('batch_completed', { size, resources: resources.length });
            return { results, resources, processed: size };
          },
          async compensate(error: any): Promise<CompensationResult> {
            eventTracker.emit('batch_compensation', { 
              error: error.message,
              attempt: operationCount
            });
            return 'retry';
          },
          async undo(result) {
            // Clean up resources and data
            let resourcesReleased = 0;
            let dataDeleted = 0;
            
            for (const resourceId of result.resources) {
              if (resourceManager.release(resourceId)) {
                resourcesReleased++;
              }
            }
            
            for (const item of result.results) {
              if (dataStore.delete(`result:${item.id}`)) {
                dataDeleted++;
              }
            }
            
            eventTracker.emit('batch_cleanup', { 
              resourcesReleased,
              dataDeleted,
              totalItems: result.results.length
            });
          }
        })
        .step('generate_report', {
          arguments: { batch: arg.step('process_batch') },
          async run({ batch }) {
            const report = {
              batchSummary: {
                processed: batch.processed,
                resourcesUsed: batch.resources.length,
                resultsStored: batch.results.length
              },
              resourceStats: resourceManager.getStats(),
              dataStats: dataStore.getStats(),
              eventStats: {
                totalEvents: eventTracker.getEventCount(),
                batchEvents: eventTracker.getEventCount('batch_start'),
                itemEvents: eventTracker.getEventCount('item_processed')
              },
              timestamp: Date.now()
            };
            
            // Store the report
            dataStore.write('final_report', report);
            eventTracker.emit('report_generated', { reportSize: Object.keys(report).length });
            
            return report;
          }
        })
        .return('generate_report')
        .build();

      const result = await reactor.execute({ batch_size: 10 });

      // Verify successful completion
      expect(result.state).toBe('completed');
      expect(result.returnValue.batchSummary.processed).toBe(10);

      // Verify resource management
      const resourceStats = result.returnValue.resourceStats;
      expect(resourceStats.allocated).toBe(10);
      expect(resourceStats.active).toBe(10);

      // Verify data storage
      const dataStats = result.returnValue.dataStats;
      expect(dataStats.writes).toBeGreaterThanOrEqual(10); // Batch results + report  
      expect(dataStats.size).toBeGreaterThanOrEqual(10);

      // Verify event tracking
      const eventStats = result.returnValue.eventStats;
      expect(eventStats.totalEvents).toBeGreaterThan(10);
      expect(eventStats.itemEvents).toBe(10);

      // Verify report was stored
      const storedReport = dataStore.read('final_report');
      expect(storedReport).toBeDefined();
      expect(storedReport.batchSummary.processed).toBe(10);

      console.log('\\n=== MEANINGFUL WORK REPORT ===');
      console.log('Resource Stats:', resourceStats);
      console.log('Data Stats:', dataStats);
      console.log('Event Stats:', eventStats);
      console.log('Active Resources:', resourceManager.getActiveResources().length);
      console.log('Total Events Generated:', eventTracker.getEventCount());
    });
  });
});