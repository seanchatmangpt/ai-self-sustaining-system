# Work Assignment System

**Purpose**: Allow agents to claim specific APS processes for execution.

```bash
/project:claim-work [process_number]
```

## Features
- Lists all available APS processes
- Shows current status and assigned agents
- Prevents work conflicts with claim tracking
- Provides role-specific task guidance
- Updates APS files with claim information

## Work Claiming Process

### 1. Process Discovery
- Scans for all `*.aps.yaml` files in project directory
- Analyzes process status and current assignments
- Identifies processes ready for handoff
- Filters processes appropriate for current agent role

### 2. Conflict Prevention
- Checks existing claims before assignment
- Validates agent role compatibility with process stage
- Ensures no duplicate work assignments
- Implements timestamp-based conflict resolution

### 3. Claim Registration
```yaml
claim:
  agent_id: "timestamp_role"
  process_id: "process_identifier"
  claimed_at: "ISO_8601_DateTime"
  status: "claimed"
  estimated_completion: "ISO_8601_DateTime"
```

### 4. Role-Specific Guidance
- **PM_Agent**: Requirements analysis and backlog management
- **Architect_Agent**: System design and technical specifications
- **Developer_Agent**: Implementation and code development
- **QA_Agent**: Testing and quality validation
- **DevOps_Agent**: Deployment and operational monitoring

## Interactive Selection
When called without arguments:
1. Lists all available processes with status
2. Shows process priorities and complexity
3. Highlights processes waiting for current agent role
4. Provides detailed process information
5. Allows selection by number or ID

## Claim Tracking Features
- **Unique Session IDs**: Timestamp-based agent identification
- **Status Broadcasting**: Real-time claim status updates
- **Completion Estimates**: Predictive completion time calculation
- **Handoff Preparation**: Automatic next-agent notification
- **Conflict Resolution**: First-come-first-served claim priority

## Usage Examples
```bash
/project:claim-work                    # Interactive selection
/project:claim-work 001               # Claim specific process
/project:claim-work authentication    # Claim by process name
```

## Integration with APS Workflow
- Updates process status to `in_progress`
- Notifies other agents of claim
- Begins work tracking and telemetry
- Prepares handoff documentation
- Monitors completion progress