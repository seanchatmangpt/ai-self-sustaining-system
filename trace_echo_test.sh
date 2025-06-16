#!/bin/bash

# Simple trace echo test - echoes received trace ID
# Used by infinite orchestrator for trace propagation verification

echo "🔍 Trace Echo Test: Received trace ID: ${TRACE_ID:-none}"
echo "🔍 OTEL Trace: ${OTEL_TRACE_ID:-none}"
echo "🔍 Master Trace: ${MASTER_TRACE:-none}"
echo "🔍 Execution ID: ${EXECUTION_ID:-none}"

# Verify trace propagation by echoing master trace if available
if [[ -n "$MASTER_TRACE" ]]; then
    echo "✅ TRACE_PROPAGATED: $MASTER_TRACE"
    exit 0
else
    echo "❌ NO_TRACE_DETECTED"
    exit 1
fi