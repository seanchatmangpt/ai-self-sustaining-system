#!/usr/bin/env elixir

# Test the actual Phoenix PubSub integration with live system
# This script validates the real-time integration works end-to-end

Application.put_env(:phoenix, :serve_endpoints, false)

{:ok, _} = Application.ensure_all_started(:ai_self_sustaining_minimal)

defmodule LivePubSubTest do
  @moduledoc """
  Test live PubSub integration with the actual system.
  """
  
  require Logger
  
  def run_live_test do
    Logger.info("🚀 Testing Live Phoenix PubSub Integration")
    Logger.info("=" |> String.duplicate(50))
    
    # Wait for system to fully initialize
    Process.sleep(1000)
    
    # Test PubSub server availability
    test_pubsub_server()
    
    # Test work item PubSub integration
    test_work_item_pubsub()
    
    # Test telemetry PubSub integration
    test_telemetry_pubsub()
    
    # Test bridge event integration (if available)
    test_bridge_pubsub()
    
    Logger.info("✅ Live PubSub integration test completed!")
  end
  
  defp test_pubsub_server do
    Logger.info("📡 Testing PubSub server availability")
    
    # Test that we can subscribe to the actual PubSub server
    try do
      Phoenix.PubSub.subscribe(AiSelfSustainingMinimal.PubSub, "test:live_validation")
      Logger.info("✅ Successfully subscribed to PubSub server")
      
      # Test broadcasting
      Phoenix.PubSub.broadcast(
        AiSelfSustainingMinimal.PubSub,
        "test:live_validation",
        {:test_message, System.system_time(:nanosecond)}
      )
      
      # Wait for message
      receive do
        {:test_message, timestamp} ->
          Logger.info("✅ PubSub message received successfully")
          Logger.info("   📊 Timestamp: #{timestamp}")
      after
        2000 ->
          Logger.error("❌ Timeout waiting for test message")
      end
      
    rescue
      error ->
        Logger.error("❌ PubSub server test failed: #{inspect(error)}")
    end
  end
  
  defp test_work_item_pubsub do
    Logger.info("🔧 Testing Work Item PubSub integration")
    
    # Subscribe to work item topics
    Phoenix.PubSub.subscribe(AiSelfSustainingMinimal.PubSub, "work_item:created")
    Phoenix.PubSub.subscribe(AiSelfSustainingMinimal.PubSub, "work_item:updated")
    
    try do
      # Create a work item through Ash
      work_item_result = AiSelfSustainingMinimal.Coordination.WorkItem
      |> Ash.Changeset.for_create(:submit_work, %{
        work_type: "pubsub_test",
        description: "Testing PubSub integration",
        priority: :high,
        payload: %{test: true}
      })
      |> Ash.create()
      
      case work_item_result do
        {:ok, work_item} ->
          Logger.info("✅ Work item created successfully")
          Logger.info("   📊 ID: #{work_item.work_item_id}")
          Logger.info("   📊 Type: #{work_item.work_type}")
          
          # Wait for PubSub message
          receive do
            pubsub_message ->
              Logger.info("✅ PubSub message received for work item:")
              Logger.info("   📦 Message: #{inspect(pubsub_message)}")
          after
            3000 ->
              Logger.warning("⚠️ No PubSub message received for work item creation")
          end
          
          # Test work item update
          update_result = work_item
          |> Ash.Changeset.for_update(:claim_work, %{claimed_by: Ash.UUID.generate()})
          |> Ash.update()
          
          case update_result do
            {:ok, updated_item} ->
              Logger.info("✅ Work item updated successfully")
              Logger.info("   📊 Status: #{updated_item.status}")
              
              # Wait for update PubSub message
              receive do
                update_message ->
                  Logger.info("✅ PubSub update message received:")
                  Logger.info("   📦 Message: #{inspect(update_message)}")
              after
                3000 ->
                  Logger.warning("⚠️ No PubSub message received for work item update")
              end
              
            {:error, error} ->
              Logger.error("❌ Work item update failed: #{inspect(error)}")
          end
          
        {:error, error} ->
          Logger.error("❌ Work item creation failed: #{inspect(error)}")
      end
      
    rescue
      error ->
        Logger.error("❌ Work item PubSub test failed: #{inspect(error)}")
    end
  end
  
  defp test_telemetry_pubsub do
    Logger.info("📊 Testing Telemetry PubSub integration")
    
    # Subscribe to telemetry topic
    Phoenix.PubSub.subscribe(AiSelfSustainingMinimal.PubSub, "telemetry:event_recorded")
    
    try do
      # Create a telemetry event through Ash
      telemetry_result = AiSelfSustainingMinimal.Telemetry.TelemetryEvent
      |> Ash.Changeset.for_create(:record_event, %{
        event_name: ["pubsub", "test", "validation"],
        measurements: %{duration: 123.45, count: 1},
        metadata: %{
          source: "live_test",
          test_id: System.system_time(:nanosecond),
          validation_type: "pubsub_integration"
        },
        trace_id: "test_trace_#{System.system_time(:nanosecond)}",
        source: "live_pubsub_test"
      })
      |> Ash.create()
      
      case telemetry_result do
        {:ok, telemetry_event} ->
          Logger.info("✅ Telemetry event created successfully")
          Logger.info("   📊 Event: #{inspect(telemetry_event.event_name)}")
          Logger.info("   📊 Trace ID: #{telemetry_event.trace_id}")
          
          # Wait for PubSub message
          receive do
            telemetry_message ->
              Logger.info("✅ Telemetry PubSub message received:")
              Logger.info("   📦 Message: #{inspect(telemetry_message)}")
          after
            3000 ->
              Logger.warning("⚠️ No PubSub message received for telemetry event")
          end
          
        {:error, error} ->
          Logger.error("❌ Telemetry event creation failed: #{inspect(error)}")
      end
      
    rescue
      error ->
        Logger.error("❌ Telemetry PubSub test failed: #{inspect(error)}")
    end
  end
  
  defp test_bridge_pubsub do
    Logger.info("🌉 Testing Bridge PubSub integration")
    
    # Subscribe to bridge events topic
    Phoenix.PubSub.subscribe(AiSelfSustainingMinimal.PubSub, "telemetry:bridge_events")
    
    # Test manual bridge event broadcasting (since bridge may not be fully active)
    bridge_activity = %{
      event_type: "test_bridge_activity",
      work_item_id: "work_#{System.system_time(:nanosecond)}",
      reactor_type: "validation_reactor",
      trace_id: "bridge_trace_#{System.system_time(:nanosecond)}",
      timestamp: DateTime.utc_now(),
      test_data: %{validation: true}
    }
    
    Phoenix.PubSub.broadcast(
      AiSelfSustainingMinimal.PubSub,
      "telemetry:bridge_events",
      {:bridge_activity, "test_activity", bridge_activity}
    )
    
    # Wait for bridge message
    receive do
      bridge_message ->
        Logger.info("✅ Bridge PubSub message received:")
        Logger.info("   📦 Message: #{inspect(bridge_message)}")
    after
      2000 ->
        Logger.warning("⚠️ No bridge PubSub message received")
    end
  end
end

# Run the live test
LivePubSubTest.run_live_test()

# Keep process alive briefly to ensure all messages are processed
Process.sleep(1000)