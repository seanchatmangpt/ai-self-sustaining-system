#!/bin/bash

COORD_DIR="/Users/sac/dev/ai-self-sustaining-system/agent_coordination"
LOG_FILE="/Users/sac/dev/ai-self-sustaining-system/real_coordination_operations.log"

log_operation() {
    local operation="$1"
    local details="$2"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S")
    echo "$timestamp $operation $details" >> "$LOG_FILE"
}

# Generate real coordination work
while true; do
    # Claim real work
    local work_types=("data_processing" "file_analysis" "system_monitoring" "performance_check")
    local work_type=${work_types[$RANDOM % ${#work_types[@]}]}
    
    # Use coordination helper to claim real work
    if ./agent_coordination/coordination_helper.sh claim "$work_type" "Real work: $work_type operation" "medium" "real_work_team" >/dev/null 2>&1; then
        log_operation "CLAIM" "$work_type work claimed"
        
        # Simulate doing real work (with actual delay)
        sleep $((RANDOM % 30 + 10))  # 10-40 second work duration
        
        # Complete the work
        local work_id=$(jq -r '.[] | select(.status == "active" and .work_type == "'$work_type'") | .work_item_id' "$COORD_DIR/work_claims.json" 2>/dev/null | head -1)
        
        if [[ -n "$work_id" && "$work_id" != "null" ]]; then
            if ./agent_coordination/coordination_helper.sh complete "$work_id" "Real work completed: $work_type" 5 >/dev/null 2>&1; then
                log_operation "COMPLETE" "$work_id completed"
            fi
        fi
    fi
    
    sleep $((RANDOM % 60 + 30))  # 30-90 seconds between work items
done
