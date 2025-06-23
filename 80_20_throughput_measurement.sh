#!/bin/bash

# 80/20 Throughput Measurement - Calculate actual vs claimed performance
# CLAUDE.md: Verify performance claims with mathematical precision

set -euo pipefail

echo "🎯 80/20 THROUGHPUT MEASUREMENT"
echo "==============================="
echo "Measuring actual completion rates vs '6 items in 16 seconds' claim"
echo ""

WORK_CLAIMS="./agent_coordination/work_claims.json"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

if [[ ! -f "$WORK_CLAIMS" ]]; then
    echo -e "${RED}❌ Work claims file not found${NC}"
    exit 1
fi

echo "📊 ANALYZING COMPLETION TIMESTAMPS"
echo "=================================="

# Extract all completed items with valid timestamps
completed_items=$(jq -r '.[] | select(.status == "completed" and .claimed_at != null and .completed_at != null) | "\(.work_item_id),\(.claimed_at),\(.completed_at),\(.work_type)"' "$WORK_CLAIMS" 2>/dev/null)

if [[ -z "$completed_items" ]]; then
    echo -e "${RED}❌ No completed items with valid timestamps found${NC}"
    exit 1
fi

total_items=0
total_duration_seconds=0
fastest_completion=999999
slowest_completion=0
items_under_20_seconds=0

echo "📋 Individual completion analysis:"
echo "$completed_items" | while IFS=',' read -r item_id claimed_at completed_at work_type; do
    if [[ -n "$claimed_at" && -n "$completed_at" ]]; then
        # Convert ISO timestamps to seconds (simplified - using date command)
        if claimed_seconds=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$claimed_at" "+%s" 2>/dev/null) && \
           completed_seconds=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$completed_at" "+%s" 2>/dev/null); then
            
            duration=$((completed_seconds - claimed_seconds))
            
            echo "  $(basename "$work_type"): ${duration}s"
            
            if [[ $duration -lt 20 ]]; then
                ((items_under_20_seconds++))
            fi
            
            if [[ $duration -lt $fastest_completion ]]; then
                fastest_completion=$duration
            fi
            
            if [[ $duration -gt $slowest_completion ]]; then
                slowest_completion=$duration
            fi
            
            total_duration_seconds=$((total_duration_seconds + duration))
            ((total_items++))
            
        else
            echo "  $work_type: Invalid timestamp format"
        fi
    fi
done

# Calculate averages and rates outside the subshell
echo ""
echo "🔍 RE-ANALYZING FOR SUMMARY (avoiding subshell limitations)..."

# Use awk for more reliable timestamp processing
analysis_results=$(echo "$completed_items" | awk -F',' '
BEGIN { 
    total_items=0; total_duration=0; fastest=999999; slowest=0; under_20=0 
}
{
    if (NF >= 4) {
        # Simple timestamp parsing (assumes format YYYY-MM-DDTHH:MM:SSZ)
        claimed_at = $2
        completed_at = $3
        work_type = $4
        
        # Extract time components (simplified)
        gsub(/[TZ-]/, " ", claimed_at)
        gsub(/[TZ-]/, " ", completed_at)
        gsub(/:/, " ", claimed_at)
        gsub(/:/, " ", completed_at)
        
        # Calculate rough duration in seconds (simplified calculation)
        # This is a rough approximation - real implementation would need proper date parsing
        split(claimed_at, c_parts, " ")
        split(completed_at, comp_parts, " ")
        
        # Rough calculation based on minutes and seconds
        if (length(c_parts) >= 6 && length(comp_parts) >= 6) {
            c_total_sec = c_parts[4]*3600 + c_parts[5]*60 + c_parts[6]
            comp_total_sec = comp_parts[4]*3600 + comp_parts[5]*60 + comp_parts[6]
            duration = comp_total_sec - c_total_sec
            
            # Handle day rollover (rough)
            if (duration < 0) duration += 86400
            
            if (duration < fastest) fastest = duration
            if (duration > slowest) slowest = duration
            if (duration < 20) under_20++
            
            total_duration += duration
            total_items++
        }
    }
}
END { 
    if (total_items > 0) {
        avg_duration = total_duration / total_items
        rate_per_hour = total_items * 3600 / total_duration
        print total_items "," total_duration "," avg_duration "," fastest "," slowest "," under_20 "," rate_per_hour
    } else {
        print "0,0,0,0,0,0,0"
    }
}')

IFS=',' read -r total_items total_duration_seconds avg_duration fastest_completion slowest_completion items_under_20_seconds rate_per_hour <<< "$analysis_results"

echo ""
echo "🎯 THROUGHPUT ANALYSIS RESULTS"
echo "=============================="
echo "Total completed items analyzed: $total_items"
echo "Total duration analyzed: $total_duration_seconds seconds"

if [[ $total_items -gt 0 ]]; then
    echo "Average completion time: $avg_duration seconds"
    echo "Fastest completion: $fastest_completion seconds"
    echo "Slowest completion: $slowest_completion seconds"
    echo "Items completed under 20 seconds: $items_under_20_seconds"
    echo "Calculated throughput: $rate_per_hour items/hour"
    
    # Test the "6 items in 16 seconds" claim
    echo ""
    echo "🧪 TESTING '6 ITEMS IN 16 SECONDS' CLAIM"
    echo "========================================"
    
    claimed_rate_per_hour=$((6 * 3600 / 16))
    echo "Claimed rate: $claimed_rate_per_hour items/hour (6 items in 16 seconds)"
    echo "Actual measured rate: $rate_per_hour items/hour"
    
    if [[ $items_under_20_seconds -ge 6 ]]; then
        echo -e "${GREEN}✅ At least 6 items completed under 20 seconds${NC}"
    else
        echo -e "${RED}❌ Only $items_under_20_seconds items completed under 20 seconds (need 6)${NC}"
    fi
    
    # Compare rates
    if [[ $(echo "$rate_per_hour >= $claimed_rate_per_hour" | bc -l 2>/dev/null || echo "0") -eq 1 ]]; then
        echo -e "${GREEN}✅ Actual rate meets or exceeds claimed rate${NC}"
        performance_ratio=$(echo "scale=2; $rate_per_hour / $claimed_rate_per_hour" | bc -l 2>/dev/null || echo "1")
        echo "Performance ratio: ${performance_ratio}x claimed rate"
    else
        echo -e "${RED}❌ Actual rate below claimed rate${NC}"
        performance_deficit=$(echo "scale=2; ($claimed_rate_per_hour - $rate_per_hour) / $claimed_rate_per_hour * 100" | bc -l 2>/dev/null || echo "0")
        echo "Performance deficit: ${performance_deficit}% below claimed rate"
    fi
    
    # Reality assessment
    echo ""
    echo "🎯 REALITY ASSESSMENT"
    echo "===================="
    
    if [[ $items_under_20_seconds -ge 6 ]] && [[ $(echo "$rate_per_hour >= $claimed_rate_per_hour" | bc -l 2>/dev/null || echo "0") -eq 1 ]]; then
        echo -e "${GREEN}🎉 CLAIM VERIFIED: Performance claims appear to be supported by data${NC}"
    elif [[ $items_under_20_seconds -ge 3 ]] && [[ $(echo "$rate_per_hour >= $(echo "$claimed_rate_per_hour * 0.5" | bc -l)" | bc -l 2>/dev/null || echo "0") -eq 1 ]]; then
        echo -e "${YELLOW}⚠️  PARTIAL VERIFICATION: Some evidence supports claims but gaps exist${NC}"
    else
        echo -e "${RED}❌ CLAIM NOT VERIFIED: Performance claims not supported by measured data${NC}"
    fi
    
else
    echo -e "${RED}❌ No valid completion data for analysis${NC}"
fi

echo ""
echo "🔄 80/20 ITERATION RECOMMENDATIONS:"
echo "1. Implement real-time performance monitoring"
echo "2. Add duration tracking to agent operations"
echo "3. Create automated claim validation"
echo "4. Remove unverifiable performance claims"