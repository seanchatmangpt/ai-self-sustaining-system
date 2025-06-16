defmodule SelfSustaining.APSTest do
  @moduledoc """
  Test suite for the Agile Protocol Specification (APS) functionality.
  
  This test module validates the APS YAML parsing, validation, and integration
  capabilities within the self-sustaining AI system. Tests cover:
  
  - APS YAML schema validation
  - Process definition parsing
  - Role and activity validation
  - Scenario and data structure verification
  - Integration with agent coordination systems
  
  ## Test Data
  
  Uses predefined APS YAML structures that conform to the agent coordination
  protocol specifications. Test scenarios include both valid and invalid
  configurations to ensure robust error handling.
  
  ## Test Categories
  
  - **Schema Validation**: YAML structure and required field validation
  - **Process Parsing**: Agent role and activity definition processing
  - **Scenario Testing**: BDD-style scenario validation
  - **Integration Testing**: Coordination with agent systems
  """
  
  use ExUnit.Case, async: true

  alias SelfSustaining.APS

  @valid_aps_yaml """
  process:
    name: "Test_Process"
    description: "A test process for validation"
    roles:
      - name: "PM_Agent"
        description: "Product manager role"
      - name: "Developer_Agent"
        description: "Developer role"
    activities:
      - name: "Planning"
        assignee: "PM_Agent"
        tasks:
          - name: "Create_Requirements"
            description: "Define project requirements"
    scenarios:
      - name: "Happy_Path"
        steps:
          - type: "Given"
            description: "Requirements are defined"
          - type: "When"
            description: "Development begins"
          - type: "Then"
            description: "Code is implemented"
    data_structures:
      - name: "requirement"
        type: "record"
        fields:
          - name: "id"
            type: "string"
            description: "Unique identifier"
  """

  @valid_aps_with_claim """
  process:
    name: "Test_Process_With_Claim"
    description: "A test process with agent claim"
    roles:
      - name: "Developer_Agent"
        description: "Developer role"
    activities:
      - name: "Development"
        assignee: "Developer_Agent"
        tasks:
          - name: "Write_Code"
            description: "Implement the feature"
    scenarios:
      - name: "Implementation"
        steps:
          - type: "Given"
            description: "Requirements exist"
  claim:
    agent_id: "1234_Developer_Agent"
    process_id: "test_process"
    claimed_at: "2024-12-15T22:00:00Z"
    status: "claimed"
  """

  describe "parse_yaml/1" do
    test "parses valid APS YAML successfully" do
      assert {:ok, %APS{} = aps} = APS.parse_yaml(@valid_aps_yaml)
      
      assert aps.name == "Test_Process"
      assert aps.description == "A test process for validation"
      assert length(aps.roles) == 2
      assert length(aps.activities) == 1
      assert length(aps.scenarios) == 1
      assert length(aps.data_structures) == 1
      assert aps.status == "pending"
    end

    test "parses APS with claim correctly" do
      assert {:ok, %APS{} = aps} = APS.parse_yaml(@valid_aps_with_claim)
      
      assert aps.name == "Test_Process_With_Claim"
      assert aps.claim["agent_id"] == "1234_Developer_Agent"
      assert aps.status == "in_progress"
    end

    test "returns error for invalid YAML" do
      invalid_yaml = "invalid: yaml: content: ["
      
      assert {:error, reason} = APS.parse_yaml(invalid_yaml)
      assert String.contains?(reason, "Failed to parse YAML")
    end
  end

  describe "validate/1" do
    test "validates complete APS structure" do
      {:ok, aps} = APS.parse_yaml(@valid_aps_yaml)
      
      assert {:ok, ^aps} = APS.validate(aps)
    end

    test "returns errors for missing required fields" do
      incomplete_aps = %APS{
        name: nil,
        description: "Test",
        roles: [],
        activities: [],
        scenarios: []
      }
      
      assert {:error, errors} = APS.validate(incomplete_aps)
      assert "Process name is required" in errors
      assert "At least one role is required" in errors
      assert "At least one activity is required" in errors
    end

    test "validates role structure" do
      aps_with_invalid_role = %APS{
        name: "Test",
        description: "Test",
        roles: [%{"name" => nil, "description" => "Test"}],
        activities: [%{"name" => "Test", "assignee" => "PM_Agent"}],
        scenarios: [%{"steps" => [%{"type" => "Given", "description" => "Test"}]}]
      }
      
      assert {:error, errors} = APS.validate(aps_with_invalid_role)
      assert "Role name is required" in errors
    end
  end

  describe "current_agent/1" do
    test "extracts current agent from claim" do
      {:ok, aps} = APS.parse_yaml(@valid_aps_with_claim)
      
      assert APS.current_agent(aps) == "Developer_Agent"
    end

    test "returns nil when no claim exists" do
      {:ok, aps} = APS.parse_yaml(@valid_aps_yaml)
      
      assert APS.current_agent(aps) == nil
    end
  end

  describe "next_agent/1" do
    test "returns correct next agent in sequence" do
      assert APS.next_agent("PM_Agent") == "Architect_Agent"
      assert APS.next_agent("Architect_Agent") == "Developer_Agent"
      assert APS.next_agent("Developer_Agent") == "QA_Agent"
      assert APS.next_agent("QA_Agent") == "DevOps_Agent"
      assert APS.next_agent("DevOps_Agent") == nil
    end

    test "returns nil for invalid role" do
      assert APS.next_agent("Invalid_Agent") == nil
    end
  end

  describe "ready_for_handoff?/1" do
    test "returns true when process is completed with claim" do
      completed_aps = %APS{
        status: "completed",
        claim: %{"agent_id" => "1234_Developer_Agent"}
      }
      
      assert APS.ready_for_handoff?(completed_aps) == true
    end

    test "returns false when process is not completed" do
      in_progress_aps = %APS{
        status: "in_progress",
        claim: %{"agent_id" => "1234_Developer_Agent"}
      }
      
      assert APS.ready_for_handoff?(in_progress_aps) == false
    end

    test "returns false when no claim exists" do
      completed_aps = %APS{
        status: "completed",
        claim: nil
      }
      
      assert APS.ready_for_handoff?(completed_aps) == false
    end
  end
end