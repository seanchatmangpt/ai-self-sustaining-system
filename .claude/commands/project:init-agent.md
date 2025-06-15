# Agent Initialization & Role Assignment

**Purpose**: Automatically determine and assign agent roles based on current system state.

```bash
/project:init-agent
```

## Features
- Reads `.claude_role_assignment` for current agent state
- Scans for active APS files and pending work
- Applies intelligent role assignment logic
- Registers session with unique timestamp-based ID
- Announces role and provides context-aware guidance

## Role Assignment Logic
1. Check for incomplete handoffs (`waiting_for_[role]`)
2. Look for blocked processes needing support
3. Assign next sequential role in active processes
4. Default to PM_Agent for new processes

## Implementation

The command automatically:
1. Checks existing role assignments
2. Analyzes current APS processes
3. Determines optimal role for current session
4. Registers in coordination system
5. Provides role-specific guidance

## Usage Notes
- No arguments required - auto-determines best role
- Creates unique session ID based on timestamp
- Updates `.claude_role_assignment` file
- Follows APS protocol for agent coordination