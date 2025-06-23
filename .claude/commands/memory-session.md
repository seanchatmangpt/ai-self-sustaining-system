AI context and memory management with shell-based coordination following proven patterns.

Memory operation: $ARGUMENTS (optional: session_init|memory_preserve|context_handoff|pattern_capture)

## Shell-Based Memory Operations

### 1. Session Initialization
```bash
# Initialize session with nanosecond precision ID
session_init() {
    local session_id="session_$(date +%s%N)"
    echo "$session_id" > .session_id
    
    # Create session memory file with structured template
    local session_file="session_memory_$(date +%s).md"
    
    cat > "$session_file" <<EOF
# Session Memory: ${AGENT_ROLE:-AI Agent}
**Session ID**: $session_id
**Timestamp**: $(date -u +%Y-%m-%dT%H:%M:%SZ)
**Agent Role**: ${AGENT_ROLE:-Autonomous AI Agent}
**Session Type**: ${SESSION_TYPE:-Development Session}

## Session Context

### Primary Objectives
- [ ] Objective 1
- [ ] Objective 2
- [ ] Objective 3

### System State Snapshot
\`\`\`yaml
current_state:
  active_work_items: $(jq length agent_coordination/work_claims.json 2>/dev/null || echo 0)
  coordination_files: $(ls agent_coordination/*.json 2>/dev/null | wc -l)
  session_start: $(date -u +%Y-%m-%dT%H:%M:%SZ)
\`\`\`

### Decision Log
EOF
    
    echo "✅ Session initialized: $session_id → $session_file"
    echo "$session_file"
}
```

### 2. Memory Preservation
```bash
# Preserve current session context to coordination files
memory_preserve() {
    local context_type="${1:-general}"
    local session_file=$(ls session_memory_*.md 2>/dev/null | tail -1)
    
    if [[ ! -f "$session_file" ]]; then
        echo "⚠️ No active session file found. Run session_init first."
        return 1
    fi
    
    # Update session file with current system state
    cat >> "$session_file" <<EOF

### Memory Preserve: $(date -u +%Y-%m-%dT%H:%M:%SZ)
**Context Type**: $context_type

**Current System State**:
- Active Agents: $(jq '[.[] | select(.status == "active")] | length' agent_coordination/agent_status.json 2>/dev/null || echo 0)
- Work Claims: $(jq length agent_coordination/work_claims.json 2>/dev/null || echo 0)
- Coordination Log: $(jq length agent_coordination/coordination_log.json 2>/dev/null || echo 0)

**Recent Operations**:
$(tail -5 agent_coordination/velocity_log.txt 2>/dev/null || echo "No recent velocity data")

EOF
    
    # Link to coordination helper for context
    agent_coordination/coordination_helper.sh dashboard >> "$session_file"
    
    echo "💾 Memory preserved in $session_file"
}
```

### 3. Context Handoff
```bash
# Prepare comprehensive handoff documentation
context_handoff() {
    local handoff_target="${1:-next_agent}"
    local handoff_file="session_handoff_$(date +%s).md"
    
    cat > "$handoff_file" <<EOF
# Session Handoff: $(date -u +%Y-%m-%dT%H:%M:%SZ)
**Handoff Target**: $handoff_target
**Session Context**: $(cat .session_id 2>/dev/null || echo "unknown")

## System State Summary
\`\`\`bash
# Quick system check commands
agent_coordination/coordination_helper.sh dashboard
agent_coordination/coordination_helper.sh agent-status
\`\`\`

## Active Work Items
$(jq -r '.[] | "- **\(.work_item_id)**: \(.description) [\(.status)]"' agent_coordination/work_claims.json 2>/dev/null || echo "No active work items")

## Recent Session Memory
$(tail -50 $(ls session_memory_*.md 2>/dev/null | tail -1) 2>/dev/null || echo "No session memory available")

## Continuation Commands
\`\`\`bash
# To resume coordination:
agent_coordination/coordination_helper.sh claim "continuation" "Resume handoff work" "high" "$handoff_target"

# To analyze system state:
agent_coordination/coordination_helper.sh claude-priorities

# To start monitoring:
agent_coordination/coordination_helper.sh claude-stream system 60
\`\`\`

## CLAUDE.md Updates Required
$(grep -n "TODO\|FIXME\|XXX" CLAUDE.md 2>/dev/null || echo "No pending CLAUDE.md updates")
EOF
    
    echo "📋 Handoff documentation: $handoff_file"
}
```

### 4. Pattern Capture
```bash
# Capture and document reusable patterns
pattern_capture() {
    local pattern_type="${1:-workflow}"
    local pattern_name="${2:-$(date +%s)_pattern}"
    local pattern_file="patterns/${pattern_type}_${pattern_name}.md"
    
    mkdir -p patterns
    
    case "$pattern_type" in
        "coordination")
            # Capture coordination patterns from recent operations
            cat > "$pattern_file" <<EOF
# Coordination Pattern: $pattern_name
**Captured**: $(date -u +%Y-%m-%dT%H:%M:%SZ)

## Pattern Commands
\`\`\`bash
# Extracted from coordination_helper.sh usage
$(tail -20 agent_coordination/velocity_log.txt | grep -o './coordination_helper.sh [^"]*' | sort | uniq)
\`\`\`

## Success Metrics
$(jq '.[] | select(.status == "completed") | {id: .work_item_id, points: .velocity_points, duration: .duration}' agent_coordination/coordination_log.json 2>/dev/null | tail -5)
EOF
            ;;
        "deployment")
            # Capture deployment patterns
            cat > "$pattern_file" <<EOF
# Deployment Pattern: $pattern_name
**Captured**: $(date -u +%Y-%m-%dT%H:%M:%SZ)

## Shell Commands Used
\`\`\`bash
$(history | tail -20 | grep -E '(mix|docker|deploy|start|stop)' | cut -c 8-)
\`\`\`
EOF
            ;;
        *)
            echo "# Generic Pattern: $pattern_name" > "$pattern_file"
            echo "**Type**: $pattern_type" >> "$pattern_file"
            echo "**Captured**: $(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$pattern_file"
            ;;
    esac
    
    echo "📝 Pattern captured: $pattern_file"
}
```

## Shell Integration Commands

### Quick Operations
```bash
# Initialize new session
bash -c "$(cat .claude/commands/memory-session.md | grep -A 30 'session_init()' | tail -25)"

# Preserve current state  
bash -c "$(cat .claude/commands/memory-session.md | grep -A 25 'memory_preserve()' | tail -20)"

# Create handoff documentation
bash -c "$(cat .claude/commands/memory-session.md | grep -A 35 'context_handoff()' | tail -30)"
```

### Coordination Integration
```bash
# Link with coordination helper
agent_coordination/coordination_helper.sh claim "memory_session" "Session memory operation" "medium" "memory_team"

# Update coordination log with memory operations
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ): Memory session operations completed" >> agent_coordination/velocity_log.txt
```

## Features
- **Nanosecond Precision**: Session IDs use `$(date +%s%N)` for mathematical uniqueness
- **JSON Integration**: Reads actual coordination files (`work_claims.json`, `agent_status.json`)
- **Shell Command Patterns**: Follows coordination_helper.sh style
- **Atomic Operations**: File-based coordination with proven locking patterns
- **OpenTelemetry Ready**: Structured for telemetry span integration

## Advanced Memory Operations
```bash
# Session memory with telemetry
session_init_with_telemetry() {
    local session_id=$(session_init)
    local trace_id=$(openssl rand -hex 16)
    
    # Create telemetry span
    echo "{\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"session_id\":\"$session_id\",\"trace_id\":\"$trace_id\",\"operation\":\"session_init\"}" >> agent_coordination/telemetry_spans.jsonl
    
    return 0
}

# Continuous memory monitoring
memory_monitor() {
    local duration="${1:-300}"  # 5 minutes default
    
    echo "🔄 Starting memory monitoring for $duration seconds..."
    
    for ((i=0; i<duration; i+=30)); do
        memory_preserve "monitor_$(date +%s)"
        sleep 30
    done
    
    echo "📊 Memory monitoring complete"
}
```

The shell-based memory system integrates with proven coordination patterns while maintaining nanosecond precision and JSON-based state management.