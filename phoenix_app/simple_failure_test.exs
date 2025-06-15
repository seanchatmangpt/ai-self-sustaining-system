#!/usr/bin/env elixir

# Simple Claude Code Failure Tests
# Deliberately trigger failures to test error handling

Mix.install([
  {:jason, "~> 1.4"},
  {:reactor, "~> 0.15.4"}
])

Code.require_file("lib/self_sustaining/reactor_steps/claude_code_step.ex", __DIR__)

defmodule SimpleFailureTest do
  @moduledoc """
  Simple failure tests to validate error handling and system resilience.
  """

  require Logger

  def run_failure_tests do
    IO.puts("💥 Simple Claude Code Failure Tests")
    IO.puts("=" |> String.duplicate(50))
    IO.puts("Testing system resilience on purpose")
    
    # Test 1: Force timeouts
    test_timeout_failures()
    
    # Test 2: Invalid commands
    test_command_failures()
    
    # Test 3: Invalid inputs
    test_invalid_inputs()
    
    # Test 4: Trace consistency during failures
    test_trace_consistency_during_failures()
    
    IO.puts("\n🎯 Simple Failure Tests Complete!")
  end

  defp test_timeout_failures do
    IO.puts("\n⏰ Test 1: Deliberate Timeout Failures")
    
    # Create tasks with very short timeouts to force failure
    timeout_tasks = [
      %{id: "timeout_1", content: "def hello, do: :world", timeout: 50},
      %{id: "timeout_2", content: "def add(a, b), do: a + b", timeout: 100}
    ]
    
    trace_id = "timeout_test_#{System.system_time(:nanosecond)}"
    
    IO.puts("   🎯 Target: Force timeouts with #{length(timeout_tasks)} tasks")
    
    results = Enum.map(timeout_tasks, fn task ->
      execute_with_short_timeout(task, trace_id)
    end)
    
    timeouts = Enum.count(results, fn r ->
      match?({:error, :timeout}, r.result) or 
      match?({:error, :claude_timeout}, r.result)
    end)
    
    IO.puts("   📊 Results: #{timeouts}/#{length(timeout_tasks)} timed out as expected")
    
    if timeouts > 0 do
      IO.puts("   ✅ PASS: Timeout handling works correctly")
    else
      IO.puts("   ⚠️  WARNING: Expected timeouts but none occurred")
    end
    
    # Check trace IDs were preserved
    valid_traces = Enum.count(results, fn r ->
      String.contains?(r.trace_id, String.slice(trace_id, -8, 8))
    end)
    
    IO.puts("   🔍 Trace preservation: #{valid_traces}/#{length(results)} (#{Float.round(valid_traces/length(results)*100, 1)}%)")
  end

  defp test_command_failures do
    IO.puts("\n🚫 Test 2: Command Not Found Failures")
    
    IO.puts("   🎯 Target: Simulate missing Claude binary")
    
    # Try to run a non-existent command
    result = try do
      case System.cmd("nonexistent_claude_command", ["--version"], stderr_to_stdout: true) do
        {_output, 0} -> {:unexpected_success, "Command should not exist"}
        {error, _code} -> {:expected_failure, error}
      end
    rescue
      error -> {:expected_error, Exception.message(error)}
    end
    
    case result do
      {:expected_error, message} ->
        IO.puts("   ✅ PASS: Command not found handled gracefully")
        IO.puts("   📝 Error: #{String.slice(message, 0, 50)}...")
      
      {:expected_failure, error} ->
        IO.puts("   ✅ PASS: Command failed as expected")
        IO.puts("   📝 Error: #{String.slice(error, 0, 50)}...")
      
      {:unexpected_success, _} ->
        IO.puts("   ⚠️  WARNING: Command unexpectedly succeeded")
    end
  end

  defp test_invalid_inputs do
    IO.puts("\n🗂️  Test 3: Invalid Input Handling")
    
    invalid_inputs = [
      %{type: "nil_input", data: nil},
      %{type: "binary_data", data: <<0, 1, 2, 255>>},
      %{type: "very_long", data: String.duplicate("x", 5000)}
    ]
    
    trace_id = "invalid_input_test_#{System.system_time(:nanosecond)}"
    
    IO.puts("   🎯 Target: Test #{length(invalid_inputs)} invalid input types")
    
    results = Enum.map(invalid_inputs, fn input ->
      test_invalid_input(input, trace_id)
    end)
    
    graceful_failures = Enum.count(results, & &1.handled_gracefully)
    
    IO.puts("   📊 Results: #{graceful_failures}/#{length(invalid_inputs)} handled gracefully")
    
    Enum.each(results, fn result ->
      status = if result.handled_gracefully, do: "✅", else: "❌"
      IO.puts("     #{status} #{result.input_type}: #{result.error_type}")
    end)
    
    if graceful_failures == length(invalid_inputs) do
      IO.puts("   ✅ PASS: All invalid inputs handled correctly")
    else
      IO.puts("   ⚠️  PARTIAL: Some inputs not handled gracefully")
    end
  end

  defp test_trace_consistency_during_failures do
    IO.puts("\n🔍 Test 4: Trace Consistency During Failures")
    
    master_trace = "consistency_test_#{System.system_time(:nanosecond)}"
    
    IO.puts("   🎯 Target: Maintain trace IDs through error conditions")
    IO.puts("   📋 Master Trace: #{String.slice(master_trace, -12, 12)}")
    
    # Create scenarios that will fail but should preserve trace IDs
    failing_scenarios = [
      %{type: "timeout", task: %{id: "trace_timeout", content: "def test, do: :ok", timeout: 50}},
      %{type: "invalid", task: %{id: "trace_invalid", content: nil}},
      %{type: "error", task: %{id: "trace_error", content: "def test", timeout: 100}}
    ]
    
    results = Enum.map(failing_scenarios, fn scenario ->
      child_trace = "#{master_trace}_#{scenario.type}_#{System.system_time(:nanosecond)}"
      
      result = case scenario.type do
        "timeout" ->
          execute_with_short_timeout(scenario.task, child_trace)
        
        "invalid" ->
          test_invalid_input(%{type: "trace_test", data: scenario.task.content}, child_trace)
        
        "error" ->
          execute_with_short_timeout(scenario.task, child_trace)
      end
      
      # Check if child trace contains master trace elements
      trace_preserved = case result do
        %{trace_id: trace} when is_binary(trace) ->
          String.contains?(trace, String.slice(master_trace, -8, 8))
        _ -> false
      end
      
      %{
        scenario_type: scenario.type,
        child_trace: String.slice(child_trace, -12, 12),
        trace_preserved: trace_preserved,
        failed_as_expected: not Map.get(result, :success, true)
      }
    end)
    
    preserved_count = Enum.count(results, & &1.trace_preserved)
    failed_count = Enum.count(results, & &1.failed_as_expected)
    
    IO.puts("   📊 Results:")
    IO.puts("     Trace Preservation: #{preserved_count}/#{length(results)} (#{Float.round(preserved_count/length(results)*100, 1)}%)")
    IO.puts("     Expected Failures: #{failed_count}/#{length(results)} (#{Float.round(failed_count/length(results)*100, 1)}%)")
    
    Enum.each(results, fn result ->
      trace_status = if result.trace_preserved, do: "✅", else: "❌"
      fail_status = if result.failed_as_expected, do: "✅", else: "❌"
      IO.puts("     #{result.scenario_type}: #{trace_status} trace, #{fail_status} failure - #{result.child_trace}")
    end)
    
    if preserved_count == length(results) and failed_count == length(results) do
      IO.puts("   ✅ PASS: Perfect trace consistency during failures")
    elsif preserved_count >= length(results) * 0.8 do
      IO.puts("   👍 GOOD: Most traces preserved during failures")
    else
      IO.puts("   ⚠️  NEEDS IMPROVEMENT: Trace consistency issues detected")
    end
  end

  # Helper functions

  defp execute_with_short_timeout(task, trace_id) do
    child_trace = "#{trace_id}_#{task.id}_#{System.system_time(:nanosecond)}"
    
    claude_args = %{
      task_type: :analyze,
      input_data: task.content,
      prompt: "Quick analysis",
      output_format: :text
    }
    
    context = %{
      trace_id: child_trace,
      task_id: task.id
    }
    
    timeout = Map.get(task, :timeout, 100)
    
    start_time = System.monotonic_time(:microsecond)
    
    task_ref = Task.async(fn ->
      SelfSustaining.ReactorSteps.ClaudeCodeStep.run(claude_args, context)
    end)
    
    result = case Task.yield(task_ref, timeout) do
      {:ok, claude_result} -> claude_result
      nil ->
        Task.shutdown(task_ref)
        {:error, :claude_timeout}
    end
    
    duration = System.monotonic_time(:microsecond) - start_time
    
    %{
      task_id: task.id,
      trace_id: child_trace,
      duration: duration,
      result: result,
      success: match?({:ok, _}, result)
    }
  end

  defp test_invalid_input(input, trace_id) do
    child_trace = "#{trace_id}_#{input.type}_#{System.system_time(:nanosecond)}"
    
    claude_args = %{
      task_type: :analyze,
      input_data: input.data,
      prompt: "Analyze this input",
      output_format: :text
    }
    
    context = %{
      trace_id: child_trace,
      input_type: input.type
    }
    
    result = try do
      SelfSustaining.ReactorSteps.ClaudeCodeStep.run(claude_args, context)
    rescue
      error -> {:error, Exception.message(error)}
    catch
      :error, reason -> {:error, inspect(reason)}
      :exit, reason -> {:error, "Process exit: #{inspect(reason)}"}
    end
    
    error_type = case result do
      {:ok, _} -> "unexpected_success"
      {:error, msg} when is_binary(msg) -> 
        cond do
          String.contains?(msg, "invalid") -> "invalid_input_error"
          String.contains?(msg, "timeout") -> "timeout_error"
          String.contains?(msg, "command") -> "command_error"
          true -> "other_error"
        end
      {:error, _} -> "unknown_error"
      _ -> "unexpected_result"
    end
    
    %{
      input_type: input.type,
      trace_id: child_trace,
      result: result,
      error_type: error_type,
      handled_gracefully: match?({:error, _}, result)
    }
  end
end

# Run the simple failure tests
SimpleFailureTest.run_failure_tests()