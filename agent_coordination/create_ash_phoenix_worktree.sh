#!/bin/bash

# S@S Ash Phoenix Worktree Creation Script
# Creates a dedicated worktree for Ash Phoenix project migration

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Configuration
WORKTREE_NAME="${1:-ash-phoenix-migration}"
BRANCH_NAME="${2:-ash-phoenix-rewrite}"
BASE_BRANCH="${3:-master}"

# OpenTelemetry configuration
OTEL_SERVICE_NAME="s2s-ash-phoenix-migration"
export OTEL_SERVICE_NAME

# Generate trace ID for this migration
generate_trace_id() {
    echo "$(openssl rand -hex 16)"
}

# Create Ash Phoenix worktree with specialized setup
create_ash_phoenix_worktree() {
    local trace_id=$(generate_trace_id)
    
    echo "🔥 CREATING ASH PHOENIX MIGRATION WORKTREE"
    echo "=========================================="
    echo "🔍 Trace ID: $trace_id"
    echo "🌿 Worktree: $WORKTREE_NAME"
    echo "🌿 Branch: $BRANCH_NAME"
    echo ""
    
    # Create the S@S worktree
    echo "📂 Creating S@S worktree..."
    "$SCRIPT_DIR/create_s2s_worktree.sh" "$WORKTREE_NAME" "$BRANCH_NAME" "$BASE_BRANCH"
    
    local worktree_path="$PROJECT_ROOT/worktrees/$WORKTREE_NAME"
    
    # Navigate to worktree
    cd "$worktree_path"
    
    echo ""
    echo "🏗️  SETTING UP ASH PHOENIX PROJECT"
    echo "=================================="
    
    # Check if Elixir and Phoenix are available
    if ! command -v elixir >/dev/null 2>&1; then
        echo "❌ ERROR: Elixir not found. Please install Elixir first."
        return 1
    fi
    
    if ! command -v mix >/dev/null 2>&1; then
        echo "❌ ERROR: Mix not found. Please install Elixir/Mix first."
        return 1
    fi
    
    # Install/update Phoenix if needed
    echo "📦 Ensuring Phoenix is available..."
    mix archive.install hex phx_new --force
    
    # Create Ash Phoenix project
    echo "🔥 Creating new Ash Phoenix project..."
    local project_name="self_sustaining_ash"
    
    # Create the project with Ash Phoenix
    mix phx.new "$project_name" --umbrella --live --database postgres --binary-id
    
    cd "$project_name"
    
    # Configure build isolation and environment
    echo "🔧 Configuring build isolation..."
    
    # Create isolated build directory
    export MIX_BUILD_PATH="$worktree_path/$project_name/_build_worktree"
    export MIX_DEPS_PATH="$worktree_path/$project_name/deps_worktree"
    
    # Configure assets with unique ports
    mkdir -p assets
    
    # Add Ash dependencies to mix.exs
    echo "📝 Adding Ash Framework dependencies..."
    
    # Create a temporary mix.exs patch
    cat > /tmp/ash_deps_patch.exs <<'EOF'
    # Ash Framework dependencies to add
    {:ash, "~> 3.0"},
    {:ash_postgres, "~> 2.0"},  
    {:ash_phoenix, "~> 2.0"},
    {:ash_authentication, "~> 4.0"},
    {:ash_authentication_phoenix, "~> 2.0"},
    {:ash_oban, "~> 0.4.9"},
    {:ash_ai, github: "ash-project/ash_ai"},
    
    # Additional dependencies from existing project
    {:reactor, "~> 0.15.4"},
    {:tidewave, "~> 0.1"},
    {:httpoison, "~> 2.0"},
    {:req, "~> 0.5.2"},
    {:file_system, "~> 1.0"},
    {:cachex, "~> 3.6"},
    {:yaml_elixir, "~> 2.9"},
    
    # OpenTelemetry - using compatible versions
    {:opentelemetry, "~> 1.3"},
    {:opentelemetry_api, "~> 1.2"},
    {:opentelemetry_exporter, "~> 1.6"},
    {:opentelemetry_phoenix, "~> 1.1"},
    {:opentelemetry_ecto, "~> 1.1"},
    {:opentelemetry_cowboy, "~> 0.2"},
    {:opentelemetry_liveview, "~> 1.0.0-rc.4"},
EOF
    
    echo "📝 Mix.exs patching instructions created"
    echo "⚠️  Manual step required: Add Ash dependencies to apps/*/mix.exs"
    
    # Configure Phoenix to use worktree overlay
    echo "🔧 Configuring Phoenix for worktree isolation..."
    
    # Update config/dev.exs to import worktree overlay
    if [ -f "config/dev.exs" ]; then
        echo "" >> config/dev.exs
        echo "# Import worktree-specific configuration" >> config/dev.exs
        echo "import_config \"worktree_overlay.exs\"" >> config/dev.exs
    fi
    
    # Update config/test.exs to import worktree overlay
    if [ -f "config/test.exs" ]; then
        echo "" >> config/test.exs
        echo "# Import worktree-specific configuration" >> config/test.exs
        echo "import_config \"worktree_overlay.exs\"" >> config/test.exs
    fi
    
    # Create .envrc for direnv support (optional)
    cat > .envrc <<EOF
# Worktree-specific environment
export MIX_BUILD_PATH="$worktree_path/$project_name/_build_worktree"
export MIX_DEPS_PATH="$worktree_path/$project_name/deps_worktree"

# Load .env file
if [ -f .env ]; then
  dotenv
fi
EOF
    
    # Create directory structure for migration
    echo "📁 Creating migration directory structure..."
    mkdir -p migration_assets
    mkdir -p migration_assets/original_phoenix_app
    mkdir -p migration_assets/ash_resources
    mkdir -p migration_assets/ash_domains
    mkdir -p migration_assets/migration_scripts
    
    # Copy key files from original Phoenix app for reference
    echo "📋 Copying reference files from original Phoenix app..."
    cp -r "$PROJECT_ROOT/phoenix_app/lib/self_sustaining" migration_assets/original_phoenix_app/ 2>/dev/null || echo "⚠️ Could not copy original app files"
    
    # Create migration plan
    cat > migration_assets/MIGRATION_PLAN.md <<'EOF'
# Ash Phoenix Migration Plan

## Overview
Migrating from traditional Phoenix app to Ash Phoenix architecture.

## Migration Phases

### Phase 1: Foundation (HIGH PRIORITY)
- [ ] Create Ash domains for core business logic
- [ ] Set up Ash resources for existing Ecto schemas
- [ ] Configure Ash Phoenix integration
- [ ] Migrate basic CRUD operations

### Phase 2: Workflow Orchestration (HIGH PRIORITY)  
- [ ] Migrate Reactor workflows to Ash actions
- [ ] Integrate agent coordination with Ash resources
- [ ] Port telemetry middleware to Ash hooks
- [ ] Migrate N8n integration workflows

### Phase 3: Advanced Features (MEDIUM PRIORITY)
- [ ] Migrate AI/ML components to Ash AI
- [ ] Port self-improvement orchestrator
- [ ] Migrate performance monitoring
- [ ] Integrate OpenTelemetry with Ash

### Phase 4: Web Interface (MEDIUM PRIORITY)
- [ ] Migrate LiveView components
- [ ] Update controllers to use Ash actions
- [ ] Migrate authentication system
- [ ] Port dashboard functionality

### Phase 5: Integrations (LOW PRIORITY)
- [ ] Port Livebook integration
- [ ] Migrate Claude Code integration
- [ ] Update deployment configurations
- [ ] Migrate test suites

## Key Ash Concepts to Implement

### Domains
- **SelfSustaining.AI** - AI and ML functionality
- **SelfSustaining.Coordination** - Agent coordination
- **SelfSustaining.Workflows** - Reactor workflows
- **SelfSustaining.Telemetry** - Monitoring and metrics

### Resources
- **Agent** - Agent coordination and status
- **WorkItem** - Work claims and tasks
- **AITask** - AI improvement tasks
- **Metric** - Performance metrics
- **Workflow** - N8n workflows

### Actions
- **claim_work** - Atomic work claiming
- **update_progress** - Progress tracking
- **complete_work** - Work completion
- **analyze_improvements** - AI analysis
- **coordinate_agents** - Agent coordination

## Migration Strategy
1. **Parallel Development** - Use worktree for isolated development
2. **Incremental Migration** - Migrate one domain at a time
3. **Feature Parity** - Ensure all existing functionality is preserved
4. **Performance Testing** - Benchmark against original app
5. **Zero Downtime** - Plan for smooth production transition

## Success Criteria
- [ ] All existing functionality preserved
- [ ] Performance equal or better than original
- [ ] Ash best practices followed
- [ ] Comprehensive test coverage
- [ ] Documentation updated
- [ ] S@S coordination system fully functional
EOF
    
    # Create initial Ash resource template
    mkdir -p lib/self_sustaining_ash/coordination
    cat > lib/self_sustaining_ash/coordination/agent.ex <<'EOF'
defmodule SelfSustainingAsh.Coordination.Agent do
  use Ash.Resource,
    domain: SelfSustainingAsh.Coordination,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "agents"
    repo SelfSustainingAsh.Repo
  end

  attributes do
    uuid_primary_key :id
    attribute :agent_id, :string, allow_nil?: false
    attribute :team, :string, allow_nil?: false
    attribute :specialization, :string, allow_nil?: false
    attribute :capacity, :integer, default: 100
    attribute :status, :string, default: "active"
    attribute :current_workload, :integer, default: 0
    attribute :last_heartbeat, :utc_datetime
    attribute :performance_metrics, :map, default: %{}
    
    timestamps()
  end

  actions do
    defaults [:create, :read, :update, :destroy]
    
    create :register do
      accept [:agent_id, :team, :specialization, :capacity]
      change fn changeset, _ ->
        Ash.Changeset.change_attribute(changeset, :last_heartbeat, DateTime.utc_now())
      end
    end
    
    update :heartbeat do
      change fn changeset, _ ->
        Ash.Changeset.change_attribute(changeset, :last_heartbeat, DateTime.utc_now())
      end
    end
    
    read :active do
      filter expr(status == "active")
    end
    
    read :by_team do
      argument :team, :string, allow_nil?: false
      filter expr(team == ^arg(:team))
    end
  end

  identities do
    identity :unique_agent_id, [:agent_id]
  end
end
EOF
    
    # Create coordination domain
    cat > lib/self_sustaining_ash/coordination.ex <<'EOF'
defmodule SelfSustainingAsh.Coordination do
  use Ash.Domain

  resources do
    resource SelfSustainingAsh.Coordination.Agent
    # Add more resources as they are created
  end
end
EOF
    
    # Create coordination context for Phoenix integration
    cat > lib/self_sustaining_ash_web/coordination.ex <<'EOF'
defmodule SelfSustainingAshWeb.Coordination do
  @moduledoc """
  Coordination context for Phoenix integration with Ash.
  """
  
  import Ash.Query
  alias SelfSustainingAsh.Coordination.Agent
  
  def list_agents do
    Agent
    |> Ash.Query.for_read(:active)
    |> SelfSustainingAsh.Coordination.read!()
  end
  
  def register_agent(attrs) do
    Agent
    |> Ash.Changeset.for_create(:register, attrs)
    |> SelfSustainingAsh.Coordination.create()
  end
  
  def get_agent!(agent_id) do
    Agent
    |> Ash.Query.filter(agent_id == ^agent_id)
    |> SelfSustainingAsh.Coordination.read_one!()
  end
  
  def update_agent_heartbeat(agent_id) do
    agent = get_agent!(agent_id)
    
    agent
    |> Ash.Changeset.for_update(:heartbeat)
    |> SelfSustainingAsh.Coordination.update()
  end
end
EOF
    
    # Create S@S specific coordination helper for Ash Phoenix
    cat > migration_assets/migration_scripts/ash_coordination_helper.sh <<'EOF'
#!/bin/bash

# Ash Phoenix Coordination Helper
# Integrates with Ash Phoenix project for S@S coordination

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASH_PROJECT_DIR="$(cd "$SCRIPT_DIR/../../self_sustaining_ash" && pwd)"

# Start the Ash Phoenix application
start_ash_app() {
    echo "🔥 Starting Ash Phoenix application..."
    cd "$ASH_PROJECT_DIR"
    
    # Install dependencies
    mix deps.get
    
    # Set up database
    mix ecto.setup
    
    # Start Phoenix server
    mix phx.server
}

# Run Ash queries for coordination
ash_query() {
    local query="$1"
    cd "$ASH_PROJECT_DIR"
    
    case "$query" in
        "list_agents")
            mix run -e "SelfSustainingAsh.Coordination.Agent |> Ash.Query.for_read(:active) |> SelfSustainingAsh.Coordination.read!() |> IO.inspect()"
            ;;
        "agent_count")
            mix run -e "SelfSustainingAsh.Coordination.Agent |> Ash.Query.for_read(:active) |> SelfSustainingAsh.Coordination.read!() |> length() |> IO.puts()"
            ;;
        *)
            echo "Unknown query: $query"
            ;;
    esac
}

# Test Ash Phoenix integration
test_ash_integration() {
    echo "🧪 Testing Ash Phoenix integration..."
    cd "$ASH_PROJECT_DIR"
    
    # Run tests
    mix test
    
    # Run basic queries
    echo "Testing agent queries..."
    ash_query "agent_count"
}

# Main execution
main() {
    local command="${1:-help}"
    
    case "$command" in
        "start")
            start_ash_app
            ;;
        "query")
            shift
            ash_query "$@"
            ;;
        "test")
            test_ash_integration
            ;;
        *)
            echo "Ash Phoenix Coordination Helper"
            echo "Usage: $0 <command>"
            echo ""
            echo "Commands:"
            echo "  start     Start the Ash Phoenix application"
            echo "  query     Run Ash queries"
            echo "  test      Test Ash Phoenix integration"
            ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
EOF
    
    chmod +x migration_assets/migration_scripts/ash_coordination_helper.sh
    
    # Create integration instructions
    cat > migration_assets/INTEGRATION_INSTRUCTIONS.md <<'EOF'
# Ash Phoenix Integration Instructions

## Immediate Next Steps

### 1. Manual Dependency Setup
Edit `apps/self_sustaining_ash/mix.exs` and add the Ash dependencies from `/tmp/ash_deps_patch.exs`

### 2. Database Configuration
Update `config/dev.exs` with your PostgreSQL configuration

### 3. Install Dependencies
```bash
mix deps.get
```

### 4. Set Up Database
```bash
mix ecto.create
mix ecto.migrate
```

### 5. Start Development Server
```bash
mix phx.server
```

## Migration Development Workflow

### Using Claude Code in This Worktree
```bash
# In this worktree directory
claude

# Claude will have access to:
# - Original Phoenix app files in migration_assets/original_phoenix_app/
# - New Ash Phoenix project structure
# - Migration plan and scripts
# - S@S coordination system
```

### Testing Migration
```bash
# Test Ash integration
./migration_assets/migration_scripts/ash_coordination_helper.sh test

# Start Ash Phoenix app
./migration_assets/migration_scripts/ash_coordination_helper.sh start
```

## Key Integration Points

### 1. Agent Coordination
- Original: `phoenix_app/lib/self_sustaining/reactor_middleware/agent_coordination_middleware.ex`
- Ash Version: `lib/self_sustaining_ash/coordination/agent.ex`

### 2. Workflow Orchestration
- Original: `phoenix_app/lib/self_sustaining/workflows/`
- Ash Version: Convert to Ash actions and hooks

### 3. Telemetry
- Original: `phoenix_app/lib/self_sustaining/reactor_middleware/telemetry_middleware.ex`
- Ash Version: Ash hooks with OpenTelemetry integration

## Success Metrics
- [ ] Agent coordination functionality preserved
- [ ] Workflow orchestration working
- [ ] Telemetry integration functional
- [ ] Performance benchmarks met
- [ ] S@S coordination system operational
EOF
    
    # Log successful creation
    echo ""
    echo "✅ ASH PHOENIX WORKTREE CREATED SUCCESSFULLY"
    echo "==========================================="
    echo "📍 Location: $worktree_path"
    echo "🔥 Project: $worktree_path/$project_name"
    echo "📋 Migration Plan: $worktree_path/$project_name/migration_assets/MIGRATION_PLAN.md"
    echo "📖 Instructions: $worktree_path/$project_name/migration_assets/INTEGRATION_INSTRUCTIONS.md"
    echo ""
    echo "🚀 NEXT STEPS:"
    echo "1. cd $worktree_path/$project_name"
    echo "2. Edit apps/self_sustaining_ash/mix.exs (add Ash dependencies)"
    echo "3. mix deps.get"
    echo "4. mix ecto.setup"
    echo "5. claude  # Start Claude Code in this worktree"
    echo ""
    echo "🤖 S@S COORDINATION:"
    echo "   Use ../agent_coordination/coordination_helper.sh for coordination"
    echo "   This worktree has isolated agent coordination"
    echo ""
    echo "📊 MONITOR PROGRESS:"
    echo "   ../agent_coordination/manage_worktrees.sh status $WORKTREE_NAME"
    
    # Update worktree coordination with Ash-specific metadata
    local coordination_dir="$worktree_path/agent_coordination"
    if [ -d "$coordination_dir" ]; then
        cat > "$coordination_dir/ash_phoenix_metadata.json" <<EOF
{
  "migration_type": "ash_phoenix",
  "ash_project_path": "$project_name",
  "original_app_path": "$PROJECT_ROOT/phoenix_app",
  "migration_phase": "foundation",
  "created_at": "$(python3 -c "import datetime; print(datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%S.%fZ')[:-3]+'Z')")",
  "trace_id": "$trace_id",
  "key_features": [
    "agent_coordination",
    "reactor_workflows", 
    "telemetry_middleware",
    "n8n_integration",
    "ai_self_improvement",
    "phoenix_liveview"
  ]
}
EOF
    fi
}

# Main execution
main() {
    create_ash_phoenix_worktree
}

# Run if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi