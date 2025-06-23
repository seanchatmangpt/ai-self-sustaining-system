/**
 * Demonstration that Nuxt Reactor supports all Elixir Reactor async patterns
 * Based on: https://hexdocs.pm/reactor/03-async-workflows.html
 */

import { describe, it, expect } from 'vitest';
import { 
  createParallelDataFetchReactor,
  createResilientWorkflowReactor,
  createHighConcurrencyIOReactor,
  createCPUIntensiveReactor
} from '../examples/async-patterns';

describe('Async Patterns Demo - Elixir Reactor Equivalent', () => {
  it('should support parallel data fetching pattern', async () => {
    const reactor = createParallelDataFetchReactor();
    const result = await reactor.execute({ user_id: '123' });

    expect(result.state).toBe('completed');
    expect(result.results.size).toBe(4); // 3 fetch + 1 aggregate
    expect(result.returnValue.user.name).toBe('John Doe');
    expect(result.returnValue.user.preferences.theme).toBe('dark');
    expect(result.returnValue.user.activity.login_count).toBe(42);
    expect(result.duration).toBeLessThan(500); // Should be faster due to parallelism
  });

  it('should support resilient workflow with compensation', async () => {
    const reactor = createResilientWorkflowReactor();
    const result = await reactor.execute({});

    expect(result.state).toBe('completed');
    expect(result.returnValue).toBeDefined();
    expect(result.returnValue.workflow_id).toBe(reactor.id);
    expect(result.returnValue.completed_at).toBeDefined();
    
    // Should handle fallbacks gracefully
    expect(['real-data', 'fallback-data']).toContain(
      result.returnValue.result.external || result.returnValue.result.processed?.toLowerCase()
    );
  });

  it('should support high concurrency I/O operations', async () => {
    const reactor = createHighConcurrencyIOReactor();
    const result = await reactor.execute({});

    expect(result.state).toBe('completed');
    expect(result.returnValue.sources_processed).toBe(5);
    expect(result.returnValue.total_records).toBeGreaterThan(500);
    expect(result.returnValue.avg_fetch_time).toBeGreaterThan(0);
    expect(result.returnValue.processing_summary).toHaveLength(5);
  });

  it('should support CPU intensive with limited concurrency', async () => {
    const reactor = createCPUIntensiveReactor();
    const result = await reactor.execute({});

    expect(result.state).toBe('completed');
    expect(result.returnValue.total_operations).toBeGreaterThan(10000);
    expect(result.returnValue.datasets_processed).toBe(10);
    expect(result.returnValue.avg_complexity).toBeGreaterThan(0);
    expect(result.returnValue.final_result).toBeDefined();
  });

  it('should demonstrate all async workflow features work together', async () => {
    // Test that we can run multiple reactor patterns simultaneously
    const promises = [
      createParallelDataFetchReactor().execute({ user_id: '1' }),
      createResilientWorkflowReactor().execute({}),
      createHighConcurrencyIOReactor().execute({}),
    ];

    const results = await Promise.all(promises);

    results.forEach(result => {
      expect(result.state).toBe('completed');
      expect(result.returnValue).toBeDefined();
    });

    // Verify parallel reactor completed first (fastest)
    expect(results[0].duration).toBeLessThan(results[2].duration);
  });
});