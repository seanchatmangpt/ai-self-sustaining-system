# Claude Code Slash Commands for AI Self-Sustaining System

This directory contains comprehensive slash commands that implement the APS (Agile Protocol Specification) protocol and enable efficient AI agent swarm coordination.

## Command Categories

### 🤖 [Agent Swarm Coordination](./agent_commands.md)
- `/init-agent` - Automatic role assignment based on system state
- `/create-aps` - Generate structured APS YAML files
- `/claim-work` - Work assignment and conflict prevention
- `/send-message` - Inter-agent communication
- `/check-handoffs` - Coordination status monitoring

### 🛠️ [Development & Debugging](./development_commands.md)
- `/debug-with-claude` - AI-assisted debugging across Phoenix, n8n, and infrastructure
- `/tdd-workflow` - Test-driven development workflow management
- `/system-status` - Comprehensive system health monitoring
- `/analyze-health` - Detailed system diagnostics
- `/workflow-health` - n8n workflow monitoring

### 🚀 [AI Enhancement](./enhancement_commands.md)
- `/discover-improvements` - AI-powered improvement identification
- `/implement-enhancement` - Automated enhancement implementation
- `/next-enhancement` - Prioritized enhancement recommendations
- `/optimize-workflows` - Performance optimization

### 🧠 [Memory & Documentation](./memory_commands.md)
- `/memory-workflow` - Session memory and knowledge management
- Context preservation and handoff protocols
- Documentation patterns and templates

### 📋 [APS Protocol Commands](./aps_commands.md)
Complete APS workflow management commands for agent coordination

## Quick Start

1. **Initialize Agent Role**:
   ```bash
   /init-agent
   ```

2. **Check Current System State**:
   ```bash
   /check-handoffs
   /system-status
   ```

3. **Claim Work or Start New Process**:
   ```bash
   /claim-work [process_id]
   # OR
   /create-aps [process_name]
   ```

## Integration with APS Workflow

These commands are designed to work seamlessly with the APS protocol defined in `CLAUDE.md`. Each command follows Unix-style utility patterns and maintains state through APS YAML files.

### Agent Flow Example

```bash
# 1. Initialize and determine role
/init-agent

# 2. Check coordination needs
/check-handoffs

# 3. Claim or create work
/claim-work

# 4. Use appropriate development tools
/tdd-workflow          # For development
/debug-with-claude     # For troubleshooting
/memory-workflow       # For documentation

# 5. Coordinate with other agents
/send-message [recipient] [subject] [content]
```

## Command Implementation

All commands follow the MCP interaction protocol specified in CLAUDE.md:
- State awareness through file system reads
- Atomic operations with MCP confirmation
- Structured communication via APS YAML files
- Error handling and status reporting

For detailed usage of each command, see the individual command documentation files.