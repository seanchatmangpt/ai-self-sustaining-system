#!/usr/bin/env elixir

# Simple API Orchestration Demo with Trace ID Propagation

Mix.install([
  {:jason, "~> 1.4"},
  {:reactor, "~> 0.15.4"}
])

Code.require_file("lib/self_sustaining/workflows/api_orchestration_reactor.ex", __DIR__)
Code.require_file("lib/self_sustaining/workflows/optimized_coordination_reactor.ex", __DIR__)

defmodule ApiOrchestrationDemo do
  @moduledoc """
  Simple demonstration of API orchestration with trace ID propagation.
  Shows how trace IDs flow through multiple API calls and coordination.
  """

  require Logger

  def run_demo do
    IO.puts("🚀 API Orchestration Demo - Trace ID Propagation")
    IO.puts("=" |> String.duplicate(60))
    
    # Setup
    setup_demo()
    
    # Create a unique trace ID
    master_trace_id = "demo_trace_#{System.system_time(:nanosecond)}"
    
    IO.puts("\n🔍 Master Trace ID: #{master_trace_id}")
    IO.puts("📊 Monitoring trace propagation through API orchestration...")
    
    # Setup telemetry monitoring
    setup_telemetry_monitoring(master_trace_id)
    
    # Prepare configuration
    config = %{
      coordination_config: %{
        coordination_dir: ".demo_orchestration",
        claims_file: "demo_claims.json",
        timeout: 5000
      },
      api_config: %{
        auth_enabled: true,
        api_timeout: 5000,
        retry_attempts: 3
      }
    }
    
    # Execute orchestration
    IO.puts("\n🎯 Executing API Orchestration Workflow...")
    
    start_time = System.monotonic_time(:microsecond)
    
    result = Reactor.run(
      SelfSustaining.Workflows.ApiOrchestrationReactor,
      %{
        user_id: "demo_user_123",
        resource_id: "demo_resource_abc",
        coordination_config: config.coordination_config,
        api_config: config.api_config
      },
      %{
        trace_id: master_trace_id,
        demo_mode: true,
        execution_context: "api_orchestration_demo"
      }
    )
    
    total_duration = System.monotonic_time(:microsecond) - start_time
    
    # Analyze results
    case result do
      {:ok, orchestration_result} ->
        IO.puts("\n✅ API Orchestration Completed Successfully!")
        IO.puts("   Total Duration: #{Float.round(total_duration / 1000, 2)}ms")
        IO.puts("   Orchestration ID: #{orchestration_result.orchestration_id}")
        IO.puts("   Steps Completed: #{length(orchestration_result.steps_completed)}")
        
        # Trace ID validation
        IO.puts("\n🔗 Trace ID Propagation Analysis:")
        IO.puts("   Master Trace ID: #{master_trace_id}")
        IO.puts("   Result Trace ID: #{orchestration_result.trace_id}")
        
        if orchestration_result.trace_id == master_trace_id do
          IO.puts("   ✅ Trace ID propagated correctly through orchestration")
        else
          IO.puts("   ❌ Trace ID mismatch - propagation failed")
        end
        
        # Check coordination trace ID
        coordination_trace_id = Map.get(orchestration_result.coordination_claim, :trace_id)
        if coordination_trace_id == master_trace_id do
          IO.puts("   ✅ Trace ID propagated to coordination system")
        else
          IO.puts("   ❌ Trace ID missing from coordination claim")
          IO.puts("   Expected: #{master_trace_id}")
          IO.puts("   Found: #{coordination_trace_id}")
        end
        
        # Show workflow results
        IO.puts("\n📋 Workflow Results:")
        IO.puts("   User Profile: #{orchestration_result.profile.username} (#{orchestration_result.profile.role})")
        IO.puts("   Permissions: #{Enum.join(orchestration_result.permissions, ", ")}")
        IO.puts("   Resource Access: #{orchestration_result.resource_access.access_level}")
        IO.puts("   Coordination Work: #{orchestration_result.coordination_claim.work_item_id}")
        
        # Show performance metadata
        if Map.has_key?(orchestration_result.coordination_claim, :performance_metadata) do
          perf_meta = orchestration_result.coordination_claim.performance_metadata
          IO.puts("   Conflict Check: #{Float.round(perf_meta.conflict_check_duration / 1000, 2)}ms")
          IO.puts("   Claims Analyzed: #{perf_meta.claims_analyzed}")
        end
        
      {:error, reason} ->
        IO.puts("\n❌ API Orchestration Failed!")
        IO.puts("   Duration: #{Float.round(total_duration / 1000, 2)}ms")
        IO.puts("   Error: #{inspect(reason)}")
        IO.puts("   Trace ID: #{master_trace_id}")
    end
    
    # Show telemetry summary
    :timer.sleep(200)  # Allow telemetry to process
    show_telemetry_summary(master_trace_id)
    
    # Cleanup
    cleanup_demo()
    
    IO.puts("\n🎉 API Orchestration Demo Complete!")
  end

  defp setup_demo do
    # Create demo directory
    File.mkdir_p(".demo_orchestration")
    
    # Setup ETS cache
    try do
      :ets.new(:coordination_cache, [:named_table, :public, {:read_concurrency, true}])
    catch
      :error, :badarg -> :ok
    end
    
    # Create initial claims file
    initial_claims = [
      %{
        "work_item_id" => "demo_existing_work_1",
        "agent_id" => "demo_agent_1",
        "work_type" => "background_processing",
        "priority" => "low",
        "status" => "in_progress",
        "claimed_at" => DateTime.utc_now() |> DateTime.to_iso8601()
      }
    ]
    
    claims_file = ".demo_orchestration/demo_claims.json"
    File.write!(claims_file, Jason.encode!(initial_claims, pretty: true))
    
    IO.puts("🛠️  Demo environment setup complete")
  end

  defp setup_telemetry_monitoring(trace_id) do
    # Store telemetry events in process dictionary for demo
    Process.put(:telemetry_events, [])
    Process.put(:demo_trace_id, trace_id)
    
    # Attach handlers for key orchestration events
    events_to_monitor = [
      [:api_orchestration, :auth, :success],
      [:api_orchestration, :profile, :success],
      [:api_orchestration, :permissions, :success],
      [:api_orchestration, :resource_validation, :success],
      [:api_orchestration, :coordination, :success],
      [:api_orchestration, :aggregation, :success],
      [:coordination, :claims, :read],
      [:coordination, :write, :success]
    ]
    
    for event <- events_to_monitor do
      handler_id = "demo_#{Enum.join(event, "_")}"
      
      :telemetry.attach(
        handler_id,
        event,
        &capture_telemetry_event/4,
        %{demo_trace_id: trace_id}
      )
    end
    
    IO.puts("📊 Telemetry monitoring active for trace: #{String.slice(trace_id, -8, 8)}")
  end

  defp capture_telemetry_event(event_name, measurements, metadata, config) do
    demo_trace_id = Map.get(config, :demo_trace_id)
    event_trace_id = Map.get(metadata, :trace_id)
    
    # Only capture events from our demo trace
    if event_trace_id == demo_trace_id do
      event_data = %{
        event: event_name,
        measurements: measurements,
        metadata: metadata,
        timestamp: System.monotonic_time(:microsecond)
      }
      
      current_events = Process.get(:telemetry_events, [])
      Process.put(:telemetry_events, [event_data | current_events])
      
      # Real-time logging for demo
      event_name_str = Enum.join(event_name, ".")
      duration = Map.get(measurements, :duration, 0)
      
      IO.puts("   📡 #{event_name_str}: #{Float.round(duration / 1000, 2)}ms [trace: #{String.slice(event_trace_id, -8, 8)}]")
    end
  end

  defp show_telemetry_summary(trace_id) do
    events = Process.get(:telemetry_events, []) |> Enum.reverse()
    
    IO.puts("\n📊 Telemetry Summary for Trace: #{String.slice(trace_id, -8, 8)}")
    IO.puts("-" |> String.duplicate(50))
    
    if length(events) > 0 do
      IO.puts("Total events captured: #{length(events)}")
      
      # Calculate total workflow time
      first_event = List.first(events)
      last_event = List.last(events)
      
      if first_event && last_event do
        total_workflow_time = last_event.timestamp - first_event.timestamp
        IO.puts("Total workflow time: #{Float.round(total_workflow_time / 1000, 2)}ms")
      end
      
      # Show step-by-step timing
      IO.puts("\\nStep-by-step telemetry:")
      
      events
      |> Enum.each(fn event ->
        event_name = Enum.join(event.event, ".")
        duration = Map.get(event.measurements, :duration, 0)
        IO.puts("  #{event_name}: #{Float.round(duration / 1000, 2)}ms")
      end)
      
      # Validate trace ID consistency
      unique_trace_ids = events
        |> Enum.map(&Map.get(&1.metadata, :trace_id))
        |> Enum.uniq()
        |> Enum.filter(& &1)
      
      IO.puts("\\n🔍 Trace ID Consistency Check:")
      IO.puts("Unique trace IDs in events: #{length(unique_trace_ids)}")
      
      if length(unique_trace_ids) == 1 and List.first(unique_trace_ids) == trace_id do
        IO.puts("✅ All events have consistent trace ID: #{String.slice(trace_id, -8, 8)}")
      else
        IO.puts("❌ Trace ID inconsistency detected")
        IO.puts("Expected: #{String.slice(trace_id, -8, 8)}")
        IO.puts("Found: #{Enum.map(unique_trace_ids, &String.slice(&1, -8, 8)) |> Enum.join(", ")}")
      end
    else
      IO.puts("No telemetry events captured for this trace")
    end
  end

  defp cleanup_demo do
    # Remove telemetry handlers
    [:api_orchestration, :coordination]
    |> Enum.each(fn prefix ->
      :telemetry.list_handlers([])
      |> Enum.filter(fn handler -> String.starts_with?(handler.id, "demo_#{prefix}") end)
      |> Enum.each(fn handler -> :telemetry.detach(handler.id) end)
    end)
    
    # Clean up files
    File.rm_rf(".demo_orchestration")
    
    # Clean up ETS
    try do
      :ets.delete(:coordination_cache)
    catch
      :error, :badarg -> :ok
    end
    
    # Clean up process dictionary
    Process.delete(:telemetry_events)
    Process.delete(:demo_trace_id)
    
    IO.puts("🧹 Demo cleanup complete")
  end
end

# Run the demo
ApiOrchestrationDemo.run_demo()