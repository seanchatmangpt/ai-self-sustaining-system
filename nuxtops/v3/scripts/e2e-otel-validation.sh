#!/usr/bin/env bash

# NuxtOps V3 End-to-End OpenTelemetry Validation
# Comprehensive validation of distributed tracing, metrics, and logs

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
readonly VALIDATION_ID="otel_validation_$(date +%s%N)"
readonly REPORT_FILE="${PROJECT_ROOT}/otel-validation-report-${VALIDATION_ID}.json"
readonly TRACE_OUTPUT="${PROJECT_ROOT}/traces-${VALIDATION_ID}.jsonl"

# OpenTelemetry endpoints
readonly OTEL_COLLECTOR_GRPC="${OTEL_COLLECTOR_GRPC:-localhost:4317}"
readonly OTEL_COLLECTOR_HTTP="${OTEL_COLLECTOR_HTTP:-localhost:4318}"
readonly OTEL_COLLECTOR_METRICS="${OTEL_COLLECTOR_METRICS:-localhost:8888}"
readonly JAEGER_ENDPOINT="${JAEGER_ENDPOINT:-http://localhost:16686}"
readonly PROMETHEUS_ENDPOINT="${PROMETHEUS_ENDPOINT:-http://localhost:9090}"

# Test configuration
readonly TEST_SERVICE_NAME="nuxtops-validation"
readonly TEST_ITERATIONS=10
readonly TRACE_PROPAGATION_TIMEOUT=30

# Validation tests
readonly VALIDATION_TESTS=(
    "collector_connectivity"
    "trace_generation"
    "trace_propagation"
    "metrics_export"
    "logs_correlation"
    "service_map"
    "span_attributes"
    "resource_detection"
    "sampling"
    "performance"
)

# Initialize validation
init_validation() {
    echo -e "${MAGENTA}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║       NuxtOps V3 OpenTelemetry E2E Validation                 ║${NC}"
    echo -e "${MAGENTA}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${CYAN}Validation ID:${NC} ${VALIDATION_ID}"
    echo -e "${CYAN}Timestamp:${NC} $(date +'%Y-%m-%d %H:%M:%S')"
    echo
    
    # Create validation report structure
    echo '{"validation_id": "'"${VALIDATION_ID}"'", "start_time": "'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'", "tests": []}' > "$REPORT_FILE"
}

# Test collector connectivity
test_collector_connectivity() {
    echo -e "${CYAN}Testing OpenTelemetry Collector connectivity...${NC}"
    
    local test_result="passed"
    local details=()
    
    # Test gRPC endpoint
    if timeout 5 bash -c "echo > /dev/tcp/${OTEL_COLLECTOR_GRPC%:*}/${OTEL_COLLECTOR_GRPC#*:}" 2>/dev/null; then
        details+=("gRPC endpoint (${OTEL_COLLECTOR_GRPC}): Connected")
    else
        test_result="failed"
        details+=("gRPC endpoint (${OTEL_COLLECTOR_GRPC}): Connection failed")
    fi
    
    # Test HTTP endpoint
    local http_status=$(curl -s -o /dev/null -w "%{http_code}" "${OTEL_COLLECTOR_HTTP}/v1/traces" -X POST 2>/dev/null || echo "000")
    if [[ "$http_status" == "400" || "$http_status" == "405" ]]; then
        # 400/405 is expected for empty POST
        details+=("HTTP endpoint (${OTEL_COLLECTOR_HTTP}): Available")
    else
        test_result="failed"
        details+=("HTTP endpoint (${OTEL_COLLECTOR_HTTP}): Not available (HTTP ${http_status})")
    fi
    
    # Test metrics endpoint
    if curl -s "${OTEL_COLLECTOR_METRICS}/metrics" | grep -q "otelcol_"; then
        details+=("Metrics endpoint (${OTEL_COLLECTOR_METRICS}): Available")
    else
        test_result="degraded"
        details+=("Metrics endpoint (${OTEL_COLLECTOR_METRICS}): Not available")
    fi
    
    # Test health endpoint
    if curl -s "http://localhost:13133/" &>/dev/null; then
        details+=("Health endpoint: Available")
    else
        test_result="degraded"
        details+=("Health endpoint: Not available")
    fi
    
    save_test_result "collector_connectivity" "$test_result" "${details[@]}"
    
    [[ "$test_result" == "passed" ]]
}

# Test trace generation
test_trace_generation() {
    echo -e "${CYAN}Testing trace generation...${NC}"
    
    local test_result="passed"
    local details=()
    local trace_id=""
    
    # Generate test trace using curl with OTLP
    trace_id=$(generate_test_trace)
    
    if [[ -n "$trace_id" ]]; then
        details+=("Generated trace ID: ${trace_id}")
        
        # Wait for trace to appear in Jaeger
        sleep 5
        
        # Query Jaeger for the trace
        local trace_data=$(curl -s "${JAEGER_ENDPOINT}/api/traces/${trace_id}" 2>/dev/null || echo "{}")
        
        if echo "$trace_data" | jq -e '.data[0]' &>/dev/null; then
            details+=("Trace found in Jaeger: Yes")
            
            # Validate trace structure
            local span_count=$(echo "$trace_data" | jq '.data[0].spans | length' 2>/dev/null || echo "0")
            details+=("Span count: ${span_count}")
            
            if [[ $span_count -eq 0 ]]; then
                test_result="failed"
                details+=("ERROR: No spans in trace")
            fi
        else
            test_result="failed"
            details+=("Trace found in Jaeger: No")
        fi
    else
        test_result="failed"
        details+=("Failed to generate trace")
    fi
    
    save_test_result "trace_generation" "$test_result" "${details[@]}"
    
    [[ "$test_result" == "passed" ]]
}

# Generate test trace
generate_test_trace() {
    local trace_id=$(printf '%032x' $RANDOM$RANDOM$RANDOM$RANDOM)
    local span_id=$(printf '%016x' $RANDOM$RANDOM)
    local timestamp=$(date +%s%N)
    
    # Create OTLP JSON payload
    local otlp_payload=$(cat <<EOF
{
  "resourceSpans": [{
    "resource": {
      "attributes": [{
        "key": "service.name",
        "value": {"stringValue": "${TEST_SERVICE_NAME}"}
      }, {
        "key": "service.version",
        "value": {"stringValue": "1.0.0"}
      }]
    },
    "scopeSpans": [{
      "scope": {
        "name": "nuxtops.validation",
        "version": "1.0.0"
      },
      "spans": [{
        "traceId": "${trace_id}",
        "spanId": "${span_id}",
        "name": "validation.test.span",
        "kind": 1,
        "startTimeUnixNano": "${timestamp}",
        "endTimeUnixNano": "$((timestamp + 1000000000))",
        "attributes": [{
          "key": "test.id",
          "value": {"stringValue": "${VALIDATION_ID}"}
        }, {
          "key": "http.method",
          "value": {"stringValue": "GET"}
        }, {
          "key": "http.url",
          "value": {"stringValue": "http://localhost:3000/test"}
        }],
        "status": {
          "code": 1
        }
      }]
    }]
  }]
}
EOF
)
    
    # Send to collector
    local response=$(curl -s -X POST "${OTEL_COLLECTOR_HTTP}/v1/traces" \
        -H "Content-Type: application/json" \
        -d "$otlp_payload" 2>&1)
    
    # Log trace for debugging
    echo "$otlp_payload" >> "$TRACE_OUTPUT"
    
    echo "$trace_id"
}

# Test trace propagation
test_trace_propagation() {
    echo -e "${CYAN}Testing trace propagation...${NC}"
    
    local test_result="passed"
    local details=()
    
    # Create parent trace
    local parent_trace_id=$(printf '%032x' $RANDOM$RANDOM$RANDOM$RANDOM)
    local parent_span_id=$(printf '%016x' $RANDOM$RANDOM)
    
    details+=("Parent trace ID: ${parent_trace_id}")
    details+=("Parent span ID: ${parent_span_id}")
    
    # Test W3C Trace Context propagation
    local traceparent="00-${parent_trace_id}-${parent_span_id}-01"
    local tracestate="nuxtops=validation"
    
    # Make request with trace context headers
    local response=$(curl -s -H "traceparent: ${traceparent}" -H "tracestate: ${tracestate}" \
        "http://localhost:3000/api/trace-test" 2>&1 || echo "{}")
    
    # Check if application created child spans
    sleep 5
    
    # Query for traces with parent
    local child_traces=$(curl -s "${JAEGER_ENDPOINT}/api/traces?service=${TEST_SERVICE_NAME}&tags={\"span.parent_span_id\":\"${parent_span_id}\"}" 2>/dev/null || echo "{}")
    
    if echo "$child_traces" | jq -e '.data[0]' &>/dev/null; then
        details+=("Child spans created: Yes")
        
        # Validate propagation
        local child_trace_id=$(echo "$child_traces" | jq -r '.data[0].traceID' 2>/dev/null || echo "")
        if [[ "$child_trace_id" == "$parent_trace_id" ]]; then
            details+=("Trace context propagated correctly: Yes")
        else
            test_result="failed"
            details+=("Trace context propagated correctly: No")
        fi
    else
        test_result="failed"
        details+=("Child spans created: No")
    fi
    
    # Test B3 propagation
    local b3_header="${parent_trace_id}-${parent_span_id}-1"
    response=$(curl -s -H "b3: ${b3_header}" "http://localhost:3000/api/trace-test" 2>&1 || echo "{}")
    
    if [[ -n "$response" ]]; then
        details+=("B3 propagation tested: Yes")
    fi
    
    save_test_result "trace_propagation" "$test_result" "${details[@]}"
    
    [[ "$test_result" == "passed" ]]
}

# Test metrics export
test_metrics_export() {
    echo -e "${CYAN}Testing metrics export...${NC}"
    
    local test_result="passed"
    local details=()
    
    # Check if metrics are being exported to Prometheus
    local metrics=$(curl -s "${PROMETHEUS_ENDPOINT}/api/v1/query?query=up{job=\"otel-collector\"}" 2>/dev/null || echo "{}")
    
    if echo "$metrics" | jq -e '.data.result[0]' &>/dev/null; then
        details+=("OpenTelemetry Collector metrics in Prometheus: Yes")
        
        # Check specific application metrics
        local app_metrics=(
            "http_server_duration_milliseconds"
            "http_server_active_requests"
            "process_runtime_nodejs_memory_heap_used_bytes"
            "process_runtime_nodejs_active_handles"
        )
        
        for metric in "${app_metrics[@]}"; do
            local metric_data=$(curl -s "${PROMETHEUS_ENDPOINT}/api/v1/query?query=${metric}" 2>/dev/null || echo "{}")
            
            if echo "$metric_data" | jq -e '.data.result[0]' &>/dev/null; then
                details+=("Metric ${metric}: Available")
            else
                test_result="degraded"
                details+=("Metric ${metric}: Not found")
            fi
        done
    else
        test_result="failed"
        details+=("OpenTelemetry Collector metrics in Prometheus: No")
    fi
    
    # Check collector's own metrics
    local collector_metrics=$(curl -s "${OTEL_COLLECTOR_METRICS}/metrics" 2>/dev/null || echo "")
    
    if echo "$collector_metrics" | grep -q "otelcol_receiver_accepted_metric_points"; then
        local accepted_points=$(echo "$collector_metrics" | grep "otelcol_receiver_accepted_metric_points" | tail -1 | awk '{print $2}')
        details+=("Metrics accepted by collector: ${accepted_points}")
    fi
    
    save_test_result "metrics_export" "$test_result" "${details[@]}"
    
    [[ "$test_result" == "passed" || "$test_result" == "degraded" ]]
}

# Test logs correlation
test_logs_correlation() {
    echo -e "${CYAN}Testing logs correlation...${NC}"
    
    local test_result="passed"
    local details=()
    
    # Generate trace with known ID
    local trace_id=$(printf '%032x' $RANDOM$RANDOM$RANDOM$RANDOM)
    local span_id=$(printf '%016x' $RANDOM$RANDOM)
    
    # Make request that should generate correlated logs
    curl -s -H "traceparent: 00-${trace_id}-${span_id}-01" \
        "http://localhost:3000/api/log-test" &>/dev/null
    
    sleep 3
    
    # Check if logs contain trace context
    if command -v docker &>/dev/null; then
        local logs=$(docker logs nuxtops_app 2>&1 | tail -100 || echo "")
        
        if echo "$logs" | grep -q "trace_id.*${trace_id}"; then
            details+=("Logs contain trace_id: Yes")
            
            if echo "$logs" | grep -q "span_id.*${span_id}"; then
                details+=("Logs contain span_id: Yes")
            else
                test_result="degraded"
                details+=("Logs contain span_id: No")
            fi
        else
            test_result="failed"
            details+=("Logs contain trace_id: No")
        fi
    else
        test_result="skipped"
        details+=("Docker not available for log checking")
    fi
    
    # Check if logs are in Loki (if available)
    local loki_query=$(curl -s -G "http://localhost:3100/loki/api/v1/query_range" \
        --data-urlencode "query={service=\"nuxtops\"} |= \"${trace_id}\"" \
        2>/dev/null || echo "{}")
    
    if echo "$loki_query" | jq -e '.data.result[0]' &>/dev/null; then
        details+=("Correlated logs in Loki: Yes")
    else
        details+=("Correlated logs in Loki: No")
    fi
    
    save_test_result "logs_correlation" "$test_result" "${details[@]}"
    
    [[ "$test_result" == "passed" || "$test_result" == "degraded" ]]
}

# Test service map
test_service_map() {
    echo -e "${CYAN}Testing service map generation...${NC}"
    
    local test_result="passed"
    local details=()
    
    # Query Jaeger for service dependencies
    local dependencies=$(curl -s "${JAEGER_ENDPOINT}/api/dependencies?endTs=$(date +%s)000&lookback=3600000" 2>/dev/null || echo "[]")
    
    if echo "$dependencies" | jq -e '.[0]' &>/dev/null; then
        details+=("Service dependencies found: Yes")
        
        local dep_count=$(echo "$dependencies" | jq 'length' 2>/dev/null || echo "0")
        details+=("Number of dependencies: ${dep_count}")
        
        # List services
        local services=$(curl -s "${JAEGER_ENDPOINT}/api/services" 2>/dev/null || echo "{}")
        local service_count=$(echo "$services" | jq '.data | length' 2>/dev/null || echo "0")
        details+=("Services discovered: ${service_count}")
    else
        test_result="degraded"
        details+=("Service dependencies found: No")
    fi
    
    save_test_result "service_map" "$test_result" "${details[@]}"
    
    [[ "$test_result" == "passed" || "$test_result" == "degraded" ]]
}

# Test span attributes
test_span_attributes() {
    echo -e "${CYAN}Testing span attributes...${NC}"
    
    local test_result="passed"
    local details=()
    
    # Generate trace with specific attributes
    local trace_id=$(generate_test_trace_with_attributes)
    
    sleep 5
    
    # Retrieve trace and check attributes
    local trace_data=$(curl -s "${JAEGER_ENDPOINT}/api/traces/${trace_id}" 2>/dev/null || echo "{}")
    
    if echo "$trace_data" | jq -e '.data[0].spans[0]' &>/dev/null; then
        local span=$(echo "$trace_data" | jq '.data[0].spans[0]')
        
        # Check required attributes
        local required_attrs=("service.name" "service.version" "telemetry.sdk.name" "telemetry.sdk.language")
        
        for attr in "${required_attrs[@]}"; do
            if echo "$span" | jq -e ".tags[] | select(.key == \"${attr}\")" &>/dev/null; then
                local value=$(echo "$span" | jq -r ".tags[] | select(.key == \"${attr}\") | .value" 2>/dev/null || echo "")
                details+=("Attribute ${attr}: ${value}")
            else
                test_result="degraded"
                details+=("Attribute ${attr}: Missing")
            fi
        done
        
        # Check semantic conventions
        if echo "$span" | jq -e '.tags[] | select(.key | startswith("http."))' &>/dev/null; then
            details+=("HTTP semantic conventions: Present")
        else
            test_result="degraded"
            details+=("HTTP semantic conventions: Missing")
        fi
    else
        test_result="failed"
        details+=("Failed to retrieve span attributes")
    fi
    
    save_test_result "span_attributes" "$test_result" "${details[@]}"
    
    [[ "$test_result" == "passed" || "$test_result" == "degraded" ]]
}

# Generate trace with attributes
generate_test_trace_with_attributes() {
    local trace_id=$(printf '%032x' $RANDOM$RANDOM$RANDOM$RANDOM)
    local span_id=$(printf '%016x' $RANDOM$RANDOM)
    local timestamp=$(date +%s%N)
    
    local otlp_payload=$(cat <<EOF
{
  "resourceSpans": [{
    "resource": {
      "attributes": [{
        "key": "service.name",
        "value": {"stringValue": "${TEST_SERVICE_NAME}"}
      }, {
        "key": "service.version",
        "value": {"stringValue": "1.0.0"}
      }, {
        "key": "service.instance.id",
        "value": {"stringValue": "instance-${VALIDATION_ID}"}
      }, {
        "key": "telemetry.sdk.name",
        "value": {"stringValue": "opentelemetry"}
      }, {
        "key": "telemetry.sdk.language",
        "value": {"stringValue": "nodejs"}
      }, {
        "key": "telemetry.sdk.version",
        "value": {"stringValue": "1.0.0"}
      }]
    },
    "scopeSpans": [{
      "scope": {
        "name": "nuxtops.validation.attributes",
        "version": "1.0.0"
      },
      "spans": [{
        "traceId": "${trace_id}",
        "spanId": "${span_id}",
        "name": "validation.attributes.test",
        "kind": 2,
        "startTimeUnixNano": "${timestamp}",
        "endTimeUnixNano": "$((timestamp + 500000000))",
        "attributes": [{
          "key": "http.method",
          "value": {"stringValue": "POST"}
        }, {
          "key": "http.url",
          "value": {"stringValue": "http://localhost:3000/api/test"}
        }, {
          "key": "http.status_code",
          "value": {"intValue": "200"}
        }, {
          "key": "http.user_agent",
          "value": {"stringValue": "NuxtOps-Validator/1.0"}
        }, {
          "key": "custom.validation.id",
          "value": {"stringValue": "${VALIDATION_ID}"}
        }],
        "events": [{
          "timeUnixNano": "$((timestamp + 100000000))",
          "name": "validation.checkpoint",
          "attributes": [{
            "key": "checkpoint.name",
            "value": {"stringValue": "attributes_test"}
          }]
        }],
        "status": {
          "code": 1,
          "message": "OK"
        }
      }]
    }]
  }]
}
EOF
)
    
    curl -s -X POST "${OTEL_COLLECTOR_HTTP}/v1/traces" \
        -H "Content-Type: application/json" \
        -d "$otlp_payload" &>/dev/null
    
    echo "$trace_id"
}

# Test resource detection
test_resource_detection() {
    echo -e "${CYAN}Testing resource detection...${NC}"
    
    local test_result="passed"
    local details=()
    
    # Check if collector is detecting resources
    local collector_metrics=$(curl -s "${OTEL_COLLECTOR_METRICS}/metrics" 2>/dev/null || echo "")
    
    if [[ -n "$collector_metrics" ]]; then
        # Check for resource attributes in exported metrics
        local resources=(
            "host.name"
            "os.type"
            "process.runtime.name"
            "process.runtime.version"
        )
        
        for resource in "${resources[@]}"; do
            if echo "$collector_metrics" | grep -q "$resource"; then
                details+=("Resource ${resource}: Detected")
            else
                test_result="degraded"
                details+=("Resource ${resource}: Not detected")
            fi
        done
    else
        test_result="failed"
        details+=("Unable to check resource detection")
    fi
    
    save_test_result "resource_detection" "$test_result" "${details[@]}"
    
    [[ "$test_result" == "passed" || "$test_result" == "degraded" ]]
}

# Test sampling
test_sampling() {
    echo -e "${CYAN}Testing trace sampling...${NC}"
    
    local test_result="passed"
    local details=()
    
    # Generate multiple traces with different sampling decisions
    local sampled_traces=0
    local total_traces=10
    
    for i in $(seq 1 $total_traces); do
        local trace_id=$(printf '%032x' $RANDOM$RANDOM$RANDOM$RANDOM)
        local span_id=$(printf '%016x' $RANDOM$RANDOM)
        local sampled=$((i % 2))  # 50% sampling
        
        # Send trace with sampling decision
        local timestamp=$(date +%s%N)
        local otlp_payload=$(cat <<EOF
{
  "resourceSpans": [{
    "resource": {
      "attributes": [{
        "key": "service.name",
        "value": {"stringValue": "${TEST_SERVICE_NAME}-sampling"}
      }]
    },
    "scopeSpans": [{
      "spans": [{
        "traceId": "${trace_id}",
        "spanId": "${span_id}",
        "name": "sampling.test.${i}",
        "startTimeUnixNano": "${timestamp}",
        "endTimeUnixNano": "$((timestamp + 100000000))",
        "flags": $((sampled * 1))
      }]
    }]
  }]
}
EOF
)
        
        curl -s -X POST "${OTEL_COLLECTOR_HTTP}/v1/traces" \
            -H "Content-Type: application/json" \
            -d "$otlp_payload" &>/dev/null
        
        if [[ $sampled -eq 1 ]]; then
            ((sampled_traces++))
        fi
    done
    
    sleep 5
    
    # Check how many traces were actually stored
    local stored_traces=$(curl -s "${JAEGER_ENDPOINT}/api/traces?service=${TEST_SERVICE_NAME}-sampling&limit=100" 2>/dev/null | \
        jq '.data | length' 2>/dev/null || echo "0")
    
    details+=("Traces sent: ${total_traces}")
    details+=("Expected sampled: ${sampled_traces}")
    details+=("Actually stored: ${stored_traces}")
    
    # Allow some variance
    if [[ $stored_traces -ge $((sampled_traces - 2)) && $stored_traces -le $((sampled_traces + 2)) ]]; then
        details+=("Sampling working correctly: Yes")
    else
        test_result="degraded"
        details+=("Sampling working correctly: No (unexpected count)")
    fi
    
    save_test_result "sampling" "$test_result" "${details[@]}"
    
    [[ "$test_result" == "passed" || "$test_result" == "degraded" ]]
}

# Test performance
test_performance() {
    echo -e "${CYAN}Testing OpenTelemetry performance impact...${NC}"
    
    local test_result="passed"
    local details=()
    
    # Baseline request without tracing
    local baseline_times=()
    for i in $(seq 1 5); do
        local time=$(curl -s -o /dev/null -w "%{time_total}" "http://localhost:3000/health" 2>/dev/null || echo "0")
        baseline_times+=($time)
    done
    
    # Calculate baseline average
    local baseline_avg=$(echo "${baseline_times[@]}" | awk '{sum=0; for(i=1;i<=NF;i++)sum+=$i; print sum/NF}')
    details+=("Baseline avg response time: ${baseline_avg}s")
    
    # Requests with full tracing
    local traced_times=()
    for i in $(seq 1 5); do
        local trace_id=$(printf '%032x' $RANDOM$RANDOM$RANDOM$RANDOM)
        local span_id=$(printf '%016x' $RANDOM$RANDOM)
        local time=$(curl -s -o /dev/null -w "%{time_total}" \
            -H "traceparent: 00-${trace_id}-${span_id}-01" \
            "http://localhost:3000/health" 2>/dev/null || echo "0")
        traced_times+=($time)
    done
    
    # Calculate traced average
    local traced_avg=$(echo "${traced_times[@]}" | awk '{sum=0; for(i=1;i<=NF;i++)sum+=$i; print sum/NF}')
    details+=("Traced avg response time: ${traced_avg}s")
    
    # Calculate overhead
    local overhead=$(echo "scale=2; (($traced_avg - $baseline_avg) / $baseline_avg) * 100" | bc)
    details+=("Performance overhead: ${overhead}%")
    
    # Check if overhead is acceptable (< 10%)
    if (( $(echo "$overhead < 10" | bc -l) )); then
        details+=("Overhead acceptable: Yes")
    else
        test_result="degraded"
        details+=("Overhead acceptable: No (> 10%)")
    fi
    
    # Check collector resource usage
    if command -v docker &>/dev/null; then
        local collector_stats=$(docker stats --no-stream --format "json" otel-collector 2>/dev/null || echo "{}")
        
        if [[ "$collector_stats" != "{}" ]]; then
            local cpu=$(echo "$collector_stats" | jq -r '.CPUPerc' | tr -d '%')
            local mem=$(echo "$collector_stats" | jq -r '.MemUsage' | awk '{print $1}')
            details+=("Collector CPU usage: ${cpu}%")
            details+=("Collector memory usage: ${mem}")
        fi
    fi
    
    save_test_result "performance" "$test_result" "${details[@]}"
    
    [[ "$test_result" == "passed" || "$test_result" == "degraded" ]]
}

# Save test result
save_test_result() {
    local test_name="$1"
    local result="$2"
    shift 2
    local details=("$@")
    
    # Create test result entry
    local test_entry=$(jq -n \
        --arg name "$test_name" \
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
    jq ".tests += [$test_entry]" "$REPORT_FILE" > "${REPORT_FILE}.tmp" && mv "${REPORT_FILE}.tmp" "$REPORT_FILE"
    
    # Display result
    if [[ "$result" == "passed" ]]; then
        echo -e "${GREEN}✓ ${test_name}: ${result}${NC}"
    elif [[ "$result" == "degraded" ]]; then
        echo -e "${YELLOW}⚠ ${test_name}: ${result}${NC}"
    elif [[ "$result" == "skipped" ]]; then
        echo -e "${BLUE}○ ${test_name}: ${result}${NC}"
    else
        echo -e "${RED}✗ ${test_name}: ${result}${NC}"
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
    # Update report with summary
    local total_tests=$(jq '.tests | length' "$REPORT_FILE")
    local passed_tests=$(jq '[.tests[] | select(.result == "passed")] | length' "$REPORT_FILE")
    local degraded_tests=$(jq '[.tests[] | select(.result == "degraded")] | length' "$REPORT_FILE")
    local failed_tests=$(jq '[.tests[] | select(.result == "failed")] | length' "$REPORT_FILE")
    local skipped_tests=$(jq '[.tests[] | select(.result == "skipped")] | length' "$REPORT_FILE")
    
    # Determine overall result
    local overall_result="passed"
    if [[ $failed_tests -gt 0 ]]; then
        overall_result="failed"
    elif [[ $degraded_tests -gt 0 ]]; then
        overall_result="degraded"
    fi
    
    # Add summary to report
    jq \
        --arg end_time "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --arg overall "$overall_result" \
        --argjson total "$total_tests" \
        --argjson passed "$passed_tests" \
        --argjson degraded "$degraded_tests" \
        --argjson failed "$failed_tests" \
        --argjson skipped "$skipped_tests" \
        '. + {
            end_time: $end_time,
            summary: {
                overall_result: $overall,
                total_tests: $total,
                passed: $passed,
                degraded: $degraded,
                failed: $failed,
                skipped: $skipped
            }
        }' "$REPORT_FILE" > "${REPORT_FILE}.tmp" && mv "${REPORT_FILE}.tmp" "$REPORT_FILE"
    
    # Display summary
    echo
    echo -e "${MAGENTA}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║         OpenTelemetry E2E Validation Summary                   ║${NC}"
    echo -e "${MAGENTA}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${CYAN}Overall Result:${NC} $(format_result "$overall_result")"
    echo -e "${CYAN}Total Tests:${NC} $total_tests"
    echo -e "${GREEN}Passed:${NC} $passed_tests"
    echo -e "${YELLOW}Degraded:${NC} $degraded_tests"
    echo -e "${RED}Failed:${NC} $failed_tests"
    echo -e "${BLUE}Skipped:${NC} $skipped_tests"
    echo
    echo -e "${CYAN}Full report:${NC} $REPORT_FILE"
    echo -e "${CYAN}Trace output:${NC} $TRACE_OUTPUT"
    
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

# Main function
main() {
    local environment="${1:-development}"
    local verbose="${2:-}"
    
    # Set verbosity
    VERBOSE="false"
    if [[ "$verbose" == "--verbose" || "$verbose" == "-v" ]]; then
        VERBOSE="true"
    fi
    
    # Initialize validation
    init_validation
    
    # Run validation tests
    local failed=0
    
    for test in "${VALIDATION_TESTS[@]}"; do
        case "$test" in
            "collector_connectivity")
                test_collector_connectivity || ((failed++))
                ;;
            "trace_generation")
                test_trace_generation || ((failed++))
                ;;
            "trace_propagation")
                test_trace_propagation || ((failed++))
                ;;
            "metrics_export")
                test_metrics_export || ((failed++))
                ;;
            "logs_correlation")
                test_logs_correlation || ((failed++))
                ;;
            "service_map")
                test_service_map || ((failed++))
                ;;
            "span_attributes")
                test_span_attributes || ((failed++))
                ;;
            "resource_detection")
                test_resource_detection || ((failed++))
                ;;
            "sampling")
                test_sampling || ((failed++))
                ;;
            "performance")
                test_performance || ((failed++))
                ;;
        esac
        
        echo  # Add spacing between tests
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
    --verbose, -v  - Show detailed test output
    --help         - Show this help message

Examples:
    $0                     # Validate development environment
    $0 production          # Validate production environment
    $0 staging --verbose   # Detailed validation for staging

This script performs comprehensive end-to-end validation of OpenTelemetry
implementation including:
- Collector connectivity
- Trace generation and propagation
- Metrics export
- Logs correlation
- Service discovery
- Performance impact

EOF
}

# Parse arguments
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    usage
    exit 0
fi

# Execute main function
main "$@"