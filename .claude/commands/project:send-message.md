# Inter-Agent Communication System

**Purpose**: Structured messaging system following APS protocol.

```bash
/project:send-message [recipient_role] [subject] [content]
```

## Features
- Validates recipient roles against APS specification
- Attaches messages to relevant APS files
- Creates standalone messages when needed
- Tracks delivery and acknowledgment
- Provides handoff instructions for recipients

## APS Message Format
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

## Valid Agent Roles
- **PM_Agent**: Product management and requirements
- **Architect_Agent**: System architecture and design
- **Developer_Agent**: Implementation and coding
- **QA_Agent**: Quality assurance and testing
- **DevOps_Agent**: Deployment and operations

## Message Types

### 1. Handoff Messages
- Process completion notifications
- Work transfer instructions
- Quality gate validation results
- Next-step recommendations

### 2. Coordination Messages
- Resource conflict notifications
- Dependency blocking alerts
- Timeline update communications
- Priority change notifications

### 3. Support Messages
- Technical assistance requests
- Knowledge sharing communications
- Problem escalation notifications
- Collaborative solution discussions

### 4. Status Updates
- Progress milestone communications
- Blocker identification and resolution
- Resource availability updates
- Completion confirmations

## Interactive Mode
When called without arguments:
1. Lists available recipient roles
2. Provides message template selection
3. Guides message composition
4. Validates message format
5. Confirms delivery

## Delivery Tracking
- **Message IDs**: Unique identifier generation
- **Delivery Confirmation**: Recipient acknowledgment tracking
- **Read Receipts**: Message consumption verification
- **Response Threading**: Message conversation tracking
- **Escalation Triggers**: Unread message alerting

## Usage Examples
```bash
/project:send-message                                          # Interactive mode
/project:send-message QA_Agent "Feature Ready" "Authentication module completed"
/project:send-message DevOps_Agent "Deployment Request" "Release v1.2.3 ready for staging"
```

## Integration Features
- **APS File Attachment**: Messages attached to relevant processes
- **Notification System**: Real-time agent notification
- **Workflow Triggers**: Message-based workflow automation
- **Audit Trail**: Complete communication history
- **Context Preservation**: Message context and artifact linking