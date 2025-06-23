#!/bin/bash

set -e

echo "🔍 Validating Observability Infrastructure Health..."
echo "=================================================="

HEALTH_REPORT="observability_health_$(date +%s).json"
FAILED_SERVICES=()

validate_service() {
    local service_name="$1"
    local url="$2"
    local expected_status="${3:-200}"
    
    echo -n "Checking $service_name... "
    
    response=$(curl -s -w "%{http_code}" -o /dev/null --max-time 30 --connect-timeout 10 "$url" 2>/dev/null || echo "000")
    
    if [[ "$response" == "$expected_status" ]]; then
        echo "✅ HEALTHY ($response)"
        echo "  \"$service_name\": {\"status\": \"healthy\", \"url\": \"$url\", \"response_code\": $response}," >> "$HEALTH_REPORT"
    elif [[ "$response" == "000" ]]; then
        echo "❌ UNREACHABLE (timeout)"
        echo "  \"$service_name\": {\"status\": \"unreachable\", \"url\": \"$url\", \"response_code\": null, \"error\": \"timeout\"}," >> "$HEALTH_REPORT"
        FAILED_SERVICES+=("$service_name")
    else
        echo "❌ UNHEALTHY ($response)"
        echo "  \"$service_name\": {\"status\": \"unhealthy\", \"url\": \"$url\", \"response_code\": $response}," >> "$HEALTH_REPORT"
        FAILED_SERVICES+=("$service_name")
    fi
}

validate_prometheus_metrics() {
    local service_name="$1"
    local url="$2"
    
    echo -n "Checking $service_name metrics... "
    
    if metrics=$(curl -s --max-time 10 "$url" 2>/dev/null | head -5); then
        if [[ -n "$metrics" && "$metrics" =~ ^#.*TYPE ]]; then
            echo "✅ METRICS ACTIVE"
            echo "  \"$service_name\": {\"status\": \"metrics_active\", \"url\": \"$url\", \"sample\": \"$(echo "$metrics" | head -1 | tr -d '\n')\"}," >> "$HEALTH_REPORT"
        else
            echo "❌ NO METRICS"
            echo "  \"$service_name\": {\"status\": \"no_metrics\", \"url\": \"$url\"}," >> "$HEALTH_REPORT"
            FAILED_SERVICES+=("$service_name")
        fi
    else
        echo "❌ UNREACHABLE"
        echo "  \"$service_name\": {\"status\": \"unreachable\", \"url\": \"$url\"}," >> "$HEALTH_REPORT"
        FAILED_SERVICES+=("$service_name")
    fi
}

echo "{" > "$HEALTH_REPORT"
echo "  \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"," >> "$HEALTH_REPORT"
echo "  \"services\": {" >> "$HEALTH_REPORT"

validate_service "Grafana" "http://localhost:3001/api/health"
validate_service "Prometheus" "http://localhost:9091/-/healthy"
validate_service "Jaeger" "http://localhost:16686/" 200
validate_service "BeamOps App" "http://localhost:4001/"

validate_prometheus_metrics "PromEx Metrics" "http://localhost:9569/metrics"

sed -i '' '$ s/,$//' "$HEALTH_REPORT" 2>/dev/null || sed -i '$ s/,$//' "$HEALTH_REPORT"
echo "  }," >> "$HEALTH_REPORT"
echo "  \"summary\": {" >> "$HEALTH_REPORT"
echo "    \"total_services\": 5," >> "$HEALTH_REPORT"
echo "    \"failed_services\": ${#FAILED_SERVICES[@]}," >> "$HEALTH_REPORT"
echo "    \"success_rate\": \"$(echo "scale=1; (5-${#FAILED_SERVICES[@]})*100/5" | bc)%\"" >> "$HEALTH_REPORT"
echo "  }" >> "$HEALTH_REPORT"
echo "}" >> "$HEALTH_REPORT"

echo ""
echo "📊 Health Summary:"
echo "=================="
echo "Total Services: 5"
echo "Failed Services: ${#FAILED_SERVICES[@]}"
echo "Success Rate: $(echo "scale=1; (5-${#FAILED_SERVICES[@]})*100/5" | bc)%"

if [[ ${#FAILED_SERVICES[@]} -gt 0 ]]; then
    echo ""
    echo "❌ Failed Services:"
    for service in "${FAILED_SERVICES[@]}"; do
        echo "  - $service"
    done
    echo ""
    echo "📄 Detailed report: $HEALTH_REPORT"
    exit 1
else
    echo ""
    echo "✅ All observability services are healthy!"
    echo "📄 Detailed report: $HEALTH_REPORT"
fi