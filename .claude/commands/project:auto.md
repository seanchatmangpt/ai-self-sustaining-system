# Autonomous AI Agent Operation

**Purpose**: Autonomous AI agent: analyze system state, think strategically, and act.

```bash
/project:auto [focus_area]
```

## Autonomous Agent Sequence

### 1. Initialize Agent Context
- Read and understand all available slash commands
- Execute `/project:init-agent` to determine role and join swarm
- Run `/project:check-handoffs` to understand current coordination state
- Execute `/project:system-health` to assess overall system status

### 2. Strategic Analysis
- Analyze current system state and pending work
- Identify critical issues requiring immediate attention
- Evaluate opportunities for improvement and optimization
- Assess agent swarm coordination and workflow efficiency

### 3. Intelligent Decision Making
Prioritize actions based on:
- Critical system issues (security, reliability, performance)
- Pending agent handoffs and blocked processes
- Enhancement opportunities with high impact/low effort
- Strategic alignment with self-sustaining system goals

### 4. Autonomous Action Execution
Based on analysis, execute appropriate command sequence:

**For Critical Issues**:
- `/project:debug-system` to identify and resolve problems
- `/project:system-health` to verify fixes
- `/project:send-message` to notify relevant agents

**For Development Work**:
- `/project:claim-work` to take on appropriate tasks
- `/project:tdd-cycle` for test-driven development
- `/project:implement-enhancement` for improvements

**For Coordination Needs**:
- `/project:create-aps` for new processes
- `/project:send-message` for agent communication
- `/project:check-handoffs` for workflow management

### 5. INFINITE LOOP MODE
- Never stop operation until explicitly commanded
- Continuous cycle through steps 1-4
- Sleep 30 seconds between cycles
- Monitor for stop conditions (`STOP`, `EXIT`, `HALT`, `SHUTDOWN`)

## Termination Commands
- Type: `STOP`, `EXIT`, `HALT`, or `SHUTDOWN`
- Use: `/project:stop-auto` (when implemented)
- Interrupt: Ctrl+C or session termination

## Success Metrics
- System health improvements and issue resolution
- Enhanced agent coordination and workflow efficiency
- Successful completion of assigned tasks and handoffs
- Knowledge capture and institutional learning
- Strategic progress toward self-sustaining system goals