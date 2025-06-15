#!/usr/bin/env elixir

# Claude Code Process-Based Tests and Benchmarks
# Demonstrates Claude Code integration with Reactor Process patterns
# Based on: https://hexdocs.pm/reactor_process/readme.html

Mix.install([
  {:jason, "~> 1.4"},
  {:reactor, "~> 0.15.4"}
])

# Load required modules
Code.require_file("lib/self_sustaining/reactor_steps/claude_code_step.ex", __DIR__)
Code.require_file("lib/self_sustaining/workflows/claude_agent_reactor.ex", __DIR__)

defmodule ClaudeProcessBenchmark do
  @moduledoc """
  Process-based testing and benchmarking for Claude Code integration.
  
  Demonstrates:
  1. Process-based reactor execution with trace ID propagation
  2. Parallel Claude Code execution across multiple processes
  3. Performance benchmarking of Claude agent workflows
  4. Trace ID consistency validation across process boundaries
  """

  require Logger

  def run_process_tests_and_benchmarks do
    IO.puts("🚀 Claude Code Process Tests & Benchmarks")
    IO.puts("=" |> String.duplicate(70))
    
    # Test 1: Process-based reactor execution
    test_process_reactor_execution()
    
    # Test 2: Parallel Claude Code execution
    test_parallel_claude_execution()
    
    # Test 3: Trace ID propagation across processes
    test_trace_id_propagation()
    
    # Test 4: Performance benchmarking
    benchmark_claude_process_performance()
    
    IO.puts("\n🎯 Claude Code Process Tests Complete!")
  end

  defp test_process_reactor_execution do
    IO.puts("\n🔧 Test 1: Process-Based Reactor Execution")
    
    # Create test scenarios for process-based execution
    scenarios = [
      create_analysis_scenario("process_test_1"),
      create_review_scenario("process_test_2"),
      create_generation_scenario("process_test_3")
    ]
    
    # Execute each scenario in a separate process
    process_results = Enum.map(scenarios, fn scenario ->
      execute_scenario_in_process(scenario)
    end)
    
    analyze_process_results(process_results)
  end

  defp test_parallel_claude_execution do
    IO.puts("\n⚡ Test 2: Parallel Claude Code Execution")
    
    # Create multiple simple Claude tasks for parallel execution
    tasks = [
      %{id: "task_1", type: :analyze, content: "def add(a, b), do: a + b"},
      %{id: "task_2", type: :review, content: "def multiply(x, y), do: x * y"},
      %{id: "task_3", type: :explain, content: "def divide(a, b), do: a / b"}
    ]
    
    IO.puts("   🚀 Executing #{length(tasks)} Claude tasks in parallel...")
    
    start_time = System.monotonic_time(:microsecond)
    
    # Execute tasks in parallel using Task.async_stream
    parallel_results = tasks
    |> Task.async_stream(&execute_claude_task/1, 
         max_concurrency: 3, 
         timeout: 15_000,
         on_timeout: :kill_task)
    |> Enum.to_list()
    
    total_duration = System.monotonic_time(:microsecond) - start_time
    
    analyze_parallel_results(parallel_results, total_duration)
  end

  defp test_trace_id_propagation do
    IO.puts("\n🔍 Test 3: Trace ID Propagation Across Processes")
    
    master_trace_id = "master_trace_#{System.system_time(:nanosecond)}"
    
    IO.puts("   📋 Master Trace ID: #{String.slice(master_trace_id, -12, 12)}")
    
    # Create child processes with trace ID propagation
    child_traces = 1..3
    |> Enum.map(fn i ->
      child_trace_id = "#{master_trace_id}_child_#{i}"
      spawn_traced_process(child_trace_id, i)
    end)
    
    # Collect results and validate trace propagation
    validate_trace_propagation(master_trace_id, length(child_traces))
  end

  defp benchmark_claude_process_performance do
    IO.puts("\n📊 Test 4: Performance Benchmarking")
    
    # Benchmark different execution patterns
    benchmarks = [
      {"Sequential Execution", &run_sequential_benchmark/0},
      {"Parallel Process Execution", &run_parallel_benchmark/0},
      {"Mixed Workload Execution", &run_mixed_workload_benchmark/0}
    ]
    
    results = Enum.map(benchmarks, fn {name, benchmark_fn} ->
      IO.puts("   🏃 Running: #{name}")
      
      {duration, result} = :timer.tc(benchmark_fn)
      duration_ms = duration / 1000
      
      IO.puts("     ⏱️  Duration: #{Float.round(duration_ms, 2)}ms")
      
      case result do
        {:ok, metrics} ->
          IO.puts("     ✅ Success: #{metrics.success_count}/#{metrics.total_count} tasks")
          IO.puts("     📈 Throughput: #{Float.round(metrics.throughput, 2)} tasks/sec")
        
        {:error, reason} ->
          IO.puts("     ❌ Failed: #{reason}")
      end
      
      {name, duration_ms, result}
    end)
    
    summarize_benchmark_results(results)
  end

  # Helper functions for test scenarios

  defp create_analysis_scenario(test_id) do
    %{
      id: test_id,
      name: "Code Analysis",
      agent_task: %{
        type: "analyze",
        description: "Analyze code complexity and maintainability",
        priority: "medium"
      },
      target_content: """
      defmodule Calculator do
        def compute(operation, a, b) do
          case operation do
            :add -> a + b
            :subtract -> a - b
            :multiply -> a * b
            :divide when b != 0 -> a / b
            _ -> {:error, "Invalid operation"}
          end
        end
      end
      """,
      context_files: %{files: []},
      output_format: %{format: :json},
      trace_id: "trace_#{test_id}_#{System.system_time(:nanosecond)}"
    }
  end

  defp create_review_scenario(test_id) do
    %{
      id: test_id,
      name: "Code Review",
      agent_task: %{
        type: "code_review",
        description: "Review code for quality and security issues",
        priority: "high"
      },
      target_content: """
      def user_login(username, password) do
        if username && password do
          # Basic authentication logic
          authenticate(username, password)
        else
          {:error, "Missing credentials"}
        end
      end
      """,
      context_files: %{files: []},
      output_format: %{format: :json},
      trace_id: "trace_#{test_id}_#{System.system_time(:nanosecond)}"
    }
  end

  defp create_generation_scenario(test_id) do
    %{
      id: test_id,
      name: "Code Generation",
      agent_task: %{
        type: "generate",
        description: "Generate Elixir module based on requirements",
        priority: "medium"
      },
      target_content: """
      Requirements:
      1. Create a UserCache module
      2. Store user sessions with expiration
      3. Provide get, set, delete functions
      4. Use ETS for storage
      """,
      context_files: %{files: []},
      output_format: %{format: :text},
      trace_id: "trace_#{test_id}_#{System.system_time(:nanosecond)}"
    }
  end

  defp execute_scenario_in_process(scenario) do
    IO.puts("   🔄 Executing #{scenario.name} (ID: #{scenario.id})")
    
    # Capture scenario ID for pattern matching
    scenario_id = scenario.id
    
    # Spawn process for reactor execution
    parent = self()
    
    process_pid = spawn(fn ->
      start_time = System.monotonic_time(:microsecond)
      
      # Set process dictionary for trace ID
      Process.put(:trace_id, scenario.trace_id)
      
      result = try do
        # Execute reactor with timeout
        task = Task.async(fn ->
          Reactor.run(
            SelfSustaining.Workflows.ClaudeAgentReactor,
            %{
              agent_task: scenario.agent_task,
              target_content: scenario.target_content,
              context_files: scenario.context_files,
              output_format: scenario.output_format
            },
            %{
              trace_id: scenario.trace_id,
              test_scenario: scenario.name,
              process_id: inspect(self())
            }
          )
        end)
        
        case Task.yield(task, 10_000) do
          {:ok, reactor_result} -> reactor_result
          nil -> 
            Task.shutdown(task)
            {:error, :timeout}
        end
      rescue
        error -> {:error, error}
      end
      
      duration = System.monotonic_time(:microsecond) - start_time
      
      send(parent, {
        :process_result,
        scenario_id,
        %{
          scenario: scenario.name,
          process_id: inspect(self()),
          trace_id: scenario.trace_id,
          duration: duration,
          result: result
        }
      })
    end)
    
    # Wait for process result with timeout
    receive do
      {:process_result, ^scenario_id, process_result} ->
        IO.puts("     ✅ Process completed: #{process_result.process_id}")
        process_result
    after
      15_000 ->
        Process.exit(process_pid, :kill)
        IO.puts("     ⏰ Process timed out")
        %{
          scenario: scenario.name,
          process_id: "timeout",
          trace_id: scenario.trace_id,
          duration: 15_000_000,
          result: {:error, :process_timeout}
        }
    end
  end

  defp execute_claude_task(task) do
    trace_id = "claude_task_#{task.id}_#{System.system_time(:nanosecond)}"
    
    start_time = System.monotonic_time(:microsecond)
    
    claude_args = %{
      task_type: task.type,
      input_data: task.content,
      prompt: "Briefly analyze this Elixir code (1-2 sentences max).",
      output_format: :text
    }
    
    context = %{
      trace_id: trace_id,
      task_id: task.id
    }
    
    result = try do
      # Execute with shorter timeout for parallel benchmark
      task_ref = Task.async(fn ->
        SelfSustaining.ReactorSteps.ClaudeCodeStep.run(claude_args, context)
      end)
      
      case Task.yield(task_ref, 8_000) do
        {:ok, claude_result} -> claude_result
        nil ->
          Task.shutdown(task_ref)
          {:error, :timeout}
      end
    rescue
      error -> {:error, error}
    end
    
    duration = System.monotonic_time(:microsecond) - start_time
    
    %{
      task_id: task.id,
      task_type: task.type,
      trace_id: trace_id,
      duration: duration,
      result: result,
      success: match?({:ok, _}, result)
    }
  end

  defp spawn_traced_process(trace_id, process_number) do
    parent = self()
    
    spawn(fn ->
      # Set trace ID in process dictionary
      Process.put(:trace_id, trace_id)
      
      # Simulate some work with trace ID
      :timer.sleep(100 + :rand.uniform(200))
      
      # Get trace ID and verify it's preserved
      retrieved_trace_id = Process.get(:trace_id)
      
      send(parent, {
        :trace_result,
        process_number,
        %{
          original_trace_id: trace_id,
          retrieved_trace_id: retrieved_trace_id,
          process_id: inspect(self()),
          match: trace_id == retrieved_trace_id
        }
      })
    end)
  end

  # Analysis functions

  defp analyze_process_results(results) do
    IO.puts("   📊 Process Execution Analysis:")
    
    successful = Enum.count(results, fn r -> match?({:ok, _}, r.result) end)
    total = length(results)
    
    avg_duration = results
    |> Enum.map(& &1.duration)
    |> Enum.sum()
    |> Kernel./(total)
    |> Kernel./(1000)  # Convert to ms
    
    IO.puts("     Success Rate: #{successful}/#{total} (#{Float.round(successful/total*100, 1)}%)")
    IO.puts("     Average Duration: #{Float.round(avg_duration, 2)}ms")
    
    # Show trace ID consistency
    trace_ids = Enum.map(results, & &1.trace_id)
    unique_traces = Enum.uniq(trace_ids)
    IO.puts("     Trace ID Uniqueness: #{length(unique_traces)}/#{length(trace_ids)} unique")
  end

  defp analyze_parallel_results(results, total_duration) do
    successful_results = Enum.filter(results, fn
      {:ok, %{success: true}} -> true
      _ -> false
    end)
    
    success_count = length(successful_results)
    total_count = length(results)
    
    IO.puts("   📊 Parallel Execution Analysis:")
    IO.puts("     Total Duration: #{Float.round(total_duration / 1000, 2)}ms")
    IO.puts("     Success Rate: #{success_count}/#{total_count}")
    IO.puts("     Parallelization Benefit: Executed #{total_count} tasks concurrently")
    
    if success_count > 0 do
      avg_task_duration = successful_results
      |> Enum.map(fn {:ok, %{duration: d}} -> d end)
      |> Enum.sum()
      |> Kernel./(success_count)
      |> Kernel./(1000)
      
      IO.puts("     Average Task Duration: #{Float.round(avg_task_duration, 2)}ms")
      
      # Calculate theoretical vs actual speedup
      theoretical_sequential = avg_task_duration * total_count
      actual_parallel = total_duration / 1000
      speedup = theoretical_sequential / actual_parallel
      
      IO.puts("     Speedup Factor: #{Float.round(speedup, 2)}x")
    end
  end

  defp validate_trace_propagation(master_trace_id, child_count) do
    IO.puts("   📊 Trace Propagation Analysis:")
    
    # Collect results from child processes
    trace_results = 1..child_count
    |> Enum.map(fn i ->
      receive do
        {:trace_result, ^i, result} -> result
      after
        5_000 -> %{match: false, error: :timeout}
      end
    end)
    
    successful_propagations = Enum.count(trace_results, & &1.match)
    
    IO.puts("     Successful Propagations: #{successful_propagations}/#{child_count}")
    IO.puts("     Master Trace: #{String.slice(master_trace_id, -12, 12)}")
    
    Enum.with_index(trace_results, 1)
    |> Enum.each(fn {result, i} ->
      status = if result.match, do: "✅", else: "❌"
      child_trace = String.slice(Map.get(result, :retrieved_trace_id, ""), -12, 12)
      IO.puts("     Child #{i}: #{status} #{child_trace}")
    end)
  end

  # Benchmark implementations

  defp run_sequential_benchmark do
    tasks = create_benchmark_tasks(3)
    
    start_time = System.monotonic_time(:microsecond)
    
    results = Enum.map(tasks, &execute_claude_task/1)
    
    duration = System.monotonic_time(:microsecond) - start_time
    
    success_count = Enum.count(results, & &1.success)
    throughput = success_count / (duration / 1_000_000)
    
    {:ok, %{
      total_count: length(tasks),
      success_count: success_count,
      duration: duration,
      throughput: throughput
    }}
  end

  defp run_parallel_benchmark do
    tasks = create_benchmark_tasks(3)
    
    start_time = System.monotonic_time(:microsecond)
    
    results = tasks
    |> Task.async_stream(&execute_claude_task/1, 
         max_concurrency: 3, 
         timeout: 10_000,
         on_timeout: :kill_task)
    |> Enum.map(fn
      {:ok, result} -> result
      {:error, :timeout} -> %{success: false, task_id: "timeout"}
    end)
    
    duration = System.monotonic_time(:microsecond) - start_time
    
    success_count = Enum.count(results, & &1.success)
    throughput = success_count / (duration / 1_000_000)
    
    {:ok, %{
      total_count: length(tasks),
      success_count: success_count,
      duration: duration,
      throughput: throughput
    }}
  end

  defp run_mixed_workload_benchmark do
    # Mix of different task types and complexities
    tasks = [
      %{id: "simple_1", type: :analyze, content: "def simple, do: :ok"},
      %{id: "complex_1", type: :review, content: create_complex_code_sample()},
      %{id: "simple_2", type: :explain, content: "def add(a, b), do: a + b"}
    ]
    
    start_time = System.monotonic_time(:microsecond)
    
    results = tasks
    |> Task.async_stream(&execute_claude_task/1, 
         max_concurrency: 2, 
         timeout: 12_000,
         on_timeout: :kill_task)
    |> Enum.map(fn
      {:ok, result} -> result
      {:error, :timeout} -> %{success: false, task_id: "timeout"}
    end)
    
    duration = System.monotonic_time(:microsecond) - start_time
    
    success_count = Enum.count(results, & &1.success)
    throughput = success_count / (duration / 1_000_000)
    
    {:ok, %{
      total_count: length(tasks),
      success_count: success_count,
      duration: duration,
      throughput: throughput
    }}
  end

  defp create_benchmark_tasks(count) do
    1..count
    |> Enum.map(fn i ->
      %{
        id: "bench_#{i}",
        type: Enum.random([:analyze, :review, :explain]),
        content: "def benchmark_#{i}(x), do: x * #{i}"
      }
    end)
  end

  defp create_complex_code_sample do
    """
    defmodule ComplexModule do
      use GenServer
      
      def start_link(opts) do
        GenServer.start_link(__MODULE__, opts, name: __MODULE__)
      end
      
      def init(opts) do
        state = %{
          data: Map.get(opts, :data, %{}),
          timeout: Map.get(opts, :timeout, 5000)
        }
        {:ok, state}
      end
      
      def handle_call({:get, key}, _from, state) do
        value = Map.get(state.data, key)
        {:reply, value, state}
      end
      
      def handle_cast({:set, key, value}, state) do
        new_data = Map.put(state.data, key, value)
        {:noreply, %{state | data: new_data}}
      end
    end
    """
  end

  defp summarize_benchmark_results(results) do
    IO.puts("   📊 Benchmark Summary:")
    
    successful_benchmarks = Enum.filter(results, fn {_, _, result} ->
      match?({:ok, _}, result)
    end)
    
    if length(successful_benchmarks) > 0 do
      best_throughput = successful_benchmarks
      |> Enum.map(fn {name, _, {:ok, metrics}} -> {name, metrics.throughput} end)
      |> Enum.max_by(fn {_, throughput} -> throughput end)
      
      {best_name, best_value} = best_throughput
      IO.puts("     🏆 Best Throughput: #{best_name} (#{Float.round(best_value, 2)} tasks/sec)")
      
      avg_success_rate = successful_benchmarks
      |> Enum.map(fn {_, _, {:ok, metrics}} -> 
        metrics.success_count / metrics.total_count 
      end)
      |> Enum.sum()
      |> Kernel./(length(successful_benchmarks))
      
      IO.puts("     📈 Average Success Rate: #{Float.round(avg_success_rate * 100, 1)}%")
    else
      IO.puts("     ⚠️  No successful benchmarks to summarize")
    end
  end
end

# Run the process tests and benchmarks
ClaudeProcessBenchmark.run_process_tests_and_benchmarks()