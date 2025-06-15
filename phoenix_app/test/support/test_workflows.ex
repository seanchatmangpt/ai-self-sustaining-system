defmodule TestWorkflows do
  @moduledoc """
  Test workflow fixtures for the n8n DSL testing framework.
  Contains various workflow examples used in tests.
  """
end

defmodule TestWorkflows.SimpleWorkflow do
  @moduledoc "Simple test workflow with basic nodes"
  
  use N8n.Reactor
  
  workflow do
    name "Simple Test Workflow"
    active true
    tags ["test", "simple"]
  end
  
  trigger :schedule do
    type :schedule
    parameters %{
      "rule" => %{
        "interval" => [%{"field" => "hours", "hoursInterval" => 1}]
      }
    }
  end
  
  node "start", "n8n-nodes-base.httpRequest" do
    name "Start Node"
    position [100, 100]
    parameters %{
      "method" => "GET",
      "url" => "https://api.example.com/status"
    }
  end
  
  node "process", "n8n-nodes-base.code" do
    name "Process Data"
    position [300, 100]
    depends_on ["start"]
    parameters %{
      "mode" => "runOnceForAllItems",
      "jsCode" => "return items;"
    }
  end
end

defmodule TestWorkflows.CompleteWorkflow do
  @moduledoc "Complete test workflow with all features"
  
  use N8n.Reactor
  
  workflow do
    name "Complete Test Workflow"
    active true
    tags ["test", "complete", "comprehensive"]
    settings %{
      "timezone" => "UTC",
      "saveManualExecutions" => true
    }
  end
  
  trigger :webhook do
    type :webhook
    parameters %{
      "path" => "test-webhook",
      "method" => "POST"
    }
  end
  
  node "validate_input", "n8n-nodes-base.code" do
    name "Validate Input"
    position [200, 100]
    parameters %{
      "mode" => "runOnceForAllItems",
      "jsCode" => """
        if (!items[0].json.data) {
          throw new Error('Missing data field');
        }
        return items;
      """
    }
  end
  
  node "check_condition", "n8n-nodes-base.if" do
    name "Check Condition"
    position [400, 100]
    depends_on ["validate_input"]
    parameters %{
      "conditions" => %{
        "string" => [
          %{
            "value1" => "={{ $json.type }}",
            "operation" => "equal",
            "value2" => "urgent"
          }
        ]
      }
    }
  end
  
  node "urgent_handler", "n8n-nodes-base.httpRequest" do
    name "Handle Urgent"
    position [600, 50]
    depends_on ["check_condition"]
    parameters %{
      "method" => "POST",
      "url" => "https://api.example.com/urgent",
      "timeout" => 5000
    }
  end
  
  node "normal_handler", "n8n-nodes-base.httpRequest" do
    name "Handle Normal"
    position [600, 150]
    depends_on ["check_condition"]
    parameters %{
      "method" => "POST",
      "url" => "https://api.example.com/normal",
      "timeout" => 10000
    }
  end
  
  # Manual connections for conditional flow
  connection "check_condition", "urgent_handler" do
    source_output "true"
    target_input "main"
  end
  
  connection "check_condition", "normal_handler" do
    source_output "false"
    target_input "main"
  end
end

defmodule TestWorkflows.InvalidWorkflow do
  @moduledoc "Intentionally invalid workflow for error testing"
  
  use N8n.Reactor
  
  # Missing workflow definition
  
  node "orphan_node", "n8n-nodes-base.httpRequest" do
    name "Orphan Node"
    parameters %{
      "method" => "GET",
      "url" => "https://api.example.com"
    }
  end
end

defmodule TestWorkflows.EmptyWorkflow do
  @moduledoc "Empty workflow for testing validation"
  
  use N8n.Reactor
  
  # No workflow definition or nodes
end

defmodule TestWorkflows.InvalidNodeTypeWorkflow do
  @moduledoc "Workflow with invalid node type"
  
  use N8n.Reactor
  
  workflow do
    name "Invalid Node Type Test"
    active true
  end
  
  node "invalid", "invalid.node.type" do
    name "Invalid Node"
    parameters %{}
  end
end

defmodule TestWorkflows.DisconnectedWorkflow do
  @moduledoc "Workflow with disconnected nodes"
  
  use N8n.Reactor
  
  workflow do
    name "Disconnected Workflow"
    active true
  end
  
  node "node1", "n8n-nodes-base.httpRequest" do
    name "Node 1"
    parameters %{
      "method" => "GET",
      "url" => "https://api.example.com/1"
    }
  end
  
  node "node2", "n8n-nodes-base.httpRequest" do
    name "Node 2"
    depends_on ["nonexistent_node"]  # This will cause a validation error
    parameters %{
      "method" => "GET",
      "url" => "https://api.example.com/2"
    }
  end
end

defmodule TestWorkflows.NodeTestWorkflow do
  @moduledoc "Workflow for testing node generation"
  
  use N8n.Reactor
  
  workflow do
    name "Node Test Workflow"
    active true
  end
  
  node "http_node", "n8n-nodes-base.httpRequest" do
    name "HTTP Request Node"
    position [100, 100]
    parameters %{
      "method" => "POST",
      "url" => "https://api.example.com/data",
      "sendBody" => true,
      "bodyContentType" => "json"
    }
    retry_on_fail true
    continue_on_fail false
  end
  
  node "code_node", "n8n-nodes-base.code" do
    name "Code Node"
    position [300, 100]
    depends_on ["http_node"]
    parameters %{
      "mode" => "runOnceForAllItems",
      "jsCode" => "return items.map(item => ({ json: { processed: true, ...item.json } }));"
    }
    notes "This node processes the HTTP response"
  end
end

defmodule TestWorkflows.OptimizationTestWorkflow do
  @moduledoc "Workflow for testing optimizations"
  
  use N8n.Reactor
  
  workflow do
    name "Optimization Test"
    active true
  end
  
  node "http1", "n8n-nodes-base.httpRequest" do
    name "HTTP 1"
    parameters %{
      "method" => "GET",
      "url" => "https://api.example.com/1"
      # No timeout specified - should be optimized
    }
  end
  
  node "http2", "n8n-nodes-base.httpRequest" do
    name "HTTP 2"
    depends_on ["http1"]
    parameters %{
      "method" => "GET",
      "url" => "https://api.example.com/2"
      # No timeout specified - should be optimized
    }
  end
end

defmodule TestWorkflows.DependencyWorkflow do
  @moduledoc "Workflow for testing dependency-based connections"
  
  use N8n.Reactor
  
  workflow do
    name "Dependency Test"
    active true
  end
  
  node "start", "n8n-nodes-base.httpRequest" do
    name "Start"
    parameters %{
      "method" => "GET",
      "url" => "https://api.example.com/start"
    }
  end
  
  node "middle", "n8n-nodes-base.code" do
    name "Middle"
    depends_on ["start"]
    parameters %{
      "mode" => "runOnceForAllItems",
      "jsCode" => "return items;"
    }
  end
  
  node "end", "n8n-nodes-base.httpRequest" do
    name "End"
    depends_on ["middle"]
    parameters %{
      "method" => "POST",
      "url" => "https://api.example.com/end"
    }
  end
end

defmodule TestWorkflows.ManualConnectionWorkflow do
  @moduledoc "Workflow with manual connections"
  
  use N8n.Reactor
  
  workflow do
    name "Manual Connection Test"
    active true
  end
  
  node "node1", "n8n-nodes-base.if" do
    name "Condition"
    parameters %{
      "conditions" => %{
        "boolean" => [%{
          "value1" => true,
          "operation" => "equal",
          "value2" => true
        }]
      }
    }
  end
  
  node "node2", "n8n-nodes-base.httpRequest" do
    name "True Branch"
    parameters %{
      "method" => "GET",
      "url" => "https://api.example.com/true"
    }
  end
  
  node "node3", "n8n-nodes-base.httpRequest" do
    name "False Branch"
    parameters %{
      "method" => "GET",
      "url" => "https://api.example.com/false"
    }
  end
  
  connection "node1", "node2" do
    source_output "true"
    target_input "main"
  end
  
  connection "node1", "node3" do
    source_output "false"
    target_input "main"
  end
end

defmodule TestWorkflows.ExportTestWorkflow do
  @moduledoc "Simple workflow for export testing"
  
  use N8n.Reactor
  
  workflow do
    name "Export Test Workflow"
    active true
    tags ["test", "export"]
  end
  
  node "simple", "n8n-nodes-base.httpRequest" do
    name "Simple Request"
    parameters %{
      "method" => "GET",
      "url" => "https://api.example.com/export"
    }
  end
end

defmodule TestWorkflows.CompilationErrorWorkflow do
  @moduledoc "Workflow that should cause compilation errors"
  
  use N8n.Reactor
  
  workflow do
    name "Compilation Error Test"
    active true
  end
  
  # This will cause an error because the node type doesn't exist
  node "error_node", "non.existent.node.type" do
    name "Error Node"
    parameters %{}
  end
end

defmodule TestWorkflows.MeaningfulErrorWorkflow do
  @moduledoc "Workflow for testing meaningful error messages"
  
  use N8n.Reactor
  
  workflow do
    name "Meaningful Error Test"
    active true
  end
  
  node "bad_node", "n8n-nodes-base.httpRequest" do
    name "Bad Node"
    depends_on ["this_node_does_not_exist"]
    parameters %{
      "method" => "GET",
      "url" => "https://api.example.com"
    }
  end
end

defmodule TestWorkflows.ValidSyntaxWorkflow do
  @moduledoc "Workflow with valid DSL syntax"
  
  use N8n.Reactor
  
  workflow do
    name "Valid Syntax Test"
    active true
    tags ["syntax", "validation"]
  end
  
  node "valid", "n8n-nodes-base.httpRequest" do
    name "Valid Node"
    position [100, 100]
    parameters %{
      "method" => "GET",
      "url" => "https://api.example.com/valid"
    }
  end
end

defmodule TestWorkflows.LargeWorkflow do
  @moduledoc "Large workflow for performance testing"
  
  use N8n.Reactor
  
  workflow do
    name "Large Performance Test"
    active true
    tags ["performance", "large"]
  end
  
  # Generate many nodes programmatically
  for i <- 1..20 do
    node "node_#{i}", "n8n-nodes-base.httpRequest" do
      name "Node #{i}"
      position [i * 100, 100]
      parameters %{
        "method" => "GET",
        "url" => "https://api.example.com/node#{i}"
      }
      depends_on if i > 1, do: ["node_#{i-1}"], else: []
    end
  end
end

defmodule TestWorkflows.ConcurrentWorkflow1 do
  @moduledoc "First workflow for concurrent testing"
  
  use N8n.Reactor
  
  workflow do
    name "Concurrent Test 1"
    active true
  end
  
  node "concurrent1", "n8n-nodes-base.httpRequest" do
    name "Concurrent Node 1"
    parameters %{
      "method" => "GET",
      "url" => "https://api.example.com/concurrent1"
    }
  end
end

defmodule TestWorkflows.ConcurrentWorkflow2 do
  @moduledoc "Second workflow for concurrent testing"
  
  use N8n.Reactor
  
  workflow do
    name "Concurrent Test 2"
    active true
  end
  
  node "concurrent2", "n8n-nodes-base.httpRequest" do
    name "Concurrent Node 2"
    parameters %{
      "method" => "GET",
      "url" => "https://api.example.com/concurrent2"
    }
  end
end

defmodule TestWorkflows.ConcurrentWorkflow3 do
  @moduledoc "Third workflow for concurrent testing"
  
  use N8n.Reactor
  
  workflow do
    name "Concurrent Test 3"
    active true
  end
  
  node "concurrent3", "n8n-nodes-base.httpRequest" do
    name "Concurrent Node 3"
    parameters %{
      "method" => "GET",
      "url" => "https://api.example.com/concurrent3"
    }
  end
end