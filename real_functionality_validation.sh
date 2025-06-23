#!/bin/bash

# Real Functionality Validation Script
# Tests actual working functionality vs synthetic claims
# Implements 80/20 principle: Test the critical 20% that proves 80% of system works

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIMESTAMP=$(date +%s)
VALIDATION_REPORT="real_functionality_validation_${TIMESTAMP}.json"

echo "🔍 REAL FUNCTIONALITY VALIDATION STARTING"
echo "Time: $(date)"
echo "Report: ${VALIDATION_REPORT}"

# Initialize validation result
cat > "${VALIDATION_REPORT}" << 'EOF'
{
  "validation_timestamp": "",
  "validation_type": "real_functionality_test",
  "methodology": "80_20_evidence_based",
  "http_endpoints": {},
  "file_operations": {},
  "process_verification": {},
  "code_compilation": {},
  "data_consistency": {},
  "overall_status": "unknown",
  "real_vs_synthetic": {},
  "critical_failures": []
}
EOF

# Update timestamp
jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '.validation_timestamp = $ts' "${VALIDATION_REPORT}" > tmp.json && mv tmp.json "${VALIDATION_REPORT}"

log() {
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $1"
}

# Test 1: HTTP Endpoints (Critical 20%)
log "🌐 TESTING HTTP ENDPOINTS..."

test_endpoint() {
    local url="$1"
    local expected_status="$2"
    local test_name="$3"
    
    log "Testing $test_name: $url"
    
    # Test with multiple possible ports
    for port in 4000 4001 4002; do
        local test_url="${url/localhost:PORT/localhost:$port}"
        local response_code=$(curl -s -o /dev/null -w "%{http_code}" "$test_url" 2>/dev/null || echo "000")
        local response_time=$(curl -s -o /dev/null -w "%{time_total}" "$test_url" 2>/dev/null || echo "999")
        
        if [[ "$response_code" == "$expected_status" ]]; then
            log "✅ $test_name WORKING on port $port: $response_code (${response_time}s)"
            echo "$port:$response_code:$response_time"
            return 0
        fi
    done
    
    log "❌ $test_name FAILED on all ports"
    echo "FAILED:000:999"
    return 1
}

# Test health endpoint
HEALTH_RESULT=$(test_endpoint "http://localhost:PORT/api/health" "200" "Health Check")
HEALTH_PORT=$(echo "$HEALTH_RESULT" | cut -d: -f1)
HEALTH_STATUS=$(echo "$HEALTH_RESULT" | cut -d: -f2)
HEALTH_TIME=$(echo "$HEALTH_RESULT" | cut -d: -f3)

# Test agents endpoint (our new implementation)
AGENTS_RESULT=$(test_endpoint "http://localhost:PORT/api/agents" "200" "Agents API")
AGENTS_PORT=$(echo "$AGENTS_RESULT" | cut -d: -f1)
AGENTS_STATUS=$(echo "$AGENTS_RESULT" | cut -d: -f2)
AGENTS_TIME=$(echo "$AGENTS_RESULT" | cut -d: -f3)

# Update validation report with HTTP results
jq --arg health_port "$HEALTH_PORT" \
   --arg health_status "$HEALTH_STATUS" \
   --arg health_time "$HEALTH_TIME" \
   --arg agents_port "$AGENTS_PORT" \
   --arg agents_status "$AGENTS_STATUS" \
   --arg agents_time "$AGENTS_TIME" \
   '.http_endpoints = {
     "health_check": {
       "port": $health_port,
       "status_code": $health_status,
       "response_time": $health_time,
       "working": ($health_status == "200")
     },
     "agents_api": {
       "port": $agents_port,
       "status_code": $agents_status,
       "response_time": $agents_time,
       "working": ($agents_status == "200")
     }
   }' "${VALIDATION_REPORT}" > tmp.json && mv tmp.json "${VALIDATION_REPORT}"

# Test 2: Process Verification
log "⚙️ TESTING RUNNING PROCESSES..."

ELIXIR_PROCESSES=$(ps aux | grep -E "(beam\.smp.*phx\.server|beam\.smp.*mix)" | grep -v grep | wc -l)
PHOENIX_LISTENING=$(lsof -i :4000 -i :4001 -i :4002 2>/dev/null | grep LISTEN | wc -l)

log "Found $ELIXIR_PROCESSES Elixir processes, $PHOENIX_LISTENING listening ports"

jq --argjson elixir_processes "$ELIXIR_PROCESSES" \
   --argjson listening_ports "$PHOENIX_LISTENING" \
   '.process_verification = {
     "elixir_processes": $elixir_processes,
     "listening_ports": $listening_ports,
     "processes_running": ($elixir_processes > 0),
     "ports_listening": ($listening_ports > 0)
   }' "${VALIDATION_REPORT}" > tmp.json && mv tmp.json "${VALIDATION_REPORT}"

# Test 3: Code Compilation
log "🔨 TESTING CODE COMPILATION..."

cd "$SCRIPT_DIR/phoenix_app"
COMPILATION_RESULT=$(mix compile 2>&1)
COMPILATION_SUCCESS=$?

if [[ $COMPILATION_SUCCESS -eq 0 ]]; then
    log "✅ Code compiles successfully"
    COMPILATION_STATUS="success"
else
    log "❌ Code compilation failed"
    COMPILATION_STATUS="failed"
fi

jq --arg status "$COMPILATION_STATUS" \
   --argjson success_code "$COMPILATION_SUCCESS" \
   '.code_compilation = {
     "status": $status,
     "success": ($success_code == 0),
     "exit_code": $success_code
   }' "${VALIDATION_REPORT}" > tmp.json && mv tmp.json "${VALIDATION_REPORT}"

cd "$SCRIPT_DIR"

# Test 4: File Operations (Data Consistency)
log "📁 TESTING FILE OPERATIONS..."

AGENT_FILE_EXISTS=false
WORK_FILE_EXISTS=false
AGENT_COUNT=0
WORK_COUNT=0

if [[ -f "agent_coordination/agent_status.json" ]]; then
    AGENT_FILE_EXISTS=true
    AGENT_COUNT=$(jq length agent_coordination/agent_status.json 2>/dev/null || echo "0")
fi

if [[ -f "agent_coordination/work_claims.json" ]]; then
    WORK_FILE_EXISTS=true
    WORK_COUNT=$(jq length agent_coordination/work_claims.json 2>/dev/null || echo "0")
fi

log "Agent file exists: $AGENT_FILE_EXISTS ($AGENT_COUNT agents)"
log "Work file exists: $WORK_FILE_EXISTS ($WORK_COUNT work items)"

jq --argjson agent_file_exists "$AGENT_FILE_EXISTS" \
   --argjson work_file_exists "$WORK_FILE_EXISTS" \
   --argjson agent_count "$AGENT_COUNT" \
   --argjson work_count "$WORK_COUNT" \
   '.file_operations = {
     "agent_file_exists": $agent_file_exists,
     "work_file_exists": $work_file_exists,
     "agent_count": $agent_count,
     "work_count": $work_count,
     "files_accessible": ($agent_file_exists and $work_file_exists)
   }' "${VALIDATION_REPORT}" > tmp.json && mv tmp.json "${VALIDATION_REPORT}"

# Test 5: Data Consistency (Real vs Synthetic)
log "🔍 TESTING REAL VS SYNTHETIC DATA..."

# Check if agents are just JSON or have real backing
ACTIVE_AGENTS=$(jq '[.[] | select(.status == "active")] | length' agent_coordination/agent_status.json 2>/dev/null || echo "0")
COMPLETED_WORK=$(jq '[.[] | select(.status == "completed")] | length' agent_coordination/work_claims.json 2>/dev/null || echo "0")

# Calculate synthetic score (higher = more synthetic)
SYNTHETIC_SCORE=0

# If we have agents but no working HTTP endpoints, it's synthetic
if [[ $ACTIVE_AGENTS -gt 0 && "$HEALTH_STATUS" != "200" ]]; then
    SYNTHETIC_SCORE=$((SYNTHETIC_SCORE + 40))
fi

# If we have work claims but no processes, it's synthetic
if [[ $COMPLETED_WORK -gt 0 && $ELIXIR_PROCESSES -eq 0 ]]; then
    SYNTHETIC_SCORE=$((SYNTHETIC_SCORE + 40))
fi

# If we have many agents but no listening ports, it's synthetic
if [[ $ACTIVE_AGENTS -gt 10 && $PHOENIX_LISTENING -eq 0 ]]; then
    SYNTHETIC_SCORE=$((SYNTHETIC_SCORE + 20))
fi

REAL_SCORE=$((100 - SYNTHETIC_SCORE))

if [[ $REAL_SCORE -ge 80 ]]; then
    REALITY_STATUS="mostly_real"
elif [[ $REAL_SCORE -ge 50 ]]; then
    REALITY_STATUS="mixed"
else
    REALITY_STATUS="mostly_synthetic"
fi

log "Reality Score: $REAL_SCORE% ($REALITY_STATUS)"

jq --argjson active_agents "$ACTIVE_AGENTS" \
   --argjson completed_work "$COMPLETED_WORK" \
   --argjson synthetic_score "$SYNTHETIC_SCORE" \
   --argjson real_score "$REAL_SCORE" \
   --arg reality_status "$REALITY_STATUS" \
   '.real_vs_synthetic = {
     "active_agents_claimed": $active_agents,
     "completed_work_claimed": $completed_work,
     "synthetic_score": $synthetic_score,
     "real_score": $real_score,
     "reality_status": $reality_status
   }' "${VALIDATION_REPORT}" > tmp.json && mv tmp.json "${VALIDATION_REPORT}"

# Calculate Overall Status
log "📊 CALCULATING OVERALL STATUS..."

CRITICAL_FAILURES=()

if [[ "$HEALTH_STATUS" != "200" ]]; then
    CRITICAL_FAILURES+=("health_endpoint_not_working")
fi

if [[ $ELIXIR_PROCESSES -eq 0 ]]; then
    CRITICAL_FAILURES+=("no_elixir_processes")
fi

if [[ $COMPILATION_SUCCESS -ne 0 ]]; then
    CRITICAL_FAILURES+=("code_compilation_failed")
fi

if [[ ! -f "agent_coordination/agent_status.json" ]]; then
    CRITICAL_FAILURES+=("agent_data_missing")
fi

FAILURE_COUNT=${#CRITICAL_FAILURES[@]}

if [[ $FAILURE_COUNT -eq 0 ]]; then
    OVERALL_STATUS="functional"
elif [[ $FAILURE_COUNT -le 2 ]]; then
    OVERALL_STATUS="partially_functional"
else
    OVERALL_STATUS="non_functional"
fi

# Convert failures array to JSON
FAILURES_JSON=$(printf '%s\n' "${CRITICAL_FAILURES[@]}" | jq -R . | jq -s .)

jq --arg status "$OVERALL_STATUS" \
   --argjson failures "$FAILURES_JSON" \
   --argjson failure_count "$FAILURE_COUNT" \
   '.overall_status = $status |
    .critical_failures = $failures |
    .summary = {
      "total_failures": $failure_count,
      "status": $status,
      "recommendation": (if $failure_count == 0 then "system_operational" 
                        elif $failure_count <= 2 then "needs_minor_fixes" 
                        else "requires_major_repairs" end)
    }' "${VALIDATION_REPORT}" > tmp.json && mv tmp.json "${VALIDATION_REPORT}"

echo ""
echo "🏁 REAL FUNCTIONALITY VALIDATION COMPLETE"
echo "Overall Status: ${OVERALL_STATUS}"
echo "Reality Score: ${REAL_SCORE}%"
echo "Critical Failures: ${FAILURE_COUNT}"
echo "Report: ${VALIDATION_REPORT}"
echo ""

# Display summary
jq -r '
"=== REAL FUNCTIONALITY VALIDATION SUMMARY ===
HTTP Endpoints: Health=\(.http_endpoints.health_check.working) Agents=\(.http_endpoints.agents_api.working)
Processes: \(.process_verification.elixir_processes) Elixir processes, \(.process_verification.listening_ports) listening ports
Code: Compilation \(.code_compilation.status)
Data: \(.file_operations.agent_count) agents, \(.file_operations.work_count) work items
Reality: \(.real_vs_synthetic.real_score)% real (\(.real_vs_synthetic.reality_status))
Overall: \(.overall_status | ascii_upcase) with \(.summary.total_failures) critical failures
Recommendation: \(.summary.recommendation)"
' "${VALIDATION_REPORT}"

echo ""
if [[ ${#CRITICAL_FAILURES[@]} -gt 0 ]]; then
    echo "🚨 Critical Failures Detected:"
    for failure in "${CRITICAL_FAILURES[@]}"; do
        echo "   - $failure"
    done
    echo ""
fi

if [[ $REAL_SCORE -ge 80 ]]; then
    echo "✅ System is mostly REAL and functional"
elif [[ $REAL_SCORE -ge 50 ]]; then
    echo "⚠️  System is mixed REAL/SYNTHETIC - needs improvement"
else
    echo "❌ System is mostly SYNTHETIC - major fixes needed"
fi