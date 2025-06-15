#!/usr/bin/env elixir

# Performance comparison demo between standard and optimized coordination reactors

Mix.install([
  {:jason, "~> 1.4"},
  {:reactor, "~> 0.15.4"}
])

Code.require_file("lib/self_sustaining/workflows/coordination_reactor.ex", __DIR__)
Code.require_file("lib/self_sustaining/workflows/optimized_coordination_reactor.ex", __DIR__)

defmodule PerformanceComparisonDemo do
  @moduledoc """
  Side-by-side performance comparison of standard vs optimized coordination reactors.
  Demonstrates the real-world performance improvements achieved.
  """

  def run_comparison_demo do
    IO.puts("🏆 Coordination Reactor Performance Comparison Demo")
    IO.puts("=" |> String.duplicate(65))
    
    # Setup
    setup_demo_environment()
    
    # Create test data
    {standard_config, optimized_config, test_claims} = prepare_demo_data()
    
    IO.puts("\n📊 Test Configuration:")
    IO.puts("  • Test Claims Count: #{length(test_claims)}")
    IO.puts("  • Iterations per reactor: 5")
    IO.puts("  • Measuring: Execution time, memory, success rate")
    
    # Run standard reactor tests
    IO.puts("\n🔧 Testing Standard CoordinationReactor...")
    standard_results = run_reactor_tests(
      SelfSustaining.Workflows.CoordinationReactor,
      standard_config,
      test_claims,
      5
    )
    
    # Run optimized reactor tests  
    IO.puts("\n⚡ Testing Optimized CoordinationReactor...")
    optimized_results = run_reactor_tests(
      SelfSustaining.Workflows.OptimizedCoordinationReactor,
      optimized_config,
      test_claims,
      5
    )
    
    # Generate comparison report
    generate_comparison_report(standard_results, optimized_results)
    
    # Cleanup
    cleanup_demo_environment()
    
    IO.puts("\n🎯 Performance Comparison Complete!")
  end

  defp setup_demo_environment do
    # Create test directories
    File.mkdir_p(".demo_standard")
    File.mkdir_p(".demo_optimized")
    
    # Initialize ETS cache for optimized reactor
    try do
      :ets.new(:coordination_cache, [:named_table, :public, {:read_concurrency, true}])
    catch
      :error, :badarg -> :ok
    end
  end

  defp cleanup_demo_environment do
    File.rm_rf(".demo_standard")
    File.rm_rf(".demo_optimized") 
    
    try do
      :ets.delete(:coordination_cache)
    catch
      :error, :badarg -> :ok
    end
  end

  defp prepare_demo_data do
    # Create existing claims to simulate real-world load
    existing_claims = Enum.map(1..25, fn i ->
      %{
        "work_item_id" => "demo_existing_#{i}",
        "agent_id" => "demo_agent_#{i}",
        "work_type" => "background_processing",
        "priority" => Enum.random(["low", "medium"]),
        "status" => "in_progress",
        "claimed_at" => DateTime.utc_now() |> DateTime.to_iso8601()
      }
    end)
    
    # Setup configurations
    standard_config = %{
      coordination_dir: ".demo_standard",
      claims_file: "demo_claims.json",
      timeout: 5000
    }
    
    optimized_config = %{
      coordination_dir: ".demo_optimized",
      claims_file: "demo_claims.json", 
      timeout: 5000
    }
    
    # Write existing claims to both files
    standard_file = Path.join(standard_config.coordination_dir, standard_config.claims_file)
    optimized_file = Path.join(optimized_config.coordination_dir, optimized_config.claims_file)
    
    encoded_claims = Jason.encode!(existing_claims, pretty: true)
    File.write!(standard_file, encoded_claims)
    File.write!(optimized_file, encoded_claims)
    
    # Generate test work claims
    test_claims = Enum.map(1..5, fn i ->
      %{
        work_item_id: "demo_work_#{i}_#{System.system_time(:nanosecond)}",
        agent_id: "demo_test_agent_#{i}_#{System.system_time(:nanosecond)}",
        work_type: "performance_demo",
        description: "Performance comparison test #{i}",
        priority: "medium"
      }
    end)
    
    {standard_config, optimized_config, test_claims}
  end

  defp run_reactor_tests(reactor_module, config, test_claims, iterations) do
    reactor_name = reactor_module |> Module.split() |> List.last()
    
    results = Enum.map(1..iterations, fn iteration ->
      test_claim = Enum.at(test_claims, rem(iteration - 1, length(test_claims)))
      
      # Add unique identifier to avoid conflicts
      unique_claim = Map.put(test_claim, :work_item_id, 
        "#{test_claim.work_item_id}_iter_#{iteration}")
      
      # Measure execution
      memory_before = :erlang.memory(:total)
      start_time = System.monotonic_time(:microsecond)
      
      result = try do
        case Reactor.run(
          reactor_module,
          %{
            work_claim: unique_claim,
            coordination_config: config
          },
          %{
            demo_context: true,
            iteration: iteration,
            trace_id: "demo_#{iteration}_#{System.system_time(:nanosecond)}"
          }
        ) do
          {:ok, claim_result} -> {:success, claim_result}
          {:error, reason} -> {:error, reason}
        end
      rescue
        error -> {:exception, error}
      end
      
      end_time = System.monotonic_time(:microsecond)
      memory_after = :erlang.memory(:total)
      
      execution_time = end_time - start_time
      memory_used = memory_after - memory_before
      
      IO.puts("    Iteration #{iteration}: #{Float.round(execution_time / 1000, 2)}ms")
      
      %{
        iteration: iteration,
        execution_time_us: execution_time,
        execution_time_ms: execution_time / 1000,
        memory_used_bytes: memory_used,
        result: result,
        success: match?({:success, _}, result)
      }
    end)
    
    # Calculate statistics
    execution_times = Enum.map(results, & &1.execution_time_us)
    memory_usages = Enum.map(results, & &1.memory_used_bytes)
    success_count = Enum.count(results, & &1.success)
    
    %{
      reactor_name: reactor_name,
      reactor_module: reactor_module,
      iterations: iterations,
      results: results,
      statistics: %{
        avg_execution_time_ms: Enum.sum(execution_times) / length(execution_times) / 1000,
        min_execution_time_ms: Enum.min(execution_times) / 1000,
        max_execution_time_ms: Enum.max(execution_times) / 1000,
        avg_memory_used_kb: Enum.sum(memory_usages) / length(memory_usages) / 1024,
        success_rate: success_count / iterations * 100
      }
    }
  end

  defp generate_comparison_report(standard_results, optimized_results) do
    IO.puts("\n" <> "=" |> String.duplicate(65))
    IO.puts("📈 PERFORMANCE COMPARISON REPORT")
    IO.puts("=" |> String.duplicate(65))
    
    # Performance metrics comparison
    std_stats = standard_results.statistics
    opt_stats = optimized_results.statistics
    
    IO.puts("\n⏱️  Execution Time Comparison:")
    IO.puts("                                Standard    Optimized    Improvement")
    IO.puts("  Average Execution Time:       #{format_time(std_stats.avg_execution_time_ms)}ms      #{format_time(opt_stats.avg_execution_time_ms)}ms      #{format_improvement(std_stats.avg_execution_time_ms, opt_stats.avg_execution_time_ms)}")
    IO.puts("  Minimum Execution Time:       #{format_time(std_stats.min_execution_time_ms)}ms      #{format_time(opt_stats.min_execution_time_ms)}ms      #{format_improvement(std_stats.min_execution_time_ms, opt_stats.min_execution_time_ms)}")
    IO.puts("  Maximum Execution Time:       #{format_time(std_stats.max_execution_time_ms)}ms      #{format_time(opt_stats.max_execution_time_ms)}ms      #{format_improvement(std_stats.max_execution_time_ms, opt_stats.max_execution_time_ms)}")
    
    IO.puts("\n💾 Memory Usage Comparison:")
    IO.puts("                                Standard    Optimized    Improvement")
    IO.puts("  Average Memory Used:          #{format_memory(std_stats.avg_memory_used_kb)}KB      #{format_memory(opt_stats.avg_memory_used_kb)}KB      #{format_memory_improvement(std_stats.avg_memory_used_kb, opt_stats.avg_memory_used_kb)}")
    
    IO.puts("\n✅ Success Rate Comparison:")
    IO.puts("                                Standard    Optimized")
    IO.puts("  Success Rate:                 #{Float.round(std_stats.success_rate, 1)}%        #{Float.round(opt_stats.success_rate, 1)}%")
    
    # Performance gains summary
    speed_improvement = calculate_speed_improvement(std_stats.avg_execution_time_ms, opt_stats.avg_execution_time_ms)
    memory_improvement = calculate_memory_improvement(std_stats.avg_memory_used_kb, opt_stats.avg_memory_used_kb)
    
    IO.puts("\n🚀 Overall Performance Gains:")
    IO.puts("  • Speed Improvement: #{speed_improvement}")
    IO.puts("  • Memory Efficiency: #{memory_improvement}")
    IO.puts("  • Caching Benefits: #{analyze_caching_benefits(optimized_results)}")
    IO.puts("  • Async Step Benefits: Enabled parallel execution")
    
    # Detailed timing analysis
    IO.puts("\n📊 Detailed Execution Times:")
    IO.puts("  Standard Reactor Iterations:")
    for result <- standard_results.results do
      IO.puts("    #{result.iteration}: #{Float.round(result.execution_time_ms, 2)}ms #{if result.success, do: "✅", else: "❌"}")
    end
    
    IO.puts("  Optimized Reactor Iterations:")
    for result <- optimized_results.results do
      IO.puts("    #{result.iteration}: #{Float.round(result.execution_time_ms, 2)}ms #{if result.success, do: "✅", else: "❌"}")
    end
    
    # Recommendations
    IO.puts("\n💡 Performance Recommendations:")
    if opt_stats.avg_execution_time_ms < std_stats.avg_execution_time_ms do
      improvement_pct = Float.round((std_stats.avg_execution_time_ms - opt_stats.avg_execution_time_ms) / std_stats.avg_execution_time_ms * 100, 1)
      IO.puts("  ✅ Use OptimizedCoordinationReactor for #{improvement_pct}% better performance")
    end
    
    if opt_stats.avg_memory_used_kb < std_stats.avg_memory_used_kb do
      IO.puts("  ✅ Optimized reactor uses less memory - better for high-concurrency scenarios")
    end
    
    IO.puts("  ✅ Enable caching for repeated operations")
    IO.puts("  ✅ Use async steps for I/O-bound coordination tasks")
  end

  defp format_time(time_ms) do
    Float.round(time_ms, 2) |> to_string() |> String.pad_leading(8)
  end

  defp format_memory(memory_kb) do
    Float.round(memory_kb, 1) |> to_string() |> String.pad_leading(8)
  end

  defp format_improvement(old_value, new_value) when old_value > 0 do
    improvement = (old_value - new_value) / old_value * 100
    if improvement > 0 do
      "#{Float.round(improvement, 1)}% faster"
    else
      "#{Float.round(abs(improvement), 1)}% slower"
    end
  end
  defp format_improvement(_, _), do: "N/A"

  defp format_memory_improvement(old_kb, new_kb) when old_kb > 0 do
    improvement = (old_kb - new_kb) / old_kb * 100
    if improvement > 0 do
      "#{Float.round(improvement, 1)}% less"
    else
      "#{Float.round(abs(improvement), 1)}% more"
    end
  end
  defp format_memory_improvement(_, _), do: "N/A"

  defp calculate_speed_improvement(old_ms, new_ms) when old_ms > 0 do
    speedup = old_ms / new_ms
    "#{Float.round(speedup, 1)}x faster"
  end
  defp calculate_speed_improvement(_, _), do: "N/A"

  defp calculate_memory_improvement(old_kb, new_kb) when old_kb > 0 do
    if new_kb < old_kb do
      reduction = (old_kb - new_kb) / old_kb * 100
      "#{Float.round(reduction, 1)}% reduction"
    else
      increase = (new_kb - old_kb) / old_kb * 100
      "#{Float.round(increase, 1)}% increase"
    end
  end
  defp calculate_memory_improvement(_, _), do: "No change"

  defp analyze_caching_benefits(optimized_results) do
    execution_times = Enum.map(optimized_results.results, & &1.execution_time_ms)
    
    if length(execution_times) >= 2 do
      first_time = List.first(execution_times)
      subsequent_times = Enum.drop(execution_times, 1)
      avg_subsequent = Enum.sum(subsequent_times) / length(subsequent_times)
      
      if first_time > avg_subsequent do
        improvement = (first_time - avg_subsequent) / first_time * 100
        "#{Float.round(improvement, 1)}% faster on cached operations"
      else
        "Minimal caching benefit observed"
      end
    else
      "Insufficient data"
    end
  end
end

# Run the comparison demo
PerformanceComparisonDemo.run_comparison_demo()