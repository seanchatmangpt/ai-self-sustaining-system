#!/bin/bash

# Continuous Real Validation Loop
# Implements 80/20 principle: 20% continuous monitoring ensures 80% system reliability
# Prevents synthetic drift by validating real functionality every 30 seconds

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="agent_coordination/real_validation_loop.log"
METRICS_DIR="agent_coordination/real_metrics"
ALERT_THRESHOLD=50  # Alert if reality score drops below 50%

mkdir -p "$METRICS_DIR"

log() {
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $1" | tee -a "$LOG_FILE"
}

log "🔄 STARTING CONTINUOUS REAL VALIDATION LOOP"
log "Alert threshold: ${ALERT_THRESHOLD}% reality score"

# Quick validation function (optimized for speed)
quick_reality_check() {
    local timestamp=$(date +%s)
    local reality_score=100
    local synthetic_flags=()
    
    # Quick Test 1: HTTP Health Check (5 seconds max)
    local health_working=false
    for port in 4000 4001 4002; do
        if timeout 2s curl -s http://localhost:$port/api/health > /dev/null 2>&1; then
            health_working=true
            break
        fi
    done
    
    if [[ "$health_working" == "false" ]]; then
        reality_score=$((reality_score - 30))
        synthetic_flags+=("health_endpoint_down")
    fi
    
    # Quick Test 2: Process Check
    local elixir_processes=$(ps aux | grep -E "beam\.smp" | grep -v grep | wc -l)
    if [[ $elixir_processes -eq 0 ]]; then
        reality_score=$((reality_score - 40))
        synthetic_flags+=("no_elixir_processes")
    fi
    
    # Quick Test 3: File Consistency Check
    if [[ ! -f "agent_coordination/agent_status.json" ]]; then
        reality_score=$((reality_score - 15))
        synthetic_flags+=("agent_file_missing")
    fi
    
    if [[ ! -f "agent_coordination/work_claims.json" ]]; then
        reality_score=$((reality_score - 15))
        synthetic_flags+=("work_file_missing")
    fi
    
    # Create quick metrics entry
    local metric_entry="{
        \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
        \"epoch\": $timestamp,
        \"reality_score\": $reality_score,
        \"health_working\": $health_working,
        \"elixir_processes\": $elixir_processes,
        \"synthetic_flags\": $(printf '%s\n' "${synthetic_flags[@]}" | jq -R . | jq -s .),
        \"alert_triggered\": $([ $reality_score -lt $ALERT_THRESHOLD ] && echo "true" || echo "false")
    }"
    
    echo "$metric_entry" >> "$METRICS_DIR/quick_metrics_$(date +%Y%m%d).jsonl"
    echo "$reality_score:$health_working:$elixir_processes"
}

# Alert function
trigger_alert() {
    local reality_score="$1"
    local synthetic_flags="$2"
    
    log "🚨 REALITY ALERT: System reality score dropped to ${reality_score}%"
    log "Synthetic flags detected: $synthetic_flags"
    
    # Create alert work item for the system to fix itself
    local alert_work_item="{
        \"work_item_id\": \"work_reality_alert_$(date +%s%N)\",
        \"agent_id\": null,
        \"reactor_id\": \"reality_monitor\",
        \"claimed_at\": null,
        \"estimated_duration\": \"10m\",
        \"work_type\": \"reality_recovery\",
        \"priority\": \"high\",
        \"description\": \"REALITY ALERT: System reality score ${reality_score}%. Flags: $synthetic_flags. Immediate investigation and recovery required.\",
        \"status\": \"pending\",
        \"team\": \"emergency_recovery_team\",
        \"created_by\": \"continuous_real_validation_loop\",
        \"created_at\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"
    }"
    
    # Add alert to work claims if file exists
    if [[ -f "agent_coordination/work_claims.json" ]]; then
        local temp_file=$(mktemp)
        jq ". += [$alert_work_item]" agent_coordination/work_claims.json > "$temp_file"
        mv "$temp_file" agent_coordination/work_claims.json
        log "📋 Created reality recovery work item"
    fi
}

# Trend analysis
analyze_trends() {
    local today=$(date +%Y%m%d)
    local metrics_file="$METRICS_DIR/quick_metrics_${today}.jsonl"
    
    if [[ -f "$metrics_file" ]] && [[ $(wc -l < "$metrics_file") -ge 5 ]]; then
        local current_score=$(tail -1 "$metrics_file" | jq -r '.reality_score')
        local prev_score=$(tail -2 "$metrics_file" | head -1 | jq -r '.reality_score')
        local trend_direction=""
        
        if [[ $current_score -gt $prev_score ]]; then
            trend_direction="IMPROVING"
        elif [[ $current_score -lt $prev_score ]]; then
            trend_direction="DEGRADING"
        else
            trend_direction="STABLE"
        fi
        
        log "📈 Reality trend: $trend_direction (${prev_score}% → ${current_score}%)"
        
        # Check for rapid degradation
        if [[ $current_score -lt $((prev_score - 20)) ]]; then
            log "⚠️  RAPID DEGRADATION DETECTED: ${prev_score}% → ${current_score}%"
            trigger_alert "$current_score" "rapid_degradation"
        fi
    fi
}

# Recovery suggestions
suggest_recovery() {
    local reality_score="$1"
    
    if [[ $reality_score -lt 30 ]]; then
        log "🔧 CRITICAL RECOVERY NEEDED:"
        log "   1. Restart Phoenix server (mix phx.server)"
        log "   2. Verify JSON files are not corrupted"
        log "   3. Check system resources and dependencies"
    elif [[ $reality_score -lt 60 ]]; then
        log "🔧 MODERATE RECOVERY NEEDED:"
        log "   1. Check HTTP endpoint health"
        log "   2. Verify process stability"
        log "   3. Review recent changes"
    elif [[ $reality_score -lt 80 ]]; then
        log "🔧 MINOR ADJUSTMENTS NEEDED:"
        log "   1. Monitor HTTP response times"
        log "   2. Check for resource constraints"
    fi
}

# Cleanup old metrics
cleanup_old_metrics() {
    # Keep only last 7 days of metrics
    find "$METRICS_DIR" -name "quick_metrics_*.jsonl" -mtime +7 -delete 2>/dev/null || true
    
    # Keep only last 1000 lines in log file
    if [[ -f "$LOG_FILE" ]] && [[ $(wc -l < "$LOG_FILE") -gt 1000 ]]; then
        tail -1000 "$LOG_FILE" > "${LOG_FILE}.tmp"
        mv "${LOG_FILE}.tmp" "$LOG_FILE"
    fi
}

# Main monitoring loop
main_loop() {
    local iteration=0
    local last_alert_time=0
    local alert_cooldown=300  # 5 minutes between alerts
    
    while true; do
        iteration=$((iteration + 1))
        local current_time=$(date +%s)
        
        # Run quick reality check
        local check_result=$(quick_reality_check)
        local reality_score=$(echo "$check_result" | cut -d: -f1)
        local health_working=$(echo "$check_result" | cut -d: -f2)
        local elixir_processes=$(echo "$check_result" | cut -d: -f3)
        
        log "🔍 Reality Check #${iteration}: ${reality_score}% (Health: $health_working, Processes: $elixir_processes)"
        
        # Trigger alert if reality score too low and cooldown expired
        if [[ $reality_score -lt $ALERT_THRESHOLD ]] && [[ $((current_time - last_alert_time)) -gt $alert_cooldown ]]; then
            trigger_alert "$reality_score" "reality_score_below_threshold"
            suggest_recovery "$reality_score"
            last_alert_time=$current_time
        fi
        
        # Analyze trends every 10 iterations
        if [[ $((iteration % 10)) -eq 0 ]]; then
            analyze_trends
        fi
        
        # Cleanup every 100 iterations
        if [[ $((iteration % 100)) -eq 0 ]]; then
            cleanup_old_metrics
            log "🧹 Cleaned up old metrics (iteration $iteration)"
        fi
        
        # Log summary every 50 iterations
        if [[ $((iteration % 50)) -eq 0 ]]; then
            log "📊 Summary after $iteration checks: Reality monitoring active"
        fi
        
        # Wait 30 seconds before next check
        sleep 30
    done
}

# Signal handlers for graceful shutdown
cleanup_and_exit() {
    log "🛑 Received shutdown signal, stopping validation loop"
    log "📊 Final iteration count: $iteration"
    exit 0
}

trap cleanup_and_exit SIGTERM SIGINT

# Command line options
case "${1:-continuous}" in
    "continuous")
        log "🔄 Starting CONTINUOUS reality validation (30s intervals)"
        main_loop
        ;;
    "single")
        log "⚡ Running SINGLE reality check"
        result=$(quick_reality_check)
        reality_score=$(echo "$result" | cut -d: -f1)
        health_working=$(echo "$result" | cut -d: -f2)
        elixir_processes=$(echo "$result" | cut -d: -f3)
        
        echo "Reality Score: ${reality_score}%"
        echo "Health Working: $health_working"
        echo "Elixir Processes: $elixir_processes"
        
        if [[ $reality_score -lt $ALERT_THRESHOLD ]]; then
            echo "⚠️  ALERT: Reality score below threshold!"
            suggest_recovery "$reality_score"
        else
            echo "✅ System reality score acceptable"
        fi
        ;;
    "trends")
        log "📈 Analyzing reality trends"
        analyze_trends
        ;;
    "cleanup")
        log "🧹 Cleaning up old metrics"
        cleanup_old_metrics
        ;;
    *)
        echo "Usage: $0 [continuous|single|trends|cleanup]"
        echo "  continuous - Run continuous monitoring (default)"
        echo "  single     - Run one reality check"
        echo "  trends     - Analyze current trends"
        echo "  cleanup    - Clean up old metrics"
        exit 1
        ;;
esac