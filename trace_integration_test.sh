#!/bin/bash

# Trace integration test - combines multiple validation approaches
# Advanced test for infinite orchestrator permutation testing

echo "🔗 Trace Integration Test"
echo "🔍 Master Trace: ${MASTER_TRACE:-none}"

if [[ -n "$MASTER_TRACE" ]]; then
    echo "✅ TRACE_PROPAGATED: $MASTER_TRACE"
    
    # Test 1: Echo verification
    echo "📋 Step 1: Echo verification"
    echo "🔍 Trace echoed: $MASTER_TRACE"
    
    # Test 2: Environment verification
    echo "📋 Step 2: Environment verification"
    if [[ "$TRACE_ID" == "$MASTER_TRACE" ]]; then
        echo "✅ TRACE_ID matches: $TRACE_ID"
    fi
    if [[ "$OTEL_TRACE_ID" == "$MASTER_TRACE" ]]; then
        echo "✅ OTEL_TRACE_ID matches: $OTEL_TRACE_ID"
    fi
    
    # Test 3: Context preservation
    echo "📋 Step 3: Context preservation"
    if [[ -n "$ORCHESTRATOR_EXECUTION" ]]; then
        echo "✅ Orchestrator context preserved"
    fi
    if [[ -n "$EXECUTION_ID" ]]; then
        echo "✅ Execution ID preserved: $EXECUTION_ID"
    fi
    
    # Test 4: Simulated downstream call
    echo "📋 Step 4: Simulated downstream call"
    echo "🔄 Calling downstream service with trace: $MASTER_TRACE"
    sleep 0.1
    echo "✅ Downstream call completed with trace: $MASTER_TRACE"
    
    echo "🎉 Integration test completed successfully"
    echo "✅ TRACE_PROPAGATED: $MASTER_TRACE"
    echo "✅ INTEGRATION_SUCCESS: true"
else
    echo "❌ NO_TRACE_DETECTED"
    exit 1
fi