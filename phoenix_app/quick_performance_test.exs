#!/usr/bin/env elixir

# Quick Performance Test for Reactor ↔ N8N Loop
# Run with: mix run quick_performance_test.exs

IO.puts("🚀 === Quick Reactor ↔ N8N Performance Test ===")

# Configure proper N8N settings
Application.put_env(:self_sustaining, :n8n, [
  api_url: "http://localhost:5678/api/v1",
  api_key: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIwM2VmZDFhMC00YjEwLTQ0M2QtODJiMC0xYjc4NjUxNDU1YzkiLCJpc3MiOiJuOG4iLCJhdWQiOiJwdWJsaWMtYXBpIiwiaWF0IjoxNzUwMDAyNzA4LCJleHAiOjE3NTI1NTIwMDB9.LoaISJGi0FuwCU53NY_kt4t_RFsGFjHZBhX9BNT_8LM",
  timeout: 5_000
])

defmodule QuickBenchmark do
  def run_speed_test(iterations \\ 20) do
    IO.puts("⚡ Testing compilation speed (#{iterations} iterations)...")
    
    # Test standard compilation
    standard_times = benchmark_compilation(:standard, iterations)
    
    # Apply optimizations
    SelfSustaining.PerformanceOptimizer.set_performance_mode(:optimized)
    
    # Test optimized compilation  
    optimized_times = benchmark_compilation(:optimized, iterations)
    
    # Apply turbo mode
    SelfSustaining.PerformanceOptimizer.set_performance_mode(:turbo)
    
    # Test turbo compilation
    turbo_times = benchmark_compilation(:turbo, iterations)
    
    # Results
    standard_avg = Enum.sum(standard_times) / length(standard_times)
    optimized_avg = Enum.sum(optimized_times) / length(optimized_times)
    turbo_avg = Enum.sum(turbo_times) / length(turbo_times)
    
    IO.puts("")
    IO.puts("📊 === PERFORMANCE RESULTS ===")
    IO.puts("Standard Mode:")
    IO.puts("  Average: #{Float.round(standard_avg / 1000, 2)}ms")
    IO.puts("  Min: #{Float.round(Enum.min(standard_times) / 1000, 2)}ms")
    IO.puts("  Max: #{Float.round(Enum.max(standard_times) / 1000, 2)}ms")
    IO.puts("")
    
    IO.puts("Optimized Mode:")
    IO.puts("  Average: #{Float.round(optimized_avg / 1000, 2)}ms")
    IO.puts("  Min: #{Float.round(Enum.min(optimized_times) / 1000, 2)}ms")
    IO.puts("  Max: #{Float.round(Enum.max(optimized_times) / 1000, 2)}ms")
    IO.puts("  Improvement: #{Float.round((standard_avg - optimized_avg) / standard_avg * 100, 1)}%")
    IO.puts("")
    
    IO.puts("Turbo Mode:")
    IO.puts("  Average: #{Float.round(turbo_avg / 1000, 2)}ms")
    IO.puts("  Min: #{Float.round(Enum.min(turbo_times) / 1000, 2)}ms")
    IO.puts("  Max: #{Float.round(Enum.max(turbo_times) / 1000, 2)}ms")
    IO.puts("  Improvement: #{Float.round((standard_avg - turbo_avg) / standard_avg * 100, 1)}%")
    IO.puts("")
    
    # Throughput calculation
    standard_throughput = 1_000_000 / standard_avg
    optimized_throughput = 1_000_000 / optimized_avg
    turbo_throughput = 1_000_000 / turbo_avg
    
    IO.puts("🎯 === THROUGHPUT ANALYSIS ===")
    IO.puts("Standard: #{Float.round(standard_throughput, 0)} operations/second")
    IO.puts("Optimized: #{Float.round(optimized_throughput, 0)} operations/second")
    IO.puts("Turbo: #{Float.round(turbo_throughput, 0)} operations/second")
    IO.puts("")
    
    max_throughput = max(standard_throughput, max(optimized_throughput, turbo_throughput))
    IO.puts("🏆 Maximum Throughput: #{Float.round(max_throughput, 0)} ops/sec")
    
    %{
      standard: %{avg: standard_avg, throughput: standard_throughput},
      optimized: %{avg: optimized_avg, throughput: optimized_throughput},
      turbo: %{avg: turbo_avg, throughput: turbo_throughput},
      max_throughput: max_throughput
    }
  end
  
  defp benchmark_compilation(mode, iterations) do
    IO.puts("  Testing #{mode} mode...")
    
    Enum.map(1..iterations, fn i ->
      workflow_def = create_test_workflow(i)
      
      start_time = System.monotonic_time()
      
      case mode do
        :standard ->
          Reactor.run(SelfSustaining.Workflows.N8nIntegrationReactor, %{
            workflow_definition: workflow_def,
            n8n_config: %{},
            action: :compile
          })
          
        :optimized ->
          Reactor.run(SelfSustaining.Workflows.N8nIntegrationReactor, %{
            workflow_definition: workflow_def,
            n8n_config: %{optimized_mode: true},
            action: :compile
          })
          
        :turbo ->
          # Use optimized step directly for maximum speed
          SelfSustaining.ReactorSteps.N8nWorkflowStepOptimized.run(%{
            workflow_id: workflow_def.name,
            workflow_data: workflow_def,
            action: :compile
          }, %{}, [])
      end
      
      end_time = System.monotonic_time()
      System.convert_time_unit(end_time - start_time, :native, :microsecond)
    end)
  end
  
  defp create_test_workflow(i) do
    %{
      name: "test_workflow_#{i}",
      nodes: [
        %{
          id: "start_#{i}",
          name: "Start Node #{i}",
          type: :webhook,
          position: [100, 200],
          parameters: %{}
        }
      ],
      connections: []
    }
  end
  
  def test_concurrent_performance(max_processes \\ 50) do
    IO.puts("🔄 Testing concurrent performance...")
    
    SelfSustaining.PerformanceOptimizer.set_performance_mode(:turbo)
    
    process_counts = [1, 5, 10, 25, 50]
    
    results = Enum.map(process_counts, fn process_count ->
      if process_count <= max_processes do
        IO.puts("  Testing #{process_count} concurrent processes...")
        
        start_time = System.monotonic_time()
        
        tasks = Enum.map(1..process_count, fn i ->
          Task.async(fn ->
            workflow_def = create_test_workflow(i)
            
            iteration_start = System.monotonic_time()
            
            SelfSustaining.ReactorSteps.N8nWorkflowStepOptimized.run(%{
              workflow_id: workflow_def.name,
              workflow_data: workflow_def,
              action: :compile
            }, %{}, [])
            
            iteration_end = System.monotonic_time()
            System.convert_time_unit(iteration_end - iteration_start, :native, :microsecond)
          end)
        end)
        
        durations = Enum.map(tasks, &Task.await(&1, 10_000))
        total_time = System.convert_time_unit(System.monotonic_time() - start_time, :native, :microsecond)
        
        avg_duration = Enum.sum(durations) / length(durations)
        throughput = length(durations) / (total_time / 1_000_000)
        
        %{
          processes: process_count,
          avg_duration: avg_duration,
          total_time: total_time,
          throughput: throughput
        }
      end
    end)
    |> Enum.filter(& &1)
    
    IO.puts("")
    IO.puts("📈 === CONCURRENT PERFORMANCE RESULTS ===")
    Enum.each(results, fn result ->
      IO.puts("#{result.processes} processes: #{Float.round(result.throughput, 1)} ops/sec (avg: #{Float.round(result.avg_duration / 1000, 2)}ms)")
    end)
    
    best_result = Enum.max_by(results, & &1.throughput)
    IO.puts("")
    IO.puts("🏆 Best Concurrent Performance: #{best_result.processes} processes at #{Float.round(best_result.throughput, 1)} ops/sec")
    
    results
  end
  
  def test_memory_efficiency(iterations \\ 100) do
    IO.puts("🧠 Testing memory efficiency...")
    
    SelfSustaining.PerformanceOptimizer.set_performance_mode(:turbo)
    
    # Baseline memory
    :erlang.garbage_collect()
    {baseline_memory, _} = :erlang.process_info(self(), :memory)
    
    # Run iterations and measure memory
    memory_samples = Enum.map(1..iterations, fn i ->
      :erlang.garbage_collect()
      {before_memory, _} = :erlang.process_info(self(), :memory)
      
      workflow_def = create_test_workflow(i)
      
      SelfSustaining.ReactorSteps.N8nWorkflowStepOptimized.run(%{
        workflow_id: workflow_def.name,
        workflow_data: workflow_def,
        action: :compile
      }, %{}, [])
      
      :erlang.garbage_collect()
      {after_memory, _} = :erlang.process_info(self(), :memory)
      
      after_memory - before_memory
    end)
    
    avg_memory_per_op = Enum.sum(memory_samples) / length(memory_samples)
    max_memory = Enum.max(memory_samples)
    min_memory = Enum.min(memory_samples)
    
    IO.puts("")
    IO.puts("💾 === MEMORY EFFICIENCY RESULTS ===")
    IO.puts("Baseline Memory: #{baseline_memory} bytes")
    IO.puts("Avg Memory per Operation: #{Float.round(avg_memory_per_op, 0)} bytes")
    IO.puts("Max Memory per Operation: #{max_memory} bytes")
    IO.puts("Min Memory per Operation: #{min_memory} bytes")
    
    %{
      baseline: baseline_memory,
      avg_per_operation: avg_memory_per_op,
      max_per_operation: max_memory,
      min_per_operation: min_memory
    }
  end
end

# Run the performance tests
speed_results = QuickBenchmark.run_speed_test(20)
concurrent_results = QuickBenchmark.test_concurrent_performance(50)
memory_results = QuickBenchmark.test_memory_efficiency(50)

IO.puts("")
IO.puts("✅ === QUICK PERFORMANCE TEST COMPLETE ===")
IO.puts("Maximum observed throughput: #{Float.round(speed_results.max_throughput, 0)} operations/second")

best_concurrent = Enum.max_by(concurrent_results, & &1.throughput)
IO.puts("Best concurrent throughput: #{Float.round(best_concurrent.throughput, 1)} ops/sec with #{best_concurrent.processes} processes")
IO.puts("Memory efficiency: #{Float.round(memory_results.avg_per_operation, 0)} bytes per operation")