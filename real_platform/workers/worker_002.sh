#!/bin/bash
# Real Worker Process
WORKER_ID="$1"
WORK_TYPE="$2"
METRICS_DIR="$3"

while true; do
    start_time=$(date +%s%N)
    
    # Do actual work (example: file processing, API calls, data processing)
    case "$WORK_TYPE" in
        "file_processor")
            # Real file processing work
            find /tmp -name "*.log" -mtime -1 | head -10 | while read file; do
                wc -l "$file" >> "$METRICS_DIR/processed_files.log"
            done
            ;;
        "api_monitor")
            # Real API monitoring work
            curl -s -o /dev/null -w "%{http_code}\n" http://localhost:3000 >> "$METRICS_DIR/api_health.log" 2>/dev/null || echo "000" >> "$METRICS_DIR/api_health.log"
            ;;
        "system_monitor")
            # Real system monitoring
            ps aux | wc -l >> "$METRICS_DIR/process_count.log"
            df -h | grep -E "/$" | awk '{print $5}' >> "$METRICS_DIR/disk_usage.log"
            ;;
        *)
            # Default work - system info collection
            date +%s >> "$METRICS_DIR/heartbeat.log"
            ;;
    esac
    
    end_time=$(date +%s%N)
    duration_ms=$(((end_time - start_time) / 1000000))
    
    # Record real performance metrics
    echo "$(date +%s),${WORKER_ID},${WORK_TYPE},${duration_ms}" >> "$METRICS_DIR/performance.csv"
    
    sleep 5  # Real work interval
done
