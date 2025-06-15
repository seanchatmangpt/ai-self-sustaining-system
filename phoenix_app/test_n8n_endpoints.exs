#!/usr/bin/env elixir

# Test N8N API endpoints to find the correct one
# Run with: mix run test_n8n_endpoints.exs

IO.puts("🔍 === Testing N8N API Endpoints ===")

defmodule N8nEndpointTester do
  def test_workflow_endpoints do
    api_key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIwM2VmZDFhMC00YjEwLTQ0M2QtODJiMC0xYjc4NjUxNDU1YzkiLCJpc3MiOiJuOG4iLCJhdWQiOiJwdWJsaWMtYXBpIiwiaWF0IjoxNzUwMDAyNzA4LCJleHAiOjE3NTI1NTIwMDB9.LoaISJGi0FuwCU53NY_kt4t_RFsGFjHZBhX9BNT_8LM"
    api_url = "http://localhost:5678/api/v1"
    
    headers = [
      {"Content-Type", "application/json"},
      {"X-N8N-API-KEY", api_key}
    ]
    
    # First create a test workflow
    workflow = %{
      "name" => "endpoint_test_workflow",
      "nodes" => [
        %{
          "parameters" => %{},
          "id" => "manual_trigger",
          "name" => "Manual Trigger",
          "type" => "n8n-nodes-base.manualTrigger",
          "typeVersion" => 1,
          "position" => [100, 200]
        },
        %{
          "parameters" => %{
            "functionCode" => "return [{\"json\": {\"message\": \"Test successful\", \"timestamp\": new Date().toISOString()}}];"
          },
          "id" => "function_node",
          "name" => "Test Function",
          "type" => "n8n-nodes-base.function",
          "typeVersion" => 1,
          "position" => [300, 200]
        }
      ],
      "connections" => %{
        "Manual Trigger" => %{
          "main" => [[%{
            "node" => "Test Function",
            "type" => "main",
            "index" => 0
          }]]
        }
      },
      "settings" => %{"executionOrder" => "v1"}
    }
    
    # Create workflow
    IO.puts("📝 Creating test workflow...")
    case Req.post(Req.new(base_url: api_url, headers: headers, receive_timeout: 10_000), url: "/workflows", json: workflow) do
      {:ok, %Req.Response{status: status_code, body: body}} when status_code in [200, 201] ->
        case body do
          %{"id" => workflow_id} ->
            IO.puts("✅ Created workflow: #{workflow_id}")
            
            # Try activation
            IO.puts("🔄 Testing activation...")
            activation_result = test_activation(workflow_id, api_url, api_key)
            IO.puts("Activation result: #{inspect(activation_result)}")
            
            # Test different execution endpoints
            test_execution_endpoints(workflow_id, api_url, api_key)
            
            # Cleanup
            HTTPoison.delete("#{api_url}/workflows/#{workflow_id}", headers)
            
          _ ->
            IO.puts("❌ Could not parse workflow creation response")
        end
        
      {:ok, %HTTPoison.Response{status_code: status_code, body: body}} ->
        IO.puts("❌ Failed to create workflow: #{status_code} - #{body}")
        
      {:error, reason} ->
        IO.puts("❌ HTTP error: #{inspect(reason)}")
    end
  end
  
  defp test_activation(workflow_id, api_url, api_key) do
    headers = [
      {"Content-Type", "application/json"},
      {"X-N8N-API-KEY", api_key}
    ]
    
    endpoints_to_try = [
      {"POST", "/workflows/#{workflow_id}/activate", %{"active" => true}},
      {"PATCH", "/workflows/#{workflow_id}", %{"active" => true}},
      {"PUT", "/workflows/#{workflow_id}/activate", %{}},
      {"POST", "/workflows/#{workflow_id}/toggle", %{}}
    ]
    
    Enum.map(endpoints_to_try, fn {method, endpoint, payload} ->
      IO.puts("  Trying #{method} #{endpoint}")
      
      result = case method do
        "POST" -> HTTPoison.post("#{api_url}#{endpoint}", Jason.encode!(payload), headers, timeout: 5_000)
        "PATCH" -> HTTPoison.patch("#{api_url}#{endpoint}", Jason.encode!(payload), headers, timeout: 5_000)
        "PUT" -> HTTPoison.put("#{api_url}#{endpoint}", Jason.encode!(payload), headers, timeout: 5_000)
      end
      
      case result do
        {:ok, %HTTPoison.Response{status_code: status_code, body: body}} ->
          IO.puts("    #{status_code}: #{String.slice(body, 0, 100)}")
          {method, endpoint, status_code, :success}
          
        {:error, reason} ->
          IO.puts("    ERROR: #{inspect(reason)}")
          {method, endpoint, :error, reason}
      end
    end)
  end
  
  defp test_execution_endpoints(workflow_id, api_url, api_key) do
    headers = [
      {"Content-Type", "application/json"},
      {"X-N8N-API-KEY", api_key}
    ]
    
    execution_data = %{"test" => true}
    
    endpoints_to_try = [
      {"POST", "/workflows/#{workflow_id}/execute"},
      {"POST", "/workflows/#{workflow_id}/test"},
      {"POST", "/workflows/#{workflow_id}/run"},
      {"POST", "/workflows/#{workflow_id}/trigger"},
      {"POST", "/executions"},
      {"POST", "/workflows/#{workflow_id}/activate"},
      {"GET", "/workflows/#{workflow_id}/execute"},
      {"POST", "/test-webhook/#{workflow_id}"}
    ]
    
    IO.puts("🚀 Testing execution endpoints...")
    
    results = Enum.map(endpoints_to_try, fn {method, endpoint} ->
      IO.puts("  Trying #{method} #{endpoint}")
      
      result = case method do
        "POST" -> 
          payload = if String.contains?(endpoint, "executions") do
            %{"workflowId" => workflow_id, "triggerData" => execution_data}
          else
            execution_data
          end
          HTTPoison.post("#{api_url}#{endpoint}", Jason.encode!(payload), headers, timeout: 5_000)
        "GET" -> 
          HTTPoison.get("#{api_url}#{endpoint}", headers, timeout: 5_000)
      end
      
      case result do
        {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
          IO.puts("    ✅ 200 SUCCESS: #{String.slice(body, 0, 200)}")
          {endpoint, 200, :success, body}
          
        {:ok, %HTTPoison.Response{status_code: 201, body: body}} ->
          IO.puts("    ✅ 201 CREATED: #{String.slice(body, 0, 200)}")
          {endpoint, 201, :created, body}
          
        {:ok, %HTTPoison.Response{status_code: status_code, body: body}} ->
          IO.puts("    ❌ #{status_code}: #{String.slice(body, 0, 100)}")
          {endpoint, status_code, :failed, body}
          
        {:error, reason} ->
          IO.puts("    💥 ERROR: #{inspect(reason)}")
          {endpoint, :error, reason, nil}
      end
    end)
    
    # Show successful endpoints
    successful = Enum.filter(results, fn {_, status, result, _} -> 
      result in [:success, :created] or status in [200, 201] 
    end)
    
    if length(successful) > 0 do
      IO.puts("\n🎉 WORKING ENDPOINTS:")
      Enum.each(successful, fn {endpoint, status, result, _} ->
        IO.puts("  ✅ #{endpoint} -> #{status} (#{result})")
      end)
    else
      IO.puts("\n😞 No working execution endpoints found")
    end
    
    results
  end
end

# Run the test
N8nEndpointTester.test_workflow_endpoints()