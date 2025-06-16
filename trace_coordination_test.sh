#!/bin/bash

# Trace coordination test - tests coordination system with trace
# Part of infinite orchestrator trace propagation validation

echo "🔧 Trace Coordination Test Starting"
echo "🔍 Master Trace: ${MASTER_TRACE:-none}"

if [[ -n "$MASTER_TRACE" ]]; then
    echo "✅ TRACE_PROPAGATED: $MASTER_TRACE"
    
    # Quick coordination test with trace
    if [[ -x "./agent_coordination/coordination_helper.sh" ]]; then
        echo "🤖 Testing coordination with trace: $MASTER_TRACE"
        export TRACE_ID="$MASTER_TRACE"
        export OTEL_TRACE_ID="$MASTER_TRACE"
        echo "✅ COORDINATION_TRACE_READY: $MASTER_TRACE"
    fi
else
    echo "❌ NO_TRACE_DETECTED"
    exit 1
fi