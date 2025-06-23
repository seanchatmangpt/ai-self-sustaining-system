#!/bin/bash

# Real Agent Coordinator - Implements distributed work claiming for real agents
# This replaces the synthetic JSON coordination with actual process coordination

COORD_DIR="agent_coordination"
WORK_QUEUE_FILE="$COORD_DIR/real_work_queue.json"
WORK_CLAIMS_FILE="$COORD_DIR/real_work_claims.json"
COORDINATOR_LOG="$COORD_DIR/coordinator_operations.log"

# Ensure coordination directory exists
mkdir -p "$COORD_DIR"

# Initialize work queue if it doesn't exist
initialize_work_queue() {
    if [[ ! -f "$WORK_QUEUE_FILE" ]]; then
        cat > "$WORK_QUEUE_FILE" <<EOF
{
  "work_items": [
    {
      "work_id": "distributed_trace_validation",
      "priority": "high",
      "estimated_duration_ms": 2500,
      "work_type": "performance_test",
      "status": "available",
      "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    },
    {
      "work_id": "system_health_analysis",
      "priority": "medium",
      "estimated_duration_ms": 150,
      "work_type": "system_analysis",
      "status": "available",
      "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    },
    {
      "work_id": "memory_optimization_check",
      "priority": "medium",
      "estimated_duration_ms": 75,
      "work_type": "calculation_work",
      "status": "available",
      "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    },
    {
      "work_id": "coordination_telemetry_analysis",
      "priority": "high",
      "estimated_duration_ms": 300,
      "work_type": "file_processing",
      "status": "available",
      "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    },
    {
      "work_id": "agent_performance_benchmarking",
      "priority": "high",
      "estimated_duration_ms": 2000,
      "work_type": "performance_test",
      "status": "available",
      "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    }
  ]
}
EOF
        log_operation "INIT" "Work queue initialized with 5 available work items"
    fi
}

# Initialize work claims file
initialize_work_claims() {
    if [[ ! -f "$WORK_CLAIMS_FILE" ]]; then
        echo '{"active_claims": []}' > "$WORK_CLAIMS_FILE"
        log_operation "INIT" "Work claims file initialized"
    fi
}

# Logging function
log_operation() {
    local OPERATION=$1
    local MESSAGE=$2
    local TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    echo "[$TIMESTAMP] [$OPERATION] $MESSAGE" >> "$COORDINATOR_LOG"
}

# Atomic work claiming using file locking
claim_work() {
    local AGENT_ID=$1
    local AGENT_PID=$2
    
    # Use flock for atomic operations
    (
        flock -x 200
        
        # Read current work queue
        local AVAILABLE_WORK=$(cat "$WORK_QUEUE_FILE" | jq -r '.work_items[] | select(.status == "available") | .work_id' | head -1)
        
        if [[ -z "$AVAILABLE_WORK" ]]; then
            log_operation "CLAIM_FAILED" "Agent $AGENT_ID (PID: $AGENT_PID) - No available work"
            echo "NO_WORK_AVAILABLE"
            return 1
        fi
        
        # Update work status to claimed
        local TEMP_FILE=$(mktemp)
        cat "$WORK_QUEUE_FILE" | jq --arg work_id "$AVAILABLE_WORK" --arg agent_id "$AGENT_ID" --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '
            .work_items = (.work_items | map(
                if .work_id == $work_id then
                    . + {"status": "claimed", "claimed_by": $agent_id, "claimed_at": $timestamp}
                else
                    .
                end
            ))
        ' > "$TEMP_FILE" && mv "$TEMP_FILE" "$WORK_QUEUE_FILE"
        
        # Add to active claims
        local TEMP_CLAIMS=$(mktemp)
        cat "$WORK_CLAIMS_FILE" | jq --arg work_id "$AVAILABLE_WORK" --arg agent_id "$AGENT_ID" --arg agent_pid "$AGENT_PID" --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '
            .active_claims += [{
                "work_id": $work_id,
                "agent_id": $agent_id,
                "agent_pid": ($agent_pid | tonumber),
                "claimed_at": $timestamp,
                "status": "in_progress"
            }]
        ' > "$TEMP_CLAIMS" && mv "$TEMP_CLAIMS" "$WORK_CLAIMS_FILE"
        
        log_operation "CLAIM_SUCCESS" "Agent $AGENT_ID (PID: $AGENT_PID) claimed work: $AVAILABLE_WORK"
        echo "$AVAILABLE_WORK"
        
    ) 200>"$WORK_QUEUE_FILE.lock"
}

# Complete work and release claim
complete_work() {
    local AGENT_ID=$1
    local WORK_ID=$2
    local DURATION_MS=$3
    local RESULT_FILE=$4
    
    (
        flock -x 200
        
        # Update work status to completed
        local TEMP_FILE=$(mktemp)
        cat "$WORK_QUEUE_FILE" | jq --arg work_id "$WORK_ID" --arg duration "$DURATION_MS" --arg result "$RESULT_FILE" --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '
            .work_items = (.work_items | map(
                if .work_id == $work_id then
                    . + {"status": "completed", "completed_at": $timestamp, "actual_duration_ms": ($duration | tonumber), "result_file": $result}
                else
                    .
                end
            ))
        ' > "$TEMP_FILE" && mv "$TEMP_FILE" "$WORK_QUEUE_FILE"
        
        # Remove from active claims
        local TEMP_CLAIMS=$(mktemp)
        cat "$WORK_CLAIMS_FILE" | jq --arg work_id "$WORK_ID" '
            .active_claims = (.active_claims | map(select(.work_id != $work_id)))
        ' > "$TEMP_CLAIMS" && mv "$TEMP_CLAIMS" "$WORK_CLAIMS_FILE"
        
        log_operation "COMPLETE_SUCCESS" "Agent $AGENT_ID completed work: $WORK_ID (${DURATION_MS}ms)"
        
    ) 200>"$WORK_QUEUE_FILE.lock"
}

# Get work details for execution
get_work_details() {
    local WORK_ID=$1
    cat "$WORK_QUEUE_FILE" | jq -r --arg work_id "$WORK_ID" '.work_items[] | select(.work_id == $work_id) | "\(.work_type):\(.estimated_duration_ms)"'
}

# Monitor coordination status
monitor_coordination() {
    local TOTAL_WORK=$(cat "$WORK_QUEUE_FILE" | jq '.work_items | length')
    local AVAILABLE_WORK=$(cat "$WORK_QUEUE_FILE" | jq '.work_items | map(select(.status == "available")) | length')
    local CLAIMED_WORK=$(cat "$WORK_QUEUE_FILE" | jq '.work_items | map(select(.status == "claimed")) | length')
    local COMPLETED_WORK=$(cat "$WORK_QUEUE_FILE" | jq '.work_items | map(select(.status == "completed")) | length')
    local ACTIVE_AGENTS=$(cat "$WORK_CLAIMS_FILE" | jq '.active_claims | length')
    
    echo "=== REAL AGENT COORDINATION STATUS ==="
    echo "Total Work Items: $TOTAL_WORK"
    echo "Available: $AVAILABLE_WORK | In Progress: $CLAIMED_WORK | Completed: $COMPLETED_WORK"
    echo "Active Agent Claims: $ACTIVE_AGENTS"
    echo "======================================"
    
    log_operation "MONITOR" "Status - Total:$TOTAL_WORK Available:$AVAILABLE_WORK InProgress:$CLAIMED_WORK Completed:$COMPLETED_WORK ActiveAgents:$ACTIVE_AGENTS"
}

# Add new work to queue
add_work() {
    local WORK_ID=$1
    local PRIORITY=$2
    local WORK_TYPE=$3
    local ESTIMATED_DURATION=$4
    
    (
        flock -x 200
        
        local TEMP_FILE=$(mktemp)
        cat "$WORK_QUEUE_FILE" | jq --arg work_id "$WORK_ID" --arg priority "$PRIORITY" --arg work_type "$WORK_TYPE" --arg duration "$ESTIMATED_DURATION" --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '
            .work_items += [{
                "work_id": $work_id,
                "priority": $priority,
                "estimated_duration_ms": ($duration | tonumber),
                "work_type": $work_type,
                "status": "available",
                "created_at": $timestamp
            }]
        ' > "$TEMP_FILE" && mv "$TEMP_FILE" "$WORK_QUEUE_FILE"
        
        log_operation "ADD_WORK" "Added work: $WORK_ID ($WORK_TYPE, ${ESTIMATED_DURATION}ms)"
        
    ) 200>"$WORK_QUEUE_FILE.lock"
}

# Main coordination operations
case "$1" in
    "init")
        initialize_work_queue
        initialize_work_claims
        monitor_coordination
        ;;
    "claim")
        claim_work "$2" "$3"
        ;;
    "complete")
        complete_work "$2" "$3" "$4" "$5"
        ;;
    "details")
        get_work_details "$2"
        ;;
    "monitor")
        monitor_coordination
        ;;
    "add")
        add_work "$2" "$3" "$4" "$5"
        ;;
    *)
        echo "Usage: $0 {init|claim|complete|details|monitor|add}"
        echo "  init                              - Initialize coordination system"
        echo "  claim <agent_id> <agent_pid>      - Claim available work"
        echo "  complete <agent_id> <work_id> <duration_ms> <result_file> - Complete work"
        echo "  details <work_id>                 - Get work execution details"
        echo "  monitor                           - Show coordination status"
        echo "  add <work_id> <priority> <work_type> <duration_ms> - Add new work"
        exit 1
        ;;
esac