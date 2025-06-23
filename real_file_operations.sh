#!/bin/bash

WORK_DIR="/Users/sac/dev/ai-self-sustaining-system/file_operations_workspace"
LOG_FILE="/Users/sac/dev/ai-self-sustaining-system/real_file_operations.log"

# Create workspace
mkdir -p "$WORK_DIR"

log_operation() {
    local operation="$1"
    local details="$2"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S")
    echo "$timestamp $operation $details" >> "$LOG_FILE"
}

# Continuous file operations
while true; do
    # Create files
    for i in {1..5}; do
        local filename="$WORK_DIR/data_$(date +%s)_$i.txt"
        echo "Real data created at $(date)" > "$filename"
        log_operation "CREATE" "$filename"
    done
    
    # Read and process files
    for file in "$WORK_DIR"/*.txt; do
        if [[ -f "$file" ]]; then
            local content=$(cat "$file" 2>/dev/null)
            local word_count=$(echo "$content" | wc -w)
            log_operation "READ" "$file ($word_count words)"
            
            # Modify file
            echo "Processed at $(date)" >> "$file"
            log_operation "UPDATE" "$file"
        fi
    done
    
    # Clean old files (keep workspace manageable)
    find "$WORK_DIR" -name "*.txt" -mmin +10 -delete 2>/dev/null || true
    log_operation "CLEANUP" "Removed old files"
    
    sleep 30  # Operations every 30 seconds
done
