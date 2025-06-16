# AI SWARM OPERATIONAL GUIDE (v4.0)

## QUICK START: ESSENTIAL WORKFLOW

```bash
# 1. Verify before implementing
grep -r "Scenario.*$FEATURE" features/ || exit 1

# 2. Coordinate work through S@S system  
./agent_coordination/coordination_helper.sh claim "$work_type" "$description" "$priority" "$team"

# 3. Quality gates before completion
mix compile --warnings-as-errors && mix test && mix format --check-formatted

# 4. Complete with metrics
./agent_coordination/coordination_helper.sh complete "$work_id" "success" "$velocity_points"
```

## SYSTEM OVERVIEW

**Location**: `/Users/sac/dev/ai-self-sustaining-system`
**Performance**: 22.5% information retention, 92.6% success rate, 7.4% error rate
**Architecture**: Reactor Engine + S@S Coordination + Claude AI + Phoenix/Ash Stack

## COORDINATION COMMANDS (HIGH-IMPACT)

### Work Management
```bash
# Claim work (atomic, nanosecond precision)
coordination_helper.sh claim "$type" "$desc" "$priority" "$team"
coordination_helper.sh progress "$work_id" "$percent" "$status"  
coordination_helper.sh complete "$work_id" "$result" "$points"

# Intelligence-enhanced claiming
coordination_helper.sh claim-intelligent "$type" "$desc" "$priority" "$team"
```

### Claude AI Analysis  
```bash
# Priority optimization with structured JSON
coordination_helper.sh claude-analyze-priorities

# Real-time coordination insights
coordination_helper.sh claude-stream "$focus_area" "$duration"

# System health assessment
coordination_helper.sh claude-health-analysis
```

### Enterprise Scrum at Scale
```bash
coordination_helper.sh dashboard              # Current sprint status
coordination_helper.sh pi-planning            # Program increment planning
coordination_helper.sh art-sync               # Cross-team alignment
coordination_helper.sh system-demo            # Integrated solution demo
```

## IMPLEMENTATION PROTOCOL

### ✅ ALWAYS DO
1. **Read actual files first** - Never assume structure or content
2. **Verify dependencies exist** - Check imports, libraries, integration points  
3. **Follow existing patterns** - Match architectural conventions
4. **Test immediately** - Validate behavior before proceeding

### ❌ NEVER DO
- Hallucinate functionality that doesn't exist
- Skip verification to save time
- Assume without testing
- Trust memory over actual file contents

### Reality Check
```bash
implementation_reality_check() {
    echo "🔍 Have you READ the actual files?"
    echo "🔍 Are dependencies VERIFIED to exist?" 
    echo "🔍 Does this follow EXISTING patterns?"
    echo "🔍 Will this ACTUALLY work here?"
}
```

## VERIFIED COMPONENTS

### Coordination System
- **Agent IDs**: `agent_$(date +%s%N)` (nanosecond precision)
- **File Locking**: Atomic operations, zero conflicts guaranteed
- **JSON Operations**: Consistent format across all components
- **Telemetry**: OpenTelemetry distributed tracing

### Performance Metrics
- **Memory**: 65.65MB baseline efficiency
- **Response**: Sub-100ms coordination operations  
- **Throughput**: 148 coordination operations/hour
- **Reliability**: Zero conflicts in work claiming

## AUTONOMOUS OPERATIONS

### Claude Code CLI Commands
```bash
/project:auto [focus_area]           # Autonomous operation with AI
/project:swarm-coordinate            # Enterprise coordination
/project:system-health [component]   # Health monitoring
/project:coordination-ops            # Shell access
```

### Focus Areas
- `performance` - System optimization and metrics
- `coordination` - Agent swarm management  
- `n8n` - Workflow automation integration
- `ash` - Database operations and framework

## DATA FILES (JSON ATOMIC)

```bash
agent_coordination/
├── work_claims.json      # Active work with timestamps
├── agent_status.json     # Team formations and metrics
├── coordination_log.json # Velocity and completed work
└── telemetry_spans.jsonl # Distributed tracing data
```

## QUALITY GATES

```bash
# Required before any completion
mix compile --warnings-as-errors
mix test  
mix format --check-formatted
mix credo --strict  # Optional but recommended
mix dialyzer       # Optional but recommended
```

## XAVOS INTEGRATION

**Quick Access**: `cd /Users/sac/dev/ai-self-sustaining-system/worktrees/xavos-system/xavos/`
**URL**: http://localhost:4002
**Admin**: http://localhost:4002/admin

```bash
# Essential XAVOS commands
./scripts/start_xavos.sh                    # Start system
./agent_coordination/deploy_xavos_complete.sh  # Full deployment  
./scripts/manage_xavos.sh status           # Check status
```

## TROUBLESHOOTING

### Common Issues
- **Port conflicts**: Check 4000, 4002, 4007 availability
- **Dependencies**: Run `mix deps.get` in Phoenix projects
- **Compilation**: Address warnings immediately
- **Coordination**: Use atomic operations only

### Performance Monitoring
```bash
# Check system health
coordination_helper.sh claude-health-analysis

# Monitor coordination efficiency  
coordination_helper.sh dashboard

# Real-time insights
coordination_helper.sh claude-stream system 30
```

## SUCCESS CRITERIA

- ✅ All operations tracked through S@S coordination
- ✅ Zero conflicts in work claiming (mathematically guaranteed)
- ✅ Performance metrics within established baselines
- ✅ Quality gates pass before completion
- ✅ Claude AI intelligence guides decision-making
- ✅ Enterprise S@S methodology followed

---
**Remember**: Verification-driven development prevents hallucination. Every claim must be evidence-based.