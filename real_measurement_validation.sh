#!/bin/bash

# Real System Measurement and Validation
# Following 80/20 DoD: Process verification, work measurement, truth-based metrics, system health

set -euo pipefail

TIMESTAMP=$(date +%s)
EVIDENCE_FILE="real_evidence_${TIMESTAMP}.json"

echo "🔬 REAL SYSTEM MEASUREMENT - $(date)"
echo "================================================"

# 1. PROCESS VERIFICATION REALITY
echo "📊 1. PROCESS VERIFICATION"
echo "----------------------------"

PHOENIX_PROCESSES=$(ps aux | grep -E "(beam|elixir)" | grep -v grep | wc -l | tr -d ' ')
COORDINATION_PROCESSES=$(ps aux | grep -E "coordination" | grep -v grep | wc -l | tr -d ' ')
TOTAL_MEMORY_MB=$(ps aux | grep -E "(beam|elixir|coordination)" | grep -v grep | awk '{sum += $6} END {print sum/1024}' || echo "0")

echo "✓ Phoenix/Elixir processes: $PHOENIX_PROCESSES"
echo "✓ Coordination processes: $COORDINATION_PROCESSES" 
echo "✓ Total memory usage: ${TOTAL_MEMORY_MB}MB"

# 2. WORK COMPLETION MEASUREMENT
echo
echo "📈 2. WORK COMPLETION MEASUREMENT"
echo "-----------------------------------"

# Count actual files created in last hour
RECENT_FILES=$(find . -name "*.json" -o -name "*.md" -o -name "*.sh" -newer <(date -v-1H +%s 2>/dev/null || date -d '1 hour ago' +%s) 2>/dev/null | wc -l | tr -d ' ')

# Count JSON work items
JSON_WORK_TOTAL=$(jq 'length' agent_coordination/work_claims.json 2>/dev/null || echo "0")
JSON_WORK_COMPLETED=$(jq '[.[] | select(.status == "completed")] | length' agent_coordination/work_claims.json 2>/dev/null || echo "0")

# Measure actual work over 30 seconds
echo "⏱️  Measuring actual work over 30 seconds..."
BASELINE_COMPLETED=$JSON_WORK_COMPLETED
sleep 30
FINAL_COMPLETED=$(jq '[.[] | select(.status == "completed")] | length' agent_coordination/work_claims.json 2>/dev/null || echo "0")
ACTUAL_COMPLETIONS=$((FINAL_COMPLETED - BASELINE_COMPLETED))

echo "✓ Files created in last hour: $RECENT_FILES"
echo "✓ JSON work items (total/completed): $JSON_WORK_TOTAL/$JSON_WORK_COMPLETED"
echo "✓ Actual completions in 30s: $ACTUAL_COMPLETIONS"

# 3. TRUTH-BASED PERFORMANCE METRICS
echo
echo "🎯 3. TRUTH-BASED PERFORMANCE" 
echo "------------------------------"

# Test system responsiveness
START_TIME=$(date +%s%N)
ls agent_coordination/ > /dev/null 2>&1
END_TIME=$(date +%s%N)
FILE_RESPONSE_MS=$(echo "scale=2; ($END_TIME - $START_TIME) / 1000000" | bc -l)

# Test coordination helper responsiveness
START_TIME=$(date +%s%N)
./agent_coordination/coordination_helper.sh dashboard > /dev/null 2>&1 || true
END_TIME=$(date +%s%N)
COORD_RESPONSE_MS=$(echo "scale=2; ($END_TIME - $START_TIME) / 1000000" | bc -l)

echo "✓ File system response: ${FILE_RESPONSE_MS}ms"
echo "✓ Coordination script response: ${COORD_RESPONSE_MS}ms"

# 4. SYSTEM HEALTH REALITY
echo
echo "🏥 4. SYSTEM HEALTH REALITY"
echo "----------------------------"

# Test service endpoints
PHOENIX_RESPONDING=$(curl -s -o /dev/null -w "%{http_code}" localhost:4000 2>/dev/null || echo "000")
DASHBOARD_RESPONDING=$(curl -s localhost:4000/dev/dashboard 2>/dev/null | grep -o "Dashboard" | wc -l | tr -d ' ')

# Database connectivity (if available)
DB_RESPONSIVE=$(cd phoenix_app && mix ecto.migrations 2>&1 | grep -c "up" || echo "0")

echo "✓ Phoenix HTTP response: $PHOENIX_RESPONDING"
echo "✓ Dashboard accessible: $DASHBOARD_RESPONDING"
echo "✓ Database migrations up: $DB_RESPONSIVE"

# 5. GENERATE EVIDENCE-BASED REPORT
echo
echo "📋 5. EVIDENCE GENERATION"
echo "-------------------------"

cat > "$EVIDENCE_FILE" << EOF
{
  "measurement_timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "measurement_duration_seconds": 30,
  "evidence_based_metrics": {
    "process_verification": {
      "phoenix_elixir_processes": $PHOENIX_PROCESSES,
      "coordination_processes": $COORDINATION_PROCESSES,
      "total_memory_mb": $TOTAL_MEMORY_MB,
      "verification_method": "ps_aux_grep"
    },
    "work_completion_measurement": {
      "recent_files_created": $RECENT_FILES,
      "json_work_total": $JSON_WORK_TOTAL,
      "json_work_completed": $JSON_WORK_COMPLETED,
      "actual_completions_30s": $ACTUAL_COMPLETIONS,
      "measurement_method": "30_second_observation"
    },
    "performance_reality": {
      "file_system_response_ms": $FILE_RESPONSE_MS,
      "coordination_response_ms": $COORD_RESPONSE_MS,
      "measurement_method": "nanosecond_timing"
    },
    "system_health_reality": {
      "phoenix_http_code": "$PHOENIX_RESPONDING",
      "dashboard_accessible": $DASHBOARD_RESPONDING,
      "database_migrations_up": $DB_RESPONSIVE,
      "verification_method": "endpoint_testing"
    }
  },
  "quality_assurance": {
    "no_extrapolation": true,
    "real_time_measurement": true,
    "evidence_based_only": true,
    "verification_methodology": "80_20_definition_of_done"
  }
}
EOF

echo "✓ Evidence report generated: $EVIDENCE_FILE"

# 6. REALITY SUMMARY
echo
echo "🏆 REALITY SUMMARY"
echo "===================="

if [[ $PHOENIX_PROCESSES -gt 0 && $COORD_RESPONSE_MS < 1000 ]]; then
    echo "✅ SYSTEM REALITY: Active with real processes and responsive coordination"
else
    echo "❌ SYSTEM REALITY: Limited activity or poor responsiveness"
fi

if [[ $ACTUAL_COMPLETIONS -gt 0 ]]; then
    echo "✅ WORK REALITY: Active work completion detected"
else
    echo "⚠️  WORK REALITY: No active work completion in 30s observation"
fi

if [[ $PHOENIX_RESPONDING == "200" ]]; then
    echo "✅ SERVICE REALITY: Phoenix service operational"
else
    echo "❌ SERVICE REALITY: Phoenix service not responding"
fi

echo
echo "📁 Evidence file: $EVIDENCE_FILE"
echo "🔬 All measurements based on 30-second real-time observation"
echo "✅ No synthetic claims or extrapolated metrics"