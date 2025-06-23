#!/bin/bash

# 80/20 Orchestrator - Focus on 80% value with 20% effort
# Rapid iteration loop for autonomous coordination improvements

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
COORDINATION_ROOT="$ROOT_DIR/agent_coordination"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
NC='\033[0m'

# 80/20 Session tracking
ITERATION=0
SESSION_ID="8020_$(date +%s)"
MASTER_TRACE_ID=$(openssl rand -hex 16)

log() {
    echo -e "${BLUE}[80/20-${ITERATION}]${NC} $1"
}

success() {
    echo -e "${GREEN}✅ [80/20]${NC} $1"
}

# 80/20 Definition of Done Validator
validate_8020_done() {
    local validation_score=0
    local max_score=4
    
    log "Validating 80/20 Definition of Done..."
    
    # 1. Trace Propagation Check (25% of score)
    if grep -q "$MASTER_TRACE_ID" "$COORDINATION_ROOT/work_claims.json" 2>/dev/null; then
        success "Trace propagation: WORKING"
        ((validation_score++))
    else
        echo "❌ Trace propagation: NEEDS WORK"
    fi
    
    # 2. Work Coordination Check (25% of score)
    if [[ -x "$COORDINATION_ROOT/coordination_helper.sh" ]]; then
        if "$COORDINATION_ROOT/coordination_helper.sh" system-status >/dev/null 2>&1; then
            success "Work coordination: WORKING"
            ((validation_score++))
        fi
    fi
    
    # 3. Health Monitoring Check (25% of score)
    if "$ROOT_DIR/beamops/v3/scripts/autonomous_grafana_integration.sh" metrics >/dev/null 2>&1; then
        success "Health monitoring: WORKING"
        ((validation_score++))
    fi
    
    # 4. Performance Metrics Check (25% of score)
    if [[ -f "$COORDINATION_ROOT/telemetry_spans.jsonl" ]] && [[ $(wc -l < "$COORDINATION_ROOT/telemetry_spans.jsonl") -gt 100 ]]; then
        success "Performance metrics: WORKING"
        ((validation_score++))
    fi
    
    local percentage=$((validation_score * 100 / max_score))
    log "80/20 Score: $validation_score/$max_score ($percentage%)"
    
    return $((percentage >= 80 ? 0 : 1))
}

# 80/20 Quick Implementation - Focus on biggest gaps
implement_8020_improvements() {
    log "Implementing 80/20 improvements for iteration $ITERATION..."
    
    # Quick Win 1: Ensure trace evidence persistence (20% effort, 80% visibility value)
    local evidence_file="$COORDINATION_ROOT/8020_trace_evidence.jsonl"
    echo "{\"iteration\": $ITERATION, \"trace_id\": \"$MASTER_TRACE_ID\", \"timestamp\": \"$(date -Iseconds)\", \"session\": \"$SESSION_ID\"}" >> "$evidence_file"
    
    # Quick Win 2: Claim work with our trace ID (minimal effort, maximum traceability)
    export OTEL_TRACE_ID="$MASTER_TRACE_ID"
    if "$COORDINATION_ROOT/coordination_helper.sh" claim "8020_iteration_${ITERATION}" "80/20 improvement cycle iteration $ITERATION" "medium" "8020_team" >/dev/null 2>&1; then
        success "Work claimed with 80/20 trace: $MASTER_TRACE_ID"
    fi
    unset OTEL_TRACE_ID
    
    # Quick Win 3: Record iteration metrics (low effort, high insight value)
    local metrics_entry=$(cat <<EOF
{
  "iteration": $ITERATION,
  "session_id": "$SESSION_ID", 
  "master_trace_id": "$MASTER_TRACE_ID",
  "timestamp": "$(date -Iseconds)",
  "operation": "8020_iteration",
  "telemetry_spans_count": $(wc -l < "$COORDINATION_ROOT/telemetry_spans.jsonl" 2>/dev/null || echo "0"),
  "work_items_count": $(jq length "$COORDINATION_ROOT/work_claims.json" 2>/dev/null || echo "0")
}
EOF
    )
    echo "$metrics_entry" >> "$COORDINATION_ROOT/8020_metrics.jsonl"
    
    # Quick Win 4: Simple script discovery improvement (focus on .sh files only)
    local actual_scripts=$(find "$ROOT_DIR" -name "*.sh" -type f | wc -l)
    log "Accurate script count: $actual_scripts (focused on .sh files)"
    
    success "80/20 improvements implemented for iteration $ITERATION"
}

# 80/20 Loop - Rapid iteration cycle
run_8020_loop() {
    local max_iterations=5
    
    log "Starting 80/20 continuous improvement loop..."
    log "Session: $SESSION_ID, Master Trace: $MASTER_TRACE_ID"
    
    while [[ $ITERATION -lt $max_iterations ]]; do
        ((ITERATION++))
        
        log "=== 80/20 ITERATION $ITERATION ==="
        
        # Implement 80/20 improvements quickly
        implement_8020_improvements
        
        # Validate definition of done
        if validate_8020_done; then
            success "80/20 Definition of Done ACHIEVED for iteration $ITERATION"
        else
            log "80/20 Definition of Done not yet met, continuing..."
        fi
        
        # Brief pause for system to settle
        sleep 2
        
        # Show progress
        log "Iteration $ITERATION complete. Evidence file size: $(wc -l < "$COORDINATION_ROOT/8020_trace_evidence.jsonl" 2>/dev/null || echo "0") entries"
    done
    
    log "80/20 loop completed after $max_iterations iterations"
}

# Quick status display
show_8020_status() {
    echo
    echo "=================================================================="
    echo -e "${PURPLE}📊 80/20 AUTONOMOUS COORDINATION STATUS${NC}"
    echo "=================================================================="
    echo -e "${BLUE}Session ID:${NC} $SESSION_ID"
    echo -e "${BLUE}Master Trace ID:${NC} $MASTER_TRACE_ID"
    echo -e "${BLUE}Current Iteration:${NC} $ITERATION"
    echo
    
    # Quick metrics
    local telemetry_count=$(wc -l < "$COORDINATION_ROOT/telemetry_spans.jsonl" 2>/dev/null || echo "0")
    local work_count=$(jq length "$COORDINATION_ROOT/work_claims.json" 2>/dev/null || echo "0")
    local evidence_count=$(wc -l < "$COORDINATION_ROOT/8020_trace_evidence.jsonl" 2>/dev/null || echo "0")
    
    echo -e "${BLUE}📊 Quick Metrics:${NC}"
    echo "  Telemetry Spans: $telemetry_count"
    echo "  Work Items: $work_count" 
    echo "  80/20 Evidence Entries: $evidence_count"
    echo
    
    # Validate current state
    validate_8020_done
    echo "=================================================================="
}

# Main execution
main() {
    echo
    echo "=================================================================="
    echo -e "${PURPLE}🎯 80/20 AUTONOMOUS COORDINATION ORCHESTRATOR${NC}"
    echo -e "${PURPLE}   Focus on 80% Value with 20% Effort${NC}"
    echo "=================================================================="
    echo
    
    # Run the 80/20 loop
    run_8020_loop
    
    # Show final status
    show_8020_status
    
    success "80/20 orchestration complete!"
}

# Execute main function
main "$@"