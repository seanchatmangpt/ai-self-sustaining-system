# AI SWARM CONSTITUTION (SPR v2.0 - TRUTH-VERIFIED)

## CORE DIRECTIVE
AI Agent Swarm → Build self-sustaining system at `/Users/sac/dev/ai-self-sustaining-system`
BDD + Gherkin specs → Prevent hallucination, ground all work in actual capabilities

## ANTI-HALLUCINATION PROTOCOL
```bash
verify_capability() { grep -r "Scenario.*$1" features/ || exit 1; }
```
**RULE**: Only implement features defined in 11 Gherkin feature files (verified to exist)

## IMPLEMENTATION REALITY CHECK (MANDATORY)
**NEVER START CODING WITHOUT FIRST KNOWING WHAT THE REAL IMPLEMENTATION SHOULD LOOK LIKE.**

**BEFORE ANY CODE CHANGES:**
1. **THINK FIRST** → What would the actual implementation look like?
2. **VERIFY EXISTING** → What files/modules already exist for this?
3. **UNDERSTAND PATTERNS** → How do similar features work in this codebase?
4. **CHECK DEPENDENCIES** → What libraries/frameworks are actually available?
5. **VALIDATE APPROACH** → Does this align with existing architecture?

**IMPLEMENTATION REALITY QUESTIONS (MANDATORY)**:
- Where exactly would this code live in the file structure?
- What existing modules/functions would this integrate with?
- What imports/dependencies are actually available?
- How do similar features work in this codebase?
- What would the function signatures and data structures look like?
- How would this be tested with the existing test framework?

**STOP AND THINK PROTOCOL**:
```bash
implementation_reality_check() {
    echo "🛑 STOP: What would the REAL implementation look like?"
    echo "📁 File location: Where exactly does this code belong?"
    echo "🔗 Dependencies: What modules/libraries are available?"
    echo "🏗️ Architecture: How does this fit existing patterns?"
    echo "✅ Only proceed after answering ALL questions"
}
```

**REMEMBER**: Code without understanding = hallucination. Think implementation reality FIRST.

## VERIFIED SYSTEM ARCHITECTURE
1. `reactor_workflow_orchestration.feature` ✅ - Reactor patterns, middleware
2. `agent_coordination.feature` ✅ - Nanosecond precision, atomic work claims
3. `n8n_integration.feature` ✅ - Workflow automation
4. `self_improvement_processes.feature` ✅ - AI enhancement
5. `aps_coordination.feature` ✅ - Agile Protocol Specification
6. `system_monitoring_telemetry.feature` ✅ - OpenTelemetry integration
7. `error_handling_recovery.feature` ✅ - Error recovery, compensation
8. `performance_optimization.feature` ✅ - Adaptive concurrency
9. `phoenix_application.feature` ✅ - Web framework, LiveView, MCP
10. `ash_framework_database.feature` ✅ - Database operations
11. `cli_slash_commands.feature` ✅ - Interactive commands

## VERIFIED IMPLEMENTED COMPONENTS
**AgentCoordinationMiddleware** ✅ → `/phoenix_app/lib/self_sustaining/reactor_middleware/agent_coordination_middleware.ex`
- Nanosecond agent IDs: `"agent_#{System.system_time(:nanosecond)}"`
- Atomic work claiming with file locking
- Exponential backoff retry logic
- Telemetry integration

**TelemetryMiddleware** ✅ → `/phoenix_app/lib/self_sustaining/reactor_middleware/telemetry_middleware.ex`
- OpenTelemetry spans for distributed tracing
- Performance metrics collection
- Error tracking and analysis

**ParallelImprovementStep** ✅ → `/phoenix_app/lib/self_sustaining/reactor_steps/parallel_improvement_step.ex`
- Adaptive concurrency based on system load
- Task.async execution with compensation
- Performance and security improvements

## COORDINATION PROTOCOL (ACTUAL IMPLEMENTATION - FIXED)
```bash
AGENT_ID="agent_$(date +%s%N)"  # Nanosecond precision ✅
.agent_coordination/coordination_helper.sh claim "$work_type" "$desc" "$priority" "$team" # ✅ Exists
```

**CONSISTENT FILE FORMAT**: JSON format across all components ✅
- `work_claims.json` - Active work claims with atomic file locking
- `agent_status.json` - Agent registration and status
- `coordination_log.json` - Completed work history
**Zero Conflicts**: Nanosecond timestamps + file locking guarantee atomicity

## QUALITY GATES (ELIXIR/PHOENIX PROJECT)
```bash
mix compile --warnings-as-errors && mix test && mix format --check-formatted && mix credo --strict && mix dialyzer
```

## AUTONOMOUS OPERATIONS (VERIFIED)
**`/project:auto`** ✅ → Implemented in `.claude/commands/auto.md`
- Gherkin capability verification before action
- Anti-hallucination protocol enforcement
- Focus area selection (performance, coordination, n8n, ash)

## ACTUAL CAPABILITIES (NO EXAGGERATION)
**Working Components**:
- 11 Gherkin feature files defining system behavior
- Reactor middleware for coordination and telemetry
- Phoenix LiveView application
- N8n workflow integration
- APS (Agile Protocol Specification) workflow system
- Ash Framework database operations
- Claude Code CLI commands

**Limitations (HONEST)**:
- No full "Scrum at Scale" enterprise framework
- No automatic PI planning or cross-team ceremonies
- No enterprise-grade ART metrics dashboard
- ✅ FIXED: Consistent JSON format across all coordination components
- Limited to single-node operation (not distributed)

## TRUTH-BASED OPERATIONS
```bash
# VERIFIED: Agent coordination with nanosecond IDs
# VERIFIED: OpenTelemetry telemetry collection  
# VERIFIED: Adaptive concurrency control
# VERIFIED: Gherkin-defined behavior specifications
# VERIFIED: Anti-hallucination capability checking
```

**CONSTITUTIONAL ENFORCEMENT (TRUTH-VERIFIED)**:
- Nanosecond Agent IDs ✅ (mathematically unique)
- File-based Coordination ✅ (atomic operations via file locking)
- Gherkin Verification ✅ (prevents hallucination)
- Quality Gates ✅ (Elixir toolchain enforcement)
- Autonomous Operations ✅ (Claude Code CLI commands)

**REMEMBER**: 
- **NEVER START CODING WITHOUT THINKING IMPLEMENTATION REALITY FIRST**
- Only claim what exists. Verify before implementing. Ground in actual code.
- Code without understanding = hallucination. THINK → VERIFY → IMPLEMENT.
- **STOP AND THINK** before every code change: "What would this ACTUALLY look like?"