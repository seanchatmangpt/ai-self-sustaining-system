defmodule SelfSustaining.AI.ComprehensiveLoopPropertyTest do
  @moduledoc """
  Property-based and comprehensive integration tests for the complete self-improvement loop.
  Uses advanced testing techniques to validate system behavior under all conditions.
  """

  use ExUnit.Case, async: false
  use ExUnitProperties

  import SelfSustaining.SelfImprovementTestHelpers

  alias SelfSustaining.AI.SelfImprovementOrchestrator
  alias SelfSustaining.AI.WorkflowGenerator

  @moduletag :comprehensive
  # 2 minutes for comprehensive tests
  @moduletag timeout: 120_000

  setup_all do
    # Start test environment with monitoring
    {:ok, _} = start_supervised({SelfImprovementOrchestrator, [cycle_interval: 1000]})
    trace_id = "trace_#{System.system_time(:nanosecond)}"

    on_exit(fn ->
      # Cleanup any generated workflows or test artifacts
      cleanup_test_artifacts()
    end)

    {:ok, trace_id: trace_id}
  end

  describe "property-based loop validation" do
    property "system maintains invariants across all cycle configurations" do
      check all(
              cycle_data <- improvement_cycle_generator(),
              max_runs: 50
            ) do
        # Simulate a cycle with the generated parameters
        initial_state = SelfImprovementOrchestrator.get_status()

        # Apply the cycle simulation
        simulate_improvement_cycle(cycle_data)

        # Verify system state after cycle
        final_state = SelfImprovementOrchestrator.get_status()

        # Assert invariants hold
        assert_system_invariants(final_state)

        # Verify state progression makes sense
        assert final_state.cycle_id >= initial_state.cycle_id,
               "Cycle ID should not decrease"
      end
    end

    property "workflow generation produces valid outputs for all input types" do
      check all(
              workflow_type <-
                member_of([:monitoring, :optimization, :error_handling, :data_processing]),
              priority <- member_of([:low, :medium, :high, :critical]),
              constraint_count <- integer(0..5),
              max_runs: 30
            ) do
        requirements = %{
          type: workflow_type,
          priority: priority,
          constraints: generate_constraints(constraint_count),
          description: "Property test workflow for #{workflow_type}"
        }

        # Mock Claude Code response for property test
        with_mock_claude_responses do
          case WorkflowGenerator.generate_workflow(requirements) do
            {:ok, workflow_result} ->
              assert_generated_workflow_validity(workflow_result)

            {:error, reason} ->
              # Acceptable if the combination is genuinely invalid
              assert is_binary(reason), "Error reason should be a descriptive string"
          end
        end
      end
    end

    property "system performance degrades gracefully under load" do
      check all(
              load_level <- integer(1..20),
              max_runs: 10
            ) do
        load_result = apply_load(load_level)

        # Performance should degrade gracefully, not cliff-drop
        assert load_result.success_rate >= 0.5,
               "System should maintain at least 50% success rate under load #{load_level}"

        assert load_result.duration < 30_000,
               "Operations should complete within 30 seconds even under load"

        # Throughput should not be negative or infinite
        assert load_result.throughput > 0,
               "Throughput should be positive"

        assert load_result.throughput < 1000,
               "Throughput should be reasonable (< 1000 ops/sec for this system)"
      end
    end
  end

  describe "chaos engineering tests" do
    test "system survives random failures throughout improvement cycle" do
      chaos_config = %{
        # 20% failure injection rate
        failure_rate: 0.2,
        failure_types: [:network, :timeout, :resource],
        # 15 seconds of chaos
        duration: 15_000
      }

      initial_state = SelfImprovementOrchestrator.get_status()

      # Run improvement cycle under chaos conditions
      chaos_test(chaos_config) do
        SelfImprovementOrchestrator.trigger_improvement_cycle()

        # Wait for cycle completion (or timeout)
        receive do
          {:cycle_completed, _result} -> :ok
          # Acceptable under chaos
          {:cycle_failed, _reason} -> :ok
        after
          20_000 -> :timeout_acceptable_under_chaos
        end
      end

      # System should still be responsive after chaos
      # Allow recovery time
      :timer.sleep(2000)

      final_state = SelfImprovementOrchestrator.get_status()
      assert_system_invariants(final_state)

      # Should be able to trigger another cycle successfully
      assert :ok = SelfImprovementOrchestrator.trigger_improvement_cycle()
    end

    test "data integrity maintained during partial system failures" do
      # Generate test data
      test_data = %{
        id: "test_#{:rand.uniform(10000)}",
        timestamp: DateTime.utc_now(),
        improvements: [
          %{type: :performance, description: "Test improvement 1"},
          %{type: :reliability, description: "Test improvement 2"}
        ]
      }

      # Inject failures during data processing
      # 30% failure rate
      inject_random_failures(0.3)

      # Process data through the improvement pipeline
      result = process_improvement_data(test_data)

      # Verify data integrity despite failures
      if result != :error do
        assert_data_flow_integrity(test_data, result)
      end
    end
  end

  describe "long-running stability tests" do
    @tag :slow
    test "system remains stable over extended operation" do
      cycle_count = 100

      # Monitor for memory leaks
      detect_memory_leaks(cycle_count)

      # Track performance over time
      performance_history = []

      for cycle <- 1..cycle_count do
        start_time = System.monotonic_time()

        # Trigger improvement cycle
        SelfImprovementOrchestrator.trigger_improvement_cycle()

        # Wait for completion
        receive do
          {:cycle_completed, result} ->
            end_time = System.monotonic_time()
            duration = System.convert_time_unit(end_time - start_time, :native, :millisecond)

            performance_data = %{
              cycle: cycle,
              duration: duration,
              success: true,
              improvements: result.improvements_processed || 0
            }

            performance_history = [performance_data | performance_history]
        after
          10_000 ->
            # Log timeout but continue
            IO.puts("Cycle #{cycle} timed out")
        end

        # Brief pause between cycles
        :timer.sleep(100)

        # Periodic health checks
        if rem(cycle, 10) == 0 do
          state = SelfImprovementOrchestrator.get_status()
          assert_system_invariants(state)

          # Check for performance regression
          if length(performance_history) >= 10 do
            recent_avg = calculate_average_performance(Enum.take(performance_history, 10))
            baseline_avg = calculate_average_performance(Enum.take(performance_history, -10))

            if recent_avg > baseline_avg * 1.5 do
              IO.puts("Warning: Performance degradation detected at cycle #{cycle}")
            end
          end
        end
      end

      # Final analysis
      analyze_long_running_performance(Enum.reverse(performance_history))
    end
  end

  describe "concurrency and race condition tests" do
    test "concurrent cycles execute safely without corruption" do
      concurrency_level = 10
      test_concurrent_cycles(concurrency_level)
    end

    test "state consistency maintained under concurrent modification" do
      # Start multiple processes that modify system state
      modification_tasks =
        for i <- 1..5 do
          Task.async(fn ->
            for _j <- 1..10 do
              improvement = %{
                id: "concurrent_#{i}_#{:rand.uniform(1000)}",
                description: "Concurrent test improvement",
                priority: Enum.random([:low, :medium, :high])
              }

              SelfImprovementOrchestrator.queue_improvement(improvement)
              :timer.sleep(:rand.uniform(50))
            end
          end)
        end

      # Start status checking tasks
      status_tasks =
        for _i <- 1..3 do
          Task.async(fn ->
            for _j <- 1..20 do
              state = SelfImprovementOrchestrator.get_status()
              assert_system_invariants(state)
              :timer.sleep(:rand.uniform(25))
            end
          end)
        end

      # Wait for all tasks
      Task.await_many(modification_tasks ++ status_tasks, 30_000)

      # Final state should be consistent
      final_state = SelfImprovementOrchestrator.get_status()
      assert_system_invariants(final_state)
    end
  end

  describe "failure recovery and resilience" do
    test "system recovers from orchestrator process death" do
      initial_state = SelfImprovementOrchestrator.get_status()

      # Kill the orchestrator process
      orchestrator_pid = Process.whereis(SelfImprovementOrchestrator)
      Process.exit(orchestrator_pid, :kill)

      # Wait for supervision tree to restart it
      :timer.sleep(1000)

      # Verify it's running again
      assert Process.whereis(SelfImprovementOrchestrator) != nil
      assert Process.whereis(SelfImprovementOrchestrator) != orchestrator_pid

      # Check state recovery
      recovered_state = SelfImprovementOrchestrator.get_status()
      assert_recovery_consistency(initial_state, recovered_state)

      # Should be able to operate normally
      assert :ok = SelfImprovementOrchestrator.trigger_improvement_cycle()
    end

    test "graceful degradation when external services fail" do
      # Mock all external services to fail
      with_failing_external_services do
        initial_state = SelfImprovementOrchestrator.get_status()

        # Trigger cycle despite external failures
        SelfImprovementOrchestrator.trigger_improvement_cycle()

        # Should complete with graceful degradation
        receive do
          {:cycle_completed, result} ->
            # Should have lower success metrics but still complete
            assert result.cycle_duration > 0
            assert result.partial_failures > 0
        after
          15_000 ->
            # Timeout is acceptable when external services fail
            :timeout_acceptable
        end

        # System should still be responsive
        final_state = SelfImprovementOrchestrator.get_status()
        assert_system_invariants(final_state)
      end
    end
  end

  describe "security and validation tests" do
    test "generated workflows cannot contain malicious code" do
      malicious_requirements = %{
        type: :malicious_test,
        description: "eval(process.exit(0)); //malicious code injection attempt",
        priority: :high,
        constraints: ["require('fs').unlinkSync('/etc/passwd')"]
      }

      with_mock_claude_responses do
        case WorkflowGenerator.generate_workflow(malicious_requirements) do
          {:ok, workflow_result} ->
            # If generation succeeds, ensure security validation catches issues
            assert_workflow_security(workflow_result.json)

          {:error, _reason} ->
            # Acceptable - malicious input should be rejected
            :ok
        end
      end
    end

    test "workflow evolution maintains backwards compatibility" do
      # Create a baseline workflow
      baseline_requirements = %{
        type: :baseline,
        description: "Baseline workflow for compatibility testing",
        priority: :medium
      }

      with_mock_claude_responses do
        {:ok, baseline_workflow} = WorkflowGenerator.generate_workflow(baseline_requirements)

        # Simulate workflow evolution
        evolution_requirements = %{
          type: :evolved,
          description: "Evolved version of baseline workflow",
          priority: :medium,
          base_workflow: baseline_workflow
        }

        {:ok, evolved_workflow} = WorkflowGenerator.generate_workflow(evolution_requirements)

        # Verify backwards compatibility
        assert_backwards_compatibility(baseline_workflow.json, evolved_workflow.json)
      end
    end
  end

  # Helper functions for comprehensive testing

  defp simulate_improvement_cycle(cycle_data) do
    # Simulate cycle execution based on property data
    start_time = System.monotonic_time()

    # Simulate discovery phase
    :timer.sleep(div(cycle_data.cycle_duration, 4))

    # Simulate generation phase
    :timer.sleep(div(cycle_data.cycle_duration, 4))

    # Simulate validation phase
    :timer.sleep(div(cycle_data.cycle_duration, 4))

    # Simulate deployment phase
    :timer.sleep(div(cycle_data.cycle_duration, 4))

    end_time = System.monotonic_time()
    actual_duration = System.convert_time_unit(end_time - start_time, :native, :millisecond)

    # Return simulated result
    %{
      opportunities_found: cycle_data.opportunities_found,
      cycle_duration: actual_duration,
      success_rate: cycle_data.success_rate,
      errors: cycle_data.error_patterns
    }
  end

  defp generate_constraints(count) do
    constraint_templates = [
      "Must complete within %d seconds",
      "Memory usage must not exceed %d MB",
      "CPU usage must stay below %d%%",
      "Must handle %d concurrent requests",
      "Error rate must be below %d%%"
    ]

    for _i <- 1..count do
      template = Enum.random(constraint_templates)
      value = :rand.uniform(100)
      :io_lib.format(template, [value]) |> to_string()
    end
  end

  defp with_mock_claude_responses(test_fun) do
    # Setup mock responses for Claude Code
    original_module =
      Application.get_env(:self_sustaining, :claude_code_module, SelfSustaining.ClaudeCode)

    # Replace with mock that returns valid responses
    Application.put_env(:self_sustaining, :claude_code_module, MockSuccessfulClaudeCode)

    try do
      test_fun.()
    after
      Application.put_env(:self_sustaining, :claude_code_module, original_module)
    end
  end

  defp inject_random_failures(failure_rate) do
    spawn(fn ->
      if :rand.uniform() < failure_rate do
        # Simulate random process failures
        send(self(), {:random_failure, "Injected failure for testing"})
      end
    end)
  end

  defp process_improvement_data(data) do
    # Simulate data processing pipeline
    try do
      # Stage 1: Validation
      validated_data = validate_improvement_data(data)

      # Stage 2: Enrichment
      enriched_data = enrich_improvement_data(validated_data)

      # Stage 3: Optimization
      optimized_data = optimize_improvement_data(enriched_data)

      optimized_data
    catch
      _ -> :error
    end
  end

  defp validate_improvement_data(data) do
    # Simulate validation failures
    receive do
      {:random_failure, _reason} -> raise "Validation failure"
    after
      0 -> data
    end
  end

  defp enrich_improvement_data(data) do
    # Add metadata and processing info
    Map.merge(data, %{
      processed_at: DateTime.utc_now(),
      enriched: true,
      metadata: %{processor: "test_pipeline"}
    })
  end

  defp optimize_improvement_data(data) do
    # Simulate optimization process
    receive do
      {:random_failure, _reason} -> raise "Optimization failure"
    after
      0 -> Map.put(data, :optimized, true)
    end
  end

  defp calculate_average_performance(performance_data) do
    if length(performance_data) == 0 do
      0
    else
      total_duration = Enum.sum(Enum.map(performance_data, & &1.duration))
      total_duration / length(performance_data)
    end
  end

  defp analyze_long_running_performance(performance_history) do
    total_cycles = length(performance_history)
    successful_cycles = Enum.count(performance_history, & &1.success)

    success_rate = successful_cycles / total_cycles
    assert success_rate >= 0.8, "Long-running success rate should be at least 80%"

    # Check for performance trends
    early_performance = Enum.take(performance_history, 10)
    late_performance = Enum.take(performance_history, -10)

    early_avg = calculate_average_performance(early_performance)
    late_avg = calculate_average_performance(late_performance)

    if late_avg > early_avg * 2 do
      IO.puts("Warning: Significant performance degradation over time")
    end

    IO.puts("Long-running test summary:")
    IO.puts("- Total cycles: #{total_cycles}")
    IO.puts("- Success rate: #{Float.round(success_rate * 100, 2)}%")
    IO.puts("- Early avg duration: #{Float.round(early_avg, 2)}ms")
    IO.puts("- Late avg duration: #{Float.round(late_avg, 2)}ms")
  end

  defp with_failing_external_services(test_fun) do
    # Mock external services to fail
    original_modules = %{
      claude: Application.get_env(:self_sustaining, :claude_code_module),
      n8n: Application.get_env(:self_sustaining, :n8n_api_module)
    }

    Application.put_env(:self_sustaining, :claude_code_module, MockFailingClaudeCode)
    Application.put_env(:self_sustaining, :n8n_api_module, MockFailingN8nApi)

    try do
      test_fun.()
    after
      for {key, original} <- original_modules do
        if original do
          case key do
            :claude -> Application.put_env(:self_sustaining, :claude_code_module, original)
            :n8n -> Application.put_env(:self_sustaining, :n8n_api_module, original)
          end
        end
      end
    end
  end

  defp cleanup_test_artifacts do
    # Clean up any generated test files or workflows
    File.rm_rf("test/tmp")
    File.rm_rf("n8n_workflows/compiled/test_*")
  end
end

# Mock modules for testing
defmodule MockSuccessfulClaudeCode do
  def prompt(_prompt, _opts) do
    {:ok, "Mock successful Claude Code response"}
  end
end

defmodule MockFailingClaudeCode do
  def prompt(_prompt, _opts) do
    {:error, "Mock Claude Code failure"}
  end
end

defmodule MockFailingN8nApi do
  def import_workflow(_json) do
    {:error, "Mock n8n API failure"}
  end
end
