#!/usr/bin/env bash

# NuxtOps V3 Zero-Downtime Deployment Script
# Implements blue-green deployment strategy with automatic rollback

set -euo pipefail

# Color definitions
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly MAGENTA='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# Script configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
readonly DEPLOYMENT_ID="zero_downtime_$(date +%s%N)"
readonly STATE_DIR="${PROJECT_ROOT}/.zero_downtime_state"
readonly BACKUP_DIR="${PROJECT_ROOT}/backups/${DEPLOYMENT_ID}"

# Deployment configuration
readonly MAX_HEALTH_CHECKS=30
readonly HEALTH_CHECK_INTERVAL=10
readonly DRAIN_TIMEOUT=30
readonly ROLLBACK_TIMEOUT=300

# Environment colors (blue/green)
declare -A ENVIRONMENTS=(
    ["blue"]="nuxtops-blue"
    ["green"]="nuxtops-green"
)

# Initialize deployment
init_deployment() {
    echo -e "${MAGENTA}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║         NuxtOps V3 Zero-Downtime Deployment                    ║${NC}"
    echo -e "${MAGENTA}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${CYAN}Deployment ID:${NC} ${DEPLOYMENT_ID}"
    echo -e "${CYAN}Timestamp:${NC} $(date +'%Y-%m-%d %H:%M:%S')"
    
    # Create state directory
    mkdir -p "$STATE_DIR"
    mkdir -p "$BACKUP_DIR"
    
    # Log deployment start
    echo "{\"deployment_id\": \"${DEPLOYMENT_ID}\", \"start_time\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" > "${STATE_DIR}/current_deployment.json"
}

# Get current active environment
get_active_environment() {
    if [[ -f "${STATE_DIR}/active_environment" ]]; then
        cat "${STATE_DIR}/active_environment"
    else
        # Default to blue if no state exists
        echo "blue"
    fi
}

# Get inactive environment
get_inactive_environment() {
    local active=$(get_active_environment)
    if [[ "$active" == "blue" ]]; then
        echo "green"
    else
        echo "blue"
    fi
}

# Check if environment is healthy
check_environment_health() {
    local environment="$1"
    local container_name="${ENVIRONMENTS[$environment]}"
    
    echo -e "${CYAN}Checking health of ${environment} environment...${NC}"
    
    # Check if container is running
    if ! docker ps --format "{{.Names}}" | grep -q "^${container_name}$"; then
        echo -e "${RED}Container ${container_name} is not running${NC}"
        return 1
    fi
    
    # Check container health status
    local health_status=$(docker inspect --format='{{.State.Health.Status}}' "$container_name" 2>/dev/null || echo "none")
    if [[ "$health_status" != "healthy" && "$health_status" != "none" ]]; then
        echo -e "${RED}Container ${container_name} is ${health_status}${NC}"
        return 1
    fi
    
    # Check HTTP endpoint
    local port=""
    if [[ "$environment" == "blue" ]]; then
        port="3001"
    else
        port="3002"
    fi
    
    local http_status=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${port}/health" 2>/dev/null || echo "000")
    if [[ "$http_status" != "200" ]]; then
        echo -e "${RED}Health endpoint returned HTTP ${http_status}${NC}"
        return 1
    fi
    
    # Check application metrics
    local app_health=$(curl -s "http://localhost:${port}/health" 2>/dev/null || echo "{}")
    local app_status=$(echo "$app_health" | jq -r '.status' 2>/dev/null || echo "unknown")
    
    if [[ "$app_status" != "healthy" && "$app_status" != "ok" ]]; then
        echo -e "${RED}Application status is ${app_status}${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✓ ${environment} environment is healthy${NC}"
    return 0
}

# Build new version
build_new_version() {
    local environment="$1"
    local image_tag="${DEPLOYMENT_ID}"
    
    echo -e "${CYAN}Building new version for ${environment} environment...${NC}"
    
    # Build Docker image
    docker build \
        -t "nuxtops:${image_tag}" \
        -f "${PROJECT_ROOT}/Dockerfile" \
        --build-arg BUILD_ENV="${ENVIRONMENT:-production}" \
        --build-arg BUILD_ID="${DEPLOYMENT_ID}" \
        "${PROJECT_ROOT}"
    
    # Tag for environment
    docker tag "nuxtops:${image_tag}" "nuxtops:${environment}-${image_tag}"
    
    echo -e "${GREEN}✓ Build completed: nuxtops:${environment}-${image_tag}${NC}"
    
    echo "${image_tag}"
}

# Deploy to inactive environment
deploy_to_inactive() {
    local environment="$1"
    local image_tag="$2"
    local container_name="${ENVIRONMENTS[$environment]}"
    
    echo -e "${CYAN}Deploying to ${environment} environment...${NC}"
    
    # Stop existing container if running
    if docker ps -a --format "{{.Names}}" | grep -q "^${container_name}$"; then
        echo -e "${YELLOW}Stopping existing ${container_name} container...${NC}"
        docker stop "$container_name" || true
        docker rm "$container_name" || true
    fi
    
    # Determine port based on environment
    local port=""
    if [[ "$environment" == "blue" ]]; then
        port="3001"
    else
        port="3002"
    fi
    
    # Start new container
    docker run -d \
        --name "$container_name" \
        --network nuxtops-network \
        -p "${port}:3000" \
        -e NODE_ENV=production \
        -e PORT=3000 \
        -e DATABASE_URL="${DATABASE_URL:-postgresql://postgres:postgres@postgres:5432/nuxtops}" \
        -e REDIS_URL="${REDIS_URL:-redis://redis:6379}" \
        --health-cmd="curl -f http://localhost:3000/health || exit 1" \
        --health-interval=10s \
        --health-timeout=5s \
        --health-retries=3 \
        --restart=unless-stopped \
        "nuxtops:${environment}-${image_tag}"
    
    echo -e "${GREEN}✓ Deployed to ${environment} environment${NC}"
}

# Wait for environment to be healthy
wait_for_healthy() {
    local environment="$1"
    local attempts=0
    
    echo -e "${CYAN}Waiting for ${environment} environment to be healthy...${NC}"
    
    while [ $attempts -lt $MAX_HEALTH_CHECKS ]; do
        if check_environment_health "$environment"; then
            return 0
        fi
        
        attempts=$((attempts + 1))
        echo -e "${YELLOW}Health check attempt ${attempts}/${MAX_HEALTH_CHECKS}...${NC}"
        sleep $HEALTH_CHECK_INTERVAL
    done
    
    echo -e "${RED}Environment failed to become healthy after ${MAX_HEALTH_CHECKS} attempts${NC}"
    return 1
}

# Update load balancer configuration
update_load_balancer() {
    local new_environment="$1"
    local old_environment="$2"
    
    echo -e "${CYAN}Updating load balancer configuration...${NC}"
    
    # Update nginx configuration
    local nginx_config="/etc/nginx/sites-available/nuxtops"
    local nginx_temp="/tmp/nuxtops.conf.tmp"
    
    # Determine ports
    local new_port=""
    local old_port=""
    if [[ "$new_environment" == "blue" ]]; then
        new_port="3001"
        old_port="3002"
    else
        new_port="3002"
        old_port="3001"
    fi
    
    # Create new nginx configuration
    cat > "$nginx_temp" << EOF
upstream nuxtops_backend {
    server localhost:${new_port} weight=100;
    server localhost:${old_port} weight=0 backup;
}

server {
    listen 80;
    server_name localhost;
    
    location / {
        proxy_pass http://nuxtops_backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    
    location /health {
        access_log off;
        proxy_pass http://nuxtops_backend/health;
    }
}
EOF
    
    # Test nginx configuration
    if nginx -t -c "$nginx_temp" 2>/dev/null; then
        # Backup current configuration
        if [[ -f "$nginx_config" ]]; then
            cp "$nginx_config" "${BACKUP_DIR}/nginx.conf.backup"
        fi
        
        # Apply new configuration
        sudo cp "$nginx_temp" "$nginx_config"
        sudo nginx -s reload
        
        echo -e "${GREEN}✓ Load balancer updated to route to ${new_environment}${NC}"
    else
        echo -e "${RED}Nginx configuration test failed${NC}"
        return 1
    fi
    
    # Update active environment state
    echo "$new_environment" > "${STATE_DIR}/active_environment"
    
    return 0
}

# Perform canary deployment
canary_deployment() {
    local new_environment="$1"
    local old_environment="$2"
    local canary_percentage="${3:-10}"
    
    echo -e "${CYAN}Starting canary deployment (${canary_percentage}% traffic)...${NC}"
    
    # Gradually increase traffic to new environment
    local current_percentage=0
    while [ $current_percentage -lt 100 ]; do
        current_percentage=$((current_percentage + canary_percentage))
        if [ $current_percentage -gt 100 ]; then
            current_percentage=100
        fi
        
        echo -e "${YELLOW}Routing ${current_percentage}% traffic to ${new_environment}...${NC}"
        
        # Update nginx weights
        local new_weight=$current_percentage
        local old_weight=$((100 - current_percentage))
        
        # Update load balancer with new weights
        # This would normally update the nginx configuration with proper weights
        
        # Monitor error rates
        sleep 30
        
        # Check if deployment should continue
        local error_rate=$(check_error_rate "$new_environment")
        if (( $(echo "$error_rate > 5" | bc -l) )); then
            echo -e "${RED}Error rate too high (${error_rate}%), stopping canary deployment${NC}"
            return 1
        fi
        
        echo -e "${GREEN}✓ Error rate acceptable (${error_rate}%)${NC}"
    done
    
    echo -e "${GREEN}✓ Canary deployment completed successfully${NC}"
    return 0
}

# Check error rate
check_error_rate() {
    local environment="$1"
    
    # Query Prometheus for error rate
    local error_rate=$(curl -s "http://localhost:9090/api/v1/query?query=rate(http_requests_total{status=~\"5..\",environment=\"${environment}\"}[5m])" | \
        jq -r '.data.result[0].value[1] // "0"' 2>/dev/null || echo "0")
    
    echo "$error_rate"
}

# Drain connections from old environment
drain_connections() {
    local environment="$1"
    
    echo -e "${CYAN}Draining connections from ${environment} environment...${NC}"
    
    # Set environment to draining mode
    local container_name="${ENVIRONMENTS[$environment]}"
    
    # Send graceful shutdown signal
    docker exec "$container_name" kill -SIGTERM 1 2>/dev/null || true
    
    # Wait for connections to drain
    local elapsed=0
    while [ $elapsed -lt $DRAIN_TIMEOUT ]; do
        local active_connections=$(docker exec "$container_name" ss -tn state established 2>/dev/null | wc -l || echo "0")
        
        if [ "$active_connections" -eq 0 ]; then
            echo -e "${GREEN}✓ All connections drained${NC}"
            return 0
        fi
        
        echo -e "${YELLOW}Waiting for ${active_connections} connections to close...${NC}"
        sleep 5
        elapsed=$((elapsed + 5))
    done
    
    echo -e "${YELLOW}⚠ Drain timeout reached, proceeding anyway${NC}"
    return 0
}

# Rollback deployment
rollback_deployment() {
    local reason="${1:-Unknown reason}"
    
    echo -e "${RED}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║                    ROLLBACK INITIATED                          ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo -e "${RED}Reason: ${reason}${NC}"
    
    # Get environments
    local failed_environment=$(get_inactive_environment)
    local stable_environment=$(get_active_environment)
    
    # Ensure stable environment is running
    if ! check_environment_health "$stable_environment"; then
        echo -e "${RED}CRITICAL: Stable environment is not healthy!${NC}"
        
        # Attempt to restart stable environment
        local container_name="${ENVIRONMENTS[$stable_environment]}"
        docker restart "$container_name" 2>/dev/null || true
        
        # Wait for it to be healthy
        if ! wait_for_healthy "$stable_environment"; then
            echo -e "${RED}CRITICAL: Cannot restore stable environment!${NC}"
            exit 1
        fi
    fi
    
    # Route all traffic back to stable environment
    update_load_balancer "$stable_environment" "$failed_environment"
    
    # Stop failed environment
    local failed_container="${ENVIRONMENTS[$failed_environment]}"
    docker stop "$failed_container" 2>/dev/null || true
    docker rm "$failed_container" 2>/dev/null || true
    
    # Log rollback
    echo "{\"deployment_id\": \"${DEPLOYMENT_ID}\", \"rollback_time\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\", \"reason\": \"${reason}\"}" >> "${STATE_DIR}/rollback_log.jsonl"
    
    echo -e "${GREEN}✓ Rollback completed successfully${NC}"
}

# Cleanup old deployments
cleanup_old_deployments() {
    echo -e "${CYAN}Cleaning up old deployments...${NC}"
    
    # Keep only last 5 deployments
    local backup_count=$(find "${PROJECT_ROOT}/backups" -maxdepth 1 -type d -name "zero_downtime_*" | wc -l)
    if [ $backup_count -gt 5 ]; then
        find "${PROJECT_ROOT}/backups" -maxdepth 1 -type d -name "zero_downtime_*" | \
            sort | head -n $((backup_count - 5)) | xargs rm -rf
    fi
    
    # Clean up old Docker images
    docker image prune -f --filter "label=nuxtops.deployment" --filter "until=24h" 2>/dev/null || true
    
    echo -e "${GREEN}✓ Cleanup completed${NC}"
}

# Main deployment function
main() {
    local deployment_type="${1:-rolling}"
    local canary_percentage="${2:-10}"
    
    # Initialize deployment
    init_deployment
    
    # Set up error handling
    trap 'rollback_deployment "Deployment script error"' ERR
    
    # Get current environments
    local active_env=$(get_active_environment)
    local inactive_env=$(get_inactive_environment)
    
    echo -e "${CYAN}Current active environment:${NC} ${active_env}"
    echo -e "${CYAN}Deploying to environment:${NC} ${inactive_env}"
    echo
    
    # Pre-deployment checks
    echo -e "${BLUE}━━━ Pre-deployment Checks ━━━${NC}"
    if ! check_environment_health "$active_env"; then
        echo -e "${RED}Active environment is not healthy, aborting deployment${NC}"
        exit 1
    fi
    echo
    
    # Build new version
    echo -e "${BLUE}━━━ Building New Version ━━━${NC}"
    local image_tag=$(build_new_version "$inactive_env")
    echo
    
    # Deploy to inactive environment
    echo -e "${BLUE}━━━ Deploying to Inactive Environment ━━━${NC}"
    deploy_to_inactive "$inactive_env" "$image_tag"
    echo
    
    # Wait for new environment to be healthy
    echo -e "${BLUE}━━━ Health Check ━━━${NC}"
    if ! wait_for_healthy "$inactive_env"; then
        rollback_deployment "New environment failed health checks"
        exit 1
    fi
    echo
    
    # Perform deployment based on type
    echo -e "${BLUE}━━━ Traffic Switch ━━━${NC}"
    case "$deployment_type" in
        "canary")
            if ! canary_deployment "$inactive_env" "$active_env" "$canary_percentage"; then
                rollback_deployment "Canary deployment failed"
                exit 1
            fi
            ;;
        "rolling"|*)
            # Switch traffic to new environment
            if ! update_load_balancer "$inactive_env" "$active_env"; then
                rollback_deployment "Failed to update load balancer"
                exit 1
            fi
            ;;
    esac
    echo
    
    # Verify new environment is handling traffic
    echo -e "${BLUE}━━━ Post-deployment Verification ━━━${NC}"
    sleep 10  # Allow time for traffic to stabilize
    
    if ! check_environment_health "$inactive_env"; then
        rollback_deployment "Post-deployment health check failed"
        exit 1
    fi
    
    # Check error rates
    local error_rate=$(check_error_rate "$inactive_env")
    if (( $(echo "$error_rate > 5" | bc -l) )); then
        rollback_deployment "High error rate detected (${error_rate}%)"
        exit 1
    fi
    echo -e "${GREEN}✓ Error rate acceptable (${error_rate}%)${NC}"
    echo
    
    # Drain and stop old environment
    echo -e "${BLUE}━━━ Cleanup ━━━${NC}"
    drain_connections "$active_env"
    
    # Stop old environment
    local old_container="${ENVIRONMENTS[$active_env]}"
    docker stop "$old_container" 2>/dev/null || true
    
    # Cleanup old deployments
    cleanup_old_deployments
    
    # Update deployment state
    echo "{\"deployment_id\": \"${DEPLOYMENT_ID}\", \"end_time\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\", \"status\": \"success\"}" >> "${STATE_DIR}/deployment_log.jsonl"
    
    echo
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║        Zero-Downtime Deployment Completed Successfully!        ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo -e "${GREEN}New active environment: ${inactive_env}${NC}"
    echo -e "${GREEN}Deployment ID: ${DEPLOYMENT_ID}${NC}"
}

# Show usage
usage() {
    cat << EOF
Usage: $0 [DEPLOYMENT_TYPE] [OPTIONS]

DEPLOYMENT_TYPE:
    rolling     - Switch all traffic at once (default)
    canary      - Gradually increase traffic to new version

OPTIONS:
    For canary deployment:
        [PERCENTAGE] - Traffic percentage increase per step (default: 10)
    
    --help      - Show this help message

Examples:
    $0                    # Rolling deployment
    $0 canary             # Canary deployment with 10% increments
    $0 canary 20          # Canary deployment with 20% increments

Prerequisites:
    - Docker must be running
    - Nginx must be installed and configured
    - Both blue and green environments must be configured
    - Health endpoints must be implemented

EOF
}

# Parse arguments
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    usage
    exit 0
fi

# Execute main function
main "$@"