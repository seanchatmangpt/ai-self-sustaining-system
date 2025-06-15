#!/bin/bash

# S@S Agent Swarm Orchestrator
# Advanced multi-agent coordination system with Claude Code CLI integration

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WORKTREES_DIR="$PROJECT_ROOT/worktrees"
SHARED_COORDINATION_DIR="$PROJECT_ROOT/shared_coordination"

# Swarm configuration
SWARM_ID="${SWARM_ID:-swarm_$(date +%s%N)}"
SWARM_CONFIG_FILE="$SHARED_COORDINATION_DIR/swarm_config.json"
SWARM_STATE_FILE="$SHARED_COORDINATION_DIR/swarm_state.json"

# OpenTelemetry configuration
OTEL_SERVICE_NAME="${OTEL_SERVICE_NAME:-s2s-agent-swarm}"
export OTEL_SERVICE_NAME

# Generate trace ID for swarm operations
generate_trace_id() {
    echo "$(openssl rand -hex 16)"
}

# Initialize swarm coordination
init_swarm() {
    echo "🤖 INITIALIZING AGENT SWARM"
    echo "=========================="
    echo "🆔 Swarm ID: $SWARM_ID"
    echo ""
    
    mkdir -p "$SHARED_COORDINATION_DIR"
    
    # Create default swarm configuration
    if [ ! -f "$SWARM_CONFIG_FILE" ]; then
        cat > "$SWARM_CONFIG_FILE" <<EOF
{
  "swarm_id": "$SWARM_ID",
  "coordination_strategy": "distributed_consensus",
  "claude_integration": {
    "output_format": "json",
    "intelligence_mode": "structured",
    "coordination_context": "s2s_swarm"
  },
  "worktrees": [
    {
      "name": "ash-phoenix-migration",
      "agent_count": 2,
      "specialization": "ash_migration",
      "focus_areas": ["schema_migration", "action_conversion", "testing"],
      "claude_config": {
        "focus": "ash_framework",
        "output_format": "json",
        "agent_mode": true
      }
    },
    {
      "name": "n8n-improvements",
      "agent_count": 1,
      "specialization": "n8n_integration", 
      "focus_areas": ["workflow_optimization", "api_integration"],
      "claude_config": {
        "focus": "n8n_workflows",
        "output_format": "json",
        "agent_mode": true
      }
    },
    {
      "name": "performance-boost",
      "agent_count": 1,
      "specialization": "performance_optimization",
      "focus_areas": ["benchmarking", "profiling", "optimization"],
      "claude_config": {
        "focus": "performance",
        "output_format": "json", 
        "agent_mode": true
      }
    }
  ],
  "coordination_rules": {
    "max_concurrent_work_per_agent": 3,
    "cross_team_collaboration": true,
    "automatic_load_balancing": true,
    "conflict_resolution": "claude_mediated",
    "heartbeat_interval": 60,
    "scaling_strategy": "demand_based"
  }
}
EOF
    fi
    
    # Initialize swarm state
    cat > "$SWARM_STATE_FILE" <<EOF
{
  "swarm_id": "$SWARM_ID",
  "status": "initializing",
  "created_at": "$(python3 -c "import datetime; print(datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%S.%fZ')[:-3]+'Z')")",
  "active_agents": 0,
  "total_capacity": 0,
  "utilized_capacity": 0,
  "coordination_efficiency": 0.0,
  "cross_worktree_collaboration": {
    "active_collaborations": 0,
    "pending_handoffs": 0,
    "shared_resources": []
  },
  "recent_decisions": []
}
EOF
    
    echo "✅ Swarm coordination initialized"
}

# Deploy agent swarm based on configuration
deploy_swarm() {
    local trace_id=$(generate_trace_id)
    echo "🚀 DEPLOYING AGENT SWARM"
    echo "======================="
    echo "🔍 Trace ID: $trace_id"
    echo ""
    
    if [ ! -f "$SWARM_CONFIG_FILE" ]; then
        echo "❌ Swarm configuration not found. Run 'init' first."
        return 1
    fi
    
    # Deploy agents to each configured worktree
    jq -c '.worktrees[]' "$SWARM_CONFIG_FILE" | while read -r worktree_config; do
        worktree_name=$(echo "$worktree_config" | jq -r '.name')
        agent_count=$(echo "$worktree_config" | jq -r '.agent_count') 
        specialization=$(echo "$worktree_config" | jq -r '.specialization')
        
        echo "📂 Deploying to worktree: $worktree_name"
        echo "   Agents: $agent_count"
        echo "   Specialization: $specialization"
        
        # Create worktree if it doesn't exist
        if [ ! -d "$WORKTREES_DIR/$worktree_name" ]; then
            echo "   Creating worktree..."
            case "$worktree_name" in
                "ash-phoenix-migration")
                    "$SCRIPT_DIR/create_ash_phoenix_worktree.sh"
                    ;;
                *)
                    "$SCRIPT_DIR/create_s2s_worktree.sh" "$worktree_name"
                    ;;
            esac
        fi
        
        # Deploy agents to worktree
        deploy_agents_to_worktree "$worktree_name" "$worktree_config" "$trace_id"
        
        echo "   ✅ Deployment complete"
        echo ""
    done
    
    # Update swarm state
    update_swarm_state "deployed"
    
    echo "🎯 SWARM DEPLOYMENT COMPLETE"
    echo "  Monitor: ./manage_worktrees.sh list"
    echo "  Status:  ./agent_swarm_orchestrator.sh status"
}

# Deploy agents to specific worktree
deploy_agents_to_worktree() {
    local worktree_name="$1"
    local worktree_config="$2"
    local trace_id="$3"
    
    local worktree_path="$WORKTREES_DIR/$worktree_name"
    local agent_count=$(echo "$worktree_config" | jq -r '.agent_count')
    local specialization=$(echo "$worktree_config" | jq -r '.specialization')
    local claude_config=$(echo "$worktree_config" | jq -r '.claude_config')
    
    # Create agent configurations
    for i in $(seq 1 "$agent_count"); do
        local agent_id="agent_${specialization}_${i}_$(date +%s%N)"
        
        echo "   🤖 Configuring agent $i: $agent_id"
        
        # Create agent-specific configuration
        cat > "$worktree_path/agent_${i}_config.json" <<EOF
{
  "agent_id": "$agent_id",
  "agent_number": $i,
  "specialization": "$specialization",
  "worktree": "$worktree_name",
  "swarm_id": "$SWARM_ID",
  "trace_id": "$trace_id",
  "claude_config": $claude_config,
  "coordination": {
    "work_claiming_strategy": "skill_matched",
    "collaboration_mode": "active",
    "reporting_interval": 60,
    "heartbeat_endpoint": "$SHARED_COORDINATION_DIR/agent_heartbeats.json"
  },
  "specialization_config": $(echo "$worktree_config" | jq '.focus_areas')
}
EOF
        
        # Create agent startup script
        cat > "$worktree_path/start_agent_${i}.sh" <<EOF
#!/bin/bash
# Agent $i startup script for $worktree_name

set -euo pipefail

cd "$worktree_path"

# Load agent configuration
export CLAUDE_AGENT_CONFIG="\$(cat agent_${i}_config.json)"
export CLAUDE_WORKTREE="$worktree_name"
export CLAUDE_SPECIALIZATION="$specialization"
export CLAUDE_AGENT_ID="$agent_id"
export CLAUDE_OUTPUT_FORMAT="json"
export CLAUDE_STRUCTURED_RESPONSE="true"
export CLAUDE_AGENT_CONTEXT="s2s_coordination"

# Set up coordination environment
export S2S_COORDINATION_DIR="$worktree_path/agent_coordination"
export SHARED_COORDINATION_DIR="$SHARED_COORDINATION_DIR"

echo "🤖 Starting agent $i in $worktree_name"
echo "🆔 Agent ID: $agent_id"
echo "🎯 Specialization: $specialization"
echo ""

# Register agent in coordination system
"$SCRIPT_DIR/coordination_helper.sh" register-agent \\
    --agent-id "$agent_id" \\
    --specialization "$specialization" \\
    --team "${specialization}_team" \\
    --capacity 100 \\
    --worktree "$worktree_name"

# Start coordinated Claude session
echo "🚀 Starting Claude Code with agent coordination..."

# Load environment if available
if [ -f .env ]; then
    export \$(cat .env | grep -v '^#' | xargs)
fi

# Start Claude with agent configuration
claude --config agent_${i}_config.json
EOF
        
        # Create agent management script
        cat > "$worktree_path/manage_agent_${i}.sh" <<EOF
#!/bin/bash
# Agent $i management script

AGENT_PID_FILE="$worktree_path/.agent_${i}.pid"

case "\${1:-help}" in
    "start")
        if [ -f "\$AGENT_PID_FILE" ] && kill -0 "\$(cat \$AGENT_PID_FILE)" 2>/dev/null; then
            echo "Agent $i is already running (PID: \$(cat \$AGENT_PID_FILE))"
        else
            echo "Starting agent $i..."
            nohup "$worktree_path/start_agent_${i}.sh" > "$worktree_path/agent_${i}.log" 2>&1 &
            echo \$! > "\$AGENT_PID_FILE"
            echo "Agent $i started (PID: \$!)"
        fi
        ;;
    "stop")
        if [ -f "\$AGENT_PID_FILE" ]; then
            PID=\$(cat "\$AGENT_PID_FILE")
            if kill -0 "\$PID" 2>/dev/null; then
                kill "\$PID"
                rm -f "\$AGENT_PID_FILE"
                echo "Agent $i stopped"
            else
                echo "Agent $i was not running"
                rm -f "\$AGENT_PID_FILE"
            fi
        else
            echo "Agent $i is not running"
        fi
        ;;
    "status")
        if [ -f "\$AGENT_PID_FILE" ] && kill -0 "\$(cat \$AGENT_PID_FILE)" 2>/dev/null; then
            echo "Agent $i is running (PID: \$(cat \$AGENT_PID_FILE))"
        else
            echo "Agent $i is not running"
        fi
        ;;
    "logs")
        if [ -f "$worktree_path/agent_${i}.log" ]; then
            tail -f "$worktree_path/agent_${i}.log"
        else
            echo "No logs found for agent $i"
        fi
        ;;
    *)
        echo "Usage: \$0 {start|stop|status|logs}"
        ;;
esac
EOF
        
        chmod +x "$worktree_path/start_agent_${i}.sh"
        chmod +x "$worktree_path/manage_agent_${i}.sh"
    done
}

# Update swarm state
update_swarm_state() {
    local new_status="$1"
    
    if [ -f "$SWARM_STATE_FILE" ]; then
        local temp_file=$(mktemp)
        jq ".status = \"$new_status\" | .last_updated = \"$(python3 -c "import datetime; print(datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%S.%fZ')[:-3]+'Z')")\"" "$SWARM_STATE_FILE" > "$temp_file"
        mv "$temp_file" "$SWARM_STATE_FILE"
    fi
}

# Start all agents in the swarm
start_swarm() {
    echo "🚀 STARTING AGENT SWARM"
    echo "====================="
    echo ""
    
    local started_agents=0
    
    for worktree_dir in "$WORKTREES_DIR"/*; do
        if [ -d "$worktree_dir" ]; then
            worktree_name=$(basename "$worktree_dir")
            echo "📂 Starting agents in $worktree_name..."
            
            # Start all agents in this worktree
            for agent_script in "$worktree_dir"/manage_agent_*.sh; do
                if [ -f "$agent_script" ]; then
                    agent_num=$(basename "$agent_script" | sed 's/manage_agent_\([0-9]*\)\.sh/\1/')
                    echo "   🤖 Starting agent $agent_num..."
                    
                    "$agent_script" start
                    started_agents=$((started_agents + 1))
                fi
            done
            echo ""
        fi
    done
    
    update_swarm_state "running"
    
    echo "✅ SWARM STARTED"
    echo "   Active agents: $started_agents"
    echo "   Monitor: ./agent_swarm_orchestrator.sh status"
    echo "   Logs: ./agent_swarm_orchestrator.sh logs"
}

# Stop all agents in the swarm
stop_swarm() {
    echo "🛑 STOPPING AGENT SWARM"
    echo "====================="
    echo ""
    
    local stopped_agents=0
    
    for worktree_dir in "$WORKTREES_DIR"/*; do
        if [ -d "$worktree_dir" ]; then
            worktree_name=$(basename "$worktree_dir")
            echo "📂 Stopping agents in $worktree_name..."
            
            # Stop all agents in this worktree
            for agent_script in "$worktree_dir"/manage_agent_*.sh; do
                if [ -f "$agent_script" ]; then
                    agent_num=$(basename "$agent_script" | sed 's/manage_agent_\([0-9]*\)\.sh/\1/')
                    echo "   🤖 Stopping agent $agent_num..."
                    
                    "$agent_script" stop
                    stopped_agents=$((stopped_agents + 1))
                fi
            done
            echo ""
        fi
    done
    
    update_swarm_state "stopped"
    
    echo "✅ SWARM STOPPED"
    echo "   Stopped agents: $stopped_agents"
}

# Show swarm status
show_swarm_status() {
    echo "📊 AGENT SWARM STATUS"
    echo "===================="
    echo ""
    
    if [ -f "$SWARM_STATE_FILE" ]; then
        echo "🆔 Swarm ID: $(jq -r '.swarm_id' "$SWARM_STATE_FILE")"
        echo "📈 Status: $(jq -r '.status' "$SWARM_STATE_FILE")"
        echo "🕐 Last Updated: $(jq -r '.last_updated' "$SWARM_STATE_FILE")"
        echo ""
    fi
    
    # Show worktree status
    echo "🌳 WORKTREE STATUS"
    echo "-----------------"
    for worktree_dir in "$WORKTREES_DIR"/*; do
        if [ -d "$worktree_dir" ]; then
            worktree_name=$(basename "$worktree_dir")
            local running_agents=0
            local total_agents=0
            
            # Count agents
            for agent_script in "$worktree_dir"/manage_agent_*.sh; do
                if [ -f "$agent_script" ]; then
                    total_agents=$((total_agents + 1))
                    if "$agent_script" status | grep -q "is running"; then
                        running_agents=$((running_agents + 1))
                    fi
                fi
            done
            
            echo "  📂 $worktree_name: $running_agents/$total_agents agents running"
        fi
    done
    echo ""
    
    # Show coordination status
    echo "🤝 COORDINATION STATUS"
    echo "---------------------"
    if [ -f "$SCRIPT_DIR/work_claims.json" ]; then
        local active_work=$(jq '[.[] | select(.status == "in_progress")] | length' "$SCRIPT_DIR/work_claims.json")
        local completed_work=$(jq '[.[] | select(.status == "completed")] | length' "$SCRIPT_DIR/work_claims.json")
        echo "  📋 Active work items: $active_work"
        echo "  ✅ Completed work items: $completed_work"
    fi
    
    if [ -f "$SCRIPT_DIR/agent_status.json" ]; then
        local total_agents=$(jq 'length' "$SCRIPT_DIR/agent_status.json")
        local active_agents=$(jq '[.[] | select(.status == "active")] | length' "$SCRIPT_DIR/agent_status.json")
        echo "  🤖 Registered agents: $active_agents/$total_agents active"
    fi
}

# Show logs from all agents
show_swarm_logs() {
    echo "📜 AGENT SWARM LOGS"
    echo "=================="
    echo ""
    
    for worktree_dir in "$WORKTREES_DIR"/*; do
        if [ -d "$worktree_dir" ]; then
            worktree_name=$(basename "$worktree_dir")
            
            for log_file in "$worktree_dir"/agent_*.log; do
                if [ -f "$log_file" ]; then
                    agent_num=$(basename "$log_file" | sed 's/agent_\([0-9]*\)\.log/\1/')
                    echo "🤖 Agent $agent_num ($worktree_name):"
                    echo "----------------------------"
                    tail -20 "$log_file" | sed 's/^/  /'
                    echo ""
                fi
            done
        fi
    done
}

# Run Claude intelligence analysis across the swarm
run_swarm_intelligence() {
    local analysis_type="${1:-overview}"
    
    echo "🧠 SWARM INTELLIGENCE ANALYSIS"
    echo "============================="
    echo "📊 Analysis Type: $analysis_type"
    echo ""
    
    case "$analysis_type" in
        "overview")
            "$SCRIPT_DIR/coordination_helper.sh" claude-analyze-priorities
            ;;
        "performance")
            "$SCRIPT_DIR/coordination_helper.sh" claude-analyze-performance
            ;;
        "optimization")
            "$SCRIPT_DIR/coordination_helper.sh" claude-optimize-assignments --all-teams
            ;;
        "health")
            "$SCRIPT_DIR/coordination_helper.sh" claude-health-analysis
            ;;
        *)
            echo "Available analysis types: overview, performance, optimization, health"
            ;;
    esac
}

# Main execution
main() {
    local command="${1:-help}"
    
    case "$command" in
        "init")
            init_swarm
            ;;
        "deploy")
            deploy_swarm
            ;;
        "start")
            start_swarm
            ;;
        "stop")
            stop_swarm
            ;;
        "status")
            show_swarm_status
            ;;
        "logs")
            show_swarm_logs
            ;;
        "intelligence")
            shift
            run_swarm_intelligence "$@"
            ;;
        "help"|"-h"|"--help")
            echo "S@S Agent Swarm Orchestrator"
            echo "============================="
            echo ""
            echo "Usage: $0 <command> [options]"
            echo ""
            echo "Commands:"
            echo "  init                 Initialize swarm coordination"
            echo "  deploy              Deploy agent swarm to worktrees"
            echo "  start               Start all agents in the swarm"
            echo "  stop                Stop all agents in the swarm"
            echo "  status              Show swarm status and metrics"
            echo "  logs                Show logs from all agents"
            echo "  intelligence <type> Run Claude intelligence analysis"
            echo "  help                Show this help message"
            echo ""
            echo "Intelligence types:"
            echo "  overview            General swarm analysis"
            echo "  performance         Performance analysis"
            echo "  optimization        Workload optimization"
            echo "  health              Health analysis"
            echo ""
            echo "Examples:"
            echo "  $0 init"
            echo "  $0 deploy"
            echo "  $0 start"
            echo "  $0 intelligence performance"
            ;;
        *)
            echo "❌ Unknown command: $command"
            echo "Run '$0 help' for usage information"
            exit 1
            ;;
    esac
}

# Run if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi