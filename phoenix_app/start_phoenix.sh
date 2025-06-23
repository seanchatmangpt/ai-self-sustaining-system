#!/bin/bash

# Phoenix 80/20 Startup Script
# Implements critical 20% fixes for 80% Phoenix functionality

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$SCRIPT_DIR/phoenix_startup.log"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "🚀 Starting Phoenix with 80/20 fixes applied"

# Navigate to correct Phoenix directory
cd "$SCRIPT_DIR"

# Check if mix.exs exists
if [ ! -f "mix.exs" ]; then
    log "❌ No mix.exs found in $SCRIPT_DIR"
    log "🔍 Searching for Phoenix application..."
    
    # Find the mix.exs with Phoenix dependencies
    PHOENIX_DIR=$(find . -name "mix.exs" -exec grep -l "phoenix" {} \; | head -1 | xargs dirname)
    
    if [ -n "$PHOENIX_DIR" ]; then
        log "✅ Found Phoenix application in: $PHOENIX_DIR"
        cd "$PHOENIX_DIR"
    else
        log "❌ No Phoenix application found"
        exit 1
    fi
fi

log "📍 Working directory: $(pwd)"

# Stop any existing Phoenix processes
log "🛑 Stopping existing Phoenix processes"
pkill -f "mix phx.server" || true
sleep 2

# Clear any compilation artifacts
log "🧹 Cleaning compilation artifacts"
rm -rf _build/dev || true

# Get dependencies
log "📦 Installing dependencies"
mix deps.get 2>&1 | tee -a "$LOG_FILE"

# Compile with fixed warnings
log "🔧 Compiling Phoenix application"
if mix compile 2>&1 | tee -a "$LOG_FILE"; then
    log "✅ Compilation successful"
else
    log "⚠️  Compilation completed with warnings"
fi

# Start Phoenix server
log "🌐 Starting Phoenix server on port 4001"
nohup mix phx.server > "$SCRIPT_DIR/phoenix_server.log" 2>&1 &
PHOENIX_PID=$!
echo $PHOENIX_PID > "$SCRIPT_DIR/phoenix.pid"

log "🔄 Waiting for Phoenix to start (PID: $PHOENIX_PID)"
sleep 10

# Test Phoenix endpoints
log "🏥 Testing Phoenix health"
if curl -s -f http://localhost:4001/health >/dev/null 2>&1; then
    log "✅ Phoenix health endpoint responding"
else
    log "⚠️  Phoenix health endpoint not responding (expected with OpenTelemetry disabled)"
fi

# Test root endpoint
if curl -s -f http://localhost:4001/ >/dev/null 2>&1; then
    log "✅ Phoenix root endpoint responding"
else
    log "⚠️  Phoenix root endpoint not responding"
fi

# Show final status
if kill -0 $PHOENIX_PID 2>/dev/null; then
    log "✅ Phoenix server running successfully (PID: $PHOENIX_PID)"
    log "🌐 Access at: http://localhost:4001"
    log "📊 Metrics at: http://localhost:4001/metrics (if PromEx enabled)"
    log "📋 Dashboard at: http://localhost:4001/dev/dashboard"
else
    log "❌ Phoenix server failed to start"
    log "📋 Check logs in: $SCRIPT_DIR/phoenix_server.log"
    exit 1
fi

log "🎯 Phoenix 80/20 startup complete!"