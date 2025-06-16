#!/bin/bash

# Infinite Trace Orchestrator - Chaos Engineering for OpenTelemetry
# Discovers, executes, and permutes ALL shell scripts while maintaining ONE trace ID
# NEVER STOPS - Continuously finds new combinations and validates trace propagation

set -e

# Colors and formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Global orchestrator state
MASTER_TRACE_ID=""
ORCHESTRATOR_ID=""
EXECUTION_COUNTER=0
PERMUTATION_COUNTER=0
DISCOVERED_SCRIPTS=()
EXECUTION_LOG="infinite_trace_orchestrator_$(date +%s).log"
TRACE_VERIFICATION_LOG="trace_verification_$(date +%s).jsonl"
COMBINATION_HISTORY=()
MAX_COMBINATION_SIZE=5
MIN_COMBINATION_SIZE=1

# Performance tracking
SUCCESSFUL_PROPAGATIONS=0
FAILED_PROPAGATIONS=0
TOTAL_SCRIPTS_EXECUTED=0
UNIQUE_COMBINATIONS_TESTED=0

# Initialize infinite orchestrator
initialize_orchestrator() {
    MASTER_TRACE_ID=$(openssl rand -hex 16)
    ORCHESTRATOR_ID="orchestrator_$(date +%s%N)"
    
    # Set global trace environment
    export TRACE_ID="$MASTER_TRACE_ID"
    export OTEL_TRACE_ID="$MASTER_TRACE_ID"
    export TRACEPARENT="00-${MASTER_TRACE_ID}-$(openssl rand -hex 8)-01"
    export X_TRACE_ID="$MASTER_TRACE_ID"
    export MASTER_TRACE="$MASTER_TRACE_ID"
    export ORCHESTRATOR_ID="$ORCHESTRATOR_ID"
    
    echo -e "${BOLD}${PURPLE}🚀 INFINITE TRACE ORCHESTRATOR INITIALIZED${NC}"
    echo -e "${PURPLE}$(printf '=%.0s' {1..60})${NC}"
    echo -e "${CYAN}Master Trace ID: ${BOLD}$MASTER_TRACE_ID${NC}"
    echo -e "${CYAN}Orchestrator ID: ${BOLD}$ORCHESTRATOR_ID${NC}"
    echo -e "${CYAN}Mission: Infinite shell script trace propagation validation${NC}"
    echo ""
    
    # Initialize logs
    echo "# Infinite Trace Orchestrator Execution Log" > "$EXECUTION_LOG"
    echo "# Master Trace: $MASTER_TRACE_ID" >> "$EXECUTION_LOG"
    echo "# Orchestrator: $ORCHESTRATOR_ID" >> "$EXECUTION_LOG"
    echo "" > "$TRACE_VERIFICATION_LOG"
}

# Discover all executable shell scripts in the system
discover_shell_scripts() {
    echo -e "${BLUE}🔍 Discovering shell scripts across the system...${NC}"
    
    local script_patterns=(
        "*.sh"
        "scripts/*.sh" 
        "*/scripts/*.sh"
        "agent_coordination/*.sh"
        "phoenix_app/scripts/*.sh"
        "beamops/*/scripts/*.sh"
        "scripts/*.sh"
        "*/coordination_helper.sh"
        "validate_*.sh"
        "test_*.sh"
        "benchmark_*.sh"
        "deploy_*.sh"
        "setup_*.sh"
    )
    
    DISCOVERED_SCRIPTS=()
    
    for pattern in "${script_patterns[@]}"; do
        while IFS= read -r -d '' script; do
            # Only include executable scripts, exclude this orchestrator
            if [[ -x "$script" && "$script" != "${BASH_SOURCE[0]}" && "$script" != "./infinite_trace_orchestrator.sh" ]]; then
                # Get relative path
                local rel_script=$(realpath --relative-to=. "$script" 2>/dev/null || echo "$script")
                DISCOVERED_SCRIPTS+=("$rel_script")
            fi
        done < <(find . -name "$pattern" -type f -print0 2>/dev/null)
    done
    
    # Remove duplicates and sort
    IFS=$'\n' DISCOVERED_SCRIPTS=($(printf '%s\n' "${DISCOVERED_SCRIPTS[@]}" | sort -u))
    
    echo -e "${GREEN}📊 Discovered ${#DISCOVERED_SCRIPTS[@]} executable shell scripts:${NC}"
    for script in "${DISCOVERED_SCRIPTS[@]}"; do
        echo -e "  ${CYAN}📜 $script${NC}"
    done
    echo ""
    
    log_orchestrator_event "script_discovery" "SUCCESS" "${#DISCOVERED_SCRIPTS[@]} scripts discovered"
}

# Log orchestrator events with trace correlation
log_orchestrator_event() {
    local event_type="$1"
    local status="$2"
    local details="$3"
    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)
    
    local log_entry="[$timestamp] $event_type: $status - $details (trace: $MASTER_TRACE_ID)"
    echo "$log_entry" | tee -a "$EXECUTION_LOG"
    
    # JSON log for trace verification
    local json_entry=$(jq -n \
        --arg timestamp "$timestamp" \
        --arg orchestrator_id "$ORCHESTRATOR_ID" \
        --arg master_trace "$MASTER_TRACE_ID" \
        --arg event_type "$event_type" \
        --arg status "$status" \
        --arg details "$details" \
        --arg execution_counter "$EXECUTION_COUNTER" \
        --arg permutation_counter "$PERMUTATION_COUNTER" \
        '{
            timestamp: $timestamp,
            orchestrator_id: $orchestrator_id,
            master_trace_id: $master_trace,
            event_type: $event_type,
            status: $status,
            details: $details,
            execution_counter: ($execution_counter | tonumber),
            permutation_counter: ($permutation_counter | tonumber)
        }')
    
    echo "$json_entry" >> "$TRACE_VERIFICATION_LOG"
}

# Generate next combination of scripts to execute
generate_next_combination() {
    local combination_size=$((RANDOM % MAX_COMBINATION_SIZE + MIN_COMBINATION_SIZE))
    local selected_scripts=()
    local temp_scripts=("${DISCOVERED_SCRIPTS[@]}")
    
    # Randomly select scripts for this combination
    for ((i=0; i<combination_size && ${#temp_scripts[@]}>0; i++)); do
        local random_index=$((RANDOM % ${#temp_scripts[@]}))
        selected_scripts+=("${temp_scripts[$random_index]}")
        
        # Remove selected script to avoid duplicates in this combination
        temp_scripts=("${temp_scripts[@]:0:$random_index}" "${temp_scripts[@]:$((random_index + 1))}")
    done
    
    # Create combination signature for uniqueness tracking
    local combination_sig=$(printf '%s,' "${selected_scripts[@]}" | sort | md5sum | cut -d' ' -f1)
    
    # Check if we've tested this exact combination before
    local is_unique=true
    for tested_combo in "${COMBINATION_HISTORY[@]}"; do
        if [[ "$tested_combo" == "$combination_sig" ]]; then
            is_unique=false
            break
        fi
    done
    
    if [[ "$is_unique" == "true" ]]; then
        COMBINATION_HISTORY+=("$combination_sig")
        UNIQUE_COMBINATIONS_TESTED=$((UNIQUE_COMBINATIONS_TESTED + 1))
        echo "${selected_scripts[@]}"
        return 0
    else
        # Try again with different combination
        if [[ ${#COMBINATION_HISTORY[@]} -lt 1000 ]]; then
            generate_next_combination
        else
            # Reset history if we've tested too many combinations
            COMBINATION_HISTORY=()
            echo "${selected_scripts[@]}"
            return 0
        fi
    fi
}

# Execute script with trace propagation verification
execute_script_with_trace() {
    local script_path="$1"
    local execution_id="exec_${EXECUTION_COUNTER}_$(date +%s%N)"
    
    echo -e "${BLUE}🔧 Executing: $script_path (ID: $execution_id)${NC}"
    
    # Set execution-specific environment
    export EXECUTION_ID="$execution_id"
    export SCRIPT_EXECUTION_TRACE="$MASTER_TRACE_ID"
    export ORCHESTRATOR_EXECUTION="true"
    
    local start_time=$(date +%s%N)
    local execution_success=false
    local trace_propagated=false
    local output_captured=""
    
    # Execute script with timeout and capture output
    if timeout 30s bash "$script_path" --trace-test 2>&1 | tee /tmp/script_output_${execution_id}.log; then
        execution_success=true
        TOTAL_SCRIPTS_EXECUTED=$((TOTAL_SCRIPTS_EXECUTED + 1))
    fi
    
    local end_time=$(date +%s%N)
    local duration_ms=$(( (end_time - start_time) / 1000000 ))
    
    # Check for trace propagation in output
    if [[ -f "/tmp/script_output_${execution_id}.log" ]]; then
        output_captured=$(cat "/tmp/script_output_${execution_id}.log")
        if echo "$output_captured" | grep -q "$MASTER_TRACE_ID"; then
            trace_propagated=true
            SUCCESSFUL_PROPAGATIONS=$((SUCCESSFUL_PROPAGATIONS + 1))
        else
            FAILED_PROPAGATIONS=$((FAILED_PROPAGATIONS + 1))
        fi
        rm -f "/tmp/script_output_${execution_id}.log"
    fi
    
    # Log execution results
    local result_status="SUCCESS"
    if [[ "$execution_success" == "false" ]]; then
        result_status="EXECUTION_FAILED"
    elif [[ "$trace_propagated" == "false" ]]; then
        result_status="TRACE_NOT_PROPAGATED"
    fi
    
    log_orchestrator_event "script_execution" "$result_status" "script=$script_path, duration=${duration_ms}ms, trace_propagated=$trace_propagated"
    
    if [[ "$trace_propagated" == "true" ]]; then
        echo -e "${GREEN}✅ $script_path: Trace propagated (${duration_ms}ms)${NC}"
    else
        echo -e "${YELLOW}⚠️  $script_path: No trace propagation detected (${duration_ms}ms)${NC}"
    fi
    
    return 0
}

# Execute combination of scripts in sequence
execute_script_combination() {
    local scripts=("$@")
    local combination_id="combo_${PERMUTATION_COUNTER}_$(date +%s%N)"
    
    echo -e "\n${BOLD}${CYAN}🎭 COMBINATION $PERMUTATION_COUNTER: ${#scripts[@]} scripts${NC}"
    echo -e "${CYAN}Combination ID: $combination_id${NC}"
    echo -e "${CYAN}Scripts: ${scripts[*]}${NC}"
    
    log_orchestrator_event "combination_start" "STARTED" "combination_id=$combination_id, scripts=${#scripts[@]}, list=${scripts[*]}"
    
    local combination_start_time=$(date +%s%N)
    local scripts_executed=0
    local traces_propagated=0
    
    # Execute each script in the combination
    for script in "${scripts[@]}"; do
        if [[ -x "$script" ]]; then
            EXECUTION_COUNTER=$((EXECUTION_COUNTER + 1))
            execute_script_with_trace "$script"
            scripts_executed=$((scripts_executed + 1))
            
            # Brief pause between scripts
            sleep 0.5
        else
            echo -e "${RED}❌ Script not executable: $script${NC}"
            log_orchestrator_event "script_skip" "NOT_EXECUTABLE" "script=$script"
        fi
    done
    
    local combination_end_time=$(date +%s%N)
    local combination_duration_ms=$(( (combination_end_time - combination_start_time) / 1000000 ))
    
    echo -e "${PURPLE}📊 Combination $PERMUTATION_COUNTER completed: ${scripts_executed} scripts in ${combination_duration_ms}ms${NC}"
    log_orchestrator_event "combination_complete" "SUCCESS" "combination_id=$combination_id, duration=${combination_duration_ms}ms, scripts_executed=$scripts_executed"
    
    PERMUTATION_COUNTER=$((PERMUTATION_COUNTER + 1))
}

# Display orchestrator status
show_orchestrator_status() {
    local uptime_seconds=$(( $(date +%s) - $(stat -c %Y "$EXECUTION_LOG" 2>/dev/null || echo 0) ))
    local propagation_rate=0
    
    if [[ $TOTAL_SCRIPTS_EXECUTED -gt 0 ]]; then
        propagation_rate=$((SUCCESSFUL_PROPAGATIONS * 100 / TOTAL_SCRIPTS_EXECUTED))
    fi
    
    echo -e "\n${BOLD}${PURPLE}📊 ORCHESTRATOR STATUS${NC}"
    echo -e "${PURPLE}$(printf '=%.0s' {1..30})${NC}"
    echo -e "${CYAN}Master Trace: ${BOLD}$MASTER_TRACE_ID${NC}"
    echo -e "${CYAN}Uptime: ${BOLD}${uptime_seconds}s${NC}"
    echo -e "${CYAN}Combinations Tested: ${BOLD}$PERMUTATION_COUNTER${NC}"
    echo -e "${CYAN}Unique Combinations: ${BOLD}$UNIQUE_COMBINATIONS_TESTED${NC}"
    echo -e "${CYAN}Scripts Executed: ${BOLD}$TOTAL_SCRIPTS_EXECUTED${NC}"
    echo -e "${CYAN}Trace Propagations: ${BOLD}$SUCCESSFUL_PROPAGATIONS${NC}"
    echo -e "${CYAN}Propagation Rate: ${BOLD}${propagation_rate}%${NC}"
    echo -e "${CYAN}Scripts Available: ${BOLD}${#DISCOVERED_SCRIPTS[@]}${NC}"
}

# Handle graceful shutdown (though we never want to stop)
cleanup_orchestrator() {
    echo -e "\n${YELLOW}🛑 Orchestrator interrupted (but we never truly stop!)${NC}"
    show_orchestrator_status
    
    echo -e "\n${BLUE}📁 Generated files:${NC}"
    echo -e "  📋 Execution Log: $EXECUTION_LOG"
    echo -e "  🔍 Trace Verification: $TRACE_VERIFICATION_LOG"
    
    log_orchestrator_event "orchestrator_cleanup" "INTERRUPTED" "final_stats: combinations=$PERMUTATION_COUNTER, executions=$TOTAL_SCRIPTS_EXECUTED, propagations=$SUCCESSFUL_PROPAGATIONS"
}

# Set up signal handling for graceful shutdown
trap cleanup_orchestrator SIGINT SIGTERM

# Infinite orchestration loop - NEVER STOPS
infinite_orchestration_loop() {
    echo -e "${BOLD}${GREEN}🔄 ENTERING INFINITE ORCHESTRATION LOOP${NC}"
    echo -e "${GREEN}The orchestrator will NEVER stop finding new combinations...${NC}\n"
    
    local loop_counter=0
    local last_status_time=$(date +%s)
    
    while true; do
        loop_counter=$((loop_counter + 1))
        
        # Generate next combination
        local script_combination
        read -ra script_combination <<< "$(generate_next_combination)"
        
        if [[ ${#script_combination[@]} -gt 0 ]]; then
            execute_script_combination "${script_combination[@]}"
        else
            echo -e "${BLUE}🔄 No new combinations available, rediscovering scripts...${NC}"
            discover_shell_scripts
        fi
        
        # Show status every 60 seconds
        local current_time=$(date +%s)
        if [[ $((current_time - last_status_time)) -ge 60 ]]; then
            show_orchestrator_status
            last_status_time=$current_time
        fi
        
        # Brief pause before next combination
        sleep 2
        
        # Rediscover scripts periodically to catch new ones
        if [[ $((loop_counter % 50)) -eq 0 ]]; then
            echo -e "${BLUE}🔄 Periodic script rediscovery (loop $loop_counter)...${NC}"
            discover_shell_scripts
        fi
        
        # Rotate logs if they get too large
        if [[ -f "$EXECUTION_LOG" && $(stat -c%s "$EXECUTION_LOG" 2>/dev/null || echo 0) -gt 10485760 ]]; then  # 10MB
            mv "$EXECUTION_LOG" "${EXECUTION_LOG}.$(date +%s)"
            echo "# Infinite Trace Orchestrator Execution Log (Rotated)" > "$EXECUTION_LOG"
            log_orchestrator_event "log_rotation" "SUCCESS" "rotated at loop $loop_counter"
        fi
    done
}

# Main orchestrator execution
main() {
    echo -e "${BOLD}${PURPLE}🎯 INFINITE TRACE ORCHESTRATOR${NC}"
    echo -e "${PURPLE}Chaos Engineering for OpenTelemetry Trace Propagation${NC}"
    echo -e "${PURPLE}$(printf '=%.0s' {1..60})${NC}\n"
    
    # Initialize the orchestrator
    initialize_orchestrator
    
    # Discover all available shell scripts
    discover_shell_scripts
    
    # Start infinite orchestration
    infinite_orchestration_loop
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi