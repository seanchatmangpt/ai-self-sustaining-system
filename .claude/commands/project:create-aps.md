# APS Process Creation

**Purpose**: Generate structured APS YAML files for new processes.

```bash
/project:create-aps [process_name] [description]
```

## Features
- Creates complete APS YAML structure
- Defines agent roles and responsibilities
- Sets up workflow state machine
- Includes Gherkin scenario templates
- Establishes communication protocols

## APS YAML Structure Generated
```yaml
process:
  name: "Unique_Process_Name"
  description: "Clear description of the overall process"
  roles:
    - name: "PM_Agent"
      description: "Product management responsibilities"
    - name: "Architect_Agent"
      description: "System architecture design"
    - name: "Developer_Agent"
      description: "Implementation and coding"
    - name: "QA_Agent"
      description: "Quality assurance and testing"
    - name: "DevOps_Agent"
      description: "Deployment and operations"
  activities:
    - name: "High_Level_Activity"
      assignee: "Agent_Role"
      tasks:
        - name: "Specific_Task"
          description: "Machine-executable task description"
  scenarios:
    - name: "Illustrative_Scenario"
      steps:
        - type: "Given | When | Then | And"
          description: "Step describing state, action, or outcome"
  data_structures:
    - name: "Data_Structure_Name"
      type: "record | list | etc."
      fields:
        - name: "field_name"
          type: "string | int | object"
          description: "Field description"
```

## Interactive Mode
When called without arguments, provides guided process creation:
1. Process name and description input
2. Role definition and responsibility assignment
3. Activity and task breakdown
4. Scenario specification with Gherkin syntax
5. Data structure definition
6. Validation and file generation

## Agent Workflow Integration
- **Sequential Flow**: PM → Architect → Developer → QA → DevOps
- **Parallel Support**: Multiple agents on different processes
- **State Tracking**: Process state management and persistence
- **Handoff Protocol**: Structured agent-to-agent communication
- **Quality Gates**: Validation points between workflow stages

## Usage Examples
```bash
/project:create-aps                                    # Interactive mode
/project:create-aps "User_Authentication" "Implement OAuth2 login system"
/project:create-aps "Performance_Optimization" "Optimize database queries"
```