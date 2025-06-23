#!/bin/bash
# NuxtOps V3 Production Deployment Script
# Deploy to production with zero-downtime

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
DEPLOY_ENV="${DEPLOY_ENV:-production}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
REGISTRY="${REGISTRY:-docker.io}"
IMAGE_NAME="${IMAGE_NAME:-nuxtops-app}"

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
    exit 1
}

# Pre-deployment checks
pre_deploy_checks() {
    log_info "Running pre-deployment checks..."
    
    # Check if production secrets exist
    if [ ! -f "./deployment/production/.env" ]; then
        log_error "Production environment file not found at ./deployment/production/.env"
    fi
    
    # Verify image exists
    if ! docker image inspect "${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}" >/dev/null 2>&1; then
        log_warning "Image not found locally, will attempt to pull from registry"
    fi
    
    # Check disk space
    local available_space=$(df -BG . | awk 'NR==2 {print $4}' | sed 's/G//')
    if [ "$available_space" -lt 5 ]; then
        log_error "Insufficient disk space. At least 5GB required, ${available_space}GB available"
    fi
    
    log_success "Pre-deployment checks passed"
}

# Build production image
build_production_image() {
    log_info "Building production image..."
    
    # Load production environment
    source ./deployment/production/.env
    
    # Build with production optimizations
    docker build \
        --target runner \
        --build-arg NUXT_PUBLIC_API_BASE="${NUXT_PUBLIC_API_BASE}" \
        --build-arg NUXT_PUBLIC_SITE_URL="${NUXT_PUBLIC_SITE_URL}" \
        --build-arg NITRO_PRESET=node-server \
        -t "${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}" \
        -t "${REGISTRY}/${IMAGE_NAME}:$(date +%Y%m%d-%H%M%S)" \
        -f Dockerfile \
        ./applications/nuxt-app
    
    log_success "Production image built successfully"
}

# Run tests
run_tests() {
    log_info "Running production tests..."
    
    # Start test container
    docker run --rm \
        --name nuxtops-test \
        -e NODE_ENV=test \
        "${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}" \
        npm test
    
    log_success "All tests passed"
}

# Deploy with zero downtime
deploy_zero_downtime() {
    log_info "Starting zero-downtime deployment..."
    
    # Create overlay network if it doesn't exist
    docker network create --driver overlay nuxtops-prod 2>/dev/null || true
    
    # Deploy new version as blue
    log_info "Deploying blue environment..."
    docker service create \
        --name nuxtops-blue \
        --network nuxtops-prod \
        --replicas 3 \
        --update-parallelism 1 \
        --update-delay 10s \
        --health-cmd "curl -f http://localhost:3000/api/health || exit 1" \
        --health-interval 30s \
        --health-retries 3 \
        --health-start-period 30s \
        --env-file ./deployment/production/.env \
        --secret source=nuxtops_db_password,target=/run/secrets/db_password \
        --secret source=nuxtops_session_secret,target=/run/secrets/session_secret \
        "${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"
    
    # Wait for blue to be healthy
    log_info "Waiting for blue environment to be healthy..."
    local retries=30
    while [ $retries -gt 0 ]; do
        if docker service ls --format "table {{.Name}}\t{{.Replicas}}" | grep nuxtops-blue | grep -q "3/3"; then
            log_success "Blue environment is healthy"
            break
        fi
        retries=$((retries - 1))
        sleep 10
    done
    
    if [ $retries -eq 0 ]; then
        log_error "Blue environment failed to become healthy"
    fi
    
    # Switch traffic to blue
    log_info "Switching traffic to blue environment..."
    docker service update \
        --label-add "traefik.enable=true" \
        --label-add "traefik.http.routers.nuxtops.rule=Host(\`${NUXT_PUBLIC_SITE_URL#https://}\`)" \
        --label-add "traefik.http.services.nuxtops.loadbalancer.server.port=3000" \
        nuxtops-blue
    
    # Remove green (old version)
    if docker service ls | grep -q nuxtops-green; then
        log_info "Removing old green environment..."
        docker service rm nuxtops-green
    fi
    
    # Rename blue to green for next deployment
    docker service update --label-add "com.nuxtops.color=green" nuxtops-blue
    
    log_success "Zero-downtime deployment completed"
}

# Post-deployment checks
post_deploy_checks() {
    log_info "Running post-deployment checks..."
    
    # Check service health
    local health_check_url="${NUXT_PUBLIC_SITE_URL}/api/health"
    if curl -f -s "$health_check_url" > /dev/null; then
        log_success "Health check passed"
    else
        log_error "Health check failed at $health_check_url"
    fi
    
    # Check metrics endpoint
    local metrics_url="${NUXT_PUBLIC_SITE_URL}/api/metrics"
    if curl -f -s "$metrics_url" > /dev/null; then
        log_success "Metrics endpoint responding"
    else
        log_warning "Metrics endpoint not responding at $metrics_url"
    fi
    
    # Verify in monitoring
    log_info "Check Grafana dashboards for application metrics"
    log_info "Check Jaeger for distributed traces"
    
    log_success "Post-deployment checks completed"
}

# Rollback function
rollback() {
    log_warning "Initiating rollback..."
    
    # Switch traffic back to green
    docker service update \
        --label-add "traefik.enable=true" \
        nuxtops-green
    
    # Remove failed blue deployment
    docker service rm nuxtops-blue
    
    log_success "Rollback completed"
}

# Main deployment flow
main() {
    log_info "Starting NuxtOps V3 production deployment"
    log_info "Environment: $DEPLOY_ENV"
    log_info "Image: ${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"
    
    # Set error trap for rollback
    trap 'rollback' ERR
    
    # Execute deployment steps
    pre_deploy_checks
    build_production_image
    run_tests
    deploy_zero_downtime
    post_deploy_checks
    
    # Remove error trap after successful deployment
    trap - ERR
    
    log_success "Production deployment completed successfully!"
    log_info ""
    log_info "Deployment summary:"
    log_info "- Image: ${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"
    log_info "- Environment: $DEPLOY_ENV"
    log_info "- URL: ${NUXT_PUBLIC_SITE_URL}"
    log_info "- Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
}

# Run main function
main "$@"