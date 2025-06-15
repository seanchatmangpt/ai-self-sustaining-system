#!/usr/bin/env elixir

IO.puts("🚀 Reactor Simulation Performance Benchmark")
IO.puts("===========================================")

# Simulate Agent Coordination functionality
defmodule AgentCoordinationSimulation do
  def generate_agent_id do
    "agent_#{System.system_time(:nanosecond)}"
  end
  
  def simulate_work_claiming(work_type, priority \\ "medium") do
    agent_id = generate_agent_id()
    work_item_id = "work_#{System.system_time(:nanosecond)}"
    
    # Simulate atomic work claiming with file operations
    work_claim = %{
      work_item_id: work_item_id,
      agent_id: agent_id,
      work_type: work_type,
      priority: priority,
      claimed_at: DateTime.utc_now(),
      status: "claimed"
    }
    
    # Simulate JSON serialization (like coordination_helper.sh does)
    serialized = inspect(work_claim, pretty: true)
    
    # Return claim info
    {agent_id, work_item_id, byte_size(serialized)}
  end
  
  def simulate_telemetry_collection(event_name, measurements \\ %{}) do
    telemetry_event = %{
      event: event_name,
      measurements: Map.merge(%{
        duration: :rand.uniform(1000),
        memory: :rand.uniform(1024*1024)
      }, measurements),
      metadata: %{
        agent_id: generate_agent_id(),
        timestamp: System.system_time(:microsecond)
      }
    }
    
    # Simulate event processing
    byte_size(inspect(telemetry_event))
  end
  
  def simulate_reactor_step_execution(step_name, input_data) do
    # Simulate step execution with telemetry
    start_time = System.monotonic_time(:microsecond)
    
    # Simulate actual work
    result = case step_name do
      :parallel_improvement ->
        # Simulate parallel tasks
        tasks = for i <- 1..4 do
          Task.async(fn -> 
            # Simulate improvement analysis
            :timer.sleep(:rand.uniform(5))
            "improvement_#{i}_#{:rand.uniform(1000)}"
          end)
        end
        Task.await_many(tasks, 1000)
        
      :coordination_middleware ->
        # Simulate coordination overhead
        simulate_work_claiming("reactor_execution", "high")
        
      :telemetry_middleware ->
        # Simulate telemetry collection
        simulate_telemetry_collection("reactor.step.complete", %{step: step_name})
        
      _ ->
        # Generic step execution
        :timer.sleep(:rand.uniform(3))
        "step_complete"
    end
    
    end_time = System.monotonic_time(:microsecond)
    duration = end_time - start_time
    
    {result, duration}
  end
end

# Benchmark functions
defmodule ReactorBenchmark do
  def benchmark(name, iterations, fun) when is_function(fun, 0) do
    IO.puts("\n🔄 Running #{name} (#{iterations} iterations)...")
    
    times = for _ <- 1..iterations do
      {time, _} = :timer.tc(fun)
      time
    end
    
    avg = Enum.sum(times) / length(times)
    min_time = Enum.min(times)
    max_time = Enum.max(times)
    
    %{
      name: name,
      iterations: iterations,
      avg_microseconds: avg,
      min_microseconds: min_time,
      max_microseconds: max_time,
      avg_milliseconds: avg / 1000,
      min_milliseconds: min_time / 1000,
      max_milliseconds: max_time / 1000
    }
  end
  
  def print_results(results) do
    IO.puts("  Average: #{Float.round(results.avg_milliseconds, 3)}ms")
    IO.puts("  Min:     #{Float.round(results.min_milliseconds, 3)}ms")
    IO.puts("  Max:     #{Float.round(results.max_milliseconds, 3)}ms")
  end
end

# System info
IO.puts("System Information:")
IO.puts("  Elixir: #{System.version()}")
IO.puts("  OTP: #{System.otp_release()}")
IO.puts("  CPU cores: #{System.schedulers_online()}")
IO.puts("  Memory: #{:erlang.memory(:total) |> div(1024*1024)} MB")

# Run Reactor simulation benchmarks
IO.puts("\n📊 Reactor Simulation Benchmark Results:")
IO.puts("========================================")

benchmarks = [
  {
    "Agent ID Generation", 
    1000, 
    fn -> AgentCoordinationSimulation.generate_agent_id() end
  },
  {
    "Work Claiming Simulation", 
    100, 
    fn -> AgentCoordinationSimulation.simulate_work_claiming("performance_test") end
  },
  {
    "Telemetry Collection", 
    200, 
    fn -> AgentCoordinationSimulation.simulate_telemetry_collection("test.event") end
  },
  {
    "Parallel Improvement Step", 
    20, 
    fn -> AgentCoordinationSimulation.simulate_reactor_step_execution(:parallel_improvement, %{}) end
  },
  {
    "Coordination Middleware", 
    50, 
    fn -> AgentCoordinationSimulation.simulate_reactor_step_execution(:coordination_middleware, %{}) end
  },
  {
    "Telemetry Middleware", 
    100, 
    fn -> AgentCoordinationSimulation.simulate_reactor_step_execution(:telemetry_middleware, %{}) end
  }
]

results = Enum.map(benchmarks, fn {name, iterations, fun} ->
  result = ReactorBenchmark.benchmark(name, iterations, fun)
  ReactorBenchmark.print_results(result)
  result
end)

# Performance analysis
IO.puts("\n📈 Reactor Performance Analysis:")
IO.puts("================================")

# Calculate coordination overhead
coordination_result = Enum.find(results, &(&1.name == "Coordination Middleware"))
telemetry_result = Enum.find(results, &(&1.name == "Telemetry Middleware"))
agent_id_result = Enum.find(results, &(&1.name == "Agent ID Generation"))

total_middleware_overhead = coordination_result.avg_milliseconds + telemetry_result.avg_milliseconds
IO.puts("Total Middleware Overhead: #{Float.round(total_middleware_overhead, 3)}ms per step")

# Agent coordination efficiency
agent_ops_per_second = 1000 / agent_id_result.avg_milliseconds
IO.puts("Agent Operations/Second: #{Float.round(agent_ops_per_second, 0)}")

# Overall system performance
total_avg = results |> Enum.map(&(&1.avg_milliseconds)) |> Enum.sum()
performance_score = case total_avg do
  x when x < 10 -> "🚀 EXCELLENT"
  x when x < 25 -> "✅ GOOD" 
  x when x < 50 -> "⚠️  FAIR"
  _ -> "🐌 NEEDS OPTIMIZATION"
end

IO.puts("Performance Score: #{performance_score}")
IO.puts("Total Benchmark Time: #{Float.round(total_avg, 3)}ms")

# Recommendations
IO.puts("\n💡 Performance Recommendations:")
IO.puts("===============================")

if coordination_result.avg_milliseconds > 5 do
  IO.puts("• Consider optimizing agent coordination overhead")
end

if telemetry_result.avg_milliseconds > 2 do
  IO.puts("• Telemetry collection could be optimized")
end

if agent_ops_per_second < 10000 do
  IO.puts("• Agent ID generation is efficient")
else
  IO.puts("• Excellent agent coordination performance")
end

IO.puts("• System shows #{performance_score |> String.downcase() |> String.trim_leading("🚀 ") |> String.trim_leading("✅ ") |> String.trim_leading("⚠️  ") |> String.trim_leading("🐌 ")} performance characteristics")

IO.puts("\n✅ Reactor simulation benchmark completed")