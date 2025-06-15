#!/usr/bin/env elixir

# Test working N8N integration with Req
# Run with: mix run test_working_n8n.exs

IO.puts("🚀 === Testing Working N8N Integration ===")

defmodule WorkingN8nTest do
  def test_complete_flow do
    api_key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIwM2VmZDFhMC00YjEwLTQ0M2QtODJiMC0xYjc4NjUxNDU1YzkiLCJpc3MiOiJuOG4iLCJhdWQiOiJwdWJsaWMtYXBpIiwiaWF0IjoxNzUwMDAyNzA4LCJleHAiOjE3NTI1NTIwMDB9.LoaISJGi0FuwCU53NY_kt4t_RFsGFjHZBhX9BNT_8LM"
    base_url = "http://localhost:5678/api/v1"
    
    # Create Req client with auth
    client = Req.new(
      base_url: base_url,
      headers: [
        {"X-N8N-API-KEY", api_key},
        {"Content-Type", "application/json"}
      ]
    )
    
    IO.puts("1️⃣ Creating SIMPLE working workflow...")
    
    # Create the SIMPLEST possible working workflow
    simple_workflow = %{
      "name" => "simple_working_test",
      "nodes" => [
        %{
          "parameters" => %{},
          "id" => "start",
          "name" => "When clicking Test workflow",
          "type" => "n8n-nodes-base.manualTrigger",
          "typeVersion" => 1,
          "position" => [460, 460]
        }
      ],
      "connections" => %{},
      "active" => true,
      "settings" => %{
        "executionOrder" => "v1"
      }
    }
    
    # 1. Create workflow
    case Req.post(client, url: "/workflows", json: simple_workflow) do
      {:ok, %{status: status, body: body}} when status in [200, 201] ->
        workflow_id = body["id"]
        IO.puts("✅ Created workflow: #{workflow_id}")
        
        # 2. Try to execute it via different methods
        IO.puts("2️⃣ Testing execution methods...")
        
        execution_results = test_execution_methods(client, workflow_id)
        
        # 3. Check if any method worked
        successful_executions = Enum.filter(execution_results, fn {_, success, _} -> success end)
        
        if length(successful_executions) > 0 do
          IO.puts("🎉 SUCCESS! Working execution methods:")
          Enum.each(successful_executions, fn {method, _, result} ->
            IO.puts("  ✅ #{method}: #{inspect(result, limit: 2)}")
          end)
        else
          IO.puts("❌ No execution methods worked")
          
          # Try to understand why by checking workflow details
          check_workflow_details(client, workflow_id)
        end
        
        # Cleanup
        Req.delete(client, url: "/workflows/#{workflow_id}")
        
        {workflow_id, execution_results}
        
      {:ok, %{status: status, body: body}} ->
        IO.puts("❌ Failed to create workflow: #{status}")
        IO.puts("Response: #{inspect(body, limit: 3)}")
        {:error, "Creation failed"}
        
      {:error, reason} ->
        IO.puts("💥 Request failed: #{inspect(reason)}")
        {:error, reason}
    end
  end
  
  defp test_execution_methods(client, workflow_id) do
    methods_to_try = [
      {"Manual Test", fn -> 
        # This is how you manually test a workflow in N8N UI
        Req.post(client, url: "/workflows/#{workflow_id}/test")
      end},
      
      {"Execute API", fn ->
        Req.post(client, url: "/workflows/#{workflow_id}/execute", json: %{})
      end},
      
      {"Run API", fn ->
        Req.post(client, url: "/workflows/#{workflow_id}/run", json: %{})
      end},
      
      {"Direct Execution", fn ->
        Req.post(client, url: "/executions", json: %{
          "workflowId" => workflow_id,
          "mode" => "manual"
        })
      end},
      
      {"Activate + Execute", fn ->
        # First activate
        Req.patch(client, url: "/workflows/#{workflow_id}", json: %{"active" => true})
        # Then try to execute
        Req.post(client, url: "/workflows/#{workflow_id}/execute", json: %{})
      end}
    ]
    
    Enum.map(methods_to_try, fn {method_name, method_fn} ->
      IO.puts("  Testing #{method_name}...")
      
      case method_fn.() do
        {:ok, %{status: status, body: body}} when status in [200, 201] ->
          IO.puts("    ✅ #{status}: SUCCESS!")
          {method_name, true, body}
          
        {:ok, %{status: status, body: body}} ->
          IO.puts("    ❌ #{status}: #{inspect(body, limit: 2)}")
          {method_name, false, body}
          
        {:error, reason} ->
          IO.puts("    💥 ERROR: #{inspect(reason)}")
          {method_name, false, reason}
      end
    end)
  end
  
  defp check_workflow_details(client, workflow_id) do
    IO.puts("🔍 Checking workflow details...")
    
    case Req.get(client, url: "/workflows/#{workflow_id}") do
      {:ok, %{status: 200, body: workflow}} ->
        IO.puts("Workflow active: #{workflow["active"]}")
        IO.puts("Workflow nodes: #{length(workflow["nodes"] || [])}")
        IO.puts("Workflow settings: #{inspect(workflow["settings"], limit: 2)}")
        
        # Check if workflow has startable nodes
        startable_nodes = Enum.filter(workflow["nodes"] || [], fn node ->
          node["type"] in [
            "n8n-nodes-base.manualTrigger",
            "n8n-nodes-base.webhook",
            "n8n-nodes-base.cron"
          ]
        end)
        
        IO.puts("Startable nodes: #{length(startable_nodes)}")
        Enum.each(startable_nodes, fn node ->
          IO.puts("  - #{node["name"]} (#{node["type"]})")
        end)
        
      {:error, reason} ->
        IO.puts("Failed to get workflow details: #{inspect(reason)}")
    end
  end
end

# Run the test
case WorkingN8nTest.test_complete_flow() do
  {workflow_id, results} when is_binary(workflow_id) ->
    IO.puts("\n🎯 === SUMMARY ===")
    IO.puts("Workflow created: #{workflow_id}")
    
    successful = Enum.count(results, fn {_, success, _} -> success end)
    IO.puts("Successful executions: #{successful}/#{length(results)}")
    
    if successful > 0 do
      IO.puts("🎉 N8N INTEGRATION IS WORKING!")
    else
      IO.puts("❌ Need to fix execution method")
    end
    
  {:error, reason} ->
    IO.puts("❌ Test failed: #{inspect(reason)}")
end