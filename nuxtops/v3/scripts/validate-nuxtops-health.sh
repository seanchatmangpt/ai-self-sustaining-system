#!/usr/bin/env bash

# NuxtOps V3 Health Validation Script
# Comprehensive health checks for all components with detailed reporting

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
readonly HEALTH_REPORT="${PROJECT_ROOT}/health-report-$(date +%s).json"
readonly VALIDATION_LOG="${PROJECT_ROOT}/logs/health-validation.log"

# Health check configuration
readonly HEALTH_CHECKS=(
    "application"
    "database"
    "cache"
    "monitoring"
    "observability"
    "network"
    "storage"
    "security"
    "performance"
)

# Thresholds
readonly CPU_THRESHOLD=80
readonly MEMORY_THRESHOLD=85
readonly DISK_THRESHOLD=90
readonly RESPONSE_TIME_THRESHOLD=1000  # milliseconds
readonly ERROR_RATE_THRESHOLD=1       # percent

# Initialize logging
init_logging() {
    mkdir -p "$(dirname "$VALIDATION_LOG")"
    exec 1> >(tee -a "$VALIDATION_LOG")
    exec 2>&1
    
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} Starting NuxtOps V3 Health Validation"
}

# Check application health
check_application_health() {
    echo -e "${CYAN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} Checking application health..."
    
    local health_status="healthy"
    local details=()
    
    # Check main application endpoint
    local app_response=$(curl -s -w "\n%{http_code}\n%{time_total}" http://localhost:3000/health 2>/dev/null || echo -e "\n000\n0")
    local http_code=$(echo "$app_response" | tail -2 | head -1)
    local response_time=$(echo "$app_response" | tail -1)
    
    if [[ "$http_code" == "200" ]]; then
        details+=("Main endpoint: OK (${response_time}s)")
        
        # Parse health response
        local health_data=$(echo "$app_response" | head -n -2)
        if [[ -n "$health_data" ]]; then
            local app_status=$(echo "$health_data" | jq -r '.status' 2>/dev/null || echo "unknown")
            local app_version=$(echo "$health_data" | jq -r '.version' 2>/dev/null || echo "unknown")
            details+=("Status: $app_status")
            details+=("Version: $app_version")
        fi
    else
        health_status="unhealthy"
        details+=("Main endpoint: FAILED (HTTP $http_code)")
    fi
    
    # Check API endpoints
    local api_endpoints=("/api/v1/status" "/api/v1/health" "/api/v1/metrics")
    for endpoint in "${api_endpoints[@]}"; do
        local api_code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:3000${endpoint}" 2>/dev/null || echo "000")
        if [[ "$api_code" == "200" || "$api_code" == "204" ]]; then
            details+=("API ${endpoint}: OK")
        else
            details+=("API ${endpoint}: FAILED (HTTP $api_code)")
            health_status="degraded"
        fi
    done
    
    # Check WebSocket connectivity
    if command -v wscat &> /dev/null; then
        if timeout 5 wscat -c ws://localhost:3000/ws 2>&1 | grep -q "Connected"; then
            details+=("WebSocket: OK")
        else
            details+=("WebSocket: FAILED")
            health_status="degraded"
        fi
    fi
    
    # Generate report
    generate_health_report "application" "$health_status" "${details[@]}"
    
    [[ "$health_status" == "healthy" ]]
}

# Check database health
check_database_health() {
    echo -e "${CYAN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} Checking database health..."
    
    local health_status="healthy"
    local details=()
    
    # Check PostgreSQL
    if docker ps | grep -q postgres; then
        # Check if PostgreSQL is ready
        if docker exec postgres pg_isready -U postgres &>/dev/null; then
            details+=("PostgreSQL: Ready")
            
            # Check connection count
            local conn_count=$(docker exec postgres psql -U postgres -t -c "SELECT count(*) FROM pg_stat_activity;" 2>/dev/null | xargs)
            local max_conn=$(docker exec postgres psql -U postgres -t -c "SHOW max_connections;" 2>/dev/null | xargs)
            details+=("Connections: $conn_count/$max_conn")
            
            # Check database size
            local db_size=$(docker exec postgres psql -U postgres -t -c "SELECT pg_size_pretty(pg_database_size('nuxtops'));" 2>/dev/null | xargs || echo "N/A")
            details+=("Database size: $db_size")
            
            # Check replication status (if configured)
            local repl_status=$(docker exec postgres psql -U postgres -t -c "SELECT state FROM pg_stat_replication;" 2>/dev/null | xargs || echo "none")
            if [[ -n "$repl_status" && "$repl_status" != "none" ]]; then
                details+=("Replication: $repl_status")
            fi
        else
            health_status="unhealthy"
            details+=("PostgreSQL: Not ready")
        fi
    else
        health_status="unhealthy"
        details+=("PostgreSQL: Container not running")
    fi
    
    # Check Redis
    if docker ps | grep -q redis; then
        if docker exec redis redis-cli ping &>/dev/null; then
            details+=("Redis: Ready")
            
            # Check Redis memory
            local redis_info=$(docker exec redis redis-cli info memory 2>/dev/null || echo "")
            local used_memory=$(echo "$redis_info" | grep "used_memory_human:" | cut -d: -f2 | tr -d '\r' || echo "N/A")
            details+=("Redis memory: $used_memory")
        else
            health_status="unhealthy"
            details+=("Redis: Not ready")
        fi
    else
        health_status="unhealthy"
        details+=("Redis: Container not running")
    fi
    
    generate_health_report "database" "$health_status" "${details[@]}"
    
    [[ "$health_status" == "healthy" ]]
}

# Check monitoring health
check_monitoring_health() {
    echo -e "${CYAN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} Checking monitoring health..."
    
    local health_status="healthy"
    local details=()
    
    # Check Prometheus
    local prom_health=$(curl -s http://localhost:9090/-/healthy 2>/dev/null || echo "")
    if [[ "$prom_health" == "Prometheus is Healthy." ]]; then
        details+=("Prometheus: Healthy")
        
        # Check targets
        local targets=$(curl -s http://localhost:9090/api/v1/targets 2>/dev/null | jq -r '.data.activeTargets | length' 2>/dev/null || echo "0")
        details+=("Active targets: $targets")
    else
        health_status="degraded"
        details+=("Prometheus: Unhealthy or unreachable")
    fi
    
    # Check Grafana
    local grafana_health=$(curl -s http://localhost:3000/api/health 2>/dev/null | jq -r '.database' 2>/dev/null || echo "")
    if [[ "$grafana_health" == "ok" ]]; then
        details+=("Grafana: Healthy")
        
        # Check dashboards
        local dashboards=$(curl -s -u admin:admin http://localhost:3000/api/search?type=dash-db 2>/dev/null | jq 'length' 2>/dev/null || echo "0")
        details+=("Dashboards: $dashboards")
    else
        health_status="degraded"
        details+=("Grafana: Unhealthy or unreachable")
    fi
    
    # Check Jaeger
    if curl -s http://localhost:16686 &>/dev/null; then
        details+=("Jaeger: Accessible")
    else
        health_status="degraded"
        details+=("Jaeger: Unreachable")
    fi
    
    # Check Loki
    local loki_ready=$(curl -s http://localhost:3100/ready 2>/dev/null || echo "")
    if [[ "$loki_ready" == "ready" ]]; then
        details+=("Loki: Ready")
    else
        health_status="degraded"
        details+=("Loki: Not ready or unreachable")
    fi
    
    generate_health_report "monitoring" "$health_status" "${details[@]}"
    
    [[ "$health_status" == "healthy" ]]
}

# Check observability health
check_observability_health() {
    echo -e "${CYAN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} Checking observability health..."
    
    local health_status="healthy"
    local details=()
    
    # Check OpenTelemetry Collector
    local otel_health=$(curl -s http://localhost:13133/ 2>/dev/null || echo "")
    if [[ -n "$otel_health" ]]; then
        details+=("OpenTelemetry Collector: Running")
        
        # Check metrics pipeline
        local metrics_received=$(curl -s http://localhost:8888/metrics 2>/dev/null | grep -c "otelcol_receiver_accepted_metric_points" || echo "0")
        if [[ $metrics_received -gt 0 ]]; then
            details+=("Metrics pipeline: Active")
        else
            details+=("Metrics pipeline: No data")
        fi
        
        # Check traces pipeline
        local traces_received=$(curl -s http://localhost:8888/metrics 2>/dev/null | grep -c "otelcol_receiver_accepted_spans" || echo "0")
        if [[ $traces_received -gt 0 ]]; then
            details+=("Traces pipeline: Active")
        else
            details+=("Traces pipeline: No data")
        fi
    else
        health_status="unhealthy"
        details+=("OpenTelemetry Collector: Not running")
    fi
    
    # Check trace correlation
    if [[ -f "${PROJECT_ROOT}/telemetry_spans.jsonl" ]]; then
        local recent_traces=$(find "${PROJECT_ROOT}/telemetry_spans.jsonl" -mmin -5 | wc -l)
        if [[ $recent_traces -gt 0 ]]; then
            details+=("Recent traces: Yes")
        else
            details+=("Recent traces: No (stale data)")
        fi
    else
        details+=("Trace file: Not found")
    fi
    
    generate_health_report "observability" "$health_status" "${details[@]}"
    
    [[ "$health_status" == "healthy" ]]
}

# Check network health
check_network_health() {
    echo -e "${CYAN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} Checking network health..."
    
    local health_status="healthy"
    local details=()
    
    # Check port availability
    local required_ports=(3000 9090 3000 16686 9200 5432 6379)
    for port in "${required_ports[@]}"; do
        if lsof -i ":$port" &>/dev/null; then
            details+=("Port $port: In use")
        else
            details+=("Port $port: Available")
            health_status="degraded"
        fi
    done
    
    # Check DNS resolution
    if host example.com &>/dev/null; then
        details+=("DNS resolution: OK")
    else
        details+=("DNS resolution: FAILED")
        health_status="degraded"
    fi
    
    # Check network connectivity
    if ping -c 1 -W 2 8.8.8.8 &>/dev/null; then
        details+=("Internet connectivity: OK")
    else
        details+=("Internet connectivity: FAILED")
        health_status="degraded"
    fi
    
    generate_health_report "network" "$health_status" "${details[@]}"
    
    [[ "$health_status" == "healthy" ]]
}

# Check storage health
check_storage_health() {
    echo -e "${CYAN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} Checking storage health..."
    
    local health_status="healthy"
    local details=()
    
    # Check disk usage
    local disk_usage=$(df -h / | awk 'NR==2 {print $5}' | tr -d '%')
    details+=("Root disk usage: ${disk_usage}%")
    
    if [[ $disk_usage -gt $DISK_THRESHOLD ]]; then
        health_status="degraded"
        details+=("WARNING: Disk usage above ${DISK_THRESHOLD}%")
    fi
    
    # Check Docker disk usage
    local docker_usage=$(docker system df --format "table {{.Type}}\t{{.Size}}\t{{.Reclaimable}}" | tail -n +2)
    details+=("Docker disk usage:")
    while IFS= read -r line; do
        details+=("  $line")
    done <<< "$docker_usage"
    
    # Check log sizes
    local log_size=$(find "${PROJECT_ROOT}/logs" -type f -name "*.log" -exec du -ch {} + 2>/dev/null | grep total$ | awk '{print $1}' || echo "0")
    details+=("Log files size: $log_size")
    
    # Check backup directory (if exists)
    if [[ -d "${PROJECT_ROOT}/backups" ]]; then
        local backup_size=$(du -sh "${PROJECT_ROOT}/backups" 2>/dev/null | awk '{print $1}' || echo "0")
        details+=("Backup size: $backup_size")
    fi
    
    generate_health_report "storage" "$health_status" "${details[@]}"
    
    [[ "$health_status" == "healthy" ]]
}

# Check security health
check_security_health() {
    echo -e "${CYAN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} Checking security health..."
    
    local health_status="healthy"
    local details=()
    
    # Check SSL certificates
    if [[ -d "${PROJECT_ROOT}/deployment/secrets/certificates" ]]; then
        local cert_count=$(find "${PROJECT_ROOT}/deployment/secrets/certificates" -name "*.crt" | wc -l)
        details+=("SSL certificates found: $cert_count")
        
        # Check certificate expiry
        for cert in "${PROJECT_ROOT}/deployment/secrets/certificates"/*.crt; do
            if [[ -f "$cert" ]]; then
                local expiry=$(openssl x509 -enddate -noout -in "$cert" 2>/dev/null | cut -d= -f2)
                local cert_name=$(basename "$cert")
                details+=("Certificate $cert_name expires: $expiry")
            fi
        done
    else
        details+=("SSL certificates: Not configured")
    fi
    
    # Check secrets management
    if [[ -f "${PROJECT_ROOT}/.env" ]]; then
        local env_perms=$(stat -c "%a" "${PROJECT_ROOT}/.env" 2>/dev/null || stat -f "%Lp" "${PROJECT_ROOT}/.env" 2>/dev/null)
        if [[ "$env_perms" == "600" || "$env_perms" == "400" ]]; then
            details+=("Environment file permissions: Secure ($env_perms)")
        else
            health_status="degraded"
            details+=("Environment file permissions: Insecure ($env_perms)")
        fi
    fi
    
    # Check firewall status (if available)
    if command -v ufw &> /dev/null; then
        local fw_status=$(sudo ufw status | grep "Status:" | awk '{print $2}' 2>/dev/null || echo "unknown")
        details+=("Firewall status: $fw_status")
    fi
    
    generate_health_report "security" "$health_status" "${details[@]}"
    
    [[ "$health_status" == "healthy" ]]
}

# Check performance health
check_performance_health() {
    echo -e "${CYAN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} Checking performance health..."
    
    local health_status="healthy"
    local details=()
    
    # Check CPU usage
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    details+=("CPU usage: ${cpu_usage}%")
    
    if (( $(echo "$cpu_usage > $CPU_THRESHOLD" | bc -l) )); then
        health_status="degraded"
        details+=("WARNING: CPU usage above ${CPU_THRESHOLD}%")
    fi
    
    # Check memory usage
    local mem_usage=$(free | grep Mem | awk '{print ($3/$2) * 100.0}' | cut -d. -f1)
    details+=("Memory usage: ${mem_usage}%")
    
    if [[ $mem_usage -gt $MEMORY_THRESHOLD ]]; then
        health_status="degraded"
        details+=("WARNING: Memory usage above ${MEMORY_THRESHOLD}%")
    fi
    
    # Check application response times
    local response_times=()
    for i in {1..5}; do
        local resp_time=$(curl -s -o /dev/null -w "%{time_total}" http://localhost:3000/ 2>/dev/null || echo "0")
        response_times+=($resp_time)
    done
    
    # Calculate average response time
    local avg_response_time=$(echo "${response_times[@]}" | awk '{sum=0; for(i=1;i<=NF;i++)sum+=$i; print sum/NF * 1000}')
    details+=("Average response time: ${avg_response_time}ms")
    
    if (( $(echo "$avg_response_time > $RESPONSE_TIME_THRESHOLD" | bc -l) )); then
        health_status="degraded"
        details+=("WARNING: Response time above ${RESPONSE_TIME_THRESHOLD}ms")
    fi
    
    # Check error rates (if metrics available)
    local error_rate=$(curl -s "http://localhost:9090/api/v1/query?query=rate(http_requests_total{status=~\"5..\"}[5m])" 2>/dev/null | \
        jq -r '.data.result[0].value[1] // "0"' 2>/dev/null || echo "0")
    
    local error_percentage=$(echo "$error_rate * 100" | bc -l 2>/dev/null || echo "0")
    details+=("Error rate: ${error_percentage}%")
    
    if (( $(echo "$error_percentage > $ERROR_RATE_THRESHOLD" | bc -l) )); then
        health_status="degraded"
        details+=("WARNING: Error rate above ${ERROR_RATE_THRESHOLD}%")
    fi
    
    generate_health_report "performance" "$health_status" "${details[@]}"
    
    [[ "$health_status" == "healthy" ]]
}

# Generate health report
generate_health_report() {
    local component="$1"
    local status="$2"
    shift 2
    local details=("$@")
    
    # Create JSON report entry
    local report_entry=$(jq -n \
        --arg comp "$component" \
        --arg stat "$status" \
        --argjson det "$(printf '%s\n' "${details[@]}" | jq -R . | jq -s .)" \
        --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        '{
            component: $comp,
            status: $stat,
            details: $det,
            timestamp: $ts
        }')
    
    # Append to report file
    echo "$report_entry" >> "${HEALTH_REPORT}.tmp"
    
    # Display result
    if [[ "$status" == "healthy" ]]; then
        echo -e "${GREEN}✓ ${component}: ${status}${NC}"
    elif [[ "$status" == "degraded" ]]; then
        echo -e "${YELLOW}⚠ ${component}: ${status}${NC}"
    else
        echo -e "${RED}✗ ${component}: ${status}${NC}"
    fi
    
    # Display details if verbose
    if [[ "${VERBOSE}" == "true" ]]; then
        for detail in "${details[@]}"; do
            echo "  $detail"
        done
    fi
}

# Generate final report
generate_final_report() {
    # Combine all reports
    if [[ -f "${HEALTH_REPORT}.tmp" ]]; then
        jq -s '.' "${HEALTH_REPORT}.tmp" > "${HEALTH_REPORT}"
        rm -f "${HEALTH_REPORT}.tmp"
        
        # Calculate overall health
        local total_checks=$(jq 'length' "${HEALTH_REPORT}")
        local healthy_checks=$(jq '[.[] | select(.status == "healthy")] | length' "${HEALTH_REPORT}")
        local degraded_checks=$(jq '[.[] | select(.status == "degraded")] | length' "${HEALTH_REPORT}")
        local unhealthy_checks=$(jq '[.[] | select(.status == "unhealthy")] | length' "${HEALTH_REPORT}")
        
        # Determine overall status
        local overall_status="healthy"
        if [[ $unhealthy_checks -gt 0 ]]; then
            overall_status="unhealthy"
        elif [[ $degraded_checks -gt 0 ]]; then
            overall_status="degraded"
        fi
        
        # Display summary
        echo
        echo -e "${MAGENTA}╔════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${MAGENTA}║            NuxtOps V3 Health Validation Summary                ║${NC}"
        echo -e "${MAGENTA}╚════════════════════════════════════════════════════════════════╝${NC}"
        echo
        echo -e "${CYAN}Overall Status:${NC} $(format_status "$overall_status")"
        echo -e "${CYAN}Total Checks:${NC} $total_checks"
        echo -e "${GREEN}Healthy:${NC} $healthy_checks"
        echo -e "${YELLOW}Degraded:${NC} $degraded_checks"
        echo -e "${RED}Unhealthy:${NC} $unhealthy_checks"
        echo
        echo -e "${CYAN}Report saved to:${NC} ${HEALTH_REPORT}"
        
        # Exit with appropriate code
        if [[ "$overall_status" == "unhealthy" ]]; then
            exit 2
        elif [[ "$overall_status" == "degraded" ]]; then
            exit 1
        else
            exit 0
        fi
    fi
}

# Format status with color
format_status() {
    local status="$1"
    case "$status" in
        "healthy")
            echo -e "${GREEN}$status${NC}"
            ;;
        "degraded")
            echo -e "${YELLOW}$status${NC}"
            ;;
        "unhealthy")
            echo -e "${RED}$status${NC}"
            ;;
        *)
            echo "$status"
            ;;
    esac
}

# Main function
main() {
    local environment="${1:-development}"
    local detailed="${2:-}"
    
    # Set verbosity
    VERBOSE="false"
    if [[ "$detailed" == "--detailed" ]]; then
        VERBOSE="true"
    fi
    
    # Initialize
    init_logging
    
    echo -e "${MAGENTA}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║            NuxtOps V3 Health Validation                        ║${NC}"
    echo -e "${MAGENTA}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${CYAN}Environment:${NC} $environment"
    echo -e "${CYAN}Timestamp:${NC} $(date +'%Y-%m-%d %H:%M:%S')"
    echo
    
    # Run health checks
    local failed_checks=0
    
    for check in "${HEALTH_CHECKS[@]}"; do
        case "$check" in
            "application")
                check_application_health || ((failed_checks++))
                ;;
            "database")
                check_database_health || ((failed_checks++))
                ;;
            "cache")
                check_database_health || ((failed_checks++))  # Included in database check
                ;;
            "monitoring")
                check_monitoring_health || ((failed_checks++))
                ;;
            "observability")
                check_observability_health || ((failed_checks++))
                ;;
            "network")
                check_network_health || ((failed_checks++))
                ;;
            "storage")
                check_storage_health || ((failed_checks++))
                ;;
            "security")
                check_security_health || ((failed_checks++))
                ;;
            "performance")
                check_performance_health || ((failed_checks++))
                ;;
        esac
    done
    
    # Generate final report
    generate_final_report
}

# Show usage
usage() {
    cat << EOF
Usage: $0 [ENVIRONMENT] [OPTIONS]

ENVIRONMENT:
    development  - Validate development environment (default)
    staging      - Validate staging environment
    production   - Validate production environment

OPTIONS:
    --detailed   - Show detailed health information
    --help       - Show this help message

Examples:
    $0                          # Validate development environment
    $0 production               # Validate production environment
    $0 staging --detailed       # Detailed validation for staging

Exit Codes:
    0 - All checks passed (healthy)
    1 - Some checks degraded
    2 - Critical checks failed (unhealthy)

EOF
}

# Parse arguments
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    usage
    exit 0
fi

# Execute main function
main "$@"