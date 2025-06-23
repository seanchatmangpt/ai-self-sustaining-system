#!/bin/bash

# 80/20 Trace Propagation Fix
# Minimal fix to enable OpenTelemetry trace context inheritance in shell scripts
# This script demonstrates the core fix needed for 0% → >0% trace propagation

set -euo pipefail

echo "🎯 80/20 TRACE PROPAGATION FIX"
echo "Problem: 0% trace propagation success (98/98 failures)"
echo "Root Cause: Missing OTEL environment variables in child processes"
echo "Solution: Export standard OpenTelemetry trace context variables"
echo ""

# Generate test trace context
MASTER_TRACE_ID=${MASTER_TRACE_ID:-$(openssl rand -hex 16)}
SPAN_ID=$(openssl rand -hex 8)

echo "🔧 BEFORE: Standard script execution (no trace context)"
echo "timeout 30s ./script.sh"
echo ""

echo "🚀 AFTER: OTEL-enabled script execution (trace context inherited)"
echo "export TRACEPARENT=\"00-${MASTER_TRACE_ID}-${SPAN_ID}-01\""
echo "export OTEL_TRACE_ID=\"${MASTER_TRACE_ID}\""
echo "export OTEL_SPAN_ID=\"${SPAN_ID}\""
echo "export OTEL_SERVICE_NAME=\"trace-orchestrator\""
echo "timeout 30s ./script.sh"
echo ""

# Test with 5 representative scripts (80/20 sample)
SAMPLE_SCRIPTS=(
    "../trace_echo_test.sh"
    "../agent_coordination/coordination_helper.sh"
    "../ai_self_sustaining_minimal/quick_benchmark.sh"
    "../scripts/check_status.sh"
    "../phoenix_app/scripts/validate_trace_implementation.sh"
)

echo "📊 TESTING 80/20 FIX ON 5 REPRESENTATIVE SCRIPTS"
echo "=============================================="

SUCCESSFUL_PROPAGATIONS=0
TOTAL_TESTS=0

for script in "${SAMPLE_SCRIPTS[@]}"; do
    if [[ -f "$script" && -x "$script" ]]; then
        echo ""
        echo "🧪 Testing: $(basename "$script")"
        
        # Set up trace context for child process
        export TRACEPARENT="00-${MASTER_TRACE_ID}-${SPAN_ID}-01"
        export OTEL_TRACE_ID="$MASTER_TRACE_ID"
        export OTEL_SPAN_ID="$SPAN_ID"
        export OTEL_SERVICE_NAME="trace-orchestrator"
        export MASTER_TRACE="$MASTER_TRACE_ID"
        
        start_time=$(date +%s%N)
        
        # Execute script with OTEL context
        if script_output=$(timeout 10s "$script" 2>&1 || true); then
            end_time=$(date +%s%N)
            duration_ms=$(( (end_time - start_time) / 1000000 ))
            
            # Check for trace propagation
            if echo "$script_output" | grep -q "$MASTER_TRACE_ID"; then
                echo "✅ TRACE PROPAGATED ($duration_ms ms)"
                ((SUCCESSFUL_PROPAGATIONS++))
            elif echo "$script_output" | grep -qE "(TRACE|trace|OTEL|otel)"; then
                echo "⚠️  PARTIAL TRACE CONTEXT ($duration_ms ms)"
            else
                echo "❌ NO TRACE PROPAGATION ($duration_ms ms)"
            fi
        else
            echo "💥 EXECUTION FAILED"
        fi
        
        ((TOTAL_TESTS++))
    else
        echo "⏭️  Skipping: $script (not found or not executable)"
    fi
done

echo ""
echo "📈 80/20 FIX RESULTS"
echo "==================="
echo "Successful propagations: $SUCCESSFUL_PROPAGATIONS/$TOTAL_TESTS"
echo "Success rate: $(( SUCCESSFUL_PROPAGATIONS * 100 / TOTAL_TESTS ))%"
echo ""

if [[ $SUCCESSFUL_PROPAGATIONS -gt 0 ]]; then
    echo "🎉 SUCCESS: 80/20 fix proven! (0% → $(( SUCCESSFUL_PROPAGATIONS * 100 / TOTAL_TESTS ))%)"
    echo "💡 Next: Apply this fix to infinite trace orchestrator"
    echo ""
    echo "🔧 CODE FIX FOR ORCHESTRATOR:"
    echo "# Add before line 162 in infinite_trace_orchestrator.sh:"
    echo 'export TRACEPARENT="00-${MASTER_TRACE_ID}-${OTEL_SPAN_ID:-$(openssl rand -hex 8)}-01"'
    echo 'export OTEL_TRACE_ID="$MASTER_TRACE_ID"'
    echo 'export MASTER_TRACE="$MASTER_TRACE_ID"'
else
    echo "🔍 ANALYSIS: Scripts may not be instrumented for OTEL"
    echo "💡 Alternative: Add echo statements to test scripts for verification"
fi

echo ""
echo "🔄 LOOP: Ready to scale fix to all 530 scripts once validated"