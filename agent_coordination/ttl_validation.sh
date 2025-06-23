#!/bin/bash
# TTL Validation Script
# Prevents future accumulation of test data through time-based cleanup

set -euo pipefail

COORDINATION_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_CLAIMS="$COORDINATION_DIR/work_claims.json"

# TTL Configuration
DEFAULT_TTL_HOURS=24
BENCHMARK_TTL_HOURS=4  # Shorter TTL for benchmark tests
CLEANUP_THRESHOLD=100  # Clean up when more than 100 stale items

# Function to check if work item is stale
is_work_item_stale() {
    local claimed_at="$1"
    local ttl_hours="$2"
    local current_time=$(date +%s)
    local ttl_seconds=$((ttl_hours * 3600))
    
    if [[ -z "$claimed_at" || "$claimed_at" == "null" ]]; then
        return 0  # No timestamp = stale
    fi
    
    local claim_epoch
    claim_epoch=$(date -d "$claimed_at" +%s 2>/dev/null || echo 0)
    local age_seconds=$((current_time - claim_epoch))
    
    [[ $age_seconds -gt $ttl_seconds ]]
}

# Function to count stale items
count_stale_items() {
    local stale_count=0
    
    while IFS= read -r line; do
        local claimed_at work_type
        claimed_at=$(echo "$line" | jq -r '.claimed_at // ""')
        work_type=$(echo "$line" | jq -r '.work_type // ""')
        
        local ttl_hours=$DEFAULT_TTL_HOURS
        if [[ "$work_type" =~ benchmark_test_ ]]; then
            ttl_hours=$BENCHMARK_TTL_HOURS
        fi
        
        if is_work_item_stale "$claimed_at" "$ttl_hours"; then
            ((stale_count++))
        fi
    done < <(jq -c '.[]' "$WORK_CLAIMS" 2>/dev/null || echo '[]')
    
    echo "$stale_count"
}

# Function to auto-cleanup if threshold exceeded
auto_cleanup_if_needed() {
    local stale_count
    stale_count=$(count_stale_items)
    
    if [[ $stale_count -gt $CLEANUP_THRESHOLD ]]; then
        echo "Found $stale_count stale items (threshold: $CLEANUP_THRESHOLD)"
        echo "Auto-triggering cleanup..."
        bash "$COORDINATION_DIR/benchmark_cleanup_script.sh" --auto
        return 0
    fi
    
    echo "Stale items: $stale_count (threshold: $CLEANUP_THRESHOLD) - no cleanup needed"
    return 1
}

# Function to validate work claims before adding new ones
validate_before_claim() {
    local max_active_benchmarks=10
    
    local active_benchmarks
    active_benchmarks=$(jq '[.[] | select(.work_type | contains("benchmark_test_")) | select(.status == "active")] | length' "$WORK_CLAIMS" 2>/dev/null || echo 0)
    
    if [[ $active_benchmarks -gt $max_active_benchmarks ]]; then
        echo "WARNING: Too many active benchmark tests ($active_benchmarks > $max_active_benchmarks)"
        echo "Consider running cleanup before adding more work items"
        return 1
    fi
    
    return 0
}

# Main function
main() {
    case "${1:-check}" in
        "check")
            count_stale_items
            ;;
        "auto-cleanup")
            auto_cleanup_if_needed
            ;;
        "validate")
            validate_before_claim
            ;;
        *)
            echo "Usage: $0 {check|auto-cleanup|validate}"
            echo "  check        - Count stale items"
            echo "  auto-cleanup - Clean up if threshold exceeded"
            echo "  validate     - Validate before claiming new work"
            exit 1
            ;;
    esac
}

main "$@"