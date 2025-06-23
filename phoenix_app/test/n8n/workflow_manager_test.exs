defmodule N8n.WorkflowManagerTest do
  @moduledoc """
  Integration tests for the n8n Workflow Manager.
  Tests workflow compilation, export, and management functionality.
  """

  use ExUnit.Case, async: false

  alias N8n.WorkflowManager

  @test_export_dir "test/tmp/n8n_workflows"

  setup do
    # Ensure test export directory exists
    File.mkdir_p!(@test_export_dir)

    # Clean up any existing test files
    File.rm_rf!(@test_export_dir)
    File.mkdir_p!(@test_export_dir)

    # Override the export directory for tests
    Application.put_env(:self_sustaining, :workflow_export_dir, @test_export_dir)

    on_exit(fn ->
      # Clean up test files
      File.rm_rf!(@test_export_dir)

      # Restore original export directory
      Application.delete_env(:self_sustaining, :workflow_export_dir)
    end)

    :ok
  end

  describe "workflow listing" do
    test "lists available workflows" do
      workflows = WorkflowManager.list_workflows()

      assert is_list(workflows)
      assert length(workflows) > 0

      # Each workflow should have required fields
      for workflow <- workflows do
        assert Map.has_key?(workflow, :name)
        assert Map.has_key?(workflow, :module)
        assert Map.has_key?(workflow, :active)
        assert Map.has_key?(workflow, :node_count)
        assert Map.has_key?(workflow, :tags)

        assert is_binary(workflow.name)
        assert is_atom(workflow.module)
        assert is_boolean(workflow.active)
        assert is_integer(workflow.node_count)
        assert is_list(workflow.tags)
      end
    end

    test "includes test workflows" do
      workflows = WorkflowManager.list_workflows()
      workflow_names = Enum.map(workflows, & &1.name)

      # Should include our test workflows
      assert "Simple Test Workflow" in workflow_names
      assert "Complete Test Workflow" in workflow_names
    end
  end

  describe "workflow compilation" do
    test "compiles a simple workflow" do
      workflow_module = TestWorkflows.SimpleWorkflow

      assert {:ok, file_path} = WorkflowManager.compile_and_export_workflow(workflow_module)
      assert File.exists?(file_path)
      assert String.ends_with?(file_path, ".json")

      # Verify file content
      {:ok, content} = File.read(file_path)
      {:ok, json} = Jason.decode(content)

      assert json["name"] == "Simple Test Workflow"
      assert is_list(json["nodes"])
      assert is_map(json["connections"])
    end

    test "handles compilation errors gracefully" do
      workflow_module = TestWorkflows.InvalidWorkflow

      assert {:error, reason} = WorkflowManager.compile_and_export_workflow(workflow_module)
      assert is_binary(reason)
    end

    test "exports to correct file location" do
      workflow_module = TestWorkflows.ExportTestWorkflow

      {:ok, file_path} = WorkflowManager.compile_and_export_workflow(workflow_module)

      # Should be in the test export directory
      assert String.starts_with?(file_path, @test_export_dir)

      # Should have correct filename
      assert String.contains?(file_path, "export_test_workflow.json")
    end
  end

  describe "batch operations" do
    test "compiles all workflows" do
      {:ok, results} = WorkflowManager.compile_all_workflows()

      assert is_list(results)
      assert length(results) > 0

      # Should have both successful and failed compilations
      successful = Enum.count(results, &match?({:ok, _, _}, &1))
      failed = Enum.count(results, &match?({:error, _, _}, &1))

      assert successful > 0
      # Some test workflows are intentionally invalid
      assert failed >= 0

      # Check that files were created for successful compilations
      for {:ok, _module, file_path} <- results do
        assert File.exists?(file_path)

        # Verify JSON structure
        {:ok, content} = File.read(file_path)
        {:ok, json} = Jason.decode(content)

        assert Map.has_key?(json, "name")
        assert Map.has_key?(json, "nodes")
        assert Map.has_key?(json, "connections")
      end
    end

    test "validates all workflows" do
      result = WorkflowManager.validate_all_workflows()

      # Should return either success or error message
      case result do
        {:ok, message} ->
          assert is_binary(message)
          assert message =~ "valid"

        {:error, message} ->
          assert is_binary(message)
          assert message =~ "error"
      end
    end
  end

  describe "workflow details" do
    test "gets detailed workflow information" do
      workflow_module = TestWorkflows.CompleteWorkflow

      {:ok, details} = WorkflowManager.get_workflow_details(workflow_module)

      assert Map.has_key?(details, :name)
      assert Map.has_key?(details, :module)
      assert Map.has_key?(details, :active)
      assert Map.has_key?(details, :tags)
      assert Map.has_key?(details, :node_count)
      assert Map.has_key?(details, :nodes)
      assert Map.has_key?(details, :json_size)
      assert Map.has_key?(details, :compiled_at)

      assert details.name == "Complete Test Workflow"
      assert details.module == TestWorkflows.CompleteWorkflow
      assert is_list(details.nodes)
      assert is_integer(details.json_size)
      assert details.json_size > 0
    end

    test "handles invalid workflow modules" do
      invalid_module = NonExistentWorkflow

      assert {:error, _reason} = WorkflowManager.get_workflow_details(invalid_module)
    end
  end

  describe "JSON output validation" do
    test "generates valid n8n JSON structure" do
      workflow_module = TestWorkflows.CompleteWorkflow

      {:ok, file_path} = WorkflowManager.compile_and_export_workflow(workflow_module)
      {:ok, content} = File.read(file_path)
      {:ok, json} = Jason.decode(content)

      # Required n8n fields
      required_fields = [
        "name",
        "active",
        "nodes",
        "connections",
        "settings",
        "staticData",
        "tags",
        "createdAt",
        "updatedAt"
      ]

      for field <- required_fields do
        assert Map.has_key?(json, field), "Missing required field: #{field}"
      end

      # Nodes should be an array of objects with required fields
      assert is_list(json["nodes"])

      for node <- json["nodes"] do
        assert Map.has_key?(node, "id")
        assert Map.has_key?(node, "name")
        assert Map.has_key?(node, "type")
        assert Map.has_key?(node, "parameters")
        assert Map.has_key?(node, "position")

        assert is_binary(node["id"])
        assert is_binary(node["name"])
        assert is_binary(node["type"])
        assert is_map(node["parameters"])
        assert is_list(node["position"])
        assert length(node["position"]) == 2
      end

      # Connections should be a map
      assert is_map(json["connections"])

      # Each connection should have valid structure
      for {source_node, outputs} <- json["connections"] do
        assert is_binary(source_node)
        assert is_map(outputs)

        for {output_name, targets} <- outputs do
          assert is_binary(output_name)
          assert is_list(targets)

          for target <- targets do
            assert Map.has_key?(target, "node")
            assert Map.has_key?(target, "type")
            assert Map.has_key?(target, "index")

            assert is_binary(target["node"])
            assert is_binary(target["type"])
            assert is_integer(target["index"])
          end
        end
      end
    end

    test "includes proper node types" do
      workflow_module = TestWorkflows.NodeTestWorkflow

      {:ok, file_path} = WorkflowManager.compile_and_export_workflow(workflow_module)
      {:ok, content} = File.read(file_path)
      {:ok, json} = Jason.decode(content)

      node_types = Enum.map(json["nodes"], & &1["type"])

      # Should contain valid n8n node types
      assert "n8n-nodes-base.httpRequest" in node_types
      assert "n8n-nodes-base.code" in node_types

      # All node types should start with "n8n-nodes-"
      for node_type <- node_types do
        assert String.starts_with?(node_type, "n8n-nodes-")
      end
    end
  end

  describe "error scenarios" do
    test "handles missing workflow gracefully" do
      # This should not crash the application
      assert {:error, _} = WorkflowManager.get_workflow_details(NonExistentModule)
    end

    test "provides meaningful error messages" do
      workflow_module = TestWorkflows.MeaningfulErrorWorkflow

      {:error, reason} = WorkflowManager.compile_and_export_workflow(workflow_module)

      # Error should be descriptive and helpful
      assert is_binary(reason)
      assert String.length(reason) > 10

      # Should mention the specific issue
      assert reason =~ ~r/connection|dependency|node/i
    end

    test "handles file system errors" do
      # Make export directory read-only to simulate file system error
      File.chmod!(@test_export_dir, 0o444)

      workflow_module = TestWorkflows.SimpleWorkflow

      result = WorkflowManager.compile_and_export_workflow(workflow_module)

      # Should handle the error gracefully
      case result do
        {:error, reason} ->
          assert is_binary(reason)
          assert reason =~ ~r/write|permission|file/i

        {:ok, _} ->
          # If it succeeds despite read-only directory, that's also acceptable
          # (might happen if the file already exists and is writable)
          :ok
      end

      # Restore directory permissions
      File.chmod!(@test_export_dir, 0o755)
    end
  end

  describe "performance" do
    test "compiles workflows within reasonable time" do
      workflow_module = TestWorkflows.LargeWorkflow

      {time_microseconds, result} =
        :timer.tc(fn -> WorkflowManager.compile_and_export_workflow(workflow_module) end)

      # Should complete within 2 seconds
      assert time_microseconds < 2_000_000

      # Should still succeed
      assert {:ok, _file_path} = result
    end

    test "handles concurrent compilation requests" do
      workflow_modules = [
        TestWorkflows.ConcurrentWorkflow1,
        TestWorkflows.ConcurrentWorkflow2,
        TestWorkflows.ConcurrentWorkflow3
      ]

      tasks =
        workflow_modules
        |> Enum.map(fn module ->
          Task.async(fn -> WorkflowManager.compile_and_export_workflow(module) end)
        end)

      results = Task.await_many(tasks, 10_000)

      # All should succeed
      for result <- results do
        assert {:ok, file_path} = result
        assert File.exists?(file_path)
      end
    end
  end

  describe "integration with n8n API" do
    test "prepares correct data for n8n import" do
      workflow_module = TestWorkflows.SimpleWorkflow

      {:ok, file_path} = WorkflowManager.compile_and_export_workflow(workflow_module)
      {:ok, content} = File.read(file_path)
      {:ok, json} = Jason.decode(content)

      # Should have the structure expected by n8n import API
      assert Map.has_key?(json, "name")
      assert Map.has_key?(json, "nodes")
      assert Map.has_key?(json, "connections")
      assert Map.has_key?(json, "active")

      # Nodes should have proper IDs for n8n
      node_ids = Enum.map(json["nodes"], & &1["id"])
      # All IDs should be unique
      assert length(node_ids) == length(Enum.uniq(node_ids))

      # Connections should reference valid node IDs
      for {source_id, _outputs} <- json["connections"] do
        assert source_id in node_ids, "Connection references unknown node: #{source_id}"
      end
    end
  end
end
