#!/bin/bash

# S@S Worktree Creation Script with Agent Coordination Integration
# Creates isolated worktrees with full S@S coordination support

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WORKTREES_DIR="$PROJECT_ROOT/worktrees"
SHARED_COORDINATION_DIR="$PROJECT_ROOT/shared_coordination"

# OpenTelemetry configuration
OTEL_SERVICE_NAME="${OTEL_SERVICE_NAME:-s2s-worktree-management}"
OTEL_SERVICE_VERSION="${OTEL_SERVICE_VERSION:-1.0.0}"

# Generate trace ID for worktree creation
generate_trace_id() {
    echo "$(openssl rand -hex 16)"
}

# Create shared coordination directory if it doesn't exist
setup_shared_coordination() {
    mkdir -p "$SHARED_COORDINATION_DIR"
    
    # Initialize shared coordination files
    [ ! -f "$SHARED_COORDINATION_DIR/worktree_registry.json" ] && echo "[]" > "$SHARED_COORDINATION_DIR/worktree_registry.json"
    [ ! -f "$SHARED_COORDINATION_DIR/cross_worktree_locks.json" ] && echo "{}" > "$SHARED_COORDINATION_DIR/cross_worktree_locks.json"
    [ ! -f "$SHARED_COORDINATION_DIR/shared_telemetry.jsonl" ] && touch "$SHARED_COORDINATION_DIR/shared_telemetry.jsonl"
}

# Log shared telemetry across all worktrees
log_shared_telemetry() {
    local operation="$1"
    local worktree_name="$2"
    local status="$3"
    local trace_id="$4"
    local attributes="$5"
    
    local span_data=$(cat <<EOF
{
  "trace_id": "$trace_id",
  "span_id": "$(openssl rand -hex 8)",
  "operation": "$operation",
  "worktree": "$worktree_name", 
  "status": "$status",
  "timestamp": "$(python3 -c "import datetime; print(datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%S.%fZ')[:-3]+'Z')")",
  "service": {
    "name": "$OTEL_SERVICE_NAME",
    "version": "$OTEL_SERVICE_VERSION"
  },
  "attributes": $attributes
}
EOF
    )
    
    echo "$span_data" >> "$SHARED_COORDINATION_DIR/shared_telemetry.jsonl"
}

# Register worktree in shared registry
register_worktree() {
    local worktree_name="$1"
    local branch_name="$2"
    local worktree_path="$3"
    local trace_id="$4"
    
    local registration=$(cat <<EOF
{
  "worktree_name": "$worktree_name",
  "branch_name": "$branch_name", 
  "worktree_path": "$worktree_path",
  "created_at": "$(python3 -c "import datetime; print(datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%S.%fZ')[:-3]+'Z')")",
  "trace_id": "$trace_id",
  "status": "active",
  "agents": [],
  "coordination_dir": "$worktree_path/agent_coordination"
}
EOF
    )
    
    # Add to registry using jq if available, otherwise append
    if command -v jq >/dev/null 2>&1; then
        local temp_file=$(mktemp)
        jq ". += [$registration]" "$SHARED_COORDINATION_DIR/worktree_registry.json" > "$temp_file"
        mv "$temp_file" "$SHARED_COORDINATION_DIR/worktree_registry.json"
    else
        echo "⚠️ jq not available, manual registry management required"
    fi
}

# Create S@S worktree with full coordination setup
create_s2s_worktree() {
    local worktree_name="$1"
    local branch_name="${2:-$worktree_name}"
    local base_branch="${3:-master}"
    
    echo "🌟 CREATING S@S WORKTREE: $worktree_name"
    echo "============================================"
    
    # Generate trace ID for this operation
    local trace_id=$(generate_trace_id)
    echo "🔍 Trace ID: $trace_id"
    
    # Setup shared coordination
    setup_shared_coordination
    
    # Create worktrees directory
    mkdir -p "$WORKTREES_DIR"
    
    local worktree_path="$WORKTREES_DIR/$worktree_name"
    
    # Check if worktree already exists
    if [ -d "$worktree_path" ]; then
        echo "❌ ERROR: Worktree $worktree_name already exists at $worktree_path"
        return 1
    fi
    
    # Create git worktree
    echo "📂 Creating git worktree..."
    cd "$PROJECT_ROOT"
    git worktree add "$worktree_path" -b "$branch_name" "$base_branch"
    
    # Create isolated agent coordination in worktree
    echo "🤖 Setting up agent coordination..."
    local worktree_coordination_dir="$worktree_path/agent_coordination"
    mkdir -p "$worktree_coordination_dir"
    
    # Copy coordination helper script to worktree
    cp "$SCRIPT_DIR/coordination_helper.sh" "$worktree_coordination_dir/"
    
    # Initialize worktree-specific coordination files
    echo "[]" > "$worktree_coordination_dir/work_claims.json"
    echo "[]" > "$worktree_coordination_dir/agent_status.json"
    echo "[]" > "$worktree_coordination_dir/coordination_log.json"
    touch "$worktree_coordination_dir/telemetry_spans.jsonl"
    
    # Set up complete environment (database, ports, configuration)
    echo "🔧 Setting up worktree environment..."
    "$SCRIPT_DIR/worktree_environment_manager.sh" setup "$worktree_name" "$worktree_path"
    
    # Create worktree-specific configuration
    cat > "$worktree_coordination_dir/worktree_config.json" <<EOF
{
  "worktree_name": "$worktree_name",
  "branch_name": "$branch_name",
  "base_branch": "$base_branch",
  "created_at": "$(python3 -c "import datetime; print(datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%S.%fZ')[:-3]+'Z')")",
  "trace_id": "$trace_id",
  "shared_coordination_dir": "$SHARED_COORDINATION_DIR",
  "project_root": "$PROJECT_ROOT"
}
EOF
    
    # Register worktree in shared coordination
    register_worktree "$worktree_name" "$branch_name" "$worktree_path" "$trace_id"
    
    # Log telemetry
    local creation_attributes=$(cat <<EOF
{
  "s2s.worktree_name": "$worktree_name",
  "s2s.branch_name": "$branch_name",
  "s2s.base_branch": "$base_branch",
  "s2s.worktree_path": "$worktree_path"
}
EOF
    )
    log_shared_telemetry "s2s.worktree.create" "$worktree_name" "success" "$trace_id" "$creation_attributes"
    
    echo "✅ SUCCESS: S@S worktree '$worktree_name' created"
    echo "📍 Path: $worktree_path"
    echo "🌿 Branch: $branch_name"
    echo "🤖 Coordination: $worktree_coordination_dir"
    echo ""
    echo "🚀 Next steps:"
    echo "   cd $worktree_path"
    echo "   claude  # Start Claude Code in isolated worktree"
    echo ""
    echo "📊 Monitor worktree:"
    echo "   ./manage_worktrees.sh list"
    echo "   ./manage_worktrees.sh status $worktree_name"
}

# Main execution
main() {
    if [ $# -lt 1 ]; then
        echo "Usage: $0 <worktree_name> [branch_name] [base_branch]"
        echo ""
        echo "Examples:"
        echo "  $0 ash-phoenix-migration"
        echo "  $0 feature-n8n-v2 n8n-improvements master"
        echo "  $0 performance-optimization perf-boost main"
        exit 1
    fi
    
    create_s2s_worktree "$@"
}

# Run if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi