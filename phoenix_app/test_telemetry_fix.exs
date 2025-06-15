#!/usr/bin/env elixir

# Telemetry Fix Verification Test
# Run with: mix run test_telemetry_fix.exs

IO.puts("🔧 === Testing Fixed Telemetry System ===")

defmodule TelemetryFixTest do
  def test_fixed_telemetry do
    IO.puts("📊 Testing if telemetry events are now being collected...")
    
    # Start a telemetry collector to verify events
    {:ok, collector_pid} = Agent.start_link(fn -> [] end)
    
    # Attach telemetry handler to capture ALL relevant events
    :telemetry.attach_many(
      "fix-verification-handler",
      [
        [:self_sustaining, :reactor, :execution, :start],
        [:self_sustaining, :reactor, :execution, :complete],
        [:self_sustaining, :reactor, :step, :start],
        [:self_sustaining, :reactor, :step, :complete],
        [:self_sustaining, :n8n, :workflow, :start],
        [:self_sustaining, :n8n, :workflow, :executed]
      ],
      fn event, measurements, metadata, _config ->
        timestamp = System.system_time(:microsecond)
        Agent.update(collector_pid, fn events ->
          [{event, measurements, metadata, timestamp} | events]
        end)
        IO.puts("   ✅ Captured telemetry: #{inspect(event)} at #{timestamp}")
      end,
      %{}
    )
    
    IO.puts("   🎯 Executing workflow with fixed telemetry middleware...")
    
    # Test workflow
    workflow_def = %{
      name: "telemetry_fix_test",
      nodes: [
        %{
          id: "test_node",
          name: "Test Node",
          type: :webhook,
          position: [100, 200],
          parameters: %{}
        }
      ],
      connections: []
    }
    
    n8n_config = %{
      api_url: "http://localhost:5678/api/v1",
      api_key: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIwM2VmZDFhMC00YjEwLTQ0M2QtODJiMC0xYjc4NjUxNDU1YzkiLCJpc3MiOiJuOG4iLCJhdWQiOiJwdWJsaWMtYXBpIiwiaWF0IjoxNzUwMDAyNzA4LCJleHAiOjE3NTI1NTIwMDB9.LoaISJGi0FuwCU53NY_kt4t_RFsGFjHZBhX9BNT_8LM",
      timeout: 10_000
    }
    
    # Execute with timing
    start_time = System.monotonic_time()
    
    result = Reactor.run(SelfSustaining.Workflows.N8nIntegrationReactor, %{
      workflow_definition: workflow_def,
      n8n_config: n8n_config,
      action: :compile
    })
    
    end_time = System.monotonic_time()
    execution_time = System.convert_time_unit(end_time - start_time, :native, :microsecond)
    
    # Give telemetry time to propagate
    Process.sleep(100)
    
    # Collect telemetry events
    collected_events = Agent.get(collector_pid, & &1)
    
    # Cleanup
    :telemetry.detach("fix-verification-handler")
    Agent.stop(collector_pid)
    
    IO.puts("")
    IO.puts("🎯 === TELEMETRY FIX VERIFICATION RESULTS ===")
    IO.puts("Execution Result: #{inspect(result, limit: 2)}")
    IO.puts("Actual Execution Time: #{Float.round(execution_time / 1000, 2)}ms")
    IO.puts("Telemetry Events Collected: #{length(collected_events)}")
    IO.puts("")
    
    if length(collected_events) > 0 do
      IO.puts("✅ TELEMETRY FIX SUCCESSFUL!")
      IO.puts("📊 Captured Events:")
      Enum.each(collected_events, fn {event, measurements, metadata, timestamp} ->
        IO.puts("   #{inspect(event)}")
        IO.puts("     Measurements: #{inspect(Map.keys(measurements))}")
        IO.puts("     Metadata keys: #{inspect(Map.keys(metadata))}")
        IO.puts("     Timestamp: #{timestamp}")
        IO.puts("")
      end)
    else
      IO.puts("❌ TELEMETRY STILL NOT WORKING!")
      IO.puts("   Events are still not being captured.")
    end
    
    %{
      execution_result: result,
      actual_execution_time: execution_time,
      telemetry_events_count: length(collected_events),
      events: collected_events,
      telemetry_fixed: length(collected_events) > 0
    }
  end
  
  def test_direct_telemetry_emission do
    IO.puts("🔍 Testing direct telemetry emission...")
    
    # Start a collector for direct test
    {:ok, collector_pid} = Agent.start_link(fn -> [] end)
    
    # Attach handler
    :telemetry.attach(
      "direct-test-handler",
      [:test, :direct, :telemetry],
      fn event, measurements, metadata, _config ->
        Agent.update(collector_pid, fn events ->
          [{event, measurements, metadata} | events]
        end)
        IO.puts("   📡 Direct telemetry captured: #{inspect(event)}")
      end,
      %{}
    )
    
    # Emit a test event
    :telemetry.execute([:test, :direct, :telemetry], %{
      test_value: 42,
      timestamp: System.system_time(:microsecond)
    }, %{
      test_context: "direct_emission"
    })
    
    Process.sleep(50)
    
    # Check results
    collected_events = Agent.get(collector_pid, & &1)
    
    # Cleanup
    :telemetry.detach("direct-test-handler")
    Agent.stop(collector_pid)
    
    if length(collected_events) > 0 do
      IO.puts("   ✅ Direct telemetry emission works")
    else
      IO.puts("   ❌ Direct telemetry emission failed")
    end
    
    length(collected_events) > 0
  end
end

# Run the tests
direct_test_result = TelemetryFixTest.test_direct_telemetry_emission()
telemetry_result = TelemetryFixTest.test_fixed_telemetry()

IO.puts("")
IO.puts("🏁 === FINAL TELEMETRY FIX SUMMARY ===")
IO.puts("Direct Telemetry Works: #{direct_test_result}")
IO.puts("Reactor Telemetry Fixed: #{telemetry_result.telemetry_fixed}")
IO.puts("Total Events Captured: #{telemetry_result.telemetry_events_count}")

if telemetry_result.telemetry_fixed do
  IO.puts("")
  IO.puts("🎉 TELEMETRY SYSTEM SUCCESSFULLY FIXED!")
  IO.puts("Performance metrics can now be accurately measured.")
else
  IO.puts("")
  IO.puts("⚠️  TELEMETRY STILL NEEDS MORE WORK")
  IO.puts("Further investigation required.")
end