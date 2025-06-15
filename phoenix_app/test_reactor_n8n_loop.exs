#!/usr/bin/env elixir

# Test script for Reactor -> N8N -> Reactor loop with telemetry collection
# Run with: mix run test_reactor_n8n_loop.exs

IO.puts("=== Starting Reactor -> N8N -> Reactor Loop Test ===")

# Generate trace ID for this integration test
trace_id = "trace_#{System.system_time(:nanosecond)}"
IO.puts("🔍 Integration test trace_id: #{trace_id}")

# Create a sample workflow definition
workflow_def = %{
  name: "test_reactor_loop",
  nodes: [
    %{id: "start", type: :webhook, name: "Start Trigger", position: [100, 200]},
    %{id: "process", type: :function, name: "Process Data", position: [300, 200]},
    %{id: "end", type: :http, name: "Send Result", position: [500, 200]}
  ],
  connections: [
    %{from: "start", to: "process"},
    %{from: "process", to: "end"}
  ]
}

# Configure n8n settings with proper JWT API key
n8n_api_key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIwM2VmZDFhMC00YjEwLTQ0M2QtODJiMC0xYjc4NjUxNDU1YzkiLCJpc3MiOiJuOG4iLCJhdWQiOiJwdWJsaWMtYXBpIiwiaWF0IjoxNzUwMDAyNzA4LCJleHAiOjE3NTI1NTIwMDB9.LoaISJGi0FuwCU53NY_kt4t_RFsGFjHZBhX9BNT_8LM"

Application.put_env(:self_sustaining, :n8n, [
  api_url: "http://localhost:5678/api/v1",
  api_key: n8n_api_key,
  timeout: 10_000
])

# Set up telemetry collection
telemetry_events = []

:telemetry.attach_many(
  "integration-test-telemetry",
  [
    [:self_sustaining, :reactor, :execution, :start],
    [:self_sustaining, :reactor, :execution, :complete],
    [:self_sustaining, :reactor, :step, :start],
    [:self_sustaining, :reactor, :step, :complete],
    [:self_sustaining, :reactor, :step, :error]
  ],
  fn event, measurements, metadata, _config ->
    timestamp = DateTime.utc_now()
    event_data = %{
      timestamp: timestamp,
      event: event,
      measurements: measurements,
      metadata: Map.take(metadata, [:reactor_id, :step_name, :success, :duration])
    }
    
    IO.puts("📊 Telemetry: #{inspect(event)} - #{timestamp}")
    IO.puts("   Measurements: #{inspect(measurements)}")
    IO.puts("   Key Metadata: #{inspect(event_data.metadata)}")
    IO.puts("")
    
    # Store for later analysis
    Agent.start_link(fn -> [event_data] end, name: :telemetry_collector)
  end,
  %{}
)

# Start telemetry collector agent
{:ok, _} = Agent.start_link(fn -> [] end, name: :telemetry_collector)

# Configure n8n settings for fallback mode
n8n_config = %{
  api_url: "http://localhost:5678/api/v1", 
  api_key: "demo_key",
  timeout: 10_000
}

IO.puts("🔧 Configuration completed - Starting Reactor workflow execution")

# Execute Reactor -> N8N workflow
try do
  IO.puts("🚀 Step 1: Executing Reactor -> N8N Integration")
  
  result1 = Reactor.run(SelfSustaining.Workflows.N8nIntegrationReactor, %{
    workflow_definition: workflow_def,
    n8n_config: n8n_config,
    action: :compile
  })
  
  case result1 do
    {:ok, compile_result} ->
      IO.puts("✅ Compilation successful!")
      IO.puts("   Action: #{compile_result.action}")
      IO.puts("   N8N JSON size: #{byte_size(Jason.encode!(compile_result.compilation_result.n8n_json))} bytes")
      IO.puts("   Node count: #{compile_result.compilation_result.node_count}")
      
      # Step 2: Export to N8N
      IO.puts("🚀 Step 2: Executing N8N Export")
      
      result2 = Reactor.run(SelfSustaining.Workflows.N8nIntegrationReactor, %{
        workflow_definition: workflow_def,
        n8n_config: n8n_config,
        action: :export
      })
      
      case result2 do
        {:ok, export_result} ->
          IO.puts("✅ Export successful!")
          IO.puts("   N8N Workflow ID: #{export_result.export_result.n8n_workflow_id}")
          IO.puts("   Export timestamp: #{export_result.timestamp}")
          
          # Step 3: Trigger execution (N8N -> Reactor feedback)
          IO.puts("🚀 Step 3: Executing N8N Trigger (Reactor -> N8N -> Reactor Loop)")
          
          result3 = Reactor.run(SelfSustaining.Workflows.N8nIntegrationReactor, %{
            workflow_definition: workflow_def,
            n8n_config: n8n_config,
            action: :trigger
          })
          
          case result3 do
            {:ok, trigger_result} ->
              IO.puts("✅ Full loop completed successfully!")
              IO.puts("   Execution ID: #{trigger_result.execution_id}")
              IO.puts("   Monitoring status: #{trigger_result.monitoring_result.status}")
              IO.puts("   Execution status: #{trigger_result.execution_result.status}")
              
              # Collect all telemetry data
              telemetry_data = Agent.get(:telemetry_collector, & &1)
              
              IO.puts("📊 === TELEMETRY ANALYSIS REPORT ===")
              IO.puts("Total telemetry events captured: #{length(telemetry_data)}")
              
              # Group events by type
              event_counts = telemetry_data
                |> Enum.group_by(& &1.event)
                |> Enum.map(fn {event, events} -> {event, length(events)} end)
              
              IO.puts("Event distribution:")
              for {event, count} <- event_counts do
                IO.puts("  #{inspect(event)}: #{count} events")
              end
              
              # Calculate timing metrics
              start_events = Enum.filter(telemetry_data, &match?([:self_sustaining, :reactor, :execution, :start], &1.event))
              complete_events = Enum.filter(telemetry_data, &match?([:self_sustaining, :reactor, :execution, :complete], &1.event))
              
              IO.puts("📈 Performance Metrics:")
              IO.puts("  Reactor executions: #{length(start_events)}")
              IO.puts("  Completed executions: #{length(complete_events)}")
              
              if length(complete_events) > 0 do
                durations = complete_events
                  |> Enum.map(& Map.get(&1.measurements, :duration, 0))
                  |> Enum.filter(& &1 > 0)
                
                if length(durations) > 0 do
                  avg_duration = Enum.sum(durations) / length(durations)
                  max_duration = Enum.max(durations)
                  min_duration = Enum.min(durations)
                  
                  IO.puts("  Average execution time: #{Float.round(avg_duration / 1000, 2)}ms")
                  IO.puts("  Max execution time: #{Float.round(max_duration / 1000, 2)}ms")
                  IO.puts("  Min execution time: #{Float.round(min_duration / 1000, 2)}ms")
                end
              end
              
              IO.puts("✅ === REACTOR -> N8N -> REACTOR LOOP TEST COMPLETED SUCCESSFULLY ===")
              
            {:error, error} ->
              IO.puts("❌ Trigger execution failed: #{inspect(error)}")
          end
          
        {:error, error} ->
          IO.puts("❌ Export failed: #{inspect(error)}")
      end
      
    {:error, error} ->
      IO.puts("❌ Compilation failed: #{inspect(error)}")
  end
  
rescue
  error ->
    IO.puts("❌ Script execution failed: #{inspect(error)}")
    IO.puts("Stack trace: #{Exception.format_stacktrace(__STACKTRACE__)}")
end

# Clean up telemetry
:telemetry.detach("integration-test-telemetry")
IO.puts("🧹 Telemetry cleanup completed")