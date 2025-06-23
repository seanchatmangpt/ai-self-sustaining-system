defmodule TraceTestHelpers do
  @moduledoc """
  Test helpers for trace ID testing following Reactor testing strategies.
  Provides reusable utilities for mocking, context setup, and trace verification.
  """

  import ExUnit.Assertions
  import Mimic

  @doc """
  Sets up N8N API mocks with predictable responses for testing.
  """
  def setup_n8n_mocks(workflow_prefix \\ "test") do
    copy(Req)

    stub(Req, :new, fn opts ->
      # Return a mock Req struct
      %{
        base_url: opts[:base_url],
        headers: opts[:headers] || [],
        options: opts
      }
    end)

    stub(Req, :post, fn _req, opts ->
      handle_n8n_request(opts[:url], opts[:json], workflow_prefix)
    end)

    stub(Req, :delete, fn _req, opts ->
      handle_n8n_delete(opts[:url])
    end)
  end

  defp handle_n8n_request(url, _json, workflow_prefix) do
    case url do
      "/workflows" ->
        {:ok,
         %Req.Response{
           status: 201,
           body: %{"id" => "#{workflow_prefix}_workflow_#{System.unique_integer()}"}
         }}

      "/workflows/" <> workflow_id <> "/activate" ->
        {:ok,
         %Req.Response{
           status: 200,
           body: %{"active" => true, "id" => workflow_id}
         }}

      "/workflows/" <> workflow_id <> "/test" ->
        {:ok,
         %Req.Response{
           status: 200,
           body: %{
             "executionId" => "exec_#{System.unique_integer()}",
             "status" => "running",
             "workflowId" => workflow_id
           }
         }}

      "/workflows/" <> workflow_id <> "/execute" ->
        {:ok,
         %Req.Response{
           status: 200,
           body: %{
             "executionId" => "exec_#{System.unique_integer()}",
             "status" => "running",
             "workflowId" => workflow_id
           }
         }}

      _ ->
        {:ok, %Req.Response{status: 200, body: %{}}}
    end
  end

  defp handle_n8n_delete(url) do
    case url do
      "/workflows/" <> _workflow_id ->
        {:ok, %Req.Response{status: 204, body: ""}}

      "/executions/" <> _execution_id ->
        {:ok, %Req.Response{status: 204, body: ""}}

      _ ->
        {:ok, %Req.Response{status: 404, body: %{"error" => "Not found"}}}
    end
  end

  @doc """
  Sets up N8N API mocks to simulate failures for error testing.
  """
  def setup_n8n_failure_mocks(failure_type \\ :network_error) do
    copy(Req)

    stub(Req, :new, fn opts ->
      %{
        base_url: opts[:base_url],
        headers: opts[:headers] || [],
        options: opts
      }
    end)

    case failure_type do
      :network_error ->
        stub(Req, :post, fn _req, _opts ->
          {:error, %Req.TransportError{reason: :econnrefused}}
        end)

      :server_error ->
        stub(Req, :post, fn _req, _opts ->
          {:ok,
           %Req.Response{
             status: 500,
             body: %{"error" => "Internal server error"}
           }}
        end)

      :timeout ->
        stub(Req, :post, fn _req, _opts ->
          {:error, %Req.TransportError{reason: :timeout}}
        end)

      :invalid_response ->
        stub(Req, :post, fn _req, _opts ->
          {:ok,
           %Req.Response{
             status: 200,
             body: "invalid json response"
           }}
        end)
    end
  end

  @doc """
  Creates a test context with trace ID and N8N configuration.
  """
  def create_test_context(trace_id, opts \\ []) do
    base_context = %{
      trace_id: trace_id,
      otel_trace_id: trace_id,
      test_mode: true
    }

    # Add N8N config if requested
    context =
      if Keyword.get(opts, :with_n8n_config, true) do
        Map.put(base_context, :private, %{
          inputs: %{
            n8n_config: %{
              api_url: "http://localhost:5678/api/v1",
              api_key: "test_api_key_#{System.unique_integer()}",
              timeout: 10_000
            }
          }
        })
      else
        base_context
      end

    # Add reactor metadata if requested
    if Keyword.get(opts, :with_reactor_metadata, false) do
      Map.put(context, :__reactor__, %{
        id: "test_reactor_#{System.unique_integer()}",
        steps: Keyword.get(opts, :steps, [:step1, :step2])
      })
    else
      context
    end
  end

  @doc """
  Creates test workflow data for testing.
  """
  def create_test_workflow(opts \\ []) do
    workflow_id = Keyword.get(opts, :workflow_id, "test_workflow_#{System.unique_integer()}")
    node_count = Keyword.get(opts, :node_count, 2)

    nodes =
      Enum.map(1..node_count, fn i ->
        %{
          id: "node_#{i}",
          name: "Test Node #{i}",
          type: Keyword.get(opts, :node_type, :function),
          parameters: %{
            code: "return {processed: true, node: #{i}}"
          },
          position: [i * 100, 100]
        }
      end)

    connections =
      if node_count > 1 do
        Enum.map(1..(node_count - 1), fn i ->
          %{from: "node_#{i}", to: "node_#{i + 1}"}
        end)
      else
        []
      end

    %{
      name: workflow_id,
      nodes: nodes,
      connections: connections,
      metadata: %{
        created_for: "testing",
        test_options: opts
      }
    }
  end

  @doc """
  Verifies trace ID consistency across multiple results.
  """
  def assert_trace_consistency(results, expected_trace_id) when is_list(results) do
    for {result, index} <- Enum.with_index(results, 1) do
      actual_trace_id = extract_trace_id(result)

      assert actual_trace_id == expected_trace_id,
             "Result #{index} has inconsistent trace ID: expected #{expected_trace_id}, got #{actual_trace_id}"
    end

    :ok
  end

  def assert_trace_consistency(result, expected_trace_id) do
    assert_trace_consistency([result], expected_trace_id)
  end

  @doc """
  Extracts trace ID from various result formats.
  """
  def extract_trace_id(result) when is_map(result) do
    cond do
      Map.has_key?(result, :trace_id) -> result.trace_id
      Map.has_key?(result, "trace_id") -> result["trace_id"]
      Map.has_key?(result, :context_trace_id) -> result.context_trace_id
      true -> nil
    end
  end

  def extract_trace_id(_), do: nil

  @doc """
  Sets up telemetry collection for trace testing.
  """
  def setup_trace_telemetry(events \\ nil) do
    events =
      events ||
        [
          [:self_sustaining, :reactor, :execution, :start],
          [:self_sustaining, :reactor, :execution, :complete],
          [:self_sustaining, :reactor, :step, :start],
          [:self_sustaining, :reactor, :step, :complete],
          [:self_sustaining, :n8n, :workflow, :start],
          [:self_sustaining, :n8n, :workflow, :executed]
        ]

    test_pid = self()
    ref = make_ref()

    for event <- events do
      :telemetry.attach(
        "trace-test-#{System.unique_integer()}",
        event,
        fn event_name, measurements, metadata, {pid, test_ref} ->
          send(
            pid,
            {:trace_telemetry, test_ref,
             %{
               event: event_name,
               measurements: measurements,
               metadata: metadata,
               captured_at: System.system_time(:microsecond)
             }}
          )
        end,
        {test_pid, ref}
      )
    end

    ref
  end

  @doc """
  Collects telemetry events for analysis.
  """
  def collect_trace_telemetry(ref, timeout \\ 1000) do
    collect_events(ref, [], System.monotonic_time(:millisecond) + timeout)
  end

  defp collect_events(ref, events, end_time) do
    if System.monotonic_time(:millisecond) >= end_time do
      Enum.reverse(events)
    else
      receive do
        {:trace_telemetry, ^ref, event} ->
          collect_events(ref, [event | events], end_time)
      after
        50 ->
          collect_events(ref, events, end_time)
      end
    end
  end

  @doc """
  Cleans up telemetry handlers.
  """
  def cleanup_trace_telemetry(_ref) do
    :telemetry.list_handlers([])
    |> Enum.filter(fn handler -> String.starts_with?(handler.id, "trace-test-") end)
    |> Enum.each(fn handler -> :telemetry.detach(handler.id) end)
  end

  @doc """
  Analyzes telemetry events for trace consistency.
  """
  def analyze_trace_telemetry(events, expected_trace_id) do
    total_events = length(events)

    trace_consistent_events =
      Enum.count(events, fn event ->
        get_in(event, [:measurements, :trace_id]) == expected_trace_id
      end)

    events_by_type =
      Enum.group_by(events, fn event ->
        event.event |> Enum.take(-1) |> List.first()
      end)

    %{
      total_events: total_events,
      trace_consistent_events: trace_consistent_events,
      consistency_rate: if(total_events > 0, do: trace_consistent_events / total_events, else: 0),
      perfect_consistency: trace_consistent_events == total_events,
      events_by_type:
        Enum.into(events_by_type, %{}, fn {type, type_events} ->
          {type, length(type_events)}
        end),
      trace_ids_found:
        events
        |> Enum.map(fn event -> get_in(event, [:measurements, :trace_id]) end)
        |> Enum.uniq()
        |> Enum.reject(&is_nil/1)
    }
  end

  @doc """
  Generates a test trace ID with optional prefix.
  """
  def generate_test_trace_id(prefix \\ "test") do
    "#{prefix}-#{System.system_time(:nanosecond)}-#{:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)}"
  end

  @doc """
  Waits for async operations to complete in tests.
  """
  def wait_for_async(timeout \\ 100) do
    :timer.sleep(timeout)
  end

  @doc """
  Creates N8N step arguments for testing.
  """
  def create_n8n_step_arguments(action, opts \\ []) do
    workflow_id = Keyword.get(opts, :workflow_id, "test_workflow_#{System.unique_integer()}")

    base_args = %{
      workflow_id: workflow_id,
      action: action
    }

    case action do
      :compile ->
        Map.put(base_args, :workflow_data, create_test_workflow(workflow_id: workflow_id))

      :export ->
        Map.put(base_args, :workflow_data, create_test_workflow(workflow_id: workflow_id))

      :trigger ->
        Map.put(base_args, :workflow_data, Keyword.get(opts, :trigger_data, %{test: "data"}))

      :validate ->
        base_args

      _ ->
        base_args
    end
  end

  @doc """
  Asserts that HTTP headers contain trace information.
  """
  def assert_trace_headers(headers, expected_trace_id) when is_list(headers) do
    trace_header = Enum.find(headers, fn {name, _value} -> name == "x-trace-id" end)

    assert trace_header != nil, "Expected x-trace-id header to be present"

    {_name, trace_id_value} = trace_header

    assert trace_id_value == expected_trace_id,
           "Expected trace ID #{expected_trace_id} in headers, got #{trace_id_value}"

    :ok
  end

  def assert_trace_headers(_, _), do: raise("Headers must be a list of tuples")
end
