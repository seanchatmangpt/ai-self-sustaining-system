#!/usr/bin/env elixir

# Performance benchmark comparing standard vs optimized coordination reactors

Mix.install([
  {:jason, "~> 1.4"},
  {:reactor, "~> 0.15.4"},
  {:benchee, "~> 1.3"}
])

# Load both coordination reactors
Code.require_file("lib/self_sustaining/workflows/coordination_reactor.ex", __DIR__)
Code.require_file("lib/self_sustaining/workflows/optimized_coordination_reactor.ex", __DIR__)

defmodule CoordinationPerformanceBenchmark do
  @moduledoc """
  Performance benchmark comparing standard vs optimized coordination reactors.
  Tests the impact of async steps, caching, and other optimizations.
  """

  def run_performance_benchmark do
    IO.puts("🚀 Coordination Reactor Performance Benchmark")
    IO.puts("=" |> String.duplicate(60))
    
    # Setup test environment
    setup_test_environment()
    
    # Prepare test data sets
    test_scenarios = [
      %{name: "Single Claim", claims_count: 1, work_items: 1},
      %{name: "Small Load", claims_count: 10, work_items: 5},
      %{name: "Medium Load", claims_count: 50, work_items: 20},
      %{name: "Large Load", claims_count: 200, work_items: 50}
    ]
    
    # Run benchmarks for each scenario
    for scenario <- test_scenarios do
      IO.puts("\n📊 Testing Scenario: #{scenario.name}")
      IO.puts("   Existing Claims: #{scenario.claims_count}")
      IO.puts("   New Work Items: #{scenario.work_items}")
      
      run_scenario_benchmark(scenario)
    end
    
    # Cleanup
    cleanup_test_environment()
    
    IO.puts("\n🏆 Performance Benchmark Complete")
  end

  defp setup_test_environment do
    # Create test directories
    File.mkdir_p(".bench_standard")
    File.mkdir_p(".bench_optimized")
    
    # Initialize ETS table for optimized reactor caching
    try do
      :ets.new(:coordination_cache, [:named_table, :public, {:read_concurrency, true}])
    catch
      :error, :badarg -> :ok  # Table already exists
    end
  end

  defp cleanup_test_environment do
    File.rm_rf(".bench_standard")
    File.rm_rf(".bench_optimized")
    
    try do
      :ets.delete(:coordination_cache)
    catch
      :error, :badarg -> :ok
    end
  end

  defp run_scenario_benchmark(scenario) do
    # Prepare test data
    {standard_config, optimized_config, work_items} = prepare_test_data(scenario)
    
    # Define benchmark jobs
    benchmark_jobs = %{
      "Standard Reactor" => fn ->
        work_item = Enum.random(work_items)
        run_coordination_reactor(
          SelfSustaining.Workflows.CoordinationReactor,
          work_item,
          standard_config
        )
      end,
      
      "Optimized Reactor" => fn ->
        work_item = Enum.random(work_items)
        run_coordination_reactor(
          SelfSustaining.Workflows.OptimizedCoordinationReactor,
          work_item,
          optimized_config
        )
      end,
      
      "Optimized Reactor (Cached)" => fn ->
        work_item = Enum.random(work_items)
        # Run twice to test cache effectiveness
        run_coordination_reactor(
          SelfSustaining.Workflows.OptimizedCoordinationReactor,
          work_item,
          optimized_config
        )
        run_coordination_reactor(
          SelfSustaining.Workflows.OptimizedCoordinationReactor,
          work_item,
          optimized_config
        )
      end
    }
    
    # Run benchmark
    Benchee.run(
      benchmark_jobs,
      time: 3,
      memory_time: 1,
      formatters: [
        {Benchee.Formatters.Console, 
         comparison: true, 
         extended_statistics: true}
      ]
    )
  end

  defp prepare_test_data(scenario) do
    # Generate existing claims for both reactors
    existing_claims = Enum.map(1..scenario.claims_count, fn i ->
      %{
        "work_item_id" => "existing_#{i}",
        "agent_id" => "agent_#{i}",
        "work_type" => "background_work",
        "priority" => Enum.random(["low", "medium"]),
        "status" => "in_progress",
        "claimed_at" => DateTime.utc_now() |> DateTime.to_iso8601()
      }
    end)
    
    # Setup standard reactor claims file
    standard_config = %{
      coordination_dir: ".bench_standard",
      claims_file: "claims.json",
      timeout: 5000
    }
    
    standard_file = Path.join(standard_config.coordination_dir, standard_config.claims_file)
    File.write!(standard_file, Jason.encode!(existing_claims, pretty: true))
    
    # Setup optimized reactor claims file
    optimized_config = %{
      coordination_dir: ".bench_optimized", 
      claims_file: "claims.json",
      timeout: 5000
    }
    
    optimized_file = Path.join(optimized_config.coordination_dir, optimized_config.claims_file)
    File.write!(optimized_file, Jason.encode!(existing_claims, pretty: true))
    
    # Generate work items to test
    work_items = Enum.map(1..scenario.work_items, fn i ->
      %{
        work_item_id: "bench_work_#{i}_#{System.system_time(:nanosecond)}",
        agent_id: "bench_agent_#{i}_#{System.system_time(:nanosecond)}",
        work_type: Enum.random(["performance_test", "benchmark_work", "load_test"]),
        description: "Benchmark work item #{i}",
        priority: Enum.random(["low", "medium", "high"])
      }
    end)
    
    {standard_config, optimized_config, work_items}
  end

  defp run_coordination_reactor(reactor_module, work_claim, coordination_config) do
    try do
      case Reactor.run(
        reactor_module,
        %{
          work_claim: work_claim,
          coordination_config: coordination_config
        },
        %{
          benchmark_context: true,
          trace_id: "bench_#{System.system_time(:nanosecond)}"
        }
      ) do
        {:ok, _result} -> :success
        {:error, _reason} -> :error
      end
    rescue
      _error -> :exception
    end
  end

  def run_memory_benchmark do
    IO.puts("\n🧠 Memory Usage Benchmark")
    IO.puts("=" |> String.duplicate(40))
    
    # Test memory usage with large claim files
    large_claims = Enum.map(1..1000, fn i ->
      %{
        "work_item_id" => "large_#{i}",
        "agent_id" => "agent_#{i}",
        "work_type" => "memory_test",
        "priority" => "medium",
        "status" => "in_progress",
        "claimed_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
        "metadata" => %{
          "large_data" => String.duplicate("x", 1000)  # 1KB per claim
        }
      }
    end)
    
    # Setup test files
    File.mkdir_p(".memory_test")
    claims_file = ".memory_test/large_claims.json"
    File.write!(claims_file, Jason.encode!(large_claims, pretty: true))
    
    config = %{
      coordination_dir: ".memory_test",
      claims_file: "large_claims.json",
      timeout: 10000
    }
    
    work_claim = %{
      work_item_id: "memory_test_#{System.system_time(:nanosecond)}",
      agent_id: "memory_agent_#{System.system_time(:nanosecond)}",
      work_type: "memory_benchmark",
      description: "Memory usage test",
      priority: "low"
    }
    
    # Benchmark memory usage
    Benchee.run(
      %{
        "Standard Reactor Memory" => fn ->
          run_coordination_reactor(
            SelfSustaining.Workflows.CoordinationReactor,
            work_claim,
            config
          )
        end,
        
        "Optimized Reactor Memory" => fn ->
          run_coordination_reactor(
            SelfSustaining.Workflows.OptimizedCoordinationReactor,
            work_claim,
            config
          )
        end
      },
      time: 2,
      memory_time: 2,
      formatters: [
        {Benchee.Formatters.Console, 
         comparison: true, 
         extended_statistics: true}
      ]
    )
    
    # Cleanup
    File.rm_rf(".memory_test")
  end

  def run_concurrent_benchmark do
    IO.puts("\n⚡ Concurrent Execution Benchmark")
    IO.puts("=" |> String.duplicate(40))
    
    setup_test_environment()
    
    # Prepare shared claims file
    shared_claims = Enum.map(1..20, fn i ->
      %{
        "work_item_id" => "shared_#{i}",
        "agent_id" => "agent_#{i}",
        "work_type" => "shared_work",
        "priority" => "medium",
        "status" => "in_progress",
        "claimed_at" => DateTime.utc_now() |> DateTime.to_iso8601()
      }
    end)
    
    standard_file = ".bench_standard/claims.json"
    optimized_file = ".bench_optimized/claims.json"
    
    File.write!(standard_file, Jason.encode!(shared_claims, pretty: true))
    File.write!(optimized_file, Jason.encode!(shared_claims, pretty: true))
    
    # Test concurrent performance
    concurrency_levels = [1, 2, 5, 10]
    
    for concurrency <- concurrency_levels do
      IO.puts("\n   Testing Concurrency Level: #{concurrency}")
      
      Benchee.run(
        %{
          "Standard #{concurrency}x" => fn ->
            tasks = Enum.map(1..concurrency, fn i ->
              Task.async(fn ->
                work_claim = %{
                  work_item_id: "concurrent_#{i}_#{System.system_time(:nanosecond)}",
                  agent_id: "concurrent_agent_#{i}",
                  work_type: "concurrent_test",
                  description: "Concurrent test #{i}",
                  priority: "low"
                }
                
                run_coordination_reactor(
                  SelfSustaining.Workflows.CoordinationReactor,
                  work_claim,
                  %{coordination_dir: ".bench_standard", claims_file: "claims.json", timeout: 5000}
                )
              end)
            end)
            
            Task.await_many(tasks, 10000)
          end,
          
          "Optimized #{concurrency}x" => fn ->
            tasks = Enum.map(1..concurrency, fn i ->
              Task.async(fn ->
                work_claim = %{
                  work_item_id: "concurrent_opt_#{i}_#{System.system_time(:nanosecond)}",
                  agent_id: "concurrent_opt_agent_#{i}",
                  work_type: "concurrent_test",
                  description: "Concurrent optimized test #{i}",
                  priority: "low"
                }
                
                run_coordination_reactor(
                  SelfSustaining.Workflows.OptimizedCoordinationReactor,
                  work_claim,
                  %{coordination_dir: ".bench_optimized", claims_file: "claims.json", timeout: 5000}
                )
              end)
            end)
            
            Task.await_many(tasks, 10000)
          end
        },
        time: 2,
        formatters: [
          {Benchee.Formatters.Console, comparison: true}
        ]
      )
    end
    
    cleanup_test_environment()
  end
end

# Run all benchmarks
IO.puts("Starting Coordination Reactor Performance Analysis...")

CoordinationPerformanceBenchmark.run_performance_benchmark()
CoordinationPerformanceBenchmark.run_memory_benchmark()
CoordinationPerformanceBenchmark.run_concurrent_benchmark()

IO.puts("\n🎉 All performance benchmarks completed!")