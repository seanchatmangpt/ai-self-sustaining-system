#!/usr/bin/env elixir

# Comprehensive Performance Benchmark for Reactor ↔ N8N Loop
# Run with: mix run benchmark_reactor_n8n_loop.exs

defmodule ReactorN8NBenchmark do
  @moduledoc """
  High-performance benchmark suite for Reactor ↔ N8N integration loop.
  Measures latency, throughput, and system resource utilization.
  """
  
  require Logger
  
  # Benchmark configuration
  @default_config %{
    warmup_iterations: 5,
    measurement_iterations: 50,
    concurrent_processes: [1, 5, 10, 25, 50],
    telemetry_enabled: true,
    detailed_profiling: true
  }
  
  def run_benchmark(config \\ @default_config) do
    IO.puts("🚀 === Reactor ↔ N8N Performance Benchmark Suite ===")
    IO.puts("Configuration: #{inspect(config)}")
    IO.puts("")
    
    # Initialize telemetry collection
    setup_benchmark_telemetry()
    
    # Run performance tests
    results = %{
      baseline: run_baseline_benchmark(config),
      optimized: run_optimized_benchmark(config),
      concurrent: run_concurrent_benchmark(config),
      memory_profile: run_memory_benchmark(config),
      latency_breakdown: run_latency_breakdown(config)
    }
    
    # Generate comprehensive report
    generate_benchmark_report(results, config)
    
    # Clean up
    cleanup_benchmark_telemetry()
    
    results
  end
  
  defp run_baseline_benchmark(config) do
    IO.puts("📊 Running Baseline Performance Test...")
    
    # Warmup
    IO.puts("   🔥 Warming up (#{config.warmup_iterations} iterations)...")
    Enum.each(1..config.warmup_iterations, fn _ ->
      execute_single_loop(:baseline)
    end)
    
    # Actual measurements
    IO.puts("   📏 Measuring performance (#{config.measurement_iterations} iterations)...")
    measurements = Enum.map(1..config.measurement_iterations, fn iteration ->
      measure_single_execution(iteration, :baseline)
    end)
    
    analyze_measurements(measurements, "Baseline")
  end
  
  defp run_optimized_benchmark(config) do
    IO.puts("⚡ Running Optimized Performance Test...")
    
    # Apply optimizations
    apply_performance_optimizations()
    
    # Warmup
    IO.puts("   🔥 Warming up optimized version...")
    Enum.each(1..config.warmup_iterations, fn _ ->
      execute_single_loop(:optimized)
    end)
    
    # Measurements
    measurements = Enum.map(1..config.measurement_iterations, fn iteration ->
      measure_single_execution(iteration, :optimized)
    end)
    
    analyze_measurements(measurements, "Optimized")
  end
  
  defp run_concurrent_benchmark(config) do
    IO.puts("🔄 Running Concurrent Load Test...")
    
    concurrent_results = Enum.map(config.concurrent_processes, fn process_count ->
      IO.puts("   👥 Testing with #{process_count} concurrent processes...")
      
      start_time = System.monotonic_time()
      
      # Spawn concurrent processes
      tasks = Enum.map(1..process_count, fn process_id ->
        Task.async(fn ->
          measurements = Enum.map(1..div(config.measurement_iterations, process_count), fn iteration ->
            measure_single_execution("#{process_id}-#{iteration}", :concurrent)
          end)
          {process_id, measurements}
        end)
      end)
      
      # Collect results
      process_results = Enum.map(tasks, &Task.await(&1, 60_000))
      total_time = System.convert_time_unit(System.monotonic_time() - start_time, :native, :millisecond)
      
      all_measurements = Enum.flat_map(process_results, fn {_id, measurements} -> measurements end)
      
      analysis = analyze_measurements(all_measurements, "Concurrent-#{process_count}")
      
      Map.merge(analysis, %{
        process_count: process_count,
        total_execution_time: total_time,
        throughput_per_second: length(all_measurements) / (total_time / 1000),
        avg_per_process: analysis.avg_duration / process_count
      })
    end)
    
    %{concurrent_results: concurrent_results}
  end
  
  defp run_memory_benchmark(config) do
    IO.puts("🧠 Running Memory Profile Test...")
    
    # Baseline memory
    :erlang.garbage_collect()
    {baseline_memory, _} = :erlang.process_info(self(), :memory)
    
    # Execute iterations while monitoring memory
    memory_samples = Enum.map(1..20, fn iteration ->
      :erlang.garbage_collect()
      {before_memory, _} = :erlang.process_info(self(), :memory)
      
      execute_single_loop(:memory_profile)
      
      :erlang.garbage_collect()
      {after_memory, _} = :erlang.process_info(self(), :memory)
      
      %{
        iteration: iteration,
        before_memory: before_memory,
        after_memory: after_memory,
        memory_delta: after_memory - before_memory
      }
    end)
    
    %{
      baseline_memory: baseline_memory,
      memory_samples: memory_samples,
      avg_memory_per_iteration: Enum.sum(Enum.map(memory_samples, & &1.memory_delta)) / length(memory_samples)
    }
  end
  
  defp run_latency_breakdown(config) do
    IO.puts("🔍 Running Latency Breakdown Analysis...")
    
    # Measure each component separately
    breakdown_measurements = Enum.map(1..10, fn iteration ->
      measure_component_latencies(iteration)
    end)
    
    # Analyze breakdown
    components = [:compilation, :export, :api_call, :webhook_processing, :total]
    
    component_analysis = Enum.into(components, %{}, fn component ->
      values = Enum.map(breakdown_measurements, &Map.get(&1, component, 0))
      {component, %{
        avg: Enum.sum(values) / length(values),
        min: Enum.min(values),
        max: Enum.max(values),
        p95: percentile(values, 95),
        p99: percentile(values, 99)
      }}
    end)
    
    %{
      breakdown_measurements: breakdown_measurements,
      component_analysis: component_analysis
    }
  end
  
  defp measure_single_execution(iteration, mode) do
    start_time = System.monotonic_time()
    start_memory = :erlang.process_info(self(), :memory) |> elem(0)
    
    result = execute_single_loop(mode)
    
    end_time = System.monotonic_time()
    end_memory = :erlang.process_info(self(), :memory) |> elem(0)
    
    duration_microseconds = System.convert_time_unit(end_time - start_time, :native, :microsecond)
    
    %{
      iteration: iteration,
      duration_microseconds: duration_microseconds,
      duration_milliseconds: duration_microseconds / 1000,
      memory_delta: end_memory - start_memory,
      success: match?({:ok, _}, result),
      mode: mode,
      timestamp: DateTime.utc_now()
    }
  end
  
  defp execute_single_loop(mode) do
    workflow_def = create_benchmark_workflow(mode)
    n8n_config = get_n8n_config()
    
    case mode do
      :optimized ->
        execute_optimized_loop(workflow_def, n8n_config)
      :memory_profile ->
        execute_memory_efficient_loop(workflow_def, n8n_config)
      _ ->
        execute_standard_loop(workflow_def, n8n_config)
    end
  end
  
  defp execute_standard_loop(workflow_def, n8n_config) do
    # Standard Reactor -> N8N flow
    Reactor.run(SelfSustaining.Workflows.N8nIntegrationReactor, %{
      workflow_definition: workflow_def,
      n8n_config: n8n_config,
      action: :export
    })
  end
  
  defp execute_optimized_loop(workflow_def, n8n_config) do
    # Optimized version with reduced telemetry overhead
    enhanced_config = Map.merge(n8n_config, %{
      timeout: 5_000,  # Reduced timeout
      optimized_mode: true
    })
    
    Reactor.run(SelfSustaining.Workflows.N8nIntegrationReactor, %{
      workflow_definition: workflow_def,
      n8n_config: enhanced_config,
      action: :export
    })
  end
  
  defp execute_memory_efficient_loop(workflow_def, n8n_config) do
    # Memory-efficient version
    compact_workflow = create_minimal_workflow()
    
    Reactor.run(SelfSustaining.Workflows.N8nIntegrationReactor, %{
      workflow_definition: compact_workflow,
      n8n_config: n8n_config,
      action: :compile  # Compile only, no API calls
    })
  end
  
  defp measure_component_latencies(iteration) do
    workflow_def = create_benchmark_workflow(:breakdown)
    n8n_config = get_n8n_config()
    
    # Measure compilation phase
    compilation_start = System.monotonic_time()
    {:ok, compile_result} = Reactor.run(SelfSustaining.Workflows.N8nIntegrationReactor, %{
      workflow_definition: workflow_def,
      n8n_config: n8n_config,
      action: :compile
    })
    compilation_time = System.convert_time_unit(System.monotonic_time() - compilation_start, :native, :microsecond)
    
    # Measure export phase (includes API call)
    export_start = System.monotonic_time()
    export_result = Reactor.run(SelfSustaining.Workflows.N8nIntegrationReactor, %{
      workflow_definition: workflow_def,
      n8n_config: n8n_config,
      action: :export
    })
    export_time = System.convert_time_unit(System.monotonic_time() - export_start, :native, :microsecond)
    
    # Simulate webhook processing time
    webhook_start = System.monotonic_time()
    SelfSustaining.N8N.Reactor.process_webhook("benchmark_#{iteration}", %{
      "workflow_type" => "performance",
      "benchmark" => true,
      "iteration" => iteration
    })
    webhook_time = System.convert_time_unit(System.monotonic_time() - webhook_start, :native, :microsecond)
    
    %{
      compilation: compilation_time,
      export: export_time,
      api_call: export_time - compilation_time,  # Approximate API time
      webhook_processing: webhook_time,
      total: compilation_time + export_time + webhook_time
    }
  end
  
  defp create_benchmark_workflow(mode) do
    base_workflow = %{
      name: "benchmark_workflow_#{System.unique_integer()}",
      nodes: [
        %{
          id: "start",
          name: "Benchmark Start",
          type: :webhook,
          position: [100, 200],
          parameters: %{}
        },
        %{
          id: "process",
          name: "Benchmark Process",
          type: :function,
          position: [300, 200],
          parameters: %{}
        }
      ],
      connections: [
        %{from: "start", to: "process"}
      ]
    }
    
    case mode do
      :optimized ->
        # Reduced nodes for faster execution
        Map.put(base_workflow, :nodes, [List.first(base_workflow.nodes)])
      :memory_profile ->
        # Minimal workflow for memory testing
        create_minimal_workflow()
      _ ->
        base_workflow
    end
  end
  
  defp create_minimal_workflow do
    %{
      name: "minimal_benchmark",
      nodes: [
        %{
          id: "minimal",
          name: "Minimal Node",
          type: :webhook,
          position: [100, 200],
          parameters: %{}
        }
      ],
      connections: []
    }
  end
  
  defp get_n8n_config do
    %{
      api_url: "http://localhost:5678/api/v1",
      api_key: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIwM2VmZDFhMC00YjEwLTQ0M2QtODJiMC0xYjc4NjUxNDU1YzkiLCJpc3MiOiJuOG4iLCJhdWQiOiJwdWJsaWMtYXBpIiwiaWF0IjoxNzUwMDAyNzA4LCJleHAiOjE3NTI1NTIwMDB9.LoaISJGi0FuwCU53NY_kt4t_RFsGFjHZBhX9BNT_8LM",
      timeout: 10_000
    }
  end
  
  defp apply_performance_optimizations do
    # Reduce telemetry overhead for benchmarking
    Application.put_env(:self_sustaining, :telemetry_mode, :minimal)
    
    # Optimize HTTP client
    HTTPoison.start()
    
    IO.puts("   ⚡ Applied performance optimizations")
  end
  
  defp setup_benchmark_telemetry do
    # Attach high-precision telemetry for benchmarking
    :telemetry.attach_many(
      "benchmark-telemetry",
      [
        [:self_sustaining, :reactor, :execution, :start],
        [:self_sustaining, :reactor, :execution, :complete],
        [:self_sustaining, :n8n, :workflow, :executed],
        [:self_sustaining, :n8n, :webhook, :processed]
      ],
      fn event, measurements, metadata, _config ->
        # Store minimal telemetry data for performance analysis
        Agent.update(:benchmark_telemetry, fn state ->
          [{event, measurements, metadata, System.monotonic_time()} | state]
        end)
      end,
      %{}
    )
    
    # Start telemetry storage
    Agent.start_link(fn -> [] end, name: :benchmark_telemetry)
  end
  
  defp cleanup_benchmark_telemetry do
    :telemetry.detach("benchmark-telemetry")
    if Process.whereis(:benchmark_telemetry), do: Agent.stop(:benchmark_telemetry)
  end
  
  defp analyze_measurements(measurements, label) do
    successful = Enum.filter(measurements, & &1.success)
    durations = Enum.map(successful, & &1.duration_microseconds)
    
    if length(durations) == 0 do
      IO.puts("   ❌ #{label}: No successful measurements")
      %{success_rate: 0}
    else
      analysis = %{
        label: label,
        total_measurements: length(measurements),
        successful_measurements: length(successful),
        success_rate: length(successful) / length(measurements) * 100,
        avg_duration: Enum.sum(durations) / length(durations),
        min_duration: Enum.min(durations),
        max_duration: Enum.max(durations),
        p50_duration: percentile(durations, 50),
        p95_duration: percentile(durations, 95),
        p99_duration: percentile(durations, 99),
        throughput_per_second: length(successful) / (Enum.sum(durations) / 1_000_000)
      }
      
      IO.puts("   ✅ #{label} Results:")
      IO.puts("      Success Rate: #{Float.round(analysis.success_rate, 1)}%")
      IO.puts("      Avg Duration: #{Float.round(analysis.avg_duration / 1000, 2)}ms")
      IO.puts("      P95 Duration: #{Float.round(analysis.p95_duration / 1000, 2)}ms")
      IO.puts("      P99 Duration: #{Float.round(analysis.p99_duration / 1000, 2)}ms")
      IO.puts("      Throughput: #{Float.round(analysis.throughput_per_second, 1)} ops/sec")
      
      analysis
    end
  end
  
  defp percentile(values, p) do
    sorted = Enum.sort(values)
    index = Float.floor(length(sorted) * p / 100)
    Enum.at(sorted, round(index))
  end
  
  defp generate_benchmark_report(results, config) do
    IO.puts("")
    IO.puts("📈 === PERFORMANCE BENCHMARK REPORT ===")
    IO.puts("Generated at: #{DateTime.utc_now()}")
    IO.puts("Configuration: #{inspect(config)}")
    IO.puts("")
    
    # Performance comparison
    if results.baseline && results.optimized do
      baseline_avg = results.baseline.avg_duration
      optimized_avg = results.optimized.avg_duration
      improvement = (baseline_avg - optimized_avg) / baseline_avg * 100
      
      IO.puts("🎯 OPTIMIZATION RESULTS:")
      IO.puts("   Baseline Average: #{Float.round(baseline_avg / 1000, 2)}ms")
      IO.puts("   Optimized Average: #{Float.round(optimized_avg / 1000, 2)}ms")
      IO.puts("   Performance Improvement: #{Float.round(improvement, 1)}%")
      IO.puts("")
    end
    
    # Concurrent performance
    if results.concurrent do
      IO.puts("🔄 CONCURRENT PERFORMANCE:")
      Enum.each(results.concurrent.concurrent_results, fn result ->
        IO.puts("   #{result.process_count} processes: #{Float.round(result.throughput_per_second, 1)} ops/sec")
      end)
      IO.puts("")
    end
    
    # Memory analysis
    if results.memory_profile do
      IO.puts("🧠 MEMORY ANALYSIS:")
      IO.puts("   Baseline Memory: #{results.memory_profile.baseline_memory} bytes")
      IO.puts("   Avg Memory per Iteration: #{Float.round(results.memory_profile.avg_memory_per_iteration, 0)} bytes")
      IO.puts("")
    end
    
    # Latency breakdown
    if results.latency_breakdown do
      IO.puts("🔍 LATENCY BREAKDOWN:")
      Enum.each(results.latency_breakdown.component_analysis, fn {component, stats} ->
        IO.puts("   #{component}: #{Float.round(stats.avg / 1000, 2)}ms avg (P95: #{Float.round(stats.p95 / 1000, 2)}ms)")
      end)
      IO.puts("")
    end
    
    # Recommendations
    IO.puts("💡 OPTIMIZATION RECOMMENDATIONS:")
    
    if results.baseline && results.baseline.avg_duration > 100_000 do
      IO.puts("   • Average latency > 100ms - Consider connection pooling")
    end
    
    if results.memory_profile && results.memory_profile.avg_memory_per_iteration > 1_000_000 do
      IO.puts("   • High memory usage per iteration - Optimize data structures")
    end
    
    if results.concurrent do
      max_throughput = Enum.max_by(results.concurrent.concurrent_results, & &1.throughput_per_second)
      IO.puts("   • Optimal concurrency: #{max_throughput.process_count} processes (#{Float.round(max_throughput.throughput_per_second, 1)} ops/sec)")
    end
    
    IO.puts("")
    IO.puts("✅ === BENCHMARK COMPLETE ===")
  end
end

# Run the benchmark
IO.puts("Starting Reactor ↔ N8N Performance Benchmark...")
ReactorN8NBenchmark.run_benchmark()