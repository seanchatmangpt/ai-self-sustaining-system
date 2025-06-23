#!/bin/bash

# Trace Test Script B - Coordination system integration test

echo "🔗 [TRACE_TEST_B] Coordination integration test starting"
echo "🔗 [TRACE_TEST_B] Master Trace: ${ORCHESTRATOR_TRACE_ID:-missing}"

# Test coordination helper integration
COORDINATION_ROOT="$(dirname "$(dirname "${BASH_SOURCE[0]}")")/agent_coordination"

if [[ -x "$COORDINATION_ROOT/coordination_helper.sh" && -n "${ORCHESTRATOR_TRACE_ID:-}" ]]; then
    echo "🔗 [TRACE_TEST_B] Testing coordination helper with trace: $ORCHESTRATOR_TRACE_ID"
    
    # Try to get system status with trace
    if "$COORDINATION_ROOT/coordination_helper.sh" system-status > /dev/null 2>&1; then
        echo "✅ [TRACE_TEST_B] Coordination helper accessible with trace $ORCHESTRATOR_TRACE_ID"
    else
        echo "⚠️  [TRACE_TEST_B] Coordination helper execution had issues"
    fi
else
    echo "❌ [TRACE_TEST_B] Coordination helper not available or no trace"
fi

echo "🏁 [TRACE_TEST_B] Coordination integration test completed"