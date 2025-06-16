#!/bin/bash

# Trace validator test - validates trace ID format and propagation
# Part of infinite orchestrator comprehensive validation

echo "🔬 Trace Validator Test"
echo "🔍 Master Trace: ${MASTER_TRACE:-none}"

validate_trace_format() {
    local trace_id="$1"
    if [[ "$trace_id" =~ ^[a-f0-9]{32}$ ]]; then
        return 0
    else
        return 1
    fi
}

if [[ -n "$MASTER_TRACE" ]]; then
    if validate_trace_format "$MASTER_TRACE"; then
        echo "✅ Valid trace format: $MASTER_TRACE"
        echo "✅ TRACE_PROPAGATED: $MASTER_TRACE"
        echo "✅ TRACE_FORMAT_VALID: true"
        
        # Additional validation
        echo "🔍 Trace length: ${#MASTER_TRACE}"
        echo "🔍 Trace type: hexadecimal"
        echo "🔍 Execution context: ${EXECUTION_ID:-unknown}"
    else
        echo "❌ Invalid trace format: $MASTER_TRACE"
        exit 1
    fi
else
    echo "❌ NO_TRACE_DETECTED"
    exit 1
fi