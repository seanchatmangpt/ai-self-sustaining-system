#!/bin/bash
# real_measurement_system.sh - 80/20 Real Results Implementation
# Replaces synthetic measurements with evidence-based verification

set -e

MEASUREMENT_LOG="/tmp/real_measurements_$(date +%s).log"
WORK_DIR="/Users/sac/dev/ai-self-sustaining-system"

# Initialize measurement report
echo "REAL MEASUREMENT SYSTEM - $(date)" > "$MEASUREMENT_LOG"
echo "=======================================" >> "$MEASUREMENT_LOG"

# 1. REAL AGENT COUNT (Process-based vs JSON-based)
measure_real_agents() {
    echo "1. AGENT COUNT VERIFICATION" >> "$MEASUREMENT_LOG"
    
    # Count actual running agent processes
    real_agents=$(ps aux | grep -v grep | grep "autonomous_agent" | wc -l)
    
    # Count JSON agent entries
    if [ -f "$WORK_DIR/agent_coordination/agent_status.json" ]; then
        json_agents=$(jq length "$WORK_DIR/agent_coordination/agent_status.json" 2>/dev/null || echo "0")
    else
        json_agents=0
    fi
    
    echo "  Real agent processes: $real_agents" >> "$MEASUREMENT_LOG"
    echo "  JSON agent entries: $json_agents" >> "$MEASUREMENT_LOG"
    echo "  Verification: $([[ $real_agents -gt 0 ]] && echo "✅ REAL AGENTS DETECTED" || echo "❌ NO REAL AGENTS")" >> "$MEASUREMENT_LOG"
    echo "  Synthetic gap: $((json_agents - real_agents)) non-existent agents in JSON" >> "$MEASUREMENT_LOG"
    
    # Return real count for further calculations
    echo "$real_agents"
}

# 2. REAL OPERATIONS MEASUREMENT (Process activity vs JSON points)
measure_real_operations() {
    echo "2. OPERATIONS MEASUREMENT" >> "$MEASUREMENT_LOG"
    
    # Baseline process count
    start_time=$(date +%s)
    start_processes=$(ps aux | wc -l)
    
    # Short measurement window (30 seconds scaled to 1 hour)
    echo "  Measuring process activity for 30 seconds..." >> "$MEASUREMENT_LOG"
    sleep 30
    
    end_time=$(date +%s)
    end_processes=$(ps aux | wc -l)
    
    # Calculate real operations per hour
    process_delta=$((end_processes - start_processes))
    measurement_duration=$((end_time - start_time))
    ops_per_hour=$(((process_delta * 3600) / measurement_duration))
    
    # Check for autonomous agent activity
    agent_work_files=$(ls /tmp/agent_work_* 2>/dev/null | wc -l)
    
    echo "  Process changes in ${measurement_duration}s: $process_delta" >> "$MEASUREMENT_LOG"
    echo "  Calculated ops/hour: $ops_per_hour" >> "$MEASUREMENT_LOG"
    echo "  Autonomous work artifacts: $agent_work_files files" >> "$MEASUREMENT_LOG"
    echo "  Verification: $([[ $ops_per_hour -gt 0 ]] && echo "✅ REAL ACTIVITY DETECTED" || echo "❌ NO MEASURABLE ACTIVITY")" >> "$MEASUREMENT_LOG"
    
    echo "$ops_per_hour"
}

# 3. REAL SUCCESS RATE (Process exit codes vs 100% synthetic)
calculate_real_success_rate() {
    echo "3. SUCCESS RATE VERIFICATION" >> "$MEASUREMENT_LOG"
    
    # Check autonomous agent logs for real success/failure patterns
    total_operations=0
    failed_operations=0
    
    if ls /tmp/autonomous_agent_*.log >/dev/null 2>&1; then
        total_operations=$(grep -h "completed\|FAILED" /tmp/autonomous_agent_*.log | wc -l)
        failed_operations=$(grep -h "FAILED" /tmp/autonomous_agent_*.log | wc -l)
    fi
    
    if [ "$total_operations" -gt 0 ]; then
        success_rate=$(echo "scale=2; (($total_operations - $failed_operations) * 100) / $total_operations" | bc)
    else
        success_rate="0.00"
    fi
    
    echo "  Total operations: $total_operations" >> "$MEASUREMENT_LOG"
    echo "  Failed operations: $failed_operations" >> "$MEASUREMENT_LOG"
    echo "  Real success rate: ${success_rate}%" >> "$MEASUREMENT_LOG"
    echo "  Verification: $([[ $(echo "$success_rate < 100" | bc) -eq 1 ]] && echo "✅ REALISTIC SUCCESS RATE" || echo "❌ UNREALISTIC 100% OR NO DATA")" >> "$MEASUREMENT_LOG"
    
    echo "$success_rate"
}

# 4. REAL SYSTEM HEALTH (Service availability vs calculated scores)
check_real_system_health() {
    echo "4. SYSTEM HEALTH VERIFICATION" >> "$MEASUREMENT_LOG"
    
    # Check critical services
    phoenix_status=$(curl -s http://localhost:4002 >/dev/null 2>&1 && echo "UP" || echo "DOWN")
    postgres_status=$(pg_isready -h localhost >/dev/null 2>&1 && echo "UP" || echo "DOWN")
    grafana_status=$(curl -s http://localhost:3000 >/dev/null 2>&1 && echo "UP" || echo "DOWN")
    
    # Calculate real health based on critical services
    services_up=0
    [[ "$phoenix_status" == "UP" ]] && ((services_up++))
    [[ "$postgres_status" == "UP" ]] && ((services_up++))
    [[ "$grafana_status" == "UP" ]] && ((services_up++))
    
    real_health_score=$(echo "scale=2; ($services_up * 100) / 3" | bc)
    
    echo "  Phoenix (critical): $phoenix_status" >> "$MEASUREMENT_LOG"
    echo "  PostgreSQL (critical): $postgres_status" >> "$MEASUREMENT_LOG"
    echo "  Grafana (monitoring): $grafana_status" >> "$MEASUREMENT_LOG"
    echo "  Real health score: ${real_health_score}%" >> "$MEASUREMENT_LOG"
    echo "  Verification: $([[ "$phoenix_status" == "UP" && "$postgres_status" == "UP" ]] && echo "✅ CORE SERVICES OPERATIONAL" || echo "❌ CRITICAL SERVICES DOWN")" >> "$MEASUREMENT_LOG"
    
    echo "$real_health_score"
}

# 5. REAL VELOCITY (Feature delivery vs abstract points)
measure_real_velocity() {
    echo "5. VELOCITY MEASUREMENT" >> "$MEASUREMENT_LOG"
    
    cd "$WORK_DIR" || exit 1
    
    # Count actual features and fixes delivered in last week
    deployed_features=$(git log --since="1 week ago" --grep="feat:" --oneline 2>/dev/null | wc -l)
    fixed_bugs=$(git log --since="1 week ago" --grep="fix:" --oneline 2>/dev/null | wc -l)
    
    # Real velocity based on delivered value
    real_velocity=$((deployed_features * 8 + fixed_bugs * 3))
    
    # Compare with JSON velocity points
    json_velocity=$(tail -10 "$WORK_DIR/agent_coordination/velocity_log.txt" 2>/dev/null | grep -o '+[0-9]*' | sed 's/+//' | awk '{sum+=$1} END{print sum}' || echo "0")
    
    echo "  Features deployed (1 week): $deployed_features" >> "$MEASUREMENT_LOG"
    echo "  Bugs fixed (1 week): $fixed_bugs" >> "$MEASUREMENT_LOG"
    echo "  Real velocity points: $real_velocity" >> "$MEASUREMENT_LOG"
    echo "  JSON velocity points: $json_velocity" >> "$MEASUREMENT_LOG"
    echo "  Verification: $([[ $real_velocity -gt 0 ]] && echo "✅ REAL DELIVERY DETECTED" || echo "❌ NO MEASURABLE DELIVERY")" >> "$MEASUREMENT_LOG"
    
    echo "$real_velocity"
}

# 6. REAL TRACE VALIDATION (Distributed vs single-process)
validate_real_traces() {
    echo "6. TRACE CORRELATION VERIFICATION" >> "$MEASUREMENT_LOG"
    
    # Check if Jaeger is accessible
    if curl -s "http://localhost:16686/api/services" >/dev/null 2>&1; then
        # Get recent traces and check service distribution
        services_in_traces=$(curl -s "http://localhost:16686/api/traces?limit=10" | jq -r '.data[].spans[].process.serviceName' 2>/dev/null | sort -u | wc -l)
        total_traces=$(curl -s "http://localhost:16686/api/traces?limit=10" | jq -r '.data | length' 2>/dev/null || echo "0")
    else
        services_in_traces=0
        total_traces=0
    fi
    
    echo "  Jaeger accessibility: $([[ $total_traces -gt 0 ]] && echo "✅ ACCESSIBLE" || echo "❌ UNAVAILABLE")" >> "$MEASUREMENT_LOG"
    echo "  Traces found: $total_traces" >> "$MEASUREMENT_LOG"
    echo "  Unique services in traces: $services_in_traces" >> "$MEASUREMENT_LOG"
    echo "  Verification: $([[ $services_in_traces -gt 1 ]] && echo "✅ REAL DISTRIBUTED TRACES" || echo "❌ SINGLE-SERVICE OR NO TRACES")" >> "$MEASUREMENT_LOG"
    
    echo "$services_in_traces"
}

# 7. REAL AUTONOMY VERIFICATION (Independent activity vs correlated)
verify_real_autonomy() {
    echo "7. AUTONOMY VERIFICATION" >> "$MEASUREMENT_LOG"
    
    # Check for running autonomous processes
    autonomous_processes=$(ps aux | grep -v grep | grep "autonomous_agent" | wc -l)
    
    # Check for recent autonomous activity
    recent_work_files=$(find /tmp -name "agent_work_*" -mtime -1 2>/dev/null | wc -l)
    
    # Check timing independence (autonomous activity during measurement)
    if [ "$autonomous_processes" -gt 0 ]; then
        latest_log=$(ls -t /tmp/autonomous_agent_*.log 2>/dev/null | head -1)
        if [ -n "$latest_log" ]; then
            recent_activity=$(tail -5 "$latest_log" | grep -c "$(date '+%Y-%m-%d')" || echo "0")
        else
            recent_activity=0
        fi
    else
        recent_activity=0
    fi
    
    echo "  Autonomous processes: $autonomous_processes" >> "$MEASUREMENT_LOG"
    echo "  Recent work artifacts: $recent_work_files" >> "$MEASUREMENT_LOG"
    echo "  Today's autonomous activity: $recent_activity operations" >> "$MEASUREMENT_LOG"
    echo "  Verification: $([[ $autonomous_processes -gt 0 && $recent_activity -gt 0 ]] && echo "✅ REAL AUTONOMOUS BEHAVIOR" || echo "❌ NO AUTONOMOUS ACTIVITY")" >> "$MEASUREMENT_LOG"
    
    echo "$autonomous_processes"
}

# MAIN MEASUREMENT EXECUTION
echo "Starting 80/20 real measurement system..."

# Execute all measurements
real_agents=$(measure_real_agents)
real_ops=$(measure_real_operations)
real_success=$(calculate_real_success_rate)
real_health=$(check_real_system_health)
real_velocity=$(measure_real_velocity)
real_traces=$(validate_real_traces)
real_autonomy=$(verify_real_autonomy)

# SUMMARY REPORT
echo "" >> "$MEASUREMENT_LOG"
echo "SUMMARY: REAL vs SYNTHETIC COMPARISON" >> "$MEASUREMENT_LOG"
echo "=======================================" >> "$MEASUREMENT_LOG"
echo "Real Agents: $real_agents (vs JSON simulation)" >> "$MEASUREMENT_LOG"
echo "Real Ops/Hour: $real_ops (vs calculated estimates)" >> "$MEASUREMENT_LOG"
echo "Real Success Rate: ${real_success}% (vs 100% synthetic)" >> "$MEASUREMENT_LOG"
echo "Real Health: ${real_health}% (vs formula-based scores)" >> "$MEASUREMENT_LOG"
echo "Real Velocity: $real_velocity points (vs JSON accumulation)" >> "$MEASUREMENT_LOG"
echo "Real Distributed Services: $real_traces (vs single-process traces)" >> "$MEASUREMENT_LOG"
echo "Real Autonomous Processes: $real_autonomy (vs JSON entries)" >> "$MEASUREMENT_LOG"

# VERIFICATION SCORE
verification_score=0
[[ $real_agents -gt 0 ]] && ((verification_score++))
[[ $real_ops -gt 0 ]] && ((verification_score++))
[[ $(echo "$real_success < 100 && $real_success > 0" | bc) -eq 1 ]] && ((verification_score++))
[[ $(echo "$real_health > 0" | bc) -eq 1 ]] && ((verification_score++))
[[ $real_velocity -gt 0 ]] && ((verification_score++))
[[ $real_traces -gt 1 ]] && ((verification_score++))
[[ $real_autonomy -gt 0 ]] && ((verification_score++))

reality_percentage=$(echo "scale=0; ($verification_score * 100) / 7" | bc)

echo "" >> "$MEASUREMENT_LOG"
echo "REALITY VERIFICATION SCORE: ${verification_score}/7 (${reality_percentage}%)" >> "$MEASUREMENT_LOG"
echo "80/20 SUCCESS: $([[ $reality_percentage -ge 80 ]] && echo "✅ REAL SYSTEM ACHIEVED" || echo "❌ STILL SYNTHETIC ($reality_percentage% real)")" >> "$MEASUREMENT_LOG"

# Output results
cat "$MEASUREMENT_LOG"
echo ""
echo "📊 Real measurement log saved to: $MEASUREMENT_LOG"