#!/bin/bash

# Phoenix Health Monitor - 80/20 Feedback Loop
# Continuously monitors Phoenix stability and applies fixes when needed

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_FILE="$PROJECT_ROOT/phoenix_health_monitor.log"
HEALTH_CHECK_INTERVAL=30
MAX_FAILURES=3

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() {
    echo -e "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

success() {
    log "${GREEN}✅ $1${NC}"
}

warning() {
    log "${YELLOW}⚠️  $1${NC}"
}

error() {
    log "${RED}❌ $1${NC}"
}

check_phoenix_process() {
    local pid_file="$PROJECT_ROOT/phoenix_app/phoenix.pid"
    
    if [ -f "$pid_file" ]; then
        local pid=$(cat "$pid_file")
        if kill -0 "$pid" 2>/dev/null; then
            return 0  # Process is running
        else
            return 1  # Process is dead
        fi
    else
        return 1  # No PID file
    fi
}

check_phoenix_endpoints() {
    local health_check=0
    local root_check=0
    
    # Test health endpoint
    if curl -s -f -m 5 http://localhost:4001/health >/dev/null 2>&1; then
        health_check=1
    fi
    
    # Test root endpoint  
    if curl -s -f -m 5 http://localhost:4001/ >/dev/null 2>&1; then
        root_check=1
    fi
    
    echo "$health_check:$root_check"
}

apply_80_20_fix() {
    local issue_type="$1"
    
    log "🔧 Applying 80/20 fix for: $issue_type"
    
    case "$issue_type" in
        "process_dead")
            log "🚀 Restarting Phoenix server"
            cd "$PROJECT_ROOT/phoenix_app/phoenix_app" || cd "$PROJECT_ROOT"
            
            # Kill any orphaned processes
            pkill -f "mix phx.server" || true
            sleep 2
            
            # Restart Phoenix
            nohup mix phx.server > "$PROJECT_ROOT/phoenix_app/phoenix_server.log" 2>&1 &
            local new_pid=$!
            echo $new_pid > "$PROJECT_ROOT/phoenix_app/phoenix.pid"
            
            log "🔄 Phoenix restarted with PID: $new_pid"
            sleep 10
            ;;
            
        "endpoints_down")
            log "🔍 Checking for OpenTelemetry issues"
            
            # Check if OpenTelemetry plugs are causing issues
            local endpoint_file="$PROJECT_ROOT/phoenix_app/lib/self_sustaining_web/endpoint.ex"
            if grep -q "plug OpenTelemetryPhoenix" "$endpoint_file"; then
                warning "OpenTelemetry plugs still enabled, commenting out"
                sed -i.bak 's/plug OpenTelemetryPhoenix/# plug OpenTelemetryPhoenix/' "$endpoint_file"
                sed -i.bak 's/plug OpenTelemetryCowboy/# plug OpenTelemetryCowboy/' "$endpoint_file"
                
                # Restart Phoenix after fixing
                apply_80_20_fix "process_dead"
            fi
            ;;
            
        "compilation_errors")
            log "🔧 Fixing compilation issues"
            cd "$PROJECT_ROOT/phoenix_app/phoenix_app" || cd "$PROJECT_ROOT"
            
            # Clean and recompile
            rm -rf _build/dev
            mix deps.clean --all
            mix deps.get
            mix compile
            
            # Restart after recompilation
            apply_80_20_fix "process_dead"
            ;;
    esac
}

monitor_loop() {
    local failure_count=0
    
    log "🔄 Starting Phoenix health monitoring loop"
    log "📍 Project root: $PROJECT_ROOT"
    log "⏰ Check interval: ${HEALTH_CHECK_INTERVAL}s"
    log "🚨 Max failures before restart: $MAX_FAILURES"
    
    while true; do
        log "🔍 Checking Phoenix health..."
        
        # Check if Phoenix process is running
        if ! check_phoenix_process; then
            error "Phoenix process not running"
            apply_80_20_fix "process_dead"
            failure_count=0
            sleep $HEALTH_CHECK_INTERVAL
            continue
        fi
        
        # Check if endpoints are responding
        local endpoint_status
        endpoint_status=$(check_phoenix_endpoints)
        local health_ok=$(echo "$endpoint_status" | cut -d: -f1)
        local root_ok=$(echo "$endpoint_status" | cut -d: -f2)
        
        if [ "$health_ok" = "1" ] || [ "$root_ok" = "1" ]; then
            success "Phoenix endpoints responding (health:$health_ok, root:$root_ok)"
            failure_count=0
        else
            failure_count=$((failure_count + 1))
            warning "Phoenix endpoints not responding (attempt $failure_count/$MAX_FAILURES)"
            
            if [ $failure_count -ge $MAX_FAILURES ]; then
                error "Max failures reached, applying fixes"
                apply_80_20_fix "endpoints_down"
                failure_count=0
            fi
        fi
        
        # Check system resources
        local memory_usage
        memory_usage=$(ps -o pid,ppid,%mem,rss,comm -p $(cat "$PROJECT_ROOT/phoenix_app/phoenix.pid" 2>/dev/null || echo "0") 2>/dev/null | tail -1 | awk '{print $3}')
        if [ -n "$memory_usage" ] && [ "$memory_usage" != "%MEM" ]; then
            log "📊 Phoenix memory usage: ${memory_usage}%"
            
            # Alert if memory usage is too high
            if (( $(echo "$memory_usage > 10.0" | bc -l) )); then
                warning "High memory usage detected: ${memory_usage}%"
            fi
        fi
        
        sleep $HEALTH_CHECK_INTERVAL
    done
}

# Handle signals
cleanup() {
    log "🛑 Phoenix health monitor stopping"
    exit 0
}

trap cleanup SIGINT SIGTERM

# Main execution
log "🚀 Phoenix Health Monitor Starting"
log "📋 80/20 feedback loop for continuous Phoenix stability"

# Initial health check
if check_phoenix_process; then
    success "Phoenix process running"
else
    warning "Phoenix process not running, starting..."
    apply_80_20_fix "process_dead"
fi

# Start monitoring loop
monitor_loop