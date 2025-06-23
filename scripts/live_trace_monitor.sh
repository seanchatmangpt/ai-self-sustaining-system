#!/bin/bash

# Live Trace Monitor - Real-time trace propagation monitoring
# Monitors the infinite trace orchestrator and validates trace continuity

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
COORDINATION_ROOT="$ROOT_DIR/agent_coordination"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

monitor_log() {
    echo -e "${CYAN}[$(date '+%H:%M:%S')] [MONITOR]${NC} $1"
}

# Function to monitor trace files
monitor_trace_files() {
    local session_pattern="$1"
    
    monitor_log "Monitoring trace files for session pattern: $session_pattern"
    
    # Monitor files that should contain traces
    local files_to_monitor=(
        "$COORDINATION_ROOT/work_claims.json"
        "$COORDINATION_ROOT/telemetry_spans.jsonl"
        "$COORDINATION_ROOT/trace_evidence_*.jsonl"
    )
    
    for file_pattern in "${files_to_monitor[@]}"; do
        if [[ "$file_pattern" == *"*"* ]]; then
            # Handle glob patterns
            local actual_files=($(ls $file_pattern 2>/dev/null))
            for actual_file in "${actual_files[@]}"; do
                if [[ -f "$actual_file" ]]; then
                    local trace_count=$(grep -c "trace_id" "$actual_file" 2>/dev/null || echo "0")
                    echo -e "  📊 $(basename "$actual_file"): $trace_count trace entries"
                fi
            done
        else
            # Handle direct file paths
            if [[ -f "$file_pattern" ]]; then
                local trace_count=$(grep -c "trace_id" "$file_pattern" 2>/dev/null || echo "0")
                echo -e "  📊 $(basename "$file_pattern"): $trace_count trace entries"
            fi
        fi
    done
}

# Function to show live trace activity
show_live_trace_activity() {
    local telemetry_file="$COORDINATION_ROOT/telemetry_spans.jsonl"
    
    if [[ -f "$telemetry_file" ]]; then
        monitor_log "Recent trace activity:"
        
        # Show last 5 trace entries
        local recent_traces=$(tail -5 "$telemetry_file" 2>/dev/null | grep "trace_id" | grep -o '"trace_id": "[^"]*"' | cut -d'"' -f4 | sort | uniq)
        
        if [[ -n "$recent_traces" ]]; then
            while IFS= read -r trace_id; do
                if [[ -n "$trace_id" ]]; then
                    echo -e "  🔍 Recent trace: $trace_id"
                fi
            done <<< "$recent_traces"
        else
            echo -e "  ⚠️  No recent trace activity detected"
        fi
    fi
}

# Function to validate orchestrator is running
check_orchestrator_status() {
    # Check if orchestrator process is running
    if pgrep -f "infinite_trace_orchestrator.sh" > /dev/null; then
        echo -e "  ${GREEN}✅ Infinite Trace Orchestrator is RUNNING${NC}"
        
        # Get process details
        local pid=$(pgrep -f "infinite_trace_orchestrator.sh")
        local runtime=$(ps -p "$pid" -o etime= 2>/dev/null | tr -d ' ')
        echo -e "  📊 PID: $pid, Runtime: $runtime"
        
        return 0
    else
        echo -e "  ${RED}❌ Infinite Trace Orchestrator is NOT RUNNING${NC}"
        return 1
    fi
}

# Function to display monitoring dashboard
display_monitoring_dashboard() {
    clear
    echo "=================================================================================="
    echo -e "${BOLD}${PURPLE}📡 LIVE TRACE MONITORING DASHBOARD${NC}"
    echo -e "${BOLD}${PURPLE}   Real-time Trace Propagation Validation${NC}"
    echo "=================================================================================="
    echo -e "${BLUE}Monitoring Time:${NC} $(date)"
    echo -e "${BLUE}Monitoring Session:${NC} live_monitor_$(date +%s)"
    echo
    
    # Check orchestrator status
    echo -e "${CYAN}🎭 ORCHESTRATOR STATUS:${NC}"
    check_orchestrator_status
    echo
    
    # Monitor trace files
    echo -e "${CYAN}📁 TRACE FILE MONITORING:${NC}"
    monitor_trace_files "comprehensive_e2e"
    echo
    
    # Show live trace activity
    echo -e "${CYAN}🔍 LIVE TRACE ACTIVITY:${NC}"
    show_live_trace_activity
    echo
    
    # Show coordination system status
    echo -e "${CYAN}🤖 COORDINATION SYSTEM STATUS:${NC}"
    if [[ -f "$COORDINATION_ROOT/work_claims.json" ]]; then
        local active_work=$(jq '[.[] | select(.status == "active")] | length' "$COORDINATION_ROOT/work_claims.json" 2>/dev/null || echo "0")
        local completed_work=$(jq '[.[] | select(.status == "completed")] | length' "$COORDINATION_ROOT/work_claims.json" 2>/dev/null || echo "0")
        echo -e "  📊 Active Work Items: $active_work"
        echo -e "  📊 Completed Work Items: $completed_work"
        
        # Show recent work with traces
        local recent_trace_work=$(jq -r '.[] | select(.telemetry.trace_id != "") | .telemetry.trace_id' "$COORDINATION_ROOT/work_claims.json" 2>/dev/null | tail -3)
        if [[ -n "$recent_trace_work" ]]; then
            echo -e "  🔗 Recent Work with Traces:"
            while IFS= read -r trace_id; do
                if [[ -n "$trace_id" ]]; then
                    echo -e "    - $trace_id"
                fi
            done <<< "$recent_trace_work"
        fi
    else
        echo -e "  ⚠️  Work claims file not accessible"
    fi
    
    echo
    echo "=================================================================================="
    echo -e "${YELLOW}Press Ctrl+C to stop monitoring${NC}"
    echo "=================================================================================="
}

# Main monitoring loop
main_monitoring_loop() {
    monitor_log "Starting live trace monitoring..."
    monitor_log "Monitoring coordination system at: $COORDINATION_ROOT"
    
    local loop_count=0
    
    while true; do
        ((loop_count++))
        
        # Display dashboard
        display_monitoring_dashboard
        
        # Wait before next update
        sleep 5
    done
}

# Signal handler for graceful shutdown
cleanup_monitor() {
    echo
    monitor_log "Stopping live trace monitoring..."
    exit 0
}

trap cleanup_monitor SIGINT SIGTERM

# Execute monitoring
main_monitoring_loop