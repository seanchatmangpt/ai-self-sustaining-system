# APS Agent Coordination System

## Overview

The AI Self-Sustaining System implements a sophisticated multi-agent coordination system using the Agile Protocol Specification (APS). This system enables autonomous task management through specialized AI agents that communicate via standardized YAML files.

## Agent Roles & Responsibilities

### PM_Agent (Product Manager)
- **Function**: Translates high-level goals into machine-readable APS requirements
- **Inputs**: High-level prompts from the MCP (Desktop Commander)
- **Outputs**: Generates `[ID]_requirements.aps.yaml` files with Gherkin scenarios
- **Handoff**: Notifies Architect_Agent when requirements are complete

### Architect_Agent
- **Function**: Designs system architecture based on APS requirements
- **Inputs**: Consumes `[ID]_requirements.aps.yaml` from PM_Agent
- **Outputs**: Generates `[ID]_architecture.aps.yaml` with C4 models and tech stack
- **Handoff**: Notifies Developer_Agent when architecture is ready

### Developer_Agent
- **Function**: Implements code based on architectural specifications
- **Inputs**: Consumes architecture files and Gherkin scenarios
- **Outputs**: Source code, unit tests, commits to repository
- **Handoff**: Notifies QA_Agent when implementation is complete

### QA_Agent
- **Function**: Validates implemented features against Gherkin scenarios
- **Inputs**: Receives notifications from Developer_Agent
- **Outputs**: Generates `[ID]_test_results.aps.yaml` with pass/fail status
- **Handoff**: Routes to DevOps_Agent (pass) or Developer_Agent (fail)

### DevOps_Agent
- **Function**: Manages CI/CD pipeline, deployment, and monitoring
- **Inputs**: Receives approval from QA_Agent
- **Outputs**: Deployment scripts, telemetry data
- **Handoff**: Triggers self-adaptation loops based on telemetry thresholds

## APS Protocol Structure

### Core APS YAML Format
```yaml
process:
  name: "Unique_Process_Name"
  description: "Clear description of the overall process"
  roles:
    - name: "Agent_Role"
      description: "Responsibilities of the agent"
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
          description: "Description of the field"
```

### Agent Communication Format
```yaml
message:
  from: "Source_Agent_Role"
  to: "Target_Agent_Role"
  timestamp: "ISO_8601_DateTime"
  subject: "Brief_Message_Subject"
  content: "Detailed message content"
  artifacts:
    - path: "relative/path/to/file"
      type: "requirements | architecture | code | tests | deployment"
      status: "ready | in_progress | blocked | completed"
```

### Work Claiming Protocol
```yaml
claim:
  agent_id: "timestamp_role"
  process_id: "001_Process_Name"
  claimed_at: "2024-12-15T22:00:45Z"
  status: "claimed"
  estimated_completion: "2024-12-15T23:30:00Z"
```

## Agent Role Assignment System

### Automatic Role Detection
1. **Read Assignment State**: Check `.claude_role_assignment` file
2. **Scan Active Work**: Look for `*.aps.yaml` files to understand current processes
3. **Apply Assignment Logic**: Use decision tree to determine appropriate role

### Assignment Decision Tree
```
IF (*.aps.yaml files exist AND status="waiting_for_architect") THEN
    role = "Architect_Agent"
ELIF (*.aps.yaml files exist AND status="waiting_for_developer") THEN
    role = "Developer_Agent"  
ELIF (*.aps.yaml files exist AND status="waiting_for_qa") THEN
    role = "QA_Agent"
ELIF (*.aps.yaml files exist AND status="waiting_for_devops") THEN
    role = "DevOps_Agent"
ELIF (*.aps.yaml files exist AND status="blocked") THEN
    role = "Developer_Agent" # Support role
ELIF (no active processes found) THEN
    role = "PM_Agent" # Start new process
ELSE
    role = "Developer_Agent" # Default parallel support
```

## Workflow Coordination

### Sequential Pipeline
The primary workflow follows a strict sequence:
**PM_Agent** → **Architect_Agent** → **Developer_Agent** → **QA_Agent** → **DevOps_Agent**

### Parallel Support
- Multiple Developer_Agents can work on different features simultaneously
- QA_Agents can test while Developers work on new features
- DevOps_Agents continuously monitor while others develop
- Support agents help with debugging and blocked tasks

### Session Coordination Rules
1. **Unique Session IDs**: Each agent gets timestamp-based ID for tracking
2. **Work Claims**: Agents must claim specific APS files before working
3. **Status Broadcasting**: All status changes written to APS files
4. **Conflict Resolution**: Earlier timestamp wins for competing claims
5. **Handoff Protocol**: Explicit notification required for work transfers

## Agent Status Management

### Status Types
- `ready`: Agent available for new tasks
- `in_progress`: Agent actively working
- `blocked`: Agent needs input from another agent or MCP
- `completed`: Agent finished current task

### Status Tracking
Each agent maintains status in their APS files and the central `.claude_role_assignment` tracking file.

## MCP Interaction Protocol

Agents interact with the file system through explicit MCP commands:

- **READ_FILE**: `[path/to/file.ext]` - Get file content
- **WRITE_FILE**: `[path/to/file.ext] [content]` - Create/overwrite file
- **APPEND_FILE**: `[path/to/file.ext] [content]` - Add content to file
- **LIST_FILES**: `[directory_path]` - List directory contents
- **RUN_TESTS**: `[test_command]` - Execute test suite
- **SEND_MESSAGE**: `[recipient_agent_role] [aps_file_path]` - Notify another agent

## Error Handling & Recovery

### Common Error Scenarios
1. **File Operation Errors**: Directory doesn't exist, permission issues
2. **Test Failures**: Failed tests require developer intervention
3. **Blocked Agents**: Waiting for dependencies or external resources
4. **Conflicting Claims**: Multiple agents claiming same work

### Recovery Protocols
- Automatic retry with corrective actions
- Escalation to support agents for complex issues
- Rollback capabilities for failed implementations
- Clear error reporting through APS files

## Integration with Phoenix Application

The APS system integrates with the Phoenix application through:

### Elixir Implementation
- `SelfSustaining.APS` module manages APS file parsing and validation
- GenServer processes for agent coordination
- Database persistence of agent states and process tracking

### Web Interface
- LiveView dashboard for real-time agent status monitoring
- Process tracking and visualization
- Manual intervention capabilities for blocked processes

### Background Processing
- Oban jobs for asynchronous agent task execution
- Telemetry collection for agent performance monitoring
- Automatic cleanup of completed processes

## Future Enhancements

### Planned Improvements
1. **Advanced Conflict Resolution**: AI-powered decision making for competing claims
2. **Dynamic Load Balancing**: Intelligent work distribution across available agents
3. **Learning Systems**: Agents that improve their performance over time
4. **Cross-Process Dependencies**: Support for complex multi-process workflows
5. **External Agent Integration**: Support for specialized external AI agents

### Scalability Considerations
- Horizontal scaling through agent pool management
- Distributed coordination across multiple systems
- Performance optimization for high-volume task processing
- Resource monitoring and automatic scaling