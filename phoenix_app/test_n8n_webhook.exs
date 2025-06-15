#!/usr/bin/env elixir

# Test script for N8N -> Reactor webhook integration
# Run with: mix run test_n8n_webhook.exs

IO.puts("=== Testing N8N -> Reactor Webhook Integration ===")

# Test the webhook processing function directly
test_webhook_data = %{
  "workflow_type" => "self_improvement",
  "improvement_type" => "performance",
  "data" => %{
    "metrics" => %{
      "response_time" => 150,
      "throughput" => 1000
    },
    "suggestions" => ["optimize database queries", "add caching"]
  },
  "source" => "n8n_automation"
}

IO.puts("🧪 Testing webhook processing...")

try do
  case SelfSustaining.N8N.Reactor.process_webhook("test_self_improvement_123", test_webhook_data) do
    {:ok, result} ->
      IO.puts("✅ Webhook processing successful!")
      IO.puts("   Reactor Module: #{result.reactor_module}")
      IO.puts("   Executed At: #{result.executed_at}")
      IO.puts("   Trace ID: #{result.trace_id}")
      IO.puts("   Reactor Result: #{inspect(result.reactor_result)}")
      
    {:error, reason} ->
      IO.puts("❌ Webhook processing failed: #{reason}")
  end
rescue
  error ->
    IO.puts("💥 Webhook test crashed: #{Exception.message(error)}")
    IO.puts("Stack trace: #{Exception.format_stacktrace(__STACKTRACE__)}")
end

IO.puts("")
IO.puts("🌐 Testing webhook endpoint via HTTP...")

# Test the actual HTTP endpoint
webhook_url = "http://localhost:4000/api/webhooks/n8n/test_performance_workflow"

test_payload = %{
  "workflow_type" => "performance",
  "metric_type" => "latency",
  "performance_data" => %{
    "avg_response_time" => 200,
    "p95_response_time" => 500,
    "error_rate" => 0.01
  },
  "thresholds" => %{
    "max_response_time" => 300,
    "max_error_rate" => 0.05
  },
  "optimization_target" => "latency"
}

headers = [{"Content-Type", "application/json"}]

IO.puts("📡 Sending HTTP request to webhook endpoint...")

case HTTPoison.post(webhook_url, Jason.encode!(test_payload), headers, timeout: 10_000) do
  {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
    case Jason.decode(body) do
      {:ok, response} ->
        IO.puts("✅ HTTP webhook successful!")
        IO.puts("   Status: #{response["status"]}")
        IO.puts("   Result: #{inspect(response["result"])}")
        
      _ ->
        IO.puts("✅ HTTP webhook successful but couldn't parse response")
        IO.puts("   Raw body: #{body}")
    end
    
  {:ok, %HTTPoison.Response{status_code: status, body: body}} ->
    IO.puts("⚠️  HTTP webhook returned #{status}")
    IO.puts("   Body: #{body}")
    
  {:error, %HTTPoison.Error{reason: :econnrefused}} ->
    IO.puts("🔌 Phoenix server not running - start with 'mix phx.server'")
    
  {:error, reason} ->
    IO.puts("❌ HTTP request failed: #{inspect(reason)}")
end

IO.puts("")
IO.puts("🔄 Testing N8N callback workflow creation...")

# Create a workflow that includes a callback to our webhook
callback_workflow = %{
  name: "reactor_callback_test",
  nodes: [
    %{
      id: "webhook_start",
      name: "Webhook Start",
      type: :webhook,
      position: [100, 200],
      parameters: %{
        "path" => "reactor-callback-test"
      }
    },
    %{
      id: "process_data",
      name: "Process Data",
      type: :function,
      position: [300, 200],
      parameters: %{
        "functionCode" => """
        // Process the incoming data
        return [{
          json: {
            processed: true,
            timestamp: new Date().toISOString(),
            original_data: $json
          }
        }];
        """
      }
    },
    %{
      id: "callback_reactor",
      name: "Callback to Reactor",
      type: :http,
      position: [500, 200],
      parameters: %{
        "url" => "http://localhost:4000/api/webhooks/n8n/callback_result",
        "method" => "POST",
        "headers" => %{
          "Content-Type" => "application/json"
        }
      }
    }
  ],
  connections: [
    %{from: "webhook_start", to: "process_data"},
    %{from: "process_data", to: "callback_reactor"}
  ]
}

# Test workflow compilation
IO.puts("🔧 Compiling callback workflow...")

try do
  case SelfSustaining.N8n.WorkflowManager.compile_workflow(callback_workflow) do
    {:ok, compile_result} ->
      IO.puts("✅ Callback workflow compiled successfully!")
      IO.puts("   Compiled at: #{compile_result.result.compilation_result.compiled_at}")
      IO.puts("   Node count: #{compile_result.result.compilation_result.node_count}")
      
    {:error, reason} ->
      IO.puts("❌ Callback workflow compilation failed: #{reason}")
  end
rescue
  error ->
    IO.puts("💥 Callback workflow compilation crashed: #{Exception.message(error)}")
end

IO.puts("")
IO.puts("✅ === N8N -> Reactor Webhook Integration Test Complete ===")