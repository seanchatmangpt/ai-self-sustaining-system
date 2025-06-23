#!/bin/bash

# Continuous Optimization Loop for Autonomous Agent System
# Implements 80/20 principle: 20% monitoring effort achieves 80% system reliability
# Runs verification, analyzes trends, and triggers optimizations automatically

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="agent_coordination/optimization_loop.log"
METRICS_DIR="agent_coordination/metrics"
OPTIMIZATION_HISTORY="agent_coordination/optimization_history.jsonl"

# Create metrics directory
mkdir -p "$METRICS_DIR"

# Logging function
log() {
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $1" | tee -a "$LOG_FILE"
}

log "🔄 STARTING CONTINUOUS OPTIMIZATION LOOP"

# Configuration
EFFICIENCY_THRESHOLD=70.0
COMPLETION_RATE_THRESHOLD=50.0
ERROR_RATE_THRESHOLD=10.0
AGENT_UTILIZATION_THRESHOLD=80.0

# Main optimization loop
optimization_cycle() {
    local cycle_id="optimization_cycle_$(date +%s)"
    log "📊 Starting $cycle_id"
    
    # Run system verification
    if [[ -f "./autonomous_system_verification.sh" ]]; then
        log "🔍 Running system verification..."
        ./autonomous_system_verification.sh > /dev/null 2>&1 || true
        
        # Get latest verification report
        local latest_report=$(ls -t autonomous_verification_*.json 2>/dev/null | head -1)
        
        if [[ -n "$latest_report" && -f "$latest_report" ]]; then
            log "📈 Analyzing verification results from $latest_report"
            
            # Extract key metrics
            local efficiency=$(jq -r '.critical_metrics.system_efficiency_score // 0' "$latest_report")
            local agent_efficiency=$(jq -r '.agent_coordination.efficiency_percentage // 0' "$latest_report")
            local completion_rate=$(jq -r '.work_completion.completion_rate // 0' "$latest_report")
            local success_rate=$(jq -r '.telemetry_health.success_rate // 0' "$latest_report")
            local total_agents=$(jq -r '.agent_coordination.total_agents // 0' "$latest_report")
            local active_agents=$(jq -r '.agent_coordination.active_agents // 0' "$latest_report")
            local total_work=$(jq -r '.work_completion.total_work_items // 0' "$latest_report")
            local completed_work=$(jq -r '.work_completion.completed_items // 0' "$latest_report")
            
            log "📊 Current Metrics:"
            log "   System Efficiency: ${efficiency}%"
            log "   Agent Efficiency: ${agent_efficiency}%"
            log "   Completion Rate: ${completion_rate}%"
            log "   Telemetry Success: ${success_rate}%"
            log "   Active Agents: ${active_agents}/${total_agents}"
            
            # Store metrics for trend analysis
            local metrics_entry="{
                \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
                \"cycle_id\": \"$cycle_id\",
                \"system_efficiency\": $efficiency,
                \"agent_efficiency\": $agent_efficiency,
                \"completion_rate\": $completion_rate,
                \"telemetry_success_rate\": $success_rate,
                \"total_agents\": $total_agents,
                \"active_agents\": $active_agents,
                \"total_work_items\": $total_work,
                \"completed_work_items\": $completed_work
            }"
            
            echo "$metrics_entry" >> "$METRICS_DIR/metrics_$(date +%Y%m%d).jsonl"
            
            # Trigger optimizations based on thresholds
            local optimizations_triggered=0
            
            # Check system efficiency
            if (( $(echo "$efficiency < $EFFICIENCY_THRESHOLD" | bc -l) )); then
                log "⚠️  System efficiency below threshold (${efficiency}% < ${EFFICIENCY_THRESHOLD}%)"
                trigger_system_optimization "$cycle_id" "low_efficiency" "$efficiency"
                optimizations_triggered=$((optimizations_triggered + 1))
            fi
            
            # Check completion rate
            if (( $(echo "$completion_rate < $COMPLETION_RATE_THRESHOLD" | bc -l) )); then
                log "⚠️  Work completion rate below threshold (${completion_rate}% < ${COMPLETION_RATE_THRESHOLD}%)"
                trigger_completion_optimization "$cycle_id" "low_completion_rate" "$completion_rate"
                optimizations_triggered=$((optimizations_triggered + 1))
            fi
            
            # Check telemetry error rate
            local error_rate=$(echo "100 - $success_rate" | bc -l)
            if (( $(echo "$error_rate > $ERROR_RATE_THRESHOLD" | bc -l) )); then
                log "⚠️  Error rate above threshold (${error_rate}% > ${ERROR_RATE_THRESHOLD}%)"
                trigger_error_reduction "$cycle_id" "high_error_rate" "$error_rate"
                optimizations_triggered=$((optimizations_triggered + 1))
            fi
            
            # Check agent utilization
            if (( $(echo "$agent_efficiency < $AGENT_UTILIZATION_THRESHOLD" | bc -l) )); then
                log "⚠️  Agent utilization below threshold (${agent_efficiency}% < ${AGENT_UTILIZATION_THRESHOLD}%)"
                trigger_agent_optimization "$cycle_id" "low_agent_utilization" "$agent_efficiency"
                optimizations_triggered=$((optimizations_triggered + 1))
            fi
            
            # Log optimization summary
            if [[ $optimizations_triggered -eq 0 ]]; then
                log "✅ System performing within acceptable parameters - no optimizations triggered"
            else
                log "🚀 Triggered $optimizations_triggered optimization(s) for performance improvement"
            fi
            
            # Record optimization cycle
            local optimization_record="{
                \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
                \"cycle_id\": \"$cycle_id\",
                \"metrics\": $metrics_entry,
                \"optimizations_triggered\": $optimizations_triggered,
                \"status\": \"completed\"
            }"
            
            echo "$optimization_record" >> "$OPTIMIZATION_HISTORY"
            
        else
            log "❌ No verification report found - skipping optimization analysis"
        fi
    else
        log "❌ Verification script not found - skipping system analysis"
    fi
    
    log "✅ Completed $cycle_id"
}

# Optimization trigger functions
trigger_system_optimization() {
    local cycle_id="$1"
    local reason="$2"
    local metric_value="$3"
    
    log "🔧 TRIGGERING: System efficiency optimization (${reason}: ${metric_value}%)"
    
    # Create optimization work item
    create_optimization_work_item \
        "system_efficiency_optimization" \
        "critical" \
        "System efficiency optimization: ${reason} detected with ${metric_value}% efficiency. Implement 80/20 optimization to improve system performance." \
        "meta_8020_team"
}

trigger_completion_optimization() {
    local cycle_id="$1"
    local reason="$2"
    local metric_value="$3"
    
    log "🔧 TRIGGERING: Work completion rate optimization (${reason}: ${metric_value}%)"
    
    create_optimization_work_item \
        "completion_rate_optimization" \
        "high" \
        "Work completion optimization: ${reason} detected with ${metric_value}% completion rate. Implement intelligent work finishing and priority management." \
        "meta_8020_team"
}

trigger_error_reduction() {
    local cycle_id="$1"
    local reason="$2"
    local metric_value="$3"
    
    log "🔧 TRIGGERING: Error rate reduction (${reason}: ${metric_value}%)"
    
    create_optimization_work_item \
        "error_rate_reduction" \
        "high" \
        "Error reduction optimization: ${reason} detected with ${metric_value}% error rate. Implement enhanced error recovery and prevention mechanisms." \
        "observability_team"
}

trigger_agent_optimization() {
    local cycle_id="$1"
    local reason="$2"
    local metric_value="$3"
    
    log "🔧 TRIGGERING: Agent utilization optimization (${reason}: ${metric_value}%)"
    
    create_optimization_work_item \
        "agent_utilization_optimization" \
        "medium" \
        "Agent optimization: ${reason} detected with ${metric_value}% utilization. Implement intelligent work distribution and capacity management." \
        "autonomous_team"
}

create_optimization_work_item() {
    local work_type="$1"
    local priority="$2"
    local description="$3"
    local team="$4"
    
    local work_id="work_optimization_$(date +%s%N)"
    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    
    # Create work item JSON
    local work_item="{
        \"work_item_id\": \"$work_id\",
        \"agent_id\": null,
        \"reactor_id\": \"optimization_loop\",
        \"claimed_at\": null,
        \"estimated_duration\": \"15m\",
        \"work_type\": \"$work_type\",
        \"priority\": \"$priority\",
        \"description\": \"$description\",
        \"status\": \"pending\",
        \"team\": \"$team\",
        \"created_by\": \"continuous_optimization_loop\",
        \"created_at\": \"$timestamp\"
    }"
    
    # Add to work claims (simplified - in real system would use proper coordination)
    if [[ -f "agent_coordination/work_claims.json" ]]; then
        # Read current work claims, add new item, write back
        local temp_file=$(mktemp)
        jq ". += [$work_item]" agent_coordination/work_claims.json > "$temp_file"
        mv "$temp_file" agent_coordination/work_claims.json
        log "📋 Created optimization work item: $work_id"
    else
        log "❌ Could not create work item - work_claims.json not found"
    fi
}

# Trend analysis function
analyze_trends() {
    log "📈 Analyzing performance trends..."
    
    local today=$(date +%Y%m%d)
    local metrics_file="$METRICS_DIR/metrics_${today}.jsonl"
    
    if [[ -f "$metrics_file" ]]; then
        local metric_count=$(wc -l < "$metrics_file")
        log "📊 Analyzing $metric_count metrics from today"
        
        if [[ $metric_count -ge 3 ]]; then
            # Calculate trends (simplified - could use more sophisticated analysis)
            local latest_efficiency=$(tail -1 "$metrics_file" | jq -r '.system_efficiency')
            local prev_efficiency=$(tail -2 "$metrics_file" | head -1 | jq -r '.system_efficiency')
            
            local efficiency_trend=$(echo "$latest_efficiency - $prev_efficiency" | bc -l)
            
            if (( $(echo "$efficiency_trend > 0" | bc -l) )); then
                log "📈 Efficiency trending UP: +${efficiency_trend}%"
            elif (( $(echo "$efficiency_trend < 0" | bc -l) )); then
                log "📉 Efficiency trending DOWN: ${efficiency_trend}%"
            else
                log "➡️  Efficiency stable"
            fi
        else
            log "ℹ️  Insufficient data for trend analysis (need 3+ metrics)"
        fi
    else
        log "ℹ️  No metrics file found for today"
    fi
}

# Cleanup old files
cleanup_old_files() {
    log "🧹 Cleaning up old verification reports and metrics..."
    
    # Keep only last 10 verification reports
    ls -t autonomous_verification_*.json 2>/dev/null | tail -n +11 | xargs rm -f 2>/dev/null || true
    
    # Keep only last 7 days of metrics
    find "$METRICS_DIR" -name "metrics_*.jsonl" -mtime +7 -delete 2>/dev/null || true
    
    log "✅ Cleanup completed"
}

# Health check function
health_check() {
    log "🏥 Running system health check..."
    
    local health_score=100
    local issues=()
    
    # Check if core files exist
    if [[ ! -f "agent_coordination/agent_status.json" ]]; then
        health_score=$((health_score - 25))
        issues+=("agent_status.json missing")
    fi
    
    if [[ ! -f "agent_coordination/work_claims.json" ]]; then
        health_score=$((health_score - 25))
        issues+=("work_claims.json missing")
    fi
    
    if [[ ! -f "agent_coordination/telemetry_spans.jsonl" ]]; then
        health_score=$((health_score - 20))
        issues+=("telemetry_spans.jsonl missing")
    fi
    
    # Check file sizes (should not be empty)
    if [[ -f "agent_coordination/agent_status.json" ]] && [[ ! -s "agent_coordination/agent_status.json" ]]; then
        health_score=$((health_score - 15))
        issues+=("agent_status.json is empty")
    fi
    
    if [[ -f "agent_coordination/work_claims.json" ]] && [[ ! -s "agent_coordination/work_claims.json" ]]; then
        health_score=$((health_score - 15))
        issues+=("work_claims.json is empty")
    fi
    
    # Report health status
    if [[ $health_score -ge 90 ]]; then
        log "✅ System health: EXCELLENT ($health_score%)"
    elif [[ $health_score -ge 70 ]]; then
        log "⚠️  System health: GOOD ($health_score%)"
    elif [[ $health_score -ge 50 ]]; then
        log "⚠️  System health: DEGRADED ($health_score%)"
    else
        log "🚨 System health: CRITICAL ($health_score%)"
    fi
    
    if [[ ${#issues[@]} -gt 0 ]]; then
        log "🔍 Health issues detected:"
        for issue in "${issues[@]}"; do
            log "   - $issue"
        done
    fi
}

# Main execution
main() {
    # Run health check first
    health_check
    
    # Run optimization cycle
    optimization_cycle
    
    # Analyze trends
    analyze_trends
    
    # Cleanup old files
    cleanup_old_files
    
    log "🏁 Optimization loop cycle completed successfully"
    
    # If running in continuous mode, schedule next run
    if [[ "${CONTINUOUS_MODE:-false}" == "true" ]]; then
        local next_run_delay=${OPTIMIZATION_INTERVAL:-300}  # 5 minutes default
        log "⏰ Scheduling next optimization cycle in ${next_run_delay} seconds"
        sleep "$next_run_delay"
        main  # Recursive call for continuous operation
    fi
}

# Command line options
case "${1:-single}" in
    "continuous")
        log "🔄 Starting CONTINUOUS optimization mode"
        CONTINUOUS_MODE=true
        main
        ;;
    "single")
        log "⚡ Running SINGLE optimization cycle"
        main
        ;;
    "health")
        log "🏥 Running health check only"
        health_check
        ;;
    "trends")
        log "📈 Running trend analysis only"
        analyze_trends
        ;;
    *)
        echo "Usage: $0 [single|continuous|health|trends]"
        echo "  single     - Run one optimization cycle (default)"
        echo "  continuous - Run continuously with periodic cycles"
        echo "  health     - Run health check only"
        echo "  trends     - Run trend analysis only"
        exit 1
        ;;
esac