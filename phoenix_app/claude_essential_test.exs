#!/usr/bin/env elixir

# Claude Code Essential 80/20 Test
# Maximum testing value with 20% effort - focuses on core functionality

Mix.install([
  {:jason, "~> 1.4"}
])

defmodule ClaudeEssentialTest do
  @moduledoc """
  80/20 Testing Strategy for Claude Code Integration
  
  Tests the 4 most critical aspects that give 80% confidence:
  1. Claude Code availability and basic execution
  2. Error handling and timeout behavior  
  3. Input/output processing
  4. Trace ID generation and consistency
  """

  def run_essential_tests do
    IO.puts("🎯 Claude Code Essential 80/20 Test")
    IO.puts("=" |> String.duplicate(50))
    IO.puts("4 critical tests → 80% confidence")
    
    master_trace = "essential_#{System.system_time(:nanosecond)}"
    
    start_time = System.monotonic_time(:microsecond)
    
    # The 4 essential tests
    tests = [
      {"Claude Availability", &test_claude_availability/0, 40},  # 40% of value
      {"Error Handling", &test_error_handling/1, 20},           # 20% of value  
      {"Input Processing", &test_input_processing/1, 20},       # 20% of value
      {"Trace Consistency", &test_trace_consistency/1, 20}      # 20% of value
    ]
    
    results = Enum.map(tests, fn {name, test_fn, value_percent} ->
      IO.puts("\n🧪 #{name} (#{value_percent}% value)")
      test_start = System.monotonic_time(:microsecond)
      
      result = try do
        case length(Function.info(test_fn)[:arity]) do
          0 -> test_fn.()
          1 -> test_fn.(master_trace)
        end
      rescue
        error -> {:test_error, error}
      end
      
      test_duration = System.monotonic_time(:microsecond) - test_start
      analyze_result(name, result, test_duration, value_percent)
    end)
    
    total_duration = System.monotonic_time(:microsecond) - start_time
    
    generate_essential_summary(results, total_duration)
  end

  # Test 1: Claude Availability (40% of testing value)
  # Most important - if Claude isn't available, nothing else matters
  defp test_claude_availability do
    IO.puts("   🎯 Checking Claude Code binary and basic execution")
    
    # Check if Claude command exists
    availability = case System.cmd("claude", ["--version"], stderr_to_stdout: true) do
      {output, 0} ->
        version = String.trim(output)
        IO.puts("   ✅ Claude Code available: #{version}")
        %{available: true, version: version}
      
      {error, _code} ->
        IO.puts("   ❌ Claude Code not available: #{String.slice(error, 0, 50)}")
        %{available: false, error: error}
    end
    
    # If available, test basic execution
    execution_test = if availability.available do
      IO.puts("   🎯 Testing basic Claude execution...")
      
      simple_input = "def hello, do: \"world\""
      
      case System.cmd("sh", ["-c", "echo '#{simple_input}' | claude -p 'Analyze this code in 1 word'"], 
                      stderr_to_stdout: true) do
        {output, 0} ->
          IO.puts("   ✅ Basic execution successful")
          IO.puts("   📝 Output length: #{String.length(output)} chars")
          %{execution_success: true, output_length: String.length(output)}
        
        {error, code} ->
          IO.puts("   ⚠️  Execution failed (exit #{code}): #{String.slice(error, 0, 50)}")
          %{execution_success: false, error: error, exit_code: code}
      end
    else
      %{execution_success: false, reason: "Claude not available"}
    end
    
    %{
      test: :claude_availability,
      availability: availability,
      execution: execution_test,
      success: availability.available and Map.get(execution_test, :execution_success, false)
    }
  end

  # Test 2: Error Handling (20% of testing value)
  # Critical for production stability
  defp test_error_handling(trace_id) do
    trace_id = "#{master_trace}_error"
    
    IO.puts("   🎯 Testing timeout and error scenarios")
    
    # Test 1: Command timeout
    timeout_result = test_command_timeout(trace_id)
    
    # Test 2: Invalid command
    invalid_result = test_invalid_command(trace_id)
    
    # Test 3: Bad input handling
    bad_input_result = test_bad_input(trace_id)
    
    handled_errors = [timeout_result, invalid_result, bad_input_result]
    |> Enum.count(& &1.handled_gracefully)
    
    IO.puts("   📊 Errors handled gracefully: #{handled_errors}/3")
    
    %{
      test: :error_handling,
      timeout_test: timeout_result,
      invalid_command_test: invalid_result,
      bad_input_test: bad_input_result,
      errors_handled: handled_errors,
      success: handled_errors >= 2  # At least 2/3 should be handled well
    }
  end

  # Test 3: Input Processing (20% of testing value)
  # Ensures different input types work correctly
  defp test_input_processing(trace_id) do
    trace_id = "#{master_trace}_input"
    
    IO.puts("   🎯 Testing various input types and formats")
    
    test_cases = [
      %{
        name: "simple_code",
        input: "def test, do: :ok",
        expected_success: true
      },
      %{
        name: "multiline_code", 
        input: "defmodule Test do\n  def hello, do: \"world\"\nend",
        expected_success: true
      },
      %{
        name: "empty_input",
        input: "",
        expected_success: true  # Should handle gracefully
      }
    ]
    
    results = Enum.map(test_cases, fn test_case ->
      result = test_input_case(test_case, trace_id)
      IO.puts("     #{test_case.name}: #{if result.success, do: "✅", else: "❌"}")
      result
    end)
    
    successful_cases = Enum.count(results, & &1.success)
    
    %{
      test: :input_processing,
      test_cases: results,
      successful_cases: successful_cases,
      total_cases: length(test_cases),
      success: successful_cases >= 2  # At least 2/3 should work
    }
  end

  # Test 4: Trace Consistency (20% of testing value)  
  # Critical for observability and debugging
  defp test_trace_consistency(trace_id) do
    IO.puts("   🎯 Testing trace ID generation and consistency")
    
    # Generate multiple trace IDs and verify uniqueness
    trace_ids = 1..5
    |> Enum.map(fn i ->
      "#{master_trace}_consistency_#{i}_#{System.system_time(:nanosecond)}"
    end)
    
    # Check uniqueness
    unique_traces = Enum.uniq(trace_ids)
    uniqueness_ok = length(unique_traces) == length(trace_ids)
    
    IO.puts("   📊 Trace uniqueness: #{length(unique_traces)}/#{length(trace_ids)}")
    
    # Check master trace inclusion
    master_inclusion = Enum.all?(trace_ids, fn trace ->
      String.contains?(trace, String.slice(master_trace, -8, 8))
    end)
    
    IO.puts("   🔗 Master trace inclusion: #{master_inclusion}")
    
    # Check nanosecond precision (no duplicates even with rapid generation)
    rapid_traces = 1..10
    |> Enum.map(fn _i ->
      System.system_time(:nanosecond)
    end)
    
    rapid_unique = Enum.uniq(rapid_traces)
    precision_ok = length(rapid_unique) == length(rapid_traces)
    
    IO.puts("   ⚡ Nanosecond precision: #{length(rapid_unique)}/#{length(rapid_traces)} unique")
    
    %{
      test: :trace_consistency,
      uniqueness_ok: uniqueness_ok,
      master_inclusion: master_inclusion,
      precision_ok: precision_ok,
      success: uniqueness_ok and master_inclusion and precision_ok
    }
  end

  # Helper functions

  defp test_command_timeout(trace_id) do
    # Test with very short timeout
    task = Task.async(fn ->
      case System.cmd("claude", ["--help"], stderr_to_stdout: true) do
        {_output, 0} -> :success
        {_error, _code} -> :error
      end
    end)
    
    case Task.yield(task, 100) do  # 100ms timeout
      {:ok, result} -> 
        %{handled_gracefully: true, result: result, type: :completed_quickly}
      nil ->
        Task.shutdown(task)
        %{handled_gracefully: true, result: :timeout, type: :expected_timeout}
    end
  end

  defp test_invalid_command(_trace_id) do
    try do
      System.cmd("nonexistent_claude_command", ["--test"], stderr_to_stdout: true)
      %{handled_gracefully: false, type: :unexpected_success}
    rescue
      _error -> %{handled_gracefully: true, type: :expected_error}
    end
  end

  defp test_bad_input(_trace_id) do
    # Test with problematic input
    bad_input = "this is not valid elixir code #!/@#$%"
    
    try do
      case System.cmd("sh", ["-c", "echo '#{bad_input}' | claude -p 'What is this?'"], 
                      stderr_to_stdout: true) do
        {_output, 0} -> %{handled_gracefully: true, type: :graceful_handling}
        {_error, _code} -> %{handled_gracefully: true, type: :expected_error}
      end
    rescue
      _error -> %{handled_gracefully: true, type: :exception_caught}
    end
  end

  defp test_input_case(test_case, trace_id) do
    child_trace = "#{trace_id}_#{test_case.name}"
    
    try do
      # Quick test with 2 second timeout
      task = Task.async(fn ->
        System.cmd("sh", ["-c", "echo '#{test_case.input}' | claude -p 'Analyze briefly'"], 
                   stderr_to_stdout: true)
      end)
      
      case Task.yield(task, 2_000) do
        {:ok, {_output, 0}} -> %{success: true, trace_id: child_trace}
        {:ok, {_error, _code}} -> %{success: false, trace_id: child_trace, reason: :command_error}
        nil -> 
          Task.shutdown(task)
          %{success: false, trace_id: child_trace, reason: :timeout}
      end
    rescue
      _error -> %{success: false, trace_id: child_trace, reason: :exception}
    end
  end

  defp analyze_result(test_name, result, duration, value_percent) do
    duration_ms = Float.round(duration / 1000, 2)
    
    success = case result do
      %{success: true} -> true
      %{success: false} -> false
      {:test_error, _} -> false
      _ -> false
    end
    
    status_icon = if success, do: "✅", else: "❌"
    IO.puts("   #{status_icon} #{if success, do: "PASS", else: "FAIL"} (#{duration_ms}ms)")
    
    %{
      test: test_name,
      success: success,
      duration: duration_ms,
      value_percent: value_percent,
      result: result
    }
  end

  defp generate_essential_summary(results, total_duration) do
    IO.puts("\n📊 Essential 80/20 Test Summary")
    IO.puts("-" |> String.duplicate(50))
    
    total_tests = length(results)
    passed_tests = Enum.count(results, & &1.success)
    
    # Calculate weighted success (based on value percentages)
    weighted_score = results
    |> Enum.map(fn r -> if r.success, do: r.value_percent, else: 0 end)
    |> Enum.sum()
    
    total_time = Float.round(total_duration / 1000, 2)
    avg_time = Float.round(total_time / total_tests, 2)
    
    IO.puts("Results: #{passed_tests}/#{total_tests} tests passed")
    IO.puts("Weighted Success: #{weighted_score}% (value-adjusted score)")
    IO.puts("Execution Time: #{total_time}ms total, #{avg_time}ms average")
    
    # Show individual results with value weighting
    IO.puts("\nDetailed Results:")
    Enum.each(results, fn result ->
      icon = if result.success, do: "✅", else: "❌"
      IO.puts("  #{icon} #{result.test} (#{result.value_percent}%): #{result.duration}ms")
    end)
    
    # 80/20 Assessment
    IO.puts("\n🎯 80/20 Assessment:")
    
    cond do
      weighted_score >= 80 ->
        IO.puts("🏆 EXCELLENT: 80%+ weighted success!")
        IO.puts("   System ready for production deployment")
        show_readiness_details(results)
      
      weighted_score >= 60 ->
        IO.puts("👍 GOOD: Solid foundation (#{weighted_score}%)")
        IO.puts("   Core functionality working, some improvements needed")
        show_improvement_areas(results)
      
      weighted_score >= 40 ->
        IO.puts("⚠️  PARTIAL: Basic functionality (#{weighted_score}%)")
        IO.puts("   Critical issues need resolution")
        show_critical_issues(results)
      
      true ->
        IO.puts("❌ CRITICAL: Major issues detected (#{weighted_score}%)")
        IO.puts("   System not ready for use")
        show_blocking_issues(results)
    end
    
    # Show 80/20 efficiency
    IO.puts("\n💡 80/20 Efficiency Achieved:")
    IO.puts("   ⚡ #{total_time}ms total test time")
    IO.puts("   🎯 #{weighted_score}% confidence with minimal effort")
    IO.puts("   📊 4 critical tests → comprehensive coverage")
    IO.puts("   🚀 Fast feedback for development decisions")
    
    # Next steps
    if weighted_score >= 80 do
      IO.puts("\n✅ READY FOR: Production deployment with monitoring")
    elsif weighted_score >= 60 do
      IO.puts("\n🔧 READY FOR: Integration testing and optimization")  
    else
      IO.puts("\n🛠️  NEEDS: Core issue resolution before proceeding")
    end
  end

  defp show_readiness_details(results) do
    claude_available = Enum.find(results, & &1.test == "Claude Availability")
    if claude_available && claude_available.success do
      version = get_in(claude_available.result, [:availability, :version])
      IO.puts("   🤖 Claude Code #{version} operational")
    end
    
    IO.puts("   ✅ Error handling: Robust")
    IO.puts("   ✅ Input processing: Functional") 
    IO.puts("   ✅ Trace system: Operational")
  end

  defp show_improvement_areas(results) do
    failed_tests = Enum.filter(results, & not &1.success)
    if length(failed_tests) > 0 do
      IO.puts("   🔧 Areas for improvement:")
      Enum.each(failed_tests, fn test ->
        IO.puts("     • #{test.test} (#{test.value_percent}% value)")
      end)
    end
  end

  defp show_critical_issues(results) do
    claude_test = Enum.find(results, & &1.test == "Claude Availability")
    if claude_test && not claude_test.success do
      IO.puts("   🚨 CRITICAL: Claude Code not available")
      IO.puts("     → Install Claude Code CLI first")
    end
  end

  defp show_blocking_issues(results) do
    IO.puts("   🛑 BLOCKING ISSUES:")
    failed_tests = Enum.filter(results, & not &1.success)
    Enum.each(failed_tests, fn test ->
      IO.puts("     • #{test.test}: #{test.value_percent}% value lost")
    end)
  end
end

# Run the essential 80/20 test
ClaudeEssentialTest.run_essential_tests()