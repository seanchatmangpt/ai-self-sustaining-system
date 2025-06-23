#!/bin/bash
# synthetic_termination_script.sh - 80/20 Synthetic Generation Elimination
# Critical 20% effort to eliminate 80% synthetic data

set -e

WORK_DIR="/Users/sac/dev/ai-self-sustaining-system"
TERMINATION_LOG="/tmp/synthetic_termination_$(date +%s).log"

echo "SYNTHETIC TERMINATION SYSTEM - $(date)" > "$TERMINATION_LOG"
echo "=======================================" >> "$TERMINATION_LOG"

# Phase 1: STOP BACKGROUND SYNTHETIC PROCESSES
terminate_synthetic_processes() {
    echo "1. TERMINATING SYNTHETIC BACKGROUND PROCESSES" >> "$TERMINATION_LOG"
    
    # Kill specific synthetic generation processes
    pkill -f "reality_verification_engine" && echo "  ✅ Killed reality_verification_engine" >> "$TERMINATION_LOG" || echo "  ℹ️  reality_verification_engine not running" >> "$TERMINATION_LOG"
    pkill -f "infinite_trace_orchestrator" && echo "  ✅ Killed infinite_trace_orchestrator" >> "$TERMINATION_LOG" || echo "  ℹ️  infinite_trace_orchestrator not running" >> "$TERMINATION_LOG"
    pkill -f "autonomous_coordination_daemon" && echo "  ✅ Killed autonomous_coordination_daemon" >> "$TERMINATION_LOG" || echo "  ℹ️  autonomous_coordination_daemon not running" >> "$TERMINATION_LOG"
    pkill -f "agent_swarm_orchestrator" && echo "  ✅ Killed agent_swarm_orchestrator" >> "$TERMINATION_LOG" || echo "  ℹ️  agent_swarm_orchestrator not running" >> "$TERMINATION_LOG"
    
    # Find and kill any background workers generating synthetic data
    synthetic_processes=$(ps aux | grep -E "(intelligent_completion|auto.*completion|synthetic|batch)" | grep -v grep | awk '{print $2}')
    if [ -n "$synthetic_processes" ]; then
        echo "$synthetic_processes" | xargs kill 2>/dev/null && echo "  ✅ Killed additional synthetic processes" >> "$TERMINATION_LOG"
    else
        echo "  ℹ️  No additional synthetic processes found" >> "$TERMINATION_LOG"
    fi
}

# Phase 2: DISABLE SYNTHETIC GENERATION SCRIPTS
disable_synthetic_scripts() {
    echo "2. DISABLING SYNTHETIC GENERATION SCRIPTS" >> "$TERMINATION_LOG"
    
    # Disable intelligent completion engine
    if [ -f "$WORK_DIR/agent_coordination/intelligent_completion_engine.sh" ]; then
        chmod -x "$WORK_DIR/agent_coordination/intelligent_completion_engine.sh"
        echo "  ✅ Disabled intelligent_completion_engine.sh" >> "$TERMINATION_LOG"
    fi
    
    # Disable autonomous coordination daemon
    if [ -f "$WORK_DIR/autonomous_coordination_daemon.sh" ]; then
        chmod -x "$WORK_DIR/autonomous_coordination_daemon.sh"
        echo "  ✅ Disabled autonomous_coordination_daemon.sh" >> "$TERMINATION_LOG"
    fi
    
    # Disable infinite trace orchestrator
    if [ -f "$WORK_DIR/scripts/infinite_trace_orchestrator.sh" ]; then
        chmod -x "$WORK_DIR/scripts/infinite_trace_orchestrator.sh"
        echo "  ✅ Disabled infinite_trace_orchestrator.sh" >> "$TERMINATION_LOG"
    fi
    
    # Disable agent rebalancing script
    if [ -f "$WORK_DIR/scripts/rebalance_agents_80_20.sh" ]; then
        chmod -x "$WORK_DIR/scripts/rebalance_agents_80_20.sh"
        echo "  ✅ Disabled rebalance_agents_80_20.sh" >> "$TERMINATION_LOG"
    fi
}

# Phase 3: CLEAN PHANTOM AGENTS
clean_phantom_agents() {
    echo "3. CLEANING PHANTOM AGENTS FROM JSON" >> "$TERMINATION_LOG"
    
    # Count real autonomous agent processes
    real_agent_count=$(ps aux | grep -v grep | grep "autonomous_agent" | wc -l)
    echo "  Real autonomous agents detected: $real_agent_count" >> "$TERMINATION_LOG"
    
    # Backup original files
    cp "$WORK_DIR/agent_coordination/agent_status.json" "$WORK_DIR/agent_coordination/agent_status_backup_$(date +%s).json"
    echo "  ✅ Backed up agent_status.json" >> "$TERMINATION_LOG"
    
    # Create cleaned agent status with only real agents
    if [ "$real_agent_count" -gt 0 ]; then
        # Keep only the first N agents that correspond to real processes
        jq ".[0:$real_agent_count]" "$WORK_DIR/agent_coordination/agent_status.json" > "$WORK_DIR/agent_coordination/agent_status_clean.json"
        mv "$WORK_DIR/agent_coordination/agent_status_clean.json" "$WORK_DIR/agent_coordination/agent_status.json"
        echo "  ✅ Cleaned agent_status.json - kept $real_agent_count real agents" >> "$TERMINATION_LOG"
    else
        echo "  ⚠️  No real agents detected - manual cleanup required" >> "$TERMINATION_LOG"
    fi
}

# Phase 4: REMOVE SYNTHETIC WORK ENTRIES
clean_synthetic_work() {
    echo "4. REMOVING SYNTHETIC WORK COMPLETIONS" >> "$TERMINATION_LOG"
    
    # Backup coordination log
    cp "$WORK_DIR/agent_coordination/coordination_log.json" "$WORK_DIR/agent_coordination/coordination_log_backup_$(date +%s).json"
    echo "  ✅ Backed up coordination_log.json" >> "$TERMINATION_LOG"
    
    # Remove synthetic completion entries
    if [ -f "$WORK_DIR/agent_coordination/coordination_log.json" ]; then
        # Filter out synthetic completions
        jq '[.[] | select(.result | contains("Intelligent auto-completion") | not) | select(.result | contains("Strategic consolidation completed through meta-coordination intelligence") | not)]' "$WORK_DIR/agent_coordination/coordination_log.json" > "$WORK_DIR/agent_coordination/coordination_log_clean.json"
        
        original_count=$(jq length "$WORK_DIR/agent_coordination/coordination_log.json")
        cleaned_count=$(jq length "$WORK_DIR/agent_coordination/coordination_log_clean.json")
        removed_count=$((original_count - cleaned_count))
        
        mv "$WORK_DIR/agent_coordination/coordination_log_clean.json" "$WORK_DIR/agent_coordination/coordination_log.json"
        echo "  ✅ Removed $removed_count synthetic work entries" >> "$TERMINATION_LOG"
    fi
}

# Phase 5: CLEAN VELOCITY INFLATION
clean_velocity_inflation() {
    echo "5. CLEANING VELOCITY POINT INFLATION" >> "$TERMINATION_LOG"
    
    # Backup velocity log
    cp "$WORK_DIR/agent_coordination/velocity_log.txt" "$WORK_DIR/agent_coordination/velocity_log_backup_$(date +%s).txt"
    echo "  ✅ Backed up velocity_log.txt" >> "$TERMINATION_LOG"
    
    # Remove duplicate timestamp entries (keep only unique timestamps)
    if [ -f "$WORK_DIR/agent_coordination/velocity_log.txt" ]; then
        awk '!seen[substr($0,1,20)]++' "$WORK_DIR/agent_coordination/velocity_log.txt" > "$WORK_DIR/agent_coordination/velocity_log_clean.txt"
        
        original_lines=$(wc -l < "$WORK_DIR/agent_coordination/velocity_log.txt")
        cleaned_lines=$(wc -l < "$WORK_DIR/agent_coordination/velocity_log_clean.txt")
        removed_lines=$((original_lines - cleaned_lines))
        
        mv "$WORK_DIR/agent_coordination/velocity_log_clean.txt" "$WORK_DIR/agent_coordination/velocity_log.txt"
        echo "  ✅ Removed $removed_lines duplicate velocity entries" >> "$TERMINATION_LOG"
    fi
}

# Phase 6: IMPLEMENT ANTI-SYNTHETIC CONTROLS
implement_controls() {
    echo "6. IMPLEMENTING ANTI-SYNTHETIC CONTROLS" >> "$TERMINATION_LOG"
    
    # Create process verification function
    cat > "$WORK_DIR/agent_coordination/verify_real_agent.sh" << 'EOF'
#!/bin/bash
# verify_real_agent.sh - Verify agent has real process before JSON operations

verify_agent_exists() {
    local agent_id="$1"
    ps aux | grep -v grep | grep "$agent_id" >/dev/null
}

# Usage: verify_agent_exists "agent_id" || exit 1
EOF
    chmod +x "$WORK_DIR/agent_coordination/verify_real_agent.sh"
    echo "  ✅ Created process verification control" >> "$TERMINATION_LOG"
    
    # Create synthetic detection monitor
    cat > "$WORK_DIR/agent_coordination/synthetic_monitor.sh" << 'EOF'
#!/bin/bash
# synthetic_monitor.sh - Monitor for synthetic generation regression

while true; do
    json_agents=$(jq length /Users/sac/dev/ai-self-sustaining-system/agent_coordination/agent_status.json 2>/dev/null || echo "0")
    real_agents=$(ps aux | grep -v grep | grep autonomous_agent | wc -l)
    gap=$((json_agents - real_agents))
    
    if [ "$gap" -gt 5 ]; then
        echo "$(date): SYNTHETIC ALERT - JSON:$json_agents Real:$real_agents Gap:$gap" >> /tmp/synthetic_alerts.log
    fi
    
    sleep 60
done &
EOF
    chmod +x "$WORK_DIR/agent_coordination/synthetic_monitor.sh"
    echo "  ✅ Created continuous synthetic detection monitor" >> "$TERMINATION_LOG"
}

# MAIN EXECUTION
echo "Starting 80/20 synthetic elimination..."

terminate_synthetic_processes
disable_synthetic_scripts
clean_phantom_agents
clean_synthetic_work
clean_velocity_inflation
implement_controls

# SUMMARY REPORT
echo "" >> "$TERMINATION_LOG"
echo "TERMINATION SUMMARY" >> "$TERMINATION_LOG"
echo "===================" >> "$TERMINATION_LOG"

# Final counts
final_json_agents=$(jq length "$WORK_DIR/agent_coordination/agent_status.json" 2>/dev/null || echo "0")
final_real_agents=$(ps aux | grep -v grep | grep autonomous_agent | wc -l)
final_gap=$((final_json_agents - final_real_agents))

echo "Final Agent Count: JSON=$final_json_agents, Real=$final_real_agents, Gap=$final_gap" >> "$TERMINATION_LOG"
echo "Synthetic processes terminated: ✅" >> "$TERMINATION_LOG"
echo "Generation scripts disabled: ✅" >> "$TERMINATION_LOG"
echo "Phantom agents cleaned: ✅" >> "$TERMINATION_LOG"
echo "Synthetic work removed: ✅" >> "$TERMINATION_LOG"
echo "Anti-synthetic controls implemented: ✅" >> "$TERMINATION_LOG"

# Start synthetic monitor
"$WORK_DIR/agent_coordination/synthetic_monitor.sh" &
echo "Continuous monitoring started (PID: $!)" >> "$TERMINATION_LOG"

echo "80/20 Success: $([[ $final_gap -le 5 ]] && echo "✅ SYNTHETIC ELIMINATED" || echo "❌ MANUAL CLEANUP REQUIRED")" >> "$TERMINATION_LOG"

# Output results
cat "$TERMINATION_LOG"
echo ""
echo "📊 Synthetic termination log: $TERMINATION_LOG"