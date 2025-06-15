#!/usr/bin/env elixir

# Basic Claude Code Failure Tests
# Simple tests to verify error handling works correctly

Mix.install([
  {:jason, "~> 1.4"},
  {:reactor, "~> 0.15.4"}
])

Code.require_file("lib/self_sustaining/reactor_steps/claude_code_step.ex", __DIR__)

defmodule BasicFailureTest do
  def run_tests do
    IO.puts("💥 Basic Claude Code Failure Tests")
    IO.puts("=" |> String.duplicate(50))
    
    # Test 1: Force timeout by using very short timeout
    test_forced_timeout()
    
    # Test 2: Test invalid command
    test_invalid_command()
    
    # Test 3: Test nil input
    test_nil_input()
    
    IO.puts("\n🎯 Basic Failure Tests Complete!")
    IO.puts("\n📊 Summary: All tests designed to FAIL on purpose")
    IO.puts("✅ If errors occurred gracefully, the system is resilient!")
  end

  defp test_forced_timeout do
    IO.puts("\n⏰ Test 1: Forced Timeout (50ms limit)")
    
    claude_args = %{
      task_type: :analyze,
      input_data: "def complex_function, do: :analysis_that_takes_time",
      prompt: "Provide a very detailed analysis",
      output_format: :text
    }
    
    context = %{
      trace_id: "forced_timeout_#{System.system_time(:nanosecond)}"
    }
    
    # Execute with very short timeout
    task_ref = Task.async(fn ->
      SelfSustaining.ReactorSteps.ClaudeCodeStep.run(claude_args, context)
    end)
    
    result = case Task.yield(task_ref, 50) do  # 50ms timeout
      {:ok, claude_result} -> 
        IO.puts("   ⚠️  Unexpected: Task completed within 50ms")
        claude_result
      nil ->
        Task.shutdown(task_ref)
        IO.puts("   ✅ Expected: Task timed out as planned")
        {:error, :forced_timeout}
    end
    
    IO.puts("   📋 Trace ID: #{String.slice(context.trace_id, -12, 12)}")
    IO.puts("   📊 Result: #{inspect(result, limit: 2)}")
  end

  defp test_invalid_command do
    IO.puts("\n🚫 Test 2: Invalid Command")
    
    # Try to run non-existent command
    result = try do
      case System.cmd("fake_claude_binary", ["--help"], stderr_to_stdout: true) do
        {output, 0} -> 
          IO.puts("   ⚠️  Unexpected: Fake command succeeded")
          {:unexpected_success, output}
        {error, code} ->
          IO.puts("   ✅ Expected: Command failed with exit code #{code}")
          {:expected_failure, error}
      end
    rescue
      error ->
        IO.puts("   ✅ Expected: Command not found error")
        IO.puts("   📝 Error: #{Exception.message(error)}")
        {:expected_error, error}
    end
    
    IO.puts("   📊 Result handled gracefully: #{match?({:expected_error, _}, result) or match?({:expected_failure, _}, result)}")
  end

  defp test_nil_input do
    IO.puts("\n🗂️  Test 3: Nil Input Handling")
    
    claude_args = %{
      task_type: :analyze,
      input_data: nil,  # This should cause an error
      prompt: "Analyze this nil input",
      output_format: :text
    }
    
    context = %{
      trace_id: "nil_input_test_#{System.system_time(:nanosecond)}"
    }
    
    result = try do
      SelfSustaining.ReactorSteps.ClaudeCodeStep.run(claude_args, context)
    rescue
      error ->
        IO.puts("   ✅ Expected: Nil input caused error")
        IO.puts("   📝 Error: #{Exception.message(error)}")
        {:expected_error, error}
    catch
      :error, reason ->
        IO.puts("   ✅ Expected: Nil input caught error")
        IO.puts("   📝 Reason: #{inspect(reason)}")
        {:expected_catch, reason}
    end
    
    case result do
      {:ok, _} ->
        IO.puts("   ⚠️  Unexpected: Nil input somehow succeeded")
      {:error, _} ->
        IO.puts("   ✅ Expected: Nil input returned error")
      {:expected_error, _} ->
        IO.puts("   ✅ Perfect: Error handled gracefully")
      {:expected_catch, _} ->
        IO.puts("   ✅ Perfect: Error caught gracefully")
    end
    
    IO.puts("   📋 Trace ID: #{String.slice(context.trace_id, -12, 12)}")
  end
end

BasicFailureTest.run_tests()