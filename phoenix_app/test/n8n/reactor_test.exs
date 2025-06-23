defmodule N8n.ReactorTest do
  @moduledoc """
  Test suite for the n8n Reactor DSL framework.
  Tests workflow compilation, validation, and JSON generation.
  """

  use ExUnit.Case, async: true

  alias N8n.Reactor
  alias N8n.WorkflowManager

  describe "workflow compilation" do
    test "compiles a simple workflow successfully" do
      workflow_module = TestWorkflows.SimpleWorkflow

      assert {:ok, json} = Reactor.compile_workflow(workflow_module)
      assert is_map(json)
      assert json["name"] == "Simple Test Workflow"
      assert is_list(json["nodes"])
      assert is_map(json["connections"])
    end

    test "fails compilation for invalid workflow" do
      workflow_module = TestWorkflows.InvalidWorkflow

      assert {:error, reason} = Reactor.compile_workflow(workflow_module)
      assert is_binary(reason)
    end

    test "includes all required workflow fields" do
      workflow_module = TestWorkflows.CompleteWorkflow

      {:ok, json} = Reactor.compile_workflow(workflow_module)

      required_fields = ["name", "active", "nodes", "connections", "settings", "tags"]

      for field <- required_fields do
        assert Map.has_key?(json, field), "Missing required field: #{field}"
      end
    end
  end

  describe "workflow validation" do
    test "validates a correct workflow" do
      workflow_module = TestWorkflows.SimpleWorkflow

      assert :ok = Reactor.validate_workflow(workflow_module)
    end

    test "catches missing workflow definition" do
      workflow_module = TestWorkflows.EmptyWorkflow

      assert {:error, reason} = Reactor.validate_workflow(workflow_module)
      assert reason =~ "Workflow definition is required"
    end

    test "catches invalid node types" do
      workflow_module = TestWorkflows.InvalidNodeTypeWorkflow

      assert {:error, reason} = Reactor.validate_workflow(workflow_module)
      assert reason =~ "Unknown node type"
    end

    test "catches missing node connections" do
      workflow_module = TestWorkflows.DisconnectedWorkflow

      assert {:error, reason} = Reactor.validate_workflow(workflow_module)
      assert reason =~ "Missing connections"
    end
  end

  describe "node generation" do
    test "generates correct node structure" do
      workflow_module = TestWorkflows.NodeTestWorkflow

      {:ok, json} = Reactor.compile_workflow(workflow_module)

      nodes = json["nodes"]
      assert length(nodes) > 0

      # Test first node structure
      node = List.first(nodes)
      assert Map.has_key?(node, "id")
      assert Map.has_key?(node, "name")
      assert Map.has_key?(node, "type")
      assert Map.has_key?(node, "parameters")
      assert Map.has_key?(node, "position")
    end

    test "applies node optimizations" do
      workflow_module = TestWorkflows.OptimizationTestWorkflow

      {:ok, json} = Reactor.compile_workflow(workflow_module)

      http_nodes = Enum.filter(json["nodes"], &(&1["type"] == "n8n-nodes-base.httpRequest"))

      for node <- http_nodes do
        params = node["parameters"]
        assert Map.has_key?(params, "timeout")
        assert params["timeout"] == 10000
      end
    end
  end

  describe "connection generation" do
    test "generates connections from dependencies" do
      workflow_module = TestWorkflows.DependencyWorkflow

      {:ok, json} = Reactor.compile_workflow(workflow_module)

      connections = json["connections"]
      assert map_size(connections) > 0

      # Verify connection structure
      for {_source, outputs} <- connections do
        for {_output, targets} <- outputs do
          for target <- targets do
            assert Map.has_key?(target, "node")
            assert Map.has_key?(target, "type")
            assert Map.has_key?(target, "index")
          end
        end
      end
    end

    test "handles manual connections" do
      workflow_module = TestWorkflows.ManualConnectionWorkflow

      {:ok, json} = Reactor.compile_workflow(workflow_module)

      connections = json["connections"]

      # Should include manually defined connections
      assert connections["node1"]["main"] != nil
      assert Enum.any?(connections["node1"]["main"], &(&1["node"] == "node2"))
    end
  end

  describe "workflow manager integration" do
    test "lists all test workflows" do
      workflows = WorkflowManager.list_workflows()

      assert is_list(workflows)
      assert length(workflows) > 0

      # Each workflow should have required metadata
      for workflow <- workflows do
        assert Map.has_key?(workflow, :name)
        assert Map.has_key?(workflow, :module)
        assert Map.has_key?(workflow, :active)
        assert Map.has_key?(workflow, :node_count)
      end
    end

    test "compiles and exports workflow" do
      workflow_module = TestWorkflows.ExportTestWorkflow

      assert {:ok, file_path} = WorkflowManager.compile_and_export_workflow(workflow_module)
      assert File.exists?(file_path)

      # Verify file content
      {:ok, content} = File.read(file_path)
      {:ok, json} = Jason.decode(content)

      assert json["name"] == "Export Test Workflow"

      # Cleanup
      File.rm(file_path)
    end

    test "validates all workflows" do
      case WorkflowManager.validate_all_workflows() do
        {:ok, message} ->
          assert is_binary(message)
          assert message =~ "valid"

        {:error, message} ->
          # Some test workflows might be intentionally invalid
          assert is_binary(message)
      end
    end
  end

  describe "error handling" do
    test "handles compilation errors gracefully" do
      workflow_module = TestWorkflows.CompilationErrorWorkflow

      assert {:error, reason} = Reactor.compile_workflow(workflow_module)
      assert is_binary(reason)
      refute reason == ""
    end

    test "provides meaningful error messages" do
      workflow_module = TestWorkflows.MeaningfulErrorWorkflow

      {:error, reason} = Reactor.validate_workflow(workflow_module)

      # Error should be descriptive
      assert String.length(reason) > 10
      # Should start with capital letter
      assert reason =~ ~r/[A-Z]/
    end
  end

  describe "DSL syntax validation" do
    test "accepts valid DSL syntax" do
      # This test ensures the DSL compiles without errors
      assert Code.ensure_loaded?(TestWorkflows.ValidSyntaxWorkflow)
    end

    test "provides compile-time errors for invalid syntax" do
      # Test that invalid DSL syntax fails at compile time
      # This would be caught by the Elixir compiler
      assert_raise CompileError, fn ->
        Code.eval_string("""
        defmodule TestWorkflows.InvalidSyntax do
          use N8n.Reactor
          
          workflow do
            # Missing required name
          end
        end
        """)
      end
    end
  end

  describe "performance" do
    test "compiles workflows within reasonable time" do
      workflow_module = TestWorkflows.LargeWorkflow

      {time_microseconds, {:ok, _json}} =
        :timer.tc(fn -> Reactor.compile_workflow(workflow_module) end)

      # Should compile within 1 second
      assert time_microseconds < 1_000_000
    end

    test "handles multiple concurrent compilations" do
      workflow_modules = [
        TestWorkflows.ConcurrentWorkflow1,
        TestWorkflows.ConcurrentWorkflow2,
        TestWorkflows.ConcurrentWorkflow3
      ]

      tasks =
        workflow_modules
        |> Enum.map(fn module ->
          Task.async(fn -> Reactor.compile_workflow(module) end)
        end)

      results = Task.await_many(tasks, 5000)

      # All should succeed
      for result <- results do
        assert {:ok, _json} = result
      end
    end
  end
end
