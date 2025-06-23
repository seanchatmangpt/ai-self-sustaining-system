#!/bin/bash

# Infinite Trace Orchestrator - Ultimate Distributed Tracing Validation
# Triggers every possible shell script while maintaining one master trace ID
# Continuously loops through different permutations and execution patterns

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
COORDINATION_ROOT="$ROOT_DIR/agent_coordination"
TELEMETRY_SPANS="$COORDINATION_ROOT/telemetry_spans.jsonl"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Global trace orchestration
MASTER_TRACE_ID=$(openssl rand -hex 16)
ORCHESTRATION_SESSION="infinite_trace_$(date +%s)"
ORCHESTRATION_START_TIME=$(date +%s%N)
EXECUTION_COUNTER=0
PERMUTATION_COUNTER=0
TOTAL_SCRIPTS_EXECUTED=0
SUCCESSFUL_TRACES=0
FAILED_TRACES=0

# Script discovery and categorization
DISCOVERED_SCRIPTS=()
COORDINATION_SCRIPTS=()
BEAMOPS_SCRIPTS=()
VALIDATION_SCRIPTS=()
SYSTEM_SCRIPTS=()
DEPLOYMENT_SCRIPTS=()
ALL_EXECUTABLE_SCRIPTS=()

log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] [ORCHESTRATOR]${NC} $1"
}

trace_log() {
    echo -e "${PURPLE}[$(date '+%Y-%m-%d %H:%M:%S')] [TRACE:$MASTER_TRACE_ID]${NC} $1"
}

success() {
    echo -e "${GREEN}✅ [ORCHESTRATOR]${NC} $1"
    ((SUCCESSFUL_TRACES++))
}

error() {
    echo -e "${RED}❌ [ORCHESTRATOR]${NC} $1"
    ((FAILED_TRACES++))
}

# Function to discover all executable scripts in the system
discover_all_scripts() {
    log "Discovering all executable scripts in the system..."
    
    # Clear previous discoveries
    DISCOVERED_SCRIPTS=()
    COORDINATION_SCRIPTS=()
    BEAMOPS_SCRIPTS=()
    VALIDATION_SCRIPTS=()
    SYSTEM_SCRIPTS=()
    DEPLOYMENT_SCRIPTS=()
    ALL_EXECUTABLE_SCRIPTS=()
    
    # Search patterns for different script types
    local search_paths=(
        "$ROOT_DIR/scripts"
        "$ROOT_DIR/agent_coordination"
        "$ROOT_DIR/beamops/v3/scripts"
        "$ROOT_DIR/beamops/v3/instrumentation"
        "$ROOT_DIR/worktrees"
        "$ROOT_DIR/phoenix_app/scripts"
        "$ROOT_DIR"
    )
    
    # Discover scripts by category
    for search_path in "${search_paths[@]}"; do
        if [[ -d "$search_path" ]]; then
            # Find all executable shell scripts
            while IFS= read -r -d '' script_file; do
                if [[ -x "$script_file" && "$script_file" != *"infinite_trace_orchestrator.sh" ]]; then
                    DISCOVERED_SCRIPTS+=("$script_file")
                    
                    # Categorize scripts
                    if [[ "$script_file" == *"coordination"* ]]; then
                        COORDINATION_SCRIPTS+=("$script_file")
                    elif [[ "$script_file" == *"beamops"* ]]; then
                        BEAMOPS_SCRIPTS+=("$script_file")
                    elif [[ "$script_file" == *"validation"* || "$script_file" == *"test"* || "$script_file" == *"e2e"* ]]; then
                        VALIDATION_SCRIPTS+=("$script_file")
                    elif [[ "$script_file" == *"deploy"* || "$script_file" == *"setup"* || "$script_file" == *"install"* ]]; then
                        DEPLOYMENT_SCRIPTS+=("$script_file")
                    else
                        SYSTEM_SCRIPTS+=("$script_file")
                    fi
                fi
            done < <(find "$search_path" -type f \( -name "*.sh" -o -perm +111 \) -print0 2>/dev/null)
        fi
    done
    
    # Also find coordination_helper.sh specifically
    if [[ -x "$COORDINATION_ROOT/coordination_helper.sh" ]]; then
        COORDINATION_SCRIPTS+=("$COORDINATION_ROOT/coordination_helper.sh")
    fi
    
    # Combine all discovered scripts
    ALL_EXECUTABLE_SCRIPTS=(
        "${COORDINATION_SCRIPTS[@]}"
        "${BEAMOPS_SCRIPTS[@]}"
        "${VALIDATION_SCRIPTS[@]}"
        "${SYSTEM_SCRIPTS[@]}"
        "${DEPLOYMENT_SCRIPTS[@]}"
    )
    
    log "Script discovery completed:"
    log "  Coordination Scripts: ${#COORDINATION_SCRIPTS[@]}"
    log "  BeamOps Scripts: ${#BEAMOPS_SCRIPTS[@]}"
    log "  Validation Scripts: ${#VALIDATION_SCRIPTS[@]}"
    log "  System Scripts: ${#SYSTEM_SCRIPTS[@]}"
    log "  Deployment Scripts: ${#DEPLOYMENT_SCRIPTS[@]}"
    log "  Total Discovered: ${#ALL_EXECUTABLE_SCRIPTS[@]}"
}

# Function to execute a script with trace propagation
execute_script_with_trace() {
    local script_path="$1"
    local execution_mode="${2:-sequential}"
    local additional_args="${3:-}"
    
    ((EXECUTION_COUNTER++))
    local execution_id="exec_${EXECUTION_COUNTER}_$(date +%s%N)"
    local span_id=$(openssl rand -hex 8)
    
    trace_log "Executing script: $(basename "$script_path") [Mode: $execution_mode] [Exec: $execution_id]"
    
    # Set comprehensive trace environment for the script
    export ORCHESTRATOR_TRACE_ID="$MASTER_TRACE_ID"
    export OTEL_TRACE_ID="$MASTER_TRACE_ID"
    export OTEL_PARENT_SPAN_ID="$span_id"
    export OTEL_SERVICE_NAME="infinite-trace-orchestrator"
    export OTEL_RESOURCE_ATTRIBUTES="service.name=infinite-trace-orchestrator,orchestration.session=$ORCHESTRATION_SESSION,execution.id=$execution_id,execution.mode=$execution_mode"
    export TRACE_EXECUTION_ID="$execution_id"
    export TRACE_ORCHESTRATION_SESSION="$ORCHESTRATION_SESSION"
    
    # Record span start
    record_orchestration_span "script_execution_start" "$span_id" "$script_path" "$execution_mode"
    
    local start_time=$(date +%s%N)
    local script_output=""
    local script_exit_code=0
    
    # Execute the script with timeout and capture output

    # 80/20 TRACE PROPAGATION FIX - Add OTEL environment variables for child processes
    export TRACEPARENT="00-${MASTER_TRACE_ID}-${OTEL_SPAN_ID:-$(openssl rand -hex 8)}-01"
    export OTEL_TRACE_ID="$MASTER_TRACE_ID"
    export MASTER_TRACE="$MASTER_TRACE_ID"
    export OTEL_SERVICE_NAME="trace-orchestrator-child"
    

    if script_output=$(timeout 30s "$script_path" $additional_args 2>&1); then
        local end_time=$(date +%s%N)
        local duration_ms=$(( (end_time - start_time) / 1000000 ))
        
        # Check if trace ID appears in output (trace propagation verification)
        if echo "$script_output" | grep -q "$MASTER_TRACE_ID"; then
            success "Script $(basename "$script_path") executed with VERIFIED trace propagation ($duration_ms ms)"
            record_trace_evidence "$script_path" "$execution_id" "trace_verified" "$script_output"
        else
            success "Script $(basename "$script_path") executed successfully ($duration_ms ms)"
            record_trace_evidence "$script_path" "$execution_id" "executed" "$script_output"
        fi
        
        ((TOTAL_SCRIPTS_EXECUTED++))
    else
        script_exit_code=$?
        local end_time=$(date +%s%N)
        local duration_ms=$(( (end_time - start_time) / 1000000 ))
        
        if [[ $script_exit_code -eq 124 ]]; then
            error "Script $(basename "$script_path") timed out after 30s"
            record_trace_evidence "$script_path" "$execution_id" "timeout" "Script execution timed out"
        else
            error "Script $(basename "$script_path") failed with exit code $script_exit_code ($duration_ms ms)"
            record_trace_evidence "$script_path" "$execution_id" "failed" "$script_output"
        fi
    fi
    
    # Record span completion
    record_orchestration_span "script_execution_complete" "$span_id" "$script_path" "$execution_mode"
    
    # Clean up trace environment (but keep master trace)
    unset OTEL_PARENT_SPAN_ID OTEL_SERVICE_NAME OTEL_RESOURCE_ATTRIBUTES TRACE_EXECUTION_ID
    
    return $script_exit_code
}

# Function to record orchestration telemetry spans
record_orchestration_span() {
    local operation="$1"
    local span_id="$2"
    local script_path="${3:-unknown}"
    local execution_mode="${4:-unknown}"
    local timestamp=$(date -Iseconds)
    local duration_ns=$(($(date +%s%N) - ORCHESTRATION_START_TIME))
    
    local span_entry=$(cat <<EOF
{
  "trace_id": "$MASTER_TRACE_ID",
  "span_id": "$span_id",
  "operation_name": "orchestrator.$operation",
  "service_name": "infinite-trace-orchestrator",
  "start_time": "$timestamp",
  "duration_ns": $duration_ns,
  "status": {"code": "OK", "message": "Orchestration operation completed"},
  "tags": {
    "orchestration.session": "$ORCHESTRATION_SESSION",
    "orchestration.execution_counter": $EXECUTION_COUNTER,
    "orchestration.permutation_counter": $PERMUTATION_COUNTER,
    "script.path": "$script_path",
    "script.name": "$(basename "$script_path")",
    "execution.mode": "$execution_mode",
    "total.scripts.executed": $TOTAL_SCRIPTS_EXECUTED,
    "successful.traces": $SUCCESSFUL_TRACES,
    "failed.traces": $FAILED_TRACES
  }
}
EOF
    )
    
    echo "$span_entry" >> "$TELEMETRY_SPANS"
}

# Function to record trace evidence
record_trace_evidence() {
    local script_path="$1"
    local execution_id="$2"
    local status="$3"
    local output="$4"
    
    local evidence_file="$COORDINATION_ROOT/trace_evidence_${ORCHESTRATION_SESSION}.jsonl"
    local evidence_entry=$(cat <<EOF
{
  "orchestration_session": "$ORCHESTRATION_SESSION",
  "master_trace_id": "$MASTER_TRACE_ID",
  "execution_id": "$execution_id",
  "script_path": "$script_path",
  "script_name": "$(basename "$script_path")",
  "execution_status": "$status",
  "timestamp": "$(date -Iseconds)",
  "trace_propagated": $(echo "$output" | grep -q "$MASTER_TRACE_ID" && echo "true" || echo "false"),
  "output_excerpt": "$(echo "$output" | head -3 | tail -1 | sed 's/"/\\"/g')"
}
EOF
    )
    
    echo "$evidence_entry" >> "$evidence_file"
}

# Function to execute scripts in sequential pattern
execute_sequential_pattern() {
    local script_array=("$@")
    local pattern_name="sequential_all_scripts"
    
    trace_log "Executing SEQUENTIAL pattern: $pattern_name (${#script_array[@]} scripts)"
    
    for script_path in "${script_array[@]}"; do
        if [[ -x "$script_path" ]]; then
            execute_script_with_trace "$script_path" "sequential"
            sleep 1  # Brief pause between executions
        fi
    done
    
    success "Sequential pattern completed: ${#script_array[@]} scripts processed"
}

# Function to execute scripts in parallel pattern
execute_parallel_pattern() {
    local script_array=("$@")
    local pattern_name="parallel_batch_execution"
    local max_parallel=5
    
    trace_log "Executing PARALLEL pattern: $pattern_name (${#script_array[@]} scripts, max $max_parallel concurrent)"
    
    local pids=()
    local active_jobs=0
    
    for script_path in "${script_array[@]}"; do
        if [[ -x "$script_path" ]]; then
            # Wait if we've reached max parallel
            while [[ $active_jobs -ge $max_parallel ]]; do
                for i in "${!pids[@]}"; do
                    if ! kill -0 "${pids[i]}" 2>/dev/null; then
                        unset "pids[i]"
                        ((active_jobs--))
                    fi
                done
                sleep 0.1
            done
            
            # Execute script in background
            (execute_script_with_trace "$script_path" "parallel") &
            pids+=($!)
            ((active_jobs++))
        fi
    done
    
    # Wait for all remaining jobs
    for pid in "${pids[@]}"; do
        wait "$pid" 2>/dev/null || true
    done
    
    success "Parallel pattern completed: ${#script_array[@]} scripts processed"
}

# Function to execute scripts in nested pattern
execute_nested_pattern() {
    local script_array=("$@")
    local pattern_name="nested_category_execution"
    
    trace_log "Executing NESTED pattern: $pattern_name by category"
    
    # Execute by category with nesting
    if [[ ${#COORDINATION_SCRIPTS[@]} -gt 0 ]]; then
        trace_log "Nested execution: Coordination scripts (${#COORDINATION_SCRIPTS[@]})"
        for script in "${COORDINATION_SCRIPTS[@]}"; do
            [[ -x "$script" ]] && execute_script_with_trace "$script" "nested_coordination"
        done
    fi
    
    if [[ ${#VALIDATION_SCRIPTS[@]} -gt 0 ]]; then
        trace_log "Nested execution: Validation scripts (${#VALIDATION_SCRIPTS[@]})"
        for script in "${VALIDATION_SCRIPTS[@]}"; do
            [[ -x "$script" ]] && execute_script_with_trace "$script" "nested_validation"
        done
    fi
    
    if [[ ${#BEAMOPS_SCRIPTS[@]} -gt 0 ]]; then
        trace_log "Nested execution: BeamOps scripts (${#BEAMOPS_SCRIPTS[@]})"
        for script in "${BEAMOPS_SCRIPTS[@]}"; do
            [[ -x "$script" ]] && execute_script_with_trace "$script" "nested_beamops"
        done
    fi
    
    success "Nested pattern completed"
}

# Function to execute scripts in random pattern
execute_random_pattern() {
    local script_array=("$@")
    local pattern_name="random_permutation"
    local random_count=$((${#script_array[@]} / 2 + RANDOM % 5))
    
    trace_log "Executing RANDOM pattern: $pattern_name ($random_count random scripts)"
    
    # Create randomized subset
    local shuffled_scripts=()
    local temp_array=("${script_array[@]}")
    
    for ((i=0; i<random_count && ${#temp_array[@]} > 0; i++)); do
        local random_index=$((RANDOM % ${#temp_array[@]}))
        shuffled_scripts+=("${temp_array[random_index]}")
        # Remove selected script from temp array
        temp_array=("${temp_array[@]:0:random_index}" "${temp_array[@]:$((random_index + 1))}")
    done
    
    # Execute randomized scripts
    for script_path in "${shuffled_scripts[@]}"; do
        [[ -x "$script_path" ]] && execute_script_with_trace "$script_path" "random"
        sleep 0.5
    done
    
    success "Random pattern completed: ${#shuffled_scripts[@]} scripts processed"
}

# Function to execute coordination helper with different commands
execute_coordination_commands() {
    local coordination_helper="$COORDINATION_ROOT/coordination_helper.sh"
    
    if [[ -x "$coordination_helper" ]]; then
        trace_log "Executing coordination helper commands with trace propagation"
        
        local commands=("dashboard" "claude-health" "claude-priorities" "claude-teams" "system-status")
        
        for cmd in "${commands[@]}"; do
            trace_log "Coordination command: $cmd"
            execute_script_with_trace "$coordination_helper" "coordination_command" "$cmd"
            sleep 2
        done
    fi
}

# Function to generate execution permutations
generate_execution_permutation() {
    ((PERMUTATION_COUNTER++))
    local permutation_type=$((PERMUTATION_COUNTER % 6))
    
    trace_log "Generating execution permutation #$PERMUTATION_COUNTER (type: $permutation_type)"
    
    case $permutation_type in
        0)
            trace_log "Permutation: Sequential execution of all scripts"
            execute_sequential_pattern "${ALL_EXECUTABLE_SCRIPTS[@]}"
            ;;
        1)
            trace_log "Permutation: Parallel execution of discovered scripts"
            execute_parallel_pattern "${ALL_EXECUTABLE_SCRIPTS[@]}"
            ;;
        2)
            trace_log "Permutation: Nested category-based execution"
            execute_nested_pattern "${ALL_EXECUTABLE_SCRIPTS[@]}"
            ;;
        3)
            trace_log "Permutation: Random script selection and execution"
            execute_random_pattern "${ALL_EXECUTABLE_SCRIPTS[@]}"
            ;;
        4)
            trace_log "Permutation: Coordination-focused execution"
            execute_coordination_commands
            execute_sequential_pattern "${COORDINATION_SCRIPTS[@]}"
            ;;
        5)
            trace_log "Permutation: Mixed parallel and sequential execution"
            execute_parallel_pattern "${VALIDATION_SCRIPTS[@]}"
            sleep 3
            execute_sequential_pattern "${BEAMOPS_SCRIPTS[@]}"
            ;;
    esac
}

# Function to display live orchestration status
display_orchestration_status() {
    echo
    echo "=================================================================================="
    echo -e "${BOLD}${CYAN}🎭 INFINITE TRACE ORCHESTRATOR - LIVE STATUS${NC}"
    echo "=================================================================================="
    echo -e "${BLUE}Master Trace ID:${NC} $MASTER_TRACE_ID"
    echo -e "${BLUE}Orchestration Session:${NC} $ORCHESTRATION_SESSION"
    echo -e "${BLUE}Runtime:${NC} $(( ($(date +%s%N) - ORCHESTRATION_START_TIME) / 1000000000 )) seconds"
    echo -e "${BLUE}Current Time:${NC} $(date)"
    echo
    echo -e "${CYAN}📊 EXECUTION STATISTICS:${NC}"
    echo "  Permutations Executed: $PERMUTATION_COUNTER"
    echo "  Total Script Executions: $EXECUTION_COUNTER"
    echo "  Scripts Successfully Executed: $TOTAL_SCRIPTS_EXECUTED"
    echo "  Successful Traces: $SUCCESSFUL_TRACES"
    echo "  Failed Traces: $FAILED_TRACES"
    
    local success_rate=0
    if [[ $EXECUTION_COUNTER -gt 0 ]]; then
        success_rate=$(( SUCCESSFUL_TRACES * 100 / EXECUTION_COUNTER ))
    fi
    echo "  Success Rate: ${success_rate}%"
    echo
    echo -e "${CYAN}🔍 DISCOVERED SCRIPTS:${NC}"
    echo "  Coordination Scripts: ${#COORDINATION_SCRIPTS[@]}"
    echo "  BeamOps Scripts: ${#BEAMOPS_SCRIPTS[@]}"
    echo "  Validation Scripts: ${#VALIDATION_SCRIPTS[@]}"
    echo "  System Scripts: ${#SYSTEM_SCRIPTS[@]}"
    echo "  Deployment Scripts: ${#DEPLOYMENT_SCRIPTS[@]}"
    echo "  Total Scripts: ${#ALL_EXECUTABLE_SCRIPTS[@]}"
    echo
    
    # Show recent trace evidence
    local evidence_file="$COORDINATION_ROOT/trace_evidence_${ORCHESTRATION_SESSION}.jsonl"
    if [[ -f "$evidence_file" ]]; then
        local trace_verified_count=$(grep -c '"trace_propagated": true' "$evidence_file" 2>/dev/null || echo "0")
        echo -e "${CYAN}🔗 TRACE PROPAGATION:${NC}"
        echo "  Scripts with Verified Trace Propagation: $trace_verified_count"
        
        if [[ $trace_verified_count -gt 0 ]]; then
            echo "  Recent Verified Scripts:"
            grep '"trace_propagated": true' "$evidence_file" | tail -3 | jq -r '."script_name"' 2>/dev/null | sed 's/^/    - /' || echo "    - (JSON parsing unavailable)"
        fi
    fi
    
    echo "=================================================================================="
    echo
}

# Function to validate trace continuity across all executions
validate_trace_continuity() {
    trace_log "Validating trace continuity across all executions..."
    
    local evidence_file="$COORDINATION_ROOT/trace_evidence_${ORCHESTRATION_SESSION}.jsonl"
    local coordination_file="$COORDINATION_ROOT/work_claims.json"
    local telemetry_file="$TELEMETRY_SPANS"
    
    local trace_locations=0
    
    # Check evidence file
    if [[ -f "$evidence_file" ]] && grep -q "$MASTER_TRACE_ID" "$evidence_file" 2>/dev/null; then
        ((trace_locations++))
        success "Master trace ID found in execution evidence"
    fi
    
    # Check coordination file
    if [[ -f "$coordination_file" ]] && grep -q "$MASTER_TRACE_ID" "$coordination_file" 2>/dev/null; then
        ((trace_locations++))
        success "Master trace ID found in coordination system"
    fi
    
    # Check telemetry file
    if [[ -f "$telemetry_file" ]] && grep -q "$MASTER_TRACE_ID" "$telemetry_file" 2>/dev/null; then
        ((trace_locations++))
        local span_count=$(grep -c "$MASTER_TRACE_ID" "$telemetry_file" 2>/dev/null || echo "0")
        success "Master trace ID found in telemetry ($span_count spans)"
    fi
    
    trace_log "Trace continuity validation: $trace_locations/3 systems contain master trace ID"
    
    # Record validation span
    local validation_span=$(openssl rand -hex 8)
    record_orchestration_span "trace_continuity_validation" "$validation_span" "validation" "continuous"
    
    return 0
}

# Main infinite orchestration loop
infinite_orchestration_loop() {
    log "Starting infinite trace orchestration loop..."
    log "Master Trace ID: $MASTER_TRACE_ID"
    log "Session: $ORCHESTRATION_SESSION"
    
    local loop_iteration=0
    local discovery_interval=10  # Rediscover scripts every 10 iterations
    
    while true; do
        ((loop_iteration++))
        
        trace_log "=== LOOP ITERATION $loop_iteration ==="
        
        # Periodic script rediscovery
        if (( loop_iteration % discovery_interval == 1 )); then
            discover_all_scripts
        fi
        
        # Generate and execute a new permutation
        generate_execution_permutation
        
        # Validate trace continuity
        validate_trace_continuity
        
        # Display status every iteration
        display_orchestration_status
        
        # Brief pause between iterations
        trace_log "Completed iteration $loop_iteration. Pausing before next permutation..."
        sleep 5
        
        # Occasionally regenerate master trace ID for variety (every 20 iterations)
        if (( loop_iteration % 20 == 0 )); then
            local old_trace_id="$MASTER_TRACE_ID"
            MASTER_TRACE_ID=$(openssl rand -hex 16)
            trace_log "Regenerated master trace ID: $old_trace_id → $MASTER_TRACE_ID"
            
            # Update environment
            export ORCHESTRATOR_TRACE_ID="$MASTER_TRACE_ID"
            export OTEL_TRACE_ID="$MASTER_TRACE_ID"
        fi
    done
}

# Signal handlers for graceful shutdown
cleanup_orchestration() {
    echo
    log "Received shutdown signal. Performing graceful cleanup..."
    
    # Final status report
    display_orchestration_status
    
    # Record final orchestration span
    local final_span=$(openssl rand -hex 8)
    record_orchestration_span "orchestration_shutdown" "$final_span" "orchestrator" "cleanup"
    
    log "Infinite trace orchestration stopped gracefully."
    log "Total runtime: $(( ($(date +%s%N) - ORCHESTRATION_START_TIME) / 1000000000 )) seconds"
    log "Final statistics: $PERMUTATION_COUNTER permutations, $EXECUTION_COUNTER executions, $SUCCESSFUL_TRACES successful traces"
    
    exit 0
}

trap cleanup_orchestration SIGINT SIGTERM

# Main execution
main() {
    echo
    echo "=================================================================================="
    echo -e "${BOLD}${PURPLE}🎭 INFINITE TRACE ORCHESTRATOR${NC}"
    echo -e "${BOLD}${PURPLE}   Ultimate Distributed Tracing Validation System${NC}"
    echo "=================================================================================="
    echo
    
    log "Initializing infinite trace orchestration..."
    
    # Ensure required directories exist
    mkdir -p "$COORDINATION_ROOT"
    touch "$TELEMETRY_SPANS"
    
    # Set global trace environment
    export ORCHESTRATOR_TRACE_ID="$MASTER_TRACE_ID"
    export OTEL_TRACE_ID="$MASTER_TRACE_ID"
    
    # Initial script discovery
    discover_all_scripts
    
    if [[ ${#ALL_EXECUTABLE_SCRIPTS[@]} -eq 0 ]]; then
        error "No executable scripts discovered. Cannot proceed with orchestration."
        exit 1
    fi
    
    log "Orchestration initialization complete."
    log "Discovered ${#ALL_EXECUTABLE_SCRIPTS[@]} executable scripts across the system."
    log "Starting infinite orchestration loop with continuous trace validation..."
    echo
    
    # Start the infinite loop
    infinite_orchestration_loop
}

# Dependency checks
for cmd in openssl jq timeout; do
    if ! command -v "$cmd" &> /dev/null; then
        error "$cmd is required but not installed. Please install $cmd first."
        exit 1
    fi
done

# Execute main orchestration
main "$@"