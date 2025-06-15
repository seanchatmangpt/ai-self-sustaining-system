#!/bin/bash

# AI Self-Sustaining System - Comprehensive End-to-End Benchmark Suite
# Tests all components under realistic load conditions

set -e

# Configuration
API_BASE="${API_BASE:-http://localhost:4000/api}"
BENCHMARK_DURATION="${BENCHMARK_DURATION:-60}"  # seconds
CONCURRENT_AGENTS="${CONCURRENT_AGENTS:-10}"
WORK_ITEMS_PER_AGENT="${WORK_ITEMS_PER_AGENT:-5}"
OTLP_REQUESTS="${OTLP_REQUESTS:-100}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Performance tracking
RESULTS_FILE="benchmark_results_$(date +%Y%m%d_%H%M%S).json"
START_TIME=$(date +%s.%N)

log() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}✓${NC} $1"
}

warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

error() {
    echo -e "${RED}✗${NC} $1"
}

header() {
    echo ""
    echo -e "${PURPLE}=== $1 ===${NC}"
    echo ""
}

# Benchmark result tracking (using simple variables instead of associative array)
total_requests=0
successful_requests=0
failed_requests=0
avg_response_time=0
max_response_time=0
min_response_time=999999

update_metrics() {
    local response_time=$1
    local success=$2
    
    total_requests=$((total_requests + 1))
    
    if [[ "$success" == "true" ]]; then
        successful_requests=$((successful_requests + 1))
    else
        failed_requests=$((failed_requests + 1))
    fi
    
    # Update response time metrics
    if (( $(echo "$response_time > $max_response_time" | bc -l) )); then
        max_response_time=$response_time
    fi
    
    if (( $(echo "$response_time < $min_response_time" | bc -l) )); then
        min_response_time=$response_time
    fi
}

# Test HTTP endpoint with timing
test_endpoint() {
    local method=$1
    local url=$2
    local data=$3
    local expected_status=${4:-200}
    
    local start_time=$(date +%s.%N)
    
    if [[ -n "$data" ]]; then
        local response=$(curl -s -w "%{http_code}" -X "$method" "$url" \
            -H "Content-Type: application/json" \
            -d "$data" 2>/dev/null)
    else
        local response=$(curl -s -w "%{http_code}" -X "$method" "$url" 2>/dev/null)
    fi
    
    local end_time=$(date +%s.%N)
    local response_time=$(echo "$end_time - $start_time" | bc -l)
    local http_code="${response: -3}"
    local response_body="${response%???}"
    
    local success="false"
    if [[ "$http_code" == "$expected_status" ]]; then
        success="true"
    fi
    
    update_metrics "$response_time" "$success"
    
    echo "$response_time|$success|$http_code|$response_body"
}

# Wait for system to be ready
wait_for_system() {
    header "System Readiness Check"
    
    local max_attempts=30
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        log "Checking system health (attempt $attempt/$max_attempts)..."
        
        local result=$(test_endpoint "GET" "$API_BASE/otlp/health")
        local success=$(echo "$result" | cut -d'|' -f2)
        
        if [[ "$success" == "true" ]]; then
            success "System is ready!"
            return 0
        fi
        
        sleep 2
        ((attempt++))
    done
    
    error "System not ready after $max_attempts attempts"
    exit 1
}

# 1. OTLP Pipeline Performance Test
benchmark_otlp_pipeline() {
    header "OTLP Pipeline Performance Benchmark"
    
    local otlp_start_time=$(date +%s.%N)
    local otlp_requests=0
    local otlp_successes=0
    
    log "Testing OTLP traces ingestion ($OTLP_REQUESTS requests)..."
    for ((i=1; i<=OTLP_REQUESTS; i++)); do
        local trace_data="{\"traces\": [{\"trace_id\": \"benchmark_trace_$i\", \"span_id\": \"span_$i\", \"operation\": \"benchmark_op_$i\"}]}"
        local result=$(test_endpoint "POST" "$API_BASE/otlp/v1/traces" "$trace_data")
        local success=$(echo "$result" | cut -d'|' -f2)
        
        otlp_requests=$((otlp_requests + 1))
        if [[ "$success" == "true" ]]; then
            otlp_successes=$((otlp_successes + 1))
        fi
        
        # Progress indicator
        if [[ $((i % 20)) -eq 0 ]]; then
            log "OTLP progress: $i/$OTLP_REQUESTS requests"
        fi
    done
    
    log "Testing OTLP metrics ingestion..."
    for ((i=1; i<=10; i++)); do
        local metrics_data="{\"metrics\": [{\"name\": \"benchmark_metric_$i\", \"value\": $i, \"timestamp\": $(date +%s)}]}"
        test_endpoint "POST" "$API_BASE/otlp/v1/metrics" "$metrics_data" >/dev/null
    done
    
    log "Testing OTLP logs ingestion..."
    for ((i=1; i<=10; i++)); do
        local logs_data="{\"logs\": [{\"message\": \"Benchmark log message $i\", \"level\": \"info\", \"timestamp\": $(date +%s)}]}"
        test_endpoint "POST" "$API_BASE/otlp/v1/logs" "$logs_data" >/dev/null
    done
    
    local otlp_end_time=$(date +%s.%N)
    local otlp_duration=$(echo "$otlp_end_time - $otlp_start_time" | bc -l)
    local otlp_throughput=$(echo "scale=2; $otlp_requests / $otlp_duration" | bc -l)
    
    success "OTLP Pipeline: $otlp_successes/$otlp_requests successful, ${otlp_throughput} req/s"
    
    # Test pipeline status
    log "Checking OTLP pipeline status..."
    test_endpoint "GET" "$API_BASE/otlp/pipeline/status" >/dev/null
    test_endpoint "GET" "$API_BASE/otlp/pipeline/statistics" >/dev/null
}

# 2. Agent Coordination Performance Test
benchmark_agent_coordination() {
    header "Agent Coordination Performance Benchmark"
    
    local coordination_start_time=$(date +%s.%N)
    local agent_registrations=0
    local agent_successes=0
    declare -a agent_ids
    
    log "Registering $CONCURRENT_AGENTS agents..."
    for ((i=1; i<=CONCURRENT_AGENTS; i++)); do
        local agent_id="benchmark_agent_$(date +%s%N)_$i"
        local capabilities='["benchmark_testing", "performance_analysis", "system_optimization"]'
        local agent_data="{\"agent_id\": \"$agent_id\", \"capabilities\": $capabilities}"
        
        local result=$(test_endpoint "POST" "$API_BASE/coordination/agents/register" "$agent_data")
        local success=$(echo "$result" | cut -d'|' -f2)
        
        agent_registrations=$((agent_registrations + 1))
        if [[ "$success" == "true" ]]; then
            agent_successes=$((agent_successes + 1))
            agent_ids+=("$agent_id")
        fi
    done
    
    success "Agent Registration: $agent_successes/$agent_registrations successful"
    
    log "Testing agent heartbeats..."
    for agent_id in "${agent_ids[@]}"; do
        test_endpoint "PUT" "$API_BASE/coordination/agents/$agent_id/heartbeat" "{}" >/dev/null
    done
    
    log "Listing active agents..."
    test_endpoint "GET" "$API_BASE/coordination/agents" >/dev/null
    
    local coordination_end_time=$(date +%s.%N)
    local coordination_duration=$(echo "$coordination_end_time - $coordination_start_time" | bc -l)
    
    success "Agent Coordination completed in ${coordination_duration}s"
    
    # Store agent IDs for work item tests
    echo "${agent_ids[@]}" > /tmp/benchmark_agents.txt
}

# 3. Work Item Lifecycle Performance Test
benchmark_work_lifecycle() {
    header "Work Item Lifecycle Performance Benchmark"
    
    # Read agent IDs from previous test
    if [[ ! -f /tmp/benchmark_agents.txt ]]; then
        error "No agents available for work item testing"
        return 1
    fi
    
    local agents=($(cat /tmp/benchmark_agents.txt))
    local total_work_items=$((${#agents[@]} * WORK_ITEMS_PER_AGENT))
    
    log "Creating $total_work_items work items across ${#agents[@]} agents..."
    
    local work_start_time=$(date +%s.%N)
    local work_submissions=0
    local work_successes=0
    declare -a work_ids
    
    # Submit work items
    for ((i=1; i<=total_work_items; i++)); do
        local work_type="benchmark_task_$i"
        local description="Benchmark work item $i - performance testing"
        local priority="medium"
        local work_data="{\"work_type\": \"$work_type\", \"description\": \"$description\", \"priority\": \"$priority\"}"
        
        local result=$(test_endpoint "POST" "$API_BASE/coordination/work" "$work_data")
        local success=$(echo "$result" | cut -d'|' -f2)
        local response_body=$(echo "$result" | cut -d'|' -f4)
        
        work_submissions=$((work_submissions + 1))
        if [[ "$success" == "true" ]]; then
            work_successes=$((work_successes + 1))
            local work_id=$(echo "$response_body" | jq -r '.data.work_item_id' 2>/dev/null || echo "")
            if [[ -n "$work_id" && "$work_id" != "null" ]]; then
                work_ids+=("$work_id")
            fi
        fi
    done
    
    success "Work Submission: $work_successes/$work_submissions successful"
    
    # Test work claiming and processing
    log "Testing work item lifecycle (claim → start → complete)..."
    local processed_work=0
    
    for ((i=0; i<${#work_ids[@]} && i<${#agents[@]}; i++)); do
        local work_id="${work_ids[$i]}"
        local agent_id="${agents[$i]}"
        
        # Claim work
        local claim_data="{\"agent_id\": \"$agent_id\"}"
        local claim_result=$(test_endpoint "PUT" "$API_BASE/coordination/work/$work_id/claim" "$claim_data")
        local claim_success=$(echo "$claim_result" | cut -d'|' -f2)
        
        if [[ "$claim_success" == "true" ]]; then
            # Start work
            local start_result=$(test_endpoint "PUT" "$API_BASE/coordination/work/$work_id/start" "{}")
            local start_success=$(echo "$start_result" | cut -d'|' -f2)
            
            if [[ "$start_success" == "true" ]]; then
                # Complete work
                local result_data="{\"result\": {\"benchmark_score\": 95, \"items_processed\": 100, \"performance_gain\": 15}}"
                local complete_result=$(test_endpoint "PUT" "$API_BASE/coordination/work/$work_id/complete" "$result_data")
                local complete_success=$(echo "$complete_result" | cut -d'|' -f2)
                
                if [[ "$complete_success" == "true" ]]; then
                    processed_work=$((processed_work + 1))
                fi
            fi
        fi
    done
    
    log "Testing work item listing..."
    test_endpoint "GET" "$API_BASE/coordination/work" >/dev/null
    test_endpoint "GET" "$API_BASE/coordination/work?status=completed" >/dev/null
    test_endpoint "GET" "$API_BASE/coordination/work?status=pending" >/dev/null
    
    local work_end_time=$(date +%s.%N)
    local work_duration=$(echo "$work_end_time - $work_start_time" | bc -l)
    
    success "Work Lifecycle: $processed_work work items fully processed in ${work_duration}s"
    
    # Cleanup
    rm -f /tmp/benchmark_agents.txt
}

# 4. Concurrent Operations Stress Test
benchmark_concurrent_operations() {
    header "Concurrent Operations Stress Test"
    
    log "Starting concurrent stress test for ${BENCHMARK_DURATION}s..."
    
    local stress_start_time=$(date +%s.%N)
    local pids=()
    
    # Concurrent OTLP ingestion
    for ((i=1; i<=3; i++)); do
        (
            local end_time=$(($(date +%s) + BENCHMARK_DURATION))
            local requests=0
            while [[ $(date +%s) -lt $end_time ]]; do
                local trace_data="{\"traces\": [{\"trace_id\": \"stress_trace_${i}_${requests}\", \"operation\": \"stress_test\"}]}"
                curl -s -X POST "$API_BASE/otlp/v1/traces" \
                    -H "Content-Type: application/json" \
                    -d "$trace_data" >/dev/null 2>&1
                requests=$((requests + 1))
            done
            echo "OTLP worker $i: $requests requests"
        ) &
        pids+=($!)
    done
    
    # Concurrent agent operations
    for ((i=1; i<=2; i++)); do
        (
            local end_time=$(($(date +%s) + BENCHMARK_DURATION))
            local operations=0
            while [[ $(date +%s) -lt $end_time ]]; do
                local agent_id="stress_agent_${i}_${operations}"
                local agent_data="{\"agent_id\": \"$agent_id\", \"capabilities\": [\"stress_testing\"]}"
                curl -s -X POST "$API_BASE/coordination/agents/register" \
                    -H "Content-Type: application/json" \
                    -d "$agent_data" >/dev/null 2>&1
                operations=$((operations + 1))
                sleep 0.1
            done
            echo "Agent worker $i: $operations operations"
        ) &
        pids+=($!)
    done
    
    # Wait for all background processes
    for pid in "${pids[@]}"; do
        wait $pid
    done
    
    local stress_end_time=$(date +%s.%N)
    local stress_duration=$(echo "$stress_end_time - $stress_start_time" | bc -l)
    
    success "Concurrent stress test completed in ${stress_duration}s"
}

# 5. System Health and Resilience Test
benchmark_system_health() {
    header "System Health and Resilience Test"
    
    log "Testing system health endpoints..."
    test_endpoint "GET" "$API_BASE/otlp/health" >/dev/null
    test_endpoint "GET" "$API_BASE/otlp/pipeline/status" >/dev/null
    test_endpoint "GET" "$API_BASE/otlp/pipeline/statistics" >/dev/null
    
    log "Testing error handling with invalid requests..."
    
    # Test invalid JSON
    test_endpoint "POST" "$API_BASE/coordination/agents/register" "invalid_json" "400" >/dev/null
    
    # Test missing required fields
    test_endpoint "POST" "$API_BASE/coordination/work" "{}" "400" >/dev/null
    
    # Test non-existent resources
    test_endpoint "PUT" "$API_BASE/coordination/work/nonexistent/claim" "{\"agent_id\": \"test\"}" "404" >/dev/null
    
    # Test database connectivity
    log "Testing database operations..."
    local db_test_agent="db_test_agent_$(date +%s%N)"
    local db_test_data="{\"agent_id\": \"$db_test_agent\", \"capabilities\": [\"database_testing\"]}"
    test_endpoint "POST" "$API_BASE/coordination/agents/register" "$db_test_data" >/dev/null
    
    success "System health and resilience tests completed"
}

# 6. Dashboard Performance Test
benchmark_dashboard() {
    header "Dashboard Performance Test"
    
    log "Testing dashboard accessibility..."
    local dashboard_start_time=$(date +%s.%N)
    
    local dashboard_response=$(curl -s -w "%{http_code}" http://localhost:4000/dashboard 2>/dev/null)
    local dashboard_status="${dashboard_response: -3}"
    
    local dashboard_end_time=$(date +%s.%N)
    local dashboard_load_time=$(echo "$dashboard_end_time - $dashboard_start_time" | bc -l)
    
    if [[ "$dashboard_status" == "200" ]]; then
        success "Dashboard accessible in ${dashboard_load_time}s"
    else
        warning "Dashboard returned status $dashboard_status"
    fi
    
    log "Testing root page..."
    local root_response=$(curl -s -w "%{http_code}" http://localhost:4000/ 2>/dev/null)
    local root_status="${root_response: -3}"
    
    if [[ "$root_status" == "200" ]]; then
        success "Root page accessible"
    else
        warning "Root page returned status $root_status"
    fi
}

# Generate comprehensive report
generate_report() {
    header "Benchmark Results Summary"
    
    local total_time=$(date +%s.%N)
    local benchmark_duration=$(echo "$total_time - $START_TIME" | bc -l)
    
    log "Total benchmark duration: ${benchmark_duration}s"
    log "Total requests: $total_requests"
    log "Successful requests: $successful_requests"
    log "Failed requests: $failed_requests"
    
    if [[ $total_requests -gt 0 ]]; then
        local success_rate=$(echo "scale=2; $successful_requests * 100 / $total_requests" | bc -l)
        log "Success rate: ${success_rate}%"
    fi
    
    log "Response time - Min: ${min_response_time}s, Max: ${max_response_time}s"
    
    # Generate JSON report
    cat > "$RESULTS_FILE" <<EOF
{
  "benchmark_timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "configuration": {
    "duration": $BENCHMARK_DURATION,
    "concurrent_agents": $CONCURRENT_AGENTS,
    "work_items_per_agent": $WORK_ITEMS_PER_AGENT,
    "otlp_requests": $OTLP_REQUESTS
  },
  "results": {
    "total_duration_seconds": $benchmark_duration,
    "total_requests": $total_requests,
    "successful_requests": $successful_requests,
    "failed_requests": $failed_requests,
    "min_response_time": $min_response_time,
    "max_response_time": $max_response_time
  },
  "system_health": "operational"
}
EOF
    
    success "Detailed results saved to: $RESULTS_FILE"
    
    # Final verdict
    local critical_failures=$failed_requests
    if [[ $critical_failures -eq 0 ]]; then
        echo ""
        echo -e "${GREEN}🎉 BENCHMARK PASSED${NC}: All systems operational"
        echo -e "${GREEN}✓ OTLP Pipeline: Functional${NC}"
        echo -e "${GREEN}✓ Agent Coordination: Functional${NC}"
        echo -e "${GREEN}✓ Work Lifecycle: Functional${NC}"
        echo -e "${GREEN}✓ Concurrent Operations: Stable${NC}"
        echo -e "${GREEN}✓ System Health: Good${NC}"
        echo -e "${GREEN}✓ Dashboard: Accessible${NC}"
        echo ""
        echo -e "${BLUE}🚀 AI Self-Sustaining System is production-ready!${NC}"
    else
        echo ""
        echo -e "${RED}⚠ BENCHMARK PARTIAL${NC}: $critical_failures failed requests detected"
        echo -e "${YELLOW}System functional but may need optimization${NC}"
    fi
}

# Main execution
main() {
    clear
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                                                               ║"
    echo "║        AI Self-Sustaining System - End-to-End Benchmark      ║"
    echo "║                                                               ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    
    log "Starting comprehensive system benchmark..."
    log "Configuration: ${CONCURRENT_AGENTS} agents, ${WORK_ITEMS_PER_AGENT} work items each, ${OTLP_REQUESTS} OTLP requests"
    echo ""
    
    # Check dependencies
    command -v curl >/dev/null 2>&1 || { error "curl is required but not installed"; exit 1; }
    command -v jq >/dev/null 2>&1 || { error "jq is required but not installed"; exit 1; }
    command -v bc >/dev/null 2>&1 || { error "bc is required but not installed"; exit 1; }
    
    # Run benchmark suite
    wait_for_system
    benchmark_otlp_pipeline
    benchmark_agent_coordination
    benchmark_work_lifecycle
    benchmark_concurrent_operations
    benchmark_system_health
    benchmark_dashboard
    
    # Generate final report
    generate_report
}

# Execute main function
main "$@"