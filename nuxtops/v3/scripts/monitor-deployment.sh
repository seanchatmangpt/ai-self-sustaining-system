#!/usr/bin/env bash

# NuxtOps V3 Real-time Deployment Monitoring
# Provides comprehensive monitoring of deployment progress and health

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
readonly STATE_FILE="${PROJECT_ROOT}/.deployment_state.json"
readonly MONITORING_INTERVAL=5
readonly METRICS_ENDPOINT="${METRICS_ENDPOINT:-http://localhost:9090}"
readonly GRAFANA_ENDPOINT="${GRAFANA_ENDPOINT:-http://localhost:3000}"
readonly JAEGER_ENDPOINT="${JAEGER_ENDPOINT:-http://localhost:16686}"

# Monitoring modes
readonly MODES=("realtime" "summary" "health" "metrics" "traces")

# Component health endpoints
declare -A HEALTH_ENDPOINTS=(
    ["application"]="/health"
    ["database"]="/db/health"
    ["cache"]="/redis/health"
    ["monitoring"]="/metrics"
    ["edge"]="/edge/health"
)

# Initialize terminal
init_terminal() {
    # Clear screen and hide cursor for real-time mode
    if [[ "${MODE}" == "realtime" ]]; then
        clear
        tput civis  # Hide cursor
        trap 'tput cnorm; exit' EXIT INT TERM
    fi
}

# Get deployment status
get_deployment_status() {
    local deployment_id="${1:-}"
    
    if [[ -z "$deployment_id" && -f "${STATE_FILE}" ]]; then
        # Get latest deployment
        deployment_id=$(jq -r 'sort_by(.timestamp) | reverse | .[0].deployment_id' "${STATE_FILE}" 2>/dev/null || echo "")
    fi
    
    if [[ -n "$deployment_id" ]]; then
        jq -r --arg id "$deployment_id" '.[] | select(.deployment_id == $id)' "${STATE_FILE}" 2>/dev/null || echo "{}"
    else
        echo "{}"
    fi
}

# Monitor component health
monitor_component_health() {
    local component="$1"
    local environment="${2:-development}"
    
    local endpoint="${HEALTH_ENDPOINTS[$component]:-/health}"
    local base_url=""
    
    # Determine base URL based on environment
    case "$environment" in
        "production")
            base_url="https://nuxtops.production.example.com"
            ;;
        "staging")
            base_url="https://nuxtops.staging.example.com"
            ;;
        *)
            base_url="http://localhost:3000"
            ;;
    esac
    
    # Check health
    local status_code=$(curl -s -o /dev/null -w "%{http_code}" "${base_url}${endpoint}" 2>/dev/null || echo "000")
    
    if [[ "$status_code" == "200" ]]; then
        echo "healthy"
    elif [[ "$status_code" == "000" ]]; then
        echo "unreachable"
    else
        echo "unhealthy ($status_code)"
    fi
}

# Get container metrics
get_container_metrics() {
    local container_name="$1"
    
    # Get Docker stats
    local stats=$(docker stats --no-stream --format "json" "$container_name" 2>/dev/null || echo "{}")
    
    if [[ "$stats" != "{}" ]]; then
        echo "$stats" | jq -r '{
            cpu: .CPUPerc,
            memory: .MemUsage,
            network: .NetIO,
            block_io: .BlockIO
        }'
    else
        echo '{"error": "Container not found"}'
    fi
}

# Get Prometheus metrics
get_prometheus_metrics() {
    local query="$1"
    local endpoint="${METRICS_ENDPOINT}/api/v1/query"
    
    curl -s -G "${endpoint}" --data-urlencode "query=${query}" | \
        jq -r '.data.result[] | {metric: .metric, value: .value[1]}' 2>/dev/null || echo "{}"
}

# Get OpenTelemetry traces
get_otel_traces() {
    local service="${1:-nuxtops}"
    local limit="${2:-10}"
    
    # Query Jaeger for recent traces
    curl -s "${JAEGER_ENDPOINT}/api/traces?service=${service}&limit=${limit}" | \
        jq -r '.data[] | {
            traceID: .traceID,
            operationName: .spans[0].operationName,
            duration: .spans[0].duration,
            startTime: .spans[0].startTime
        }' 2>/dev/null || echo "{}"
}

# Display real-time monitoring dashboard
display_realtime_dashboard() {
    local deployment_id="$1"
    
    while true; do
        clear
        
        # Header
        echo -e "${MAGENTA}╔════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${MAGENTA}║         NuxtOps V3 Deployment Monitor - Real-time View         ║${NC}"
        echo -e "${MAGENTA}╚════════════════════════════════════════════════════════════════╝${NC}"
        echo
        echo -e "${CYAN}Deployment ID:${NC} ${deployment_id}"
        echo -e "${CYAN}Timestamp:${NC} $(date +'%Y-%m-%d %H:%M:%S')"
        echo
        
        # Deployment Progress
        echo -e "${BLUE}━━━ Deployment Progress ━━━${NC}"
        if [[ -f "${STATE_FILE}" ]]; then
            jq -r --arg id "$deployment_id" '
                .[] | select(.deployment_id == $id) |
                "\(.component): \(.status) - \(.timestamp)"
            ' "${STATE_FILE}" 2>/dev/null | while read -r line; do
                if [[ "$line" =~ "completed" ]]; then
                    echo -e "${GREEN}✓ $line${NC}"
                elif [[ "$line" =~ "in_progress" ]]; then
                    echo -e "${YELLOW}⟳ $line${NC}"
                elif [[ "$line" =~ "failed" ]]; then
                    echo -e "${RED}✗ $line${NC}"
                else
                    echo -e "  $line"
                fi
            done
        fi
        echo
        
        # Component Health
        echo -e "${BLUE}━━━ Component Health ━━━${NC}"
        for component in "${!HEALTH_ENDPOINTS[@]}"; do
            local health=$(monitor_component_health "$component")
            if [[ "$health" == "healthy" ]]; then
                echo -e "${GREEN}✓ ${component}: ${health}${NC}"
            elif [[ "$health" == "unreachable" ]]; then
                echo -e "${YELLOW}? ${component}: ${health}${NC}"
            else
                echo -e "${RED}✗ ${component}: ${health}${NC}"
            fi
        done
        echo
        
        # Container Metrics
        echo -e "${BLUE}━━━ Container Metrics ━━━${NC}"
        for container in "nuxtops_app" "postgres" "redis" "prometheus" "grafana"; do
            local metrics=$(get_container_metrics "$container")
            if [[ $(echo "$metrics" | jq -r '.error' 2>/dev/null) != "Container not found" ]]; then
                echo -e "${CYAN}$container:${NC}"
                echo "$metrics" | jq -r 'to_entries[] | "  \(.key): \(.value)"' 2>/dev/null || echo "  No metrics available"
            fi
        done
        echo
        
        # System Metrics
        echo -e "${BLUE}━━━ System Metrics ━━━${NC}"
        echo -e "CPU Load: $(uptime | awk -F'load average:' '{print $2}')"
        echo -e "Memory: $(free -h | awk '/^Mem:/ {print $3 " / " $2 " (" int($3/$2 * 100) "%)"}')"
        echo -e "Disk: $(df -h / | awk 'NR==2 {print $3 " / " $2 " (" $5 ")"}')"
        echo
        
        # Recent Traces
        echo -e "${BLUE}━━━ Recent Traces (Last 5) ━━━${NC}"
        get_otel_traces "nuxtops" 5 | jq -r '
            "[\(.traceID[0:8])] \(.operationName) - \(.duration)μs"
        ' 2>/dev/null | head -5 || echo "No traces available"
        
        # Refresh indicator
        echo
        echo -e "${CYAN}Refreshing in ${MONITORING_INTERVAL}s... (Press Ctrl+C to exit)${NC}"
        
        sleep "${MONITORING_INTERVAL}"
    done
}

# Display deployment summary
display_deployment_summary() {
    local deployment_id="$1"
    
    echo -e "${MAGENTA}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║            NuxtOps V3 Deployment Summary                       ║${NC}"
    echo -e "${MAGENTA}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo
    
    if [[ -f "${STATE_FILE}" ]]; then
        # Get deployment details
        local deployment_data=$(jq -r --arg id "$deployment_id" '.[] | select(.deployment_id == $id)' "${STATE_FILE}")
        
        # Summary statistics
        local total_components=$(echo "$deployment_data" | jq -s 'length')
        local completed=$(echo "$deployment_data" | jq -s '[.[] | select(.status == "completed")] | length')
        local in_progress=$(echo "$deployment_data" | jq -s '[.[] | select(.status == "in_progress")] | length')
        local failed=$(echo "$deployment_data" | jq -s '[.[] | select(.status == "failed")] | length')
        
        echo -e "${CYAN}Deployment ID:${NC} $deployment_id"
        echo -e "${CYAN}Total Components:${NC} $total_components"
        echo -e "${GREEN}Completed:${NC} $completed"
        echo -e "${YELLOW}In Progress:${NC} $in_progress"
        echo -e "${RED}Failed:${NC} $failed"
        echo
        
        # Component details
        echo -e "${BLUE}Component Status:${NC}"
        echo "$deployment_data" | jq -r '
            "\(.component): \(.status) (\(.timestamp))"
        ' | while read -r line; do
            if [[ "$line" =~ "completed" ]]; then
                echo -e "  ${GREEN}✓ $line${NC}"
            elif [[ "$line" =~ "in_progress" ]]; then
                echo -e "  ${YELLOW}⟳ $line${NC}"
            elif [[ "$line" =~ "failed" ]]; then
                echo -e "  ${RED}✗ $line${NC}"
            fi
        done
        
        # Duration calculation
        local start_time=$(echo "$deployment_data" | jq -s 'sort_by(.timestamp) | .[0].timestamp' | tr -d '"')
        local end_time=$(echo "$deployment_data" | jq -s 'sort_by(.timestamp) | .[-1].timestamp' | tr -d '"')
        
        if [[ -n "$start_time" && -n "$end_time" ]]; then
            local duration=$(($(date -d "$end_time" +%s) - $(date -d "$start_time" +%s)))
            echo
            echo -e "${CYAN}Total Duration:${NC} ${duration}s"
        fi
    else
        echo -e "${RED}No deployment data found${NC}"
    fi
}

# Monitor health with detailed checks
monitor_health() {
    echo -e "${MAGENTA}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║            NuxtOps V3 Health Monitor                           ║${NC}"
    echo -e "${MAGENTA}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo
    
    # Application health
    echo -e "${BLUE}━━━ Application Health ━━━${NC}"
    local app_health=$(curl -s "http://localhost:3000/api/health" 2>/dev/null || echo '{"status": "unreachable"}')
    echo "$app_health" | jq . 2>/dev/null || echo "Application unreachable"
    echo
    
    # Database health
    echo -e "${BLUE}━━━ Database Health ━━━${NC}"
    docker exec postgres pg_isready &>/dev/null && echo -e "${GREEN}✓ PostgreSQL is ready${NC}" || echo -e "${RED}✗ PostgreSQL is not ready${NC}"
    echo
    
    # Redis health
    echo -e "${BLUE}━━━ Cache Health ━━━${NC}"
    docker exec redis redis-cli ping &>/dev/null && echo -e "${GREEN}✓ Redis is ready${NC}" || echo -e "${RED}✗ Redis is not ready${NC}"
    echo
    
    # Monitoring stack health
    echo -e "${BLUE}━━━ Monitoring Stack Health ━━━${NC}"
    curl -s "${METRICS_ENDPOINT}/-/healthy" &>/dev/null && echo -e "${GREEN}✓ Prometheus is healthy${NC}" || echo -e "${RED}✗ Prometheus is unhealthy${NC}"
    curl -s "${GRAFANA_ENDPOINT}/api/health" &>/dev/null && echo -e "${GREEN}✓ Grafana is healthy${NC}" || echo -e "${RED}✗ Grafana is unhealthy${NC}"
    curl -s "${JAEGER_ENDPOINT}/" &>/dev/null && echo -e "${GREEN}✓ Jaeger is healthy${NC}" || echo -e "${RED}✗ Jaeger is unhealthy${NC}"
    echo
    
    # OpenTelemetry collector health
    echo -e "${BLUE}━━━ OpenTelemetry Health ━━━${NC}"
    local otel_health=$(curl -s "http://localhost:13133/" 2>/dev/null)
    if [[ -n "$otel_health" ]]; then
        echo -e "${GREEN}✓ OpenTelemetry Collector is healthy${NC}"
        echo "  Uptime: $(echo "$otel_health" | grep -oP 'Uptime: \K[^<]*' || echo 'N/A')"
    else
        echo -e "${RED}✗ OpenTelemetry Collector is unreachable${NC}"
    fi
}

# Monitor metrics
monitor_metrics() {
    echo -e "${MAGENTA}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║            NuxtOps V3 Metrics Monitor                          ║${NC}"
    echo -e "${MAGENTA}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo
    
    # Application metrics
    echo -e "${BLUE}━━━ Application Metrics ━━━${NC}"
    get_prometheus_metrics 'rate(http_requests_total[5m])' | jq -r '
        "HTTP Request Rate: \(.value) req/s"
    ' 2>/dev/null || echo "No HTTP metrics available"
    
    get_prometheus_metrics 'histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))' | jq -r '
        "95th Percentile Latency: \(.value)s"
    ' 2>/dev/null || echo "No latency metrics available"
    echo
    
    # Resource metrics
    echo -e "${BLUE}━━━ Resource Metrics ━━━${NC}"
    get_prometheus_metrics 'node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes * 100' | jq -r '
        "Memory Available: \(.value)%"
    ' 2>/dev/null || echo "No memory metrics available"
    
    get_prometheus_metrics '100 - (avg(irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)' | jq -r '
        "CPU Usage: \(.value)%"
    ' 2>/dev/null || echo "No CPU metrics available"
    echo
    
    # Database metrics
    echo -e "${BLUE}━━━ Database Metrics ━━━${NC}"
    get_prometheus_metrics 'pg_stat_database_numbackends{datname="nuxtops"}' | jq -r '
        "Active Connections: \(.value)"
    ' 2>/dev/null || echo "No database metrics available"
}

# Monitor traces
monitor_traces() {
    echo -e "${MAGENTA}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║            NuxtOps V3 Trace Monitor                            ║${NC}"
    echo -e "${MAGENTA}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo
    
    # Recent traces
    echo -e "${BLUE}━━━ Recent Traces ━━━${NC}"
    get_otel_traces "nuxtops" 20 | jq -r '
        "[\(.traceID[0:8])] \(.operationName)"
    ' 2>/dev/null || echo "No traces available"
    echo
    
    # Trace statistics
    echo -e "${BLUE}━━━ Trace Statistics ━━━${NC}"
    local trace_stats=$(curl -s "${JAEGER_ENDPOINT}/api/services/nuxtops/operations" 2>/dev/null)
    if [[ -n "$trace_stats" ]]; then
        echo "$trace_stats" | jq -r '.data[]' 2>/dev/null | head -10
    else
        echo "No trace statistics available"
    fi
}

# Wait for component
wait_for_component() {
    local component="$1"
    local timeout="${2:-300}"
    local elapsed=0
    
    echo -e "${CYAN}Waiting for ${component} to be ready...${NC}"
    
    while [ $elapsed -lt $timeout ]; do
        local health=$(monitor_component_health "$component")
        
        if [[ "$health" == "healthy" ]]; then
            echo -e "${GREEN}✓ ${component} is ready${NC}"
            return 0
        fi
        
        echo -ne "\r${YELLOW}⟳ Waiting... ${elapsed}s / ${timeout}s${NC}"
        sleep 5
        elapsed=$((elapsed + 5))
    done
    
    echo -e "\n${RED}✗ Timeout waiting for ${component}${NC}"
    return 1
}

# Main function
main() {
    local mode="${1:-realtime}"
    local deployment_id="${2:-}"
    local component="${3:-}"
    local wait="${4:-}"
    
    MODE="$mode"
    
    # Handle wait mode
    if [[ "$component" == "--wait" || "$wait" == "--wait" ]]; then
        wait_for_component "${2:-application}" "${3:-300}"
        exit $?
    fi
    
    # Initialize terminal for real-time mode
    init_terminal
    
    case "$mode" in
        "realtime")
            display_realtime_dashboard "$deployment_id"
            ;;
        "summary")
            display_deployment_summary "$deployment_id"
            ;;
        "health")
            monitor_health
            ;;
        "metrics")
            monitor_metrics
            ;;
        "traces")
            monitor_traces
            ;;
        *)
            echo -e "${RED}Unknown mode: $mode${NC}"
            usage
            exit 1
            ;;
    esac
}

# Show usage
usage() {
    cat << EOF
Usage: $0 [MODE] [OPTIONS]

MODES:
    realtime     - Real-time monitoring dashboard (default)
    summary      - Show deployment summary
    health       - Show component health status
    metrics      - Show system metrics
    traces       - Show OpenTelemetry traces

OPTIONS:
    For realtime/summary mode:
        [DEPLOYMENT_ID] - Specific deployment to monitor
    
    For wait mode:
        --component [COMPONENT] --wait [TIMEOUT]

Examples:
    $0                                    # Real-time monitoring
    $0 summary deploy_123456              # Summary for specific deployment
    $0 health                             # Health check all components
    $0 --component application --wait     # Wait for app to be ready
    $0 --component monitoring --wait 600  # Wait up to 10 minutes

EOF
}

# Parse arguments
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    usage
    exit 0
fi

# Handle component wait syntax
if [[ "$1" == "--component" ]]; then
    shift
    main "wait" "$@"
else
    main "$@"
fi