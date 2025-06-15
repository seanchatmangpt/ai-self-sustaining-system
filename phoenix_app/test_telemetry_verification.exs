#!/usr/bin/env elixir

# Telemetry Verification Test
# Run with: mix run test_telemetry_verification.exs

IO.puts("🔍 === Verifying OpenTelemetry Collection ===")

defmodule TelemetryVerification do
  def test_telemetry_collection do
    IO.puts("📊 Testing if telemetry events are actually being collected...")
    
    # Start a telemetry collector to verify events
    {:ok, collector_pid} = Agent.start_link(fn -> [] end)
    
    # Attach telemetry handler to capture events
    :telemetry.attach_many(
      "verification-handler",
      [
        [:self_sustaining, :reactor, :execution, :start],
        [:self_sustaining, :reactor, :execution, :complete],
        [:self_sustaining, :reactor, :step, :start],
        [:self_sustaining, :reactor, :step, :complete],
        [:self_sustaining, :n8n, :workflow, :executed]
      ],
      fn event, measurements, metadata, _config ->
        timestamp = System.system_time(:microsecond)
        Agent.update(collector_pid, fn events ->
          [{event, measurements, metadata, timestamp} | events]
        end)
        IO.puts("   📡 Captured telemetry: #{inspect(event)} at #{timestamp}")
      end,
      %{}
    )
    
    IO.puts("   🎯 Executing a real workflow to generate telemetry...")
    
    # Execute a real workflow
    workflow_def = %{
      name: "telemetry_test_workflow",
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
    
    # Execute and time it
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
    :telemetry.detach("verification-handler")
    Agent.stop(collector_pid)
    
    IO.puts("")
    IO.puts("✅ === TELEMETRY VERIFICATION RESULTS ===")
    IO.puts("Execution Result: #{inspect(result, limit: 2)}")
    IO.puts("Actual Execution Time: #{Float.round(execution_time / 1000, 2)}ms")
    IO.puts("Telemetry Events Collected: #{length(collected_events)}")
    IO.puts("")
    
    if length(collected_events) > 0 do
      IO.puts("📊 Captured Events:")
      Enum.each(collected_events, fn {event, measurements, metadata, timestamp} ->
        IO.puts("   #{inspect(event)}")
        IO.puts("     Measurements: #{inspect(measurements)}")
        IO.puts("     Metadata keys: #{inspect(Map.keys(metadata))}")
        IO.puts("     Timestamp: #{timestamp}")
        IO.puts("")
      end)
    else
      IO.puts("❌ NO TELEMETRY EVENTS CAPTURED!")
      IO.puts("   This means telemetry is not working as expected.")
    end
    
    %{
      execution_result: result,
      actual_execution_time: execution_time,
      telemetry_events_count: length(collected_events),
      events: collected_events
    }
  end
  
  def test_opentelemetry_spans do
    IO.puts("🔍 Testing OpenTelemetry spans...")
    
    require OpenTelemetry.Tracer
    alias OpenTelemetry.Span
    
    # Create a test span
    OpenTelemetry.Tracer.with_span "test_reactor_n8n_span" do
      Span.set_attributes([
        {"test.type", "verification"},
        {"reactor.workflow", "test"},
        {"n8n.integration", true}
      ])
      
      # Simulate some work
      Process.sleep(10)
      
      # Check if span context exists
      span_ctx = OpenTelemetry.Tracer.current_span_ctx()
      
      IO.puts("   Current Span Context: #{inspect(span_ctx)}")
      
      if span_ctx != :undefined do
        IO.puts("   ✅ OpenTelemetry spans are working")
      else
        IO.puts("   ❌ OpenTelemetry spans not working")
      end
      
      span_ctx
    end
  end
  
  def check_n8n_telemetry_support do
    IO.puts("🔍 Checking N8N's telemetry capabilities...")
    
    # Check N8N API for telemetry endpoints
    api_key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIwM2VmZDFhMC00YjEwLTQ0M2QtODJiMC0xYjc4NjUxNDU1YzkiLCJpc3MiOiJuOG4iLCJhdWQiOiJwdWJsaWMtYXBpIiwiaWF0IjoxNzUwMDAyNzA4LCJleHAiOjE3NTI1NTIwMDB9.LoaISJGi0FuwCU53NY_kt4t_RFsGFjHZBhX9BNT_8LM"
    
    headers = [
      {"X-N8N-API-KEY", api_key},
      {"Content-Type", "application/json"}
    ]
    
    # Check various N8N endpoints
    endpoints_to_check = [
      "/executions",
      "/workflows", 
      "/metrics",
      "/health",
      "/status"
    ]
    
    IO.puts("   Testing N8N API endpoints...")
    
    endpoint_results = Enum.map(endpoints_to_check, fn endpoint ->
      case HTTPoison.get("http://localhost:5678/api/v1#{endpoint}", headers, timeout: 5_000) do
        {:ok, %HTTPoison.Response{status_code: status, body: body}} ->
          # Check if response mentions telemetry or metrics
          has_telemetry = String.contains?(String.downcase(body), ["telemetry", "metrics", "trace", "span"])
          
          IO.puts("     #{endpoint}: #{status} #{if has_telemetry, do: "(has telemetry refs)", else: ""}")
          
          %{
            endpoint: endpoint,
            status: status,
            has_telemetry_refs: has_telemetry,
            body_size: byte_size(body)
          }
          
        {:error, reason} ->
          IO.puts("     #{endpoint}: ERROR - #{inspect(reason)}")
          %{endpoint: endpoint, error: reason}
      end
    end)
    
    # Check N8N configuration endpoints
    IO.puts("   Checking N8N configuration...")
    
    case HTTPoison.get("http://localhost:5678/api/v1/workflows", headers, timeout: 5_000) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, %{"data" => workflows}} ->
            IO.puts("     ✅ N8N API accessible, #{length(workflows)} workflows found")
            
            # Check if any workflows have telemetry nodes
            telemetry_workflows = Enum.filter(workflows, fn workflow ->
              workflow_str = inspect(workflow)
              String.contains?(String.downcase(workflow_str), ["telemetry", "metrics", "trace"])
            end)
            
            if length(telemetry_workflows) > 0 do
              IO.puts("     📊 Found #{length(telemetry_workflows)} workflows with telemetry references")
            else
              IO.puts("     ℹ️  No workflows with explicit telemetry references found")
            end
            
          _ ->
            IO.puts("     ⚠️  Could not parse N8N workflows response")
        end
        
      {:ok, %HTTPoison.Response{status_code: status}} ->
        IO.puts("     ❌ N8N API returned status: #{status}")
        
      {:error, reason} ->
        IO.puts("     ❌ Could not connect to N8N: #{inspect(reason)}")
    end
    
    endpoint_results
  end
  
  def test_real_vs_measured_performance do
    IO.puts("⏱️  Testing real vs measured performance...")
    
    # Test with actual HTTP calls to verify timing
    api_key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIwM2VmZDFhMC00YjEwLTQ0M2QtODJiMC0xYjc4NjUxNDU1YzkiLCJpc3MiOiJuOG4iLCJhdWQiOiJwdWJsaWMtYXBpIiwiaWF0IjoxNzUwMDAyNzA4LCJleHAiOjE3NTI1NTIwMDB9.LoaISJGi0FuwCU53NY_kt4t_RFsGFjHZBhX9BNT_8LM"
    
    headers = [
      {"X-N8N-API-KEY", api_key},
      {"Content-Type", "application/json"}
    ]
    
    # Test direct N8N API call timing
    IO.puts("   Testing direct N8N API call timing...")
    
    api_times = Enum.map(1..5, fn i ->
      simple_workflow = %{
        "name" => "timing_test_#{i}",
        "nodes" => [%{
          "parameters" => %{},
          "id" => "test-#{i}",
          "name" => "Test Node",
          "type" => "n8n-nodes-base.webhook",
          "typeVersion" => 1,
          "position" => [100, 200]
        }],
        "connections" => %{},
        "settings" => %{"executionOrder" => "v1"}
      }
      
      start_time = System.monotonic_time()
      
      case HTTPoison.post(
        "http://localhost:5678/api/v1/workflows",
        Jason.encode!(simple_workflow),
        headers,
        timeout: 10_000
      ) do
        {:ok, %HTTPoison.Response{status_code: status}} when status in [200, 201] ->
          end_time = System.monotonic_time()
          duration = System.convert_time_unit(end_time - start_time, :native, :microsecond)
          IO.puts("     API call #{i}: #{Float.round(duration / 1000, 2)}ms (status #{status})")
          {true, duration}
          
        {:ok, %HTTPoison.Response{status_code: status}} ->
          end_time = System.monotonic_time()
          duration = System.convert_time_unit(end_time - start_time, :native, :microsecond)
          IO.puts("     API call #{i}: #{Float.round(duration / 1000, 2)}ms (FAILED status #{status})")
          {false, duration}
          
        {:error, reason} ->
          end_time = System.monotonic_time()
          duration = System.convert_time_unit(end_time - start_time, :native, :microsecond)
          IO.puts("     API call #{i}: #{Float.round(duration / 1000, 2)}ms (ERROR: #{inspect(reason)})")
          {false, duration}
      end
    end)
    
    successful_calls = Enum.filter(api_times, fn {success, _} -> success end)
    
    if length(successful_calls) > 0 do
      avg_api_time = Enum.sum(Enum.map(successful_calls, fn {_, time} -> time end)) / length(successful_calls)
      IO.puts("   ✅ Average N8N API call time: #{Float.round(avg_api_time / 1000, 2)}ms")
      IO.puts("   📊 Success rate: #{length(successful_calls)}/#{length(api_times)} calls")
    else
      IO.puts("   ❌ No successful N8N API calls!")
    end
    
    %{
      total_calls: length(api_times),
      successful_calls: length(successful_calls),
      api_times: api_times
    }
  end
end

# Run all verification tests
telemetry_result = TelemetryVerification.test_telemetry_collection()
span_result = TelemetryVerification.test_opentelemetry_spans()
n8n_support = TelemetryVerification.check_n8n_telemetry_support()
performance_test = TelemetryVerification.test_real_vs_measured_performance()

IO.puts("")
IO.puts("🎯 === FINAL TELEMETRY VERIFICATION SUMMARY ===")
IO.puts("Telemetry Events Captured: #{telemetry_result.telemetry_events_count}")
IO.puts("OpenTelemetry Spans Working: #{span_result != :undefined}")
IO.puts("N8N API Accessible: #{length(Enum.filter(n8n_support, &Map.has_key?(&1, :status)))}")
IO.puts("Real API Performance: #{performance_test.successful_calls}/#{performance_test.total_calls} successful calls")

if telemetry_result.telemetry_events_count == 0 do
  IO.puts("")
  IO.puts("⚠️  WARNING: No telemetry events captured!")
  IO.puts("The performance metrics may not be accurately measured.")
end