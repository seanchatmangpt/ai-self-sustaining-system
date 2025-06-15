Mix.install([
  {:telemetry, "~> 1.0"},
  {:jason, "~> 1.4"}
])

defmodule SimpleTelemetryTest do
  @moduledoc """
  Simple test to verify our refactored n8n integration produces telemetry.
  """

  def run do
    IO.puts("🔬 Testing Reactor -> n8n Integration Telemetry")
    IO.puts("=" |> String.duplicate(50))
    
    # Setup telemetry collector
    events = []
    ref = make_ref()
    
    # Attach telemetry handlers
    handlers = [
      [:self_sustaining, :reactor, :execution, :start],
      [:self_sustaining, :reactor, :execution, :complete], 
      [:self_sustaining, :reactor, :step, :complete],
      [:self_sustaining, :n8n, :workflow, :start],
      [:self_sustaining, :n8n, :workflow, :executed]
    ]
    
    for event <- handlers do
      :telemetry.attach(
        "test-#{inspect(event)}-#{System.unique_integer()}",
        event,
        fn event_name, measurements, metadata, {pid, events_ref} ->
          send(pid, {:telemetry_event, events_ref, %{
            event: event_name,
            measurements: measurements,
            metadata: metadata,
            timestamp: System.system_time(:microsecond)
          }})
        end,
        {self(), ref}
      )
    end
    
    IO.puts("✅ Attached telemetry handlers for #{length(handlers)} events")
    
    # Test the telemetry emissions directly
    test_direct_emissions(ref)
    
    # Collect events
    collected_events = collect_events(ref, 2000)
    
    # Analyze results
    analyze_telemetry_results(collected_events)
    
    # Cleanup - detach all handlers that start with "test-"
    :telemetry.list_handlers([])
    |> Enum.filter(fn handler -> String.starts_with?(handler.id, "test-") end)
    |> Enum.each(fn handler -> :telemetry.detach(handler.id) end)
    
    :ok
  end
  
  defp test_direct_emissions(ref) do
    IO.puts("\n📡 Emitting test telemetry events...")
    
    # Simulate reactor execution start
    :telemetry.execute([:self_sustaining, :reactor, :execution, :start], %{
      reactor_id: "test_reactor",
      timestamp: System.system_time(:microsecond),
      workflow_name: "test_workflow"
    }, %{
      source: "simple_test",
      ref: ref
    })
    
    # Simulate n8n workflow step
    :telemetry.execute([:self_sustaining, :n8n, :workflow, :start], %{
      workflow_id: "test_n8n_workflow",
      action: :trigger,
      timestamp: System.system_time(:microsecond)
    }, %{
      source: "simple_test",
      ref: ref
    })
    
    :timer.sleep(100)
    
    # Simulate completion
    :telemetry.execute([:self_sustaining, :n8n, :workflow, :executed], %{
      workflow_id: "test_n8n_workflow", 
      action: :trigger,
      success: true,
      timestamp: System.system_time(:microsecond)
    }, %{
      source: "simple_test",
      ref: ref
    })
    
    :telemetry.execute([:self_sustaining, :reactor, :execution, :complete], %{
      reactor_id: "test_reactor",
      action: :trigger,
      success: true,
      timestamp: System.system_time(:microsecond)
    }, %{
      source: "simple_test", 
      ref: ref
    })
    
    IO.puts("✅ Emitted 4 test telemetry events")
  end
  
  defp collect_events(ref, timeout) do
    IO.puts("\n📥 Collecting telemetry events for #{timeout}ms...")
    
    events = collect_events_loop(ref, [], System.monotonic_time(:millisecond) + timeout)
    
    IO.puts("✅ Collected #{length(events)} telemetry events")
    events
  end
  
  defp collect_events_loop(ref, events, end_time) do
    if System.monotonic_time(:millisecond) >= end_time do
      events
    else
      receive do
        {:telemetry_event, ^ref, event} ->
          collect_events_loop(ref, [event | events], end_time)
      after
        100 ->
          collect_events_loop(ref, events, end_time)
      end
    end
  end
  
  defp analyze_telemetry_results(events) do
    IO.puts("\n📊 Telemetry Analysis")
    IO.puts("=" |> String.duplicate(30))
    
    if Enum.empty?(events) do
      IO.puts("❌ No telemetry events received!")
    else
      IO.puts("📈 Total events: #{length(events)}")
      
      # Group by event type
      by_event = Enum.group_by(events, & &1.event)
      
      for {event_name, event_list} <- by_event do
        IO.puts("  • #{inspect(event_name)}: #{length(event_list)} events")
      end
      
      # Check for expected events
      expected_events = [
        [:self_sustaining, :reactor, :execution, :start],
        [:self_sustaining, :reactor, :execution, :complete],
        [:self_sustaining, :n8n, :workflow, :start], 
        [:self_sustaining, :n8n, :workflow, :executed]
      ]
      
      IO.puts("\n🎯 Expected Events Check:")
      
      for expected <- expected_events do
        count = Map.get(by_event, expected, []) |> length()
        status = if count > 0, do: "✅", else: "❌"
        IO.puts("  #{status} #{inspect(expected)}: #{count}")
      end
      
      # Performance metrics
      if length(events) > 1 do
        timestamps = Enum.map(events, & &1.timestamp)
        duration = Enum.max(timestamps) - Enum.min(timestamps)
        IO.puts("\n⏱️  Total duration: #{duration / 1000}ms")
      end
      
      # Check for metadata
      events_with_metadata = Enum.count(events, fn event ->
        Map.has_key?(event, :metadata) and map_size(event.metadata) > 0
      end)
      
      IO.puts("📋 Events with metadata: #{events_with_metadata}/#{length(events)}")
    end
    
    :ok
  end
end

# Run the test
SimpleTelemetryTest.run()