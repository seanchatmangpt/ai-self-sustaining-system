#!/bin/bash

# XAVOS: Exact Commands Implementation
# Uses the precise shell commands as specified

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "🌟 XAVOS: EXACT COMMANDS IMPLEMENTATION"
echo "======================================"
echo "Using the precise shell commands as specified"
echo ""

# Step 1: Create worktree with S@S integration
echo "📂 Step 1/5: Creating XAVOS worktree..."
cd "$SCRIPT_DIR"

if [ ! -d "../worktrees/xavos-system" ]; then
    ./create_s2s_worktree.sh xavos-system xavos-main master
    ./worktree_environment_manager.sh setup xavos-system "../worktrees/xavos-system"
    echo "✅ XAVOS worktree created with S@S coordination"
else
    echo "✅ XAVOS worktree already exists"
fi
echo ""

# Step 2: Navigate to worktree
echo "📍 Step 2/5: Navigating to worktree..."
cd "../worktrees/xavos-system"
echo "Working directory: $(pwd)"
echo ""

# Step 3: Install archives (EXACT COMMANDS)
echo "📦 Step 3/5: Installing archives..."
echo "Running: mix archive.install hex igniter_new --force"
mix archive.install hex igniter_new --force

echo "Running: mix archive.install hex phx_new 1.8.0-rc.3 --force"
mix archive.install hex phx_new 1.8.0-rc.3 --force

echo "✅ Archives installed"
echo ""

# Step 4: Generate XAVOS project (EXACT COMMAND)
echo "🔥 Step 4/5: Generating XAVOS with complete Ash ecosystem..."

if [ ! -d "xavos" ]; then
    echo "Running the complete igniter.new command..."
    echo ""
    
    # Load environment variables if available
    if [ -f .env ]; then
        export $(cat .env | grep -v '^#' | xargs)
    fi
    
    # EXACT COMMAND AS SPECIFIED - NO MODIFICATIONS
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
    
    echo "✅ XAVOS project generated"
else
    echo "✅ XAVOS project already exists"
fi
echo ""

# Step 5: Run ash.setup (EXACT COMMAND)
echo "🏗️ Step 5/5: Running Ash setup..."
echo "Running: cd xavos && mix ash.setup"

# EXACT COMMAND AS SPECIFIED
cd xavos && mix ash.setup

echo "✅ Ash setup completed"
echo ""

# Create management scripts for the generated project
echo "🛠️ Creating management scripts..."

mkdir -p scripts

# Create start script
cat > scripts/start_xavos.sh <<'EOF'
#!/bin/bash
# XAVOS Startup Script

set -euo pipefail

echo "🌟 Starting XAVOS System"
echo "======================="

# Load environment
if [ -f ../.env ]; then
    export $(cat ../.env | grep -v '^#' | xargs)
fi

echo "🔧 Environment: ${MIX_ENV:-dev}"
echo "🌐 Port: ${PORT:-4001}"
echo ""

# Ensure dependencies and database are ready
mix deps.get --quiet
mix ecto.migrate --quiet

echo "🚀 Starting XAVOS Phoenix server..."
echo "🌐 Access at: http://localhost:${PORT:-4001}"
echo "🎛️ Admin at: http://localhost:${PORT:-4001}/dev/dashboard"
echo "📝 CMS at: http://localhost:${PORT:-4001}/cms/admin"
echo ""

exec mix phx.server
EOF

# Create management script
cat > scripts/manage_xavos.sh <<'EOF'
#!/bin/bash
# XAVOS Management Script

case "${1:-help}" in
    "start")
        ./scripts/start_xavos.sh
        ;;
    "console")
        echo "🔧 Starting IEx console..."
        iex -S mix
        ;;
    "test")
        echo "🧪 Running tests..."
        mix test
        ;;
    "reset")
        echo "🔄 Resetting database..."
        mix ecto.reset
        ;;
    "deps")
        echo "📦 Checking dependencies..."
        mix deps.get
        mix compile
        ;;
    "info")
        echo "📋 XAVOS Project Information"
        echo "=========================="
        echo "Location: $(pwd)"
        echo "Elixir: $(elixir --version | head -1)"
        echo "Phoenix: $(mix phx.new --version)"
        echo ""
        echo "Key dependencies:"
        grep -E "(ash|phoenix|beacon)" mix.exs | sed 's/^/  /'
        ;;
    *)
        echo "XAVOS Management Commands:"
        echo "  start     Start XAVOS server"
        echo "  console   Start IEx console"
        echo "  test      Run test suite"
        echo "  reset     Reset database"
        echo "  deps      Install/update dependencies"
        echo "  info      Show project information"
        ;;
esac
EOF

chmod +x scripts/*.sh

echo "✅ Management scripts created"
echo ""

# Show final status
echo "🎯 XAVOS DEPLOYMENT COMPLETE!"
echo "============================="
echo ""
echo "📍 Project Location: $(pwd)"
echo "🏗️ Generated with: igniter.new + complete Ash ecosystem"
echo "🗄️ Database: Set up with ash.setup"
echo ""
echo "🚀 Start XAVOS:"
echo "   ./scripts/start_xavos.sh"
echo ""
echo "🎛️ Management:"
echo "   ./scripts/manage_xavos.sh info     # Project information"
echo "   ./scripts/manage_xavos.sh console  # Interactive console"
echo "   ./scripts/manage_xavos.sh test     # Run tests"
echo ""
echo "🌐 Access Points (after starting):"
echo "   Main App: http://localhost:4001"
echo "   Phoenix Dashboard: http://localhost:4001/dev/dashboard"
echo "   Beacon CMS: http://localhost:4001/cms/admin"
echo ""
echo "📋 Installed Packages:"
echo "   ✅ ash + ash_phoenix + ash_postgres"
echo "   ✅ ash_authentication (password, magic_link, api_key)"
echo "   ✅ ash_admin + ash_json_api"
echo "   ✅ ash_oban + oban_web (background jobs)"
echo "   ✅ ash_state_machine + ash_events"
echo "   ✅ ash_money + ash_double_entry"
echo "   ✅ beacon + beacon_live_admin (CMS)"
echo "   ✅ mishka_chelekom + tidewave"
echo "   ✅ ash_paper_trail + ash_ai"
echo "   ✅ cloak + ash_cloak (encryption)"
echo ""
echo "🤖 S@S Integration:"
echo "   Agent coordination available in worktree"
echo "   Use Claude Code CLI in this directory for AI development"
echo ""
echo "🌟 XAVOS is ready for advanced Ash Phoenix development!"

# Show worktree status
echo ""
echo "📊 S@S Worktree Status:"
cd "$SCRIPT_DIR"
./manage_worktrees.sh status xavos-system