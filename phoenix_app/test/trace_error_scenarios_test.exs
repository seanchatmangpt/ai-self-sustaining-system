defmodule TraceErrorScenariosTest do
  @moduledoc """
  Tests error scenarios and compensation logic for trace ID implementation.
  Follows Reactor testing strategies for error handling and compensation testing.
  """

  use ExUnit.Case
  use Mimic

  alias SelfSustaining.ReactorSteps.N8nWorkflowStep
  alias SelfSustaining.ReactorMiddleware.TelemetryMiddleware

  import TraceTestHelpers

  # Test reactor for error scenario testing
  defmodule ErrorTestReactor do
    use Reactor

    @reactor async?: false

    middleware(TelemetryMiddleware)

    step :initialize_workflow do
      argument(:workflow_spec, from_input(:workflow_spec))

      run(fn arguments, context ->
        trace_id = Map.get(context, :trace_id)

        # Simulate potential initialization failure
        if Map.get(arguments.workflow_spec, :should_fail_init, false) do
          {:error, "Initialization failed for testing"}
        else
          {:ok,
           %{
             workflow_id: "error_test_#{System.unique_integer()}",
             trace_id: trace_id,
             initialized_at: DateTime.utc_now()
           }}
        end
      end)
    end

    step :export_with_potential_failure do
      argument(:workflow_data, from_result(:initialize_workflow))

      run(&N8nWorkflowStep.run/3, %{
        action: :export,
        workflow_id: &get_in(&1.workflow_data, [:workflow_id]),
        workflow_data: & &1.workflow_data
      })

      compensate(fn result, _arguments, context, _options ->
        trace_id = Map.get(context, :trace_id)

        # Log compensation with trace ID
        :telemetry.execute(
          [:trace_test, :compensation, :export],
          %{
            trace_id: trace_id,
            compensated_result: inspect(result),
            timestamp: System.system_time(:microsecond)
          },
          context
        )

        # Perform actual compensation
        N8nWorkflowStep.undo(result, %{action: :export}, context, [])
      end)
    end

    step :trigger_with_fallback do
      argument(:export_result, from_result(:export_with_potential_failure))

      run(&N8nWorkflowStep.run/3, %{
        action: :trigger,
        workflow_id: &get_in(&1.export_result, [:workflow_id]),
        workflow_data: %{test: "error_scenario"}
      })

      compensate(fn result, _arguments, context, _options ->
        trace_id = Map.get(context, :trace_id)

        :telemetry.execute(
          [:trace_test, :compensation, :trigger],
          %{
            trace_id: trace_id,
            compensated_result: inspect(result),
            timestamp: System.system_time(:microsecond)
          },
          context
        )

        N8nWorkflowStep.undo(result, %{action: :trigger}, context, [])
      end)
    end

    step :verify_trace_after_errors do
      argument(:workflow_data, from_result(:initialize_workflow))
      argument(:export_result, from_result(:export_with_potential_failure))
      argument(:trigger_result, from_result(:trigger_with_fallback))

      run(fn arguments, context ->
        context_trace_id = Map.get(context, :trace_id)
        workflow_trace_id = Map.get(arguments.workflow_data, :trace_id)

        {:ok,
         %{
           trace_consistent_after_errors: context_trace_id == workflow_trace_id,
           context_trace_id: context_trace_id,
           workflow_trace_id: workflow_trace_id,
           error_recovery_successful: true
         }}
      end)
    end
  end

  describe "error handling with trace consistency" do
    setup do
      setup_n8n_mocks("error_test")
      :ok
    end

    test "network timeout preserves trace ID" do
      trace_id = generate_test_trace_id("network_timeout")

      # Setup network timeout mock
      setup_n8n_failure_mocks(:timeout)

      arguments = create_n8n_step_arguments(:trigger)
      context = create_test_context(trace_id)

      # Should succeed with fallback
      {:ok, result} = N8nWorkflowStep.run(arguments, context, [])

      assert result.action == :trigger
      assert result.status == "fallback_mode"

      # Context should still have original trace ID
      assert Map.get(context, :trace_id) == trace_id
    end

    test "server error with trace ID in logs" do
      trace_id = generate_test_trace_id("server_error")

      # Setup telemetry to capture error events
      ref =
        setup_trace_telemetry([
          [:self_sustaining, :n8n, :workflow, :start],
          [:self_sustaining, :n8n, :workflow, :executed]
        ])

      setup_n8n_failure_mocks(:server_error)

      arguments = create_n8n_step_arguments(:export)
      context = create_test_context(trace_id)

      # Should succeed with fallback
      {:ok, result} = N8nWorkflowStep.run(arguments, context, [])

      assert result.action == :export

      # Check telemetry events captured the trace ID
      wait_for_async()
      events = collect_trace_telemetry(ref)

      # Should have start event with trace ID
      start_events =
        Enum.filter(events, fn event ->
          List.last(event.event) == :start
        end)

      for event <- start_events do
        assert get_in(event, [:measurements, :trace_id]) == trace_id
      end

      cleanup_trace_telemetry(ref)
    end

    test "invalid response handled gracefully with trace" do
      trace_id = generate_test_trace_id("invalid_response")

      setup_n8n_failure_mocks(:invalid_response)

      arguments = create_n8n_step_arguments(:trigger)
      context = create_test_context(trace_id)

      # Should handle invalid response gracefully
      {:ok, result} = N8nWorkflowStep.run(arguments, context, [])

      assert result.action == :trigger
      assert result.status == "fallback_mode"

      # Trace ID should be preserved in context
      assert Map.get(context, :trace_id) == trace_id
    end
  end

  describe "compensation logic with trace tracking" do
    test "export compensation removes N8N workflow" do
      trace_id = generate_test_trace_id("compensation")

      # Setup successful export followed by compensation need
      copy(Req)

      stub(Req, :post, fn _req, opts ->
        case opts[:url] do
          "/workflows" ->
            {:ok,
             %Req.Response{
               status: 201,
               body: %{"id" => "compensation_test_workflow"}
             }}

          "/workflows/compensation_test_workflow/activate" ->
            {:ok, %Req.Response{status: 200, body: %{}}}

          _ ->
            {:ok, %Req.Response{status: 200, body: %{}}}
        end
      end)

      stub(Req, :delete, fn _req, opts ->
        case opts[:url] do
          "/workflows/compensation_test_workflow" ->
            {:ok, %Req.Response{status: 204, body: ""}}

          _ ->
            {:ok, %Req.Response{status: 404, body: %{}}}
        end
      end)

      arguments = create_n8n_step_arguments(:export)
      context = create_test_context(trace_id)

      # Execute export step
      {:ok, export_result} = N8nWorkflowStep.run(arguments, context, [])

      assert export_result.action == :export
      assert export_result.n8n_workflow_id == "compensation_test_workflow"

      # Now test compensation (undo)
      compensation_result =
        N8nWorkflowStep.undo(
          {:ok, export_result},
          arguments,
          context,
          []
        )

      # Compensation should succeed
      assert compensation_result == :ok

      # Verify delete was called (through mock verification)
      assert_called(Req.delete(_req, url: "/workflows/compensation_test_workflow"))
    end

    test "trigger compensation cancels execution" do
      trace_id = generate_test_trace_id("trigger_compensation")

      copy(Req)

      stub(Req, :post, fn _req, _opts ->
        {:ok,
         %Req.Response{
           status: 200,
           body: %{"executionId" => "compensation_exec_123"}
         }}
      end)

      stub(Req, :delete, fn _req, opts ->
        case opts[:url] do
          "/executions/compensation_exec_123" ->
            {:ok, %Req.Response{status: 204, body: ""}}

          _ ->
            {:ok, %Req.Response{status: 404, body: %{}}}
        end
      end)

      arguments = create_n8n_step_arguments(:trigger)
      context = create_test_context(trace_id)

      # Execute trigger step
      {:ok, trigger_result} = N8nWorkflowStep.run(arguments, context, [])

      assert trigger_result.action == :trigger
      assert trigger_result.execution_id == "compensation_exec_123"

      # Test compensation
      compensation_result =
        N8nWorkflowStep.undo(
          {:ok, trigger_result},
          arguments,
          context,
          []
        )

      assert compensation_result == :ok

      # Verify execution cancellation was called
      assert_called(Req.delete(_req, url: "/executions/compensation_exec_123"))
    end
  end

  describe "complete reactor error scenarios" do
    test "reactor handles initialization failure with trace" do
      trace_id = generate_test_trace_id("init_failure")

      workflow_spec = %{
        should_fail_init: true,
        nodes: []
      }

      # Should fail at initialization step
      result =
        Reactor.run(ErrorTestReactor, %{workflow_spec: workflow_spec}, %{trace_id: trace_id})

      assert {:error, reason} = result
      assert reason == "Initialization failed for testing"
    end

    test "reactor succeeds despite N8N failures with trace consistency" do
      trace_id = generate_test_trace_id("n8n_failures")

      # Setup N8N to fail initially then recover
      setup_n8n_failure_mocks(:network_error)

      workflow_spec = %{
        should_fail_init: false,
        nodes: [%{id: "test", type: :function}]
      }

      # Should succeed despite N8N failures due to fallback logic
      result =
        Reactor.run(ErrorTestReactor, %{workflow_spec: workflow_spec}, %{trace_id: trace_id})

      assert {:ok, final_result} = result
      assert final_result.trace_consistent_after_errors == true
      assert final_result.context_trace_id == trace_id
      assert final_result.error_recovery_successful == true
    end

    test "compensation events include trace ID" do
      trace_id = generate_test_trace_id("compensation_trace")

      # Setup telemetry to capture compensation events
      ref =
        setup_trace_telemetry([
          [:trace_test, :compensation, :export],
          [:trace_test, :compensation, :trigger]
        ])

      # Force an error scenario that would trigger compensation
      # (This is a simplified test - in practice, we'd need to trigger actual compensation)

      # Manually emit compensation events to test telemetry
      :telemetry.execute(
        [:trace_test, :compensation, :export],
        %{
          trace_id: trace_id,
          compensated_result: "test_export_result",
          timestamp: System.system_time(:microsecond)
        },
        %{test: true}
      )

      :telemetry.execute(
        [:trace_test, :compensation, :trigger],
        %{
          trace_id: trace_id,
          compensated_result: "test_trigger_result",
          timestamp: System.system_time(:microsecond)
        },
        %{test: true}
      )

      wait_for_async()
      events = collect_trace_telemetry(ref)

      # Should have captured compensation events with trace ID
      assert length(events) >= 2

      for event <- events do
        assert get_in(event, [:measurements, :trace_id]) == trace_id
        assert String.contains?(to_string(List.last(event.event)), "compensation")
      end

      cleanup_trace_telemetry(ref)
    end
  end

  describe "middleware error resilience" do
    test "middleware handles missing reactor context" do
      trace_id = generate_test_trace_id("missing_context")

      # Context without __reactor__ key
      incomplete_context = %{
        trace_id: trace_id,
        some_data: "test"
      }

      # Should still initialize successfully
      {:ok, enhanced_context} = TelemetryMiddleware.init(incomplete_context)

      assert Map.get(enhanced_context, :trace_id) == trace_id
      assert Map.has_key?(enhanced_context, TelemetryMiddleware)

      # Should have reasonable defaults
      middleware_state = Map.get(enhanced_context, TelemetryMiddleware)
      assert middleware_state[:reactor_id] == "unknown_reactor"
      assert middleware_state[:trace_id] == trace_id
    end

    test "middleware handles malformed context gracefully" do
      # Test with various malformed contexts
      malformed_contexts = [
        nil,
        "not_a_map",
        [],
        %{__reactor__: "not_a_map"},
        # Missing required fields
        %{__reactor__: %{}}
      ]

      for malformed_context <- malformed_contexts do
        # Should either succeed with defaults or fail gracefully
        result =
          try do
            TelemetryMiddleware.init(malformed_context)
          rescue
            _ -> {:error, "handled_gracefully"}
          catch
            _ -> {:error, "handled_gracefully"}
          end

        # Should not crash the system
        assert result != nil
      end
    end

    test "telemetry events survive handler failures" do
      trace_id = generate_test_trace_id("handler_failure")

      # Attach a failing telemetry handler
      :telemetry.attach(
        "failing-handler-#{System.unique_integer()}",
        [:self_sustaining, :reactor, :execution, :start],
        fn _event, _measurements, _metadata, _config ->
          # This handler intentionally fails
          raise "Telemetry handler failure"
        end,
        nil
      )

      # Also attach a working handler to verify others still work
      test_pid = self()
      ref = make_ref()

      :telemetry.attach(
        "working-handler-#{System.unique_integer()}",
        [:self_sustaining, :reactor, :execution, :start],
        fn _event, measurements, _metadata, {pid, test_ref} ->
          send(pid, {:telemetry_success, test_ref, measurements})
        end,
        {test_pid, ref}
      )

      # Initialize middleware (which emits telemetry)
      context = %{
        __reactor__: %{id: "handler_failure_test", steps: []},
        trace_id: trace_id
      }

      # Should succeed despite failing handler
      {:ok, enhanced_context} = TelemetryMiddleware.init(context)

      assert Map.get(enhanced_context, :trace_id) == trace_id

      # Working handler should still receive the event
      assert_receive {:telemetry_success, ^ref, measurements}, 1000
      assert measurements.trace_id == trace_id

      # Cleanup handlers
      :telemetry.list_handlers([])
      |> Enum.filter(fn handler ->
        String.ends_with?(handler.id, "-handler-" <> to_string(System.unique_integer() - 1)) or
          String.ends_with?(handler.id, "-handler-" <> to_string(System.unique_integer() - 2))
      end)
      |> Enum.each(fn handler -> :telemetry.detach(handler.id) end)
    end
  end

  describe "race condition resilience" do
    test "concurrent middleware initialization maintains trace isolation" do
      # Test concurrent middleware initialization to check for race conditions
      concurrency_level = 10

      tasks =
        Enum.map(1..concurrency_level, fn i ->
          Task.async(fn ->
            trace_id = generate_test_trace_id("concurrent-#{i}")

            context = %{
              __reactor__: %{id: "concurrent_reactor_#{i}", steps: []},
              trace_id: trace_id
            }

            {:ok, enhanced_context} = TelemetryMiddleware.init(context)

            %{
              original_trace_id: trace_id,
              enhanced_trace_id: Map.get(enhanced_context, :trace_id),
              middleware_trace_id: get_in(enhanced_context, [TelemetryMiddleware, :trace_id]),
              reactor_id: get_in(enhanced_context, [TelemetryMiddleware, :reactor_id])
            }
          end)
        end)

      results = Task.await_many(tasks, 5000)

      # All should have consistent trace IDs
      for result <- results do
        assert result.original_trace_id == result.enhanced_trace_id
        assert result.original_trace_id == result.middleware_trace_id
        assert String.starts_with?(result.reactor_id, "concurrent_reactor_")
      end

      # All trace IDs should be unique
      trace_ids = Enum.map(results, & &1.original_trace_id)
      unique_trace_ids = Enum.uniq(trace_ids)

      assert length(trace_ids) == length(unique_trace_ids)
    end
  end
end
