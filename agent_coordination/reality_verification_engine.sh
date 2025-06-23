#!/bin/bash

# Reality Verification Engine - Real Evidence Collection
# NO synthetic metrics, NO circular validation, ONLY observable evidence

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COORDINATION_ROOT="$SCRIPT_DIR"

# Colors for reality output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"; }
reality() { echo -e "${GREEN}📊 REALITY: $1${NC}"; }
false_claim() { echo -e "${RED}❌ FALSE: $1${NC}"; }

# Definition of Done for REAL verification
define_real_verification_dod() {
    cat << 'EOF'
REAL VERIFICATION DEFINITION OF DONE:

CRITICAL REQUIREMENTS (Must verify for confidence):
1. ACTUAL performance: Measure real work completion over time
2. ACTUAL infrastructure: Test real system responses, not connectivity
3. ACTUAL agents: Count processes/services actually running
4. ACTUAL health: Measure system responsiveness under load

SUPPORTING METRICS (Nice to have but not essential):
- Grafana dashboard prettiness
- JSON file completeness  
- Mathematical precision claims
- Theoretical throughput calculations

VERIFICATION CRITERIA:
- NO extrapolation from micro-benchmarks
- NO circular self-validation
- NO testing claims against other claims
- ONLY observable, measurable, repeatable evidence

REALITY THRESHOLD: Claims within 25% of measured reality = VALID
EOF
}

# Measure ACTUAL performance over real time
measure_actual_performance() {
    local reality_trace="reality_$(date +%s%N)"
    local work_file="$COORDINATION_ROOT/work_claims.json"
    local results_file="$COORDINATION_ROOT/actual_performance_$reality_trace.json"
    
    log "Measuring ACTUAL performance over real time..."
    
    # Baseline: Current completed work
    local baseline_completed=$(jq '[.[] | select(.status == "completed")] | length' "$work_file")
    local baseline_time=$(date +%s)
    
    # Wait and measure real work completion (30 seconds observation)
    log "Observing actual work completion for 30 seconds..."
    sleep 30
    
    # Measure actual completion
    local final_completed=$(jq '[.[] | select(.status == "completed")] | length' "$work_file")
    local final_time=$(date +%s)
    local actual_duration=$((final_time - baseline_time))
    local actual_completions=$((final_completed - baseline_completed))
    
    # Calculate REAL operations per hour
    local real_ops_hour=0
    if [[ $actual_duration -gt 0 ]]; then
        real_ops_hour=$(echo "scale=1; $actual_completions * 3600 / $actual_duration" | bc -l)
    fi
    
    # Calculate REAL completion rate
    local total_work=$(jq 'length' "$work_file")
    local real_completion_rate=$(echo "scale=2; $final_completed * 100 / $total_work" | bc -l)
    
    cat > "$results_file" << EOF
{
  "reality_trace_id": "$reality_trace",
  "timestamp": "$(date -Iseconds)",
  "actual_performance": {
    "observation_duration_seconds": $actual_duration,
    "actual_completions": $actual_completions,
    "real_operations_per_hour": $real_ops_hour,
    "real_completion_rate": $real_completion_rate,
    "baseline_completed": $baseline_completed,
    "final_completed": $final_completed,
    "total_work_items": $total_work
  },
  "verification_method": "real_time_observation",
  "no_extrapolation": true
}
EOF
    
    reality "Real ops/hour: $real_ops_hour (observed over $actual_duration seconds)"
    reality "Real completion rate: $real_completion_rate%"
    reality "Actual completions in timeframe: $actual_completions"
    
    echo "$results_file"
}

# Count ACTUAL running processes/agents
count_actual_agents() {
    local reality_trace="$1"
    local agent_file="$COORDINATION_ROOT/agent_status.json"
    local results_file="$COORDINATION_ROOT/actual_agents_$reality_trace.json"
    
    log "Counting ACTUAL running agents..."
    
    # JSON entries (what we've been measuring)
    local json_agents=$(jq 'length' "$agent_file" 2>/dev/null || echo "0")
    
    # Actual coordination processes
    local coordination_processes=$(pgrep -f coordination_helper | wc -l)
    local shell_processes=$(pgrep -f "reactor_id.*shell_agent" | wc -l || echo "0")
    local agent_processes=$(pgrep -f "agent_" | wc -l || echo "0")
    
    # Memory usage of coordination system
    local memory_usage=$(ps aux | grep coordination | grep -v grep | awk '{sum+=$6} END {print sum/1024}' || echo "0")
    
    cat > "$results_file" << EOF
{
  "reality_trace_id": "$reality_trace",
  "timestamp": "$(date -Iseconds)",
  "actual_agents": {
    "json_entries": $json_agents,
    "coordination_processes": $coordination_processes,
    "shell_processes": $shell_processes,
    "agent_processes": $agent_processes,
    "memory_usage_mb": $memory_usage
  },
  "reality_check": {
    "json_vs_processes": "$(echo "scale=1; $coordination_processes * 100 / $json_agents" | bc -l)% actual",
    "process_efficiency": "$(echo "scale=2; $memory_usage / $json_agents" | bc -l) MB per agent entry"
  }
}
EOF
    
    reality "JSON agent entries: $json_agents"
    reality "Actual coordination processes: $coordination_processes"
    reality "Memory usage: ${memory_usage} MB"
    
    if [[ $coordination_processes -lt 5 ]]; then
        false_claim "Agent swarm claims vs $coordination_processes actual processes"
    fi
    
    echo "$results_file"
}

# Test ACTUAL system responsiveness
test_actual_system_health() {
    local reality_trace="$1"
    local results_file="$COORDINATION_ROOT/actual_health_$reality_trace.json"
    
    log "Testing ACTUAL system responsiveness..."
    
    # Test coordination system response time
    local start_time=$(date +%s%N)
    "$COORDINATION_ROOT/coordination_helper.sh" status > /dev/null 2>&1
    local end_time=$(date +%s%N)
    local response_time_ms=$(echo "scale=2; ($end_time - $start_time) / 1000000" | bc -l)
    
    # Test file system responsiveness
    local file_start=$(date +%s%N)
    ls "$COORDINATION_ROOT"/*.json > /dev/null 2>&1
    local file_end=$(date +%s%N)
    local file_response_ms=$(echo "scale=2; ($file_end - $file_start) / 1000000" | bc -l)
    
    # Test JSON parsing responsiveness
    local json_start=$(date +%s%N)
    jq '.[] | length' "$COORDINATION_ROOT/work_claims.json" > /dev/null 2>&1
    local json_end=$(date +%s%N)
    local json_response_ms=$(echo "scale=2; ($json_end - $json_start) / 1000000" | bc -l)
    
    # Calculate actual health score (based on responsiveness)
    local health_score=100
    if (( $(echo "$response_time_ms > 1000" | bc -l) )); then
        health_score=$((health_score - 30))
    fi
    if (( $(echo "$file_response_ms > 500" | bc -l) )); then
        health_score=$((health_score - 20))  
    fi
    if (( $(echo "$json_response_ms > 200" | bc -l) )); then
        health_score=$((health_score - 10))
    fi
    
    cat > "$results_file" << EOF
{
  "reality_trace_id": "$reality_trace",
  "timestamp": "$(date -Iseconds)",
  "actual_health": {
    "coordination_response_ms": $response_time_ms,
    "file_system_response_ms": $file_response_ms,
    "json_parsing_response_ms": $json_response_ms,
    "calculated_health_score": $health_score
  },
  "health_criteria": {
    "coordination_threshold_ms": 1000,
    "file_threshold_ms": 500,
    "json_threshold_ms": 200
  },
  "measurement_method": "actual_system_responsiveness"
}
EOF
    
    reality "Coordination response: ${response_time_ms}ms"
    reality "File system response: ${file_response_ms}ms"
    reality "Health score: $health_score% (responsiveness-based)"
    
    echo "$results_file"
}

# Compare claims with reality
compare_claims_with_reality() {
    local performance_file="$1"
    local agents_file="$2"
    local health_file="$3"
    local comparison_file="$COORDINATION_ROOT/reality_comparison_$(date +%s%N).json"
    
    log "Comparing claims with measured reality..."
    
    # Extract reality measurements
    local real_ops_hour=$(jq -r '.actual_performance.real_operations_per_hour' "$performance_file")
    local real_completion=$(jq -r '.actual_performance.real_completion_rate' "$performance_file")
    local actual_processes=$(jq -r '.actual_agents.coordination_processes' "$agents_file")
    local actual_health=$(jq -r '.actual_health.calculated_health_score' "$health_file")
    
    # Common false claims to check
    local claimed_ops_hour=148
    local claimed_health=95
    local claimed_agents_count=50
    
    # Calculate accuracy
    local ops_accuracy=$(echo "scale=1; $real_ops_hour * 100 / $claimed_ops_hour" | bc -l 2>/dev/null || echo "0")
    local health_accuracy=$(echo "scale=1; $actual_health * 100 / $claimed_health" | bc -l)
    local agent_accuracy=$(echo "scale=1; $actual_processes * 100 / $claimed_agents_count" | bc -l)
    
    cat > "$comparison_file" << EOF
{
  "timestamp": "$(date -Iseconds)",
  "reality_check": {
    "performance": {
      "claimed_ops_hour": $claimed_ops_hour,
      "actual_ops_hour": $real_ops_hour,
      "accuracy_percent": $ops_accuracy
    },
    "health": {
      "claimed_health": $claimed_health,
      "actual_health": $actual_health,
      "accuracy_percent": $health_accuracy
    },
    "agents": {
      "claimed_agents": $claimed_agents_count,
      "actual_processes": $actual_processes,
      "accuracy_percent": $agent_accuracy
    }
  },
  "verdict": {
    "performance_realistic": $([ $(echo "$ops_accuracy > 25 && $ops_accuracy < 400" | bc -l) ] && echo "true" || echo "false"),
    "health_realistic": $([ $(echo "$health_accuracy > 25 && $health_accuracy < 400" | bc -l) ] && echo "true" || echo "false"),
    "agents_realistic": $([ $(echo "$agent_accuracy > 25 && $agent_accuracy < 400" | bc -l) ] && echo "true" || echo "false")
  }
}
EOF
    
    reality "Operations accuracy: $ops_accuracy% (claimed: $claimed_ops_hour, actual: $real_ops_hour)"
    reality "Health accuracy: $health_accuracy% (claimed: $claimed_health, actual: $actual_health)"
    reality "Agent accuracy: $agent_accuracy% (claimed: $claimed_agents_count, actual: $actual_processes)"
    
    echo "$comparison_file"
}

# Main reality verification
main() {
    echo -e "${PURPLE}🔍 REALITY VERIFICATION ENGINE${NC}"
    echo -e "${PURPLE}===============================${NC}"
    echo
    define_real_verification_dod
    echo
    
    # Step 1: Measure actual performance
    local performance_file=$(measure_actual_performance)
    
    # Step 2: Count actual agents
    local reality_trace=$(basename "$performance_file" | sed 's/actual_performance_//;s/.json//')
    local agents_file=$(count_actual_agents "$reality_trace")
    
    # Step 3: Test actual health
    local health_file=$(test_actual_system_health "$reality_trace")
    
    # Step 4: Compare with claims
    local comparison_file=$(compare_claims_with_reality "$performance_file" "$agents_file" "$health_file")
    
    echo
    reality "Reality verification completed"
    reality "Evidence files: $(ls actual_*$reality_trace*.json reality_comparison_*.json | tr '\n' ' ')"
}

# Check dependencies
for cmd in jq bc; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "Error: $cmd is required but not installed"
        exit 1
    fi
done

main "$@"