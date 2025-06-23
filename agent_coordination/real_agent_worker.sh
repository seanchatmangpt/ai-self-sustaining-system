#!/bin/bash
# Real Agent Worker Process
AGENT_ID="$1"
WORK_TYPE="$2"

while true; do
    # Check for work
    work=$(jq -r ".[] | select(.assigned_to == \"$AGENT_ID\" and .status == \"pending\") | .id" ../work_claims.json 2>/dev/null | head -1)
    
    if [[ -n "$work" ]]; then
        # Update to active
        ./coordination_helper.sh progress "$work" "active" >/dev/null 2>&1
        
        # Simulate real work
        sleep $((RANDOM % 5 + 1))
        
        # Complete work
        ./coordination_helper.sh complete "$work" "Completed by real agent $AGENT_ID" >/dev/null 2>&1
        
        echo "[$(date '+%H:%M:%S')] Agent $AGENT_ID completed work: $work"
    fi
    
    sleep 2
done
