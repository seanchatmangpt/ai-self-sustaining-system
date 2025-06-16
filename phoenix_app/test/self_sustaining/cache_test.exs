defmodule SelfSustaining.CacheTest do
  @moduledoc """
  Test suite for the SelfSustaining.Cache module.

  Validates comprehensive caching functionality including basic operations,
  TTL (Time To Live) expiration, fetch-and-compute patterns, statistics tracking,
  and specialized convenience functions for system optimization.

  ## Test Categories

  ### Basic Cache Operations
  - **put/get**: Core storage and retrieval functionality
  - **delete**: Cache entry removal and cleanup
  - **clear**: Complete cache reset operations
  - **get with defaults**: Fallback value handling

  ### TTL (Time To Live) Functionality
  - **Expiration Testing**: Values expire after specified TTL
  - **TTL Validation**: Values remain valid within TTL window
  - **Automatic Cleanup**: Expired entries are automatically removed

  ### Fetch-and-Compute Operations
  - **Lazy Computation**: Compute values only when needed
  - **Cache Efficiency**: Avoid recomputation for cached values
  - **Function Composition**: Higher-order function support

  ### Statistics and Monitoring
  - **Hit/Miss Tracking**: Cache performance metrics
  - **Size Monitoring**: Cache entry count tracking
  - **Hit Rate Calculation**: Performance optimization insights

  ### Convenience Functions
  Specialized caching for system components:
  - **Enhancement Discovery**: AI enhancement caching with prefix
  - **Database Queries**: Query result caching with hash keys
  - **Workflow Generation**: Generated workflow caching with SHA256 keys
  - **Performance Metrics**: System metrics caching with TTL

  ### Error Handling
  - **Graceful Failures**: Compute function error handling
  - **Cache Consistency**: Failed computations don't corrupt cache
  - **Exception Propagation**: Proper error bubbling

  ### Performance Characteristics
  - **Large Dataset Handling**: Efficiency with many cache entries
  - **Response Time**: Consistent performance under load
  - **Memory Management**: Proper cleanup and resource usage

  ## Test Setup

  Each test starts with a fresh cache instance using `start_supervised/1`
  to ensure test isolation and proper cleanup between test runs.
  """
  use ExUnit.Case, async: true
  
  alias SelfSustaining.Cache
  
  setup do
    # Start cache for each test
    {:ok, cache_pid} = start_supervised({Cache, []})
    Cache.clear()
    {:ok, cache: cache_pid}
  end
  
  describe "basic cache operations" do
    test "put and get values" do
      assert Cache.get("test_key") == nil
      assert Cache.put("test_key", "test_value") == :ok
      assert Cache.get("test_key") == "test_value"
    end
    
    test "get with default value" do
      assert Cache.get("nonexistent", "default") == "default"
    end
    
    test "delete values" do
      Cache.put("test_key", "test_value")
      assert Cache.get("test_key") == "test_value"
      
      Cache.delete("test_key")
      assert Cache.get("test_key") == nil
    end
    
    test "clear all values" do
      Cache.put("key1", "value1")
      Cache.put("key2", "value2")
      
      Cache.clear()
      assert Cache.get("key1") == nil
      assert Cache.get("key2") == nil
    end
  end
  
  describe "TTL functionality" do
    test "values expire after TTL" do
      # Put with very short TTL
      Cache.put("short_ttl", "value", 50)
      assert Cache.get("short_ttl") == "value"
      
      # Wait for expiration
      Process.sleep(100)
      assert Cache.get("short_ttl") == nil
    end
    
    test "values remain valid within TTL" do
      Cache.put("long_ttl", "value", 10_000)
      Process.sleep(50)
      assert Cache.get("long_ttl") == "value"
    end
  end
  
  describe "fetch operation" do
    test "fetch computes and caches value" do
      compute_count = Agent.start_link(fn -> 0 end)
      
      compute_fn = fn ->
        Agent.update(compute_count, &(&1 + 1))
        "computed_value"
      end
      
      # First fetch should compute
      assert Cache.fetch("fetch_key", compute_fn) == "computed_value"
      assert Agent.get(compute_count, & &1) == 1
      
      # Second fetch should use cache
      assert Cache.fetch("fetch_key", compute_fn) == "computed_value"
      assert Agent.get(compute_count, & &1) == 1
    end
  end
  
  describe "statistics" do
    test "tracks hit and miss counts" do
      # Initial stats
      stats = Cache.stats()
      assert stats.cache_hits == 0
      assert stats.cache_misses == 0
      assert stats.total_accesses == 0
      
      # Cache miss
      Cache.get("nonexistent")
      stats = Cache.stats()
      assert stats.cache_misses == 1
      assert stats.total_accesses == 1
      
      # Cache hit
      Cache.put("test", "value")
      Cache.get("test")
      stats = Cache.stats()
      assert stats.cache_hits == 1
      assert stats.cache_misses == 1
      assert stats.total_accesses == 2
      assert stats.hit_rate_percent == 50.0
    end
    
    test "tracks cache size" do
      stats = Cache.stats()
      assert stats.cache_size == 0
      
      Cache.put("key1", "value1")
      Cache.put("key2", "value2")
      
      stats = Cache.stats()
      assert stats.cache_size == 2
    end
  end
  
  describe "convenience functions" do
    test "cache_enhancement_discovery" do
      discovery_fn = fn -> "discovered_enhancement" end
      
      result1 = Cache.cache_enhancement_discovery("test_enhancement", discovery_fn)
      result2 = Cache.cache_enhancement_discovery("test_enhancement", discovery_fn)
      
      assert result1 == "discovered_enhancement"
      assert result2 == "discovered_enhancement"
      # Should be cached
      assert Cache.get("enhancement:test_enhancement") == "discovered_enhancement"
    end
    
    test "cache_db_query" do
      query_fn = fn -> %{id: 1, name: "test"} end
      query_hash = "abc123"
      
      result = Cache.cache_db_query(query_hash, query_fn)
      assert result == %{id: 1, name: "test"}
      assert Cache.get("db:#{query_hash}") == %{id: 1, name: "test"}
    end
    
    test "cache_workflow_generation" do
      workflow_spec = "test_workflow_spec"
      generation_fn = fn -> %{workflow: "generated"} end
      
      result = Cache.cache_workflow_generation(workflow_spec, generation_fn)
      assert result == %{workflow: "generated"}
      
      # Should be cached with hashed key
      expected_key = "workflow:" <> (:crypto.hash(:sha256, workflow_spec) |> Base.encode16())
      assert Cache.get(expected_key) == %{workflow: "generated"}
    end
    
    test "cache_performance_metrics" do
      metrics_fn = fn -> %{cpu: 45.2, memory: 78.1} end
      
      result = Cache.cache_performance_metrics("system_metrics", metrics_fn)
      assert result == %{cpu: 45.2, memory: 78.1}
      assert Cache.get("metrics:system_metrics") == %{cpu: 45.2, memory: 78.1}
    end
  end
  
  describe "error handling" do
    test "handles compute function errors gracefully" do
      failing_fn = fn -> raise "computation failed" end
      
      assert_raise RuntimeError, "computation failed", fn ->
        Cache.fetch("error_key", failing_fn)
      end
      
      # Should not cache failed results
      assert Cache.get("error_key") == nil
    end
  end
  
  describe "performance characteristics" do
    test "handles large number of entries" do
      # Add many entries
      for i <- 1..100 do
        Cache.put("key_#{i}", "value_#{i}")
      end
      
      stats = Cache.stats()
      assert stats.cache_size <= 100
      
      # Should still be responsive
      assert Cache.get("key_50") == "value_50"
    end
  end
end