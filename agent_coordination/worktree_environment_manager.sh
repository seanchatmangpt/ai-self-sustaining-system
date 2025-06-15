#!/bin/bash

# S@S Worktree Environment Manager
# Handles database isolation, port allocation, and environment configuration

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WORKTREES_DIR="$PROJECT_ROOT/worktrees"
SHARED_COORDINATION_DIR="$PROJECT_ROOT/shared_coordination"

# Environment configuration
BASE_PORT=4000
BASE_DB_NAME="self_sustaining"
POSTGRES_USER="${POSTGRES_USER:-postgres}"
POSTGRES_HOST="${POSTGRES_HOST:-localhost}"

# Create environment registry
ENVIRONMENT_REGISTRY="$SHARED_COORDINATION_DIR/environment_registry.json"

# Initialize environment registry
init_environment_registry() {
    mkdir -p "$SHARED_COORDINATION_DIR"
    
    if [ ! -f "$ENVIRONMENT_REGISTRY" ]; then
        cat > "$ENVIRONMENT_REGISTRY" <<EOF
{
  "port_allocations": {
    "main": 4000,
    "base_port": 4000,
    "next_available": 4001
  },
  "database_allocations": {
    "main": "self_sustaining_dev",
    "test": "self_sustaining_test"
  },
  "worktree_environments": {}
}
EOF
    fi
}

# Allocate unique port for worktree
allocate_port() {
    local worktree_name="$1"
    
    init_environment_registry
    
    if command -v jq >/dev/null 2>&1; then
        local next_port=$(jq -r '.port_allocations.next_available' "$ENVIRONMENT_REGISTRY")
        
        # Check if port is actually available
        while lsof -Pi :$next_port -sTCP:LISTEN -t >/dev/null 2>&1; do
            next_port=$((next_port + 1))
        done
        
        # Update registry
        local temp_file=$(mktemp)
        jq ".port_allocations.next_available = $((next_port + 1)) | .port_allocations[\"$worktree_name\"] = $next_port" "$ENVIRONMENT_REGISTRY" > "$temp_file"
        mv "$temp_file" "$ENVIRONMENT_REGISTRY"
        
        echo "$next_port"
    else
        # Fallback without jq
        echo $((BASE_PORT + $(find "$WORKTREES_DIR" -maxdepth 1 -type d | wc -l)))
    fi
}

# Allocate unique database name for worktree
allocate_database() {
    local worktree_name="$1"
    local environment="${2:-dev}"
    
    init_environment_registry
    
    local db_name="${BASE_DB_NAME}_${worktree_name}_${environment}"
    # Sanitize database name
    db_name=$(echo "$db_name" | tr '-' '_' | tr '[:upper:]' '[:lower:]')
    
    if command -v jq >/dev/null 2>&1; then
        local temp_file=$(mktemp)
        jq ".database_allocations[\"${worktree_name}_${environment}\"] = \"$db_name\"" "$ENVIRONMENT_REGISTRY" > "$temp_file"
        mv "$temp_file" "$ENVIRONMENT_REGISTRY"
    fi
    
    echo "$db_name"
}

# Create database for worktree
create_worktree_database() {
    local worktree_name="$1"
    local db_dev=$(allocate_database "$worktree_name" "dev")
    local db_test=$(allocate_database "$worktree_name" "test")
    
    echo "🗄️  Creating databases for worktree: $worktree_name"
    echo "   Dev:  $db_dev"
    echo "   Test: $db_test"
    
    # Create development database
    if command -v createdb >/dev/null 2>&1; then
        createdb -h "$POSTGRES_HOST" -U "$POSTGRES_USER" "$db_dev" 2>/dev/null || echo "   ⚠️  Database $db_dev may already exist"
        createdb -h "$POSTGRES_HOST" -U "$POSTGRES_USER" "$db_test" 2>/dev/null || echo "   ⚠️  Database $db_test may already exist"
    else
        echo "   ⚠️  createdb not found. Manual database creation required:"
        echo "      psql -h $POSTGRES_HOST -U $POSTGRES_USER -c \"CREATE DATABASE $db_dev;\""
        echo "      psql -h $POSTGRES_HOST -U $POSTGRES_USER -c \"CREATE DATABASE $db_test;\""
    fi
}

# Generate environment configuration for worktree
generate_worktree_env() {
    local worktree_name="$1"
    local worktree_path="$2"
    
    local port=$(allocate_port "$worktree_name")
    local db_dev=$(allocate_database "$worktree_name" "dev")
    local db_test=$(allocate_database "$worktree_name" "test")
    
    # Create .env file for worktree
    cat > "$worktree_path/.env" <<EOF
# S@S Worktree Environment Configuration
# Generated for worktree: $worktree_name

# Phoenix Configuration
PHX_SERVER=true
PORT=$port
PHX_HOST=localhost

# Database Configuration  
DATABASE_URL=postgres://$POSTGRES_USER@$POSTGRES_HOST:5432/$db_dev
TEST_DATABASE_URL=postgres://$POSTGRES_USER@$POSTGRES_HOST:5432/$db_test

# Database Names
DB_NAME_DEV=$db_dev
DB_NAME_TEST=$db_test

# OpenTelemetry Configuration
OTEL_SERVICE_NAME=s2s-worktree-$worktree_name
OTEL_SERVICE_VERSION=1.0.0
OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4318

# S@S Coordination
WORKTREE_NAME=$worktree_name
SHARED_COORDINATION_DIR=$SHARED_COORDINATION_DIR

# Asset Configuration
ASSETS_PORT=$((port + 1000))
LIVERELOAD_PORT=$((port + 2000))
EOF

    # Create Elixir configuration overlay
    mkdir -p "$worktree_path/config"
    cat > "$worktree_path/config/worktree_overlay.exs" <<EOF
# S@S Worktree Configuration Overlay
# Auto-generated for worktree: $worktree_name

import Config

# Environment-specific database configuration
config :self_sustaining_ash, SelfSustainingAsh.Repo,
  database: "$db_dev",
  hostname: "$POSTGRES_HOST",
  username: "$POSTGRES_USER",
  pool_size: 10

# Phoenix endpoint configuration
config :self_sustaining_ash, SelfSustainingAshWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: $port],
  url: [host: "localhost", port: $port],
  server: true

# LiveReload configuration (dev only)
if Mix.env() == :dev do
  config :self_sustaining_ash, SelfSustainingAshWeb.Endpoint,
    live_reload: [
      patterns: [
        ~r"priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$",
        ~r"priv/gettext/.*(po)$", 
        ~r"lib/self_sustaining_ash_web/(controllers|live|components)/.*(ex|heex)$"
      ],
      port: $((port + 2000))
    ]
end

# Test environment
if Mix.env() == :test do
  config :self_sustaining_ash, SelfSustainingAsh.Repo,
    database: "$db_test",
    pool: Ecto.Adapters.SQL.Sandbox,
    pool_size: 10
end

# OpenTelemetry configuration
config :opentelemetry,
  resource: [
    service: [
      name: "s2s-worktree-$worktree_name",
      version: "1.0.0"
    ]
  ]

# S@S Coordination configuration  
config :self_sustaining_ash, :s2s_coordination,
  worktree_name: "$worktree_name",
  shared_coordination_dir: "$SHARED_COORDINATION_DIR"
EOF

    echo "📝 Environment configuration created:"
    echo "   Port: $port"
    echo "   Dev DB: $db_dev" 
    echo "   Test DB: $db_test"
    echo "   Config: $worktree_path/.env"
    echo "   Overlay: $worktree_path/config/worktree_overlay.exs"
}

# Setup development environment for worktree
setup_worktree_environment() {
    local worktree_name="$1"
    local worktree_path="$2"
    
    echo "🔧 Setting up environment for worktree: $worktree_name"
    
    # Generate environment configuration
    generate_worktree_env "$worktree_name" "$worktree_path"
    
    # Create databases
    create_worktree_database "$worktree_name"
    
    # Create development scripts
    create_worktree_scripts "$worktree_name" "$worktree_path"
    
    # Update environment registry
    update_environment_registry "$worktree_name" "$worktree_path"
}

# Create worktree-specific development scripts
create_worktree_scripts() {
    local worktree_name="$1"
    local worktree_path="$2"
    
    mkdir -p "$worktree_path/scripts"
    
    # Start script
    cat > "$worktree_path/scripts/start.sh" <<EOF
#!/bin/bash
# Start worktree development environment

set -euo pipefail

SCRIPT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
WORKTREE_DIR="\$(cd "\$SCRIPT_DIR/.." && pwd)"

# Load environment
if [ -f "\$WORKTREE_DIR/.env" ]; then
    export \$(cat "\$WORKTREE_DIR/.env" | grep -v '^#' | xargs)
fi

cd "\$WORKTREE_DIR"

echo "🚀 Starting $worktree_name development environment..."
echo "📍 Directory: \$WORKTREE_DIR"
echo "🌐 URL: http://localhost:\$PORT"
echo "🗄️  Database: \$DB_NAME_DEV"

# Install dependencies
mix deps.get

# Set up database
mix ecto.create --quiet || true
mix ecto.migrate --quiet || true

# Install assets
if [ -d "assets" ]; then
    cd assets && npm install && cd ..
fi

# Start Phoenix server
mix phx.server
EOF

    # Test script
    cat > "$worktree_path/scripts/test.sh" <<EOF
#!/bin/bash
# Run tests for worktree

set -euo pipefail

SCRIPT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
WORKTREE_DIR="\$(cd "\$SCRIPT_DIR/.." && pwd)"

# Load environment
if [ -f "\$WORKTREE_DIR/.env" ]; then
    export \$(cat "\$WORKTREE_DIR/.env" | grep -v '^#' | xargs)
fi

cd "\$WORKTREE_DIR"

echo "🧪 Running tests for $worktree_name..."

# Set up test database
MIX_ENV=test mix ecto.create --quiet || true
MIX_ENV=test mix ecto.migrate --quiet || true

# Run tests
MIX_ENV=test mix test
EOF

    # Cleanup script
    cat > "$worktree_path/scripts/cleanup.sh" <<EOF
#!/bin/bash
# Cleanup worktree environment

set -euo pipefail

echo "🧹 Cleaning up $worktree_name environment..."

# Stop any running processes
pkill -f "mix phx.server.*$worktree_name" || true
pkill -f "beam.*$worktree_name" || true

# Remove databases
dropdb -h $POSTGRES_HOST -U $POSTGRES_USER --if-exists \$DB_NAME_DEV || true
dropdb -h $POSTGRES_HOST -U $POSTGRES_USER --if-exists \$DB_NAME_TEST || true

echo "✅ Cleanup complete"
EOF

    chmod +x "$worktree_path/scripts/"*.sh
    
    echo "📜 Development scripts created:"
    echo "   Start: $worktree_path/scripts/start.sh"
    echo "   Test:  $worktree_path/scripts/test.sh" 
    echo "   Clean: $worktree_path/scripts/cleanup.sh"
}

# Update environment registry
update_environment_registry() {
    local worktree_name="$1"
    local worktree_path="$2"
    
    if command -v jq >/dev/null 2>&1; then
        local port=$(jq -r ".port_allocations[\"$worktree_name\"]" "$ENVIRONMENT_REGISTRY")
        local db_dev=$(jq -r ".database_allocations[\"${worktree_name}_dev\"]" "$ENVIRONMENT_REGISTRY")
        local db_test=$(jq -r ".database_allocations[\"${worktree_name}_test\"]" "$ENVIRONMENT_REGISTRY")
        
        local env_config=$(cat <<EOF
{
  "worktree_path": "$worktree_path",
  "port": $port,
  "database_dev": "$db_dev",
  "database_test": "$db_test", 
  "created_at": "$(python3 -c "import datetime; print(datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%S.%fZ')[:-3]+'Z')")",
  "status": "active"
}
EOF
        )
        
        local temp_file=$(mktemp)
        jq ".worktree_environments[\"$worktree_name\"] = $env_config" "$ENVIRONMENT_REGISTRY" > "$temp_file"
        mv "$temp_file" "$ENVIRONMENT_REGISTRY"
    fi
}

# List all worktree environments
list_environments() {
    echo "🌍 WORKTREE ENVIRONMENTS"
    echo "========================"
    
    if [ ! -f "$ENVIRONMENT_REGISTRY" ]; then
        echo "No environments configured"
        return 0
    fi
    
    if command -v jq >/dev/null 2>&1; then
        echo "Port Allocations:"
        jq -r '.port_allocations | to_entries[] | "  \(.key): \(.value)"' "$ENVIRONMENT_REGISTRY"
        echo ""
        
        echo "Database Allocations:"
        jq -r '.database_allocations | to_entries[] | "  \(.key): \(.value)"' "$ENVIRONMENT_REGISTRY"
        echo ""
        
        echo "Worktree Environments:"
        jq -r '.worktree_environments | to_entries[] | "  \(.key): Port \(.value.port), DB \(.value.database_dev)"' "$ENVIRONMENT_REGISTRY"
    else
        echo "Environment registry exists but jq not available for detailed view"
    fi
}

# Clean up environment for removed worktree
cleanup_environment() {
    local worktree_name="$1"
    
    echo "🧹 Cleaning up environment for: $worktree_name"
    
    if command -v jq >/dev/null 2>&1 && [ -f "$ENVIRONMENT_REGISTRY" ]; then
        # Get database names
        local db_dev=$(jq -r ".database_allocations[\"${worktree_name}_dev\"] // empty" "$ENVIRONMENT_REGISTRY")
        local db_test=$(jq -r ".database_allocations[\"${worktree_name}_test\"] // empty" "$ENVIRONMENT_REGISTRY")
        
        # Drop databases
        if [ -n "$db_dev" ]; then
            dropdb -h "$POSTGRES_HOST" -U "$POSTGRES_USER" --if-exists "$db_dev" || true
        fi
        if [ -n "$db_test" ]; then
            dropdb -h "$POSTGRES_HOST" -U "$POSTGRES_USER" --if-exists "$db_test" || true
        fi
        
        # Update registry
        local temp_file=$(mktemp)
        jq "del(.port_allocations[\"$worktree_name\"]) | del(.database_allocations[\"${worktree_name}_dev\"]) | del(.database_allocations[\"${worktree_name}_test\"]) | del(.worktree_environments[\"$worktree_name\"])" "$ENVIRONMENT_REGISTRY" > "$temp_file"
        mv "$temp_file" "$ENVIRONMENT_REGISTRY"
        
        echo "✅ Environment cleanup complete"
    fi
}

# Main execution
main() {
    local command="${1:-help}"
    
    case "$command" in
        "setup")
            if [ $# -lt 3 ]; then
                echo "Usage: $0 setup <worktree_name> <worktree_path>"
                exit 1
            fi
            setup_worktree_environment "$2" "$3"
            ;;
        "list")
            list_environments
            ;;
        "cleanup")
            if [ $# -lt 2 ]; then
                echo "Usage: $0 cleanup <worktree_name>"
                exit 1
            fi
            cleanup_environment "$2"
            ;;
        "allocate-port")
            if [ $# -lt 2 ]; then
                echo "Usage: $0 allocate-port <worktree_name>"
                exit 1
            fi
            allocate_port "$2"
            ;;
        "allocate-db")
            if [ $# -lt 2 ]; then
                echo "Usage: $0 allocate-db <worktree_name> [environment]"
                exit 1
            fi
            allocate_database "$2" "${3:-dev}"
            ;;
        *)
            echo "S@S Worktree Environment Manager"
            echo "Usage: $0 <command> [options]"
            echo ""
            echo "Commands:"
            echo "  setup <name> <path>    Set up complete environment for worktree"
            echo "  list                   List all environment allocations"
            echo "  cleanup <name>         Clean up environment for worktree"
            echo "  allocate-port <name>   Allocate unique port for worktree"
            echo "  allocate-db <name>     Allocate unique database for worktree"
            ;;
    esac
}

# Run if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi