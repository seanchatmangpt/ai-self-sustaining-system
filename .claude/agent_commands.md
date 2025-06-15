# Agent Swarm Coordination Commands

## `/init-agent` - Agent Initialization & Role Assignment

**Purpose**: Automatically determine and assign agent roles based on current system state.

```bash
/init-agent
```

**Features**:
- Reads `.claude_role_assignment` for current agent state
- Scans for active APS files and pending work
- Applies intelligent role assignment logic
- Registers session with unique timestamp-based ID
- Announces role and provides context-aware guidance

**Role Assignment Logic**:
1. Check for incomplete handoffs (`waiting_for_[role]`)
2. Look for blocked processes needing support
3. Assign next sequential role in active processes
4. Default to PM_Agent for new processes

## `/create-aps` - APS Process Creation

**Purpose**: Generate structured APS YAML files for new processes.

```bash
/create-aps [process_name] [description]
# Interactive mode if no arguments provided
```

**Features**:
- Creates complete APS YAML structure
- Defines agent roles and responsibilities
- Sets up workflow state machine
- Includes Gherkin scenario templates
- Establishes communication protocols

## `/claim-work` - Work Assignment System

**Purpose**: Allow agents to claim specific APS processes for execution.

```bash
/claim-work [process_number]
# Interactive selection if no argument provided
```

**Features**:
- Lists all available APS processes
- Shows current status and assigned agents
- Prevents work conflicts with claim tracking
- Provides role-specific task guidance
- Updates APS files with claim information

## `/send-message` - Inter-Agent Communication

**Purpose**: Structured messaging system following APS protocol.

```bash
/send-message [recipient_role] [subject] [content]
# Interactive mode if no arguments provided
```

**Features**:
- Validates recipient roles
- Attaches messages to relevant APS files
- Creates standalone messages when needed
- Tracks delivery and acknowledgment
- Provides handoff instructions for recipients

## `/check-handoffs` - Coordination Status Monitor

**Purpose**: Monitor pending work and inter-agent communications.

```bash
/check-handoffs
```

**Features**:
- Shows current agent assignments
- Identifies processes ready for handoff
- Lists unread messages for current agent
- Provides role-specific recommendations
- Reports swarm coordination health