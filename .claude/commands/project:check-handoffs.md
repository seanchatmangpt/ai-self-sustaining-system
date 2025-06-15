# Coordination Status Monitor

**Purpose**: Monitor pending work and inter-agent communications.

```bash
/project:check-handoffs
```

## Features
- Shows current agent assignments and status
- Identifies processes ready for handoff
- Lists unread messages for current agent
- Provides role-specific recommendations
- Reports swarm coordination health

## Monitoring Areas

### 1. Active Agent Status
```
Agent ID              | Role            | Process         | Status      | Since
---------------------|-----------------|-----------------|-------------|--------
1750066159           | Developer_Agent | 001_APS_Engine  | active      | 2h 15m
1749966579           | QA_Agent        | 002_Auth_System | in_progress | 45m
1750120850           | PM_Agent        | 003_Dashboard   | waiting     | 1h 30m
```

### 2. Process Handoff Status
- **Ready for Handoff**: Completed processes awaiting next agent
- **Blocked Processes**: Processes waiting for dependencies
- **Overdue Handoffs**: Processes exceeding expected completion time
- **Priority Escalations**: High-priority processes requiring attention

### 3. Communication Health
- **Unread Messages**: Messages awaiting agent attention
- **Pending Responses**: Messages requiring response or action
- **Escalated Communications**: Messages escalated due to timeout
- **System Notifications**: Automated system alerts and updates

### 4. Workflow Efficiency Metrics
- **Average Handoff Time**: Time between process completion and pickup
- **Agent Utilization**: Current workload distribution across agents
- **Bottleneck Identification**: Stages with consistent delays
- **Success Rate**: Percentage of processes completing successfully

## Status Indicators
- **🟢 Active**: Agent currently working on assigned process
- **🟡 Waiting**: Agent available but waiting for work assignment
- **🔴 Blocked**: Agent unable to proceed due to dependencies
- **⚪ Idle**: Agent available for new work assignment
- **🔄 Handoff**: Process ready for transfer to next agent
- **⚠️ Overdue**: Process exceeding expected completion time

## Recommendations Engine
Based on current status, provides actionable recommendations:

### For Current Agent
- **Available Work**: Processes ready for claim by current agent role
- **Priority Tasks**: High-priority processes requiring immediate attention
- **Collaboration Opportunities**: Processes benefiting from parallel work
- **Skill Alignment**: Processes matching agent specialization

### For System Health
- **Load Balancing**: Suggestions for distributing work across agents
- **Process Optimization**: Recommendations for workflow improvements
- **Resource Allocation**: Guidance for efficient resource utilization
- **Quality Assurance**: Validation checkpoints and quality gates

## Interactive Features
- **Process Details**: Drill-down into specific process information
- **Message Preview**: Quick preview of unread messages
- **Agent Contact**: Direct communication with other agents
- **Status Updates**: Real-time status refresh and monitoring

## Usage Examples
```bash
/project:check-handoffs                # Full coordination status
/project:check-handoffs --processes    # Process-focused view
/project:check-handoffs --messages     # Communication-focused view
/project:check-handoffs --agents       # Agent-focused view
```

## Integration with APS Workflow
- **Real-time Updates**: Live status monitoring and refresh
- **Automated Alerts**: Proactive notification of handoff opportunities
- **Performance Analytics**: Historical coordination performance analysis
- **Process Health**: Overall system coordination health assessment