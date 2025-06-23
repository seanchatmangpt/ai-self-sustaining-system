#!/bin/bash

# 80/20 FIX: Telemetry Parsing - Fix the 20% causing 80% of data extraction failures
# Convert multi-line JSON to proper JSONL format for reliable parsing

set -euo pipefail

readonly TELEMETRY_FILE="/Users/sac/dev/ai-self-sustaining-system/agent_coordination/telemetry_spans.jsonl"
readonly FIXED_TELEMETRY="/tmp/telemetry_fixed_$(date +%s).jsonl"
readonly FIX_REPORT="/tmp/telemetry_fix_report_$(date +%s).json"

log_fix() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [TELEMETRY-FIX] $*"
}

# 80/20 FIX 1: Convert multi-line JSON to single-line JSONL
fix_telemetry_format() {
    log_fix "🔧 FIXING: Converting multi-line JSON to JSONL format"
    
    if [[ ! -f "${TELEMETRY_FILE}" ]]; then
        log_fix "❌ ERROR: Telemetry file not found"
        return 1
    fi
    
    # Convert multi-line JSON objects to single lines
    # This uses jq to compact each JSON object to one line
    local json_objects=0
    local successful_conversions=0
    
    # Split file into individual JSON objects and compact them
    awk '/{/{p++} p; /}/{if(--p==0){print ""; next}}' "${TELEMETRY_FILE}" | while IFS= read -r line; do
        if [[ -n "${line}" ]]; then
            echo "${line}" | jq -c . 2>/dev/null >> "${FIXED_TELEMETRY}" && ((successful_conversions++)) || true
            ((json_objects++))
        fi
    done
    
    log_fix "✅ FIXED: Converted JSON objects to JSONL format"
    log_fix "📊 Original objects: ${json_objects}"
    log_fix "📊 Successfully converted: ${successful_conversions}"
    
    echo "${FIXED_TELEMETRY}"
}

# 80/20 FIX 2: Extract actual telemetry metrics with proper parsing
extract_telemetry_metrics() {
    local fixed_file="$1"
    
    log_fix "📊 EXTRACTING: Real telemetry metrics from fixed data"
    
    if [[ ! -f "${fixed_file}" ]]; then
        log_fix "❌ ERROR: Fixed telemetry file not found"
        return 1
    fi
    
    # Extract actual metrics using proper JSON parsing
    local total_spans=$(wc -l < "${fixed_file}")
    local unique_trace_ids=$(jq -r '.trace_id' "${fixed_file}" | sort -u | wc -l)
    local error_spans=$(jq -r 'select(.status == "error") | .trace_id' "${fixed_file}" | wc -l)
    local success_spans=$(jq -r 'select(.status == "ok") | .trace_id' "${fixed_file}" | wc -l)
    local unique_services=$(jq -r '.service.name // .resource_attributes."service.name" // "unknown"' "${fixed_file}" | sort -u | wc -l)
    
    # Calculate error rate
    local error_rate=0
    if [[ ${total_spans} -gt 0 ]]; then
        error_rate=$(echo "scale=2; ${error_spans} * 100 / ${total_spans}" | bc -l)
    fi
    
    # Calculate average duration
    local avg_duration=$(jq -r '.duration_ms // 0' "${fixed_file}" | awk '{sum+=$1; count++} END {if(count>0) print sum/count; else print 0}')
    
    # Extract service names
    local service_names=$(jq -r '.service.name // .resource_attributes."service.name" // "unknown"' "${fixed_file}" | sort -u | head -5 | tr '\n' ',' | sed 's/,$//')
    
    log_fix "📊 REAL TELEMETRY METRICS EXTRACTED:"
    log_fix "  Total Spans: ${total_spans}"
    log_fix "  Unique Trace IDs: ${unique_trace_ids}"
    log_fix "  Error Spans: ${error_spans}"
    log_fix "  Success Spans: ${success_spans}"
    log_fix "  Error Rate: ${error_rate}%"
    log_fix "  Average Duration: ${avg_duration}ms"
    log_fix "  Unique Services: ${unique_services}"
    log_fix "  Service Names: ${service_names}"
    
    # Generate fix report with actual metrics
    cat > "${FIX_REPORT}" << EOF
{
  "telemetry_fix_report": {
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)",
    "fix_type": "80_20_telemetry_parsing_fix",
    "original_file": "${TELEMETRY_FILE}",
    "fixed_file": "${fixed_file}",
    "real_metrics": {
      "total_spans": ${total_spans},
      "unique_trace_ids": ${unique_trace_ids},
      "error_spans": ${error_spans},
      "success_spans": ${success_spans},
      "error_rate_percent": ${error_rate},
      "average_duration_ms": ${avg_duration},
      "unique_services": ${unique_services},
      "service_names": "${service_names}"
    },
    "fix_validation": {
      "parsing_successful": $(if [[ ${unique_trace_ids} -gt 0 ]]; then echo "true"; else echo "false"; fi),
      "data_extracted": $(if [[ ${total_spans} -gt 0 && ${unique_trace_ids} -gt 0 ]]; then echo "true"; else echo "false"; fi),
      "services_identified": $(if [[ ${unique_services} -gt 0 ]]; then echo "true"; else echo "false"; fi)
    }
  }
}
EOF
    
    log_fix "📋 Fix report generated: ${FIX_REPORT}"
    
    # Verify the fix worked
    if [[ ${unique_trace_ids} -gt 0 && ${unique_services} -gt 0 ]]; then
        log_fix "✅ 80/20 FIX SUCCESSFUL: Telemetry parsing now extracts real data"
        return 0
    else
        log_fix "❌ 80/20 FIX FAILED: Still not extracting meaningful data"
        return 1
    fi
}

# Main execution
main() {
    log_fix "🚀 80/20 TELEMETRY PARSING FIX INITIATED"
    
    # Fix telemetry format
    local fixed_file
    fixed_file=$(fix_telemetry_format)
    
    # Extract real metrics
    if extract_telemetry_metrics "${fixed_file}"; then
        log_fix "🎯 80/20 FIX COMPLETE: Telemetry parsing fixed"
        echo "FIXED_TELEMETRY_FILE=${fixed_file}"
        echo "FIX_REPORT=${FIX_REPORT}"
    else
        log_fix "❌ 80/20 FIX INCOMPLETE: Manual intervention required"
        return 1
    fi
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi