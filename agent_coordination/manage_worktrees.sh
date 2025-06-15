#!/bin/bash

# S@S Worktree Management Script
# List, monitor, cleanup, and coordinate multiple worktrees

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WORKTREES_DIR="$PROJECT_ROOT/worktrees"
SHARED_COORDINATION_DIR="$PROJECT_ROOT/shared_coordination"

# OpenTelemetry configuration
OTEL_SERVICE_NAME="${OTEL_SERVICE_NAME:-s2s-worktree-management}"

# Generate trace ID for operations
generate_trace_id() {
    echo "$(openssl rand -hex 16)"
}

# Log shared telemetry
log_shared_telemetry() {
    local operation="$1"
    local status="$2"
    local trace_id="$3"
    local attributes="$4"
    
    local span_data=$(cat <<EOF
{
  "trace_id": "$trace_id",
  "span_id": "$(openssl rand -hex 8)",
  "operation": "$operation",
  "status": "$status",
  "timestamp": "$(python3 -c "import datetime; print(datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%S.%fZ')[:-3]+'Z')")",
  "service": {
    "name": "$OTEL_SERVICE_NAME",
    "version": "1.0.0"
  },
  "attributes": $attributes
}
EOF
    )
    
    if [ -f "$SHARED_COORDINATION_DIR/shared_telemetry.jsonl" ]; then
        echo "$span_data" >> "$SHARED_COORDINATION_DIR/shared_telemetry.jsonl"
    fi
}

# List all S@S worktrees
list_worktrees() {
    echo "🌳 S@S WORKTREE STATUS"
    echo "====================="
    echo ""
    
    # Show git worktrees
    echo "📂 Git Worktrees:"
    if git worktree list >/dev/null 2>&1; then
        git worktree list | grep -E "(worktrees/|main)" || echo "  No worktrees found"
    else
        echo "  Error: Not in a git repository"
    fi
    echo ""
    
    # Show S@S coordination status
    if [ -f "$SHARED_COORDINATION_DIR/worktree_registry.json" ]; then
        echo "🤖 S@S Coordination Status:"
        if command -v jq >/dev/null 2>&1; then
            jq -r '.[] | "  🌿 \(.worktree_name) (\(.status)) - \(.branch_name) - \(.agents | length) agent(s)"' "$SHARED_COORDINATION_DIR/worktree_registry.json" 2>/dev/null || echo "  No registered worktrees"
        else
            echo "  Registry exists but jq not available for detailed status"
        fi
    else
        echo "🤖 S@S Coordination Status: Not initialized"
    fi
    echo ""
    
    # Show active agents across worktrees
    echo "👥 Active Agents Across Worktrees:"
    local total_agents=0
    for worktree_dir in "$WORKTREES_DIR"/*; do
        if [ -d "$worktree_dir/agent_coordination" ]; then
            local worktree_name=$(basename "$worktree_dir")
            local agent_count=0
            if [ -f "$worktree_dir/agent_coordination/agent_status.json" ]; then
                if command -v jq >/dev/null 2>&1; then
                    agent_count=$(jq 'length' "$worktree_dir/agent_coordination/agent_status.json" 2>/dev/null || echo 0)
                else
                    agent_count=$(grep -c "agent_id" "$worktree_dir/agent_coordination/agent_status.json" 2>/dev/null || echo 0)
                fi
            fi
            echo "  🤖 $worktree_name: $agent_count agent(s)"
            total_agents=$((total_agents + agent_count))
        fi
    done
    echo "  📊 Total: $total_agents agent(s)"
}

# Show detailed status of a specific worktree
show_worktree_status() {
    local worktree_name="$1"
    local worktree_path="$WORKTREES_DIR/$worktree_name"
    
    echo "🔍 WORKTREE STATUS: $worktree_name"
    echo "=================================="
    echo ""
    
    if [ ! -d "$worktree_path" ]; then
        echo "❌ ERROR: Worktree '$worktree_name' not found"
        return 1
    fi
    
    # Basic info
    echo "📍 Path: $worktree_path"
    echo "🌿 Branch: $(cd "$worktree_path" && git branch --show-current 2>/dev/null || echo 'unknown')"
    echo "📈 Commits: $(cd "$worktree_path" && git rev-list --count HEAD 2>/dev/null || echo 'unknown')"
    echo ""
    
    # Agent coordination status
    local coordination_dir="$worktree_path/agent_coordination"
    if [ -d "$coordination_dir" ]; then
        echo "🤖 Agent Coordination:"
        
        # Active agents
        if [ -f "$coordination_dir/agent_status.json" ] && command -v jq >/dev/null 2>&1; then
            local agent_count=$(jq 'length' "$coordination_dir/agent_status.json" 2>/dev/null || echo 0)
            echo "  👥 Active agents: $agent_count"
            if [ "$agent_count" -gt 0 ]; then
                echo "  Agents:"
                jq -r '.[] | "    🤖 \(.agent_id) (\(.team)) - \(.specialization)"' "$coordination_dir/agent_status.json" 2>/dev/null || echo "    Error reading agents"
            fi
        fi
        
        # Work items
        if [ -f "$coordination_dir/work_claims.json" ] && command -v jq >/dev/null 2>&1; then
            local work_count=$(jq 'length' "$coordination_dir/work_claims.json" 2>/dev/null || echo 0)
            echo "  📋 Work items: $work_count"
            if [ "$work_count" -gt 0 ]; then
                echo "  Recent work:"
                jq -r '.[-3:] | .[] | "    📝 \(.work_type) (\(.status)) - \(.description)"' "$coordination_dir/work_claims.json" 2>/dev/null || echo "    Error reading work items"
            fi
        fi
        
        # Telemetry
        if [ -f "$coordination_dir/telemetry_spans.jsonl" ]; then
            local span_count=$(wc -l < "$coordination_dir/telemetry_spans.jsonl" 2>/dev/null || echo 0)
            echo "  📊 Telemetry spans: $span_count"
        fi
    else
        echo "🤖 Agent Coordination: Not initialized"
    fi
    echo ""
    
    # Recent activity
    echo "📈 Recent Activity (last 10 minutes):"
    local recent_activity=false
    if [ -f "$coordination_dir/telemetry_spans.jsonl" ]; then
        # Show recent spans (simplified without complex date parsing)
        local recent_spans=$(tail -5 "$coordination_dir/telemetry_spans.jsonl" 2>/dev/null || echo "")
        if [ -n "$recent_spans" ]; then
            echo "  Recent telemetry spans logged"
            recent_activity=true
        fi
    fi
    
    if [ "$recent_activity" = false ]; then
        echo "  No recent activity detected"
    fi
}

# Cleanup completed worktrees
cleanup_worktrees() {
    echo "🧹 WORKTREE CLEANUP"
    echo "==================="
    echo ""
    
    local trace_id=$(generate_trace_id)
    echo "🔍 Trace ID: $trace_id"
    
    if [ ! -d "$WORKTREES_DIR" ]; then
        echo "📂 No worktrees directory found"
        return 0
    fi
    
    local cleaned_count=0
    
    # Look for worktrees marked for cleanup
    for worktree_dir in "$WORKTREES_DIR"/*; do
        if [ -d "$worktree_dir" ]; then
            local worktree_name=$(basename "$worktree_dir")
            
            # Check if worktree is marked for cleanup
            if [ -f "$worktree_dir/.cleanup_requested" ]; then
                echo "🗑️  Cleaning up worktree: $worktree_name"
                
                # Clean up environment (databases, ports, etc.)
                "$SCRIPT_DIR/worktree_environment_manager.sh" cleanup "$worktree_name"
                
                # Remove git worktree
                cd "$PROJECT_ROOT"
                if git worktree remove "$worktree_dir" --force 2>/dev/null; then
                    echo "  ✅ Git worktree removed"
                else
                    # If git worktree remove fails, remove directory manually
                    rm -rf "$worktree_dir"
                    echo "  ✅ Directory removed manually"
                fi
                
                # Update shared registry
                if [ -f "$SHARED_COORDINATION_DIR/worktree_registry.json" ] && command -v jq >/dev/null 2>&1; then
                    local temp_file=$(mktemp)
                    jq "map(select(.worktree_name != \"$worktree_name\"))" "$SHARED_COORDINATION_DIR/worktree_registry.json" > "$temp_file"
                    mv "$temp_file" "$SHARED_COORDINATION_DIR/worktree_registry.json"
                    echo "  ✅ Removed from registry"
                fi
                
                cleaned_count=$((cleaned_count + 1))
            fi
        fi
    done
    
    # Log telemetry
    local cleanup_attributes=$(cat <<EOF
{
  "s2s.worktrees_cleaned": $cleaned_count,
  "s2s.operation": "cleanup"
}
EOF
    )
    log_shared_telemetry "s2s.worktree.cleanup" "success" "$trace_id" "$cleanup_attributes"
    
    echo "📊 Cleaned up $cleaned_count worktree(s)"
}

# Mark a worktree for cleanup
mark_for_cleanup() {
    local worktree_name="$1"
    local worktree_path="$WORKTREES_DIR/$worktree_name"
    
    if [ ! -d "$worktree_path" ]; then
        echo "❌ ERROR: Worktree '$worktree_name' not found"
        return 1
    fi
    
    touch "$worktree_path/.cleanup_requested"
    echo "🗑️  Marked worktree '$worktree_name' for cleanup"
    echo "   Run './manage_worktrees.sh cleanup' to remove it"
}

# Show cross-worktree coordination status
show_cross_coordination() {
    echo "🔄 CROSS-WORKTREE COORDINATION"
    echo "=============================="
    echo ""
    
    if [ -f "$SHARED_COORDINATION_DIR/shared_telemetry.jsonl" ]; then
        local span_count=$(wc -l < "$SHARED_COORDINATION_DIR/shared_telemetry.jsonl" || echo 0)
        echo "📊 Shared telemetry spans: $span_count"
        
        if [ "$span_count" -gt 0 ]; then
            echo "Recent shared operations:"
            tail -5 "$SHARED_COORDINATION_DIR/shared_telemetry.jsonl" | while read -r line; do
                if command -v jq >/dev/null 2>&1; then
                    echo "  $(echo "$line" | jq -r '"\(.operation) (\(.status)) - \(.timestamp)"')"
                else
                    echo "  $line"
                fi
            done
        fi
    else
        echo "📊 No shared telemetry found"
    fi
    echo ""
    
    if [ -f "$SHARED_COORDINATION_DIR/cross_worktree_locks.json" ]; then
        echo "🔒 Cross-worktree locks:"
        if command -v jq >/dev/null 2>&1; then
            jq -r 'keys[] // "  No active locks"' "$SHARED_COORDINATION_DIR/cross_worktree_locks.json" 2>/dev/null || echo "  No locks file"
        else
            echo "  Locks file exists but jq not available"
        fi
    else
        echo "🔒 No cross-worktree locks"
    fi
}

# Main execution
main() {
    local command="${1:-list}"
    
    case "$command" in
        "list"|"ls")
            list_worktrees
            ;;
        "status")
            if [ $# -lt 2 ]; then
                echo "Usage: $0 status <worktree_name>"
                exit 1
            fi
            show_worktree_status "$2"
            ;;
        "cleanup")
            cleanup_worktrees
            ;;
        "remove"|"rm")
            if [ $# -lt 2 ]; then
                echo "Usage: $0 remove <worktree_name>"
                exit 1
            fi
            mark_for_cleanup "$2"
            ;;
        "cross"|"coordination")
            show_cross_coordination
            ;;
        "help"|"-h"|"--help")
            echo "S@S Worktree Management"
            echo "======================"
            echo ""
            echo "Usage: $0 <command> [options]"
            echo ""
            echo "Commands:"
            echo "  list, ls              List all worktrees and their status"
            echo "  status <name>         Show detailed status of a worktree"
            echo "  cleanup              Clean up worktrees marked for removal"
            echo "  remove <name>        Mark a worktree for cleanup"
            echo "  cross, coordination  Show cross-worktree coordination status"
            echo "  help                 Show this help message"
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