#!/usr/bin/env elixir

# Comprehensive API Orchestration Benchmark with Trace ID Validation

Mix.install([
  {:jason, "~> 1.4"},
  {:reactor, "~> 0.15.4"},
  {:benchee, "~> 1.3"}
])

Code.require_file("lib/self_sustaining/workflows/api_orchestration_reactor.ex", __DIR__)
Code.require_file("lib/self_sustaining/workflows/optimized_coordination_reactor.ex", __DIR__)

defmodule ApiOrchestrationBenchmark do
  @moduledoc """
  Comprehensive benchmark testing API orchestration under load with trace ID validation.
  
  Focuses on:
  1. High-concurrency trace ID consistency
  2. Performance under various load patterns
  3. Telemetry and monitoring overhead
  4. Error recovery with trace context
  5. Integration with coordination system at scale
  """

  require Logger

  def run_comprehensive_benchmark do
    IO.puts("🚀 API Orchestration Comprehensive Benchmark")
    IO.puts("=" |> String.duplicate(65))
    IO.puts("Testing trace ID propagation under various load conditions")
    
    # Setup
    setup_benchmark_environment()
    
    # Run sequential benchmarks
    run_sequential_benchmarks()
    
    # Run concurrent benchmarks  
    run_concurrent_benchmarks()
    
    # Run load testing benchmarks
    run_load_testing_benchmarks()
    
    # Run trace consistency validation
    run_trace_consistency_validation()
    
    # Cleanup
    cleanup_benchmark_environment()
    
    IO.puts("\n🏆 API Orchestration Benchmark Complete!")
  end

  defp setup_benchmark_environment do
    IO.puts("🛠️  Setting up benchmark environment...")
    
    # Create test directories
    File.mkdir_p(".bench_orchestration")
    
    # Setup ETS cache
    try do
      :ets.new(:coordination_cache, [:named_table, :public, {:read_concurrency, true}])
    catch
      :error, :badarg -> :ok
    end
    
    # Create initial coordination state with some existing work
    existing_claims = Enum.map(1..50, fn i ->
      %{
        "work_item_id" => "benchmark_existing_#{i}",
        "agent_id" => "bench_agent_#{i}",
        "work_type" => "background_processing",
        "priority" => Enum.random(["low", "medium"]),
        "status" => "in_progress",
        "claimed_at" => DateTime.utc_now() |> DateTime.to_iso8601()
      }
    end)
    
    claims_file = ".bench_orchestration/bench_claims.json"
    File.write!(claims_file, Jason.encode!(existing_claims, pretty: true))
    
    IO.puts("   ✅ Environment setup complete with #{length(existing_claims)} existing claims")
  end

  defp run_sequential_benchmarks do
    IO.puts("\n📊 Sequential Performance Benchmarks")
    IO.puts("-" |> String.duplicate(50))
    
    config = prepare_benchmark_config()
    
    Benchee.run(
      %{
        "Single API Orchestration" => fn ->
          trace_id = "seq_bench_#{System.system_time(:nanosecond)}"
          
          run_orchestration_with_trace(
            "seq_user_#{Enum.random(1..1000)}",
            "seq_resource_#{Enum.random(1..100)}",
            trace_id,
            config
          )
        end,
        
        "High Priority Orchestration" => fn ->
          trace_id = "priority_bench_#{System.system_time(:nanosecond)}"
          
          # Simulate high priority by using admin permissions
          run_orchestration_with_trace(
            "admin_user_#{Enum.random(1..10)}",
            "critical_resource_#{Enum.random(1..5)}",
            trace_id,
            config
          )
        end,
        
        "Complex Resource Orchestration" => fn ->
          trace_id = "complex_bench_#{System.system_time(:nanosecond)}"
          
          # Simulate complex resource with longer processing
          run_orchestration_with_trace(
            "complex_user_#{Enum.random(1..100)}",
            "complex_resource_#{Enum.random(1..20)}",
            trace_id,
            config
          )
        end
      },
      time: 10,
      memory_time: 3,
      formatters: [
        {Benchee.Formatters.Console, 
         comparison: true, 
         extended_statistics: true}
      ]
    )
  end

  defp run_concurrent_benchmarks do
    IO.puts("\n⚡ Concurrent Performance Benchmarks")
    IO.puts("-" |> String.duplicate(50))
    
    config = prepare_benchmark_config()
    
    concurrency_levels = [2, 5, 10, 20]
    
    for concurrency <- concurrency_levels do
      IO.puts("\n   Testing Concurrency Level: #{concurrency}")
      
      benchmark_jobs = %{
        "Concurrent #{concurrency}x Orchestration" => fn ->
          # Generate unique trace IDs for each concurrent operation
          tasks = Enum.map(1..concurrency, fn i ->
            Task.async(fn ->
              trace_id = "concurrent_#{concurrency}_#{i}_#{System.system_time(:nanosecond)}"
              
              result = run_orchestration_with_trace(
                "concurrent_user_#{i}",
                "concurrent_resource_#{i}",
                trace_id,
                config
              )
              
              # Return both result and trace ID for validation
              {trace_id, result}
            end)
          end)
          
          # Await all tasks and validate trace IDs
          results = Task.await_many(tasks, 30000)
          
          # Validate that all trace IDs are unique and properly propagated
          trace_ids = Enum.map(results, fn {trace_id, _result} -> trace_id end)
          unique_traces = Enum.uniq(trace_ids)
          
          if length(trace_ids) == length(unique_traces) do
            {:ok, :trace_consistency_validated}
          else
            {:error, :trace_id_collision}
          end
        end
      }
      
      Benchee.run(
        benchmark_jobs,
        time: 5,
        formatters: [
          {Benchee.Formatters.Console, comparison: false}
        ]
      )
    end
  end

  defp run_load_testing_benchmarks do
    IO.puts("\n🔥 Load Testing Benchmarks")
    IO.puts("-" |> String.duplicate(40))
    
    config = prepare_benchmark_config()
    
    # Test sustained load over time
    load_scenarios = [
      %{name: "Light Load", ops_per_second: 5, duration_seconds: 10},
      %{name: "Medium Load", ops_per_second: 15, duration_seconds: 8},
      %{name: "Heavy Load", ops_per_second: 30, duration_seconds: 5}
    ]
    
    for scenario <- load_scenarios do
      IO.puts("\\n   📋 Testing #{scenario.name}: #{scenario.ops_per_second} ops/sec for #{scenario.duration_seconds}s")
      
      start_time = System.monotonic_time(:millisecond)
      end_time = start_time + (scenario.duration_seconds * 1000)
      
      operation_interval = div(1000, scenario.ops_per_second)  # ms between operations
      
      # Track all trace IDs and results
      trace_results = run_sustained_load(config, end_time, operation_interval, scenario.name)
      
      # Analyze results
      successful_ops = Enum.count(trace_results, fn {_trace, result} -> 
        match?({:ok, _}, result) 
      end)
      
      total_ops = length(trace_results)
      success_rate = (successful_ops / total_ops * 100) |> Float.round(1)
      
      # Validate trace ID uniqueness
      trace_ids = Enum.map(trace_results, fn {trace_id, _} -> trace_id end)
      unique_traces = Enum.uniq(trace_ids)
      trace_consistency = length(trace_ids) == length(unique_traces)
      
      IO.puts("      Results:")
      IO.puts("      Total Operations: #{total_ops}")
      IO.puts("      Success Rate: #{success_rate}%")
      IO.puts("      Trace Consistency: #{if trace_consistency, do: "✅ PASS", else: "❌ FAIL"}")
      IO.puts("      Unique Traces: #{length(unique_traces)}/#{length(trace_ids)}")
    end
  end

  defp run_trace_consistency_validation do
    IO.puts("\\n🔍 Trace Consistency Validation Test")
    IO.puts("-" |> String.duplicate(50))
    
    config = prepare_benchmark_config()
    
    # Test 1: Rapid succession operations
    IO.puts("\\n📋 Test 1: Rapid Succession Operations")
    
    rapid_traces = Enum.map(1..20, fn i ->
      trace_id = "rapid_#{System.system_time(:nanosecond)}_#{i}"
      
      result = run_orchestration_with_trace(
        "rapid_user_#{i}",
        "rapid_resource_#{i}",
        trace_id,
        config
      )
      
      {trace_id, result}
    end)
    
    # Validate no trace ID collisions
    rapid_trace_ids = Enum.map(rapid_traces, fn {trace_id, _} -> trace_id end)
    rapid_unique = Enum.uniq(rapid_trace_ids)
    
    IO.puts("   Rapid operations: #{length(rapid_traces)}")
    IO.puts("   Unique trace IDs: #{length(rapid_unique)}")
    IO.puts("   Consistency: #{if length(rapid_traces) == length(rapid_unique), do: "✅ PASS", else: "❌ FAIL"}")
    
    # Test 2: Mixed success/failure scenarios
    IO.puts("\\n📋 Test 2: Mixed Success/Failure Scenarios")
    
    mixed_config = Map.put(config, :failure_rate, 20)  # 20% failure rate
    
    mixed_traces = Enum.map(1..15, fn i ->
      trace_id = "mixed_#{System.system_time(:nanosecond)}_#{i}"
      
      result = if Enum.random(1..100) <= 20 do
        # Simulate failure by using disabled auth
        failure_config = put_in(mixed_config[:api_config][:auth_enabled], false)
        run_orchestration_with_trace(
          "mixed_user_#{i}",
          "mixed_resource_#{i}",
          trace_id,
          failure_config
        )
      else
        run_orchestration_with_trace(
          "mixed_user_#{i}",
          "mixed_resource_#{i}",
          trace_id,
          mixed_config
        )
      end
      
      {trace_id, result}
    end)
    
    mixed_successes = Enum.count(mixed_traces, fn {_, result} -> match?({:ok, _}, result) end)
    mixed_failures = Enum.count(mixed_traces, fn {_, result} -> match?({:error, _}, result) end)
    
    IO.puts("   Mixed operations: #{length(mixed_traces)}")
    IO.puts("   Successes: #{mixed_successes}")
    IO.puts("   Failures: #{mixed_failures}")
    IO.puts("   All operations traced: #{if mixed_successes + mixed_failures == length(mixed_traces), do: "✅ PASS", else: "❌ FAIL"}")
    
    # Test 3: Validate trace propagation depth
    IO.puts("\\n📋 Test 3: Trace Propagation Depth Validation")
    
    depth_trace_id = "depth_test_#{System.system_time(:nanosecond)}"
    
    case run_orchestration_with_trace(
      "depth_test_user",
      "depth_test_resource",
      depth_trace_id,
      config
    ) do
      {:ok, result} ->
        # Check trace ID at multiple levels
        top_level_trace = result.trace_id
        coordination_trace = Map.get(result.coordination_claim, :trace_id)
        
        all_match = top_level_trace == depth_trace_id and 
                   coordination_trace == depth_trace_id
        
        IO.puts("   Orchestration trace: #{String.slice(top_level_trace, -8, 8)}")
        IO.puts("   Coordination trace: #{String.slice(coordination_trace || "none", -8, 8)}")
        IO.puts("   Expected trace: #{String.slice(depth_trace_id, -8, 8)}")
        IO.puts("   Depth consistency: #{if all_match, do: "✅ PASS", else: "❌ FAIL"}")
      
      {:error, reason} ->
        IO.puts("   Depth test failed: #{inspect(reason)}")
        IO.puts("   Depth consistency: ❌ FAIL")
    end
  end

  defp run_sustained_load(config, end_time, operation_interval, scenario_name) do
    trace_results = []
    operation_count = 0
    
    run_load_loop(config, end_time, operation_interval, scenario_name, operation_count, trace_results)
  end

  defp run_load_loop(config, end_time, operation_interval, scenario_name, operation_count, trace_results) do
    current_time = System.monotonic_time(:millisecond)
    
    if current_time >= end_time do
      trace_results
    else
      # Generate operation
      trace_id = "load_#{scenario_name}_#{operation_count}_#{System.system_time(:nanosecond)}"
      
      result = run_orchestration_with_trace(
        "load_user_#{operation_count}",
        "load_resource_#{operation_count}",
        trace_id,
        config
      )
      
      new_trace_results = [{trace_id, result} | trace_results]
      
      # Wait for next operation
      :timer.sleep(operation_interval)
      
      run_load_loop(config, end_time, operation_interval, scenario_name, operation_count + 1, new_trace_results)
    end
  end

  defp run_orchestration_with_trace(user_id, resource_id, trace_id, config) do
    try do
      Reactor.run(
        SelfSustaining.Workflows.ApiOrchestrationReactor,
        %{
          user_id: user_id,
          resource_id: resource_id,
          coordination_config: config[:coordination_config],
          api_config: config[:api_config]
        },
        %{
          trace_id: trace_id,
          benchmark_context: true,
          execution_mode: "benchmark"
        }
      )
    rescue
      error -> {:error, error}
    end
  end

  defp prepare_benchmark_config do
    %{
      coordination_config: %{
        coordination_dir: ".bench_orchestration",
        claims_file: "bench_claims.json",
        timeout: 10000
      },
      api_config: %{
        auth_enabled: true,
        api_timeout: 8000,
        retry_attempts: 2
      }
    }
  end

  defp cleanup_benchmark_environment do
    File.rm_rf(".bench_orchestration")
    
    try do
      :ets.delete(:coordination_cache)
    catch
      :error, :badarg -> :ok
    end
    
    IO.puts("🧹 Benchmark environment cleaned up")
  end
end

# Run the comprehensive benchmark
ApiOrchestrationBenchmark.run_comprehensive_benchmark()