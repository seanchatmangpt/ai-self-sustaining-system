#!/bin/bash

# XAVOS Complete Deployment Script
# Implements the full XAVOS-ASH-PHOENIX-FULL-SAS-AGENT.md guide

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "🌟 DEPLOYING XAVOS: COMPLETE ASH PHOENIX SYSTEM"
echo "=============================================="
echo "🎯 Advanced AI-driven system with full Ash ecosystem"
echo "🤖 S@S agent coordination and Claude intelligence"
echo "🌳 Worktree-based isolation and parallel development"
echo ""

# Verify prerequisites
echo "🔍 Verifying prerequisites..."
if ! command -v elixir >/dev/null 2>&1; then
    echo "❌ ERROR: Elixir not found. Please install Elixir first."
    exit 1
fi

if ! command -v mix >/dev/null 2>&1; then
    echo "❌ ERROR: Mix not found. Please install Elixir/Mix first."
    exit 1
fi

if ! command -v psql >/dev/null 2>&1; then
    echo "⚠️ WARNING: PostgreSQL client not found. Database operations may fail."
fi

echo "✅ Prerequisites verified"
echo ""

# Step 1: Create XAVOS worktree with S@S coordination
echo "📂 Step 1/8: Creating XAVOS worktree with S@S coordination..."
cd "$SCRIPT_DIR"

if [ ! -d "../worktrees/xavos-system" ]; then
    ./create_s2s_worktree.sh xavos-system xavos-main master
    echo "✅ XAVOS worktree created"
else
    echo "✅ XAVOS worktree already exists"
fi
echo ""

# Step 2: Set up environment isolation
echo "🔧 Step 2/8: Setting up environment isolation..."
./worktree_environment_manager.sh setup xavos-system "../worktrees/xavos-system"
echo "✅ Environment isolation configured"
echo ""

# Step 3: Install archives and generate XAVOS
echo "📦 Step 3/8: Installing archives and generating XAVOS..."
cd "../worktrees/xavos-system"

# Install required archives
echo "Installing Igniter and Phoenix archives..."
mix archive.install hex igniter_new --force
mix archive.install hex phx_new 1.8.0-rc.3 --force

# Generate XAVOS project if it doesn't exist
if [ ! -d "xavos" ]; then
    echo "🔥 Generating XAVOS with complete Ash ecosystem..."
    
    # Load environment variables for database configuration
    if [ -f .env ]; then
        export $(cat .env | grep -v '^#' | xargs)
    fi
    
    # Generate XAVOS with full Ash ecosystem - EXACT COMMAND AS SPECIFIED
    mix igniter.new xavos --with phx.new --install ash,ash_phoenix \
      --install ash_json_api,ash_postgres \
      --install ash_sqlite,ash_authentication \
      --install ash_authentication_phoenix,ash_admin \
      --install ash_oban,oban_web --install ash_state_machine,ash_events \
      --install ash_money,ash_double_entry --install ash_archival,live_debugger \
      --install mishka_chelekom,tidewave --install ash_paper_trail,ash_ai \
      --install cloak,ash_cloak --install beacon,beacon_live_admin \
      --auth-strategy password --auth-strategy magic_link \
      --auth-strategy api_key --beacon.site cms \
      --beacon-live-admin.path /cms/admin --yes
    
    echo "✅ XAVOS generated with complete Ash ecosystem"
    
    # Navigate into project and run ash.setup - EXACT COMMAND AS SPECIFIED  
    echo "🏗️ Running Ash setup..."
    cd xavos && mix ash.setup
    echo "✅ Ash setup completed"
    cd ..
else
    echo "✅ XAVOS project already exists"
fi
echo ""

# Step 4: Configure XAVOS for S@S integration
echo "🤖 Step 4/8: Configuring XAVOS for S@S integration..."
cd xavos

# Create S@S integration configuration
mkdir -p config
cat > config/s2s_integration.exs <<'EOF'
# XAVOS S@S Agent Integration Configuration
import Config

# S@S Agent Coordination
config :xavos, :s2s_coordination,
  enabled: true,
  agent_registration: true,
  work_claiming: true,
  claude_integration: true,
  telemetry_integration: true

# OpenTelemetry for S@S coordination
config :opentelemetry,
  resource: [
    service: [
      name: "xavos-ash-phoenix",
      version: "1.0.0"
    ],
    deployment: [
      environment: Mix.env() |> to_string()
    ]
  ]

# Claude AI Integration for XAVOS
config :xavos, :claude_ai,
  integration_mode: "s2s_coordinated",
  output_format: "structured_json",
  focus_areas: ["ash_framework", "system_optimization", "user_experience"]

# XAVOS-specific Ash configuration
config :xavos, :ash,
  domains: [
    Xavos.Accounts,
    Xavos.Content,
    Xavos.Operations,
    Xavos.Intelligence,
    Xavos.Coordination
  ]
EOF

# Add S@S configuration import
if ! grep -q "s2s_integration.exs" config/config.exs; then
    echo 'import_config "s2s_integration.exs"' >> config/config.exs
fi

echo "✅ S@S integration configuration added"
echo ""

# Step 5: Create S@S coordination domains
echo "🏗️ Step 5/8: Creating S@S coordination domains..."

# Create coordination domain directory
mkdir -p lib/xavos/coordination

# Create main coordination domain
cat > lib/xavos/coordination.ex <<'EOF'
defmodule Xavos.Coordination do
  @moduledoc """
  XAVOS S@S Agent Coordination Domain
  
  Manages agent registration, work distribution, and coordination
  within the XAVOS system using Ash Framework.
  """
  
  use Ash.Domain
  
  resources do
    resource Xavos.Coordination.Agent
    resource Xavos.Coordination.WorkItem
  end
  
  authorization do
    authorize :by_default
  end
end
EOF

# Create Agent resource (simplified for initial deployment)
cat > lib/xavos/coordination/agent.ex <<'EOF'
defmodule Xavos.Coordination.Agent do
  @moduledoc """
  XAVOS Agent resource for S@S coordination
  """
  
  use Ash.Resource,
    domain: Xavos.Coordination,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "s2s_agents"
    repo Xavos.Repo
  end

  attributes do
    uuid_primary_key :id
    
    attribute :agent_id, :string do
      allow_nil? false
      public? true
    end
    
    attribute :specialization, :string do
      allow_nil? false
      public? true
    end
    
    attribute :team, :string do
      allow_nil? false
      public? true
    end
    
    attribute :capacity, :integer do
      allow_nil? false
      default 100
      public? true
    end
    
    attribute :current_workload, :integer do
      allow_nil? false
      default 0
      public? true
    end
    
    attribute :status, :string do
      allow_nil? false
      default "active"
      public? true
    end
    
    attribute :last_heartbeat, :utc_datetime do
      public? true
    end
    
    timestamps()
  end

  actions do
    defaults [:read, :destroy]
    
    create :register do
      accept [:agent_id, :specialization, :team, :capacity]
      
      change fn changeset, _context ->
        Ash.Changeset.change_attribute(changeset, :last_heartbeat, DateTime.utc_now())
      end
    end
    
    update :heartbeat do
      change fn changeset, _context ->
        Ash.Changeset.change_attribute(changeset, :last_heartbeat, DateTime.utc_now())
      end
    end
    
    read :active do
      filter expr(status == "active")
    end
  end

  identities do
    identity :unique_agent_id, [:agent_id]
  end
end
EOF

# Create WorkItem resource (simplified)
cat > lib/xavos/coordination/work_item.ex <<'EOF'
defmodule Xavos.Coordination.WorkItem do
  @moduledoc """
  XAVOS Work Item resource for S@S coordination
  """
  
  use Ash.Resource,
    domain: Xavos.Coordination,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "s2s_work_items"
    repo Xavos.Repo
  end

  attributes do
    uuid_primary_key :id
    
    attribute :work_item_id, :string do
      allow_nil? false
      public? true
    end
    
    attribute :work_type, :string do
      allow_nil? false
      public? true
    end
    
    attribute :description, :string do
      allow_nil? false
      public? true
    end
    
    attribute :priority, :string do
      allow_nil? false
      default "medium"
      public? true
    end
    
    attribute :status, :string do
      allow_nil? false
      default "pending"
      public? true
    end
    
    attribute :team, :string do
      allow_nil? false
      public? true
    end
    
    attribute :progress, :integer do
      default 0
      public? true
    end
    
    timestamps()
  end

  actions do
    defaults [:read, :destroy]
    
    create :create_work do
      accept [:work_item_id, :work_type, :description, :priority, :team]
    end
    
    update :update_progress do
      accept [:progress, :status]
    end
    
    read :available_work do
      filter expr(status == "pending")
    end
  end

  identities do
    identity :unique_work_item_id, [:work_item_id]
  end
end
EOF

echo "✅ S@S coordination domains created"
echo ""

# Step 6: Set up XAVOS database
echo "🗄️ Step 6/8: Setting up XAVOS database..."

# Install dependencies
echo "Installing dependencies..."
mix deps.get

# Set up database with error handling
echo "Setting up database..."
mix ecto.create --quiet || echo "Database may already exist"

# Generate migration for S@S tables
echo "Generating S@S coordination migration..."
mix ash_postgres.generate_migrations --name create_s2s_coordination

# Run migrations
echo "Running migrations..."
mix ecto.migrate

echo "✅ XAVOS database setup complete"
echo ""

# Step 7: Create agent coordinator script
echo "🤖 Step 7/8: Creating agent coordinator..."

mkdir -p scripts
cat > scripts/xavos_agent_coordinator.exs <<'EOF'
# XAVOS Agent Coordinator
# Registers initial agents for S@S coordination

alias Xavos.Coordination.Agent

# Register XAVOS development agents
IO.puts("🤖 Registering XAVOS development agents...")

agents = [
  %{
    agent_id: "xavos_dev_agent_#{System.system_time(:nanosecond)}",
    specialization: "development",
    team: "xavos_core",
    capacity: 100
  },
  %{
    agent_id: "xavos_ash_agent_#{System.system_time(:nanosecond)}",
    specialization: "ash_migration",
    team: "xavos_ash",
    capacity: 100
  },
  %{
    agent_id: "xavos_intel_agent_#{System.system_time(:nanosecond)}",
    specialization: "intelligence",
    team: "xavos_ai",
    capacity: 80
  }
]

Enum.each(agents, fn agent_config ->
  case Agent
       |> Ash.Changeset.for_create(:register, agent_config)
       |> Xavos.Coordination.create() do
    {:ok, agent} ->
      IO.puts("✅ Registered: #{agent.specialization} agent (#{agent.agent_id})")
    {:error, error} ->
      IO.puts("❌ Failed to register agent: #{inspect(error)}")
  end
end)

IO.puts("🎯 XAVOS agent registration complete!")
EOF

echo "✅ Agent coordinator created"
echo ""

# Step 8: Create startup and management scripts
echo "🚀 Step 8/8: Creating startup and management scripts..."

# Create startup script
cat > scripts/start_xavos.sh <<'EOF'
#!/bin/bash
# XAVOS Complete Startup Script

set -euo pipefail

XAVOS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$XAVOS_DIR"

echo "🌟 STARTING XAVOS: COMPLETE ASH PHOENIX SYSTEM"
echo "============================================="
echo ""

# Load environment configuration
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

echo "🔧 XAVOS Environment:"
echo "  Database: ${DB_NAME_DEV:-xavos_dev}"
echo "  Port: ${PORT:-4001}"
echo "  Environment: ${MIX_ENV:-dev}"
echo ""

# Install dependencies
echo "📦 Installing dependencies..."
mix deps.get
echo "✅ Dependencies installed"
echo ""

# Set up database
echo "🗄️ Setting up database..."
mix ecto.create --quiet || true
mix ecto.migrate --quiet
echo "✅ Database ready"
echo ""

# Register XAVOS agents
echo "🤖 Registering XAVOS agents..."
mix run scripts/xavos_agent_coordinator.exs
echo "✅ Agents registered"
echo ""

# Start Phoenix server
echo "🚀 Starting XAVOS Phoenix server..."
echo "🌐 Access XAVOS at: http://localhost:${PORT:-4001}"
echo "🎛️ Admin Panel: http://localhost:${PORT:-4001}/dev/dashboard"
echo ""

# Start with Phoenix
exec mix phx.server
EOF

# Create management script
cat > scripts/manage_xavos.sh <<'EOF'
#!/bin/bash
# XAVOS Management Script

set -euo pipefail

XAVOS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$XAVOS_DIR"

case "${1:-help}" in
    "start")
        echo "🚀 Starting XAVOS..."
        ./scripts/start_xavos.sh
        ;;
    "test")
        echo "🧪 Running XAVOS tests..."
        mix test
        ;;
    "agents")
        echo "🤖 XAVOS Agent Status:"
        mix run -e "
        try do
          agents = Xavos.Coordination.read!(Xavos.Coordination.Agent)
          IO.puts(\"Active Agents: #{length(agents)}\")
          Enum.each(agents, fn agent ->
            IO.puts(\"  🤖 #{agent.specialization}: #{agent.status} (#{agent.current_workload}/#{agent.capacity})\")
          end)
        rescue
          e -> IO.puts(\"Error reading agents: #{inspect(e)}\")
        end
        "
        ;;
    "reset")
        echo "🔄 Resetting XAVOS database..."
        mix ecto.reset
        mix run scripts/xavos_agent_coordinator.exs
        echo "✅ XAVOS reset complete"
        ;;
    *)
        echo "XAVOS Management Commands:"
        echo "  start    Start XAVOS system"
        echo "  test     Run test suite"
        echo "  agents   Show agent status"
        echo "  reset    Reset database"
        ;;
esac
EOF

chmod +x scripts/*.sh

echo "✅ XAVOS management scripts created"
echo ""

# Create S@S integration bridge
echo "🌉 Creating S@S integration bridge..."
cd "$SCRIPT_DIR"

cat > xavos_integration.sh <<'EOF'
#!/bin/bash
# XAVOS S@S Integration Bridge

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
XAVOS_DIR="$SCRIPT_DIR/../worktrees/xavos-system/xavos"

show_xavos_status() {
    echo "📊 XAVOS S@S INTEGRATION STATUS"
    echo "================================"
    echo ""
    
    if [ -d "$XAVOS_DIR" ]; then
        echo "✅ XAVOS system found at: $XAVOS_DIR"
        
        # Check if XAVOS is running
        if lsof -Pi :4001 -sTCP:LISTEN -t >/dev/null 2>&1; then
            echo "🟢 XAVOS Phoenix server running on port 4001"
        else
            echo "🔴 XAVOS Phoenix server not running"
        fi
        
        echo ""
        echo "🌐 XAVOS Access Points:"
        echo "  Main Application: http://localhost:4001"
        echo "  Phoenix Dashboard: http://localhost:4001/dev/dashboard"
        
    else
        echo "❌ XAVOS system not found"
        echo "   Run: ./deploy_xavos_complete.sh"
    fi
}

case "${1:-help}" in
    "status")
        show_xavos_status
        ;;
    "start-xavos")
        cd "$XAVOS_DIR"
        ./scripts/start_xavos.sh
        ;;
    *)
        echo "XAVOS S@S Integration Commands:"
        echo "  status      Show XAVOS integration status"
        echo "  start-xavos Start XAVOS system"
        ;;
esac
EOF

chmod +x xavos_integration.sh

echo "✅ S@S integration bridge created"
echo ""

# Final summary
echo "🎯 XAVOS DEPLOYMENT COMPLETE!"
echo "============================"
echo ""
echo "🏗️ XAVOS System Architecture:"
echo "  ✅ Complete Ash ecosystem with all packages"
echo "  ✅ S@S agent coordination integration"
echo "  ✅ Worktree-based isolation"
echo "  ✅ Database setup and migrations"
echo "  ✅ Agent registration system"
echo "  ✅ Management and startup scripts"
echo ""
echo "🚀 Start XAVOS:"
echo "  cd ../worktrees/xavos-system/xavos"
echo "  ./scripts/start_xavos.sh"
echo ""
echo "🌐 Access Points:"
echo "  Main App: http://localhost:4001"
echo "  Dashboard: http://localhost:4001/dev/dashboard"
echo ""
echo "🤖 S@S Integration:"
echo "  ./xavos_integration.sh status"
echo "  ./xavos_integration.sh start-xavos"
echo ""
echo "💡 Management:"
echo "  cd ../worktrees/xavos-system/xavos"
echo "  ./scripts/manage_xavos.sh agents"
echo "  ./scripts/manage_xavos.sh reset"
echo ""
echo "🎯 XAVOS: Advanced AI system ready for development!"
echo ""
echo "📚 Next Steps:"
echo "  1. Start XAVOS system"
echo "  2. Open Claude Code in the XAVOS worktree"
echo "  3. Begin development with full S@S coordination"
echo "  4. Use agent swarm for parallel development"