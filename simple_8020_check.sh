#!/bin/bash
# Simple 80/20 Validation

echo "🎯 80/20 SYSTEM CHECK"
echo "===================="

# Count active agents
active_agents=$(jq -r '.[] | select(.status == "active") | .agent_id' agent_coordination/agent_status.json 2>/dev/null | wc -l || echo "0")
echo "Active agents: $active_agents"

# Check recent work
recent_work=$(tail -5 agent_coordination/coordination_log.json 2>/dev/null | grep -c "success\|completed" || echo "0") 
echo "Recent successes: $recent_work/5"

# Check trace activity
trace_count=$(grep -c "trace_id" agent_coordination/work_claims.json 2>/dev/null || echo "0")
echo "Active traces: $trace_count"

# Calculate score
score=0
if [ "$active_agents" -gt 5 ]; then score=$((score + 40)); fi
if [ "$recent_work" -gt 2 ]; then score=$((score + 30)); fi  
if [ "$trace_count" -gt 2 ]; then score=$((score + 30)); fi

echo "Score: $score/100"

if [ "$score" -ge 80 ]; then
    echo "✅ 80/20 SUCCESS"
else
    echo "⚠️  Needs improvement"
fi