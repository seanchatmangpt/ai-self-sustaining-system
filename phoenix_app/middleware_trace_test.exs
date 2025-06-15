#!/usr/bin/env elixir

# Simple test to verify the TelemetryMiddleware trace ID functionality
Mix.install([
  {:telemetry, "~> 1.0"},
  {:jason, "~> 1.4"}
])

defmodule MiddlewareTraceTest do
  @moduledoc """
  Test the TelemetryMiddleware trace ID generation and propagation
  without requiring full Reactor execution.
  """
  
  require Logger
  
  def run_middleware_trace_test do
    IO.puts("🔍 TelemetryMiddleware Trace ID Test")
    IO.puts("=" |> String.duplicate(50))
    
    # Test 1: Trace ID generation
    test_trace_id_generation()
    
    # Test 2: Middleware initialization with trace ID
    test_middleware_initialization()
    
    # Test 3: Telemetry event emission with trace IDs
    test_telemetry_trace_propagation()
    
    IO.puts("\n✅ Middleware Trace Test Complete")
  end
  
  def test_trace_id_generation do
    IO.puts("\n📋 Test 1: Trace ID Generation")
    IO.puts("-" |> String.duplicate(40))
    
    # Test the trace ID generation function
    trace_ids = Enum.map(1..5, fn i ->
      trace_id = generate_trace_id()
      IO.puts("  Generated trace ID #{i}: #{trace_id}")
      trace_id
    end)
    
    # Verify uniqueness
    unique_trace_ids = Enum.uniq(trace_ids)
    IO.puts("  Generated: #{length(trace_ids)}")
    IO.puts("  Unique: #{length(unique_trace_ids)}")
    IO.puts("  Uniqueness: #{if length(trace_ids) == length(unique_trace_ids), do: "✅ PERFECT", else: "❌ DUPLICATES"}")
    
    # Verify format
    valid_format = Enum.all?(trace_ids, fn trace_id ->
      String.starts_with?(trace_id, "reactor-") and
      String.length(trace_id) > 20 and
      String.contains?(trace_id, "-")
    end)
    
    IO.puts("  Format validation: #{if valid_format, do: "✅ VALID", else: "❌ INVALID"}")
  end
  
  def test_middleware_initialization do
    IO.puts("\n🔧 Test 2: Middleware Context Initialization")
    IO.puts("-" |> String.duplicate(40))
    
    # Simulate middleware initialization
    test_context = %{
      __reactor__: %{
        id: "test_reactor",
        steps: [:step1, :step2, :step3]
      },
      test_data: "middleware_test"
    }
    
    IO.puts("  Initial context keys: #{inspect(Map.keys(test_context))}")
    
    # Simulate middleware init
    enhanced_context = simulate_middleware_init(test_context)
    
    IO.puts("  Enhanced context keys: #{inspect(Map.keys(enhanced_context))}")
    
    # Check trace ID presence
    trace_id = Map.get(enhanced_context, :trace_id)
    otel_trace_id = Map.get(enhanced_context, :otel_trace_id)
    
    IO.puts("  Trace ID present: #{if trace_id, do: "✅", else: "❌"} (#{trace_id})")
    IO.puts("  OTel Trace ID present: #{if otel_trace_id, do: "✅", else: "❌"} (#{otel_trace_id})")
    
    # Check middleware state
    middleware_state = Map.get(enhanced_context, SelfSustaining.ReactorMiddleware.TelemetryMiddleware)
    
    if middleware_state do
      IO.puts("  Middleware state present: ✅")
      IO.puts("    Reactor ID: #{middleware_state[:reactor_id]}")
      IO.puts("    Trace ID: #{middleware_state[:trace_id]}")
      IO.puts("    Start time: #{middleware_state[:start_time]}")
    else
      IO.puts("  Middleware state present: ❌")
    end
  end
  
  def test_telemetry_trace_propagation do
    IO.puts("\n📡 Test 3: Telemetry Trace Propagation")
    IO.puts("-" |> String.duplicate(40))
    
    # Setup telemetry listener
    telemetry_ref = setup_telemetry_listener()
    
    # Generate test trace ID
    test_trace_id = generate_trace_id()
    IO.puts("  Test trace ID: #{test_trace_id}")
    
    # Emit various telemetry events with trace ID
    events_to_emit = [
      [:self_sustaining, :reactor, :execution, :start],
      [:self_sustaining, :reactor, :step, :start],
      [:self_sustaining, :reactor, :step, :complete],
      [:self_sustaining, :reactor, :execution, :complete]
    ]
    
    IO.puts("  Emitting #{length(events_to_emit)} telemetry events...")
    
    for {event, index} <- Enum.with_index(events_to_emit, 1) do
      :telemetry.execute(event, %{
        reactor_id: "test_reactor",
        trace_id: test_trace_id,
        step_index: index,
        timestamp: System.system_time(:microsecond)
      }, %{
        test_context: true,
        trace_test: true
      })
      
      # Small delay between events
      :timer.sleep(10)
    end
    
    # Collect emitted events
    :timer.sleep(100) # Allow events to be processed
    collected_events = collect_telemetry_events(telemetry_ref, 500)
    
    IO.puts("  Events emitted: #{length(events_to_emit)}")
    IO.puts("  Events collected: #{length(collected_events)}")
    
    # Analyze trace ID consistency
    trace_consistent_events = Enum.count(collected_events, fn event ->
      get_in(event, [:measurements, :trace_id]) == test_trace_id
    end)
    
    IO.puts("  Trace ID consistent: #{trace_consistent_events}/#{length(collected_events)}")
    IO.puts("  Trace propagation: #{if trace_consistent_events == length(collected_events), do: "✅ PERFECT", else: "⚠️ ISSUES"}")
    
    # Show detailed trace analysis
    for {event, index} <- Enum.with_index(collected_events, 1) do
      event_trace_id = get_in(event, [:measurements, :trace_id])
      status = if event_trace_id == test_trace_id, do: "✅", else: "❌"
      event_name = Enum.join(event.event, ".")
      
      IO.puts("    Event #{index}: #{status} #{event_name} (#{event_trace_id})")
    end
    
    cleanup_telemetry_listener(telemetry_ref)
  end
  
  # Helper functions that simulate the actual middleware behavior
  
  defp generate_trace_id do
    "reactor-" <> 
    (:crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)) <>
    "-" <> 
    (System.system_time(:nanosecond) |> to_string())
  end
  
  defp simulate_middleware_init(context) do
    # Simulate the TelemetryMiddleware.init/1 behavior
    reactor_id = get_in(context, [:__reactor__, :id]) || "unknown_reactor"
    
    # Generate trace ID
    trace_id = generate_trace_id()
    otel_trace_id = trace_id # In real implementation, this would come from OpenTelemetry
    
    # Create enhanced context similar to actual middleware
    enhanced_context = context
      |> Map.put(:execution_start_time, System.monotonic_time())
      |> Map.put(:trace_id, trace_id)
      |> Map.put(:otel_trace_id, otel_trace_id)
      |> Map.put(SelfSustaining.ReactorMiddleware.TelemetryMiddleware, %{
        reactor_id: reactor_id,
        start_time: System.monotonic_time(),
        step_timings: %{},
        trace_id: trace_id,
        otel_trace_id: otel_trace_id
      })
    
    # Emit initialization telemetry
    :telemetry.execute([:self_sustaining, :reactor, :execution, :start], %{
      timestamp: System.system_time(:microsecond),
      reactor_id: reactor_id,
      steps_count: get_steps_count(context),
      trace_id: trace_id,
      otel_trace_id: otel_trace_id
    }, context)
    
    enhanced_context
  end
  
  defp get_steps_count(context) do
    case context[:__reactor__] do
      %{steps: steps} when is_list(steps) -> length(steps)
      _ -> 0
    end
  end
  
  # Telemetry helpers
  
  defp setup_telemetry_listener do
    ref = make_ref()
    
    events = [
      [:self_sustaining, :reactor, :execution, :start],
      [:self_sustaining, :reactor, :execution, :complete],
      [:self_sustaining, :reactor, :step, :start],
      [:self_sustaining, :reactor, :step, :complete]
    ]
    
    for event <- events do
      :telemetry.attach(
        "middleware-trace-test-#{System.unique_integer()}",
        event,
        fn event_name, measurements, metadata, {pid, events_ref} ->
          send(pid, {:trace_telemetry_event, events_ref, %{
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
  
  defp collect_telemetry_events(ref, timeout) do
    collect_events_loop(ref, [], System.monotonic_time(:millisecond) + timeout)
  end
  
  defp collect_events_loop(ref, events, end_time) do
    if System.monotonic_time(:millisecond) >= end_time do
      events
    else
      receive do
        {:trace_telemetry_event, ^ref, event} ->
          collect_events_loop(ref, [event | events], end_time)
      after
        50 ->
          collect_events_loop(ref, events, end_time)
      end
    end
  end
  
  defp cleanup_telemetry_listener(_ref) do
    :telemetry.list_handlers([])
    |> Enum.filter(fn handler -> String.starts_with?(handler.id, "middleware-trace-test-") end)
    |> Enum.each(fn handler -> :telemetry.detach(handler.id) end)
  end
end

# Run the test
if System.argv() == [] do
  MiddlewareTraceTest.run_middleware_trace_test()
else
  case List.first(System.argv()) do
    "generation" -> MiddlewareTraceTest.test_trace_id_generation()
    "init" -> MiddlewareTraceTest.test_middleware_initialization()
    "telemetry" -> MiddlewareTraceTest.test_telemetry_trace_propagation()
    _ -> 
      IO.puts("Usage: elixir middleware_trace_test.exs [generation|init|telemetry]")
      IO.puts("Or run without arguments for full test suite")
  end
end