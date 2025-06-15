#!/bin/bash

# XAVOS Realistic Deployment Script
# Incremental, tested approach with proper error handling

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
XAVOS_WORKTREE_PATH="$PROJECT_ROOT/worktrees/xavos-system"
DEPLOYMENT_LOG="$SCRIPT_DIR/xavos_deployment.log"

# Color output for better UX
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} [${level}] ${message}" | tee -a "$DEPLOYMENT_LOG"
}

info() {
    log "INFO" "${BLUE}$*${NC}"
}

success() {
    log "SUCCESS" "${GREEN}$*${NC}"
}

warning() {
    log "WARNING" "${YELLOW}$*${NC}"
}

error() {
    log "ERROR" "${RED}$*${NC}"
}

# Cleanup function for failures
cleanup_on_failure() {
    error "Deployment failed. Cleaning up..."
    
    # Stop any running servers
    pkill -f "mix phx.server" || true
    
    # Clean up worktree if it was created
    if [ -d "$XAVOS_WORKTREE_PATH" ]; then
        cd "$PROJECT_ROOT"
        git worktree remove "$XAVOS_WORKTREE_PATH" --force 2>/dev/null || true
        rm -rf "$XAVOS_WORKTREE_PATH" 2>/dev/null || true
    fi
    
    # Clean up database
    if command -v dropdb >/dev/null 2>&1; then
        dropdb --if-exists xavos_xavos_system_dev 2>/dev/null || true
        dropdb --if-exists xavos_xavos_system_test 2>/dev/null || true
    fi
    
    error "Cleanup completed. Check $DEPLOYMENT_LOG for details."
}

trap cleanup_on_failure ERR

# Validation functions
validate_prerequisites() {
    info "Validating prerequisites..."
    
    local missing_deps=()
    
    if ! command -v elixir >/dev/null 2>&1; then
        missing_deps+=("elixir")
    fi
    
    if ! command -v mix >/dev/null 2>&1; then
        missing_deps+=("mix")
    fi
    
    if ! command -v node >/dev/null 2>&1; then
        missing_deps+=("node")
    fi
    
    if ! command -v git >/dev/null 2>&1; then
        missing_deps+=("git")
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        error "Missing required dependencies: ${missing_deps[*]}"
        error "Please install missing dependencies and try again"
        return 1
    fi
    
    # Check PostgreSQL
    if ! command -v psql >/dev/null 2>&1; then
        warning "PostgreSQL client not found. Database operations may fail."
        warning "Please install PostgreSQL client (psql)"
    else
        if ! psql -h localhost -U postgres -c "SELECT 1;" >/dev/null 2>&1; then
            warning "Cannot connect to PostgreSQL server"
            warning "Please ensure PostgreSQL is running and accessible"
            warning "You may need to create a postgres user or update connection settings"
        else
            success "PostgreSQL connection verified"
        fi
    fi
    
    success "Prerequisites validation completed"
}

validate_package_exists() {
    local package="$1"
    info "Validating package: $package"
    
    if mix hex.info "$package" >/dev/null 2>&1; then
        success "Package $package exists and is accessible"
        return 0
    else
        error "Package $package not found on Hex"
        return 1
    fi
}

# Core Phoenix app creation
create_basic_phoenix_app() {
    info "Creating basic Phoenix application..."
    
    cd "$XAVOS_WORKTREE_PATH"
    
    # Create basic Phoenix app
    mix phx.new xavos --live --database postgres --binary-id --no-install
    
    cd xavos
    
    # Get initial dependencies
    info "Installing initial dependencies..."
    mix deps.get
    
    success "Basic Phoenix application created"
}

# Database setup with proper error handling
setup_database() {
    info "Setting up database..."
    
    cd "$XAVOS_WORKTREE_PATH/xavos"
    
    # Load environment variables
    if [ -f "../.env" ]; then
        export $(cat ../.env | grep -v '^#' | xargs)
    fi
    
    # Create database with retry logic
    local max_retries=3
    local retry=0
    
    while [ $retry -lt $max_retries ]; do
        if mix ecto.create --quiet; then
            success "Database created successfully"
            break
        else
            retry=$((retry + 1))
            if [ $retry -lt $max_retries ]; then
                warning "Database creation failed, retrying ($retry/$max_retries)..."
                sleep 2
            else
                error "Failed to create database after $max_retries attempts"
                error "Please check PostgreSQL configuration and permissions"
                return 1
            fi
        fi
    done
    
    # Run migrations
    info "Running initial migrations..."
    mix ecto.migrate
    
    success "Database setup completed"
}

# Incremental package installation
install_ash_core() {
    info "Installing core Ash packages..."
    
    cd "$XAVOS_WORKTREE_PATH/xavos"
    
    # Core Ash packages (most stable)
    local core_packages=(
        "ash:~>3.0"
        "ash_postgres:~>2.0"
        "ash_phoenix:~>2.0"
    )
    
    for package_spec in "${core_packages[@]}"; do
        local package=$(echo "$package_spec" | cut -d: -f1)
        local version=$(echo "$package_spec" | cut -d: -f2)
        
        info "Installing $package $version..."
        
        # Add to mix.exs
        if ! grep -q "$package" mix.exs; then
            # Add dependency to mix.exs (simplified approach)
            sed -i.bak "s/defp deps do/defp deps do\\n      {:$package, \"$version\"},/" mix.exs
            
            # Get dependencies
            if mix deps.get; then
                success "$package installed successfully"
            else
                error "Failed to install $package"
                return 1
            fi
            
            # Compile
            if mix compile; then
                success "$package compiled successfully"
            else
                error "Failed to compile after adding $package"
                return 1
            fi
        else
            info "$package already installed"
        fi
    done
    
    success "Core Ash packages installed"
}

install_ash_authentication() {
    info "Installing Ash authentication..."
    
    cd "$XAVOS_WORKTREE_PATH/xavos"
    
    # Authentication packages
    local auth_packages=(
        "ash_authentication:~>4.0"
        "ash_authentication_phoenix:~>2.0"
    )
    
    for package_spec in "${auth_packages[@]}"; do
        local package=$(echo "$package_spec" | cut -d: -f1)
        local version=$(echo "$package_spec" | cut -d: -f2)
        
        info "Installing $package $version..."
        
        if ! grep -q "$package" mix.exs; then
            sed -i.bak "s/defp deps do/defp deps do\\n      {:$package, \"$version\"},/" mix.exs
            
            if mix deps.get && mix compile; then
                success "$package installed and compiled"
            else
                error "Failed to install $package"
                return 1
            fi
        fi
    done
    
    success "Ash authentication packages installed"
}

install_ash_extras() {
    info "Installing additional Ash packages..."
    
    cd "$XAVOS_WORKTREE_PATH/xavos"
    
    # Additional packages (install if available)
    local extra_packages=(
        "ash_admin:~>0.10"
        "ash_json_api:~>1.4"
    )
    
    for package_spec in "${extra_packages[@]}"; do
        local package=$(echo "$package_spec" | cut -d: -f1)
        local version=$(echo "$package_spec" | cut -d: -f2)
        
        info "Attempting to install $package $version..."
        
        if validate_package_exists "$package"; then
            if ! grep -q "$package" mix.exs; then
                sed -i.bak "s/defp deps do/defp deps do\\n      {:$package, \"$version\"},/" mix.exs
                
                if mix deps.get && mix compile; then
                    success "$package installed and compiled"
                else
                    warning "Failed to install $package, skipping..."
                    # Revert changes
                    mv mix.exs.bak mix.exs
                fi
            fi
        else
            warning "$package not available, skipping..."
        fi
    done
    
    success "Additional Ash packages processed"
}

# Create basic Ash domain and resources
create_ash_foundation() {
    info "Creating Ash foundation..."
    
    cd "$XAVOS_WORKTREE_PATH/xavos"
    
    # Create basic domain directory
    mkdir -p lib/xavos/coordination
    
    # Create minimal domain
    cat > lib/xavos/coordination.ex <<'EOF'
defmodule Xavos.Coordination do
  @moduledoc """
  XAVOS Coordination Domain - Basic S@S integration
  """
  
  use Ash.Domain
  
  resources do
    resource Xavos.Coordination.Agent
  end
end
EOF

    # Create minimal agent resource
    cat > lib/xavos/coordination/agent.ex <<'EOF'
defmodule Xavos.Coordination.Agent do
  @moduledoc """
  Basic Agent resource for S@S coordination
  """
  
  use Ash.Resource,
    domain: Xavos.Coordination,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "coordination_agents"
    repo Xavos.Repo
  end

  attributes do
    uuid_primary_key :id
    
    attribute :agent_id, :string do
      allow_nil? false
      public? true
    end
    
    attribute :name, :string do
      allow_nil? false
      public? true
    end
    
    attribute :status, :string do
      allow_nil? false
      default "active"
      public? true
    end
    
    timestamps()
  end

  actions do
    defaults [:read, :destroy]
    
    create :create do
      accept [:agent_id, :name, :status]
    end
    
    update :update do
      accept [:name, :status]
    end
  end

  identities do
    identity :unique_agent_id, [:agent_id]
  end
end
EOF

    success "Ash foundation created"
}

# Generate and run Ash migrations
setup_ash_database() {
    info "Setting up Ash database..."
    
    cd "$XAVOS_WORKTREE_PATH/xavos"
    
    # Generate Ash migrations
    if command -v mix | grep -q ash_postgres; then
        info "Generating Ash migrations..."
        mix ash_postgres.generate_migrations --name create_coordination_tables
    else
        # Manual migration if ash_postgres generator not available
        info "Creating manual migration..."
        migration_file="priv/repo/migrations/$(date +%Y%m%d%H%M%S)_create_coordination_tables.exs"
        mkdir -p priv/repo/migrations
        
        cat > "$migration_file" <<'EOF'
defmodule Xavos.Repo.Migrations.CreateCoordinationTables do
  use Ecto.Migration

  def change do
    create table(:coordination_agents, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :agent_id, :string, null: false
      add :name, :string, null: false
      add :status, :string, null: false, default: "active"
      
      timestamps()
    end
    
    create unique_index(:coordination_agents, [:agent_id])
  end
end
EOF
    fi
    
    # Run migrations
    info "Running Ash migrations..."
    mix ecto.migrate
    
    success "Ash database setup completed"
}

# Test the installation
test_installation() {
    info "Testing XAVOS installation..."
    
    cd "$XAVOS_WORKTREE_PATH/xavos"
    
    # Compile everything
    info "Compiling application..."
    if ! mix compile; then
        error "Compilation failed"
        return 1
    fi
    
    # Test basic functionality
    info "Testing basic functionality..."
    if mix run -e "IO.puts('XAVOS basic test: ' <> inspect(Xavos.Coordination))"; then
        success "Basic functionality test passed"
    else
        error "Basic functionality test failed"
        return 1
    fi
    
    # Test database connectivity
    info "Testing database connectivity..."
    if mix run -e "Xavos.Repo.all(Xavos.Coordination.Agent) |> IO.inspect()"; then
        success "Database connectivity test passed"
    else
        error "Database connectivity test failed"
        return 1
    fi
    
    success "Installation testing completed"
}

# Create management scripts
create_management_scripts() {
    info "Creating management scripts..."
    
    cd "$XAVOS_WORKTREE_PATH/xavos"
    mkdir -p scripts
    
    # Basic startup script
    cat > scripts/start_xavos.sh <<'EOF'
#!/bin/bash
# XAVOS Startup Script

set -euo pipefail

XAVOS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$XAVOS_DIR"

echo "🌟 Starting XAVOS System"
echo "======================="

# Load environment
if [ -f ../.env ]; then
    export $(cat ../.env | grep -v '^#' | xargs)
fi

echo "🔧 Environment: ${MIX_ENV:-dev}"
echo "🗄️ Database: ${DB_NAME_DEV:-xavos_dev}"
echo "🌐 Port: ${PORT:-4001}"
echo ""

# Setup
mix deps.get --quiet
mix ecto.migrate --quiet

echo "🚀 Starting Phoenix server..."
echo "🌐 Access at: http://localhost:${PORT:-4001}"
echo ""

exec mix phx.server
EOF

    # Management script
    cat > scripts/manage_xavos.sh <<'EOF'
#!/bin/bash
# XAVOS Management Script

XAVOS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$XAVOS_DIR"

case "${1:-help}" in
    "start")
        ./scripts/start_xavos.sh
        ;;
    "test")
        echo "🧪 Running tests..."
        mix test
        ;;
    "console")
        echo "🔧 Starting IEx console..."
        iex -S mix
        ;;
    "reset")
        echo "🔄 Resetting database..."
        mix ecto.reset
        ;;
    "agents")
        echo "🤖 Agent status..."
        mix run -e "Xavos.Repo.all(Xavos.Coordination.Agent) |> IO.inspect(label: \"Agents\")"
        ;;
    *)
        echo "XAVOS Management Commands:"
        echo "  start     Start XAVOS server"
        echo "  test      Run test suite"
        echo "  console   Start IEx console"
        echo "  reset     Reset database"
        echo "  agents    Show agents"
        ;;
esac
EOF

    chmod +x scripts/*.sh
    
    success "Management scripts created"
}

# Main deployment flow
main() {
    info "🌟 XAVOS REALISTIC DEPLOYMENT"
    info "=========================="
    info "Incremental, tested approach with proper error handling"
    info ""
    
    # Start deployment log
    echo "XAVOS Deployment Log - $(date)" > "$DEPLOYMENT_LOG"
    
    # Step 1: Prerequisites
    validate_prerequisites
    
    # Step 2: Create worktree (if not exists)
    if [ ! -d "$XAVOS_WORKTREE_PATH" ]; then
        info "Creating XAVOS worktree..."
        cd "$SCRIPT_DIR"
        ./create_s2s_worktree.sh xavos-system xavos-main master
        ./worktree_environment_manager.sh setup xavos-system "$XAVOS_WORKTREE_PATH"
        success "XAVOS worktree created"
    else
        info "XAVOS worktree already exists"
    fi
    
    # Step 3: Create Phoenix app (if not exists)
    if [ ! -d "$XAVOS_WORKTREE_PATH/xavos" ]; then
        create_basic_phoenix_app
    else
        info "Phoenix app already exists"
    fi
    
    # Step 4: Database setup
    setup_database
    
    # Step 5: Install Ash packages incrementally
    install_ash_core
    install_ash_authentication
    install_ash_extras
    
    # Step 6: Create Ash foundation
    create_ash_foundation
    setup_ash_database
    
    # Step 7: Test installation
    test_installation
    
    # Step 8: Create management scripts
    create_management_scripts
    
    # Success!
    success "🎯 XAVOS REALISTIC DEPLOYMENT COMPLETE!"
    success "======================================"
    success ""
    success "📍 Location: $XAVOS_WORKTREE_PATH/xavos"
    success "🚀 Start: cd $XAVOS_WORKTREE_PATH/xavos && ./scripts/start_xavos.sh"
    success "🎛️ Manage: cd $XAVOS_WORKTREE_PATH/xavos && ./scripts/manage_xavos.sh"
    success "📋 Logs: $DEPLOYMENT_LOG"
    success ""
    success "🌟 XAVOS is ready for development!"
}

# Run main function
main "$@"