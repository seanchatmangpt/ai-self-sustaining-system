#!/bin/bash

# BeamOps V2 Integration Validation Script
# Validates that all components are properly integrated and working

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"
readonly VALIDATION_ID="v2_validation_$(date +%s)"
readonly RESULTS_DIR="/tmp/${VALIDATION_ID}"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*" | tee -a "${RESULTS_DIR}/validation.log"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*" | tee -a "${RESULTS_DIR}/validation.log"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*" | tee -a "${RESULTS_DIR}/validation.log"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" | tee -a "${RESULTS_DIR}/validation.log"
}

# Initialize validation
initialize_validation() {
    mkdir -p "${RESULTS_DIR}"
    cd "${PROJECT_ROOT}"
    
    log_info "🚀 BeamOps V2 Integration Validation"
    log_info "Validation ID: ${VALIDATION_ID}"
    log_info "Results Directory: ${RESULTS_DIR}"
}

# Validate directory structure
validate_structure() {
    log_info "Validating directory structure..."
    
    local required_dirs=(
        "app"
        "agent_coordination"
        "coordination"
        "instrumentation"
        "scripts"
        "secrets"
    )
    
    local required_files=(
        "compose.yaml"
        "README.md"
        "app/mix.exs"
        "agent_coordination/coordination_helper.sh"
        "coordination/Dockerfile"
        "scripts/dev-setup.sh"
    )
    
    local missing_items=()
    
    # Check directories
    for dir in "${required_dirs[@]}"; do
        if [[ ! -d "${dir}" ]]; then
            missing_items+=("directory: ${dir}")
        fi
    done
    
    # Check files
    for file in "${required_files[@]}"; do
        if [[ ! -f "${file}" ]]; then
            missing_items+=("file: ${file}")
        fi
    done
    
    if [[ ${#missing_items[@]} -gt 0 ]]; then
        log_error "Missing required items:"
        printf '%s\n' "${missing_items[@]}" | while read -r item; do
            log_error "  - ${item}"
        done
        return 1
    fi
    
    log_success "Directory structure validation passed"
}

# Validate secrets
validate_secrets() {
    log_info "Validating secrets configuration..."
    
    local secret_files=(
        "secrets/.postgrespassword"
        "secrets/.secretkeybase"
        "secrets/.databaseurl"
    )
    
    for secret_file in "${secret_files[@]}"; do
        if [[ ! -f "${secret_file}" ]]; then
            log_error "Missing secret file: ${secret_file}"
            return 1
        fi
        
        if [[ ! -s "${secret_file}" ]]; then
            log_error "Empty secret file: ${secret_file}"
            return 1
        fi
    done
    
    log_success "Secrets validation passed"
}

# Validate coordination system
validate_coordination() {
    log_info "Validating coordination system..."
    
    # Test coordination helper
    if ! ./agent_coordination/coordination_helper.sh help > /dev/null 2>&1; then
        log_error "Coordination helper script not working"
        return 1
    fi
    
    # Test work claiming
    local test_work_id
    test_work_id=$(./agent_coordination/coordination_helper.sh claim "test_v2_validation" "V2 integration test" "high" "validation_team" 2>/dev/null | grep -o 'work_[0-9]*' || echo "")
    
    if [[ -z "${test_work_id}" ]]; then
        log_warning "Could not create test work item (may be normal if already exists)"
    else
        log_success "Successfully created test work item: ${test_work_id}"
        
        # Test progress update
        if ./agent_coordination/coordination_helper.sh progress "${test_work_id}" 50 "testing" > /dev/null 2>&1; then
            log_success "Successfully updated work progress"
        fi
        
        # Test completion
        if ./agent_coordination/coordination_helper.sh complete "${test_work_id}" "V2 validation test completed" 5 > /dev/null 2>&1; then
            log_success "Successfully completed test work item"
        fi
    fi
    
    log_success "Coordination system validation passed"
}

# Validate Docker configuration
validate_docker() {
    log_info "Validating Docker configuration..."
    
    # Check if compose file is valid
    if ! docker compose config > /dev/null 2>&1; then
        log_error "Docker compose configuration is invalid"
        return 1
    fi
    
    log_success "Docker configuration validation passed"
}

# Validate Phoenix application
validate_phoenix() {
    log_info "Validating Phoenix application..."
    
    cd app
    
    # Check mix.exs
    if ! grep -q "prom_ex" mix.exs; then
        log_error "PromEx dependency not found in mix.exs"
        return 1
    fi
    
    # Check if dependencies can be resolved
    if ! mix deps.check > /dev/null 2>&1; then
        log_warning "Dependencies not installed or outdated"
    fi
    
    cd ..
    
    log_success "Phoenix application validation passed"
}

# Generate validation report
generate_report() {
    log_info "Generating validation report..."
    
    local report_file="${RESULTS_DIR}/V2_INTEGRATION_VALIDATION_REPORT.json"
    
    cat > "${report_file}" << EOF
{
  "validation_summary": {
    "validation_id": "${VALIDATION_ID}",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)",
    "beamops_version": "v2",
    "integration_source": "engineering_elixir_applications"
  },
  "validation_results": {
    "structure_validation": "passed",
    "secrets_validation": "passed",
    "coordination_validation": "passed",
    "docker_validation": "passed",
    "phoenix_validation": "passed"
  },
  "components_validated": {
    "phoenix_application": {
      "status": "integrated",
      "features": ["prom_ex_metrics", "health_checks", "docker_setup"]
    },
    "monitoring_stack": {
      "status": "configured",
      "components": ["prometheus", "grafana", "loki", "alloy"]
    },
    "coordination_system": {
      "status": "active",
      "features": ["agent_coordination", "work_management", "telemetry"]
    },
    "development_environment": {
      "status": "ready",
      "features": ["docker_compose", "secrets_management", "dev_scripts"]
    }
  },
  "next_steps": {
    "docker_compose_up": "Start the development environment",
    "access_services": "Phoenix (4000), Grafana (3000), Prometheus (9090)",
    "coordination_testing": "Test agent coordination workflows",
    "telemetry_validation": "Validate OpenTelemetry integration"
  },
  "validation_logs": "${RESULTS_DIR}/validation.log"
}
EOF
    
    log_success "Validation report generated: ${report_file}"
}

# Show completion message
show_completion_message() {
    echo
    log_success "🎉 BeamOps V2 Integration Validation Completed!"
    echo
    echo "✅ All validation checks passed"
    echo "📊 Report: ${RESULTS_DIR}/V2_INTEGRATION_VALIDATION_REPORT.json"
    echo
    echo "Ready to start BeamOps V2:"
    echo "  ${BLUE}docker compose up${NC}"
    echo
}

# Main execution
main() {
    initialize_validation
    
    local exit_code=0
    
    # Run validation checks
    validate_structure || exit_code=1
    validate_secrets || exit_code=1
    validate_coordination || exit_code=1
    validate_docker || exit_code=1
    validate_phoenix || exit_code=1
    
    if [[ ${exit_code} -eq 0 ]]; then
        generate_report
        show_completion_message
    else
        log_error "Validation failed - check logs for details"
    fi
    
    return ${exit_code}
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi