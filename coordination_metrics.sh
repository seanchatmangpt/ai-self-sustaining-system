#!/bin/bash
# Simple coordination metrics

get_coordination_metrics() {
    local coord_dir="/Users/sac/dev/ai-self-sustaining-system/agent_coordination"
    
    # Count active agents
    local active_agents=$(jq length "$coord_dir/agent_status.json" 2>/dev/null || echo "0")
    
    # Count active work
    local active_work=$(jq -r '.[] | select(.status == "active") | .work_item_id' "$coord_dir/work_claims.json" 2>/dev/null | wc -l || echo "0")
    
    # Recent completions
    local recent_completions=$(tail -10 "$coord_dir/coordination_log.json" | grep -c "completed_at" || echo "0")
    
    echo "📊 Coordination Metrics:"
    echo "  Active agents: $active_agents"
    echo "  Active work: $active_work"
    echo "  Recent completions: $recent_completions"
}

get_coordination_metrics
