#!/bin/bash
# Comprehensive Trace Orchestrator - Maximum Shell Script Execution with One Trace ID
# CLAUDE.md: Only trust OpenTelemetry traces - verify everything
# Implements: execute → verify → loop → discover new permutations

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ORCHESTRATOR_DIR="/tmp/trace_orchestrator_$(date +%s)"
MASTER_TRACE_ID=""
EXECUTION_ROUND=0
TOTAL_SCRIPTS_EXECUTED=0
TOTAL_TRACE_VERIFICATIONS=0
SUCCESSFUL_TRACES=0

# Tracking arrays
DISCOVERED_SCRIPTS=()
EXECUTION_PATTERNS=()
SUCCESSFUL_PATTERNS=()
TRACE_EVIDENCE=()

# Create orchestrator directory
mkdir -p "$ORCHESTRATOR_DIR"

# Initialize comprehensive logging
exec 1> >(tee -a "$ORCHESTRATOR_DIR/orchestrator_output.log")
exec 2> >(tee -a "$ORCHESTRATOR_DIR/orchestrator_errors.log" >&2)

echo -e "${BOLD}${PURPLE}🎯 COMPREHENSIVE TRACE ORCHESTRATOR${NC}"
echo -e "${PURPLE}$(printf '=%.0s' {1..50})${NC}"
echo -e "${CYAN}Objective: Maximum shell script execution with single trace ID${NC}"
echo -e "${CYAN}Strategy: Execute → Verify → Loop → Discover permutations${NC}"
echo -e "${CYAN}Orchestrator Directory: $ORCHESTRATOR_DIR${NC}\n"

# Initialize master trace that will propagate through ALL executions
initialize_master_trace() {
    echo -e "${BOLD}${BLUE}🚀 Master Trace Initialization${NC}"
    echo "==============================="
    
    # Generate cryptographically secure master trace ID
    MASTER_TRACE_ID=$(openssl rand -hex 16)
    
    # Set comprehensive trace environment variables
    export TRACE_ID="$MASTER_TRACE_ID"
    export OTEL_TRACE_ID="$MASTER_TRACE_ID"
    export OTEL_SPAN_ID="$(openssl rand -hex 8)"
    export TRACEPARENT="00-${MASTER_TRACE_ID}-${OTEL_SPAN_ID}-01"
    export TRACE_STATE=""
    export ORCHESTRATOR_TRACE_ID="$MASTER_TRACE_ID"
    export COMPREHENSIVE_TRACE_ID="$MASTER_TRACE_ID"
    
    echo -e "${GREEN}✅ Master Trace ID: $MASTER_TRACE_ID${NC}"
    echo -e "${CYAN}📝 TracePArent: $TRACEPARENT${NC}"
    echo -e "${CYAN}🌐 All trace environment variables set${NC}"
    
    # Save master trace info
    cat > "$ORCHESTRATOR_DIR/master_trace_info.json" << EOF
{
  "master_trace_id": "$MASTER_TRACE_ID",
  "orchestrator_start": "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)",
  "orchestrator_dir": "$ORCHESTRATOR_DIR",
  "trace_environment": {
    "TRACE_ID": "$TRACE_ID",
    "OTEL_TRACE_ID": "$OTEL_TRACE_ID",
    "OTEL_SPAN_ID": "$OTEL_SPAN_ID",
    "TRACEPARENT": "$TRACEPARENT",
    "ORCHESTRATOR_TRACE_ID": "$ORCHESTRATOR_TRACE_ID"
  }
}
EOF
    
    echo -e "${CYAN}💾 Master trace info saved${NC}\n"
}

# Discover all available shell scripts in the system
discover_shell_scripts() {
    echo -e "${BOLD}${BLUE}🔍 Shell Script Discovery Phase${NC}"
    echo "================================"
    
    # Find all executable shell scripts
    local search_paths=(
        "$SCRIPT_DIR"
        "$SCRIPT_DIR/agent_coordination"
        "$SCRIPT_DIR/scripts"
        "$SCRIPT_DIR/worktrees"
        "$SCRIPT_DIR/beamops"
    )
    
    DISCOVERED_SCRIPTS=()
    
    for path in "${search_paths[@]}"; do
        if [[ -d "$path" ]]; then
            echo -e "${CYAN}🔍 Searching: $path${NC}"
            
            # Find shell scripts with various patterns
            while IFS= read -r -d '' script; do
                if [[ -x "$script" && -f "$script" ]]; then
                    local script_name=$(basename "$script")
                    echo -e "${GREEN}  ✅ Found: $script_name${NC}"
                    DISCOVERED_SCRIPTS+=("$script")
                fi
            done < <(find "$path" -type f \( -name "*.sh" -o -name "*helper*" -o -name "*deploy*" -o -name "*validate*" \) -executable -print0 2>/dev/null || true)
        fi
    done
    
    # Add coordination helper specifically
    if [[ -x "$SCRIPT_DIR/agent_coordination/coordination_helper.sh" ]]; then
        DISCOVERED_SCRIPTS+=("$SCRIPT_DIR/agent_coordination/coordination_helper.sh")
    fi
    
    echo -e "${GREEN}📊 Total discovered scripts: ${#DISCOVERED_SCRIPTS[@]}${NC}"
    
    # Save discovery results
    printf '%s\n' "${DISCOVERED_SCRIPTS[@]}" > "$ORCHESTRATOR_DIR/discovered_scripts.txt"
    echo -e "${CYAN}💾 Discovery results saved${NC}\n"
}

# Execute a specific shell script with trace context
execute_script_with_trace() {
    local script_path="$1"
    local execution_args="$2"
    local script_name=$(basename "$script_path")
    
    echo -e "${CYAN}🚀 Executing: $script_name${NC}"
    echo -e "${CYAN}   Path: $script_path${NC}"
    echo -e "${CYAN}   Args: $execution_args${NC}"
    echo -e "${CYAN}   Trace: $MASTER_TRACE_ID${NC}"
    
    local execution_start=$(date +%s%N)
    local execution_success=false
    local execution_output=""
    
    # Ensure trace environment is set for this execution
    export TRACE_ID="$MASTER_TRACE_ID"
    export OTEL_TRACE_ID="$MASTER_TRACE_ID"
    export ORCHESTRATOR_TRACE_ID="$MASTER_TRACE_ID"
    
    # Execute the script with timeout
    if execution_output=$(timeout 45 "$script_path" $execution_args 2>&1); then
        execution_success=true
        echo -e "${GREEN}  ✅ SUCCESS: $script_name completed${NC}"
    else
        echo -e "${YELLOW}  ⚠️ TIMEOUT/ERROR: $script_name${NC}"
    fi
    
    local execution_end=$(date +%s%N)
    local execution_duration_ms=$(( (execution_end - execution_start) / 1000000 ))
    
    echo -e "${CYAN}  ⏱️ Duration: ${execution_duration_ms}ms${NC}"
    
    # Log execution details
    cat >> "$ORCHESTRATOR_DIR/execution_log.jsonl" << EOF
{
  "execution_round": $EXECUTION_ROUND,
  "script_name": "$script_name",
  "script_path": "$script_path",
  "execution_args": "$execution_args",
  "master_trace_id": "$MASTER_TRACE_ID",
  "execution_start": "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)",
  "duration_ms": $execution_duration_ms,
  "success": $execution_success,
  "output_preview": "$(echo "$execution_output" | head -c 200 | tr '\n' ' ')"
}
EOF
    
    TOTAL_SCRIPTS_EXECUTED=$((TOTAL_SCRIPTS_EXECUTED + 1))
    
    # Wait for telemetry to be written
    sleep 1
    
    echo ""
}

# Verify trace propagation after script execution
verify_trace_propagation() {
    echo -e "${BOLD}${BLUE}🔍 Trace Propagation Verification${NC}"
    echo "=================================="
    
    local verification_files=(
        "agent_coordination/work_claims.json"
        "agent_coordination/telemetry_spans.jsonl"
        "agent_coordination/agent_status.json"
        "agent_coordination/coordination_log.json"
    )
    
    local round_traces_found=0
    local round_total_occurrences=0
    
    for file in "${verification_files[@]}"; do
        if [[ -f "$file" ]]; then
            local occurrences=$(grep -c "$MASTER_TRACE_ID" "$file" 2>/dev/null | tr -d ' \t\n' || echo "0")
            if [[ ! "$occurrences" =~ ^[0-9]+$ ]]; then
                occurrences=0
            fi
            
            if [[ $occurrences -gt 0 ]]; then
                echo -e "${GREEN}✅ $file: $occurrences traces${NC}"
                round_traces_found=$((round_traces_found + 1))
                round_total_occurrences=$((round_total_occurrences + occurrences))
                
                # Extract evidence
                local evidence=$(grep -n "$MASTER_TRACE_ID" "$file" 2>/dev/null | head -1 || echo "")
                if [[ -n "$evidence" ]]; then
                    TRACE_EVIDENCE+=("Round $EXECUTION_ROUND: $file: ${evidence:0:100}")
                fi
            else
                echo -e "${YELLOW}⚠️ $file: No traces${NC}"
            fi
        else
            echo -e "${RED}❌ $file: Missing${NC}"
        fi
    done
    
    TOTAL_TRACE_VERIFICATIONS=$((TOTAL_TRACE_VERIFICATIONS + 1))
    
    if [[ $round_traces_found -gt 0 ]]; then
        SUCCESSFUL_TRACES=$((SUCCESSFUL_TRACES + 1))
        echo -e "${GREEN}🎯 Round $EXECUTION_ROUND: $round_traces_found files with $round_total_occurrences traces${NC}"
    else
        echo -e "${YELLOW}🔧 Round $EXECUTION_ROUND: No trace propagation detected${NC}"
    fi
    
    # Save verification results
    cat >> "$ORCHESTRATOR_DIR/verification_log.jsonl" << EOF
{
  "round": $EXECUTION_ROUND,
  "master_trace_id": "$MASTER_TRACE_ID",
  "verification_timestamp": "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)",
  "files_with_traces": $round_traces_found,
  "total_occurrences": $round_total_occurrences,
  "success": $([ $round_traces_found -gt 0 ] && echo "true" || echo "false")
}
EOF
    
    echo ""
}

# Generate execution permutation for this round
generate_execution_permutation() {
    local permutation_type=$((EXECUTION_ROUND % 6))
    local execution_pattern=""
    
    case $permutation_type in
        0)
            # Single script execution
            execution_pattern="single"
            echo -e "${PURPLE}🎲 Round $EXECUTION_ROUND: Single Script Execution${NC}"
            ;;
        1)
            # Coordination helper commands
            execution_pattern="coordination"
            echo -e "${PURPLE}🎲 Round $EXECUTION_ROUND: Coordination Helper Focus${NC}"
            ;;
        2)
            # Multiple sequential scripts
            execution_pattern="sequential"
            echo -e "${PURPLE}🎲 Round $EXECUTION_ROUND: Sequential Multi-Script${NC}"
            ;;
        3)
            # Validation scripts focus
            execution_pattern="validation"
            echo -e "${PURPLE}🎲 Round $EXECUTION_ROUND: Validation Scripts Focus${NC}"
            ;;
        4)
            # Deployment scripts focus
            execution_pattern="deployment"
            echo -e "${PURPLE}🎲 Round $EXECUTION_ROUND: Deployment Scripts Focus${NC}"
            ;;
        5)
            # Random combination
            execution_pattern="random"
            echo -e "${PURPLE}🎲 Round $EXECUTION_ROUND: Random Combination${NC}"
            ;;
    esac
    
    EXECUTION_PATTERNS+=("Round $EXECUTION_ROUND: $execution_pattern")
    echo ""
}

# Execute coordination helper commands with trace
execute_coordination_commands() {
    echo -e "${CYAN}🔄 Coordination Helper Command Execution${NC}"
    
    local coord_helper="$SCRIPT_DIR/agent_coordination/coordination_helper.sh"
    if [[ -x "$coord_helper" ]]; then
        local commands=(
            "claim-intelligent orchestrator_test_$EXECUTION_ROUND 'Orchestrator test round $EXECUTION_ROUND' high orchestrator_team"
            "claude-analyze-priorities"
            "claude-analyze-health"
            "claude-dashboard"
            "status"
        )
        
        for cmd in "${commands[@]}"; do
            execute_script_with_trace "$coord_helper" "$cmd"
        done
    fi
}

# Execute validation scripts with trace
execute_validation_scripts() {
    echo -e "${CYAN}🔄 Validation Script Execution${NC}"
    
    for script in "${DISCOVERED_SCRIPTS[@]}"; do
        if [[ "$script" =~ validate.*\.sh$ ]]; then
            execute_script_with_trace "$script" ""
        fi
    done
}

# Execute deployment scripts with trace
execute_deployment_scripts() {
    echo -e "${CYAN}🔄 Deployment Script Execution${NC}"
    
    for script in "${DISCOVERED_SCRIPTS[@]}"; do
        if [[ "$script" =~ deploy.*\.sh$ ]] || [[ "$script" =~ manage.*\.sh$ ]]; then
            # Safe deployment commands
            if [[ "$script" =~ manage.*\.sh$ ]]; then
                execute_script_with_trace "$script" "status"
            else
                execute_script_with_trace "$script" ""
            fi
        fi
    done
}

# Execute random script combination
execute_random_combination() {
    echo -e "${CYAN}🔄 Random Script Combination${NC}"
    
    local num_scripts=${#DISCOVERED_SCRIPTS[@]}
    if [[ $num_scripts -gt 0 ]]; then
        # Execute 2-4 random scripts
        local scripts_to_execute=$((RANDOM % 3 + 2))
        
        for ((i=1; i<=scripts_to_execute; i++)); do
            local random_index=$((RANDOM % num_scripts))
            local script="${DISCOVERED_SCRIPTS[$random_index]}"
            
            # Determine safe arguments
            local args=""
            if [[ "$script" =~ coordination_helper\.sh$ ]]; then
                args="status"
            elif [[ "$script" =~ manage.*\.sh$ ]]; then
                args="status"
            fi
            
            execute_script_with_trace "$script" "$args"
        done
    fi
}

# Main execution round
execute_round() {
    EXECUTION_ROUND=$((EXECUTION_ROUND + 1))
    
    echo -e "${BOLD}${PURPLE}🎯 EXECUTION ROUND $EXECUTION_ROUND${NC}"
    echo -e "${PURPLE}$(printf '=%.0s' {1..40})${NC}"
    echo -e "${CYAN}Master Trace: $MASTER_TRACE_ID${NC}"
    echo -e "${CYAN}Round Start: $(date)${NC}\n"
    
    # Generate execution pattern for this round
    generate_execution_permutation
    
    local permutation_type=$((EXECUTION_ROUND % 6))
    
    case $permutation_type in
        0)
            # Single script execution
            if [[ ${#DISCOVERED_SCRIPTS[@]} -gt 0 ]]; then
                local script_index=$((EXECUTION_ROUND % ${#DISCOVERED_SCRIPTS[@]}))
                execute_script_with_trace "${DISCOVERED_SCRIPTS[$script_index]}" ""
            fi
            ;;
        1)
            execute_coordination_commands
            ;;
        2)
            # Sequential execution of multiple scripts
            local scripts_to_run=3
            for ((i=0; i<scripts_to_run && i<${#DISCOVERED_SCRIPTS[@]}; i++)); do
                local script_index=$(( (EXECUTION_ROUND + i) % ${#DISCOVERED_SCRIPTS[@]} ))
                execute_script_with_trace "${DISCOVERED_SCRIPTS[$script_index]}" ""
            done
            ;;
        3)
            execute_validation_scripts
            ;;
        4)
            execute_deployment_scripts
            ;;
        5)
            execute_random_combination
            ;;
    esac
    
    # Verify trace propagation after execution
    verify_trace_propagation
    
    # Generate round summary
    generate_round_summary
}

# Generate summary for this round
generate_round_summary() {
    echo -e "${BOLD}${BLUE}📊 Round $EXECUTION_ROUND Summary${NC}"
    echo "========================="
    
    local success_rate=0
    if [[ $TOTAL_TRACE_VERIFICATIONS -gt 0 ]]; then
        success_rate=$((SUCCESSFUL_TRACES * 100 / TOTAL_TRACE_VERIFICATIONS))
    fi
    
    echo -e "${CYAN}Total Scripts Executed: $TOTAL_SCRIPTS_EXECUTED${NC}"
    echo -e "${CYAN}Total Verifications: $TOTAL_TRACE_VERIFICATIONS${NC}"
    echo -e "${CYAN}Successful Traces: $SUCCESSFUL_TRACES${NC}"
    echo -e "${CYAN}Success Rate: $success_rate%${NC}"
    echo -e "${CYAN}Master Trace ID: $MASTER_TRACE_ID${NC}"
    
    # Save comprehensive round summary
    cat > "$ORCHESTRATOR_DIR/round_${EXECUTION_ROUND}_summary.json" << EOF
{
  "round": $EXECUTION_ROUND,
  "master_trace_id": "$MASTER_TRACE_ID",
  "round_timestamp": "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)",
  "total_scripts_executed": $TOTAL_SCRIPTS_EXECUTED,
  "total_verifications": $TOTAL_TRACE_VERIFICATIONS,
  "successful_traces": $SUCCESSFUL_TRACES,
  "success_rate_percent": $success_rate,
  "execution_patterns": [
$(printf '    "%s"' "${EXECUTION_PATTERNS[@]}" | paste -sd, -)
  ],
  "trace_evidence_count": ${#TRACE_EVIDENCE[@]}
}
EOF
    
    echo -e "${CYAN}💾 Round summary saved${NC}\n"
}

# Continuous orchestrator loop
continuous_orchestration_loop() {
    echo -e "${BOLD}${GREEN}🔄 CONTINUOUS ORCHESTRATION LOOP STARTED${NC}"
    echo "========================================"
    echo -e "${YELLOW}Press Ctrl+C to stop the orchestrator${NC}\n"
    
    while true; do
        execute_round
        
        # Brief pause between rounds
        echo -e "${CYAN}⏱️ Pausing 3 seconds before next round...${NC}\n"
        sleep 3
        
        # Every 10 rounds, show comprehensive statistics
        if [[ $((EXECUTION_ROUND % 10)) -eq 0 ]]; then
            show_comprehensive_statistics
        fi
    done
}

# Show comprehensive statistics
show_comprehensive_statistics() {
    echo -e "${BOLD}${PURPLE}📈 COMPREHENSIVE ORCHESTRATOR STATISTICS${NC}"
    echo -e "${PURPLE}$(printf '=%.0s' {1..45})${NC}"
    
    local success_rate=0
    if [[ $TOTAL_TRACE_VERIFICATIONS -gt 0 ]]; then
        success_rate=$((SUCCESSFUL_TRACES * 100 / TOTAL_TRACE_VERIFICATIONS))
    fi
    
    echo -e "${CYAN}Master Trace ID: ${GREEN}$MASTER_TRACE_ID${NC}"
    echo -e "${CYAN}Execution Rounds: $EXECUTION_ROUND${NC}"
    echo -e "${CYAN}Total Scripts Executed: $TOTAL_SCRIPTS_EXECUTED${NC}"
    echo -e "${CYAN}Total Verifications: $TOTAL_TRACE_VERIFICATIONS${NC}"
    echo -e "${CYAN}Successful Traces: $SUCCESSFUL_TRACES${NC}"
    echo -e "${CYAN}Overall Success Rate: $success_rate%${NC}"
    echo -e "${CYAN}Discovered Scripts: ${#DISCOVERED_SCRIPTS[@]}${NC}"
    echo -e "${CYAN}Execution Patterns: ${#EXECUTION_PATTERNS[@]}${NC}"
    echo -e "${CYAN}Trace Evidence: ${#TRACE_EVIDENCE[@]}${NC}"
    
    echo -e "\n${CYAN}📁 Generated Files:${NC}"
    echo -e "  📊 Master Trace: $ORCHESTRATOR_DIR/master_trace_info.json"
    echo -e "  📝 Execution Log: $ORCHESTRATOR_DIR/execution_log.jsonl"
    echo -e "  🔍 Verification Log: $ORCHESTRATOR_DIR/verification_log.jsonl"
    echo -e "  📄 Output Log: $ORCHESTRATOR_DIR/orchestrator_output.log"
    
    echo -e "\n${CYAN}Recent Trace Evidence:${NC}"
    local evidence_count=${#TRACE_EVIDENCE[@]}
    local start_index=$((evidence_count > 5 ? evidence_count - 5 : 0))
    for ((i=start_index; i<evidence_count; i++)); do
        echo -e "  ${GREEN}✅ ${TRACE_EVIDENCE[$i]}${NC}"
    done
    
    echo ""
}

# Graceful shutdown handler
graceful_shutdown() {
    echo -e "\n${YELLOW}🛑 Graceful shutdown initiated...${NC}"
    
    # Generate final comprehensive report
    cat > "$ORCHESTRATOR_DIR/final_orchestrator_report.json" << EOF
{
  "orchestrator_session": {
    "master_trace_id": "$MASTER_TRACE_ID",
    "session_start": "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)",
    "total_rounds": $EXECUTION_ROUND,
    "total_scripts_executed": $TOTAL_SCRIPTS_EXECUTED,
    "total_verifications": $TOTAL_TRACE_VERIFICATIONS,
    "successful_traces": $SUCCESSFUL_TRACES,
    "success_rate_percent": $((SUCCESSFUL_TRACES * 100 / (TOTAL_TRACE_VERIFICATIONS > 0 ? TOTAL_TRACE_VERIFICATIONS : 1))),
    "discovered_scripts_count": ${#DISCOVERED_SCRIPTS[@]},
    "execution_patterns_count": ${#EXECUTION_PATTERNS[@]},
    "trace_evidence_count": ${#TRACE_EVIDENCE[@]}
  },
  "execution_patterns": [
$(printf '    "%s"' "${EXECUTION_PATTERNS[@]}" | paste -sd, -)
  ],
  "discovered_scripts": [
$(printf '    "%s"' "${DISCOVERED_SCRIPTS[@]}" | paste -sd, -)
  ]
}
EOF
    
    echo -e "${GREEN}📊 Final report saved to: $ORCHESTRATOR_DIR/final_orchestrator_report.json${NC}"
    echo -e "${CYAN}🏁 Orchestrator completed ${EXECUTION_ROUND} rounds with trace $MASTER_TRACE_ID${NC}"
    
    exit 0
}

# Main execution
main() {
    # Set up signal handlers
    trap graceful_shutdown SIGINT SIGTERM
    
    echo -e "${CYAN}🚀 Starting comprehensive trace orchestrator...${NC}\n"
    
    # Initialize the master trace
    initialize_master_trace
    
    # Discover all available shell scripts
    discover_shell_scripts
    
    # Start continuous orchestration loop
    continuous_orchestration_loop
}

# Execute orchestrator
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi