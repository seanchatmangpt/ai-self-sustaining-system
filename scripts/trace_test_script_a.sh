#!/bin/bash

# Trace Test Script A - Simple trace propagation test
# This script validates trace ID propagation and records telemetry

echo "🔍 [TRACE_TEST_A] Starting with trace ID: ${ORCHESTRATOR_TRACE_ID:-no_trace}"
echo "🔍 [TRACE_TEST_A] OTEL Trace: ${OTEL_TRACE_ID:-no_otel_trace}"
echo "🔍 [TRACE_TEST_A] Execution ID: ${TRACE_EXECUTION_ID:-no_exec_id}"

# Simulate some work
sleep 1

# Check if we have trace propagation
if [[ -n "${ORCHESTRATOR_TRACE_ID:-}" ]]; then
    echo "✅ [TRACE_TEST_A] Trace propagation VERIFIED: $ORCHESTRATOR_TRACE_ID"
    
    # Record trace activity
    if [[ -n "${TRACE_EXECUTION_ID:-}" ]]; then
        echo "📊 [TRACE_TEST_A] Recording trace activity for execution: $TRACE_EXECUTION_ID"
    fi
else
    echo "❌ [TRACE_TEST_A] No trace propagation detected"
fi

echo "🏁 [TRACE_TEST_A] Script completed successfully"