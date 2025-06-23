#!/bin/bash

# Apply 80/20 Trace Propagation Fix to Infinite Orchestrator
# This script implements the minimal fix to enable trace context inheritance

set -euo pipefail

echo "🎯 APPLYING 80/20 FIX TO INFINITE TRACE ORCHESTRATOR"
echo "===================================================="
echo "Current Status: 0% trace propagation (98/98 failures)"
echo "Target: >0% trace propagation success rate"
echo "Method: Add OTEL environment variables before script execution"
echo ""

ORCHESTRATOR_FILE="./scripts/infinite_trace_orchestrator.sh"
BACKUP_FILE="./scripts/infinite_trace_orchestrator_backup_$(date +%s).sh"

if [[ ! -f "$ORCHESTRATOR_FILE" ]]; then
    echo "❌ Orchestrator file not found: $ORCHESTRATOR_FILE"
    exit 1
fi

echo "📁 Creating backup: $(basename $BACKUP_FILE)"
cp "$ORCHESTRATOR_FILE" "$BACKUP_FILE"

echo "🔧 Applying 80/20 fix..."

# Create the fix to add before line 162 (the timeout execution line)
FIX_CODE='
    # 80/20 TRACE PROPAGATION FIX - Add OTEL environment variables for child processes
    export TRACEPARENT="00-${MASTER_TRACE_ID}-${OTEL_SPAN_ID:-$(openssl rand -hex 8)}-01"
    export OTEL_TRACE_ID="$MASTER_TRACE_ID"
    export MASTER_TRACE="$MASTER_TRACE_ID"
    export OTEL_SERVICE_NAME="trace-orchestrator-child"
    
'

# Find the line number where the timeout command is executed
LINE_NUM=$(grep -n "timeout 30s" "$ORCHESTRATOR_FILE" | head -1 | cut -d: -f1)

if [[ -z "$LINE_NUM" ]]; then
    echo "❌ Could not find timeout execution line in orchestrator"
    exit 1
fi

echo "📍 Found script execution at line $LINE_NUM"
echo "➕ Adding OTEL environment variables before execution"

# Create temporary file with the fix applied
{
    head -n $((LINE_NUM - 1)) "$ORCHESTRATOR_FILE"
    echo "$FIX_CODE"
    tail -n +$LINE_NUM "$ORCHESTRATOR_FILE"
} > "${ORCHESTRATOR_FILE}.tmp"

# Replace the original file
mv "${ORCHESTRATOR_FILE}.tmp" "$ORCHESTRATOR_FILE"

echo "✅ 80/20 fix applied successfully!"
echo ""
echo "🔄 LOOP VALIDATION:"
echo "1. Stop current orchestrator (PID 71603)"
echo "2. Start new orchestrator with fix"
echo "3. Monitor for trace propagation success (0% → >0%)"
echo ""
echo "📋 To validate:"
echo "  kill 71603"
echo "  ./start_infinite_orchestrator.sh"
echo "  tail -f orchestrator_output.log | grep -E '(VERIFIED|trace_propagated=true)'"
echo ""
echo "🎉 Ready to scale from 0% to >0% trace propagation success!"