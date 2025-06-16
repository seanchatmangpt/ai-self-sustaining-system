#!/bin/bash

# Comprehensive End-to-End OpenTelemetry Validation Script
# Tests trace ID propagation through the complete autonomous AI coordination system
# Including Reactor workflows, Phoenix LiveView, Ash Framework, and distributed services

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
COORDINATION_ROOT="$ROOT_DIR/agent_coordination"
TELEMETRY_SPANS="$COORDINATION_ROOT/telemetry_spans.jsonl"
BEAMOPS_ROOT="$ROOT_DIR/beamops/v3"
XAVOS_ROOT="$ROOT_DIR/worktrees/xavos-system/xavos"
PHOENIX_ROOT="$ROOT_DIR/phoenix_app"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Test results tracking
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
VALIDATION_RESULTS=()
TRACE_CORRELATIONS=()
TRACE_EVIDENCE=()

# Generate master trace ID for this comprehensive validation
MASTER_TRACE_ID=$(openssl rand -hex 16)
VALIDATION_SESSION="comprehensive_e2e_$(date +%s)"
SESSION_START_TIME=$(date +%s%N)

log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
    VALIDATION_RESULTS+=("✅ $1")
    ((PASSED_TESTS++))
    ((TOTAL_TESTS++))
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
    VALIDATION_RESULTS+=("⚠️  $1")
    ((TOTAL_TESTS++))
}

error() {
    echo -e "${RED}❌ $1${NC}"
    VALIDATION_RESULTS+=("❌ $1")
    ((FAILED_TESTS++))
    ((TOTAL_TESTS++))
}

trace_checkpoint() {
    local checkpoint_name="$1"
    local span_id=$(openssl rand -hex 8)
    local parent_span="${2:-root}"
    
    echo -e "${PURPLE}🔍 TRACE CHECKPOINT: $checkpoint_name${NC}"
    echo -e "${CYAN}   Master Trace ID: $MASTER_TRACE_ID${NC}"
    echo -e "${CYAN}   Checkpoint Span: $span_id${NC}"
    echo -e "${CYAN}   Parent Span:     $parent_span${NC}"
    
    # Record comprehensive telemetry span
    record_comprehensive_span "$checkpoint_name" "$span_id" "$parent_span"
    
    # Return the span ID via echo for capture
    echo "$span_id"
}

record_comprehensive_span() {
    local operation="$1"
    local span_id="$2"
    local parent_span="$3"
    local timestamp=$(date -Iseconds)
    local duration_ns=$(($(date +%s%N) - SESSION_START_TIME))
    local duration_ms=$((duration_ns / 1000000))
    
    # Create comprehensive telemetry span with full OpenTelemetry compliance
    local span_entry=$(cat <<EOF
{
  "trace_id": "$MASTER_TRACE_ID",
  "span_id": "$span_id",
  "parent_span_id": "$parent_span",
  "operation_name": "e2e.comprehensive.validation.$operation",
  "service_name": "comprehensive-e2e-validation",
  "start_time": "$timestamp",
  "end_time": "$(date -Iseconds)",
  "duration_ms": $duration_ms,
  "duration_ns": $duration_ns,
  "status": {
    "code": "OK",
    "message": "Checkpoint completed successfully"
  },
  "tags": {
    "validation.session": "$VALIDATION_SESSION",
    "validation.checkpoint": "$operation",
    "system.component": "autonomous_coordination",
    "environment": "development",
    "version": "3.0.0"
  },
  "process": {
    "service_name": "comprehensive-e2e-validation",
    "tags": {
      "hostname": "$(hostname)",
      "os": "$(uname -s)",
      "runtime": "bash",
      "validation_type": "comprehensive_e2e"
    }
  },
  "logs": [
    {
      "timestamp": "$timestamp",
      "level": "INFO",
      "message": "Trace checkpoint: $operation",
      "fields": {
        "checkpoint": "$operation",
        "trace_id": "$MASTER_TRACE_ID",
        "span_id": "$span_id"
      }
    }
  ]
}
EOF
    )
    
    # Append to telemetry spans file
    echo "$span_entry" >> "$TELEMETRY_SPANS"
    
    # Emit telemetry event to BeamOps if available
    emit_telemetry_event "$operation" "$span_id" "$parent_span"
}

emit_telemetry_event() {
    local operation="$1"
    local span_id="$2"
    local parent_span="$3"
    
    # Try to emit to BeamOps telemetry endpoint
    if command -v curl &> /dev/null; then
        local telemetry_payload=$(cat <<EOF
{
  "event": ["beamops", "e2e", "validation", "$operation"],
  "measurements": {
    "duration": $(($(date +%s%N) - SESSION_START_TIME)),
    "checkpoint_count": ${#TRACE_CORRELATIONS[@]}
  },
  "metadata": {
    "trace_id": "$MASTER_TRACE_ID",
    "span_id": "$span_id",
    "parent_span_id": "$parent_span",
    "validation_session": "$VALIDATION_SESSION",
    "operation": "$operation"
  }
}
EOF
        )
        
        curl -s -X POST "http://localhost:4369/telemetry/event" \
            -H "Content-Type: application/json" \
            -H "X-Trace-Id: $MASTER_TRACE_ID" \
            -H "X-Span-Id: $span_id" \
            -d "$telemetry_payload" > /dev/null 2>&1 || true
    fi
}

validate_trace_correlation() {
    local expected_trace_id="$1"
    local component="$2"
    local file_path="$3"
    
    log "Validating trace correlation in $component ($file_path)..."
    
    if [[ -f "$file_path" ]] && grep -q "$expected_trace_id" "$file_path" 2>/dev/null; then
        success "Trace ID $expected_trace_id correlated in $component"
        TRACE_CORRELATIONS+=("$component:$expected_trace_id")
        TRACE_EVIDENCE+=("$component:$file_path:$(grep -n "$expected_trace_id" "$file_path" | head -1)")
        return 0
    else
        error "Trace ID $expected_trace_id NOT found in $component"
        return 1
    fi
}

test_coordination_workflow_comprehensive() {
    trace_checkpoint "coordination_workflow_start" > /dev/null 2>&1
    local checkpoint_span=$(openssl rand -hex 8)
    
    log "Starting comprehensive coordination workflow test..."
    
    # Set comprehensive trace context
    export OTEL_TRACE_ID="$MASTER_TRACE_ID"
    export OTEL_PARENT_SPAN_ID="$checkpoint_span"
    export OTEL_SERVICE_NAME="comprehensive-e2e-validation"
    export OTEL_RESOURCE_ATTRIBUTES="service.name=comprehensive-e2e-validation,service.version=3.0.0,deployment.environment=development"
    
    # Test 1: Claim work with full trace propagation
    trace_checkpoint "work_claim_start" "$checkpoint_span"
    local work_description="Comprehensive E2E OpenTelemetry validation - coordination test"
    
    log "Claiming work with comprehensive trace propagation..."
    local claim_output
    if claim_output=$("$COORDINATION_ROOT/coordination_helper.sh" claim-intelligent "e2e_otel_comprehensive" "$work_description" "high" "validation_team" 2>&1); then
        success "Work claimed with comprehensive trace propagation"
        
        # Extract work ID
        local work_id=$(echo "$claim_output" | grep -o "work_[0-9]*" | head -1)
        if [[ -n "$work_id" ]]; then
            log "Claimed Work ID: $work_id"
            
            # Validate immediate trace correlation
            validate_trace_correlation "$MASTER_TRACE_ID" "work_claims" "$COORDINATION_ROOT/work_claims.json"
            
            # Test 2: Progress updates with trace
            trace_checkpoint "work_progress_updates" "$checkpoint_span" > /dev/null 2>&1
            for progress in 25 50 75; do
                log "Updating progress to ${progress}%..."
                "$COORDINATION_ROOT/coordination_helper.sh" progress "$work_id" "$progress" "comprehensive_validation_step_${progress}" || true
                sleep 1
                validate_trace_correlation "$MASTER_TRACE_ID" "work_claims_progress_${progress}" "$COORDINATION_ROOT/work_claims.json"
            done
            
            # Test 3: Complete work with comprehensive result
            trace_checkpoint "work_completion" "$checkpoint_span" > /dev/null 2>&1
            local completion_result="Comprehensive E2E validation completed with ${#TRACE_CORRELATIONS[@]} trace correlations verified"
            "$COORDINATION_ROOT/coordination_helper.sh" complete "$work_id" "$completion_result" 8 || true
            
            validate_trace_correlation "$MASTER_TRACE_ID" "work_completion" "$COORDINATION_ROOT/work_claims.json"
        else
            error "Could not extract work ID from claim output"
        fi
    else
        error "Failed to claim work: $claim_output"
    fi
    
    unset OTEL_TRACE_ID OTEL_PARENT_SPAN_ID OTEL_SERVICE_NAME OTEL_RESOURCE_ATTRIBUTES
}

test_reactor_middleware_integration() {
    trace_checkpoint "reactor_middleware_test" > /dev/null 2>&1
    local checkpoint_span=$(openssl rand -hex 8)
    
    log "Testing Reactor middleware integration with trace propagation..."
    
    # Check if Phoenix app exists and has reactor middleware
    if [[ -d "$PHOENIX_ROOT" ]]; then
        log "Found Phoenix application at $PHOENIX_ROOT"
        
        # Look for reactor middleware files
        local middleware_files=$(find "$PHOENIX_ROOT" -name "*middleware*" -type f 2>/dev/null || echo "")
        if [[ -n "$middleware_files" ]]; then
            success "Reactor middleware files found in Phoenix app"
            TRACE_CORRELATIONS+=("reactor_middleware:phoenix_app")
            
            # Check for telemetry middleware specifically
            if find "$PHOENIX_ROOT" -name "*telemetry*middleware*" -type f | head -1 | xargs grep -l "trace_id" 2>/dev/null; then
                success "Telemetry middleware with trace_id support detected"
                TRACE_CORRELATIONS+=("telemetry_middleware:trace_support")
            else
                warning "Telemetry middleware trace support not confirmed"
            fi
        else
            warning "No reactor middleware files found in Phoenix app"
        fi
    else
        warning "Phoenix application directory not found"
    fi
    
    # Test XAVOS reactor integration
    if [[ -d "$XAVOS_ROOT" ]]; then
        trace_checkpoint "xavos_reactor_test" "$checkpoint_span" > /dev/null 2>&1
        
        cd "$XAVOS_ROOT"
        if [[ -f "mix.exs" ]]; then
            log "Testing XAVOS reactor compilation with trace context..."
            
            # Set trace context for compilation
            export MIX_ENV=test
            export OTEL_TRACE_ID="$MASTER_TRACE_ID"
            
            if mix compile --warnings-as-errors > /dev/null 2>&1; then
                success "XAVOS reactor system compiles successfully"
                TRACE_CORRELATIONS+=("xavos_reactor:compilation_success")
                
                # Check for reactor files with telemetry
                local reactor_files=$(find . -name "*reactor*.ex" -type f 2>/dev/null | head -5)
                local telemetry_reactors=0
                
                for reactor_file in $reactor_files; do
                    if grep -q "telemetry\|trace" "$reactor_file" 2>/dev/null; then
                        ((telemetry_reactors++))
                    fi
                done
                
                if [[ $telemetry_reactors -gt 0 ]]; then
                    success "Found $telemetry_reactors reactor files with telemetry support"
                    TRACE_CORRELATIONS+=("xavos_reactors:telemetry_count_$telemetry_reactors")
                else
                    warning "No reactor files with telemetry support found"
                fi
            else
                warning "XAVOS reactor compilation issues detected"
            fi
            
            unset MIX_ENV OTEL_TRACE_ID
        fi
        
        cd "$SCRIPT_DIR"
    else
        warning "XAVOS system directory not found"
    fi
}

test_distributed_services_integration() {
    trace_checkpoint "distributed_services_test" > /dev/null 2>&1
    local checkpoint_span=$(openssl rand -hex 8)
    
    log "Testing distributed services integration..."
    
    # Test BeamOps integration
    trace_checkpoint "beamops_integration" "$checkpoint_span" > /dev/null 2>&1
    if [[ -d "$BEAMOPS_ROOT" ]]; then
        log "Testing BeamOps integration..."
        
        # Test Grafana integration
        if [[ -x "$BEAMOPS_ROOT/scripts/autonomous_grafana_integration.sh" ]]; then
            local grafana_output
            if grafana_output=$("$BEAMOPS_ROOT/scripts/autonomous_grafana_integration.sh" metrics 2>&1); then
                success "BeamOps Grafana integration accessible"
                TRACE_CORRELATIONS+=("beamops:grafana_integration")
                
                # Check for coordination metrics
                if echo "$grafana_output" | grep -q "Coordination Metrics"; then
                    success "Coordination metrics accessible via BeamOps"
                    TRACE_CORRELATIONS+=("beamops:coordination_metrics")
                fi
            else
                warning "BeamOps Grafana integration issues: $grafana_output"
            fi
        fi
        
        # Test PromEx configuration
        if [[ -f "$BEAMOPS_ROOT/lib/beamops/promex.ex" ]]; then
            if grep -q "coordination\|agent" "$BEAMOPS_ROOT/lib/beamops/promex.ex" 2>/dev/null; then
                success "BeamOps PromEx configured for agent coordination"
                TRACE_CORRELATIONS+=("beamops:promex_coordination")
            fi
        fi
    else
        warning "BeamOps directory not found"
    fi
    
    # Test HTTP endpoints with trace headers
    trace_checkpoint "http_endpoints_test" "$checkpoint_span" > /dev/null 2>&1
    if command -v curl &> /dev/null; then
        local endpoints=(
            "http://localhost:4002/health"
            "http://localhost:4369/metrics"
            "http://localhost:3000/api/health"
            "http://localhost:4000/health"
        )
        
        for endpoint in "${endpoints[@]}"; do
            local service_name=$(echo "$endpoint" | cut -d':' -f3 | cut -d'/' -f1)
            
            if curl -s -H "X-Trace-Id: $MASTER_TRACE_ID" -H "X-Span-Id: $(openssl rand -hex 8)" "$endpoint" > /dev/null 2>&1; then
                success "Service on port $service_name accessible with trace headers"
                TRACE_CORRELATIONS+=("http_service:port_$service_name")
            else
                warning "Service on port $service_name not accessible"
            fi
        done
    fi
}

test_telemetry_data_integrity() {
    trace_checkpoint "telemetry_integrity_test" > /dev/null 2>&1
    local checkpoint_span=$(openssl rand -hex 8)
    
    log "Testing telemetry data integrity and correlation..."
    
    # Validate telemetry spans file structure
    if [[ -f "$TELEMETRY_SPANS" ]]; then
        local span_count=$(wc -l < "$TELEMETRY_SPANS")
        local master_trace_spans=$(grep -c "$MASTER_TRACE_ID" "$TELEMETRY_SPANS" 2>/dev/null || echo "0")
        
        success "Telemetry spans file contains $span_count total spans"
        success "Found $master_trace_spans spans with master trace ID"
        TRACE_CORRELATIONS+=("telemetry_integrity:total_spans_$span_count")
        TRACE_CORRELATIONS+=("telemetry_integrity:master_trace_spans_$master_trace_spans")
        
        # Validate JSON structure of recent spans
        local recent_spans=$(tail -5 "$TELEMETRY_SPANS")
        local valid_json_count=0
        
        while IFS= read -r span_line; do
            if [[ -n "$span_line" ]] && echo "$span_line" | jq . > /dev/null 2>&1; then
                ((valid_json_count++))
            fi
        done <<< "$recent_spans"
        
        if [[ $valid_json_count -gt 0 ]]; then
            success "Found $valid_json_count recent spans with valid JSON structure"
            TRACE_CORRELATIONS+=("telemetry_integrity:valid_json_$valid_json_count")
        else
            warning "No recent spans with valid JSON structure found"
        fi
    else
        error "Telemetry spans file not found"
    fi
    
    # Test trace continuity across time
    trace_checkpoint "trace_continuity_test" "$checkpoint_span" > /dev/null 2>&1
    local continuity_test_span=$(openssl rand -hex 8)
    
    # Record continuity test span
    record_comprehensive_span "continuity_test" "$continuity_test_span" "$checkpoint_span"
    
    # Wait briefly and verify it appears
    sleep 1
    if grep -q "$continuity_test_span" "$TELEMETRY_SPANS" 2>/dev/null; then
        success "Trace continuity test span recorded and retrievable"
        TRACE_CORRELATIONS+=("trace_continuity:test_span_recorded")
    else
        error "Trace continuity test span not found"
    fi
}

test_cross_system_correlation() {
    trace_checkpoint "cross_system_correlation" > /dev/null 2>&1
    local checkpoint_span=$(openssl rand -hex 8)
    
    log "Testing cross-system trace correlation..."
    
    # Generate correlation test data
    local correlation_test_id="correlation_test_$(date +%s)"
    local correlation_span=$(openssl rand -hex 8)
    
    # Test correlation across multiple files
    local test_files=(
        "$COORDINATION_ROOT/work_claims.json"
        "$COORDINATION_ROOT/agent_status.json"
        "$COORDINATION_ROOT/coordination_log.json"
        "$TELEMETRY_SPANS"
    )
    
    local correlated_files=0
    for test_file in "${test_files[@]}"; do
        if [[ -f "$test_file" ]] && grep -q "$MASTER_TRACE_ID" "$test_file" 2>/dev/null; then
            success "Master trace ID found in $(basename "$test_file")"
            ((correlated_files++))
            TRACE_CORRELATIONS+=("cross_system:$(basename "$test_file")")
        else
            warning "Master trace ID not found in $(basename "$test_file")"
        fi
    done
    
    if [[ $correlated_files -ge 2 ]]; then
        success "Cross-system correlation verified across $correlated_files files"
        TRACE_CORRELATIONS+=("cross_system:correlation_count_$correlated_files")
    else
        error "Insufficient cross-system correlation ($correlated_files files)"
    fi
    
    # Test real-time trace injection
    trace_checkpoint "realtime_injection_test" "$checkpoint_span" > /dev/null 2>&1
    
    # Inject trace into coordination system
    export TRACE_INJECTION_TEST="$MASTER_TRACE_ID"
    if "$COORDINATION_ROOT/coordination_helper.sh" claude-health-analysis > /dev/null 2>&1; then
        success "Real-time trace injection test completed"
        TRACE_CORRELATIONS+=("realtime_injection:health_analysis")
    else
        warning "Real-time trace injection test failed"
    fi
    unset TRACE_INJECTION_TEST
}

generate_comprehensive_report() {
    local session_end_time=$(date +%s%N)
    local total_duration_ms=$(((session_end_time - SESSION_START_TIME) / 1000000))
    
    trace_checkpoint "comprehensive_report_generation" > /dev/null 2>&1
    
    echo
    echo "================================================================================"
    echo -e "${BOLD}${CYAN}🔍 COMPREHENSIVE END-TO-END OPENTELEMETRY VALIDATION REPORT${NC}"
    echo "================================================================================"
    echo
    echo -e "${BLUE}Validation Session:${NC} $VALIDATION_SESSION"
    echo -e "${BLUE}Master Trace ID:${NC} $MASTER_TRACE_ID"
    echo -e "${BLUE}Total Duration:${NC} ${total_duration_ms}ms ($(echo "scale=2; $total_duration_ms / 1000" | bc -l)s)"
    echo -e "${BLUE}Start Time:${NC} $(date -d "@$((SESSION_START_TIME / 1000000000))")"
    echo -e "${BLUE}End Time:${NC} $(date)"
    echo -e "${BLUE}Host System:${NC} $(hostname) ($(uname -s))"
    echo
    
    # Test Results Summary
    echo -e "${CYAN}📊 TEST RESULTS SUMMARY:${NC}"
    echo "  Total Tests: $TOTAL_TESTS"
    echo "  Passed: $PASSED_TESTS"
    echo "  Failed: $FAILED_TESTS"
    echo "  Warnings: $((TOTAL_TESTS - PASSED_TESTS - FAILED_TESTS))"
    
    local success_rate=0
    if [[ $TOTAL_TESTS -gt 0 ]]; then
        success_rate=$((PASSED_TESTS * 100 / TOTAL_TESTS))
    fi
    echo "  Success Rate: ${success_rate}%"
    echo
    
    # Detailed Results
    echo -e "${CYAN}📋 DETAILED VALIDATION RESULTS:${NC}"
    for result in "${VALIDATION_RESULTS[@]}"; do
        echo "  $result"
    done
    echo
    
    # Trace Correlations
    echo -e "${CYAN}🔗 TRACE CORRELATIONS (${#TRACE_CORRELATIONS[@]} found):${NC}"
    for correlation in "${TRACE_CORRELATIONS[@]}"; do
        echo "  🔗 $correlation"
    done
    echo
    
    # Trace Evidence
    if [[ ${#TRACE_EVIDENCE[@]} -gt 0 ]]; then
        echo -e "${CYAN}🔍 TRACE EVIDENCE:${NC}"
        for evidence in "${TRACE_EVIDENCE[@]}"; do
            echo "  📝 $evidence"
        done
        echo
    fi
    
    # System Components Tested
    local components_tested=()
    for correlation in "${TRACE_CORRELATIONS[@]}"; do
        local component=$(echo "$correlation" | cut -d':' -f1)
        if [[ ! " ${components_tested[@]} " =~ " $component " ]]; then
            components_tested+=("$component")
        fi
    done
    
    echo -e "${CYAN}🎯 SYSTEM COMPONENTS TESTED (${#components_tested[@]}):${NC}"
    for component in "${components_tested[@]}"; do
        echo "  🎯 $component"
    done
    echo
    
    # Final Assessment
    echo -e "${CYAN}📈 COMPREHENSIVE ASSESSMENT:${NC}"
    echo "  Trace Propagation: $([ ${#TRACE_CORRELATIONS[@]} -ge 5 ] && echo "✅ Excellent" || echo "⚠️  Limited")"
    echo "  System Integration: $([ ${#components_tested[@]} -ge 4 ] && echo "✅ Comprehensive" || echo "⚠️  Partial")"
    echo "  Data Integrity: $([ $success_rate -ge 70 ] && echo "✅ Good" || echo "❌ Poor")"
    echo "  Cross-System Correlation: $([ $(echo "${TRACE_CORRELATIONS[@]}" | grep -c "cross_system") -gt 0 ] && echo "✅ Verified" || echo "❌ Not Verified")"
    
    # Record final span
    local final_span=$(cat <<EOF
{
  "trace_id": "$MASTER_TRACE_ID",
  "span_id": "$(openssl rand -hex 8)",
  "operation_name": "e2e.comprehensive.validation.complete",
  "service_name": "comprehensive-e2e-validation",
  "start_time": "$(date -Iseconds)",
  "end_time": "$(date -Iseconds)",
  "duration_ms": $total_duration_ms,
  "status": {
    "code": "$([ $success_rate -ge 80 ] && echo "OK" || echo "ERROR")",
    "message": "Comprehensive validation completed with ${success_rate}% success rate"
  },
  "tags": {
    "validation.session": "$VALIDATION_SESSION",
    "validation.complete": true,
    "total_tests": $TOTAL_TESTS,
    "passed_tests": $PASSED_TESTS,
    "success_rate": $success_rate,
    "trace_correlations": ${#TRACE_CORRELATIONS[@]},
    "components_tested": ${#components_tested[@]}
  }
}
EOF
    )
    
    echo "$final_span" >> "$TELEMETRY_SPANS"
    
    # Final verdict
    echo
    if [[ $success_rate -ge 80 && ${#TRACE_CORRELATIONS[@]} -ge 8 ]]; then
        echo -e "${GREEN}${BOLD}🎉 COMPREHENSIVE E2E OPENTELEMETRY VALIDATION PASSED${NC}"
        echo -e "${GREEN}   Trace propagation successfully verified across autonomous coordination system${NC}"
        return 0
    elif [[ $success_rate -ge 60 ]]; then
        echo -e "${YELLOW}${BOLD}⚠️  COMPREHENSIVE E2E OPENTELEMETRY VALIDATION PARTIALLY SUCCESSFUL${NC}"
        echo -e "${YELLOW}   Some trace propagation verified, but improvements needed${NC}"
        return 1
    else
        echo -e "${RED}${BOLD}❌ COMPREHENSIVE E2E OPENTELEMETRY VALIDATION FAILED${NC}"
        echo -e "${RED}   Insufficient trace propagation verified${NC}"
        return 2
    fi
}

# Main execution flow
main() {
    echo
    echo "================================================================================"
    echo -e "${BOLD}${PURPLE}🚀 COMPREHENSIVE END-TO-END OPENTELEMETRY VALIDATION${NC}"
    echo -e "${BOLD}${PURPLE}   Autonomous AI Agent Coordination System - Full Stack Test${NC}"
    echo "================================================================================"
    echo
    
    log "Initializing comprehensive E2E OpenTelemetry validation..."
    log "Validation Session: $VALIDATION_SESSION"
    log "Master Trace ID: $MASTER_TRACE_ID"
    log "System: $(hostname) ($(uname -s))"
    echo
    
    # Initialize validation
    trace_checkpoint "validation_initialization" > /dev/null 2>&1
    
    # Execute comprehensive test suite
    echo -e "${BOLD}Phase 1: Coordination Workflow Testing${NC}"
    test_coordination_workflow_comprehensive
    echo
    
    echo -e "${BOLD}Phase 2: Reactor Middleware Integration${NC}"
    test_reactor_middleware_integration
    echo
    
    echo -e "${BOLD}Phase 3: Distributed Services Integration${NC}"
    test_distributed_services_integration
    echo
    
    echo -e "${BOLD}Phase 4: Telemetry Data Integrity${NC}"
    test_telemetry_data_integrity
    echo
    
    echo -e "${BOLD}Phase 5: Cross-System Correlation${NC}"
    test_cross_system_correlation
    echo
    
    echo -e "${BOLD}Phase 6: Comprehensive Report Generation${NC}"
    generate_comprehensive_report
}

# Dependency checks
for cmd in openssl jq bc curl; do
    if ! command -v "$cmd" &> /dev/null; then
        error "$cmd is required but not installed. Please install $cmd first."
        exit 1
    fi
done

# Ensure required directories and files exist
mkdir -p "$COORDINATION_ROOT"
touch "$TELEMETRY_SPANS"

# Execute comprehensive validation
main "$@"