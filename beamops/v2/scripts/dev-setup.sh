#!/bin/bash

# BeamOps V2 Development Setup Script
# Sets up complete development environment with monitoring and coordination

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    local missing_tools=()
    
    # Check for Docker
    if ! command -v docker &> /dev/null; then
        missing_tools+=("docker")
    fi
    
    # Check for Docker Compose
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        missing_tools+=("docker-compose")
    fi
    
    # Check for jq
    if ! command -v jq &> /dev/null; then
        missing_tools+=("jq")
    fi
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_error "Please install the missing tools and try again."
        return 1
    fi
    
    log_success "All prerequisites satisfied"
}

# Setup secrets
setup_secrets() {
    log_info "Setting up secrets..."
    
    local secrets_dir="${PROJECT_ROOT}/secrets"
    
    # Create secrets directory if it doesn't exist
    mkdir -p "${secrets_dir}"
    
    # Generate secrets if they don't exist
    if [[ ! -f "${secrets_dir}/.postgrespassword" ]]; then
        openssl rand -base64 32 > "${secrets_dir}/.postgrespassword"
        log_success "Generated PostgreSQL password"
    fi
    
    if [[ ! -f "${secrets_dir}/.secretkeybase" ]]; then
        openssl rand -base64 64 > "${secrets_dir}/.secretkeybase"
        log_success "Generated Phoenix secret key base"
    fi
    
    if [[ ! -f "${secrets_dir}/.databaseurl" ]]; then
        local postgres_password=$(cat "${secrets_dir}/.postgrespassword")
        echo "postgresql://postgres:${postgres_password}@db:5432/beamops_v2_dev" > "${secrets_dir}/.databaseurl"
        log_success "Generated database URL"
    fi
    
    log_success "Secrets setup completed"
}

# Setup agent coordination
setup_coordination() {
    log_info "Setting up agent coordination..."
    
    local coord_dir="${PROJECT_ROOT}/agent_coordination"
    mkdir -p "${coord_dir}"
    
    # Make coordination helper executable
    if [[ -f "${coord_dir}/coordination_helper.sh" ]]; then
        chmod +x "${coord_dir}/coordination_helper.sh"
        log_success "Made coordination helper executable"
    fi
    
    # Initialize coordination files
    local files=(
        "work_claims.json"
        "agent_status.json"
        "coordination_log.json"
    )
    
    for file in "${files[@]}"; do
        if [[ ! -f "${coord_dir}/${file}" ]]; then
            echo "[]" > "${coord_dir}/${file}"
            log_success "Initialized ${file}"
        fi
    done
    
    # Initialize telemetry file
    if [[ ! -f "${coord_dir}/telemetry_spans.jsonl" ]]; then
        touch "${coord_dir}/telemetry_spans.jsonl"
        log_success "Initialized telemetry spans file"
    fi
    
    log_success "Agent coordination setup completed"
}

# Setup Phoenix application
setup_phoenix_app() {
    log_info "Setting up Phoenix application..."
    
    local app_dir="${PROJECT_ROOT}/app"
    
    if [[ ! -f "${app_dir}/mix.exs" ]]; then
        log_error "Phoenix application not found in ${app_dir}"
        return 1
    fi
    
    # Make scripts executable
    chmod +x "${PROJECT_ROOT}/coordination/scripts/"*.sh
    
    log_success "Phoenix application setup completed"
}

# Create monitoring directories
setup_monitoring() {
    log_info "Setting up monitoring infrastructure..."
    
    # Create necessary directories for monitoring
    local monitoring_dirs=(
        "${PROJECT_ROOT}/instrumentation"
        "${PROJECT_ROOT}/grafana/data"
        "${PROJECT_ROOT}/prometheus/data"
    )
    
    for dir in "${monitoring_dirs[@]}"; do
        mkdir -p "${dir}"
    done
    
    log_success "Monitoring infrastructure setup completed"
}

# Display completion message
show_completion_message() {
    echo
    log_success "🎉 BeamOps V2 development environment setup completed!"
    echo
    echo "Next steps:"
    echo "1. Start the development environment:"
    echo "   ${BLUE}docker compose up${NC}"
    echo
    echo "2. Access the services:"
    echo "   • Phoenix App:  ${BLUE}http://localhost:4000${NC}"
    echo "   • Grafana:      ${BLUE}http://localhost:3000${NC}"
    echo "   • Prometheus:   ${BLUE}http://localhost:9090${NC}"
    echo
    echo "3. Monitor coordination:"
    echo "   ${BLUE}./agent_coordination/coordination_helper.sh status${NC}"
    echo
    echo "4. View logs:"
    echo "   ${BLUE}docker compose logs -f${NC}"
    echo
}

# Main execution
main() {
    echo "🚀 BeamOps V2 Development Setup"
    echo "================================"
    echo
    
    cd "${PROJECT_ROOT}"
    
    # Run setup steps
    check_prerequisites
    setup_secrets
    setup_coordination
    setup_phoenix_app
    setup_monitoring
    
    # Show completion message
    show_completion_message
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi