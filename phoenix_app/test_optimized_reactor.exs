#!/usr/bin/env elixir

# Simple test for the optimized coordination reactor

Mix.install([
  {:jason, "~> 1.4"},
  {:reactor, "~> 0.15.4"}
])

Code.require_file("lib/self_sustaining/workflows/optimized_coordination_reactor.ex", __DIR__)

defmodule TestOptimizedReactor do
  def test_basic_functionality do
    IO.puts("🔧 Testing Optimized Coordination Reactor")
    IO.puts("=" |> String.duplicate(50))
    
    # Cleanup and setup
    coordination_dir = ".test_optimized"
    File.rm_rf(coordination_dir)
    
    # Create ETS table for caching
    try do
      :ets.new(:coordination_cache, [:named_table, :public, {:read_concurrency, true}])
    catch
      :error, :badarg -> :ok
    end
    
    work_claim = %{
      work_item_id: "opt_test_#{System.system_time(:nanosecond)}",
      agent_id: "opt_agent_#{System.system_time(:nanosecond)}",
      work_type: "optimization_test",
      description: "Testing optimized reactor",
      priority: "medium"
    }
    
    coordination_config = %{
      coordination_dir: coordination_dir,
      claims_file: "optimized_claims.json",
      timeout: 5000
    }
    
    IO.puts("\n🧪 Test 1: Basic Optimized Coordination")
    
    start_time = System.monotonic_time(:microsecond)
    
    case Reactor.run(
      SelfSustaining.Workflows.OptimizedCoordinationReactor,
      %{
        work_claim: work_claim,
        coordination_config: coordination_config
      },
      %{
        test_context: true,
        trace_id: "opt_test_#{System.system_time(:nanosecond)}"
      }
    ) do
      {:ok, result} ->
        duration = System.monotonic_time(:microsecond) - start_time
        IO.puts("  ✅ Optimized coordination successful")
        IO.puts("     Duration: #{Float.round(duration / 1000, 2)}ms")
        IO.puts("     Work ID: #{result.work_item_id}")
        IO.puts("     Coordination ID: #{result.coordination_id}")
        IO.puts("     Performance metadata present: #{Map.has_key?(result, :performance_metadata)}")
        
        if Map.has_key?(result, :performance_metadata) do
          meta = result.performance_metadata
          IO.puts("     Conflict check duration: #{Float.round(meta.conflict_check_duration / 1000, 2)}ms")
          IO.puts("     Claims analyzed: #{meta.claims_analyzed}")
        end
      
      {:error, reason} ->
        IO.puts("  ❌ Optimized coordination failed: #{inspect(reason)}")
    end
    
    IO.puts("\n🧪 Test 2: Cache Performance Test")
    
    # Run the same operation twice to test caching
    second_claim = %{work_claim | work_item_id: "opt_test_2_#{System.system_time(:nanosecond)}"}
    
    start_time_2 = System.monotonic_time(:microsecond)
    
    case Reactor.run(
      SelfSustaining.Workflows.OptimizedCoordinationReactor,
      %{
        work_claim: second_claim,
        coordination_config: coordination_config
      },
      %{
        test_context: true,
        trace_id: "opt_test_2_#{System.system_time(:nanosecond)}"
      }
    ) do
      {:ok, result} ->
        duration_2 = System.monotonic_time(:microsecond) - start_time_2
        IO.puts("  ✅ Second coordination successful (with potential caching)")
        IO.puts("     Duration: #{Float.round(duration_2 / 1000, 2)}ms")
        IO.puts("     Work ID: #{result.work_item_id}")
      
      {:error, reason} ->
        IO.puts("  ❌ Second coordination failed: #{inspect(reason)}")
    end
    
    # Cleanup
    File.rm_rf(coordination_dir)
    
    try do
      :ets.delete(:coordination_cache)
    catch
      :error, :badarg -> :ok
    end
    
    IO.puts("\n✅ Optimized Reactor Test Complete")
  end
end

TestOptimizedReactor.test_basic_functionality()