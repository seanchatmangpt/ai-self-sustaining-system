defmodule SelfSustaining.APS.WorkflowEngineTest do
  use ExUnit.Case, async: false

  alias SelfSustaining.APS.{WorkflowEngine, ProcessState}
  alias SelfSustaining.APS

  @test_aps_content """
  process:
    name: "Test_Workflow_Process"
    description: "A test process for workflow engine"
    roles:
      - name: "PM_Agent"
        description: "Product manager"
      - name: "Developer_Agent"
        description: "Developer"
    activities:
      - name: "Planning"
        assignee: "PM_Agent"
        tasks:
          - name: "Create_Requirements"
            description: "Define requirements"
    scenarios:
      - name: "Basic_Flow"
        steps:
          - type: "Given"
            description: "Process is created"
          - type: "When"
            description: "Agent claims work"
          - type: "Then"
            description: "Work progresses"
  """

  setup do
    # Create a temporary test file
    test_file = "/tmp/test_workflow_process.aps.yaml"
    File.write!(test_file, @test_aps_content)
    
    on_exit(fn ->
      if File.exists?(test_file), do: File.rm!(test_file)
    end)
    
    {:ok, test_file: test_file}
  end

  describe "load_process/1" do
    test "loads and validates APS process file", %{test_file: test_file} do
      {:ok, pid} = WorkflowEngine.start_link()
      
      assert {:ok, process_id} = WorkflowEngine.load_process(test_file)
      assert process_id == "test_workflow_process"
      
      status = WorkflowEngine.get_status()
      assert status.active_processes == 1
      assert Map.has_key?(status.process_states, process_id)
      
      GenServer.stop(pid)
    end

    test "returns error for non-existent file" do
      {:ok, pid} = WorkflowEngine.start_link()
      
      assert {:error, reason} = WorkflowEngine.load_process("/non/existent/file.aps.yaml")
      assert String.contains?(reason, "Failed to read file")
      
      GenServer.stop(pid)
    end

    test "returns error for invalid YAML content" do
      invalid_file = "/tmp/invalid.aps.yaml"
      File.write!(invalid_file, "invalid: yaml: [")
      
      {:ok, pid} = WorkflowEngine.start_link()
      
      assert {:error, reason} = WorkflowEngine.load_process(invalid_file)
      assert String.contains?(reason, "Failed to parse YAML")
      
      File.rm!(invalid_file)
      GenServer.stop(pid)
    end
  end

  describe "get_status/0" do
    test "returns current workflow engine status", %{test_file: test_file} do
      {:ok, pid} = WorkflowEngine.start_link()
      
      # Initially empty
      status = WorkflowEngine.get_status()
      assert status.active_processes == 0
      assert status.process_states == %{}
      
      # After loading a process
      {:ok, _process_id} = WorkflowEngine.load_process(test_file)
      
      status = WorkflowEngine.get_status()
      assert status.active_processes == 1
      assert map_size(status.process_states) == 1
      
      GenServer.stop(pid)
    end
  end

  describe "execute_next/1" do
    test "executes next workflow step", %{test_file: test_file} do
      {:ok, pid} = WorkflowEngine.start_link()
      
      {:ok, process_id} = WorkflowEngine.load_process(test_file)
      
      assert {:ok, message} = WorkflowEngine.execute_next(process_id)
      assert String.contains?(message, "PM_Agent")
      
      GenServer.stop(pid)
    end

    test "returns error for non-existent process" do
      {:ok, pid} = WorkflowEngine.start_link()
      
      assert {:error, "Process not found"} = WorkflowEngine.execute_next("non_existent")
      
      GenServer.stop(pid)
    end
  end

  describe "complete_task/2" do
    test "marks task as completed for assigned agent", %{test_file: test_file} do
      {:ok, pid} = WorkflowEngine.start_link()
      
      {:ok, process_id} = WorkflowEngine.load_process(test_file)
      
      # Simulate agent assignment
      agent_id = "1234_PM_Agent"
      assert :ok = WorkflowEngine.complete_task(process_id, agent_id)
      
      GenServer.stop(pid)
    end

    test "returns error for non-existent process" do
      {:ok, pid} = WorkflowEngine.start_link()
      
      assert {:error, "Process not found"} = WorkflowEngine.complete_task("non_existent", "agent_id")
      
      GenServer.stop(pid)
    end
  end

  describe "get_next_agent/1" do
    test "returns next agent in workflow sequence" do
      {:ok, pid} = WorkflowEngine.start_link()
      
      assert WorkflowEngine.get_next_agent("PM_Agent") == "Architect_Agent"
      assert WorkflowEngine.get_next_agent("Developer_Agent") == "QA_Agent"
      assert WorkflowEngine.get_next_agent("DevOps_Agent") == nil
      
      GenServer.stop(pid)
    end
  end
end