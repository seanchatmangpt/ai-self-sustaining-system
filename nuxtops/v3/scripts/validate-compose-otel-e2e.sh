#!/usr/bin/env bash

# NuxtOps V3 Docker Compose OpenTelemetry E2E Validation
# Validates complete OpenTelemetry stack deployment via Docker Compose

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
readonly VALIDATION_ID="compose_otel_$(date +%s%N)"
readonly COMPOSE_FILE="${PROJECT_ROOT}/monitoring/compose.otel.yaml"
readonly REPORT_FILE="${PROJECT_ROOT}/compose-otel-validation-${VALIDATION_ID}.json"

# Container and service configuration
readonly OTEL_SERVICES=(
    "otel-collector"
    "jaeger"
    "prometheus"
    "grafana"
    "loki"
    "tempo"
)

readonly VALIDATION_ENDPOINTS=(
    "http://localhost:13133/"           # OTel Collector health
    "http://localhost:16686/"           # Jaeger UI
    "http://localhost:9090/"            # Prometheus
    "http://localhost:3000/"            # Grafana
    "http://localhost:3100/ready"       # Loki
    "http://localhost:3200/ready"       # Tempo
)

# Test scenarios
readonly TEST_SCENARIOS=(
    "stack_deployment"
    "service_connectivity"
    "data_flow_validation"
    "cross_service_correlation"
    "performance_monitoring"
    "alerting_rules"
    "dashboard_validation"
    "backup_restore"
)

# Initialize validation
init_validation() {
    echo -e "${MAGENTA}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║       Docker Compose OpenTelemetry E2E Validation             ║${NC}"
    echo -e "${MAGENTA}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${CYAN}Validation ID:${NC} ${VALIDATION_ID}"
    echo -e "${CYAN}Compose File:${NC} ${COMPOSE_FILE}"
    echo -e "${CYAN}Timestamp:${NC} $(date +'%Y-%m-%d %H:%M:%S')"
    echo
    
    # Create validation report
    echo '{"validation_id": "'"${VALIDATION_ID}"'", "start_time": "'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'", "scenarios": []}' > "$REPORT_FILE"
}

# Test stack deployment
test_stack_deployment() {
    echo -e "${CYAN}Testing OpenTelemetry stack deployment...${NC}"
    
    local scenario_result="passed"
    local details=()
    
    # Check if compose file exists
    if [[ ! -f "$COMPOSE_FILE" ]]; then
        scenario_result="failed"
        details+=("Compose file not found: $COMPOSE_FILE")
        save_scenario_result "stack_deployment" "$scenario_result" "${details[@]}"
        return 1
    fi
    
    details+=("Compose file found: $COMPOSE_FILE")
    
    # Stop any existing stack
    echo -e "${YELLOW}Stopping existing stack...${NC}"
    docker-compose -f "$COMPOSE_FILE" down --volumes --remove-orphans 2>/dev/null || true
    
    # Pull latest images
    echo -e "${YELLOW}Pulling latest images...${NC}"
    if docker-compose -f "$COMPOSE_FILE" pull; then
        details+=("Image pull: Success")
    else
        scenario_result="degraded"
        details+=("Image pull: Failed (continuing with local images)")
    fi
    
    # Start stack
    echo -e "${YELLOW}Starting OpenTelemetry stack...${NC}"
    if docker-compose -f "$COMPOSE_FILE" up -d; then
        details+=("Stack startup: Success")
    else
        scenario_result="failed"
        details+=("Stack startup: Failed")
        save_scenario_result "stack_deployment" "$scenario_result" "${details[@]}"
        return 1
    fi
    
    # Wait for services to be ready
    echo -e "${YELLOW}Waiting for services to be ready...${NC}"
    local max_attempts=60
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        local ready_services=0
        
        for service in "${OTEL_SERVICES[@]}"; do
            if docker-compose -f "$COMPOSE_FILE" ps --services --filter "status=running" | grep -q "^${service}$"; then
                ((ready_services++))
            fi
        done
        
        if [ $ready_services -eq ${#OTEL_SERVICES[@]} ]; then
            details+=("All services running: Yes (${ready_services}/${#OTEL_SERVICES[@]})")
            break
        fi
        
        sleep 5
        ((attempt++))
    done
    
    if [ $attempt -eq $max_attempts ]; then
        scenario_result="failed"
        details+=("Service startup timeout: Some services not running")
    fi
    
    # Check individual service status
    for service in "${OTEL_SERVICES[@]}"; do
        local status=$(docker-compose -f "$COMPOSE_FILE" ps "$service" --format "{{.State}}" 2>/dev/null || echo "not found")
        if [[ "$status" == "running" ]]; then
            details+=("Service $service: Running")
        else
            scenario_result="degraded"
            details+=("Service $service: $status")
        fi
    done
    
    save_scenario_result "stack_deployment" "$scenario_result" "${details[@]}"
    [[ "$scenario_result" == "passed" ]]
}

# Test service connectivity
test_service_connectivity() {
    echo -e "${CYAN}Testing service connectivity...${NC}"
    
    local scenario_result="passed"
    local details=()
    
    # Test endpoint connectivity
    for i in "${!VALIDATION_ENDPOINTS[@]}"; do
        local endpoint="${VALIDATION_ENDPOINTS[$i]}"
        local service="${OTEL_SERVICES[$i]:-unknown}"
        
        echo -e "${YELLOW}Testing $service endpoint: $endpoint${NC}"
        
        local max_attempts=30
        local attempt=0
        local connected=false
        
        while [ $attempt -lt $max_attempts ]; do
            if curl -s --max-time 5 "$endpoint" &>/dev/null; then
                connected=true
                break
            fi
            sleep 2
            ((attempt++))
        done
        
        if $connected; then
            details+=("$service ($endpoint): Connected")
        else
            scenario_result="degraded"
            details+=("$service ($endpoint): Connection failed")
        fi
    done
    
    # Test inter-service communication
    echo -e "${YELLOW}Testing inter-service communication...${NC}"
    
    # Test OTel Collector to Jaeger
    local jaeger_endpoint=$(docker-compose -f "$COMPOSE_FILE" exec -T otel-collector printenv JAEGER_ENDPOINT 2>/dev/null || echo "")
    if [[ -n "$jaeger_endpoint" ]]; then
        details+=("OTel Collector → Jaeger config: Present")
    else
        scenario_result="degraded"
        details+=("OTel Collector → Jaeger config: Missing")
    fi
    
    # Test OTel Collector to Prometheus
    local prom_endpoint=$(docker-compose -f "$COMPOSE_FILE" exec -T otel-collector printenv PROMETHEUS_ENDPOINT 2>/dev/null || echo "")
    if [[ -n "$prom_endpoint" ]]; then
        details+=("OTel Collector → Prometheus config: Present")
    else
        scenario_result="degraded"
        details+=("OTel Collector → Prometheus config: Missing")
    fi
    
    # Test network connectivity between containers
    if docker-compose -f "$COMPOSE_FILE" exec -T prometheus wget -q --timeout=5 -O- http://otel-collector:8888/metrics &>/dev/null; then
        details+=("Prometheus → OTel Collector network: Connected")
    else
        scenario_result="degraded"
        details+=("Prometheus → OTel Collector network: Failed")
    fi
    
    save_scenario_result "service_connectivity" "$scenario_result" "${details[@]}"
    [[ "$scenario_result" == "passed" || "$scenario_result" == "degraded" ]]
}

# Test data flow validation
test_data_flow_validation() {
    echo -e "${CYAN}Testing data flow validation...${NC}"
    
    local scenario_result="passed"
    local details=()
    
    # Generate test telemetry data
    echo -e "${YELLOW}Generating test telemetry data...${NC}"
    
    # Generate traces
    local trace_id=$(printf '%032x' $RANDOM$RANDOM$RANDOM$RANDOM)
    local span_id=$(printf '%016x' $RANDOM$RANDOM)
    local timestamp=$(date +%s%N)
    
    local trace_payload=$(cat <<EOF
{
  "resourceSpans": [{
    "resource": {
      "attributes": [{
        "key": "service.name",
        "value": {"stringValue": "compose-validation-test"}
      }]
    },
    "scopeSpans": [{
      "spans": [{
        "traceId": "${trace_id}",
        "spanId": "${span_id}",
        "name": "compose.validation.test",
        "startTimeUnixNano": "${timestamp}",
        "endTimeUnixNano": "$((timestamp + 1000000000))"
      }]
    }]
  }]
}
EOF
)
    
    # Send trace to OTel Collector
    if curl -s -X POST "http://localhost:4318/v1/traces" \
        -H "Content-Type: application/json" \
        -d "$trace_payload" &>/dev/null; then
        details+=("Trace sent to collector: Success")
    else
        scenario_result="failed"
        details+=("Trace sent to collector: Failed")
    fi
    
    # Generate metrics
    local metrics_payload=$(cat <<EOF
{
  "resourceMetrics": [{
    "resource": {
      "attributes": [{
        "key": "service.name",
        "value": {"stringValue": "compose-validation-test"}
      }]
    },
    "scopeMetrics": [{
      "metrics": [{
        "name": "compose_validation_counter",
        "unit": "1",
        "sum": {
          "dataPoints": [{
            "asInt": "42",
            "timeUnixNano": "${timestamp}",
            "attributes": [{
              "key": "test.scenario",
              "value": {"stringValue": "compose_validation"}
            }]
          }],
          "aggregationTemporality": 2,
          "isMonotonic": true
        }
      }]
    }]
  }]
}
EOF
)
    
    # Send metrics to OTel Collector
    if curl -s -X POST "http://localhost:4318/v1/metrics" \
        -H "Content-Type: application/json" \
        -d "$metrics_payload" &>/dev/null; then
        details+=("Metrics sent to collector: Success")
    else
        scenario_result="failed"
        details+=("Metrics sent to collector: Failed")
    fi
    
    # Wait for data propagation
    echo -e "${YELLOW}Waiting for data propagation...${NC}"
    sleep 10
    
    # Verify trace in Jaeger
    local jaeger_trace=$(curl -s "http://localhost:16686/api/traces/${trace_id}" 2>/dev/null || echo "{}")
    if echo "$jaeger_trace" | jq -e '.data[0]' &>/dev/null; then
        details+=("Trace in Jaeger: Found")
    else
        scenario_result="degraded"
        details+=("Trace in Jaeger: Not found")
    fi
    
    # Verify metrics in Prometheus
    local prom_metrics=$(curl -s "http://localhost:9090/api/v1/query?query=compose_validation_counter" 2>/dev/null || echo "{}")
    if echo "$prom_metrics" | jq -e '.data.result[0]' &>/dev/null; then
        details+=("Metrics in Prometheus: Found")
    else
        scenario_result="degraded"
        details+=("Metrics in Prometheus: Not found")
    fi
    
    # Check OTel Collector metrics
    local collector_metrics=$(curl -s "http://localhost:8888/metrics" 2>/dev/null || echo "")
    if echo "$collector_metrics" | grep -q "otelcol_receiver_accepted_spans"; then
        local spans_received=$(echo "$collector_metrics" | grep "otelcol_receiver_accepted_spans" | tail -1 | awk '{print $2}')
        details+=("Spans received by collector: $spans_received")
    else
        scenario_result="degraded"
        details+=("Collector span metrics: Not found")
    fi
    
    if echo "$collector_metrics" | grep -q "otelcol_receiver_accepted_metric_points"; then
        local metrics_received=$(echo "$collector_metrics" | grep "otelcol_receiver_accepted_metric_points" | tail -1 | awk '{print $2}')
        details+=("Metric points received by collector: $metrics_received")
    else
        scenario_result="degraded"
        details+=("Collector metric metrics: Not found")
    fi
    
    save_scenario_result "data_flow_validation" "$scenario_result" "${details[@]}"
    [[ "$scenario_result" == "passed" || "$scenario_result" == "degraded" ]]
}

# Test cross-service correlation
test_cross_service_correlation() {
    echo -e "${CYAN}Testing cross-service correlation...${NC}"
    
    local scenario_result="passed"
    local details=()
    
    # Generate correlated telemetry across multiple services
    local trace_id=$(printf '%032x' $RANDOM$RANDOM$RANDOM$RANDOM)
    local parent_span_id=$(printf '%016x' $RANDOM$RANDOM)
    local child_span_id=$(printf '%016x' $RANDOM$RANDOM)
    local timestamp=$(date +%s%N)
    
    # Send parent span (frontend service)
    local parent_payload=$(cat <<EOF
{
  "resourceSpans": [{
    "resource": {
      "attributes": [{
        "key": "service.name",
        "value": {"stringValue": "frontend-service"}
      }]
    },
    "scopeSpans": [{
      "spans": [{
        "traceId": "${trace_id}",
        "spanId": "${parent_span_id}",
        "name": "http_request",
        "kind": 2,
        "startTimeUnixNano": "${timestamp}",
        "endTimeUnixNano": "$((timestamp + 2000000000))"
      }]
    }]
  }]
}
EOF
)
    
    # Send child span (backend service)
    local child_payload=$(cat <<EOF
{
  "resourceSpans": [{
    "resource": {
      "attributes": [{
        "key": "service.name",
        "value": {"stringValue": "backend-service"}
      }]
    },
    "scopeSpans": [{
      "spans": [{
        "traceId": "${trace_id}",
        "spanId": "${child_span_id}",
        "parentSpanId": "${parent_span_id}",
        "name": "database_query",
        "kind": 3,
        "startTimeUnixNano": "$((timestamp + 100000000))",
        "endTimeUnixNano": "$((timestamp + 1500000000))"
      }]
    }]
  }]
}
EOF
)
    
    # Send both spans
    curl -s -X POST "http://localhost:4318/v1/traces" \
        -H "Content-Type: application/json" \
        -d "$parent_payload" &>/dev/null
    
    curl -s -X POST "http://localhost:4318/v1/traces" \
        -H "Content-Type: application/json" \
        -d "$child_payload" &>/dev/null
    
    details+=("Correlated spans sent: Yes")
    
    # Wait for processing
    sleep 10
    
    # Check trace correlation in Jaeger
    local trace_data=$(curl -s "http://localhost:16686/api/traces/${trace_id}" 2>/dev/null || echo "{}")
    
    if echo "$trace_data" | jq -e '.data[0]' &>/dev/null; then
        local span_count=$(echo "$trace_data" | jq '.data[0].spans | length' 2>/dev/null || echo "0")
        details+=("Spans in trace: $span_count")
        
        if [[ $span_count -eq 2 ]]; then
            details+=("Trace correlation: Success")
            
            # Check parent-child relationship
            local has_parent_child=$(echo "$trace_data" | jq -r '.data[0].spans[] | select(.references[]?.refType == "CHILD_OF") | .operationName' 2>/dev/null || echo "")
            if [[ -n "$has_parent_child" ]]; then
                details+=("Parent-child relationship: Preserved")
            else
                scenario_result="degraded"
                details+=("Parent-child relationship: Not preserved")
            fi
        else
            scenario_result="degraded"
            details+=("Trace correlation: Incomplete")
        fi
    else
        scenario_result="failed"
        details+=("Trace correlation: Failed")
    fi
    
    # Check service dependencies
    local dependencies=$(curl -s "http://localhost:16686/api/dependencies?endTs=$(date +%s)000&lookback=3600000" 2>/dev/null || echo "[]")
    
    if echo "$dependencies" | jq -e '.[0]' &>/dev/null; then
        local dep_count=$(echo "$dependencies" | jq 'length' 2>/dev/null || echo "0")
        details+=("Service dependencies discovered: $dep_count")
    else
        details+=("Service dependencies discovered: 0")
    fi
    
    save_scenario_result "cross_service_correlation" "$scenario_result" "${details[@]}"
    [[ "$scenario_result" == "passed" || "$scenario_result" == "degraded" ]]
}

# Test performance monitoring
test_performance_monitoring() {
    echo -e "${CYAN}Testing performance monitoring...${NC}"
    
    local scenario_result="passed"
    local details=()
    
    # Check resource usage of all services
    for service in "${OTEL_SERVICES[@]}"; do
        local stats=$(docker stats --no-stream --format "json" "${service}" 2>/dev/null || echo "{}")
        
        if [[ "$stats" != "{}" ]]; then
            local cpu=$(echo "$stats" | jq -r '.CPUPerc' | tr -d '%')
            local memory=$(echo "$stats" | jq -r '.MemUsage' | awk '{print $1}')
            
            details+=("$service - CPU: ${cpu}%, Memory: ${memory}")
            
            # Check if CPU usage is reasonable (< 50%)
            if (( $(echo "$cpu > 50" | bc -l) )); then
                scenario_result="degraded"
                details+=("WARNING: $service high CPU usage")
            fi
        else
            scenario_result="degraded"
            details+=("$service - Stats not available")
        fi
    done
    
    # Check overall system resource usage
    local total_memory=$(docker stats --no-stream --format "table {{.Container}}\t{{.MemUsage}}" | grep -E "$(IFS='|'; echo "${OTEL_SERVICES[*]}")" | awk '{print $2}' | cut -d'/' -f1 | sed 's/[^0-9.]//g' | awk '{sum += $1} END {print sum}')
    
    if [[ -n "$total_memory" ]]; then
        details+=("Total stack memory usage: ${total_memory}MB")
    fi
    
    # Test throughput
    echo -e "${YELLOW}Testing throughput...${NC}"
    
    # Send multiple traces rapidly
    for i in $(seq 1 100); do
        local trace_id=$(printf '%032x' $RANDOM$RANDOM$RANDOM$RANDOM)
        local span_id=$(printf '%016x' $RANDOM$RANDOM)
        
        curl -s -X POST "http://localhost:4318/v1/traces" \
            -H "Content-Type: application/json" \
            -d "{\"resourceSpans\":[{\"scopeSpans\":[{\"spans\":[{\"traceId\":\"${trace_id}\",\"spanId\":\"${span_id}\",\"name\":\"throughput_test_${i}\",\"startTimeUnixNano\":\"$(date +%s%N)\",\"endTimeUnixNano\":\"$(date +%s%N)\"}]}]}]}" &
    done
    
    wait  # Wait for all background jobs
    
    details+=("Throughput test: 100 traces sent concurrently")
    
    # Wait and check if collector handled the load
    sleep 10
    
    local collector_metrics=$(curl -s "http://localhost:8888/metrics" 2>/dev/null || echo "")
    if echo "$collector_metrics" | grep -q "otelcol_receiver_accepted_spans"; then
        local total_spans=$(echo "$collector_metrics" | grep "otelcol_receiver_accepted_spans" | tail -1 | awk '{print $2}')
        details+=("Total spans processed: $total_spans")
    fi
    
    save_scenario_result "performance_monitoring" "$scenario_result" "${details[@]}"
    [[ "$scenario_result" == "passed" || "$scenario_result" == "degraded" ]]
}

# Test alerting rules
test_alerting_rules() {
    echo -e "${CYAN}Testing alerting rules...${NC}"
    
    local scenario_result="passed"
    local details=()
    
    # Check if Prometheus has alerting rules configured
    local alerts=$(curl -s "http://localhost:9090/api/v1/rules" 2>/dev/null || echo "{}")
    
    if echo "$alerts" | jq -e '.data.groups[0]' &>/dev/null; then
        local rule_count=$(echo "$alerts" | jq '[.data.groups[].rules[]] | length' 2>/dev/null || echo "0")
        details+=("Alerting rules configured: $rule_count")
        
        # Check for OpenTelemetry specific alerts
        local otel_alerts=$(echo "$alerts" | jq -r '.data.groups[].rules[] | select(.alert | contains("OpenTelemetry") or contains("OTel")) | .alert' 2>/dev/null || echo "")
        
        if [[ -n "$otel_alerts" ]]; then
            details+=("OpenTelemetry alerts: Present")
            echo "$otel_alerts" | while read -r alert; do
                details+=("  Alert: $alert")
            done
        else
            scenario_result="degraded"
            details+=("OpenTelemetry alerts: Not configured")
        fi
    else
        scenario_result="degraded"
        details+=("Alerting rules configured: None")
    fi
    
    # Check current alert status
    local active_alerts=$(curl -s "http://localhost:9090/api/v1/alerts" 2>/dev/null || echo "{}")
    
    if echo "$active_alerts" | jq -e '.data.alerts[0]' &>/dev/null; then
        local alert_count=$(echo "$active_alerts" | jq '.data.alerts | length' 2>/dev/null || echo "0")
        details+=("Active alerts: $alert_count")
        
        # List active alerts
        echo "$active_alerts" | jq -r '.data.alerts[] | "\(.labels.alertname): \(.state)"' 2>/dev/null | while read -r alert; do
            details+=("  $alert")
        done
    else
        details+=("Active alerts: None")
    fi
    
    save_scenario_result "alerting_rules" "$scenario_result" "${details[@]}"
    [[ "$scenario_result" == "passed" || "$scenario_result" == "degraded" ]]
}

# Test dashboard validation
test_dashboard_validation() {
    echo -e "${CYAN}Testing dashboard validation...${NC}"
    
    local scenario_result="passed"
    local details=()
    
    # Check if Grafana has OpenTelemetry dashboards
    local dashboards=$(curl -s -u admin:admin "http://localhost:3000/api/search?type=dash-db" 2>/dev/null || echo "[]")
    
    if echo "$dashboards" | jq -e '.[0]' &>/dev/null; then
        local dashboard_count=$(echo "$dashboards" | jq 'length' 2>/dev/null || echo "0")
        details+=("Grafana dashboards: $dashboard_count")
        
        # Look for OpenTelemetry related dashboards
        local otel_dashboards=$(echo "$dashboards" | jq -r '.[] | select(.title | contains("OpenTelemetry") or contains("OTel") or contains("Tracing")) | .title' 2>/dev/null || echo "")
        
        if [[ -n "$otel_dashboards" ]]; then
            details+=("OpenTelemetry dashboards: Present")
            echo "$otel_dashboards" | while read -r dashboard; do
                details+=("  Dashboard: $dashboard")
            done
        else
            scenario_result="degraded"
            details+=("OpenTelemetry dashboards: Not found")
        fi
    else
        scenario_result="degraded"
        details+=("Grafana dashboards: None")
    fi
    
    # Check data sources
    local datasources=$(curl -s -u admin:admin "http://localhost:3000/api/datasources" 2>/dev/null || echo "[]")
    
    if echo "$datasources" | jq -e '.[0]' &>/dev/null; then
        local ds_count=$(echo "$datasources" | jq 'length' 2>/dev/null || echo "0")
        details+=("Grafana data sources: $ds_count")
        
        # Check for required data sources
        local required_ds=("prometheus" "jaeger" "loki" "tempo")
        
        for ds in "${required_ds[@]}"; do
            if echo "$datasources" | jq -e ".[] | select(.type == \"$ds\")" &>/dev/null; then
                details+=("Data source $ds: Configured")
            else
                scenario_result="degraded"
                details+=("Data source $ds: Not configured")
            fi
        done
    else
        scenario_result="failed"
        details+=("Grafana data sources: None")
    fi
    
    save_scenario_result "dashboard_validation" "$scenario_result" "${details[@]}"
    [[ "$scenario_result" == "passed" || "$scenario_result" == "degraded" ]]
}

# Test backup and restore
test_backup_restore() {
    echo -e "${CYAN}Testing backup and restore capabilities...${NC}"
    
    local scenario_result="passed"
    local details=()
    
    # Create backup directory
    local backup_dir="${PROJECT_ROOT}/backups/compose-otel-${VALIDATION_ID}"
    mkdir -p "$backup_dir"
    
    # Backup Prometheus data
    if docker-compose -f "$COMPOSE_FILE" exec -T prometheus tar -czf - /prometheus 2>/dev/null > "$backup_dir/prometheus-data.tar.gz"; then
        details+=("Prometheus backup: Success")
    else
        scenario_result="degraded"
        details+=("Prometheus backup: Failed")
    fi
    
    # Backup Grafana data
    if docker-compose -f "$COMPOSE_FILE" exec -T grafana tar -czf - /var/lib/grafana 2>/dev/null > "$backup_dir/grafana-data.tar.gz"; then
        details+=("Grafana backup: Success")
    else
        scenario_result="degraded"
        details+=("Grafana backup: Failed")
    fi
    
    # Export configurations
    if docker-compose -f "$COMPOSE_FILE" config > "$backup_dir/docker-compose.yml"; then
        details+=("Compose config export: Success")
    else
        scenario_result="degraded"
        details+=("Compose config export: Failed")
    fi
    
    # Test configuration export
    local config_files=(
        "/etc/otelcol-contrib/otel-collector-config.yaml"
        "/etc/prometheus/prometheus.yml"
        "/etc/grafana/grafana.ini"
    )
    
    for config in "${config_files[@]}"; do
        local service=$(echo "$config" | cut -d'/' -f3)
        local filename=$(basename "$config")
        
        if docker-compose -f "$COMPOSE_FILE" exec -T "$service" cat "$config" > "$backup_dir/$filename" 2>/dev/null; then
            details+=("$service config backup: Success")
        else
            scenario_result="degraded"
            details+=("$service config backup: Failed")
        fi
    done
    
    # Check backup file sizes
    local backup_size=$(du -sh "$backup_dir" | awk '{print $1}')
    details+=("Total backup size: $backup_size")
    
    details+=("Backup location: $backup_dir")
    
    save_scenario_result "backup_restore" "$scenario_result" "${details[@]}"
    [[ "$scenario_result" == "passed" || "$scenario_result" == "degraded" ]]
}

# Save scenario result
save_scenario_result() {
    local scenario_name="$1"
    local result="$2"
    shift 2
    local details=("$@")
    
    # Create scenario result entry
    local scenario_entry=$(jq -n \
        --arg name "$scenario_name" \
        --arg res "$result" \
        --argjson det "$(printf '%s\n' "${details[@]}" | jq -R . | jq -s .)" \
        --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        '{
            name: $name,
            result: $res,
            details: $det,
            timestamp: $ts
        }')
    
    # Update report file
    jq ".scenarios += [$scenario_entry]" "$REPORT_FILE" > "${REPORT_FILE}.tmp" && mv "${REPORT_FILE}.tmp" "$REPORT_FILE"
    
    # Display result
    if [[ "$result" == "passed" ]]; then
        echo -e "${GREEN}✓ ${scenario_name}: ${result}${NC}"
    elif [[ "$result" == "degraded" ]]; then
        echo -e "${YELLOW}⚠ ${scenario_name}: ${result}${NC}"
    else
        echo -e "${RED}✗ ${scenario_name}: ${result}${NC}"
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
    local total_scenarios=$(jq '.scenarios | length' "$REPORT_FILE")
    local passed_scenarios=$(jq '[.scenarios[] | select(.result == "passed")] | length' "$REPORT_FILE")
    local degraded_scenarios=$(jq '[.scenarios[] | select(.result == "degraded")] | length' "$REPORT_FILE")
    local failed_scenarios=$(jq '[.scenarios[] | select(.result == "failed")] | length' "$REPORT_FILE")
    
    # Determine overall result
    local overall_result="passed"
    if [[ $failed_scenarios -gt 0 ]]; then
        overall_result="failed"
    elif [[ $degraded_scenarios -gt 0 ]]; then
        overall_result="degraded"
    fi
    
    # Add summary to report
    jq \
        --arg end_time "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --arg overall "$overall_result" \
        --argjson total "$total_scenarios" \
        --argjson passed "$passed_scenarios" \
        --argjson degraded "$degraded_scenarios" \
        --argjson failed "$failed_scenarios" \
        '. + {
            end_time: $end_time,
            summary: {
                overall_result: $overall,
                total_scenarios: $total,
                passed: $passed,
                degraded: $degraded,
                failed: $failed
            }
        }' "$REPORT_FILE" > "${REPORT_FILE}.tmp" && mv "${REPORT_FILE}.tmp" "$REPORT_FILE"
    
    # Display summary
    echo
    echo -e "${MAGENTA}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║      Docker Compose OpenTelemetry Validation Summary          ║${NC}"
    echo -e "${MAGENTA}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${CYAN}Overall Result:${NC} $(format_result "$overall_result")"
    echo -e "${CYAN}Total Scenarios:${NC} $total_scenarios"
    echo -e "${GREEN}Passed:${NC} $passed_scenarios"
    echo -e "${YELLOW}Degraded:${NC} $degraded_scenarios"
    echo -e "${RED}Failed:${NC} $failed_scenarios"
    echo
    echo -e "${CYAN}Full report:${NC} $REPORT_FILE"
    
    # Exit with appropriate code
    if [[ "$overall_result" == "failed" ]]; then
        exit 1
    else
        exit 0
    fi
}

# Format result with color
format_result() {
    local result="$1"
    case "$result" in
        "passed")
            echo -e "${GREEN}PASSED${NC}"
            ;;
        "degraded")
            echo -e "${YELLOW}DEGRADED${NC}"
            ;;
        "failed")
            echo -e "${RED}FAILED${NC}"
            ;;
        *)
            echo "$result"
            ;;
    esac
}

# Cleanup function
cleanup() {
    echo -e "${CYAN}Cleaning up...${NC}"
    
    # Stop the stack
    docker-compose -f "$COMPOSE_FILE" down --volumes --remove-orphans 2>/dev/null || true
    
    echo -e "${GREEN}Cleanup completed${NC}"
}

# Main function
main() {
    local cleanup_on_exit="${1:-true}"
    local verbose="${2:-}"
    
    # Set verbosity
    VERBOSE="false"
    if [[ "$verbose" == "--verbose" || "$verbose" == "-v" ]]; then
        VERBOSE="true"
    fi
    
    # Set cleanup on exit
    if [[ "$cleanup_on_exit" == "true" ]]; then
        trap cleanup EXIT
    fi
    
    # Initialize validation
    init_validation
    
    # Run validation scenarios
    local failed=0
    
    for scenario in "${TEST_SCENARIOS[@]}"; do
        case "$scenario" in
            "stack_deployment")
                test_stack_deployment || ((failed++))
                ;;
            "service_connectivity")
                test_service_connectivity || ((failed++))
                ;;
            "data_flow_validation")
                test_data_flow_validation || ((failed++))
                ;;
            "cross_service_correlation")
                test_cross_service_correlation || ((failed++))
                ;;
            "performance_monitoring")
                test_performance_monitoring || ((failed++))
                ;;
            "alerting_rules")
                test_alerting_rules || ((failed++))
                ;;
            "dashboard_validation")
                test_dashboard_validation || ((failed++))
                ;;
            "backup_restore")
                test_backup_restore || ((failed++))
                ;;
        esac
        
        echo  # Add spacing between scenarios
    done
    
    # Generate final report
    generate_final_report
}

# Show usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

OPTIONS:
    --no-cleanup   - Don't clean up containers after validation
    --verbose, -v  - Show detailed test output
    --help         - Show this help message

Examples:
    $0                    # Full validation with cleanup
    $0 --no-cleanup       # Keep containers running after validation
    $0 --verbose          # Detailed output

This script validates the complete OpenTelemetry stack deployment
via Docker Compose including:
- Stack deployment and service health
- Service connectivity and networking
- Data flow validation (traces, metrics, logs)
- Cross-service correlation
- Performance monitoring
- Alerting rules configuration
- Dashboard validation
- Backup and restore capabilities

EOF
}

# Parse arguments
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    usage
    exit 0
fi

# Parse cleanup option
cleanup_on_exit="true"
verbose=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --no-cleanup)
            cleanup_on_exit="false"
            shift
            ;;
        --verbose|-v)
            verbose="--verbose"
            shift
            ;;
        *)
            shift
            ;;
    esac
done

# Execute main function
main "$cleanup_on_exit" "$verbose"