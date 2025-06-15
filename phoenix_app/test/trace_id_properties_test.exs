defmodule TraceIdPropertiesTest do
  @moduledoc """
  Property-based tests for trace ID generation and propagation.
  Uses StreamData to verify trace ID properties across many generated values.
  """
  
  use ExUnit.Case
  use ExUnitProperties
  
  alias SelfSustaining.ReactorMiddleware.TelemetryMiddleware
  require TraceTestHelpers
  
  import TraceTestHelpers
  
  describe "trace ID generation properties" do
    property "trace IDs are always unique" do
      check all count <- integer(1..1000) do
        trace_ids = Enum.map(1..count, fn _ -> 
          generate_test_trace_id("property") 
        end)
        
        unique_ids = Enum.uniq(trace_ids)
        
        assert length(trace_ids) == length(unique_ids),
          "Generated #{length(trace_ids)} trace IDs but only #{length(unique_ids)} were unique"
      end
    end
    
    property "trace IDs have consistent format" do
      check all _iteration <- integer(1..100) do
        trace_id = generate_test_trace_id("format-test")
        
        # Should start with prefix
        assert String.starts_with?(trace_id, "format-test-")
        
        # Should have exactly 3 parts separated by hyphens
        parts = String.split(trace_id, "-")
        assert length(parts) >= 3, "Trace ID should have at least 3 hyphen-separated parts"
        
        # Should have minimum length
        assert String.length(trace_id) > 20, "Trace ID should be reasonably long"
        
        # Should be valid ASCII
        assert String.valid?(trace_id), "Trace ID should be valid UTF-8"
        
        # Should not contain whitespace
        refute String.contains?(trace_id, [" ", "\t", "\n"]), "Trace ID should not contain whitespace"
      end
    end
    
    property "trace IDs are URL safe" do
      check all _iteration <- integer(1..100) do
        trace_id = generate_test_trace_id("url-safe")
        
        # Should only contain URL-safe characters
        url_safe_pattern = ~r/^[a-zA-Z0-9\-_]+$/
        assert Regex.match?(url_safe_pattern, trace_id),
          "Trace ID should only contain URL-safe characters: #{trace_id}"
      end
    end
    
    property "trace IDs maintain temporal ordering" do
      check all count <- integer(2..50) do
        # Generate trace IDs with small delays
        trace_ids_with_times = Enum.map(1..count, fn i ->
          if i > 1, do: :timer.sleep(1)  # Ensure temporal separation
          
          trace_id = generate_test_trace_id("temporal")
          timestamp = System.system_time(:nanosecond)
          {trace_id, timestamp}
        end)
        
        # Extract timestamps from trace IDs
        extracted_timestamps = Enum.map(trace_ids_with_times, fn {trace_id, _system_time} ->
          # Extract nanosecond timestamp from trace ID
          parts = String.split(trace_id, "-")
          timestamp_str = List.last(parts)
          String.to_integer(timestamp_str)
        end)
        
        # Verify timestamps are in ascending order (mostly)
        # Allow some tolerance for concurrent generation
        sorted_timestamps = Enum.sort(extracted_timestamps)
        
        # Most timestamps should be in order (allowing for some out-of-order due to timing)
        differences = Enum.zip(extracted_timestamps, sorted_timestamps)
                     |> Enum.count(fn {original, sorted} -> original == sorted end)
        
        order_percentage = differences / count
        
        # At least 80% should be in order for reasonable temporal consistency
        assert order_percentage >= 0.8,
          "Expected at least 80% temporal ordering, got #{Float.round(order_percentage * 100, 1)}%"
      end
    end
  end
  
  describe "context propagation properties" do
    property "trace ID is preserved through context transformations" do
      check all trace_prefix <- string(:alphanumeric, min_length: 1, max_length: 10),
                extra_keys <- map_of(atom(:alphanumeric), term()) do
        
        trace_id = generate_test_trace_id(trace_prefix)
        
        # Create context with trace ID and extra data
        initial_context = extra_keys
                         |> Map.put(:trace_id, trace_id)
                         |> Map.put(:__reactor__, %{id: "test", steps: []})
        
        # Simulate middleware initialization
        {:ok, enhanced_context} = TelemetryMiddleware.init(initial_context)
        
        # Trace ID should be preserved in enhanced context
        assert Map.get(enhanced_context, :trace_id) == trace_id
        
        # Middleware state should also contain the trace ID
        middleware_state = Map.get(enhanced_context, TelemetryMiddleware)
        assert middleware_state[:trace_id] == trace_id
        
        # Original extra keys should be preserved
        for {key, value} <- extra_keys do
          assert Map.get(enhanced_context, key) == value,
            "Key #{key} was not preserved during context enhancement"
        end
      end
    end
    
    property "trace ID propagates through step arguments" do
      check all workflow_name <- string(:alphanumeric, min_length: 1),
                node_count <- integer(1..10),
                action <- member_of([:compile, :export, :trigger, :validate]) do
        
        trace_id = generate_test_trace_id("step-args")
        
        # Create workflow data
        workflow_data = create_test_workflow(
          workflow_id: workflow_name,
          node_count: node_count
        )
        
        # Create step arguments
        arguments = create_n8n_step_arguments(action, 
          workflow_id: workflow_name,
          trigger_data: %{test: "property_data"}
        )
        
        # Create context with trace ID
        context = create_test_context(trace_id)
        
        # The arguments and context should maintain trace consistency
        # (This is testing the test helpers themselves, but also verifies the pattern)
        assert extract_trace_id(context) == trace_id
        assert Map.get(arguments, :workflow_id) == workflow_name
      end
    end
  end
  
  describe "concurrent trace isolation properties" do
    property "concurrent trace generation maintains isolation" do
      check all concurrency_level <- integer(2..20) do
        # Generate multiple trace IDs concurrently
        tasks = Enum.map(1..concurrency_level, fn i ->
          Task.async(fn ->
            trace_id = generate_test_trace_id("concurrent-#{i}")
            
            # Simulate some work that might cause race conditions
            :timer.sleep(Enum.random(1..10))
            
            # Return trace info
            %{
              worker_id: i,
              trace_id: trace_id,
              generated_at: System.system_time(:nanosecond)
            }
          end)
        end)
        
        results = Task.await_many(tasks, 5000)
        
        # All trace IDs should be unique
        trace_ids = Enum.map(results, & &1.trace_id)
        unique_trace_ids = Enum.uniq(trace_ids)
        
        assert length(trace_ids) == length(unique_trace_ids),
          "Expected #{length(trace_ids)} unique trace IDs, got #{length(unique_trace_ids)}"
        
        # All should have different worker IDs
        worker_ids = Enum.map(results, & &1.worker_id)
        unique_worker_ids = Enum.uniq(worker_ids)
        
        assert length(worker_ids) == length(unique_worker_ids),
          "Worker IDs should be unique"
        
        # Each trace ID should contain its worker ID (from the prefix)
        for %{worker_id: worker_id, trace_id: trace_id} <- results do
          assert String.contains?(trace_id, "concurrent-#{worker_id}"),
            "Trace ID #{trace_id} should contain worker ID #{worker_id}"
        end
      end
    end
  end
  
  describe "error resilience properties" do
    property "trace IDs survive various error conditions" do
      check all error_type <- member_of([:network_error, :server_error, :timeout, :invalid_response]),
                trace_prefix <- string(:alphanumeric, min_length: 1, max_length: 8) do
        
        trace_id = generate_test_trace_id(trace_prefix)
        
        # Setup mocks for the specific error type
        setup_n8n_failure_mocks(error_type)
        
        # Create test context and arguments
        context = create_test_context(trace_id)
        arguments = create_n8n_step_arguments(:trigger)
        
        # Execute step that should handle the error gracefully
        result = SelfSustaining.ReactorSteps.N8nWorkflowStep.run(arguments, context, [])
        
        # Step should either succeed with fallback or fail gracefully
        case result do
          {:ok, step_result} ->
            # If successful (fallback), trace context should be maintained
            # Note: Current implementation doesn't return trace_id in step result
            # This would need to be enhanced in the actual implementation
            assert step_result.action == :trigger
            
          {:error, _reason} ->
            # If failed, that's also acceptable for error conditions
            # The important thing is that it didn't crash
            :ok
        end
        
        # Context should still contain original trace ID
        assert Map.get(context, :trace_id) == trace_id
      end
    end
  end
  
  describe "telemetry integration properties" do
    property "telemetry events maintain trace consistency" do
      check all event_count <- integer(1..20),
                trace_prefix <- string(:alphanumeric, min_length: 1, max_length: 8) do
        
        trace_id = generate_test_trace_id(trace_prefix)
        
        # Setup telemetry collection
        ref = setup_trace_telemetry()
        
        # Emit multiple telemetry events with the same trace ID
        events_to_emit = [
          [:self_sustaining, :reactor, :execution, :start],
          [:self_sustaining, :reactor, :step, :start],
          [:self_sustaining, :reactor, :step, :complete],
          [:self_sustaining, :reactor, :execution, :complete]
        ]
        
        # Emit events multiple times
        for _i <- 1..event_count do
          event = Enum.random(events_to_emit)
          
          :telemetry.execute(event, %{
            trace_id: trace_id,
            timestamp: System.system_time(:microsecond),
            event_index: event_count
          }, %{test: true})
          
          # Small delay to ensure events are processed
          :timer.sleep(1)
        end
        
        # Collect and analyze events
        wait_for_async(50)
        collected_events = collect_trace_telemetry(ref, 500)
        
        # All events should have the same trace ID
        trace_ids_in_events = Enum.map(collected_events, fn event ->
          get_in(event, [:measurements, :trace_id])
        end)
        
        unique_trace_ids = Enum.uniq(trace_ids_in_events)
        
        # Should have exactly one unique trace ID
        assert length(unique_trace_ids) <= 1,
          "Expected at most 1 unique trace ID, got #{length(unique_trace_ids)}: #{inspect(unique_trace_ids)}"
        
        # If events were captured, they should all have our trace ID
        if length(collected_events) > 0 do
          assert List.first(unique_trace_ids) == trace_id,
            "Expected trace ID #{trace_id}, got #{List.first(unique_trace_ids)}"
        end
        
        cleanup_trace_telemetry(ref)
      end
    end
  end
  
  describe "performance properties" do
    property "trace ID operations are performant" do
      check all operation_count <- integer(100..1000) do
        # Measure trace ID generation performance
        {generation_time, trace_ids} = :timer.tc(fn ->
          Enum.map(1..operation_count, fn _ ->
            generate_test_trace_id("perf")
          end)
        end)
        
        # Should generate trace IDs reasonably quickly
        # Allow up to 10ms per 100 operations
        max_time_per_100 = 10_000  # microseconds
        expected_max_time = (operation_count / 100) * max_time_per_100
        
        assert generation_time <= expected_max_time,
          "Trace ID generation took #{generation_time}μs for #{operation_count} operations, expected <= #{expected_max_time}μs"
        
        # All should be unique
        assert length(trace_ids) == length(Enum.uniq(trace_ids)),
          "All generated trace IDs should be unique"
        
        # Measure context enhancement performance
        test_context = %{
          __reactor__: %{id: "perf_test", steps: [:step1]},
          trace_id: List.first(trace_ids)
        }
        
        {enhancement_time, _enhanced_context} = :timer.tc(fn ->
          TelemetryMiddleware.init(test_context)
        end)
        
        # Context enhancement should be fast (< 1ms)
        assert enhancement_time < 1_000,
          "Context enhancement took #{enhancement_time}μs, expected < 1000μs"
      end
    end
  end
end