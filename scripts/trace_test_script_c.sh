#!/bin/bash

# Trace Test Script C - Telemetry validation test

echo "📊 [TRACE_TEST_C] Telemetry validation starting"
echo "📊 [TRACE_TEST_C] Trace context: ${OTEL_TRACE_ID:-no_trace}, Span: ${OTEL_PARENT_SPAN_ID:-no_span}"

# Validate telemetry file access
TELEMETRY_FILE="$(dirname "$(dirname "${BASH_SOURCE[0]}")")/agent_coordination/telemetry_spans.jsonl"

if [[ -f "$TELEMETRY_FILE" && -n "${ORCHESTRATOR_TRACE_ID:-}" ]]; then
    echo "📊 [TRACE_TEST_C] Checking telemetry file for trace: $ORCHESTRATOR_TRACE_ID"
    
    # Check if our trace appears in telemetry
    if grep -q "$ORCHESTRATOR_TRACE_ID" "$TELEMETRY_FILE" 2>/dev/null; then
        local span_count=$(grep -c "$ORCHESTRATOR_TRACE_ID" "$TELEMETRY_FILE" 2>/dev/null || echo "0")
        echo "✅ [TRACE_TEST_C] Found $span_count spans with trace $ORCHESTRATOR_TRACE_ID"
    else
        echo "⚠️  [TRACE_TEST_C] Trace not yet found in telemetry (may appear later)"
    fi
    
    # Simulate telemetry emission
    echo "📊 [TRACE_TEST_C] Simulating telemetry emission for trace $ORCHESTRATOR_TRACE_ID"
    
else
    echo "❌ [TRACE_TEST_C] Telemetry file not accessible or no trace context"
fi

echo "🏁 [TRACE_TEST_C] Telemetry validation completed"