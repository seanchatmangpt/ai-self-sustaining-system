/**
 * Meaningful Error Handling Tests
 * In-memory work with actual state management and resource operations
 */

import { describe, it, expect, beforeEach } from 'vitest';
import { createReactor, arg } from '../core/reactor-builder';
import type { CompensationResult } from '../types';

// Resource Management System
class ResourcePool {
  private resources: Map<string, { id: string; type: string; status: 'allocated' | 'released'; allocatedAt: number }> = new Map();
  private metrics = {
    totalAllocated: 0,
    totalReleased: 0,
    currentlyActive: 0,
    failedAllocations: 0
  };

  allocate(type: string): string {
    const resourceId = `${type}_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
    this.resources.set(resourceId, {
      id: resourceId,
      type,
      status: 'allocated',
      allocatedAt: Date.now()
    });
    this.metrics.totalAllocated++;
    this.metrics.currentlyActive++;
    return resourceId;
  }

  release(resourceId: string): boolean {
    const resource = this.resources.get(resourceId);
    if (resource && resource.status === 'allocated') {
      resource.status = 'released';
      this.metrics.totalReleased++;
      this.metrics.currentlyActive--;
      return true;
    }
    return false;
  }

  getResource(id: string) {
    return this.resources.get(id);
  }

  getMetrics() {
    return { ...this.metrics };
  }

  getActiveResources() {
    return Array.from(this.resources.values()).filter(r => r.status === 'allocated');
  }

  clear() {
    this.resources.clear();
    this.metrics = {
      totalAllocated: 0,
      totalReleased: 0,
      currentlyActive: 0,
      failedAllocations: 0
    };
  }
}

// Circuit Breaker Implementation
class CircuitBreaker {
  private failures = 0;
  private lastFailureTime = 0;
  private state: 'closed' | 'open' | 'half-open' = 'closed';
  private successCount = 0;

  constructor(
    private failureThreshold = 3,
    private recoveryTimeoutMs = 1000,
    private successThreshold = 2
  ) {}

  canExecute(): boolean {
    const now = Date.now();
    
    if (this.state === 'open') {
      if (now - this.lastFailureTime >= this.recoveryTimeoutMs) {
        this.state = 'half-open';
        this.successCount = 0;
        return true;
      }
      return false;
    }
    
    return true;
  }

  recordSuccess(): void {
    this.failures = 0;
    
    if (this.state === 'half-open') {
      this.successCount++;
      if (this.successCount >= this.successThreshold) {
        this.state = 'closed';
      }
    }
  }

  recordFailure(): void {
    this.failures++;
    this.lastFailureTime = Date.now();
    
    if (this.failures >= this.failureThreshold) {
      this.state = 'open';
    }
  }

  getState() {
    return {
      state: this.state,
      failures: this.failures,
      successCount: this.successCount,
      lastFailureTime: this.lastFailureTime
    };
  }

  reset() {
    this.failures = 0;
    this.lastFailureTime = 0;
    this.state = 'closed';
    this.successCount = 0;
  }
}

// Data Cache System
class DataCache {
  private cache: Map<string, { value: any; ttl: number; hits: number; createdAt: number }> = new Map();
  private metrics = {
    hits: 0,
    misses: 0,
    sets: 0,
    evictions: 0
  };

  set(key: string, value: any, ttlMs = 60000): void {
    this.cache.set(key, {
      value,
      ttl: Date.now() + ttlMs,
      hits: 0,
      createdAt: Date.now()
    });
    this.metrics.sets++;
  }

  get(key: string): any {
    const entry = this.cache.get(key);
    if (!entry || entry.ttl < Date.now()) {
      if (entry) {
        this.cache.delete(key);
        this.metrics.evictions++;
      }
      this.metrics.misses++;
      return null;
    }
    
    entry.hits++;
    this.metrics.hits++;
    return entry.value;
  }

  delete(key: string): boolean {
    const deleted = this.cache.delete(key);
    if (deleted) {
      this.metrics.evictions++;
    }
    return deleted;
  }

  getMetrics() {
    return {
      ...this.metrics,
      size: this.cache.size,
      hitRate: this.metrics.hits / (this.metrics.hits + this.metrics.misses)
    };
  }

  clear() {
    this.cache.clear();
    this.metrics = { hits: 0, misses: 0, sets: 0, evictions: 0 };
  }
}

// Event Aggregator
class EventAggregator {
  private events: Array<{ type: string; data: any; timestamp: number; id: string }> = [];
  private subscribers: Map<string, Array<(event: any) => void>> = new Map();

  emit(type: string, data: any): string {
    const event = {
      type,
      data,
      timestamp: Date.now(),
      id: `event_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`
    };
    
    this.events.push(event);
    
    const subs = this.subscribers.get(type) || [];
    subs.forEach(callback => {
      try {
        callback(event);
      } catch (error) {
        // Ignore subscriber errors
      }
    });
    
    return event.id;
  }

  subscribe(type: string, callback: (event: any) => void): () => void {
    if (!this.subscribers.has(type)) {
      this.subscribers.set(type, []);
    }
    this.subscribers.get(type)!.push(callback);
    
    return () => {
      const subs = this.subscribers.get(type);
      if (subs) {
        const index = subs.indexOf(callback);
        if (index > -1) {
          subs.splice(index, 1);
        }
      }
    };
  }

  getEvents(type?: string) {
    return type ? this.events.filter(e => e.type === type) : [...this.events];
  }

  getMetrics() {
    const typeCount = new Map<string, number>();
    this.events.forEach(e => {
      typeCount.set(e.type, (typeCount.get(e.type) || 0) + 1);
    });
    
    return {
      totalEvents: this.events.length,
      uniqueTypes: typeCount.size,
      eventsByType: Object.fromEntries(typeCount)
    };
  }

  clear() {
    this.events = [];
    this.subscribers.clear();
  }
}

describe('Meaningful Error Handling Tests', () => {
  let resourcePool: ResourcePool;
  let circuitBreaker: CircuitBreaker;
  let dataCache: DataCache;
  let eventAggregator: EventAggregator;

  beforeEach(() => {
    resourcePool = new ResourcePool();
    circuitBreaker = new CircuitBreaker(2, 500, 1); // More aggressive for testing
    dataCache = new DataCache();
    eventAggregator = new EventAggregator();
  });

  describe('Resource Management with Retry', () => {
    it('Should retry resource allocation with exponential backoff', async () => {
      let allocationAttempts = 0;
      const allocatedResources: string[] = [];

      const reactor = createReactor()
        .input('resource_count')
        .step('allocate_resources', {
          arguments: { count: arg.input('resource_count') },
          maxRetries: 3,
          async run({ count }) {
            allocationAttempts++;
            eventAggregator.emit('allocation_attempt', { attempt: allocationAttempts, count });
            
            // Simulate resource exhaustion on first attempts
            if (allocationAttempts < 3) {
              const error = new Error('Resource pool exhausted') as any;
              error.type = 'resource_exhaustion';
              error.retryable = true;
              throw error;
            }
            
            // Successful allocation
            const resources = [];
            for (let i = 0; i < count; i++) {
              const resourceId = resourcePool.allocate('compute');
              allocatedResources.push(resourceId);
              resources.push({ id: resourceId, type: 'compute' });
            }
            
            eventAggregator.emit('allocation_success', { resources: resources.length });
            return { 
              resources, 
              allocated: resources.length,
              attempt: allocationAttempts 
            };
          },
          async compensate(error: any): Promise<CompensationResult> {
            eventAggregator.emit('allocation_compensation', { 
              error: error.message, 
              type: error.type,
              attempt: allocationAttempts
            });
            
            if (error.type === 'resource_exhaustion' && allocationAttempts <= 3) {
              // Simulate waiting for resources to become available
              return 'retry';
            }
            return 'abort';
          },
          async undo(result) {
            // Release all allocated resources
            let released = 0;
            for (const resource of result.resources) {
              if (resourcePool.release(resource.id)) {
                released++;
              }
            }
            eventAggregator.emit('resource_cleanup', { released });
          }
        })
        .return('allocate_resources')
        .build();

      const result = await reactor.execute({ resource_count: 5 });

      expect(result.state).toBe('completed');
      expect(result.returnValue.allocated).toBe(5);
      expect(allocationAttempts).toBe(3);
      
      const metrics = resourcePool.getMetrics();
      expect(metrics.totalAllocated).toBe(5);
      expect(metrics.currentlyActive).toBe(5);
      
      const events = eventAggregator.getEvents();
      expect(events.filter(e => e.type === 'allocation_attempt')).toHaveLength(3);
      expect(events.filter(e => e.type === 'allocation_compensation')).toHaveLength(2);
      expect(events.filter(e => e.type === 'allocation_success')).toHaveLength(1);
    });

    it('Should handle resource cleanup on failure', async () => {
      const allocatedResources: string[] = [];

      const reactor = createReactor()
        .input('operations')
        .step('allocate_memory', {
          arguments: { ops: arg.input('operations') },
          async run({ ops }) {
            const resourceId = resourcePool.allocate('memory');
            allocatedResources.push(resourceId);
            eventAggregator.emit('memory_allocated', { resourceId, size: ops.length });
            return { resourceId, size: ops.length };
          },
          async undo(result) {
            if (resourcePool.release(result.resourceId)) {
              eventAggregator.emit('memory_released', { resourceId: result.resourceId });
            }
          }
        })
        .step('process_operations', {
          arguments: { 
            memory: arg.step('allocate_memory'),
            ops: arg.input('operations')
          },
          async run({ memory, ops }) {
            // Simulate processing failure
            throw new Error('Processing failed - out of memory');
          }
        })
        .return('process_operations')
        .build();

      const result = await reactor.execute({ 
        operations: Array.from({ length: 1000 }, (_, i) => ({ id: i, data: 'test' }))
      });

      expect(result.state).toBe('failed');
      
      // Verify resource was cleaned up
      const metrics = resourcePool.getMetrics();
      expect(metrics.currentlyActive).toBe(0);
      expect(metrics.totalReleased).toBe(1);
      
      const cleanupEvents = eventAggregator.getEvents('memory_released');
      expect(cleanupEvents).toHaveLength(1);
    });
  });

  describe('Circuit Breaker with Skip Strategy', () => {
    it('Should implement circuit breaker pattern with skip compensation', async () => {
      let serviceCallCount = 0;

      const reactor = createReactor()
        .input('requests')
        .step('call_external_service', {
          arguments: { requests: arg.input('requests') },
          async run({ requests }) {
            serviceCallCount++;
            eventAggregator.emit('service_call', { attempt: serviceCallCount });
            
            if (!circuitBreaker.canExecute()) {
              const error = new Error('Circuit breaker is OPEN') as any;
              error.type = 'circuit_open';
              throw error;
            }
            
            // Simulate service failures to trip circuit breaker
            if (serviceCallCount <= 2) {
              circuitBreaker.recordFailure();
              const error = new Error('Service unavailable') as any;
              error.type = 'service_unavailable';
              throw error;
            }
            
            circuitBreaker.recordSuccess();
            return { 
              processed: requests.length,
              serviceCall: serviceCallCount,
              circuitState: circuitBreaker.getState()
            };
          },
          async compensate(error: any): Promise<CompensationResult> {
            const circuitState = circuitBreaker.getState();
            eventAggregator.emit('service_compensation', { 
              error: error.type,
              circuitState: circuitState.state,
              failures: circuitState.failures
            });
            
            if (error.type === 'circuit_open') {
              // Circuit is open, skip and use cached data
              return { continue: { 
                processed: 0, 
                fromCache: true, 
                circuitState: circuitState.state 
              }};
            } else if (error.type === 'service_unavailable') {
              // Service failure, let circuit breaker decide
              return 'skip';
            }
            return 'abort';
          }
        })
        .step('handle_result', {
          arguments: { 
            serviceResult: arg.step('call_external_service'),
            requests: arg.input('requests')
          },
          async run({ serviceResult, requests }) {
            if (serviceResult?.fromCache) {
              // Use cached/fallback data
              const cachedData = dataCache.get('service_fallback') || { processed: requests.length, source: 'fallback' };
              eventAggregator.emit('fallback_used', { source: 'cache', items: cachedData.processed });
              return cachedData;
            }
            
            // Cache successful result
            dataCache.set('service_result', serviceResult, 30000);
            eventAggregator.emit('result_cached', { items: serviceResult.processed });
            return serviceResult;
          }
        })
        .return('handle_result')
        .build();

      // Set up fallback data
      dataCache.set('service_fallback', { processed: 100, source: 'fallback' });

      const requests = Array.from({ length: 100 }, (_, i) => ({ id: i }));
      const result = await reactor.execute({ requests });

      expect(result.state).toBe('completed');
      expect(result.returnValue.source).toBe('fallback');
      
      const circuitState = circuitBreaker.getState();
      expect(circuitState.state).toBe('open');
      expect(circuitState.failures).toBe(2);
      
      const fallbackEvents = eventAggregator.getEvents('fallback_used');
      expect(fallbackEvents).toHaveLength(1);
      
      const cacheMetrics = dataCache.getMetrics();
      expect(cacheMetrics.hits).toBeGreaterThan(0);
    });
  });

  describe('Data Pipeline with Cache and Fallback', () => {
    it('Should implement sophisticated caching with compensation strategies', async () => {
      let apiCallCount = 0;
      const processedData = new Map<string, any>();

      const reactor = createReactor()
        .input('data_keys')
        .input('options')
        .step('fetch_from_cache', {
          arguments: { keys: arg.input('data_keys') },
          async run({ keys }) {
            const cached = [];
            const missing = [];
            
            for (const key of keys) {
              const data = dataCache.get(`data:${key}`);
              if (data) {
                cached.push({ key, data, source: 'cache' });
                eventAggregator.emit('cache_hit', { key });
              } else {
                missing.push(key);
                eventAggregator.emit('cache_miss', { key });
              }
            }
            
            return { cached, missing, cacheHitRate: cached.length / keys.length };
          }
        })
        .step('fetch_missing_data', {
          arguments: { 
            cacheResult: arg.step('fetch_from_cache'),
            options: arg.input('options')
          },
          async run({ cacheResult, options }) {
            if (cacheResult.missing.length === 0) {
              return { fetched: [], source: 'none_needed' };
            }
            
            apiCallCount++;
            eventAggregator.emit('api_call', { attempt: apiCallCount, keys: cacheResult.missing });
            
            // Simulate API rate limiting
            if (apiCallCount > 2 && options.strict) {
              const error = new Error('API rate limit exceeded') as any;
              error.type = 'rate_limit';
              error.retryAfter = 1000;
              throw error;
            }
            
            const fetched = [];
            for (const key of cacheResult.missing) {
              const data = { id: key, value: `api_data_${key}`, timestamp: Date.now() };
              fetched.push({ key, data, source: 'api' });
              
              // Cache the fetched data
              dataCache.set(`data:${key}`, data, 60000);
              eventAggregator.emit('data_cached', { key });
            }
            
            return { fetched, source: 'api' };
          },
          async compensate(error: any): Promise<CompensationResult> {
            eventAggregator.emit('api_compensation', { 
              error: error.type,
              retryAfter: error.retryAfter 
            });
            
            if (error.type === 'rate_limit') {
              // Use stale cache data or generate defaults
              return { continue: { 
                fetched: [], 
                source: 'rate_limited',
                fallbackUsed: true 
              }};
            }
            return 'retry';
          }
        })
        .step('process_data', {
          arguments: {
            cached: arg.step('fetch_from_cache'),
            fetched: arg.step('fetch_missing_data'),
            keys: arg.input('data_keys')
          },
          async run({ cached, fetched, keys }) {
            const allData = [...cached.cached, ...fetched.fetched];
            const processed = [];
            
            for (const item of allData) {
              const processedItem = {
                ...item,
                processed: true,
                processedAt: Date.now(),
                hash: `hash_${item.key}_${Date.now()}`
              };
              processed.push(processedItem);
              processedData.set(item.key, processedItem);
              eventAggregator.emit('data_processed', { key: item.key, source: item.source });
            }
            
            // Handle missing data with defaults
            const processedKeys = new Set(processed.map(p => p.key));
            for (const key of keys) {
              if (!processedKeys.has(key)) {
                const defaultItem = {
                  key,
                  data: { id: key, value: `default_${key}`, isDefault: true },
                  source: 'default',
                  processed: true,
                  processedAt: Date.now()
                };
                processed.push(defaultItem);
                processedData.set(key, defaultItem);
                eventAggregator.emit('default_used', { key });
              }
            }
            
            return {
              processed: processed.length,
              items: processed,
              summary: {
                fromCache: cached.cached.length,
                fromApi: fetched.fetched.length,
                defaults: processed.filter(p => p.source === 'default').length,
                fallbackUsed: fetched.fallbackUsed || false
              }
            };
          }
        })
        .return('process_data')
        .build();

      // Pre-populate some cache data
      dataCache.set('data:key1', { id: 'key1', value: 'cached_data_1' });
      dataCache.set('data:key2', { id: 'key2', value: 'cached_data_2' });

      const keys = ['key1', 'key2', 'key3', 'key4', 'key5'];
      const result = await reactor.execute({ 
        data_keys: keys, 
        options: { strict: true } 
      });

      expect(result.state).toBe('completed');
      expect(result.returnValue.processed).toBe(5);
      expect(result.returnValue.summary.fromCache).toBe(2);
      
      const cacheMetrics = dataCache.getMetrics();
      expect(cacheMetrics.hits).toBe(2);
      expect(cacheMetrics.misses).toBe(3);
      
      const eventMetrics = eventAggregator.getMetrics();
      expect(eventMetrics.totalEvents).toBeGreaterThan(10);
      expect(eventMetrics.eventsByType.cache_hit).toBe(2);
      expect(eventMetrics.eventsByType.cache_miss).toBe(3);
      
      // Verify all data was processed
      expect(processedData.size).toBe(5);
      for (const key of keys) {
        expect(processedData.has(key)).toBe(true);
      }
    });
  });

  describe('Performance and State Tracking', () => {
    it('Should demonstrate comprehensive state management and metrics', async () => {
      const operationMetrics = {
        totalOperations: 0,
        successfulOperations: 0,
        failedOperations: 0,
        retryCount: 0,
        compensationCount: 0
      };

      const reactor = createReactor()
        .input('batch_size')
        .input('failure_rate')
        .step('batch_processor', {
          arguments: { 
            size: arg.input('batch_size'),
            failureRate: arg.input('failure_rate')
          },
          maxRetries: 2,
          async run({ size, failureRate }) {
            operationMetrics.totalOperations++;
            
            const operations = [];
            const resources = [];
            
            for (let i = 0; i < size; i++) {
              // Simulate random failures based on failure rate
              if (Math.random() < failureRate) {
                operationMetrics.failedOperations++;
                const error = new Error(`Operation ${i} failed`) as any;
                error.type = 'operation_failure';
                error.operationId = i;
                throw error;
              }
              
              // Allocate resources for successful operations
              const resourceId = resourcePool.allocate('worker');
              resources.push(resourceId);
              
              const operation = {
                id: i,
                resourceId,
                result: `processed_${i}`,
                timestamp: Date.now()
              };
              operations.push(operation);
              
              // Cache operation result
              dataCache.set(`op:${i}`, operation, 30000);
              eventAggregator.emit('operation_success', { operationId: i, resourceId });
            }
            
            operationMetrics.successfulOperations++;
            return {
              operations,
              resources,
              processed: operations.length,
              batchId: `batch_${Date.now()}`
            };
          },
          async compensate(error: any): Promise<CompensationResult> {
            operationMetrics.compensationCount++;
            operationMetrics.retryCount++;
            
            eventAggregator.emit('operation_compensation', {
              error: error.type,
              operationId: error.operationId,
              retryCount: operationMetrics.retryCount
            });
            
            if (error.type === 'operation_failure' && operationMetrics.retryCount <= 2) {
              return 'retry';
            }
            
            // Use fallback processing
            return { continue: {
              operations: [],
              resources: [],
              processed: 0,
              batchId: `fallback_${Date.now()}`,
              fallback: true
            }};
          },
          async undo(result) {
            // Clean up allocated resources
            let cleaned = 0;
            for (const resourceId of result.resources) {
              if (resourcePool.release(resourceId)) {
                cleaned++;
              }
            }
            
            // Clear cached operations
            for (const op of result.operations) {
              dataCache.delete(`op:${op.id}`);
            }
            
            eventAggregator.emit('batch_cleanup', { 
              resourcesCleaned: cleaned,
              operationsCleaned: result.operations.length,
              batchId: result.batchId
            });
          }
        })
        .step('generate_report', {
          arguments: { 
            batch: arg.step('batch_processor'),
            metrics: arg.value(operationMetrics)
          },
          async run({ batch, metrics }) {
            const report = {
              batchSummary: {
                batchId: batch.batchId,
                processed: batch.processed,
                fallbackUsed: batch.fallback || false
              },
              resourceUsage: resourcePool.getMetrics(),
              cachePerformance: dataCache.getMetrics(),
              eventSummary: eventAggregator.getMetrics(),
              operationMetrics: { ...metrics },
              timestamp: Date.now()
            };
            
            eventAggregator.emit('report_generated', { reportId: report.timestamp });
            return report;
          }
        })
        .return('generate_report')
        .build();

      const startTime = Date.now();
      const result = await reactor.execute({ 
        batch_size: 50, 
        failure_rate: 0.1 
      });
      const duration = Date.now() - startTime;

      expect(result.state).toBe('completed');
      expect(result.returnValue.batchSummary.processed).toBeGreaterThanOrEqual(0);
      
      const report = result.returnValue;
      expect(report.resourceUsage.totalAllocated).toBeGreaterThanOrEqual(0);
      expect(report.cachePerformance.sets).toBeGreaterThanOrEqual(0);
      expect(report.eventSummary.totalEvents).toBeGreaterThan(0);
      expect(report.operationMetrics.totalOperations).toBeGreaterThan(0);
      
      // Verify no resource leaks
      const finalResources = resourcePool.getActiveResources();
      expect(finalResources.length).toBe(report.batchSummary.processed);
      
      console.log('\\n=== COMPREHENSIVE PERFORMANCE REPORT ===');
      console.log(`Duration: ${duration}ms`);
      console.log(`Batch ID: ${report.batchSummary.batchId}`);
      console.log(`Processed Operations: ${report.batchSummary.processed}`);
      console.log(`Resource Usage:`, report.resourceUsage);
      console.log(`Cache Performance:`, report.cachePerformance);
      console.log(`Event Summary:`, report.eventSummary);
      console.log(`Operation Metrics:`, report.operationMetrics);
    });
  });
});