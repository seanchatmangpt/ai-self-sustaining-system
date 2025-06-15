# APS (Agile Protocol Specification) Slash Commands

For AI Agent Swarm Coordination in Self-Sustaining System

## Agent Role Management Commands

### `/aps-init`
Initialize APS agent system and auto-assign role based on current state
- Reads .claude_role_assignment file
- Scans for active *.aps.yaml files  
- Assigns role using decision tree logic
- Registers agent session and announces role

### `/aps-role [PM_Agent|Architect_Agent|Developer_Agent|QA_Agent|DevOps_Agent]`
Manually assign specific agent role for current session
- Overrides auto-assignment
- Updates .claude_role_assignment file
- Announces role assignment

### `/aps-status`
Check current APS system status
- Shows active agents and their roles
- Lists current processes and their states
- Shows pending handoffs and blocked tasks

## Workflow Management Commands

### `/aps-start <process_name>`
Start new APS process (PM_Agent role required)
- Creates new process ID and requirements.aps.yaml file
- Initializes APS YAML structure with process name
- Sets status to "requirements_gathering"

### `/aps-handoff <target_agent_role>`
Hand off current work to next agent in pipeline
- Updates current APS file with completion status
- Creates handoff message for target agent
- Sets status to "waiting_for_[target_role]"

### `/aps-claim <process_id>`
Claim work on specific APS process
- Adds agent claim to APS file
- Prevents conflicts between parallel agents
- Sets status to "claimed" with timestamp

## File Operations Commands

### `/aps-create-requirements <process_id> <description>`
Create requirements.aps.yaml file (PM_Agent)
- Generates APS YAML with Gherkin scenarios
- Includes process description and acceptance criteria
- Sets status to "ready_for_architecture"

### `/aps-create-architecture <process_id>`
Create architecture.aps.yaml file (Architect_Agent)
- Generates C4 model definitions
- Includes tech stack and non-functional requirements
- Sets status to "ready_for_implementation"

### `/aps-create-tests <process_id>`
Create test_results.aps.yaml file (QA_Agent)
- Generates test execution results
- Includes pass/fail status and bug reports
- Sets status based on test outcomes

## Communication Commands

### `/aps-message <recipient_role> <subject> <message>`
Send message to another agent role
- Creates message entry in relevant APS file
- Includes timestamp and sender information
- Notifies target agent of pending message

### `/aps-notify <process_id> <status_update>`
Broadcast status update for process
- Updates APS file with new status
- Logs status change with timestamp
- Triggers notifications to dependent agents

## Development Commands

### `/aps-implement <process_id>`
Begin implementation of APS process (Developer_Agent)
- Reads architecture.aps.yaml specifications
- Creates code structure based on requirements
- Writes unit tests alongside implementation

### `/aps-test <process_id>`
Execute tests for APS process (QA_Agent)
- Runs Gherkin scenario validation
- Executes unit and integration tests
- Generates test_results.aps.yaml with outcomes

### `/aps-deploy <process_id>`
Deploy completed process (DevOps_Agent)
- Validates all tests pass
- Executes deployment pipeline
- Updates telemetry.log with deployment status

## Monitoring Commands

### `/aps-telemetry`
View current system telemetry and health
- Shows deployment status
- Displays performance metrics
- Lists any threshold breaches requiring adaptation

### `/aps-self-adapt`
Trigger self-adaptation loop based on telemetry
- Analyzes telemetry data for improvement opportunities
- Creates new APS processes for system enhancements
- Notifies colony of adaptation requirements

## Utility Commands

### `/aps-list`
List all active APS processes and their status
- Shows process IDs and current states
- Indicates which agents are working on what
- Highlights blocked or waiting processes

### `/aps-history <process_id>`
Show history and timeline for specific process
- Displays all status changes and handoffs
- Shows which agents worked on the process
- Includes timestamps and completion metrics

### `/aps-validate <aps_file>`
Validate APS YAML file structure and content
- Checks YAML syntax and APS schema compliance
- Validates required fields are present
- Reports any structural issues

### `/aps-help [command]`
Show help for APS commands
- Lists all available commands if no argument
- Shows detailed help for specific command if provided
- Includes usage examples and requirements

## File Structure Commands

### `/aps-template <template_type>`
Generate APS YAML template
- Available types: requirements, architecture, tests, deployment
- Creates properly structured YAML with placeholders
- Includes all required APS fields and examples

### `/aps-merge <source_process> <target_process>`
Merge two APS processes
- Combines related processes into single workflow
- Maintains history and status information
- Handles conflicts and dependencies