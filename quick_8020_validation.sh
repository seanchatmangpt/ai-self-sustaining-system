#!/bin/bash
# 80/20 Quick Validation - Core System Performance Check

set -euo pipefail

echo "🎯 80/20 SYSTEM VALIDATION"
echo "========================="
echo "Timestamp: $(date -Iseconds)"
echo ""

COORD_DIR="./agent_coordination"

# 80/20 Metric 1: Active Agent Performance
echo "📊 ACTIVE AGENT PERFORMANCE (80/20 Critical)"
active_agents=$(jq -r '.[] | select(.status == "active") | .agent_id' "$COORD_DIR/agent_status.json" 2>/dev/null | wc -l)
echo "  Active agents: $active_agents"

# 80/20 Metric 2: Recent Work Completion Rate
echo "📈 RECENT WORK COMPLETION (Last 10 items)"
recent_completions=$(tail -10 "$COORD_DIR/coordination_log.json" 2>/dev/null | jq -r '.result' 2>/dev/null | grep -c "success\|completed" || echo "0")
echo "  Successful completions: $recent_completions/10"

# 80/20 Metric 3: Telemetry Trace Health
echo "🔍 TELEMETRY TRACE HEALTH"
total_traces=$(jq -r '.telemetry.trace_id' "$COORD_DIR/work_claims.json" 2>/dev/null | grep -v "null" | wc -l || echo "0")
echo "  Active traces with IDs: $total_traces"

# 80/20 Metric 4: Performance Benchmark
echo "⚡ COORDINATION PERFORMANCE TEST"
start_time=$(date +%s%3N)
test_trace_id=$(openssl rand -hex 16)
test_operation="{\"test_trace\":\"$test_trace_id\",\"operation\":\"8020_validation\",\"timestamp\":\"$(date -Iseconds)\"}"
echo "$test_operation" >> "$COORD_DIR/telemetry_spans.jsonl" 2>/dev/null || echo "  Telemetry write failed"
end_time=$(date +%s%3N)
operation_time=$((end_time - start_time))
echo "  Test operation time: ${operation_time}ms"

# 80/20 Summary Score
echo ""
echo "🎯 80/20 VALIDATION SCORE"
echo "========================"

score=0
if [ "$active_agents" -gt 5 ]; then
    echo "✅ Agent Performance: PASS ($active_agents active)"
    ((score += 25))
else
    echo "❌ Agent Performance: FAIL ($active_agents active)"
fi

if [ "$recent_completions" -gt 7 ]; then
    echo "✅ Completion Rate: PASS ($recent_completions/10)"
    ((score += 25))
else
    echo "⚠️  Completion Rate: MARGINAL ($recent_completions/10)"
    ((score += 15))
fi

if [ "$total_traces" -gt 3 ]; then
    echo "✅ Trace Health: PASS ($total_traces traces)"
    ((score += 25))
else
    echo "❌ Trace Health: FAIL ($total_traces traces)"
fi

if [ "$operation_time" -lt 150 ]; then
    echo "✅ Performance: PASS (${operation_time}ms)"
    ((score += 25))
else
    echo "⚠️  Performance: MARGINAL (${operation_time}ms)"
    ((score += 15))
fi

echo ""
echo "📊 OVERALL 80/20 SCORE: $score/100"

if [ "$score" -ge 80 ]; then
    echo "🎉 80/20 SUCCESS: System meets enhancement targets"
    exit 0
elif [ "$score" -ge 60 ]; then
    echo "⚠️  80/20 PARTIAL: System needs focused improvements"
    exit 1
else
    echo "❌ 80/20 FAIL: System requires immediate attention"
    exit 2
fi