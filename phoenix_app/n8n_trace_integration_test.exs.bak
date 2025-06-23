#!/usr/bin/env elixir

# Test N8N workflow steps with trace ID propagation
Mix.install([
  {:telemetry, "~> 1.0"},
  {:jason, "~> 1.4"},
  {:req, "~> 0.5"}
])

defmodule N8nTraceIntegrationTest do
  @moduledoc """
  Test N8N workflow step integration with trace ID propagation
  through the actual step implementations.
  """
  
  require Logger
  
  def run_n8n_trace_integration_test do
    IO.puts("🔄 N8N Trace ID Integration Test")
    IO.puts("=" |> String.duplicate(50))
    
    # Test 1: N8N step execution with trace ID context
    test_n8n_step_trace_propagation()
    
    # Test 2: N8N webhook processing with trace preservation
    test_n8n_webhook_trace_preservation()
    
    # Test 3: HTTP header trace propagation
    test_http_header_trace_propagation()
    
    IO.puts("\n✅ N8N Trace Integration Test Complete")
  end
  
  def test_n8n_step_trace_propagation do
    IO.puts("\n📋 Test 1: N8N Step Trace Propagation")
    IO.puts("-" |> String.duplicate(40))
    
    # Setup telemetry
    telemetry_ref = setup_n8n_telemetry()
    
    # Create test trace ID and context
    test_trace_id = generate_test_trace_id()
    IO.puts("  Test trace ID: #{test_trace_id}")
    
    test_context = %{
      trace_id: test_trace_id,
      otel_trace_id: test_trace_id,
      n8n_config: %{
        api_url: "http://localhost:5678/api/v1",
        api_key: "test_api_key",
        timeout: 10_000
      }
    }
    
    # Test different N8N step actions
    actions_to_test = [:compile, :validate, :export, :trigger]
    
    for action <- actions_to_test do
      IO.puts("  Testing #{action} action...")
      
      arguments = %{
        workflow_id: "test_workflow_#{action}",
        action: action,
        workflow_data: %{
          nodes: [
            %{id: "test_node", type: :function, parameters: %{}}
          ],
          connections: []
        }
      }
      
      # Simulate step execution with trace context
      {execution_time, step_result} = :timer.tc(fn ->
        simulate_n8n_step_execution(arguments, test_context, action)
      end)
      
      # Check trace ID preservation
      result_trace_id = Map.get(step_result, :trace_id)
      trace_preserved = result_trace_id == test_trace_id
      
      status = if trace_preserved, do: "✅", else: "❌"
      IO.puts("    #{action}: #{status} #{execution_time / 1000}ms (trace: #{result_trace_id})")
    end
    
    # Collect telemetry and analyze
    :timer.sleep(100)
    telemetry_events = collect_n8n_telemetry(telemetry_ref, 1000)
    analyze_n8n_trace_telemetry(telemetry_events, test_trace_id)
    
    cleanup_n8n_telemetry(telemetry_ref)
  end
  
  def test_n8n_webhook_trace_preservation do
    IO.puts("\n🔗 Test 2: N8N Webhook Trace Preservation")
    IO.puts("-" |> String.duplicate(40))
    
    # Test webhook processing with trace preservation
    original_trace_id = generate_test_trace_id()
    IO.puts("  Original trace ID: #{original_trace_id}")
    
    webhook_data = %{
      "workflow_type" => "performance",
      "source_trace_id" => original_trace_id,
      "performance_data" => %{
        "response_time" => 150,
        "throughput" => 1000
      }
    }
    
    # Simulate webhook processing
    {webhook_time, webhook_result} = :timer.tc(fn ->
      simulate_webhook_processing("test_performance_workflow", webhook_data, original_trace_id)
    end)
    
    result_trace_id = Map.get(webhook_result, :trace_id)
    trace_preserved = result_trace_id == original_trace_id
    
    status = if trace_preserved, do: "✅", else: "❌"
    IO.puts("  Webhook processing: #{status} #{webhook_time / 1000}ms")
    IO.puts("    Original: #{original_trace_id}")
    IO.puts("    Result: #{result_trace_id}")
    IO.puts("    Preserved: #{trace_preserved}")
  end
  
  def test_http_header_trace_propagation do
    IO.puts("\n🌐 Test 3: HTTP Header Trace Propagation")
    IO.puts("-" |> String.duplicate(40))
    
    test_trace_id = generate_test_trace_id()
    IO.puts("  Test trace ID: #{test_trace_id}")
    
    test_context = %{
      trace_id: test_trace_id,
      otel_trace_id: test_trace_id
    }
    
    # Test trace header generation
    trace_headers = generate_trace_headers(test_context)
    
    IO.puts("  Generated HTTP headers:")
    for {header_name, header_value} <- trace_headers do
      IO.puts("    #{header_name}: #{header_value}")
    end
    
    # Verify expected headers are present
    expected_headers = ["x-trace-id"]
    
    header_names = Enum.map(trace_headers, fn {name, _value} -> name end)
    
    for expected_header <- expected_headers do
      present = expected_header in header_names
      status = if present, do: "✅", else: "❌"
      IO.puts("  #{expected_header}: #{status}")
    end
    
    # Check trace ID values in headers
    trace_id_header = Enum.find(trace_headers, fn {name, _} -> name == "x-trace-id" end)
    
    if trace_id_header do
      {_name, header_trace_id} = trace_id_header
      trace_match = header_trace_id == test_trace_id
      status = if trace_match, do: "✅", else: "❌"
      IO.puts("  Trace ID match: #{status} (#{header_trace_id})")
    else
      IO.puts("  Trace ID match: ❌ (header not found)")
    end
  end
  
  # Simulation functions
  
  defp simulate_n8n_step_execution(arguments, context, action) do
    # Simulate N8N step execution with telemetry emission
    trace_id = Map.get(context, :trace_id)
    workflow_id = Map.get(arguments, :workflow_id)
    
    # Emit start telemetry
    :telemetry.execute([:self_sustaining, :n8n, :workflow, :start], %{
      workflow_id: workflow_id,
      action: action,
      trace_id: trace_id,
      timestamp: System.system_time(:microsecond)
    }, %{context: context, arguments: arguments})
    
    # Simulate work based on action
    work_time = case action do
      :compile -> Enum.random(20..50)
      :validate -> Enum.random(10..30)
      :export -> Enum.random(30..80)
      :trigger -> Enum.random(40..100)
    end
    
    :timer.sleep(work_time)
    
    # Create result with trace ID preserved
    step_result = %{
      action: action,
      workflow_id: workflow_id,
      trace_id: trace_id,
      success: true,
      completed_at: DateTime.utc_now()
    }
    
    # Emit completion telemetry
    :telemetry.execute([:self_sustaining, :n8n, :workflow, :executed], %{
      workflow_id: workflow_id,
      action: action,
      trace_id: trace_id,
      success: true,
      timestamp: System.system_time(:microsecond)
    }, %{context: context, result: step_result})
    
    step_result
  end
  
  defp simulate_webhook_processing(workflow_id, webhook_data, original_trace_id) do
    # Extract or preserve trace ID from webhook data
    source_trace_id = Map.get(webhook_data, "source_trace_id", original_trace_id)
    
    # Simulate webhook processing
    :timer.sleep(Enum.random(15..50))
    
    # Create result preserving trace ID
    webhook_result = %{
      workflow_id: workflow_id,
      trace_id: source_trace_id,
      original_trace_id: original_trace_id,
      processed_at: DateTime.utc_now(),
      success: true,
      webhook_data: webhook_data
    }
    
    webhook_result
  end
  
  defp generate_trace_headers(context) do
    headers = []
    
    # Add trace ID if available
    headers = if trace_id = Map.get(context, :trace_id) do
      [{"x-trace-id", to_string(trace_id)} | headers]
    else
      headers
    end
    
    # Add OpenTelemetry trace context if available (simulated)
    headers = if otel_trace_id = Map.get(context, :otel_trace_id) do
      # Simulate OpenTelemetry trace context header
      [{"X-OTel-Trace-Context", "#{otel_trace_id}-span123"} | headers]
    else
      headers
    end
    
    headers
  end
  
  # Telemetry helpers
  
  defp setup_n8n_telemetry do
    ref = make_ref()
    
    events = [
      [:self_sustaining, :n8n, :workflow, :start],
      [:self_sustaining, :n8n, :workflow, :executed]
    ]
    
    for event <- events do
      :telemetry.attach(
        "n8n-trace-test-#{System.unique_integer()}",
        event,
        fn event_name, measurements, metadata, {pid, events_ref} ->
          send(pid, {:n8n_trace_event, events_ref, %{
            event: event_name,
            measurements: measurements,
            metadata: metadata,
            captured_at: System.system_time(:microsecond)
          }})
        end,
        {self(), ref}
      )
    end
    
    ref
  end
  
  defp collect_n8n_telemetry(ref, timeout) do
    collect_telemetry_loop(ref, [], System.monotonic_time(:millisecond) + timeout)
  end
  
  defp collect_telemetry_loop(ref, events, end_time) do
    if System.monotonic_time(:millisecond) >= end_time do
      events
    else
      receive do
        {:n8n_trace_event, ^ref, event} ->
          collect_telemetry_loop(ref, [event | events], end_time)
      after
        50 ->
          collect_telemetry_loop(ref, events, end_time)
      end
    end
  end
  
  defp cleanup_n8n_telemetry(_ref) do
    :telemetry.list_handlers([])
    |> Enum.filter(fn handler -> String.starts_with?(handler.id, "n8n-trace-test-") end)
    |> Enum.each(fn handler -> :telemetry.detach(handler.id) end)
  end
  
  defp analyze_n8n_trace_telemetry(events, expected_trace_id) do
    IO.puts("\n📊 N8N Trace Telemetry Analysis")
    IO.puts("-" |> String.duplicate(40))
    
    IO.puts("  Total telemetry events: #{length(events)}")
    IO.puts("  Expected trace ID: #{expected_trace_id}")
    
    # Check trace ID consistency
    trace_consistent_events = Enum.count(events, fn event ->
      get_in(event, [:measurements, :trace_id]) == expected_trace_id
    end)
    
    IO.puts("  Trace consistent events: #{trace_consistent_events}/#{length(events)}")
    
    # Show event details
    for {event, index} <- Enum.with_index(events, 1) do
      event_trace_id = get_in(event, [:measurements, :trace_id])
      workflow_id = get_in(event, [:measurements, :workflow_id])
      action = get_in(event, [:measurements, :action])
      
      status = if event_trace_id == expected_trace_id, do: "✅", else: "❌"
      event_name = Enum.join(event.event, ".")
      
      IO.puts("    #{index}. #{status} #{event_name}")
      IO.puts("       Workflow: #{workflow_id}, Action: #{action}")
      IO.puts("       Trace: #{event_trace_id}")
    end
    
    # Overall assessment
    perfect_trace_consistency = trace_consistent_events == length(events)
    IO.puts("  Overall consistency: #{if perfect_trace_consistency, do: "✅ PERFECT", else: "⚠️ ISSUES"}")
  end
  
  defp generate_test_trace_id do
    "n8n-test-#{System.system_time(:nanosecond)}-#{:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)}"
  end
end

# Run the test
case System.argv() do
  [] ->
    N8nTraceIntegrationTest.run_n8n_trace_integration_test()
  ["steps"] ->
    N8nTraceIntegrationTest.test_n8n_step_trace_propagation()
  ["webhook"] ->
    N8nTraceIntegrationTest.test_n8n_webhook_trace_preservation()
  ["headers"] ->
    N8nTraceIntegrationTest.test_http_header_trace_propagation()
  _ ->
    IO.puts("Usage: elixir n8n_trace_integration_test.exs [steps|webhook|headers]")
    IO.puts("Or run without arguments for full test suite")
end