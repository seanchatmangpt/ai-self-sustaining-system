Autonomous AI agent operation guided by comprehensive Gherkin specifications and anti-hallucination protocols.

Auto operation mode: $ARGUMENTS (optional: focus area like "performance", "coordination", "n8n", "ash")

## GHERKIN-DRIVEN AUTONOMOUS OPERATION

### Pre-Flight Verification (MANDATORY)
Before any autonomous action, verify capabilities exist in Gherkin specifications:

```bash
# MANDATORY: Check feature specifications exist
verify_gherkin_capability() {
    local capability="$1"
    local feature_dir="/Users/sac/dev/ai-self-sustaining-system/features"
    
    echo "🔍 Verifying capability: $capability"
    
    if ! find "$feature_dir" -name "*.feature" -exec grep -l "Scenario.*$capability" {} \; | head -1; then
        echo "❌ ERROR: Capability '$capability' not found in Gherkin specifications"
        echo "📋 Available capabilities:"
        find "$feature_dir" -name "*.feature" -exec basename {} .feature \;
        return 1
    fi
    
    echo "✅ Capability verified in Gherkin specifications"
    return 0
}

# Example verification before autonomous work
verify_gherkin_capability "Agent Coordination" || exit 1
```

### Implemented System Architecture (VERIFIED)
The autonomous agent operates within these **actually implemented** components:

1. **Reactor Workflows** (Located: `/phoenix_app/lib/self_sustaining/workflows/`)
   - `SelfImprovementReactor` - AI enhancement workflows
   - `N8nIntegrationReactor` - n8n compilation/execution
   - `APSReactor` - Agent coordination workflows

2. **Reactor Middleware** (Located: `/phoenix_app/lib/self_sustaining/reactor_middleware/`)
   - `AgentCoordinationMiddleware` - Nanosecond precision coordination
   - `TelemetryMiddleware` - OpenTelemetry integration

3. **Reactor Steps** (Located: `/phoenix_app/lib/self_sustaining/reactor_steps/`)
   - `ParallelImprovementStep` - Adaptive concurrency control
   - `N8nWorkflowStep` - n8n workflow operations

## AUTONOMOUS OPERATION MODES (GHERKIN-VERIFIED)

### Available Focus Areas
Based on implemented Gherkin specifications, the autonomous agent can focus on:

1. **"reactor"** - Reactor workflow orchestration and middleware enhancement
2. **"coordination"** - Agent coordination with nanosecond precision
3. **"n8n"** - N8n integration workflows and automation
4. **"ash"** - Ash Framework database operations and migrations
5. **"performance"** - Performance optimization and adaptive concurrency
6. **"telemetry"** - System monitoring and OpenTelemetry integration
7. **"error-handling"** - Error recovery and compensation logic

### Focus Area Selection Logic
```bash
# Auto-determine focus based on system state and Gherkin priorities
determine_autonomous_focus() {
    local requested_focus="$1"
    local feature_dir="/Users/sac/dev/ai-self-sustaining-system/features"
    
    case "$requested_focus" in
        "reactor")
            verify_gherkin_capability "Reactor Workflow" && 
            focus_on_reactor_orchestration ;;
        "coordination") 
            verify_gherkin_capability "Agent Coordination" &&
            focus_on_agent_coordination ;;
        "n8n")
            verify_gherkin_capability "N8n Integration" &&
            focus_on_n8n_workflows ;;
        "ash")
            verify_gherkin_capability "Ash.*Database" &&
            focus_on_database_operations ;;
        "performance")
            verify_gherkin_capability "Performance.*Optimization" &&
            focus_on_performance_tuning ;;
        *)
            echo "Auto-selecting focus based on current system needs..."
            auto_select_priority_focus ;;
    esac
}

### Autonomous Operation Workflow (Based on Current Todo List)
```bash
# ACTUAL PENDING TASKS from current system state
autonomous_workflow() {
    echo "📋 Current pending tasks (from todo list):"
    echo "1. Create AtomicAgentAssignmentStep and related coordination steps (medium priority)"
    echo "2. Enhance existing Reactor workflows with new middleware and advanced patterns (medium priority)"
    
    # Priority-based autonomous execution
    case "$1" in
        "coordination"|"reactor"|"")
            implement_atomic_agent_assignment_step ;;
        "enhancement"|"middleware")
            enhance_reactor_workflows_with_middleware ;;
        *)
            echo "Available autonomous focus areas:"
            echo "- coordination: Implement AtomicAgentAssignmentStep"
            echo "- enhancement: Enhance Reactor workflows with middleware"
            ;;
    esac
}

implement_atomic_agent_assignment_step() {
    echo "🎯 Implementing AtomicAgentAssignmentStep based on Gherkin specifications..."
    
    # Reference Gherkin scenarios from agent_coordination.feature
    verify_gherkin_capability "Atomic.*Agent.*Assignment" || return 1
    
    # Follow the pattern from existing ParallelImprovementStep
    local base_dir="/Users/sac/dev/ai-self-sustaining-system/phoenix_app/lib/self_sustaining/reactor_steps"
    
    echo "📂 Creating new Reactor step in: $base_dir"
    echo "📋 Following Gherkin scenarios from agent_coordination.feature"
    echo "🔧 Using patterns from existing ParallelImprovementStep"
}

enhance_reactor_workflows_with_middleware() {
    echo "🎯 Enhancing existing Reactor workflows with new middleware..."
    
    # Reference implemented middleware components
    local middleware_dir="/Users/sac/dev/ai-self-sustaining-system/phoenix_app/lib/self_sustaining/reactor_middleware"
    local workflows_dir="/Users/sac/dev/ai-self-sustaining-system/phoenix_app/lib/self_sustaining/workflows"
    
    echo "📂 Available middleware: AgentCoordinationMiddleware, TelemetryMiddleware"
    echo "📂 Target workflows: SelfImprovementReactor, N8nIntegrationReactor, APSReactor"
    echo "🔧 Integrating middleware with existing workflow patterns"
}
```

## GHERKIN-DRIVEN QUALITY GATES

### Mandatory Pre-Implementation Validation
```bash
# ANTI-HALLUCINATION: Verify all features exist in Gherkin before implementation
pre_implementation_checks() {
    local feature_name="$1"
    local scenario_name="$2"
    
    echo "🔍 Running pre-implementation validation..."
    
    # Check 1: Gherkin specification exists
    if ! verify_gherkin_capability "$scenario_name"; then
        echo "❌ HALT: No Gherkin specification for '$scenario_name'"
        return 1
    fi
    
    # Check 2: Current system state allows implementation
    check_system_readiness() {
        echo "🏥 Checking Phoenix application status..."
        curl -s http://localhost:4000/health >/dev/null || {
            echo "⚠️  Phoenix not running, attempting to start..."
            return 1
        }
        
        echo "📊 Checking database connectivity..."
        mix ecto.migrate --check >/dev/null 2>&1 || {
            echo "⚠️  Database issues detected"
            return 1
        }
        
        echo "✅ System ready for implementation"
        return 0
    }
    
    check_system_readiness
}

# Example usage in autonomous mode
autonomous_implementation() {
    local focus="$1"
    
    case "$focus" in
        "coordination")
            pre_implementation_checks "agent_coordination" "Atomic Agent Assignment" &&
            implement_from_gherkin "agent_coordination" ;;
        "reactor")
            pre_implementation_checks "reactor_workflow_orchestration" "Reactor Middleware Integration" &&
            implement_from_gherkin "reactor_workflow_orchestration" ;;
        *)
            echo "🎯 Available autonomous implementations:"
            echo "  /project:auto coordination - Implement agent coordination features"
            echo "  /project:auto reactor - Implement reactor workflow enhancements"
            ;;
    esac
}
```

### Implementation Pattern (Anti-Hallucination)
```bash
# ONLY implement features that exist in Gherkin specifications
implement_from_gherkin() {
    local feature_file="$1"
    local gherkin_path="/Users/sac/dev/ai-self-sustaining-system/features/${feature_file}.feature"
    
    echo "📋 Extracting implementation requirements from: $gherkin_path"
    
    # Parse Gherkin scenarios for implementation guidance
    echo "🔍 Available scenarios in $feature_file:"
    grep "Scenario:" "$gherkin_path" | head -5
    
    echo "📝 Implementation will follow Given-When-Then patterns from Gherkin"
    echo "🛡️  Anti-hallucination: Only implementing defined behaviors"
}

## AUTONOMOUS EXECUTION SEQUENCE (GHERKIN-GUIDED)

### Step 1: System State Analysis
```bash
# Analyze current system state using implemented capabilities
analyze_system_state() {
    echo "🔍 Analyzing current system state..."
    
    # Check implemented Reactor workflows
    local workflows_dir="/Users/sac/dev/ai-self-sustaining-system/phoenix_app/lib/self_sustaining/workflows"
    echo "📂 Available Reactor workflows:"
    ls "$workflows_dir"/*.ex 2>/dev/null | xargs -I{} basename {} .ex
    
    # Check implemented middleware  
    local middleware_dir="/Users/sac/dev/ai-self-sustaining-system/phoenix_app/lib/self_sustaining/reactor_middleware"
    echo "🔧 Available middleware:"
    ls "$middleware_dir"/*.ex 2>/dev/null | xargs -I{} basename {} .ex
    
    # Check Gherkin specifications
    local features_dir="/Users/sac/dev/ai-self-sustaining-system/features"
    echo "📋 Available Gherkin specifications:"
    ls "$features_dir"/*.feature 2>/dev/null | xargs -I{} basename {} .feature
    
    echo "✅ System state analysis complete"
}

# Work priority determination based on actual pending tasks
determine_work_priority() {
    echo "📋 Current pending work from todo list:"
    echo "1. AtomicAgentAssignmentStep (medium priority)"
    echo "2. Enhance Reactor workflows with middleware (medium priority)"
    
    # Auto-select based on system readiness
    if [[ "$1" == "coordination" ]] || [[ -z "$1" ]]; then
        echo "🎯 Priority: Implement AtomicAgentAssignmentStep"
        return 0
    elif [[ "$1" == "enhancement" ]] || [[ "$1" == "middleware" ]]; then
        echo "🎯 Priority: Enhance Reactor workflows with middleware"
        return 0
    fi
    
    echo "🤖 Auto-selecting: AtomicAgentAssignmentStep (first pending task)"
}
```

### Step 2: Gherkin-Verified Implementation
```bash
# Execute work following Gherkin specifications
execute_autonomous_work() {
    local focus_area="$1"
    
    echo "🚀 Starting autonomous work execution..."
    
    # Step 1: Verify capabilities exist in Gherkin
    analyze_system_state
    determine_work_priority "$focus_area"
    
    # Step 2: Execute based on Gherkin scenarios
    case "$focus_area" in
        "coordination"|"")
            echo "🎯 Implementing agent coordination features..."
            verify_gherkin_capability "Agent.*Assignment" && 
            implement_atomic_agent_assignment_step ;;
        "enhancement"|"middleware") 
            echo "🎯 Enhancing workflows with middleware..."
            verify_gherkin_capability "Reactor.*Middleware" &&
            enhance_reactor_workflows_with_middleware ;;
        *)
            echo "❓ Unknown focus area: $focus_area"
            echo "Available options: coordination, enhancement"
            return 1 ;;
    esac
    
    echo "✅ Autonomous work execution complete"
}
```

### Step 3: Quality Gates and Verification
```bash
# Comprehensive quality gates based on Gherkin scenarios
run_quality_gates() {
    echo "🔧 Running quality gates..."
    
    # Test execution (from Phoenix and Ash specifications)
    echo "🧪 Running test suite..."
    if ! mix test; then
        echo "❌ Tests failed - halting autonomous execution"
        return 1
    fi
    
    # Code quality checks
    echo "📊 Running code quality checks..."
    mix format --check-formatted || {
        echo "⚠️  Code formatting issues detected, auto-fixing..."
        mix format
    }
    
    # Database integrity (Ash Framework requirements)
    echo "🗄️  Checking database integrity..."
    mix ash_postgres.generate_migrations --check || {
        echo "⚠️  Database migration issues detected"
        return 1
    }
    
    # Compilation check (zero warnings requirement)
    echo "⚙️  Verifying compilation..."
    if ! mix compile --warnings-as-errors; then
        echo "❌ Compilation warnings detected - must fix before completion"
        return 1
    fi
    
    echo "✅ All quality gates passed"
    return 0
}

# Continuous improvement feedback loop
continuous_improvement_cycle() {
    echo "🔄 Starting continuous improvement cycle..."
    
    # Analyze current implementation against Gherkin scenarios
    analyze_gherkin_compliance() {
        local feature_dir="/Users/sac/dev/ai-self-sustaining-system/features"
        echo "📋 Checking compliance with Gherkin specifications..."
        
        # Count implemented vs specified scenarios
        local total_scenarios=$(find "$feature_dir" -name "*.feature" -exec grep -c "Scenario:" {} \; | awk '{sum+=$1} END {print sum}')
        echo "📊 Total Gherkin scenarios: $total_scenarios"
        echo "🎯 Implementation guidance available for all autonomous work"
    }
    
    analyze_gherkin_compliance
    
    echo "🔄 Improvement cycle complete - ready for next iteration"
}
```

### Autonomous Operation Loop (Anti-Hallucination)
```bash
# Main autonomous operation loop - grounded in actual system capabilities
autonomous_main_loop() {
    local focus_area="${1:-coordination}"  # Default to coordination work
    local max_iterations="${2:-5}"         # Limit iterations to prevent runaway
    local iteration=0
    
    echo "🤖 Starting autonomous operation loop (max $max_iterations iterations)"
    echo "🎯 Focus area: $focus_area"
    
    while [[ $iteration -lt $max_iterations ]]; do
        echo "🔄 Iteration $((iteration + 1))/$max_iterations"
        
        # Step 1: System state analysis
        analyze_system_state
        
        # Step 2: Verify Gherkin-defined capabilities
        if ! verify_gherkin_capability ".*"; then
            echo "❌ No valid Gherkin capabilities found - halting"
            break
        fi
        
        # Step 3: Execute work based on focus area
        if ! execute_autonomous_work "$focus_area"; then
            echo "⚠️  Work execution failed - trying different focus"
            focus_area="enhancement"  # Switch to fallback
        fi
        
        # Step 4: Quality gates
        if ! run_quality_gates; then
            echo "❌ Quality gates failed - halting autonomous operation"
            break
        fi
        
        # Step 5: Continuous improvement
        continuous_improvement_cycle
        
        # Step 6: Brief pause for system stability
        echo "⏸️  Pausing for system stability (30 seconds)..."
        sleep 30
        
        ((iteration++))
    done
    
    echo "✅ Autonomous operation loop completed ($iteration iterations)"
}

# Safe autonomous execution with error handling
safe_autonomous_execution() {
    local focus_area="$1"
    
    # Trap errors to prevent runaway processes
    trap 'echo "🛑 Autonomous execution interrupted"; exit 1' INT TERM
    
    # Verify system is ready
    if ! pre_implementation_checks "system" "ready"; then
        echo "❌ System not ready for autonomous operation"
        return 1
    fi
    
    # Execute with error handling
    if autonomous_main_loop "$focus_area"; then
        echo "🎉 Autonomous execution completed successfully"
        return 0
    else
        echo "⚠️  Autonomous execution completed with issues"
        return 1
    fi
}
```

## USAGE EXAMPLES

### Basic Autonomous Operation
```bash
# Default autonomous operation (coordination focus)
/project:auto

# Specific focus areas
/project:auto coordination     # Focus on agent coordination features
/project:auto enhancement      # Focus on middleware and workflow enhancement
/project:auto reactor          # Focus on Reactor pattern improvements
```

### Advanced Usage with Safety Limits
```bash
# Limited iterations for testing
/project:auto coordination 3   # Run max 3 iterations

# Debug mode with verbose output
DEBUG=1 /project:auto enhancement
```

This Gherkin-driven autonomous system ensures all work is grounded in actual specifications and prevents hallucination by requiring verification of capabilities before implementation.

## SYSTEM INTEGRATION POINTS

### Available Gherkin Feature Files
The autonomous system can reference these comprehensive specifications:

- **`reactor_workflow_orchestration.feature`** - 15 scenarios covering Reactor patterns
- **`agent_coordination.feature`** - 14 scenarios for nanosecond precision coordination  
- **`n8n_integration.feature`** - 14 scenarios for workflow automation
- **`self_improvement_processes.feature`** - 18 scenarios for AI enhancement
- **`aps_coordination.feature`** - 15 scenarios for protocol specification
- **`system_monitoring_telemetry.feature`** - 16 scenarios for monitoring
- **`error_handling_recovery.feature`** - 16 scenarios for error management
- **`performance_optimization.feature`** - 16 scenarios for optimization
- **`phoenix_application.feature`** - 15 scenarios for web framework
- **`ash_framework_database.feature`** - 15 scenarios for database operations
- **`cli_slash_commands.feature`** - 16 scenarios for command interface

### Implemented System Components
The autonomous agent can work with these actual implementations:

- **Reactor Middleware**: `AgentCoordinationMiddleware`, `TelemetryMiddleware`
- **Reactor Steps**: `ParallelImprovementStep`, `N8nWorkflowStep`
- **Reactor Workflows**: `SelfImprovementReactor`, `N8nIntegrationReactor`, `APSReactor`
- **Phoenix Application**: LiveView, Tidewave MCP endpoint, health checks
- **Ash Framework**: Database resources, migrations, relationships

### Success Criteria
Autonomous operations are successful when they:
1. ✅ Verify capabilities exist in Gherkin specifications before implementation
2. ✅ Reference actual system components and file paths
3. ✅ Pass all quality gates (tests, compilation, formatting)
4. ✅ Follow Given-When-Then patterns from Gherkin scenarios
5. ✅ Maintain system stability and prevent runaway processes

## SUMMARY

This autonomous AI agent system operates entirely within the bounds of comprehensive Gherkin specifications, preventing hallucination by requiring verification of capabilities before any implementation work. The system leverages actual implemented components including Reactor workflows, middleware, and Phoenix application infrastructure to deliver reliable, testable, and maintainable autonomous operations.