#!/bin/bash

# Start Infinite Trace Orchestrator in background
# This script starts the orchestrator and lets it run indefinitely

echo "🚀 Starting Infinite Trace Orchestrator in background..."
echo "📋 Master trace propagation testing will run continuously"
echo "🔄 Finding new script combinations and verifying trace flow"
echo ""

# Start orchestrator in background with output redirection
nohup ./infinite_trace_orchestrator.sh > orchestrator_output.log 2>&1 &
ORCHESTRATOR_PID=$!

echo "✅ Infinite Trace Orchestrator started with PID: $ORCHESTRATOR_PID"
echo "📁 Output being logged to: orchestrator_output.log"
echo "📊 Trace verification logged to: trace_verification_*.jsonl"
echo "🔍 Execution log in: infinite_trace_orchestrator_*.log"
echo ""
echo "🛑 To stop: kill $ORCHESTRATOR_PID"
echo "📋 To monitor: tail -f orchestrator_output.log"
echo ""
echo "🎯 The orchestrator will:"
echo "   • Discover and execute all shell scripts"
echo "   • Generate infinite combinations and permutations"  
echo "   • Maintain single trace ID across all executions"
echo "   • Verify trace propagation through every script"
echo "   • Never stop finding new combinations"
echo ""
echo "PID: $ORCHESTRATOR_PID" > orchestrator.pid