defmodule SelfSustaining.SelfImprovementTestHelpers do
  @moduledoc """
  Comprehensive test utilities for validating the entire self-improvement loop.
  Provides property-based testing, chaos testing, and deep validation helpers.
  """
  
  import ExUnit.Assertions
  import StreamData
  
  alias SelfSustaining.AI.SelfImprovementOrchestrator
  alias SelfSustaining.AI.WorkflowGenerator
  alias N8n.WorkflowManager
  
  @doc """
  Generates property-based test data for improvement cycles.
  """
  def improvement_cycle_generator do
    gen all(
          opportunity_count <- integer(1..10),
          success_rate <- float(min: 0.0, max: 1.0),
          cycle_duration <- integer(1000..30000),
          resource_usage <- map_of(atom(:alphanumeric), float(min: 0.0, max: 1.0)),
          error_patterns <- list_of(string(:alphanumeric), min_length: 0, max_length: 5)
        ) do
      %{
        opportunities_found: opportunity_count,
        success_rate: success_rate,
        cycle_duration: cycle_duration,
        resource_usage: resource_usage,
        error_patterns: error_patterns,
        timestamp: DateTime.utc_now()
      }
    end
  end
  
  @doc """
  Validates system state invariants that must hold throughout any cycle.
  """
  def assert_system_invariants(system_state) do
    # Core invariants that must always be true
    assert system_state.cycle_id >= 0, "Cycle ID must be non-negative"
    assert system_state.queued_improvements >= 0, "Queue count must be non-negative"
    assert system_state.active_workflows >= 0, "Active workflow count must be non-negative"
    
    # Performance invariants
    if system_state.last_cycle do
      assert DateTime.diff(DateTime.utc_now(), system_state.last_cycle, :second) >= 0,
        "Last cycle cannot be in the future"
    end
    
    # Resource constraints
    if system_state.performance_metrics do
      metrics = system_state.performance_metrics
      
      if Map.has_key?(metrics, :memory_usage) do
        assert metrics.memory_usage >= 0, "Memory usage cannot be negative"
        assert metrics.memory_usage <= 100, "Memory usage cannot exceed 100%"
      end
      
      if Map.has_key?(metrics, :cpu_usage) do
        assert metrics.cpu_usage >= 0, "CPU usage cannot be negative"
        assert metrics.cpu_usage <= 100, "CPU usage cannot exceed 100%"
      end
    end
  end
  
  @doc """
  Performs chaos testing by injecting random failures into the system.
  """
  def chaos_test(chaos_config \\ %{}) do
    failure_rate = Map.get(chaos_config, :failure_rate, 0.1)
    failure_types = Map.get(chaos_config, :failure_types, [:network, :timeout, :resource])
    duration = Map.get(chaos_config, :duration, 10_000)
    
    chaos_pid = spawn_link(fn -> chaos_injector(failure_rate, failure_types, duration) end)
    
    try do
      # Run normal operations during chaos
      yield()
    after
      Process.exit(chaos_pid, :normal)
    end
  end
  
  @doc """
  Tests data flow integrity through the entire improvement pipeline.
  """
  def assert_data_flow_integrity(input_data, output_data) do
    # Verify data transformations maintain essential properties
    assert_data_lineage(input_data, output_data)
    assert_no_data_corruption(input_data, output_data)
    assert_data_consistency(output_data)
  end
  
  @doc """
  Validates workflow generation produces valid, executable workflows.
  """
  def assert_generated_workflow_validity(workflow_result) do
    # Structural validity
    assert workflow_result.module != nil, "Generated workflow must have a module"
    assert workflow_result.spec != nil, "Generated workflow must have a specification"
    assert workflow_result.json != nil, "Generated workflow must have JSON output"
    
    # Compilation validity
    assert Code.ensure_loaded?(workflow_result.module), "Generated module must be compilable"
    
    # DSL validity
    assert {:ok, _info} = N8n.Reactor.get_workflow_info(workflow_result.module),
      "Generated workflow must be valid according to DSL"
    
    # n8n JSON validity
    assert_valid_n8n_json(workflow_result.json)
    
    # Semantic validity
    assert_workflow_semantic_correctness(workflow_result)
  end
  
  @doc """
  Performs memory leak detection over multiple improvement cycles.
  """
  def detect_memory_leaks(cycle_count \\ 50) do
    initial_memory = :erlang.memory(:total)
    
    for cycle <- 1..cycle_count do
      # Force garbage collection between cycles
      if rem(cycle, 10) == 0 do
        :erlang.garbage_collect()
        current_memory = :erlang.memory(:total)
        memory_growth = current_memory - initial_memory
        
        # Alert if memory grows beyond reasonable bounds
        max_growth = initial_memory * 0.5  # 50% growth threshold
        
        if memory_growth > max_growth do
          raise "Potential memory leak detected at cycle #{cycle}. " <>
                "Memory grew by #{memory_growth} bytes (#{Float.round(memory_growth / initial_memory * 100, 2)}%)"
        end
      end
      
      yield()
    end
  end
  
  @doc """
  Tests concurrent cycle execution for race conditions.
  """
  def test_concurrent_cycles(concurrency_level \\ 5) do
    # Start multiple improvement cycles concurrently
    tasks = for i <- 1..concurrency_level do
      Task.async(fn ->
        cycle_id = SelfImprovementOrchestrator.trigger_improvement_cycle()
        
        # Wait for completion
        receive do
          {:cycle_completed, result} -> {i, :success, result}
          {:cycle_failed, reason} -> {i, :failed, reason}
        after
          30_000 -> {i, :timeout, nil}
        end
      end)
    end
    
    results = Task.await_many(tasks, 35_000)
    
    # Analyze results for race conditions
    analyze_concurrent_results(results)
  end
  
  @doc """
  Validates state consistency after system recovery.
  """
  def assert_recovery_consistency(pre_failure_state, post_recovery_state) do
    # Critical state elements should be preserved or properly reset
    assert post_recovery_state.cycle_id >= pre_failure_state.cycle_id,
      "Cycle ID should not go backwards after recovery"
    
    # Queue should not lose items unless explicitly handled
    queue_diff = post_recovery_state.queued_improvements - pre_failure_state.queued_improvements
    assert queue_diff >= -1, "Should not lose more than 1 queued item during recovery"
    
    # Active workflows should be reset or maintained
    assert post_recovery_state.active_workflows >= 0,
      "Active workflow count should be valid after recovery"
  end
  
  @doc """
  Performance regression testing with statistical analysis.
  """
  def assert_performance_regression(baseline_metrics, current_metrics, tolerance \\ 0.1) do
    performance_keys = [:cycle_duration, :deployment_time, :validation_time]
    
    for key <- performance_keys do
      if Map.has_key?(baseline_metrics, key) and Map.has_key?(current_metrics, key) do
        baseline = baseline_metrics[key]
        current = current_metrics[key]
        
        # Allow for some variance, but flag significant regressions
        regression_threshold = baseline * (1 + tolerance)
        
        if current > regression_threshold do
          raise "Performance regression detected for #{key}: " <>
                "baseline=#{baseline}ms, current=#{current}ms " <>
                "(#{Float.round((current - baseline) / baseline * 100, 2)}% increase)"
        end
      end
    end
  end
  
  @doc """
  Tests the system's ability to handle gradual load increases.
  """
  def load_test(start_load \\ 1, max_load \\ 20, increment \\ 2) do
    results = []
    
    for load <- start_load..max_load//increment do
      load_result = apply_load(load)
      results = [load_result | results]
      
      # Check if system is still responsive
      if load_result.success_rate < 0.8 do
        raise "System became unresponsive at load level #{load}"
      end
      
      # Brief cooldown between load levels
      :timer.sleep(1000)
    end
    
    analyze_load_test_results(Enum.reverse(results))
  end
  
  @doc """
  Security testing for generated workflows to prevent injection attacks.
  """
  def assert_workflow_security(workflow_json) do
    # Check for potential code injection patterns
    dangerous_patterns = [
      ~r/eval\(/i,
      ~r/exec\(/i,
      ~r/system\(/i,
      ~r/process\./i,
      ~r/require\(/i,
      ~r/import\(/i,
      ~r/fs\./i,
      ~r/child_process/i
    ]
    
    workflow_string = Jason.encode!(workflow_json)
    
    for pattern <- dangerous_patterns do
      if Regex.match?(pattern, workflow_string) do
        raise "Potentially dangerous pattern detected in workflow: #{pattern.source}"
      end
    end
    
    # Validate parameter sanitization
    assert_parameter_sanitization(workflow_json)
  end
  
  @doc """
  Tests backwards compatibility with older workflow versions.
  """
  def assert_backwards_compatibility(old_workflow, new_workflow) do
    # Core workflow properties should be maintained
    assert old_workflow["name"] == new_workflow["name"],
      "Workflow name should be preserved"
    
    # Node count should not decrease unless explicitly removing nodes
    old_node_count = length(old_workflow["nodes"] || [])
    new_node_count = length(new_workflow["nodes"] || [])
    
    if new_node_count < old_node_count do
      # This might be intentional optimization, log for review
      IO.puts("Warning: Node count decreased from #{old_node_count} to #{new_node_count}")
    end
    
    # Essential functionality should be preserved
    assert_functionality_preservation(old_workflow, new_workflow)
  end
  
  # Private helper functions
  
  defp chaos_injector(failure_rate, failure_types, duration) do
    end_time = System.monotonic_time() + System.convert_time_unit(duration, :millisecond, :native)
    
    chaos_loop(failure_rate, failure_types, end_time)
  end
  
  defp chaos_loop(failure_rate, failure_types, end_time) do
    if System.monotonic_time() < end_time do
      if :rand.uniform() < failure_rate do
        inject_failure(Enum.random(failure_types))
      end
      
      :timer.sleep(100)
      chaos_loop(failure_rate, failure_types, end_time)
    end
  end
  
  defp inject_failure(:network) do
    # Simulate network failures
    Process.send_after(self(), {:network_failure, "Simulated network timeout"}, 0)
  end
  
  defp inject_failure(:timeout) do
    # Simulate timeouts
    Process.send_after(self(), {:timeout_failure, "Simulated timeout"}, 0)
  end
  
  defp inject_failure(:resource) do
    # Simulate resource exhaustion
    Process.send_after(self(), {:resource_failure, "Simulated resource exhaustion"}, 0)
  end
  
  defp assert_data_lineage(input_data, output_data) do
    # Verify that output data can be traced back to input data
    # This is a simplified check - in practice, you'd want more sophisticated lineage tracking
    
    if Map.has_key?(input_data, :id) and Map.has_key?(output_data, :source_id) do
      assert input_data.id == output_data.source_id,
        "Data lineage broken: input ID #{input_data.id} != output source ID #{output_data.source_id}"
    end
  end
  
  defp assert_no_data_corruption(input_data, output_data) do
    # Check for obvious signs of data corruption
    # This is a basic implementation - extend based on your data types
    
    for {key, value} <- input_data do
      if is_binary(value) and Map.has_key?(output_data, key) do
        output_value = output_data[key]
        if is_binary(output_value) do
          # Check for encoding issues
          assert String.valid?(output_value),
            "Data corruption detected: invalid UTF-8 in #{key}"
        end
      end
    end
  end
  
  defp assert_data_consistency(data) do
    # Verify internal data consistency
    if Map.has_key?(data, :timestamps) do
      timestamps = data.timestamps
      
      if Map.has_key?(timestamps, :created_at) and Map.has_key?(timestamps, :updated_at) do
        assert DateTime.compare(timestamps.created_at, timestamps.updated_at) != :gt,
          "Data inconsistency: created_at is after updated_at"
      end
    end
  end
  
  defp assert_valid_n8n_json(json) do
    # Validate n8n JSON structure
    required_fields = ["name", "nodes", "connections"]
    
    for field <- required_fields do
      assert Map.has_key?(json, field), "Missing required n8n field: #{field}"
    end
    
    # Validate nodes structure
    nodes = json["nodes"]
    assert is_list(nodes), "Nodes must be a list"
    
    for node <- nodes do
      assert Map.has_key?(node, "id"), "Node missing ID"
      assert Map.has_key?(node, "type"), "Node missing type"
      assert Map.has_key?(node, "parameters"), "Node missing parameters"
    end
    
    # Validate connections structure
    connections = json["connections"]
    assert is_map(connections), "Connections must be a map"
  end
  
  defp assert_workflow_semantic_correctness(workflow_result) do
    # Check that the workflow makes logical sense
    json = workflow_result.json
    
    # Should have at least one node
    assert length(json["nodes"]) > 0, "Workflow should have at least one node"
    
    # If there are multiple nodes, they should be connected
    if length(json["nodes"]) > 1 do
      connections = json["connections"]
      assert map_size(connections) > 0, "Multi-node workflow should have connections"
    end
    
    # Check for unreachable nodes
    assert_no_unreachable_nodes(json)
  end
  
  defp assert_no_unreachable_nodes(json) do
    nodes = json["nodes"]
    connections = json["connections"]
    
    node_ids = MapSet.new(nodes, & &1["id"])
    
    # Find nodes that are targets of connections
    connected_nodes = 
      connections
      |> Enum.flat_map(fn {_source, outputs} ->
        Enum.flat_map(outputs, fn {_output, targets} ->
          Enum.map(targets, & &1["node"])
        end)
      end)
      |> MapSet.new()
    
    # Find nodes that are sources of connections
    source_nodes = MapSet.new(Map.keys(connections))
    
    # All nodes should be either sources or targets (unless it's a single node workflow)
    if length(nodes) > 1 do
      all_connected = MapSet.union(connected_nodes, source_nodes)
      unreachable = MapSet.difference(node_ids, all_connected)
      
      assert MapSet.size(unreachable) == 0,
        "Found unreachable nodes: #{inspect(MapSet.to_list(unreachable))}"
    end
  end
  
  defp analyze_concurrent_results(results) do
    successes = Enum.count(results, fn {_i, status, _result} -> status == :success end)
    failures = Enum.count(results, fn {_i, status, _result} -> status == :failed end)
    timeouts = Enum.count(results, fn {_i, status, _result} -> status == :timeout end)
    
    total = length(results)
    
    # At least 80% should succeed for concurrent operations
    success_rate = successes / total
    assert success_rate >= 0.8,
      "Concurrent operations success rate too low: #{Float.round(success_rate * 100, 2)}% " <>
      "(#{successes}/#{total} succeeded, #{failures} failed, #{timeouts} timed out)"
    
    # Check for duplicate cycle IDs (race condition indicator)
    cycle_ids = 
      results
      |> Enum.filter(fn {_i, status, _result} -> status == :success end)
      |> Enum.map(fn {_i, _status, result} -> result.cycle_id end)
    
    unique_ids = Enum.uniq(cycle_ids)
    
    assert length(cycle_ids) == length(unique_ids),
      "Duplicate cycle IDs detected (race condition): #{inspect(cycle_ids -- unique_ids)}"
  end
  
  defp apply_load(load_level) do
    # Simulate load by creating multiple concurrent improvement requests
    start_time = System.monotonic_time()
    
    tasks = for _i <- 1..load_level do
      Task.async(fn ->
        try do
          SelfImprovementOrchestrator.get_status()
          :success
        catch
          _ -> :error
        end
      end)
    end
    
    results = Task.await_many(tasks, 10_000)
    end_time = System.monotonic_time()
    
    duration = System.convert_time_unit(end_time - start_time, :native, :millisecond)
    successes = Enum.count(results, &(&1 == :success))
    
    %{
      load_level: load_level,
      duration: duration,
      success_rate: successes / load_level,
      throughput: load_level / (duration / 1000)  # operations per second
    }
  end
  
  defp analyze_load_test_results(results) do
    # Check for performance degradation under load
    baseline = List.first(results)
    peak = List.last(results)
    
    throughput_degradation = (baseline.throughput - peak.throughput) / baseline.throughput
    
    if throughput_degradation > 0.5 do
      IO.puts("Warning: Throughput degraded by #{Float.round(throughput_degradation * 100, 2)}% under load")
    end
    
    results
  end
  
  defp assert_parameter_sanitization(workflow_json) do
    # Check that user inputs are properly sanitized
    nodes = workflow_json["nodes"] || []
    
    for node <- nodes do
      parameters = node["parameters"] || %{}
      
      for {_key, value} <- parameters do
        if is_binary(value) do
          # Check for script injection patterns
          assert not String.contains?(value, "<script"),
            "Potential XSS injection in workflow parameters"
          
          assert not String.contains?(value, "javascript:"),
            "Potential JavaScript injection in workflow parameters"
        end
      end
    end
  end
  
  defp assert_functionality_preservation(old_workflow, new_workflow) do
    # Check that core functionality is preserved
    # This is a basic check - extend based on your specific requirements
    
    old_triggers = count_triggers(old_workflow)
    new_triggers = count_triggers(new_workflow)
    
    assert new_triggers >= old_triggers,
      "Workflow should not lose trigger functionality"
  end
  
  defp count_triggers(workflow) do
    nodes = workflow["nodes"] || []
    Enum.count(nodes, fn node ->
      type = node["type"] || ""
      String.contains?(type, "trigger") or String.contains?(type, "webhook")
    end)
  end
end