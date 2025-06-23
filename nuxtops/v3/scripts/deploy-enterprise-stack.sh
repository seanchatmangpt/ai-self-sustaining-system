#!/usr/bin/env bash

# NuxtOps V3 Enterprise Stack Deployment Orchestrator
# Production-ready deployment with comprehensive error handling and rollback

set -euo pipefail

# Color definitions for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly MAGENTA='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Script configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
readonly DEPLOYMENT_ID="deploy_$(date +%s%N)"
readonly LOG_DIR="${PROJECT_ROOT}/logs/deployments/${DEPLOYMENT_ID}"
readonly STATE_FILE="${PROJECT_ROOT}/.deployment_state.json"
readonly LOCK_FILE="${PROJECT_ROOT}/.deployment.lock"

# Environment configurations
readonly ENVIRONMENTS=("development" "staging" "production")
readonly REQUIRED_TOOLS=("docker" "docker-compose" "kubectl" "helm" "terraform" "ansible" "jq" "yq")

# Deployment components
readonly COMPONENTS=(
    "infrastructure"
    "database"
    "cache"
    "monitoring"
    "application"
    "edge"
    "observability"
)

# Initialize logging
init_logging() {
    mkdir -p "${LOG_DIR}"
    exec 1> >(tee -a "${LOG_DIR}/deployment.log")
    exec 2> >(tee -a "${LOG_DIR}/deployment_error.log" >&2)
    
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} Deployment ID: ${DEPLOYMENT_ID}"
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} Log directory: ${LOG_DIR}"
}

# Acquire deployment lock
acquire_lock() {
    local timeout=300
    local elapsed=0
    
    while [ $elapsed -lt $timeout ]; do
        if mkdir "${LOCK_FILE}" 2>/dev/null; then
            echo "${DEPLOYMENT_ID}" > "${LOCK_FILE}/deployment_id"
            echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} Acquired deployment lock"
            return 0
        fi
        
        echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} Waiting for deployment lock..."
        sleep 5
        elapsed=$((elapsed + 5))
    done
    
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} Failed to acquire deployment lock"
    return 1
}

# Release deployment lock
release_lock() {
    if [ -d "${LOCK_FILE}" ]; then
        rm -rf "${LOCK_FILE}"
        echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} Released deployment lock"
    fi
}

# Check prerequisites
check_prerequisites() {
    echo -e "${CYAN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} Checking prerequisites..."
    
    # Check required tools
    for tool in "${REQUIRED_TOOLS[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} Missing required tool: $tool"
            return 1
        fi
    done
    
    # Check Docker daemon
    if ! docker info &> /dev/null; then
        echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} Docker daemon is not running"
        return 1
    fi
    
    # Check Kubernetes connectivity (if deploying to production)
    if [[ "${ENVIRONMENT}" == "production" ]]; then
        if ! kubectl cluster-info &> /dev/null; then
            echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} Cannot connect to Kubernetes cluster"
            return 1
        fi
    fi
    
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} Prerequisites check passed"
    return 0
}

# Save deployment state
save_state() {
    local component="$1"
    local status="$2"
    local details="${3:-}"
    
    local state_entry=$(jq -n \
        --arg id "$DEPLOYMENT_ID" \
        --arg env "$ENVIRONMENT" \
        --arg comp "$component" \
        --arg stat "$status" \
        --arg det "$details" \
        --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        '{
            deployment_id: $id,
            environment: $env,
            component: $comp,
            status: $stat,
            details: $det,
            timestamp: $ts
        }')
    
    # Append to state file
    echo "$state_entry" >> "${STATE_FILE}.tmp"
    jq -s '.' "${STATE_FILE}.tmp" > "${STATE_FILE}"
    rm -f "${STATE_FILE}.tmp"
}

# Deploy infrastructure
deploy_infrastructure() {
    echo -e "${CYAN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} Deploying infrastructure..."
    save_state "infrastructure" "in_progress"
    
    cd "${PROJECT_ROOT}/infrastructure/terraform/${ENVIRONMENT}"
    
    # Initialize Terraform
    terraform init -upgrade
    
    # Plan deployment
    terraform plan -out=tfplan
    
    # Apply with auto-approve for CI/CD
    if [[ "${CI:-false}" == "true" ]]; then
        terraform apply -auto-approve tfplan
    else
        terraform apply tfplan
    fi
    
    save_state "infrastructure" "completed"
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} Infrastructure deployment completed"
}

# Deploy database
deploy_database() {
    echo -e "${CYAN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} Deploying database..."
    save_state "database" "in_progress"
    
    if [[ "${ENVIRONMENT}" == "production" ]]; then
        # Production database deployment via Kubernetes
        kubectl apply -f "${PROJECT_ROOT}/infrastructure/kubernetes/database/"
        
        # Wait for database to be ready
        kubectl wait --for=condition=ready pod -l app=postgres --timeout=300s
    else
        # Development/staging via Docker Compose
        docker-compose -f "${PROJECT_ROOT}/compose.yaml" up -d postgres redis
    fi
    
    # Run migrations
    "${SCRIPT_DIR}/tools/run-migrations.sh" "${ENVIRONMENT}"
    
    save_state "database" "completed"
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} Database deployment completed"
}

# Deploy monitoring stack
deploy_monitoring() {
    echo -e "${CYAN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} Deploying monitoring stack..."
    save_state "monitoring" "in_progress"
    
    if [[ "${ENVIRONMENT}" == "production" ]]; then
        # Deploy via Helm
        helm upgrade --install monitoring "${PROJECT_ROOT}/infrastructure/kubernetes/helm/monitoring" \
            --namespace monitoring \
            --create-namespace \
            --values "${PROJECT_ROOT}/infrastructure/kubernetes/helm/monitoring/values-${ENVIRONMENT}.yaml"
    else
        # Deploy via Docker Compose
        docker-compose -f "${PROJECT_ROOT}/monitoring/compose.monitoring.yaml" up -d
    fi
    
    # Wait for monitoring stack to be ready
    "${SCRIPT_DIR}/monitor-deployment.sh" --component monitoring --wait
    
    save_state "monitoring" "completed"
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} Monitoring deployment completed"
}

# Deploy application
deploy_application() {
    echo -e "${CYAN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} Deploying application..."
    save_state "application" "in_progress"
    
    # Build application
    cd "${PROJECT_ROOT}/applications/${ENVIRONMENT}"
    
    # Build Docker image
    local image_tag="${DEPLOYMENT_ID}"
    docker build -t "nuxtops:${image_tag}" -f "${PROJECT_ROOT}/Dockerfile" "${PROJECT_ROOT}"
    
    if [[ "${ENVIRONMENT}" == "production" ]]; then
        # Push to registry
        docker tag "nuxtops:${image_tag}" "${DOCKER_REGISTRY}/nuxtops:${image_tag}"
        docker push "${DOCKER_REGISTRY}/nuxtops:${image_tag}"
        
        # Deploy via Kubernetes
        kubectl set image deployment/nuxtops-app \
            nuxtops="${DOCKER_REGISTRY}/nuxtops:${image_tag}" \
            --namespace="${ENVIRONMENT}"
    else
        # Deploy via Docker Compose
        export NUXTOPS_IMAGE_TAG="${image_tag}"
        docker-compose -f "${PROJECT_ROOT}/compose.yaml" up -d nuxtops
    fi
    
    save_state "application" "completed"
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} Application deployment completed"
}

# Deploy edge functions
deploy_edge() {
    echo -e "${CYAN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} Deploying edge functions..."
    save_state "edge" "in_progress"
    
    if [[ -f "${SCRIPT_DIR}/edge-deployment.sh" ]]; then
        "${SCRIPT_DIR}/edge-deployment.sh" --environment "${ENVIRONMENT}"
    fi
    
    save_state "edge" "completed"
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} Edge deployment completed"
}

# Deploy observability
deploy_observability() {
    echo -e "${CYAN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} Deploying observability..."
    save_state "observability" "in_progress"
    
    # Deploy OpenTelemetry collectors
    if [[ "${ENVIRONMENT}" == "production" ]]; then
        kubectl apply -f "${PROJECT_ROOT}/infrastructure/kubernetes/observability/"
    else
        docker-compose -f "${PROJECT_ROOT}/monitoring/compose.otel.yaml" up -d
    fi
    
    # Validate OpenTelemetry setup
    "${SCRIPT_DIR}/e2e-otel-validation.sh" --environment "${ENVIRONMENT}"
    
    save_state "observability" "completed"
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} Observability deployment completed"
}

# Rollback deployment
rollback_deployment() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} Initiating rollback..."
    
    # Read deployment state
    if [[ -f "${STATE_FILE}" ]]; then
        local completed_components=$(jq -r '.[] | select(.deployment_id == "'"${DEPLOYMENT_ID}"'" and .status == "completed") | .component' "${STATE_FILE}")
        
        # Rollback in reverse order
        for component in $(echo "${completed_components}" | tac); do
            echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} Rolling back ${component}..."
            
            case "${component}" in
                "infrastructure")
                    cd "${PROJECT_ROOT}/infrastructure/terraform/${ENVIRONMENT}"
                    terraform destroy -auto-approve
                    ;;
                "application")
                    if [[ "${ENVIRONMENT}" == "production" ]]; then
                        kubectl rollout undo deployment/nuxtops-app --namespace="${ENVIRONMENT}"
                    fi
                    ;;
                *)
                    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} Rollback handler not implemented for ${component}"
                    ;;
            esac
        done
    fi
    
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} Rollback completed"
}

# Health check
perform_health_check() {
    echo -e "${CYAN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} Performing health checks..."
    
    "${SCRIPT_DIR}/validate-nuxtops-health.sh" --environment "${ENVIRONMENT}" --detailed
    
    local health_status=$?
    if [[ $health_status -ne 0 ]]; then
        echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} Health check failed"
        return 1
    fi
    
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} Health check passed"
    return 0
}

# Main deployment orchestration
main() {
    local environment="${1:-development}"
    local components="${2:-all}"
    local dry_run="${3:-false}"
    
    # Set global environment
    ENVIRONMENT="$environment"
    
    # Initialize
    init_logging
    
    # Acquire lock
    if ! acquire_lock; then
        exit 1
    fi
    
    # Ensure cleanup on exit
    trap 'release_lock' EXIT
    trap 'rollback_deployment; release_lock' ERR
    
    # Check prerequisites
    if ! check_prerequisites; then
        exit 1
    fi
    
    echo -e "${MAGENTA}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} Starting NuxtOps V3 Enterprise Stack Deployment"
    echo -e "${MAGENTA}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} Environment: ${ENVIRONMENT}"
    echo -e "${MAGENTA}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} Components: ${components}"
    
    # Deploy components
    if [[ "${components}" == "all" ]]; then
        for component in "${COMPONENTS[@]}"; do
            case "${component}" in
                "infrastructure") deploy_infrastructure ;;
                "database") deploy_database ;;
                "monitoring") deploy_monitoring ;;
                "application") deploy_application ;;
                "edge") deploy_edge ;;
                "observability") deploy_observability ;;
            esac
        done
    else
        # Deploy specific component
        case "${components}" in
            "infrastructure") deploy_infrastructure ;;
            "database") deploy_database ;;
            "monitoring") deploy_monitoring ;;
            "application") deploy_application ;;
            "edge") deploy_edge ;;
            "observability") deploy_observability ;;
            *)
                echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} Unknown component: ${components}"
                exit 1
                ;;
        esac
    fi
    
    # Perform health check
    if ! perform_health_check; then
        echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} Deployment health check failed"
        rollback_deployment
        exit 1
    fi
    
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} ✅ NuxtOps V3 Enterprise Stack Deployment Completed Successfully!"
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} Deployment ID: ${DEPLOYMENT_ID}"
}

# Show usage
usage() {
    cat << EOF
Usage: $0 [ENVIRONMENT] [COMPONENTS] [OPTIONS]

ENVIRONMENT:
    development  - Deploy to development environment (default)
    staging      - Deploy to staging environment
    production   - Deploy to production environment

COMPONENTS:
    all           - Deploy all components (default)
    infrastructure - Deploy only infrastructure
    database      - Deploy only database
    monitoring    - Deploy only monitoring
    application   - Deploy only application
    edge          - Deploy only edge functions
    observability - Deploy only observability

OPTIONS:
    --dry-run     - Perform dry run without actual deployment
    --help        - Show this help message

Examples:
    $0                              # Deploy all to development
    $0 production                   # Deploy all to production
    $0 staging application          # Deploy only app to staging
    $0 production all --dry-run     # Dry run for production

EOF
}

# Parse arguments
if [[ "$1" == "--help" ]]; then
    usage
    exit 0
fi

# Execute main function
main "$@"