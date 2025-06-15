#!/usr/bin/env elixir

# Enhanced Reactor Runner Performance Benchmark Runner
# Executes comprehensive performance tests and generates detailed reports

# Start Mix application
Mix.start()
Mix.env(:dev)

# Load and start the application
Application.load(:self_sustaining)

# Ensure the application is compiled
{_output, 0} = System.cmd("mix", ["compile"], [])

defmodule BenchmarkRunner do
  @moduledoc """
  Performance benchmark runner for the Enhanced Reactor Runner system.
  
  Executes comprehensive benchmarks and generates detailed performance reports
  with telemetry validation and analysis.
  """
  
  require Logger
  
  def run_comprehensive_benchmark(options \\ []) do
    IO.puts("🚀 Enhanced Reactor Runner - Comprehensive Performance Benchmark")
    IO.puts("=" <> String.duplicate("=", 70))
    
    # Configure benchmark parameters
    benchmark_options = [
      iterations: Keyword.get(options, :iterations, 50),
      max_concurrency: Keyword.get(options, :max_concurrency, 8),
      verbose: Keyword.get(options, :verbose, true)
    ]
    
    IO.puts("\n📋 Benchmark Configuration:")
    IO.puts("  • Iterations per test: #{benchmark_options[:iterations]}")
    IO.puts("  • Max concurrency: #{benchmark_options[:max_concurrency]}")
    IO.puts("  • Verbose output: #{benchmark_options[:verbose]}")
    
    # Start telemetry collection
    start_telemetry_collection()
    
    try do
      # Run the comprehensive benchmark suite
      results = SelfSustaining.Benchmarks.ReactorPerformanceBenchmark.run_full_benchmark(benchmark_options)
      
      # Generate and display reports
      generate_benchmark_report(results)
      
      # Save results to file
      save_benchmark_results(results)
      
      IO.puts("\n🎉 Performance Benchmark Completed Successfully!")
      
    rescue
      error ->
        IO.puts("\n❌ Benchmark failed with error: #{inspect(error)}")
        IO.puts("Stack trace: #{Exception.format_stacktrace(__STACKTRACE__)}")
        exit(1)
    end
  end
  
  def run_quick_benchmark do
    IO.puts("⚡ Enhanced Reactor Runner - Quick Performance Check")
    IO.puts("=" <> String.duplicate("=", 50))
    
    quick_options = [iterations: 10, max_concurrency: 4, verbose: false]
    
    start_time = System.monotonic_time(:microsecond)
    
    # Quick execution benchmark
    execution_times = for _i <- 1..10 do
      {time, _result} = :timer.tc(fn ->
        SelfSustaining.EnhancedReactorRunner.run(
          SelfSustaining.Benchmarks.TestReactor,
          %{test_input: "quick_benchmark"},
          [verbose: false, telemetry_dashboard: false]
        )
      end)
      time
    end
    
    end_time = System.monotonic_time(:microsecond)
    total_time = end_time - start_time
    
    # Analyze quick results
    avg_time = Enum.sum(execution_times) / length(execution_times)
    min_time = Enum.min(execution_times)
    max_time = Enum.max(execution_times)
    
    IO.puts("\n📊 Quick Performance Results:")
    IO.puts("  • Average execution time: #{format_microseconds(avg_time)}")
    IO.puts("  • Minimum execution time: #{format_microseconds(min_time)}")
    IO.puts("  • Maximum execution time: #{format_microseconds(max_time)}")
    IO.puts("  • Total benchmark time: #{format_microseconds(total_time)}")
    IO.puts("  • Throughput: #{Float.round(10 / (total_time / 1_000_000), 2)} reactors/second")
    
    # Performance rating
    rating = case avg_time do
      x when x < 10_000 -> "🌟 Excellent"
      x when x < 25_000 -> "✅ Good"
      x when x < 50_000 -> "⚠️ Acceptable"
      _ -> "❌ Needs Optimization"
    end
    
    IO.puts("  • Performance rating: #{rating}")
    
    IO.puts("\n✅ Quick benchmark completed!")
  end
  
  def run_telemetry_validation do
    IO.puts("📡 Enhanced Reactor Runner - Telemetry Validation")
    IO.puts("=" <> String.duplicate("=", 50))
    
    # Start telemetry event collection
    collected_events = []
    
    handler_id = :telemetry_validation
    
    :telemetry.attach_many(
      handler_id,
      [
        [:self_sustaining, :reactor, :coordination, :start],
        [:self_sustaining, :reactor, :coordination, :complete],
        [:self_sustaining, :reactor, :step, :coordination_start],
        [:self_sustaining, :reactor, :step, :coordination_complete]
      ],
      fn event_name, measurements, metadata, _acc ->
        event = %{
          event: event_name,
          measurements: measurements,
          metadata: metadata,
          timestamp: System.system_time(:microsecond)
        }
        send(self(), {:telemetry_event, event})
      end,
      collected_events
    )
    
    IO.puts("\n🔍 Running reactor with telemetry collection...")
    
    # Execute reactor with telemetry
    {execution_time, result} = :timer.tc(fn ->
      SelfSustaining.EnhancedReactorRunner.run(
        SelfSustaining.Benchmarks.TestReactor,
        %{test_input: "telemetry_validation"},
        [verbose: true, telemetry_dashboard: false, agent_coordination: true]
      )
    end)
    
    # Collect telemetry events
    events = collect_telemetry_events([])
    
    :telemetry.detach(handler_id)
    
    IO.puts("\n📊 Telemetry Validation Results:")
    IO.puts("  • Execution time: #{format_microseconds(execution_time)}")
    IO.puts("  • Execution result: #{inspect(result, limit: 2)}")
    IO.puts("  • Total telemetry events: #{length(events)}")
    
    if length(events) > 0 do
      IO.puts("  • Event types collected:")
      
      events
      |> Enum.map(& &1.event)
      |> Enum.frequencies()
      |> Enum.each(fn {event_type, count} ->
        IO.puts("    - #{inspect(event_type)}: #{count} events")
      end)
      
      # Validate event structure
      valid_events = Enum.count(events, fn event ->
        Map.has_key?(event, :event) and
        Map.has_key?(event, :measurements) and
        Map.has_key?(event, :metadata) and
        Map.has_key?(event, :timestamp)
      end)
      
      IO.puts("  • Valid event structure: #{valid_events}/#{length(events)} (#{Float.round(valid_events / length(events) * 100, 1)}%)")
      
      # Check for coordination events
      coordination_events = Enum.count(events, fn event ->
        case List.last(event.event) do
          last_part when last_part in [:start, :complete] -> true
          _ -> false
        end
      end)
      
      IO.puts("  • Coordination events: #{coordination_events}")
      
      if coordination_events > 0 do
        IO.puts("  ✅ Agent coordination telemetry working correctly")
      else
        IO.puts("  ⚠️ No coordination telemetry events detected")
      end
      
    else
      IO.puts("  ❌ No telemetry events collected - telemetry system may not be working")
    end
    
    IO.puts("\n✅ Telemetry validation completed!")
  end
  
  def run_stress_test(duration_seconds \\ 30) do
    IO.puts("💪 Enhanced Reactor Runner - Stress Test")
    IO.puts("=" <> String.duplicate("=", 45))
    IO.puts("  Duration: #{duration_seconds} seconds")
    
    start_time = System.monotonic_time(:second)
    end_time = start_time + duration_seconds
    
    execution_count = :counters.new(1, [])
    error_count = :counters.new(1, [])
    
    IO.puts("\n🏃 Starting stress test...")
    
    # Start multiple concurrent stress test workers
    stress_workers = for i <- 1..4 do
      Task.async(fn ->
        stress_worker(i, end_time, execution_count, error_count)
      end)
    end
    
    # Monitor progress
    monitor_stress_test(end_time, execution_count, error_count)
    
    # Wait for all workers to complete
    Task.await_many(stress_workers, (duration_seconds + 10) * 1000)
    
    final_executions = :counters.get(execution_count, 1)
    final_errors = :counters.get(error_count, 1)
    
    IO.puts("\n📊 Stress Test Results:")
    IO.puts("  • Total executions: #{final_executions}")
    IO.puts("  • Total errors: #{final_errors}")
    IO.puts("  • Success rate: #{Float.round((final_executions - final_errors) / final_executions * 100, 2)}%")
    IO.puts("  • Average throughput: #{Float.round(final_executions / duration_seconds, 2)} reactors/second")
    
    if final_errors == 0 do
      IO.puts("  🌟 Excellent - No errors during stress test")
    else
      error_rate = final_errors / final_executions * 100
      case error_rate do
        x when x < 1 -> IO.puts("  ✅ Good - Low error rate (#{Float.round(x, 2)}%)")
        x when x < 5 -> IO.puts("  ⚠️ Acceptable - Moderate error rate (#{Float.round(x, 2)}%)")
        _ -> IO.puts("  ❌ High error rate - System needs optimization")
      end
    end
    
    IO.puts("\n✅ Stress test completed!")
  end
  
  # Helper functions
  
  defp start_telemetry_collection do
    # Configure telemetry for benchmark collection
    Logger.configure(level: :info)
    
    IO.puts("📡 Telemetry collection started")
  end
  
  defp generate_benchmark_report(results) do
    IO.puts("\n📊 COMPREHENSIVE PERFORMANCE REPORT")
    IO.puts("=" <> String.duplicate("=", 50))
    
    # System Information
    IO.puts("\n🖥️ System Information:")
    system_info = results.system_info
    IO.puts("  • Elixir version: #{system_info.elixir_version}")
    IO.puts("  • OTP release: #{system_info.otp_release}")
    IO.puts("  • Schedulers: #{system_info.schedulers}")
    IO.puts("  • Total memory: #{format_bytes(system_info.memory[:total])}")
    
    # Execution Performance
    if execution = get_in(results, [:benchmarks, :execution]) do
      IO.puts("\n⚡ Execution Performance:")
      IO.puts("  • Simple reactor (baseline):")
      display_timing_stats(execution.simple_reactor, "    ")
      
      IO.puts("  • Enhanced reactor (with middleware):")
      display_timing_stats(execution.enhanced_reactor, "    ")
      
      IO.puts("  • Complex reactor (full workflow):")
      display_timing_stats(execution.complex_reactor, "    ")
      
      if overhead = execution.middleware_overhead do
        IO.puts("  • Middleware overhead:")
        IO.puts("    - Additional time: #{format_microseconds(overhead.overhead_microseconds)}")
        IO.puts("    - Overhead percentage: #{Float.round(overhead.overhead_percentage, 2)}%")
        IO.puts("    - Performance ratio: #{Float.round(overhead.overhead_ratio, 2)}x")
      end
    end
    
    # Middleware Analysis
    if middleware = get_in(results, [:benchmarks, :middleware]) do
      IO.puts("\n🔧 Middleware Performance:")
      
      if debug = middleware.debug_overhead do
        IO.puts("  • Debug middleware: #{format_microseconds(debug.mean)} avg")
      end
      
      if telemetry = middleware.telemetry_overhead do
        IO.puts("  • Telemetry middleware: #{format_microseconds(telemetry.mean)} avg")
      end
      
      if coordination = middleware.coordination_overhead do
        IO.puts("  • Coordination middleware: #{format_microseconds(coordination.mean)} avg")
      end
      
      if efficiency = middleware.efficiency_analysis do
        IO.puts("  • Combined efficiency ratio: #{Float.round(efficiency.efficiency_ratio, 2)}")
      end
    end
    
    # Coordination Performance
    if coordination = get_in(results, [:benchmarks, :coordination]) do
      IO.puts("\n🤝 Agent Coordination Performance:")
      
      if claiming = coordination.work_claiming do
        IO.puts("  • Work claiming: #{format_microseconds(claiming.mean)} avg")
      end
      
      if file_ops = coordination.file_operations do
        IO.puts("  • File operations: #{format_microseconds(file_ops.mean)} avg")
      end
      
      if id_gen = coordination.id_generation do
        IO.puts("  • ID generation: #{format_microseconds(id_gen.mean)} avg")
      end
      
      if efficiency = coordination.coordination_efficiency do
        IO.puts("  • Efficiency rating: #{efficiency.efficiency_rating}")
      end
    end
    
    # Telemetry Analysis
    if telemetry = get_in(results, [:benchmarks, :telemetry]) do
      IO.puts("\n📡 Telemetry Performance:")
      
      if emission = telemetry.emission_performance do
        IO.puts("  • Event emission: #{format_microseconds(emission.mean)} avg")
      end
      
      if validation = telemetry.event_validation do
        IO.puts("  • Total events collected: #{validation.total_events}")
        IO.puts("  • Event types: #{map_size(validation.event_types)}")
      end
      
      if overhead = telemetry.telemetry_overhead do
        IO.puts("  • Overhead rating: #{overhead.overhead_rating}")
        IO.puts("  • Events/second capacity: #{Float.round(overhead.events_per_second_capacity, 0)}")
      end
    end
    
    # Memory Analysis
    if memory = get_in(results, [:benchmarks, :memory]) do
      IO.puts("\n💾 Memory Performance:")
      
      if enhanced = memory.enhanced_reactor do
        IO.puts("  • Memory per iteration: #{format_bytes(enhanced.memory_per_iteration)}")
      end
      
      if efficiency = memory.memory_efficiency do
        IO.puts("  • Memory efficiency rating: #{efficiency.memory_efficiency_rating}")
      end
    end
    
    # Concurrency Analysis
    if concurrency = get_in(results, [:benchmarks, :concurrency]) do
      IO.puts("\n🚀 Concurrency Performance:")
      
      if optimal = concurrency.optimal_concurrency do
        IO.puts("  • Optimal concurrency: #{optimal.optimal_concurrency} workers")
        IO.puts("  • Peak throughput: #{Float.round(optimal.optimal_throughput, 2)} reactors/second")
      end
      
      if scaling = concurrency.scalability_analysis do
        IO.puts("  • Scalability assessment: #{scaling.scalability_assessment}")
      end
    end
    
    # Overall Summary
    if summary = results.summary do
      IO.puts("\n🎯 Performance Summary:")
      IO.puts("  • Overall rating: #{summary.performance_rating}")
      
      if key_metrics = summary.key_metrics do
        if avg_time = key_metrics.average_execution_time do
          IO.puts("  • Average execution time: #{format_microseconds(avg_time)}")
        end
        
        if overhead = key_metrics.middleware_overhead do
          IO.puts("  • Middleware overhead: #{Float.round(overhead, 2)}%")
        end
      end
    end
    
    # Recommendations
    if recommendations = results.recommendations do
      if length(recommendations) > 0 do
        IO.puts("\n💡 Performance Recommendations:")
        Enum.each(recommendations, fn rec ->
          IO.puts("  • #{rec}")
        end)
      else
        IO.puts("\n✅ No optimization recommendations - system performing well!")
      end
    end
  end
  
  defp save_benchmark_results(results) do
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601() |> String.replace(":", "-")
    filename = "benchmark_results_#{timestamp}.json"
    filepath = Path.join(["benchmarks", filename])
    
    # Ensure benchmarks directory exists
    File.mkdir_p!("benchmarks")
    
    # Save results as JSON
    json_content = Jason.encode!(results, pretty: true)
    File.write!(filepath, json_content)
    
    IO.puts("\n💾 Benchmark results saved to: #{filepath}")
  end
  
  defp display_timing_stats(stats, prefix \\ "") do
    IO.puts("#{prefix}- Count: #{stats.count}")
    IO.puts("#{prefix}- Average: #{format_microseconds(stats.mean)}")
    IO.puts("#{prefix}- Min: #{format_microseconds(stats.min)}")
    IO.puts("#{prefix}- Max: #{format_microseconds(stats.max)}")
    IO.puts("#{prefix}- 95th percentile: #{format_microseconds(stats.p95)}")
  end
  
  defp format_microseconds(microseconds) do
    cond do
      microseconds < 1_000 -> "#{Float.round(microseconds, 1)}μs"
      microseconds < 1_000_000 -> "#{Float.round(microseconds / 1_000, 1)}ms"
      true -> "#{Float.round(microseconds / 1_000_000, 2)}s"
    end
  end
  
  defp format_bytes(bytes) do
    cond do
      bytes < 1_024 -> "#{bytes}B"
      bytes < 1_048_576 -> "#{Float.round(bytes / 1_024, 1)}KB"
      bytes < 1_073_741_824 -> "#{Float.round(bytes / 1_048_576, 1)}MB"
      true -> "#{Float.round(bytes / 1_073_741_824, 2)}GB"
    end
  end
  
  defp collect_telemetry_events(acc) do
    receive do
      {:telemetry_event, event} ->
        collect_telemetry_events([event | acc])
    after
      1000 -> Enum.reverse(acc)
    end
  end
  
  defp stress_worker(worker_id, end_time, execution_count, error_count) do
    if System.monotonic_time(:second) < end_time do
      try do
        SelfSustaining.EnhancedReactorRunner.run(
          SelfSustaining.Benchmarks.TestReactor,
          %{test_input: "stress_test_worker_#{worker_id}"},
          [verbose: false, telemetry_dashboard: false]
        )
        
        :counters.add(execution_count, 1, 1)
      rescue
        _error ->
          :counters.add(error_count, 1, 1)
      end
      
      stress_worker(worker_id, end_time, execution_count, error_count)
    end
  end
  
  defp monitor_stress_test(end_time, execution_count, error_count) do
    if System.monotonic_time(:second) < end_time do
      current_executions = :counters.get(execution_count, 1)
      current_errors = :counters.get(error_count, 1)
      
      remaining = end_time - System.monotonic_time(:second)
      
      IO.write("\r  Progress: #{current_executions} executions, #{current_errors} errors, #{remaining}s remaining...")
      
      :timer.sleep(1000)
      monitor_stress_test(end_time, execution_count, error_count)
    else
      IO.puts("")
    end
  end
end

# Main execution
case System.argv() do
  ["full"] ->
    BenchmarkRunner.run_comprehensive_benchmark(iterations: 100, max_concurrency: 8)
    
  ["quick"] ->
    BenchmarkRunner.run_quick_benchmark()
    
  ["telemetry"] ->
    BenchmarkRunner.run_telemetry_validation()
    
  ["stress"] ->
    BenchmarkRunner.run_stress_test(30)
    
  ["stress", duration] ->
    {duration_int, _} = Integer.parse(duration)
    BenchmarkRunner.run_stress_test(duration_int)
    
  [] ->
    IO.puts("Enhanced Reactor Runner Performance Benchmark")
    IO.puts("Usage:")
    IO.puts("  elixir run_performance_benchmark.exs [full|quick|telemetry|stress] [duration]")
    IO.puts("")
    IO.puts("Commands:")
    IO.puts("  full      - Run comprehensive performance benchmark")
    IO.puts("  quick     - Run quick performance check")
    IO.puts("  telemetry - Validate telemetry system")
    IO.puts("  stress    - Run stress test (default 30 seconds)")
    IO.puts("")
    IO.puts("Running quick benchmark by default...")
    BenchmarkRunner.run_quick_benchmark()
    
  [command | _] ->
    IO.puts("Unknown command: #{command}")
    IO.puts("Use: full, quick, telemetry, or stress")
    exit(1)
end