#!/bin/bash
# COMPREHENSIVE DEVOPS INFRASTRUCTURE DEPLOYMENT SCRIPT
# Deploys production-ready AI Self-Sustaining System with full observability

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DEPLOYMENT_MODE="${1:-development}"
FORCE_REBUILD="${2:-false}"

echo -e "${BOLD}${PURPLE}🚀 COMPREHENSIVE DEVOPS INFRASTRUCTURE DEPLOYMENT${NC}"
echo -e "${PURPLE}$(printf '=%.0s' {1..55})${NC}"
echo -e "${CYAN}Project: AI Self-Sustaining System${NC}"
echo -e "${CYAN}Mode: $DEPLOYMENT_MODE${NC}"
echo -e "${CYAN}Force Rebuild: $FORCE_REBUILD${NC}"
echo -e "${CYAN}Project Root: $PROJECT_ROOT${NC}\n"

cd "$PROJECT_ROOT"

# Check prerequisites
check_prerequisites() {
    echo -e "${BOLD}${BLUE}🔍 Checking Prerequisites${NC}"
    echo "============================"
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}❌ Docker is not installed${NC}"
        exit 1
    fi
    
    # Check Docker Compose
    if ! docker compose version &> /dev/null; then
        echo -e "${RED}❌ Docker Compose V2 is not available${NC}"
        exit 1
    fi
    
    # Check available disk space (at least 5GB)
    available_space=$(df / | awk 'NR==2 {print $4}')
    if [[ $available_space -lt 5242880 ]]; then
        echo -e "${YELLOW}⚠️ Low disk space. Available: $(($available_space/1024/1024))GB${NC}"
    fi
    
    echo -e "${GREEN}✅ All prerequisites met${NC}\n"
}

# Setup environment
setup_environment() {
    echo -e "${BOLD}${BLUE}🔧 Setting Up Environment${NC}"
    echo "=========================="
    
    # Create .env file if it doesn't exist
    if [[ ! -f .env ]]; then
        echo -e "${CYAN}📝 Creating environment configuration...${NC}"
        cat > .env << EOF
# Database Configuration
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres_secure_password_123
POSTGRES_DB=ai_self_sustaining

# N8N Configuration
N8N_ENCRYPTION_KEY=$(openssl rand -hex 32)
N8N_JWT_SECRET=$(openssl rand -hex 32)

# Phoenix Configuration
SECRET_KEY_BASE=$(openssl rand -hex 64)

# Grafana Configuration
GRAFANA_PASSWORD=admin123

# Domain Configuration
DOMAIN=localhost

# Claude AI Configuration (optional)
# CLAUDE_API_KEY=your_claude_api_key_here
EOF
        echo -e "${GREEN}✅ Environment file created${NC}"
    else
        echo -e "${GREEN}✅ Environment file exists${NC}"
    fi
    
    # Create necessary directories
    echo -e "${CYAN}📁 Creating necessary directories...${NC}"
    mkdir -p redis-data
    mkdir -p shared
    mkdir -p n8n_workflows
    
    # Setup BeamOps monitoring rules if they don't exist
    if [[ ! -d "beamops/v3/monitoring/prometheus/rules" ]]; then
        mkdir -p beamops/v3/monitoring/prometheus/rules
        cat > beamops/v3/monitoring/prometheus/rules/ai_system.yml << 'EOF'
groups:
  - name: ai_system_alerts
    rules:
      - alert: HighMemoryUsage
        expr: (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) < 0.1
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "High memory usage detected"
          
      - alert: PhoenixAppDown
        expr: up{job="beamops-v3"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Phoenix application is down"
          
      - alert: DatabaseConnectionFailed
        expr: pg_up == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Database connection failed"
EOF
    fi
    
    echo -e "${GREEN}✅ Environment setup complete${NC}\n"
}

# Build containers
build_containers() {
    echo -e "${BOLD}${BLUE}🔨 Building Container Images${NC}"
    echo "============================="
    
    if [[ "$FORCE_REBUILD" == "true" ]]; then
        echo -e "${CYAN}🔄 Force rebuilding all images...${NC}"
        docker compose -f docker-compose.devops.yml build --no-cache
    else
        echo -e "${CYAN}🔄 Building images...${NC}"
        docker compose -f docker-compose.devops.yml build
    fi
    
    echo -e "${GREEN}✅ Container images built${NC}\n"
}

# Deploy infrastructure
deploy_infrastructure() {
    echo -e "${BOLD}${BLUE}🚀 Deploying Infrastructure${NC}"
    echo "============================"
    
    # Stop any existing containers
    echo -e "${CYAN}🛑 Stopping existing containers...${NC}"
    docker compose -f docker-compose.devops.yml down --remove-orphans || true
    
    # Deploy based on mode
    case "$DEPLOYMENT_MODE" in
        "production")
            echo -e "${CYAN}🏭 Deploying production infrastructure...${NC}"
            docker compose -f docker-compose.devops.yml --profile production up -d
            ;;
        "monitoring-only")
            echo -e "${CYAN}📊 Deploying monitoring stack only...${NC}"
            docker compose -f docker-compose.devops.yml --profile monitoring-only up -d
            ;;
        "development"|*)
            echo -e "${CYAN}🛠️ Deploying development infrastructure...${NC}"
            docker compose -f docker-compose.devops.yml --profile development up -d
            ;;
    esac
    
    echo -e "${GREEN}✅ Infrastructure deployed${NC}\n"
}

# Wait for services
wait_for_services() {
    echo -e "${BOLD}${BLUE}⏳ Waiting for Services to be Ready${NC}"
    echo "====================================="
    
    local services=(
        "postgres:5432"
        "redis:6379"
        "prometheus:9090"
        "grafana:3000"
        "jaeger:16686"
        "loki:3100"
        "n8n:5678"
        "qdrant:6333"
        "ollama:11434"
    )
    
    for service in "${services[@]}"; do
        local host="${service%:*}"
        local port="${service#*:}"
        
        echo -e "${CYAN}⏳ Waiting for $host:$port...${NC}"
        
        local max_attempts=60
        local attempt=1
        
        while ! docker compose -f docker-compose.devops.yml exec -T "$host" sh -c "timeout 1 bash -c '</dev/tcp/localhost/$port'" 2>/dev/null; do
            if [[ $attempt -ge $max_attempts ]]; then
                echo -e "${RED}❌ Timeout waiting for $host:$port${NC}"
                break
            fi
            
            echo -e "${YELLOW}  Attempt $attempt/$max_attempts...${NC}"
            sleep 2
            attempt=$((attempt + 1))
        done
        
        echo -e "${GREEN}✅ $host:$port is ready${NC}"
    done
    
    echo -e "${GREEN}✅ All services are ready${NC}\n"
}

# Verify deployment
verify_deployment() {
    echo -e "${BOLD}${BLUE}🔍 Verifying Deployment${NC}"
    echo "========================"
    
    local endpoints=(
        "http://localhost:3000:Grafana Dashboard"
        "http://localhost:9090:Prometheus Metrics"
        "http://localhost:16686:Jaeger Tracing"
        "http://localhost:5678:N8N Workflows"
        "http://localhost:6333:Qdrant Vector DB"
        "http://localhost:11434/api/version:Ollama LLM"
    )
    
    echo -e "${CYAN}🌐 Testing endpoints...${NC}"
    
    for endpoint in "${endpoints[@]}"; do
        local url="${endpoint%:*}"
        local name="${endpoint#*:}"
        
        if curl -f -s "$url" >/dev/null 2>&1; then
            echo -e "${GREEN}✅ $name: $url${NC}"
        else
            echo -e "${RED}❌ $name: $url${NC}"
        fi
    done
    
    # Check container health
    echo -e "\n${CYAN}🏥 Checking container health...${NC}"
    docker compose -f docker-compose.devops.yml ps --format "table {{.Name}}\t{{.Status}}\t{{.Health}}"
    
    echo -e "\n${GREEN}✅ Deployment verification complete${NC}\n"
}

# Show access information
show_access_info() {
    echo -e "${BOLD}${GREEN}🎉 DEPLOYMENT SUCCESSFUL${NC}"
    echo -e "${GREEN}$(printf '=%.0s' {1..35})${NC}"
    echo ""
    echo -e "${BOLD}${CYAN}📊 Monitoring & Observability:${NC}"
    echo -e "  🎛️  Grafana Dashboard:  ${YELLOW}http://localhost:3000${NC} (admin/admin123)"
    echo -e "  📈 Prometheus Metrics:  ${YELLOW}http://localhost:9090${NC}"
    echo -e "  🔍 Jaeger Tracing:      ${YELLOW}http://localhost:16686${NC}"
    echo -e "  📝 Loki Logs:           ${YELLOW}http://localhost:3100${NC}"
    echo ""
    echo -e "${BOLD}${CYAN}🤖 AI System Services:${NC}"
    echo -e "  🌐 Phoenix App:         ${YELLOW}http://localhost:4000${NC}"
    echo -e "  🔗 N8N Workflows:       ${YELLOW}http://localhost:5678${NC}"
    echo -e "  🧠 Ollama LLM:          ${YELLOW}http://localhost:11434${NC}"
    echo -e "  🗄️  Qdrant Vector DB:    ${YELLOW}http://localhost:6333${NC}"
    echo ""
    echo -e "${BOLD}${CYAN}⚡ Management:${NC}"
    echo -e "  🔄 Caddy Load Balancer: ${YELLOW}http://localhost:2019${NC}"
    echo -e "  💾 PostgreSQL:          ${YELLOW}localhost:5434${NC}"
    echo -e "  🗃️  Redis Cache:         ${YELLOW}localhost:6379${NC}"
    echo ""
    echo -e "${BOLD}${CYAN}🛠️ Management Commands:${NC}"
    echo -e "  Stop:     ${YELLOW}docker compose -f docker-compose.devops.yml down${NC}"
    echo -e "  Restart:  ${YELLOW}docker compose -f docker-compose.devops.yml restart${NC}"
    echo -e "  Logs:     ${YELLOW}docker compose -f docker-compose.devops.yml logs -f${NC}"
    echo -e "  Status:   ${YELLOW}docker compose -f docker-compose.devops.yml ps${NC}"
    echo ""
}

# Cleanup function
cleanup_on_error() {
    echo -e "\n${RED}❌ Deployment failed. Cleaning up...${NC}"
    docker compose -f docker-compose.devops.yml down --remove-orphans || true
    exit 1
}

# Main execution
main() {
    # Set up error handling
    trap cleanup_on_error ERR
    
    # Execute deployment steps
    check_prerequisites
    setup_environment
    build_containers
    deploy_infrastructure
    wait_for_services
    verify_deployment
    show_access_info
    
    echo -e "${BOLD}${GREEN}🚀 DevOps infrastructure deployment completed successfully!${NC}"
    echo -e "${CYAN}The autonomous system now has comprehensive observability with Grafana at localhost:3000${NC}"
}

# Show usage if help requested
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    echo "Usage: $0 [DEPLOYMENT_MODE] [FORCE_REBUILD]"
    echo ""
    echo "DEPLOYMENT_MODE:"
    echo "  development    - Full development stack (default)"
    echo "  production     - Production-optimized deployment"
    echo "  monitoring-only - Only monitoring stack"
    echo ""
    echo "FORCE_REBUILD:"
    echo "  true          - Force rebuild all containers"
    echo "  false         - Use cached builds (default)"
    echo ""
    echo "Examples:"
    echo "  $0                           # Development mode"
    echo "  $0 production               # Production mode"
    echo "  $0 development true         # Force rebuild"
    echo "  $0 monitoring-only          # Monitoring only"
    exit 0
fi

# Execute main function
main "$@"