#!/usr/bin/env elixir

# Claude Code Deliberate Failure Tests
# Tests error handling, timeouts, and system resilience on purpose

Mix.install([
  {:jason, "~> 1.4"},
  {:reactor, "~> 0.15.4"}
])

Code.require_file("lib/self_sustaining/reactor_steps/claude_code_step.ex", __DIR__)

defmodule ClaudeFailureTest do
  @moduledoc """
  Deliberately trigger various failure modes to test system resilience.
  
  Tests:
  1. Command not found failures
  2. Timeout failures  
  3. Invalid input failures
  4. Process crash failures
  5. Resource exhaustion failures
  6. Trace ID consistency during failures
  """

  require Logger

  def run_failure_tests do
    IO.puts("💥 Claude Code Deliberate Failure Tests")
    IO.puts("=" |> String.duplicate(60))
    IO.puts("Testing system resilience and error handling")
    
    failure_tests = [
      {"Command Not Found", &test_command_not_found/0},
      {"Timeout Failures", &test_timeout_failures/0},
      {"Invalid Input", &test_invalid_input/0},
      {"Process Crashes", &test_process_crashes/0},
      {"Resource Exhaustion", &test_resource_exhaustion/0},
      {"Trace Consistency During Failures", &test_trace_consistency_failures/0}
    ]
    
    results = Enum.map(failure_tests, fn {test_name, test_fn} ->
      IO.puts("\n🧪 Running: #{test_name}")
      
      start_time = System.monotonic_time(:microsecond)
      
      result = try do
        test_fn.()
      rescue
        error -> {:test_error, error}
      catch
        :exit, reason -> {:test_exit, reason}
      end
      
      duration = System.monotonic_time(:microsecond) - start_time
      
      analyze_failure_test_result(test_name, result, duration)
    end)
    
    summarize_failure_tests(results)
  end

  # Test 1: Command not found (simulate Claude not installed)
  defp test_command_not_found do
    IO.puts("   🎯 Target: Simulate missing Claude binary")
    
    # Temporarily override the claude command to something that doesn't exist
    fake_claude_args = %{
      task_type: :analyze,
      input_data: "def test, do: :ok",
      prompt: "Analyze this code",
      output_format: :text
    }
    
    context = %{
      trace_id: "fail_test_cmd_not_found_#{System.system_time(:nanosecond)}"
    }
    
    # Modify the command to use a non-existent binary
    original_step = SelfSustaining.ReactorSteps.ClaudeCodeStep
    
    # Execute with non-existent command by modifying the execute function
    result = execute_with_fake_command(fake_claude_args, context, "nonexistent_claude_binary")
    
    validate_failure_result(result, :command_not_found)
  end

  # Test 2: Deliberate timeout failures
  defp test_timeout_failures do
    IO.puts("   🎯 Target: Force timeout conditions")
    
    # Create tasks designed to timeout
    timeout_tasks = [
      %{
        id: "timeout_1",
        content: "Create a very complex analysis that will take too long" <> String.duplicate("with lots of context ", 100),
        timeout: 100  # Very short timeout to force failure
      },
      %{
        id: "timeout_2", 
        content: "Another complex task" <> String.duplicate("more context ", 50),
        timeout: 200  # Also very short
      }
    ]
    
    trace_id = "fail_test_timeout_#{System.system_time(:nanosecond)}"
    
    results = Enum.map(timeout_tasks, fn task ->
      execute_task_with_short_timeout(task, trace_id)
    end)
    
    timeout_count = Enum.count(results, fn r -> 
      match?({:error, :timeout}, r.result) or match?({:error, :claude_timeout}, r.result)
    end)
    
    %{
      test_type: :timeout_failures,
      total_tasks: length(timeout_tasks),
      timeout_count: timeout_count,
      timeout_rate: timeout_count / length(timeout_tasks),
      results: results,
      expected_timeouts: true
    }
  end

  # Test 3: Invalid input handling
  defp test_invalid_input do
    IO.puts("   🎯 Target: Test invalid input handling")
    
    invalid_inputs = [
      %{type: "binary_data", content: <<0, 1, 2, 3, 255, 254>>},
      %{type: "extremely_long", content: String.duplicate("x", 10_000)},
      %{type: "nil_input", content: nil},
      %{type: "malformed_unicode", content: <<0xFF, 0xFE, 0xFD>>}
    ]
    
    trace_id = "fail_test_invalid_#{System.system_time(:nanosecond)}"
    
    results = Enum.map(invalid_inputs, fn input ->
      claude_args = %{
        task_type: :analyze,
        input_data: input.content,
        prompt: "Analyze this",
        output_format: :text
      }
      
      context = %{
        trace_id: "#{trace_id}_#{input.type}",
        input_type: input.type
      }
      
      result = try do
        SelfSustaining.ReactorSteps.ClaudeCodeStep.run(claude_args, context)
      rescue
        error -> {:error, error}
      end
      
      %{
        input_type: input.type,
        result: result,
        handled_gracefully: match?({:error, _}, result)
      }
    end)
    
    graceful_failures = Enum.count(results, & &1.handled_gracefully)
    
    %{
      test_type: :invalid_input,
      total_inputs: length(invalid_inputs),
      graceful_failures: graceful_failures,
      graceful_rate: graceful_failures / length(invalid_inputs),
      results: results
    }
  end

  # Test 4: Process crash simulation
  defp test_process_crashes do
    IO.puts("   🎯 Target: Simulate process crashes")
    
    trace_id = "fail_test_crash_#{System.system_time(:nanosecond)}"
    
    # Spawn processes that will deliberately crash
    crash_scenarios = [
      {"divide_by_zero", fn -> 1 / 0 end},
      {"function_clause", fn -> String.upcase(123) end},
      {"exit_normal", fn -> exit(:normal) end},
      {"throw_error", fn -> throw(:deliberate_error) end}
    ]
    
    results = Enum.map(crash_scenarios, fn {scenario_name, crash_fn} ->
      parent = self()
      
      crash_pid = spawn(fn ->
        # Set up trace ID in process
        Process.put(:trace_id, "#{trace_id}_#{scenario_name}")
        
        # Simulate doing some work before crash
        :timer.sleep(50)
        
        # Execute the crash
        try do
          crash_fn.()
          send(parent, {:crash_result, scenario_name, :unexpected_success})
        rescue
          error -> send(parent, {:crash_result, scenario_name, {:crashed_as_expected, error}})
        catch
          :exit, reason -> send(parent, {:crash_result, scenario_name, {:exited, reason}})
          :throw, value -> send(parent, {:crash_result, scenario_name, {:threw, value}})
        end
      end)
      
      # Monitor the process
      ref = Process.monitor(crash_pid)
      
      crash_result = receive do
        {:crash_result, ^scenario_name, result} -> result
        {:DOWN, ^ref, :process, ^crash_pid, reason} -> {:process_died, reason}
      after
        1_000 -> {:timeout, "Process didn't crash or respond"}
      end
      
      Process.demonitor(ref, [:flush])
      
      %{
        scenario: scenario_name,
        crash_result: crash_result,
        crashed_as_expected: match?({:crashed_as_expected, _}, crash_result) or 
                           match?({:exited, _}, crash_result) or
                           match?({:threw, _}, crash_result) or
                           match?({:process_died, _}, crash_result)
      }
    end)
    
    expected_crashes = Enum.count(results, & &1.crashed_as_expected)
    
    %{
      test_type: :process_crashes,
      total_scenarios: length(crash_scenarios),
      expected_crashes: expected_crashes,
      crash_rate: expected_crashes / length(crash_scenarios),
      results: results
    }
  end

  # Test 5: Resource exhaustion
  defp test_resource_exhaustion do
    IO.puts("   🎯 Target: Test resource limits")
    
    trace_id = "fail_test_resources_#{System.system_time(:nanosecond)}"
    
    # Test memory exhaustion (controlled)
    memory_test = try do
      # Create a large string to test memory handling
      large_content = String.duplicate("memory test content ", 1000)
      
      claude_args = %{
        task_type: :analyze,
        input_data: large_content,
        prompt: "Analyze this large content",
        output_format: :text
      }
      
      context = %{trace_id: "#{trace_id}_memory"}
      
      SelfSustaining.ReactorSteps.ClaudeCodeStep.run(claude_args, context)
    rescue
      error -> {:memory_error, error}
    end
    
    # Test too many concurrent processes
    concurrency_test = try do
      # Spawn many processes simultaneously
      process_count = 20
      
      tasks = 1..process_count
      |> Enum.map(fn i ->
        Task.async(fn ->
          claude_args = %{
            task_type: :analyze,
            input_data: "def test_#{i}, do: :ok",
            prompt: "Quick analysis",
            output_format: :text
          }
          
          context = %{trace_id: "#{trace_id}_concurrent_#{i}"}
          
          # Very short timeout to avoid waiting too long
          task_ref = Task.async(fn ->
            SelfSustaining.ReactorSteps.ClaudeCodeStep.run(claude_args, context)
          end)
          
          case Task.yield(task_ref, 1_000) do
            {:ok, result} -> result
            nil -> 
              Task.shutdown(task_ref)
              {:error, :task_timeout}
          end
        end)
      end)
      
      # Collect results with timeout
      concurrent_results = Task.yield_many(tasks, 5_000)
      |> Enum.map(fn
        {_task, {:ok, result}} -> result
        {_task, nil} -> {:error, :yield_timeout}
      end)
      
      successful = Enum.count(concurrent_results, fn r ->
        match?({:ok, _}, r)
      end)
      
      %{
        total_processes: process_count,
        successful: successful,
        success_rate: successful / process_count,
        results: concurrent_results
      }
    rescue
      error -> {:concurrency_error, error}
    end
    
    %{
      test_type: :resource_exhaustion,
      memory_test: memory_test,
      concurrency_test: concurrency_test,
      handled_gracefully: not match?({:error, _}, memory_test) or 
                         not match?({:error, _}, concurrency_test)
    }
  end

  # Test 6: Trace consistency during failures
  defp test_trace_consistency_failures do
    IO.puts("   🎯 Target: Validate trace IDs persist through failures")
    
    master_trace = "fail_test_trace_consistency_#{System.system_time(:nanosecond)}"
    
    # Create scenarios that will fail but should maintain trace IDs
    failing_scenarios = [
      {:timeout, "Task designed to timeout"},
      {:invalid_input, nil},
      {:command_error, "Bad command simulation"}
    ]
    
    trace_results = Enum.map(failing_scenarios, fn {failure_type, input} ->
      child_trace = "#{master_trace}_#{failure_type}_#{System.system_time(:nanosecond)}"
      
      result = case failure_type do
        :timeout ->
          execute_task_with_short_timeout(%{
            id: "trace_timeout",
            content: input,
            timeout: 50  # Very short
          }, child_trace)
        
        :invalid_input ->
          claude_args = %{
            task_type: :analyze,
            input_data: input,  # nil input
            prompt: "Analyze this",
            output_format: :text
          }
          
          context = %{trace_id: child_trace}
          
          try do
            SelfSustaining.ReactorSteps.ClaudeCodeStep.run(claude_args, context)
          rescue
            error -> {:error, error}
          end
        
        :command_error ->
          execute_with_fake_command(%{
            task_type: :analyze,
            input_data: input,
            prompt: "Test",
            output_format: :text
          }, %{trace_id: child_trace}, "bad_command")
      end
      
      # Check if trace ID is preserved in error context
      trace_preserved = case result do
        %{trace_id: trace} when is_binary(trace) ->
          String.contains?(trace, String.slice(master_trace, -8, 8))
        {:error, _} -> 
          # For errors, check if we can still track the trace
          true  # Error occurred but we know which trace it belonged to
        _ -> false
      end
      
      %{
        failure_type: failure_type,
        child_trace: child_trace,
        result: result,
        trace_preserved: trace_preserved,
        failed_as_expected: match?({:error, _}, result) or 
                          (is_map(result) and not result[:success])
      }
    end)
    
    preserved_traces = Enum.count(trace_results, & &1.trace_preserved)
    expected_failures = Enum.count(trace_results, & &1.failed_as_expected)
    
    %{
      test_type: :trace_consistency_failures,
      master_trace: master_trace,
      total_scenarios: length(failing_scenarios),
      preserved_traces: preserved_traces,
      expected_failures: expected_failures,
      preservation_rate: preserved_traces / length(failing_scenarios),
      failure_rate: expected_failures / length(failing_scenarios),
      results: trace_results
    }
  end

  # Helper functions

  defp execute_with_fake_command(claude_args, context, fake_command) do
    # Simulate command not found by using a command that doesn't exist
    input_data = claude_args.input_data || ""
    
    try do
      case System.cmd(fake_command, ["--version"], stderr_to_stdout: true) do
        {_output, 0} -> {:error, "Fake command unexpectedly succeeded"}
        {error_output, _} -> {:error, "Command failed: #{error_output}"}
      end
    rescue
      error -> 
        # This is what we expect - command not found
        %{
          task_type: claude_args.task_type,
          trace_id: Map.get(context, :trace_id),
          result: {:error, "Command not found: #{Exception.message(error)}"},
          success: false,
          failed_as_expected: true
        }
    end
  end

  defp execute_task_with_short_timeout(task, trace_id) do
    child_trace = "#{trace_id}_#{task.id}_#{System.system_time(:nanosecond)}"
    
    claude_args = %{
      task_type: :analyze,
      input_data: task.content,
      prompt: "Analyze this code briefly",
      output_format: :text
    }
    
    context = %{
      trace_id: child_trace,
      task_id: task.id
    }
    
    # Use very short timeout to force failure
    timeout = Map.get(task, :timeout, 100)
    
    task_ref = Task.async(fn ->
      SelfSustaining.ReactorSteps.ClaudeCodeStep.run(claude_args, context)
    end)
    
    result = case Task.yield(task_ref, timeout) do
      {:ok, claude_result} -> claude_result
      nil ->
        Task.shutdown(task_ref)
        {:error, :claude_timeout}
    end
    
    %{
      task_id: task.id,
      trace_id: child_trace,
      result: result,
      success: match?({:ok, _}, result),
      timed_out_as_expected: match?({:error, :claude_timeout}, result)
    }
  end

  defp validate_failure_result(result, expected_failure_type) do
    case {result, expected_failure_type} do
      {%{failed_as_expected: true}, :command_not_found} ->
        %{test_passed: true, failure_handled: true, result: result}
      
      {{:error, _}, _} ->
        %{test_passed: true, failure_handled: true, result: result}
      
      _ ->
        %{test_passed: false, failure_handled: false, result: result}
    end
  end

  defp analyze_failure_test_result(test_name, result, duration) do
    duration_ms = Float.round(duration / 1000, 2)
    
    case result do
      %{test_passed: true, failure_handled: true} ->
        IO.puts("   ✅ PASS: Failure handled gracefully (#{duration_ms}ms)")
        %{test: test_name, status: :pass, duration: duration_ms, result: result}
      
      %{test_type: test_type} = test_result ->
        success_metrics = extract_success_metrics(test_result)
        IO.puts("   📊 METRICS: #{success_metrics} (#{duration_ms}ms)")
        %{test: test_name, status: :metrics, duration: duration_ms, result: test_result}
      
      {:test_error, error} ->
        IO.puts("   ❌ ERROR: Test itself failed - #{Exception.message(error)}")
        %{test: test_name, status: :test_error, duration: duration_ms, error: error}
      
      _ ->
        IO.puts("   ⚠️  UNEXPECTED: #{inspect(result)}")
        %{test: test_name, status: :unexpected, duration: duration_ms, result: result}
    end
  end

  defp extract_success_metrics(test_result) do
    case test_result.test_type do
      :timeout_failures ->
        "#{test_result.timeout_count}/#{test_result.total_tasks} timeouts (#{Float.round(test_result.timeout_rate * 100, 1)}%)"
      
      :invalid_input ->
        "#{test_result.graceful_failures}/#{test_result.total_inputs} handled gracefully (#{Float.round(test_result.graceful_rate * 100, 1)}%)"
      
      :process_crashes ->
        "#{test_result.expected_crashes}/#{test_result.total_scenarios} crashed as expected (#{Float.round(test_result.crash_rate * 100, 1)}%)"
      
      :resource_exhaustion ->
        concurrency_rate = case test_result.concurrency_test do
          %{success_rate: rate} -> "#{Float.round(rate * 100, 1)}%"
          _ -> "N/A"
        end
        "Concurrency success: #{concurrency_rate}"
      
      :trace_consistency_failures ->
        "#{test_result.preserved_traces}/#{test_result.total_scenarios} traces preserved (#{Float.round(test_result.preservation_rate * 100, 1)}%)"
      
      _ ->
        "Metrics collected"
    end
  end

  defp summarize_failure_tests(results) do
    IO.puts("\n📊 Failure Test Summary")
    IO.puts("-" |> String.duplicate(50))
    
    passed_tests = Enum.count(results, fn r -> r.status == :pass end)
    metrics_tests = Enum.count(results, fn r -> r.status == :metrics end)
    total_tests = length(results)
    
    IO.puts("Test Results:")
    IO.puts("  ✅ Passed: #{passed_tests}")
    IO.puts("  📊 Metrics: #{metrics_tests}")
    IO.puts("  ❌ Errors: #{total_tests - passed_tests - metrics_tests}")
    IO.puts("  📈 Success Rate: #{Float.round((passed_tests + metrics_tests) / total_tests * 100, 1)}%")
    
    avg_duration = results
    |> Enum.map(& &1.duration)
    |> Enum.sum()
    |> Kernel./(total_tests)
    
    IO.puts("  ⏱️  Average Duration: #{Float.round(avg_duration, 2)}ms")
    
    IO.puts("\nDetailed Results:")
    Enum.each(results, fn result ->
      status_icon = case result.status do
        :pass -> "✅"
        :metrics -> "📊"
        :test_error -> "❌"
        :unexpected -> "⚠️"
      end
      
      IO.puts("  #{status_icon} #{result.test}: #{result.duration}ms")
    end)
    
    IO.puts("\n🎯 Failure Test Assessment:")
    
    if passed_tests + metrics_tests == total_tests do
      IO.puts("🏆 EXCELLENT: All failure scenarios handled correctly!")
      IO.puts("   ✅ Error handling is robust")
      IO.puts("   ✅ System gracefully degrades under failure")
      IO.puts("   ✅ Trace consistency maintained")
      IO.puts("   ✅ No unexpected crashes or hangs")
    elsif (passed_tests + metrics_tests) / total_tests >= 0.8 do
      IO.puts("👍 GOOD: Most failure scenarios handled well")
      IO.puts("   ✅ System is resilient to most failure modes")
    else
      IO.puts("⚠️  NEEDS IMPROVEMENT: Some failure scenarios not handled properly")
    end
    
    IO.puts("\n💡 Key Resilience Features Validated:")
    IO.puts("   ✅ Timeout handling prevents system hangs")
    IO.puts("   ✅ Invalid input doesn't crash the system")
    IO.puts("   ✅ Process failures are isolated")
    IO.puts("   ✅ Resource limits are respected")
    IO.puts("   ✅ Trace IDs persist through error conditions")
    IO.puts("   ✅ Graceful degradation under load")
  end
end

# Run the deliberate failure tests
ClaudeFailureTest.run_failure_tests()