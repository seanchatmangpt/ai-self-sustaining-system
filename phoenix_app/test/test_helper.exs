# Test Helper Configuration for Self-Sustaining AI System
#
# This file configures the comprehensive testing framework for the entire
# self-improvement loop, including property-based testing, chaos engineering,
# and long-running stability tests.

ExUnit.start()

# Configure test timeouts for different test types
ExUnit.configure(
  timeout: 10_000,           # Default timeout: 10 seconds
  exclude: [:slow, :chaos],  # Exclude slow/chaos tests by default
  seed: 0                    # Deterministic test runs
)

# Test tags configuration:
# - :unit - Fast unit tests (< 1 second)
# - :integration - Integration tests (< 10 seconds)
# - :slow - Long-running tests (> 30 seconds)
# - :chaos - Chaos engineering tests
# - :property - Property-based tests
# - :comprehensive - Full system validation tests

# Load test support modules
Code.require_file("support/test_workflows.ex", __DIR__)
Code.require_file("support/self_improvement_test_helpers.ex", __DIR__)

# Configure mock modules for testing
Mox.defmock(SelfSustaining.MockClaudeCode, for: SelfSustaining.ClaudeCodeBehaviour)
Mox.defmock(SelfSustaining.MockN8nApi, for: SelfSustaining.N8nApiBehaviour)
Mox.defmock(SelfSustaining.MockPerformanceMonitor, for: SelfSustaining.PerformanceMonitorBehaviour)

# Test data setup
Application.put_env(:self_sustaining, :test_mode, true)
Application.put_env(:self_sustaining, :workflow_export_dir, "test/tmp/workflows")

# Ensure test directories exist
File.mkdir_p!("test/tmp/workflows")
File.mkdir_p!("test/tmp/logs")

# Clean up function for test isolation
defmodule TestCleanup do
  @moduledoc """
  Utilities for cleaning up test state between runs.
  """
  
  def clean_test_state do
    # Clean up generated workflows
    File.rm_rf("test/tmp")
    File.mkdir_p!("test/tmp/workflows")
    File.mkdir_p!("test/tmp/logs")
    
    # Reset application state
    if pid = Process.whereis(SelfSustaining.AI.SelfImprovementOrchestrator) do
      GenServer.stop(pid)
    end
    
    # Clean up any test processes
    cleanup_test_processes()
  end
  
  defp cleanup_test_processes do
    # Find and terminate any test-spawned processes
    Process.list()
    |> Enum.filter(fn pid ->
      case Process.info(pid, :dictionary) do
        {:dictionary, dict} -> Keyword.get(dict, :test_process, false)
        _ -> false
      end
    end)
    |> Enum.each(&Process.exit(&1, :cleanup))
  end
end

# Global test setup
ExUnit.after_suite(fn _results ->
  TestCleanup.clean_test_state()
end)

# Custom assertions for the self-improvement system
defmodule SelfSustainingAssertions do
  @moduledoc """
  Custom assertions specific to the self-sustaining AI system.
  """
  
  import ExUnit.Assertions
  
  @doc """
  Asserts that a workflow module is valid and compilable.
  """
  def assert_valid_workflow_module(module) do
    assert function_exported?(module, :spark_dsl_config, 0),
      "Module #{module} should export spark_dsl_config/0"
    
    case N8n.Reactor.validate_workflow(module) do
      :ok -> :ok
      {:error, reason} -> flunk("Workflow validation failed: #{reason}")
    end
  end
  
  @doc """
  Asserts that a self-improvement cycle completes successfully.
  """
  def assert_successful_improvement_cycle(timeout \\ 10_000) do
    receive do
      {:cycle_completed, result} ->
        assert result.cycle_duration > 0, "Cycle should have measurable duration"
        assert result.opportunities_found >= 0, "Opportunities count should be non-negative"
        result
      
      {:cycle_failed, reason} ->
        flunk("Improvement cycle failed: #{reason}")
    after
      timeout ->
        flunk("Improvement cycle timed out after #{timeout}ms")
    end
  end
  
  @doc """
  Asserts that system performance metrics are within acceptable ranges.
  """
  def assert_performance_acceptable(metrics, thresholds \\ %{}) do
    default_thresholds = %{
      cycle_duration: 30_000,      # 30 seconds max
      memory_usage: 80,            # 80% max
      cpu_usage: 90,               # 90% max
      success_rate: 0.8,           # 80% min
      error_rate: 0.1              # 10% max
    }
    
    thresholds = Map.merge(default_thresholds, thresholds)
    
    for {metric, threshold} <- thresholds do
      if Map.has_key?(metrics, metric) do
        value = metrics[metric]
        
        case metric do
          :success_rate ->
            assert value >= threshold,
              "Success rate #{value} below threshold #{threshold}"
          
          :error_rate ->
            assert value <= threshold,
              "Error rate #{value} above threshold #{threshold}"
          
          _ ->
            assert value <= threshold,
              "#{metric} value #{value} exceeds threshold #{threshold}"
        end
      end
    end
  end
  
  @doc """
  Asserts that generated n8n JSON is structurally valid.
  """
  def assert_valid_n8n_json(json) do
    # Required top-level fields
    required_fields = ["name", "nodes", "connections"]
    
    for field <- required_fields do
      assert Map.has_key?(json, field), "Missing required field: #{field}"
    end
    
    # Validate nodes
    nodes = json["nodes"]
    assert is_list(nodes), "Nodes should be a list"
    
    if length(nodes) > 0 do
      for node <- nodes do
        assert Map.has_key?(node, "id"), "Node missing id"
        assert Map.has_key?(node, "type"), "Node missing type"
        assert is_binary(node["id"]), "Node id should be string"
        assert is_binary(node["type"]), "Node type should be string"
      end
    end
    
    # Validate connections
    connections = json["connections"]
    assert is_map(connections), "Connections should be a map"
    
    # Validate connection references
    node_ids = MapSet.new(nodes, & &1["id"])
    
    for {source_id, _outputs} <- connections do
      assert MapSet.member?(node_ids, source_id),
        "Connection references unknown source node: #{source_id}"
    end
  end
end

# Import custom assertions globally
import SelfSustainingAssertions

# Test environment validation
defmodule TestEnvironmentValidator do
  @moduledoc """
  Validates that the test environment is properly configured.
  """
  
  def validate! do
    # Check required dependencies
    deps = [:jason, :mox, :stream_data]
    
    for dep <- deps do
      unless Code.ensure_loaded?(dep) do
        raise "Missing test dependency: #{dep}"
      end
    end
    
    # Check test directories
    unless File.dir?("test/tmp") do
      File.mkdir_p!("test/tmp")
    end
    
    # Validate configuration
    if Application.get_env(:self_sustaining, :test_mode) != true do
      raise "Test mode not enabled. Set :test_mode to true in config."
    end
    
    :ok
  end
end

# Validate environment on startup
TestEnvironmentValidator.validate!()

# Test run configuration based on environment
case System.get_env("TEST_SUITE") do
  "unit" ->
    ExUnit.configure(include: [:unit], exclude: [:integration, :slow, :chaos, :comprehensive])
    
  "integration" ->
    ExUnit.configure(include: [:unit, :integration], exclude: [:slow, :chaos, :comprehensive])
    
  "comprehensive" ->
    ExUnit.configure(include: [:unit, :integration, :comprehensive], exclude: [:slow, :chaos])
    
  "all" ->
    ExUnit.configure(include: [:unit, :integration, :slow, :chaos, :comprehensive])
    
  "chaos" ->
    ExUnit.configure(include: [:chaos], exclude: [:unit, :integration, :slow, :comprehensive])
    
  _ ->
    # Default: run unit and integration tests
    ExUnit.configure(include: [:unit, :integration], exclude: [:slow, :chaos, :comprehensive])
end

IO.puts("""

🤖 Self-Sustaining AI System Test Suite Initialized

Test Configuration:
- Suite: #{System.get_env("TEST_SUITE") || "default"}
- Timeout: #{ExUnit.configuration()[:timeout]}ms
- Seed: #{ExUnit.configuration()[:seed]}
- Excluded tags: #{inspect(ExUnit.configuration()[:exclude])}

Available Test Suites:
- TEST_SUITE=unit          # Fast unit tests only
- TEST_SUITE=integration   # Unit + integration tests
- TEST_SUITE=comprehensive # Full system validation
- TEST_SUITE=chaos         # Chaos engineering tests
- TEST_SUITE=all           # All tests (slow)

Test Categories:
🔹 Unit Tests: Fast, isolated component tests
🔹 Integration Tests: Multi-component interaction tests  
🔹 Property Tests: Property-based testing with StreamData
🔹 Chaos Tests: Fault injection and resilience testing
🔹 Comprehensive Tests: Full end-to-end system validation

Running tests for the complete self-improvement loop...

""")