#!/bin/bash

# Autonomous Decision Engine - System Analysis and Rule-Based Decisions
# Implements rule-based system analysis and automated improvement recommendations

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COORDINATION_ROOT="$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
}

decision() {
    echo -e "${PURPLE}🧠 DECISION: $1${NC}"
}

# Generate unique decision trace ID
generate_decision_trace() {
    echo "decision_$(date +%s%N)"
}

# Analyze current system state for autonomous decisions
analyze_system_state() {
    local decision_trace="$1"
    
    log "Analyzing system state for autonomous decisions..."
    
    # Read current coordination state
    local work_claims_file="$COORDINATION_ROOT/work_claims.json"
    local agent_status_file="$COORDINATION_ROOT/agent_status.json"
    
    if [[ ! -f "$work_claims_file" ]] || [[ ! -f "$agent_status_file" ]]; then
        error "Coordination files not found"
        return 1
    fi
    
    # Calculate key metrics
    local total_work=$(jq 'length' "$work_claims_file")
    local completed_work=$(jq '[.[] | select(.status == "completed")] | length' "$work_claims_file")
    local active_work=$(jq '[.[] | select(.status == "active")] | length' "$work_claims_file")
    local total_agents=$(jq 'length' "$agent_status_file")
    local completion_rate=$(echo "scale=2; $completed_work * 100 / $total_work" | bc -l)
    
    # Calculate team distribution
    local team_count=$(jq '[.[].team] | unique | length' "$agent_status_file")
    local avg_agents_per_team=$(echo "scale=2; $total_agents / $team_count" | bc -l)
    
    # Calculate telemetry volume
    local telemetry_spans=0
    if [[ -f "$COORDINATION_ROOT/telemetry_spans.jsonl" ]]; then
        telemetry_spans=$(wc -l < "$COORDINATION_ROOT/telemetry_spans.jsonl")
    fi
    
    # System health scoring
    local health_score=100
    if [[ $(echo "$completion_rate < 50" | bc -l) == 1 ]]; then
        health_score=75
    fi
    if [[ $(echo "$active_work > 10" | bc -l) == 1 ]]; then
        health_score=$((health_score - 10))
    fi
    
    # Generate system state analysis
    cat > "$COORDINATION_ROOT/system_state_analysis_$decision_trace.json" << EOF
{
  "decision_trace_id": "$decision_trace",
  "timestamp": "$(date -Iseconds)",
  "system_metrics": {
    "total_work_items": $total_work,
    "completed_work": $completed_work,
    "active_work": $active_work,
    "completion_rate": $completion_rate,
    "total_agents": $total_agents,
    "team_count": $team_count,
    "avg_agents_per_team": $avg_agents_per_team,
    "telemetry_spans": $telemetry_spans,
    "health_score": $health_score
  },
  "quality_indicators": {
    "coordination_efficiency": $(echo "scale=2; $completed_work / ($completed_work + $active_work)" | bc -l),
    "agent_utilization": $(echo "scale=2; $active_work / $total_agents" | bc -l),
    "telemetry_density": $(echo "scale=2; $telemetry_spans / $total_work" | bc -l)
  }
}
EOF
    
    log "System analysis completed:"
    log "  Total Work: $total_work"
    log "  Completion Rate: ${completion_rate}%"
    log "  Active Agents: $total_agents"
    log "  Health Score: $health_score"
    log "  Telemetry Spans: $telemetry_spans"
    
    echo "$decision_trace"
}

# Make autonomous decisions based on system state
make_autonomous_decisions() {
    local decision_trace="$1"
    local analysis_file="$COORDINATION_ROOT/system_state_analysis_$decision_trace.json"
    
    if [[ ! -f "$analysis_file" ]]; then
        error "System analysis file not found"
        return 1
    fi
    
    log "Making autonomous decisions..."
    
    # Extract metrics for decision making
    local completion_rate=$(jq -r '.system_metrics.completion_rate' "$analysis_file")
    local health_score=$(jq -r '.system_metrics.health_score' "$analysis_file")
    local active_work=$(jq -r '.system_metrics.active_work' "$analysis_file")
    local total_agents=$(jq -r '.system_metrics.total_agents' "$analysis_file")
    local telemetry_spans=$(jq -r '.system_metrics.telemetry_spans' "$analysis_file")
    
    # Decision logic based on rule-based analysis
    local decisions=()
    local priority_decisions=()
    
    # High-priority decisions (critical issues)
    if (( $(echo "$completion_rate < 60" | bc -l) )); then
        priority_decisions+=("coordination_optimization")
        decision "Completion rate ${completion_rate}% < 60% - prioritize coordination optimization"
    fi
    
    if (( $(echo "$health_score < 85" | bc -l) )); then
        priority_decisions+=("system_health_enhancement")
        decision "Health score ${health_score} < 85 - prioritize system health enhancement"
    fi
    
    if (( $(echo "$active_work > 15" | bc -l) )); then
        priority_decisions+=("workload_optimization")
        decision "Active work ${active_work} > 15 - prioritize workload optimization"
    fi
    
    # Improvement opportunities (secondary priorities)
    if (( telemetry_spans > 5000 )); then
        decisions+=("telemetry_analysis_automation")
        decision "Telemetry volume ${telemetry_spans} > 5000 - enable analysis automation"
    fi
    
    if (( total_agents > 10 )); then
        decisions+=("agent_specialization_optimization")
        decision "Agent count ${total_agents} > 10 - optimize specialization"
    fi
    
    # Always include continuous improvement
    decisions+=("continuous_improvement")
    
    # Generate decision manifest
    local all_decisions=(${priority_decisions[@]} ${decisions[@]})
    local decisions_json=$(printf '%s\n' "${all_decisions[@]}" | jq -R . | jq -s .)
    
    cat > "$COORDINATION_ROOT/autonomous_decisions_$decision_trace.json" << EOF
{
  "decision_trace_id": "$decision_trace",
  "timestamp": "$(date -Iseconds)",
  "system_state_summary": {
    "completion_rate": $completion_rate,
    "health_score": $health_score,
    "active_work": $active_work,
    "total_agents": $total_agents
  },
  "priority_decisions": $(printf '%s\n' "${priority_decisions[@]}" | jq -R . | jq -s .),
  "improvement_decisions": $(printf '%s\n' "${decisions[@]}" | jq -R . | jq -s .),
  "decision_confidence": 85,
  "expected_impact": "System improvements through targeted optimization"
}
EOF
    
    success "Autonomous decisions generated: ${#all_decisions[@]} items"
    echo "$decision_trace"
}

# Execute autonomous improvements based on decisions
execute_autonomous_improvements() {
    local decision_trace="$1"
    local decisions_file="$COORDINATION_ROOT/autonomous_decisions_$decision_trace.json"
    
    if [[ ! -f "$decisions_file" ]]; then
        error "Decisions file not found"
        return 1
    fi
    
    log "Executing autonomous improvements..."
    
    # Get priority decisions
    local priority_decisions=$(jq -r '.priority_decisions[]' "$decisions_file" 2>/dev/null || echo "")
    local improvement_decisions=$(jq -r '.improvement_decisions[]' "$decisions_file" 2>/dev/null || echo "")
    
    # Execute priority decisions first (critical 20%)
    local executed_count=0
    
    for decision in $priority_decisions; do
        case "$decision" in
            "coordination_optimization")
                log "Executing: Coordination optimization"
                "$COORDINATION_ROOT/coordination_helper.sh" claim "coordination_optimization" "System coordination optimization based on decision engine analysis" "high" "coordination_team" > /dev/null
                ((executed_count++))
                ;;
            "system_health_enhancement")
                log "Executing: System health enhancement"
                "$COORDINATION_ROOT/coordination_helper.sh" claim "system_health_enhancement" "System health enhancement based on decision engine analysis" "high" "health_team" > /dev/null
                ((executed_count++))
                ;;
            "workload_optimization")
                log "Executing: Workload optimization"
                "$COORDINATION_ROOT/coordination_helper.sh" claim "workload_optimization" "System workload optimization based on decision engine analysis" "medium" "optimization_team" > /dev/null
                ((executed_count++))
                ;;
        esac
    done
    
    # Execute improvement decisions (secondary priorities)
    for decision in $improvement_decisions; do
        if [[ "$decision" == "continuous_improvement" ]]; then
            log "Executing: Continuous improvement cycle"
            "$COORDINATION_ROOT/coordination_helper.sh" claim "continuous_improvement" "System continuous improvement cycle" "medium" "improvement_team" > /dev/null
            ((executed_count++))
            break  # Only execute one improvement per cycle
        fi
    done
    
    success "Executed $executed_count autonomous improvements"
    echo "$executed_count"
}

# Trigger self-improvement loop
trigger_self_improvement_loop() {
    local decision_trace="$1"
    
    log "Triggering self-improvement loop..."
    
    # Create self-improvement work item
    "$COORDINATION_ROOT/coordination_helper.sh" claim "self_improvement_loop" "System self-improvement loop triggered by decision engine" "medium" "improvement_team" > /dev/null
    
    # Record loop initiation
    cat > "$COORDINATION_ROOT/self_improvement_loop_$decision_trace.json" << EOF
{
  "loop_trace_id": "$decision_trace",
  "timestamp": "$(date -Iseconds)",
  "trigger_reason": "autonomous_decision_engine",
  "loop_type": "continuous_improvement",
  "expected_cycle_duration": "30m",
  "success_criteria": [
    "System health score improvement",
    "Completion rate optimization", 
    "New capability identification",
    "Next improvement opportunity discovery"
  ]
}
EOF
    
    success "Self-improvement loop triggered"
}

# Main autonomous decision engine execution
main() {
    local command="${1:-analyze}"
    
    case "$command" in
        "analyze")
            echo -e "${PURPLE}🧠 AUTONOMOUS DECISION ENGINE${NC}"
            echo -e "${PURPLE}================================${NC}"
            
            local decision_trace=$(generate_decision_trace)
            
            # Step 1: Analyze system state
            decision_trace=$(analyze_system_state "$decision_trace")
            
            # Step 2: Make autonomous decisions
            decision_trace=$(make_autonomous_decisions "$decision_trace")
            
            # Step 3: Execute improvements
            local executed_count=$(execute_autonomous_improvements "$decision_trace")
            
            # Step 4: Trigger self-improvement loop
            trigger_self_improvement_loop "$decision_trace"
            
            success "Autonomous decision cycle completed"
            log "Decision trace: $decision_trace"
            log "Improvements executed: $executed_count"
            ;;
        "status")
            if ls "$COORDINATION_ROOT"/autonomous_decisions_*.json 1> /dev/null 2>&1; then
                local latest_decision=$(ls -t "$COORDINATION_ROOT"/autonomous_decisions_*.json | head -1)
                log "Latest autonomous decision: $(basename "$latest_decision")"
                jq -r '.system_state_summary' "$latest_decision"
            else
                warning "No autonomous decisions found"
            fi
            ;;
        "loop")
            trigger_self_improvement_loop "$(generate_decision_trace)"
            ;;
        "help")
            echo "Autonomous Decision Engine - System Analysis and Rule-Based Decisions"
            echo
            echo "Usage: $0 <command>"
            echo
            echo "Commands:"
            echo "  analyze  - Run full autonomous decision cycle"
            echo "  status   - Show latest decision status"
            echo "  loop     - Trigger self-improvement loop"
            echo "  help     - Show this help"
            ;;
        *)
            error "Unknown command: $command"
            $0 help
            exit 1
            ;;
    esac
}

# Check dependencies
if ! command -v jq &> /dev/null; then
    error "jq is required but not installed"
    exit 1
fi

if ! command -v bc &> /dev/null; then
    error "bc is required but not installed"
    exit 1
fi

main "$@"