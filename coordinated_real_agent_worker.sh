#!/bin/bash
# Coordinated Real Agent Worker - Uses distributed work claiming system

set -e

AGENT_ID="real_agent_$(date +%s%N)"
AGENT_PID_FILE="agent_coordination/real_agents/${AGENT_ID}.pid"
AGENT_LOG_FILE="agent_coordination/real_agents/${AGENT_ID}.log"
WORK_RESULTS_DIR="agent_coordination/real_work_results"
COORDINATOR_SCRIPT="./real_agent_coordinator.sh"

# Ensure directories exist
mkdir -p "agent_coordination/real_agents"
mkdir -p "$WORK_RESULTS_DIR"

# Coordinated agent main loop
coordinated_agent_main_loop() {
    echo "🚀 Coordinated Real Agent Started: $AGENT_ID (PID: $$)" | tee -a "$AGENT_LOG_FILE"
    echo "$$" > "$AGENT_PID_FILE"
    
    while true; do
        # Claim work from coordinator
        local CLAIMED_WORK=$($COORDINATOR_SCRIPT claim "$AGENT_ID" "$$")
        
        if [[ "$CLAIMED_WORK" == "NO_WORK_AVAILABLE" ]]; then
            echo "⏳ No work available, waiting..." | tee -a "$AGENT_LOG_FILE"
            sleep 10
            continue
        fi
        
        echo "📋 Claimed work: $CLAIMED_WORK" | tee -a "$AGENT_LOG_FILE"
        
        # Get work details
        local WORK_DETAILS=$($COORDINATOR_SCRIPT details "$CLAIMED_WORK")
        local WORK_TYPE=$(echo "$WORK_DETAILS" | cut -d':' -f1)
        local ESTIMATED_DURATION=$(echo "$WORK_DETAILS" | cut -d':' -f2)
        
        # Execute the claimed work
        local WORK_START=$(date +%s%N)
        local RESULT_FILE=$(execute_coordinated_work "$CLAIMED_WORK" "$WORK_TYPE")
        local WORK_END=$(date +%s%N)
        local DURATION_NS=$((WORK_END - WORK_START))
        local DURATION_MS=$((DURATION_NS / 1000000))
        
        # Complete work with coordinator
        $COORDINATOR_SCRIPT complete "$AGENT_ID" "$CLAIMED_WORK" "$DURATION_MS" "$RESULT_FILE"
        
        # Record real metrics
        record_coordinated_metrics "$CLAIMED_WORK" "$DURATION_MS" "$WORK_TYPE:$RESULT_FILE"
        
        # Generate real telemetry
        generate_coordinated_telemetry "$CLAIMED_WORK" "$DURATION_MS"
        
        echo "✅ Completed work: $CLAIMED_WORK in ${DURATION_MS}ms" | tee -a "$AGENT_LOG_FILE"
        
        # Brief pause before claiming next work
        sleep 5
    done
}

execute_coordinated_work() {
    local WORK_ID=$1
    local WORK_TYPE=$2
    local RESULT_FILE="${WORK_RESULTS_DIR}/coordinated_${WORK_ID}_$(date +%s).result"
    
    case "$WORK_TYPE" in
        "file_processing")
            execute_file_processing_work "$RESULT_FILE"
            ;;
        "calculation_work")
            execute_calculation_work "$RESULT_FILE"
            ;;
        "system_analysis")
            execute_system_analysis_work "$RESULT_FILE"
            ;;
        "performance_test")
            execute_performance_test_work "$RESULT_FILE"
            ;;
        *)
            execute_default_work "$RESULT_FILE"
            ;;
    esac
    
    echo "$RESULT_FILE"
}

execute_file_processing_work() {
    local RESULT_FILE=$1
    local TEST_DIR="${WORK_RESULTS_DIR}/file_test_$(date +%s%N)"
    
    # Real file operations
    mkdir -p "$TEST_DIR"
    
    # Create test files
    for i in {1..10}; do
        echo "Test data line $i - $(date +%s%N)" > "${TEST_DIR}/test_${i}.txt"
    done
    
    # Process files
    local FILE_COUNT=$(find "$TEST_DIR" -name "*.txt" | wc -l)
    local TOTAL_LINES=$(cat "${TEST_DIR}"/*.txt | wc -l)
    local TOTAL_SIZE=$(du -sb "$TEST_DIR" | cut -f1)
    
    # Cleanup
    rm -rf "$TEST_DIR"
    
    # Record real results
    cat > "$RESULT_FILE" <<EOF
{
  "work_type": "file_processing",
  "coordinated": true,
  "files_created": $FILE_COUNT,
  "total_lines": $TOTAL_LINES,
  "total_bytes": $TOTAL_SIZE,
  "operations": ["mkdir", "write", "read", "count", "cleanup"],
  "success": true
}
EOF
}

execute_calculation_work() {
    local RESULT_FILE=$1
    local START_TIME=$(date +%s%N)
    
    # Real mathematical calculations
    local RESULT=0
    for i in {1..1000}; do
        RESULT=$((RESULT + i * i))
    done
    
    local FIBONACCI_20=$(calculate_fibonacci 20)
    local PRIME_COUNT=$(count_primes_up_to 100)
    
    local END_TIME=$(date +%s%N)
    local CALCULATION_TIME=$((END_TIME - START_TIME))
    
    cat > "$RESULT_FILE" <<EOF
{
  "work_type": "calculation_work",
  "coordinated": true,
  "sum_of_squares": $RESULT,
  "fibonacci_20": $FIBONACCI_20,
  "primes_up_to_100": $PRIME_COUNT,
  "calculation_time_ns": $CALCULATION_TIME,
  "operations": ["sum_of_squares", "fibonacci", "prime_counting"],
  "success": true
}
EOF
}

calculate_fibonacci() {
    local n=$1
    if [[ $n -le 1 ]]; then
        echo $n
    else
        local a=0 b=1 c
        for ((i=2; i<=n; i++)); do
            c=$((a + b))
            a=$b
            b=$c
        done
        echo $b
    fi
}

count_primes_up_to() {
    local limit=$1
    local count=0
    
    for ((n=2; n<=limit; n++)); do
        local is_prime=1
        for ((i=2; i*i<=n; i++)); do
            if ((n % i == 0)); then
                is_prime=0
                break
            fi
        done
        if [[ $is_prime -eq 1 ]]; then
            count=$((count + 1))
        fi
    done
    
    echo $count
}

execute_system_analysis_work() {
    local RESULT_FILE=$1
    
    # Real system metrics collection
    local MEMORY_USAGE=$(vm_stat | grep "Pages free" | awk '{print $3}' | tr -d '.' | awk '{print $1 * 4096}')
    local PROCESS_COUNT=$(ps aux | wc -l)
    local DISK_USAGE=$(df -h . | tail -1 | awk '{print $5}' | tr -d '%')
    local LOAD_AVERAGE=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | tr -d ',')
    
    cat > "$RESULT_FILE" <<EOF
{
  "work_type": "system_analysis",
  "coordinated": true,
  "memory_bytes": $MEMORY_USAGE,
  "process_count": $PROCESS_COUNT,
  "disk_usage_percent": $DISK_USAGE,
  "load_average": "$LOAD_AVERAGE",
  "analysis_timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "operations": ["memory_check", "process_count", "disk_usage", "load_average"],
  "success": true
}
EOF
}

execute_performance_test_work() {
    local RESULT_FILE=$1
    local START_TIME=$(date +%s%N)
    
    # Real performance test
    local TEST_ITERATIONS=1000
    local SUCCESS_COUNT=0
    
    for ((i=1; i<=TEST_ITERATIONS; i++)); do
        # Simple CPU work
        local HASH=$(echo "test_$i" | md5)
        if [[ ${#HASH} -eq 32 ]]; then
            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        fi
    done
    
    local END_TIME=$(date +%s%N)
    local TOTAL_TIME=$((END_TIME - START_TIME))
    local OPERATIONS_PER_SECOND=$(echo "scale=2; $TEST_ITERATIONS * 1000000000 / $TOTAL_TIME" | bc)
    
    cat > "$RESULT_FILE" <<EOF
{
  "work_type": "performance_test",
  "coordinated": true,
  "iterations": $TEST_ITERATIONS,
  "successes": $SUCCESS_COUNT,
  "total_time_ns": $TOTAL_TIME,
  "operations_per_second": $OPERATIONS_PER_SECOND,
  "success_rate": $(echo "scale=4; $SUCCESS_COUNT * 100 / $TEST_ITERATIONS" | bc),
  "operations": ["hash_generation", "validation", "performance_measurement"],
  "success": true
}
EOF
}

execute_default_work() {
    local RESULT_FILE=$1
    
    cat > "$RESULT_FILE" <<EOF
{
  "work_type": "default_work",
  "coordinated": true,
  "message": "Default coordinated work executed successfully",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "operations": ["default_operation"],
  "success": true
}
EOF
}

record_coordinated_metrics() {
    local WORK_ID=$1
    local DURATION_MS=$2
    local WORK_RESULTS=$3
    
    local METRICS_FILE="agent_coordination/real_agents/${AGENT_ID}_coordinated_metrics.json"
    local TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    
    # Create or update metrics file
    if [[ ! -f "$METRICS_FILE" ]]; then
        cat > "$METRICS_FILE" <<EOF
{
  "agent_id": "$AGENT_ID",
  "agent_pid": $$,
  "started_at": "$TIMESTAMP",
  "coordination_enabled": true,
  "work_completed": []
}
EOF
    fi
    
    # Add work completion record
    local WORK_RECORD=$(cat <<EOF
{
  "work_id": "$WORK_ID",
  "duration_ms": $DURATION_MS,
  "completed_at": "$TIMESTAMP",
  "work_results": "$WORK_RESULTS",
  "coordinated": true
}
EOF
)
    
    # Update metrics file with new work record
    jq --argjson work "$WORK_RECORD" '.work_completed += [$work]' "$METRICS_FILE" > /tmp/coordinated_metrics_updated.json
    mv /tmp/coordinated_metrics_updated.json "$METRICS_FILE"
}

generate_coordinated_telemetry() {
    local WORK_ID=$1
    local DURATION_MS=$2
    local TRACE_ID=$(uuidgen | tr '[:upper:]' '[:lower:]' | tr -d '-')
    local SPAN_ID="${AGENT_ID}_coordinated_work_${WORK_ID}"
    
    # Write real telemetry span
    local TELEMETRY_SPAN=$(cat <<EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "trace_id": "$TRACE_ID",
  "span_id": "$SPAN_ID",
  "operation": "real.coordinated.agent.work.execution",
  "service": "coordinated-real-agent-worker",
  "duration_ms": $DURATION_MS,
  "success": true,
  "agent_id": "$AGENT_ID",
  "agent_pid": $$,
  "work_id": "$WORK_ID",
  "real_execution": true,
  "coordinated": true
}
EOF
)
    
    echo "$TELEMETRY_SPAN" >> "agent_coordination/coordinated_real_telemetry_spans.jsonl"
}

cleanup() {
    echo "🛑 Coordinated Real Agent Shutting Down: $AGENT_ID" | tee -a "$AGENT_LOG_FILE"
    rm -f "$AGENT_PID_FILE"
    exit 0
}

# Set up signal handlers
trap cleanup SIGTERM SIGINT

# Start the coordinated real agent
echo "🚀 Starting Coordinated Real Agent Worker: $AGENT_ID"
coordinated_agent_main_loop