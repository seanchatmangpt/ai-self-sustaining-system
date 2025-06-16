#!/bin/bash

# Trace benchmark test - measures trace propagation performance
# Part of infinite orchestrator validation suite

echo "⚡ Trace Benchmark Test"
echo "🔍 Master Trace: ${MASTER_TRACE:-none}"

if [[ -n "$MASTER_TRACE" ]]; then
    start_time=$(date +%s%N)
    
    # Simulate some work with trace context
    for i in {1..10}; do
        echo "🔄 Processing with trace: $MASTER_TRACE (iteration $i)"
        sleep 0.01
    done
    
    end_time=$(date +%s%N)
    duration_ms=$(( (end_time - start_time) / 1000000 ))
    
    echo "⏱️  Benchmark completed in ${duration_ms}ms with trace: $MASTER_TRACE"
    echo "✅ TRACE_PROPAGATED: $MASTER_TRACE"
    echo "📊 BENCHMARK_RESULT: ${duration_ms}ms"
else
    echo "❌ NO_TRACE_DETECTED"
    exit 1
fi