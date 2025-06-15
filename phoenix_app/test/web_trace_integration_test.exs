defmodule WebTraceIntegrationTest do
  @moduledoc """
  Tests trace ID propagation through web requests and error scenarios.
  Ensures trace IDs are properly handled in HTTP requests, LiveView, and error conditions.
  """
  
  use ExUnit.Case
  use Plug.Test
  
  alias SelfSustainingWeb.Plugs.TraceHeaderPlug
  
  describe "TraceHeaderPlug" do
    test "extracts trace ID from X-Trace-ID header" do
      trace_id = "test-trace-123"
      
      conn = conn(:get, "/", "")
      |> put_req_header("x-trace-id", trace_id)
      |> TraceHeaderPlug.call([])
      
      assert conn.assigns[:trace_id] == trace_id
      assert get_resp_header(conn, "x-trace-id") == [trace_id]
    end
    
    test "extracts trace ID from legacy X-Correlation-ID header" do
      trace_id = "legacy-correlation-123"
      
      conn = conn(:get, "/", "")
      |> put_req_header("x-correlation-id", trace_id)
      |> TraceHeaderPlug.call([])
      
      assert conn.assigns[:trace_id] == trace_id
      assert get_resp_header(conn, "x-trace-id") == [trace_id]
    end
    
    test "extracts trace ID from W3C traceparent header" do
      traceparent = "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01"
      expected_trace_id = "otel-4bf92f3577b34da6a3ce929d0e0e4736"
      
      conn = conn(:get, "/", "")
      |> put_req_header("traceparent", traceparent)
      |> TraceHeaderPlug.call([])
      
      assert conn.assigns[:trace_id] == expected_trace_id
      assert get_resp_header(conn, "x-trace-id") == [expected_trace_id]
    end
    
    test "generates new trace ID when none provided" do
      conn = conn(:get, "/", "")
      |> TraceHeaderPlug.call([])
      
      trace_id = conn.assigns[:trace_id]
      
      assert is_binary(trace_id)
      assert String.starts_with?(trace_id, "web-")
      assert String.length(trace_id) > 40
      assert get_resp_header(conn, "x-trace-id") == [trace_id]
    end
    
    test "emits telemetry events with trace ID" do
      # Setup telemetry collection
      test_pid = self()
      ref = make_ref()
      
      :telemetry.attach(
        "test-web-trace-#{System.unique_integer()}",
        [:self_sustaining, :web, :request, :start],
        fn _event, measurements, metadata, {pid, test_ref} ->
          send(pid, {:telemetry_event, test_ref, measurements, metadata})
        end,
        {test_pid, ref}
      )
      
      trace_id = "telemetry-test-123"
      
      conn = conn(:get, "/test-path", "")
      |> put_req_header("x-trace-id", trace_id)
      |> TraceHeaderPlug.call([])
      
      # Should receive telemetry event
      assert_receive {:telemetry_event, ^ref, measurements, metadata}, 1000
      
      assert measurements.trace_id == trace_id
      assert metadata.trace_id == trace_id
      assert metadata.method == "GET"
      assert metadata.path == "/test-path"
      
      # Cleanup
      :telemetry.detach("test-web-trace-#{System.unique_integer()}")
    end
    
    test "handles malformed traceparent header gracefully" do
      malformed_traceparent = "invalid-format-header"
      
      conn = conn(:get, "/", "")
      |> put_req_header("traceparent", malformed_traceparent)
      |> TraceHeaderPlug.call([])
      
      # Should generate new trace ID instead of crashing
      trace_id = conn.assigns[:trace_id]
      assert is_binary(trace_id)
      assert String.starts_with?(trace_id, "web-")
    end
  end
  
  describe "trace ID uniqueness across requests" do
    test "generates unique trace IDs for concurrent requests" do
      # Simulate multiple concurrent requests
      tasks = Enum.map(1..10, fn _i ->
        Task.async(fn ->
          conn = conn(:get, "/", "")
          |> TraceHeaderPlug.call([])
          
          conn.assigns[:trace_id]
        end)
      end)
      
      trace_ids = Task.await_many(tasks, 1000)
      unique_ids = Enum.uniq(trace_ids)
      
      assert length(trace_ids) == length(unique_ids), "All trace IDs should be unique"
      
      # All should follow expected format
      for trace_id <- trace_ids do
        assert String.starts_with?(trace_id, "web-")
        assert String.length(trace_id) > 40
      end
    end
  end
  
  describe "error scenario trace propagation" do
    test "trace ID preserved through error conditions" do
      trace_id = "error-scenario-123"
      
      # Simulate a plug that might raise an error
      error_plug = fn conn, _opts ->
        # Trace ID should still be available even if subsequent plugs fail
        assert conn.assigns[:trace_id] == trace_id
        
        # Simulate an error scenario
        if get_req_header(conn, "force-error") != [] do
          raise "Simulated error"
        end
        
        conn
      end
      
      # Normal case - should work fine
      conn = conn(:get, "/", "")
      |> put_req_header("x-trace-id", trace_id)
      |> TraceHeaderPlug.call([])
      |> error_plug.([])
      
      assert conn.assigns[:trace_id] == trace_id
      
      # Error case - trace ID should still be in conn even if plug fails
      assert_raise RuntimeError, "Simulated error", fn ->
        conn(:get, "/", "")
        |> put_req_header("x-trace-id", trace_id)
        |> put_req_header("force-error", "true")
        |> TraceHeaderPlug.call([])
        |> error_plug.([])
      end
    end
    
    test "trace ID included in error telemetry" do
      trace_id = "error-telemetry-123"
      
      # Setup error telemetry collection
      test_pid = self()
      ref = make_ref()
      
      :telemetry.attach(
        "test-error-trace-#{System.unique_integer()}",
        [:self_sustaining, :web, :request, :complete],
        fn _event, measurements, metadata, {pid, test_ref} ->
          send(pid, {:error_telemetry, test_ref, measurements, metadata})
        end,
        {test_pid, ref}
      )
      
      # Create connection with trace ID and trigger completion callback
      conn = conn(:get, "/error-test", "")
      |> put_req_header("x-trace-id", trace_id)
      |> TraceHeaderPlug.call([])
      |> put_status(500)  # Simulate error response
      |> send_resp(500, "Error")
      
      # The before_send callback should have triggered
      assert_receive {:error_telemetry, ^ref, measurements, metadata}, 1000
      
      assert measurements.trace_id == trace_id
      assert measurements.status == 500
      assert metadata.trace_id == trace_id
      assert metadata.status == 500
      
      # Cleanup
      :telemetry.detach("test-error-trace-#{System.unique_integer()}")
    end
  end
end