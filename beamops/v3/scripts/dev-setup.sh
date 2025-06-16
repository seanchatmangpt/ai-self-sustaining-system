#!/bin/bash
# BEAMOPS v3 Development Environment Setup
# Following Engineering Elixir Applications Chapter 5 patterns

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SECRETS_DIR="$PROJECT_ROOT/secrets"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    # Check Docker Compose
    if ! docker compose version &> /dev/null; then
        log_error "Docker Compose is not available. Please install Docker Compose."
        exit 1
    fi
    
    # Check if Docker daemon is running
    if ! docker info &> /dev/null; then
        log_error "Docker daemon is not running. Please start Docker."
        exit 1
    fi
    
    log_info "Prerequisites check passed ✓"
}

# Setup secrets
setup_secrets() {
    log_info "Setting up development secrets..."
    
    mkdir -p "$SECRETS_DIR"
    
    # PostgreSQL password
    if [[ ! -f "$SECRETS_DIR/.postgrespassword" ]]; then
        echo "postgres_dev_password_$(date +%s)" > "$SECRETS_DIR/.postgrespassword"
        log_info "Created PostgreSQL password"
    fi
    
    # Phoenix secret key base
    if [[ ! -f "$SECRETS_DIR/.secretkeybase" ]]; then
        # Generate a secure random key (64 bytes = 512 bits)
        openssl rand -base64 64 | tr -d '\n' > "$SECRETS_DIR/.secretkeybase"
        log_info "Created Phoenix secret key base"
    fi
    
    # Database URL
    if [[ ! -f "$SECRETS_DIR/.databaseurl" ]]; then
        local postgres_password
        postgres_password=$(cat "$SECRETS_DIR/.postgrespassword")
        echo "postgresql://postgres:${postgres_password}@db:5432/beamops_dev" > "$SECRETS_DIR/.databaseurl"
        log_info "Created database URL"
    fi
    
    # Grafana admin password
    if [[ ! -f "$SECRETS_DIR/.grafanapassword" ]]; then
        echo "admin_dev_password_$(date +%s)" > "$SECRETS_DIR/.grafanapassword"
        log_info "Created Grafana admin password"
    fi
    
    # Set appropriate permissions
    chmod 600 "$SECRETS_DIR"/.* 2>/dev/null || true
    log_info "Secrets setup completed ✓"
}

# Setup environment variables
setup_environment() {
    log_info "Setting up environment configuration..."
    
    # Create .env file if it doesn't exist
    if [[ ! -f "$PROJECT_ROOT/.env" ]]; then
        cat > "$PROJECT_ROOT/.env" << EOF
# BEAMOPS v3 Development Environment Variables

# Database Configuration
POSTGRES_PORT=5432

# Redis Configuration  
REDIS_PORT=6379

# Agent Coordination Configuration
MAX_AGENT_COUNT=10
COORDINATION_POLL_INTERVAL=10000

# Feature Flags
ENABLE_DISTRIBUTED_ERLANG=true
ENABLE_LIVE_DASHBOARD=true
ENABLE_TELEMETRY_UI=true

# Development Tools
DEV_TOOLS_ENABLED=true
EOF
        log_info "Created .env file"
    fi
    
    log_info "Environment setup completed ✓"
}

# Build Docker images
build_images() {
    log_info "Building Docker images..."
    
    cd "$PROJECT_ROOT"
    
    # Build the main application image
    docker compose build app
    
    log_info "Docker images built ✓"
}

# Start development environment
start_environment() {
    log_info "Starting BEAMOPS v3 development environment..."
    
    cd "$PROJECT_ROOT"
    
    # Start all services
    docker compose up -d
    
    # Wait for services to be healthy
    log_info "Waiting for services to be ready..."
    
    # Wait for database
    local max_attempts=30
    local attempt=0
    while [[ $attempt -lt $max_attempts ]]; do
        if docker compose exec -T db pg_isready -U postgres &> /dev/null; then
            break
        fi
        ((attempt++))
        sleep 2
    done
    
    if [[ $attempt -eq $max_attempts ]]; then
        log_error "Database failed to start"
        exit 1
    fi
    
    log_info "Development environment started ✓"
    
    # Show status
    show_status
}

# Show environment status
show_status() {
    log_info "BEAMOPS v3 Development Environment Status:"
    echo ""
    echo "📱 Phoenix Application:     http://localhost:4000"
    echo "📊 Grafana Dashboard:       http://localhost:3000"
    echo "📈 Prometheus:              http://localhost:9090"
    echo "🔍 Jaeger Tracing:          http://localhost:16686"
    echo "💾 Adminer (Database):      http://localhost:8080"
    echo "📋 PromEx Metrics:          http://localhost:9568/metrics"
    echo ""
    
    local grafana_password
    grafana_password=$(cat "$SECRETS_DIR/.grafanapassword")
    echo "🔑 Grafana Login: admin / $grafana_password"
    echo ""
    
    # Show running containers
    docker compose ps
}

# Stop environment
stop_environment() {
    log_info "Stopping BEAMOPS v3 development environment..."
    
    cd "$PROJECT_ROOT"
    docker compose down
    
    log_info "Environment stopped ✓"
}

# Clean environment
clean_environment() {
    log_info "Cleaning BEAMOPS v3 development environment..."
    
    cd "$PROJECT_ROOT"
    
    # Stop and remove containers, networks, images, and volumes
    docker compose down --volumes --rmi local
    
    # Remove dangling images
    docker image prune -f
    
    log_info "Environment cleaned ✓"
}

# Show help
show_help() {
    cat << EOF
BEAMOPS v3 Development Environment Manager

Usage: $0 [command]

Commands:
    setup     Setup development environment (secrets, env, build)
    start     Start development environment
    stop      Stop development environment  
    restart   Restart development environment
    status    Show environment status
    clean     Clean environment (removes volumes and images)
    help      Show this help message

Examples:
    $0 setup     # First time setup
    $0 start     # Start environment
    $0 status    # Check status
    $0 clean     # Clean everything
EOF
}

# Main function
main() {
    local command=${1:-help}
    
    case $command in
        setup)
            check_prerequisites
            setup_secrets
            setup_environment
            build_images
            log_info "Setup completed! Run '$0 start' to start the environment."
            ;;
        start)
            check_prerequisites
            start_environment
            ;;
        stop)
            stop_environment
            ;;
        restart)
            stop_environment
            start_environment
            ;;
        status)
            show_status
            ;;
        clean)
            clean_environment
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            log_error "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

# Run main function
main "$@"