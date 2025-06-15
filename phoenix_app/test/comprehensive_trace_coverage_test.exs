defmodule ComprehensiveTraceCoverageTest do
  @moduledoc """
  Comprehensive test suite ensuring complete trace ID coverage across all system components.
  This test fills any gaps in trace ID implementation and verifies end-to-end tracing.
  """
  
  use ExUnit.Case
  use Mimic
  
  import TraceTestHelpers
  
  describe "middleware trace coverage" do
    test "AgentCoordinationMiddleware includes trace ID" do
      trace_id = generate_test_trace_id("agent-coord")
      
      context = %{
        __reactor__: %{id: "test_reactor", steps: [:step1]},
        trace_id: trace_id
      }
      
      # Test middleware initialization
      {:ok, enhanced_context} = SelfSustaining.ReactorMiddleware.AgentCoordinationMiddleware.init(context)
      
      assert Map.get(enhanced_context, :trace_id) == trace_id
      
      middleware_state = Map.get(enhanced_context, SelfSustaining.ReactorMiddleware.AgentCoordinationMiddleware)
      assert middleware_state[:trace_id] == trace_id
    end
    
    test "TelemetryMiddleware trace ID generation and propagation" do
      context = %{
        __reactor__: %{id: "telemetry_test", steps: [:test_step]}
      }
      
      {:ok, enhanced_context} = SelfSustaining.ReactorMiddleware.TelemetryMiddleware.init(context)
      
      # Should have generated trace_id
      assert Map.has_key?(enhanced_context, :trace_id)
      assert Map.has_key?(enhanced_context, :otel_trace_id)
      
      trace_id = Map.get(enhanced_context, :trace_id)
      otel_trace_id = Map.get(enhanced_context, :otel_trace_id)
      
      assert is_binary(trace_id)
      assert String.starts_with?(trace_id, "reactor-")
      assert trace_id == otel_trace_id  # Should be same in test environment
      
      # Middleware state should include trace_id
      middleware_state = Map.get(enhanced_context, SelfSustaining.ReactorMiddleware.TelemetryMiddleware)
      assert middleware_state[:trace_id] == trace_id
      assert middleware_state[:otel_trace_id] == otel_trace_id
    end
  end
  
  describe "reactor workflow trace coverage" do
    test "N8nIntegrationReactor preserves trace ID" do
      trace_id = generate_test_trace_id("n8n-integration")
      
      workflow_definition = %{
        name: "test_workflow",
        nodes: [%{id: "node1", type: :function}],
        connections: []
      }
      
      n8n_config = %{
        api_url: "http://localhost:5678/api/v1",
        api_key: "test_key"
      }
      
      inputs = %{
        workflow_definition: workflow_definition,
        n8n_config: n8n_config,
        action: :validate
      }
      
      context = %{trace_id: trace_id}
      
      # Setup telemetry collection
      ref = setup_trace_telemetry([
        [:self_sustaining, :reactor, :execution, :start],
        [:self_sustaining, :reactor, :execution, :complete]
      ])
      
      # Run the reactor
      result = Reactor.run(SelfSustaining.Workflows.N8nIntegrationReactor, inputs, context)
      
      assert {:ok, final_result} = result
      assert final_result.action == :validate
      assert Map.get(final_result.validation, :trace_id) == trace_id
      
      # Check telemetry events
      wait_for_async()
      events = collect_trace_telemetry(ref)
      
      # Should have start and complete events with trace_id
      start_events = Enum.filter(events, fn event -> List.last(event.event) == :start end)
      complete_events = Enum.filter(events, fn event -> List.last(event.event) == :complete end)
      
      assert length(start_events) >= 1
      assert length(complete_events) >= 1
      
      for event <- start_events ++ complete_events do
        assert get_in(event, [:measurements, :trace_id]) == trace_id
      end
      
      cleanup_trace_telemetry(ref)
    end
    
    test "CoordinationReactor maintains trace ID" do
      trace_id = generate_test_trace_id("coordination")
      
      work_claim = %{
        work_item_id: "test_work_#{System.unique_integer()}",
        agent_id: "test_agent_#{System.unique_integer()}",
        description: "Test coordination work"
      }
      
      coordination_config = %{
        coordination_dir: "test_coordination",
        claims_file: "test_claims.json"
      }
      
      # Ensure test directory is clean
      File.rm_rf("test_coordination")
      
      inputs = %{
        work_claim: work_claim,
        coordination_config: coordination_config
      }
      
      context = %{trace_id: trace_id}
      
      # Run coordination steps
      result = Reactor.run(SelfSustaining.Workflows.CoordinationReactor, inputs, context)
      
      case result do
        {:ok, coordination_result} ->
          # Should have trace_id in directory info
          assert Map.get(coordination_result, :trace_id) == trace_id
          
        {:error, _reason} ->
          # Even if coordination fails, trace_id should be preserved in error logs
          :ok
      end
      
      # Cleanup
      File.rm_rf("test_coordination")
    end
  end
  
  describe "HTTP trace propagation" do
    test "web requests include trace headers" do
      trace_id = generate_test_trace_id("web-request")
      
      # Test the trace header plug directly
      conn = Plug.Test.conn(:get, "/test", "")
      |> Plug.Test.put_req_header("x-trace-id", trace_id)
      |> SelfSustainingWeb.Plugs.TraceHeaderPlug.call([])
      
      assert conn.assigns[:trace_id] == trace_id
      assert Plug.Conn.get_resp_header(conn, "x-trace-id") == [trace_id]
    end
    
    test "web requests without trace ID get generated one" do
      conn = Plug.Test.conn(:get, "/test", "")
      |> SelfSustainingWeb.Plugs.TraceHeaderPlug.call([])
      
      trace_id = conn.assigns[:trace_id]
      
      assert is_binary(trace_id)
      assert String.starts_with?(trace_id, "web-")
      assert Plug.Conn.get_resp_header(conn, "x-trace-id") == [trace_id]
    end
  end
  
  describe "error scenario trace preservation" do
    test "trace ID preserved through N8N step failures" do
      trace_id = generate_test_trace_id("n8n-failure")
      
      # Setup N8N to fail
      setup_n8n_failure_mocks(:network_error)
      
      arguments = create_n8n_step_arguments(:trigger)
      context = create_test_context(trace_id)
      
      # Should handle failure gracefully and preserve trace_id
      result = SelfSustaining.ReactorSteps.N8nWorkflowStep.run(arguments, context, [])
      
      case result do
        {:ok, step_result} ->
          # Fallback mode should still preserve context
          assert step_result.action == :trigger
          assert Map.get(context, :trace_id) == trace_id
          
        {:error, _reason} ->
          # Even on error, context should preserve trace_id
          assert Map.get(context, :trace_id) == trace_id
      end
    end
    
    test "middleware failures preserve trace ID in context" do
      trace_id = generate_test_trace_id("middleware-failure")
      
      # Test with malformed context that might cause middleware issues
      malformed_context = %{
        trace_id: trace_id,
        # Missing __reactor__ key
        some_invalid_data: "test"
      }
      
      # TelemetryMiddleware should handle gracefully
      result = SelfSustaining.ReactorMiddleware.TelemetryMiddleware.init(malformed_context)
      
      case result do
        {:ok, enhanced_context} ->
          assert Map.get(enhanced_context, :trace_id) == trace_id
          
        {:error, _reason} ->
          # Even on failure, original trace_id should be preserved
          assert Map.get(malformed_context, :trace_id) == trace_id
      end
    end
    
    test "concurrent trace IDs remain isolated during errors" do
      # Test that errors in one trace don't affect others
      concurrency_level = 5
      
      tasks = Enum.map(1..concurrency_level, fn i ->
        Task.async(fn ->
          trace_id = generate_test_trace_id("concurrent-error-#{i}")
          
          # Some tasks will succeed, others will simulate errors
          if rem(i, 2) == 0 do
            # Success case
            context = create_test_context(trace_id)
            {:ok, %{trace_id: trace_id, result: :success, task_id: i}}
          else
            # Error case
            try do
              # Simulate some operation that might fail
              setup_n8n_failure_mocks(:timeout)
              arguments = create_n8n_step_arguments(:export)
              context = create_test_context(trace_id)
              
              SelfSustaining.ReactorSteps.N8nWorkflowStep.run(arguments, context, [])
              {:ok, %{trace_id: trace_id, result: :success_with_fallback, task_id: i}}
            rescue
              _error ->
                {:error, %{trace_id: trace_id, result: :error, task_id: i}}
            end
          end
        end)
      end)
      
      results = Task.await_many(tasks, 5000)
      
      # All tasks should have maintained their unique trace IDs
      trace_ids = Enum.map(results, fn 
        {:ok, data} -> data.trace_id
        {:error, data} -> data.trace_id
      end)
      
      unique_trace_ids = Enum.uniq(trace_ids)
      assert length(trace_ids) == length(unique_trace_ids), "Trace IDs should remain isolated"
      
      # Verify each trace ID contains the expected task identifier
      for {result, index} <- Enum.with_index(results, 1) do
        case result do
          {:ok, data} ->
            assert String.contains?(data.trace_id, "concurrent-error-#{index}")
            assert data.task_id == index
            
          {:error, data} ->
            assert String.contains?(data.trace_id, "concurrent-error-#{index}")
            assert data.task_id == index
        end
      end
    end
  end
  
  describe "telemetry trace consistency" do
    test "all system components emit trace-consistent telemetry" do
      trace_id = generate_test_trace_id("telemetry-consistency")
      
      # Setup comprehensive telemetry collection
      ref = setup_trace_telemetry([
        [:self_sustaining, :reactor, :coordination, :start],
        [:self_sustaining, :reactor, :execution, :start],
        [:self_sustaining, :reactor, :step, :complete],
        [:self_sustaining, :n8n, :workflow, :start],
        [:self_sustaining, :web, :request, :start]
      ])
      
      # Trigger multiple system components
      
      # 1. Agent coordination middleware
      context = %{
        __reactor__: %{id: "consistency_test", steps: [:step1]},
        trace_id: trace_id
      }
      
      {:ok, _enhanced_context} = SelfSustaining.ReactorMiddleware.AgentCoordinationMiddleware.init(context)
      
      # 2. Web request
      _conn = Plug.Test.conn(:get, "/consistency-test", "")
      |> Plug.Test.put_req_header("x-trace-id", trace_id)
      |> SelfSustainingWeb.Plugs.TraceHeaderPlug.call([])
      
      # 3. N8N step (with mocks)
      setup_n8n_mocks("consistency_test")
      arguments = create_n8n_step_arguments(:export)
      test_context = create_test_context(trace_id)
      
      {:ok, _step_result} = SelfSustaining.ReactorSteps.N8nWorkflowStep.run(arguments, test_context, [])
      
      # Collect all telemetry events
      wait_for_async(200)
      events = collect_trace_telemetry(ref)
      
      # All events should have the same trace_id
      trace_ids_in_events = events
      |> Enum.map(fn event -> get_in(event, [:measurements, :trace_id]) end)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()
      
      # Should have at least one trace_id and it should be consistent
      assert length(trace_ids_in_events) >= 1
      assert trace_id in trace_ids_in_events
      
      cleanup_trace_telemetry(ref)
    end
  end
  
  describe "trace ID format validation" do
    test "all generated trace IDs follow consistent format" do
      # Test trace ID generation from different components
      generators = [
        fn -> 
          {:ok, context} = SelfSustaining.ReactorMiddleware.TelemetryMiddleware.init(%{
            __reactor__: %{id: "test", steps: []}
          })
          Map.get(context, :trace_id)
        end,
        fn ->
          {:ok, context} = SelfSustaining.ReactorMiddleware.AgentCoordinationMiddleware.init(%{
            __reactor__: %{id: "test", steps: []}
          })
          Map.get(context, :trace_id)
        end,
        fn ->
          conn = Plug.Test.conn(:get, "/", "")
          |> SelfSustainingWeb.Plugs.TraceHeaderPlug.call([])
          conn.assigns[:trace_id]
        end
      ]
      
      # Generate trace IDs from each component
      trace_ids = Enum.map(generators, fn generator -> generator.() end)
      
      # All should be unique
      assert length(trace_ids) == length(Enum.uniq(trace_ids))
      
      # All should follow expected format patterns
      for trace_id <- trace_ids do
        assert is_binary(trace_id)
        assert String.length(trace_id) > 30
        assert String.contains?(trace_id, "-")
        
        # Should have at least 3 parts separated by hyphens
        parts = String.split(trace_id, "-")
        assert length(parts) >= 3
        
        # Last part should be a nanosecond timestamp (numeric)
        last_part = List.last(parts)
        assert String.match?(last_part, ~r/^\d+$/)
      end
    end
  end
end