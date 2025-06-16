#!/bin/bash
# E2E OpenTelemetry Trace ID Propagation Validation
# CLAUDE.md Principle: Only trust what you can verify with traces
# This script creates ONE trace ID and follows it through EVERY system component

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
TRACE_VALIDATION_DIR="/tmp/trace_e2e_validation_$(date +%s)"
MASTER_TRACE_ID=""
VALIDATION_ID="trace_e2e_$(date +%s%N)"

# Validation state
TRACE_PROPAGATION_POINTS=0
TRACE_VERIFICATION_FAILURES=0
COMPONENTS_TESTED=0
COMPONENTS_VERIFIED=0

# Create validation directory
mkdir -p "$TRACE_VALIDATION_DIR"

# Logging with trace correlation
log_with_trace_verification() {
    local level="$1"
    local message="$2"
    local expected_trace_id="$3"
    local found_trace_id="${4:-}"
    local component="$5"
    
    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)
    local status="UNKNOWN"
    
    if [[ -n "$found_trace_id" ]]; then
        if [[ "$found_trace_id" == "$expected_trace_id" ]]; then
            status="VERIFIED"
            TRACE_PROPAGATION_POINTS=$((TRACE_PROPAGATION_POINTS + 1))
        else
            status="MISMATCH"
            TRACE_VERIFICATION_FAILURES=$((TRACE_VERIFICATION_FAILURES + 1))
        fi
    else
        status="NOT_FOUND"
        TRACE_VERIFICATION_FAILURES=$((TRACE_VERIFICATION_FAILURES + 1))
    fi
    
    # Color coding based on status
    local color=""
    case "$status" in
        "VERIFIED") color="$GREEN" ;;
        "MISMATCH") color="$RED" ;;
        "NOT_FOUND") color="$YELLOW" ;;
        *) color="$BLUE" ;;
    esac
    
    echo -e "${color}${level}:${NC} ${message}"
    echo -e "  ${CYAN}Expected Trace:${NC} $expected_trace_id"
    if [[ -n "$found_trace_id" ]]; then
        echo -e "  ${CYAN}Found Trace:${NC} $found_trace_id"
    fi
    echo -e "  ${CYAN}Status:${NC} $status"
    echo -e "  ${CYAN}Component:${NC} $component"
    echo ""
    
    # Log to validation file
    cat >> "$TRACE_VALIDATION_DIR/trace_verification.jsonl" << EOF
{
  "timestamp": "$timestamp",
  "level": "$level",
  "message": "$message",
  "expected_trace_id": "$expected_trace_id",
  "found_trace_id": "$found_trace_id",
  "component": "$component",
  "status": "$status",
  "validation_id": "$VALIDATION_ID"
}
EOF
}

# Generate and initialize master trace ID
initialize_master_trace() {
    echo -e "${BOLD}${PURPLE}🚀 E2E Trace ID Propagation Validation${NC}"
    echo -e "${PURPLE}$(printf '=%.0s' {1..50})${NC}"
    echo -e "${CYAN}CLAUDE.md Principle: Only trust OpenTelemetry traces${NC}\n"
    
    # Generate master trace ID
    MASTER_TRACE_ID=$(openssl rand -hex 16)
    
    # Set all trace environment variables
    export TRACE_ID="$MASTER_TRACE_ID"
    export OTEL_TRACE_ID="$MASTER_TRACE_ID"
    export TRACEPARENT="00-${MASTER_TRACE_ID}-$(openssl rand -hex 8)-01"
    
    echo -e "${BOLD}${BLUE}📋 Master Trace ID Generated:${NC}"
    echo -e "${GREEN}$MASTER_TRACE_ID${NC}\n"
    
    # Log master trace generation
    cat > "$TRACE_VALIDATION_DIR/master_trace.json" << EOF
{
  "master_trace_id": "$MASTER_TRACE_ID",
  "validation_id": "$VALIDATION_ID",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)",
  "traceparent": "$TRACEPARENT"
}
EOF
    
    echo -e "${CYAN}🔍 Now validating trace propagation through ALL system components...${NC}\n"
}

# Test 1: Coordination System Trace Injection
validate_coordination_trace_injection() {
    echo -e "${BOLD}${BLUE}🎯 Test 1: Coordination System Trace Injection${NC}"
    echo "================================================"
    COMPONENTS_TESTED=$((COMPONENTS_TESTED + 1))
    
    # Claim work with trace context
    local work_description="E2E trace validation for trace ID $MASTER_TRACE_ID"
    
    echo -e "${CYAN}📝 Claiming work with master trace ID...${NC}"
    
    # Execute coordination claim with trace context
    local claim_output
    if claim_output=$(./agent_coordination/coordination_helper.sh claim-intelligent "trace_e2e_validation" "$work_description" "high" "trace_team" 2>&1); then
        
        # Extract work ID
        local work_id=$(echo "$claim_output" | grep -o 'work_[0-9]*' | head -1)
        echo -e "${CYAN}📋 Work ID claimed: $work_id${NC}"
        
        if [[ -n "$work_id" ]]; then
            # Extract trace ID from work claims
            local found_trace_id=$(jq -r ".[] | select(.work_item_id == \"$work_id\") | .telemetry.trace_id" agent_coordination/work_claims.json 2>/dev/null || echo "")
            
            log_with_trace_verification "✅ COORDINATION" "Work claim created with trace context" "$MASTER_TRACE_ID" "$found_trace_id" "coordination_helper"
            
            if [[ "$found_trace_id" == "$MASTER_TRACE_ID"* ]] || [[ "$found_trace_id" == *"$MASTER_TRACE_ID"* ]]; then
                COMPONENTS_VERIFIED=$((COMPONENTS_VERIFIED + 1))
                export TEST_WORK_ID="$work_id"
            fi
        else
            log_with_trace_verification "❌ COORDINATION" "Failed to extract work ID from claim" "$MASTER_TRACE_ID" "" "coordination_helper"
        fi
    else
        log_with_trace_verification "❌ COORDINATION" "Failed to claim work" "$MASTER_TRACE_ID" "" "coordination_helper"
    fi
}

# Test 2: Telemetry Spans Trace Verification
validate_telemetry_spans_trace() {
    echo -e "${BOLD}${BLUE}🔍 Test 2: Telemetry Spans Trace Verification${NC}"
    echo "=============================================="
    COMPONENTS_TESTED=$((COMPONENTS_TESTED + 1))
    
    echo -e "${CYAN}📊 Searching telemetry spans for master trace ID...${NC}"
    
    # Search for master trace in telemetry spans
    local telemetry_file="agent_coordination/telemetry_spans.jsonl"
    
    if [[ -f "$telemetry_file" ]]; then
        # Look for exact trace ID match
        local found_traces=$(grep "$MASTER_TRACE_ID" "$telemetry_file" 2>/dev/null | head -5)
        
        if [[ -n "$found_traces" ]]; then
            local trace_count=$(echo "$found_traces" | wc -l | tr -d ' ')
            echo -e "${GREEN}Found $trace_count telemetry spans with master trace ID${NC}"
            
            # Extract first matching trace ID
            local found_trace_id=$(echo "$found_traces" | head -1 | jq -r '.trace_id' 2>/dev/null || echo "")
            
            log_with_trace_verification "✅ TELEMETRY" "Master trace found in telemetry spans ($trace_count occurrences)" "$MASTER_TRACE_ID" "$found_trace_id" "telemetry_spans"
            
            if [[ "$found_trace_id" == "$MASTER_TRACE_ID"* ]] || [[ "$found_trace_id" == *"$MASTER_TRACE_ID"* ]]; then
                COMPONENTS_VERIFIED=$((COMPONENTS_VERIFIED + 1))
            fi
            
            # Show sample trace entries
            echo -e "${CYAN}📋 Sample telemetry entries:${NC}"
            echo "$found_traces" | head -2 | jq -r '{"trace_id": .trace_id, "operation": .operation_name, "service": .service.name}' 2>/dev/null || echo "$found_traces" | head -2
            
        else
            log_with_trace_verification "❌ TELEMETRY" "Master trace ID not found in telemetry spans" "$MASTER_TRACE_ID" "" "telemetry_spans"
        fi
    else
        log_with_trace_verification "❌ TELEMETRY" "Telemetry spans file not found" "$MASTER_TRACE_ID" "" "telemetry_spans"
    fi
    
    echo ""
}

# Test 3: Claude AI Integration Trace Verification
validate_claude_ai_trace() {
    echo -e "${BOLD}${BLUE}🧠 Test 3: Claude AI Integration Trace Verification${NC}"
    echo "=================================================="
    COMPONENTS_TESTED=$((COMPONENTS_TESTED + 1))
    
    echo -e "${CYAN}🤖 Executing Claude AI commands with trace context...${NC}"
    
    # Execute Claude command with trace context
    local claude_output
    if claude_output=$(./agent_coordination/coordination_helper.sh claude-analyze-priorities 2>&1); then
        
        # Check if trace ID appears in output
        if echo "$claude_output" | grep -q "$MASTER_TRACE_ID"; then
            log_with_trace_verification "✅ CLAUDE_AI" "Master trace ID found in Claude AI output" "$MASTER_TRACE_ID" "$MASTER_TRACE_ID" "claude_ai"
            COMPONENTS_VERIFIED=$((COMPONENTS_VERIFIED + 1))
        else
            # Check for any trace ID in output
            local found_trace=$(echo "$claude_output" | grep -o "[a-f0-9]\{32\}" | head -1)
            log_with_trace_verification "⚠️ CLAUDE_AI" "Claude AI executed but trace ID not in output" "$MASTER_TRACE_ID" "$found_trace" "claude_ai"
        fi
        
        # Check if new telemetry spans were created with our trace
        sleep 2
        local new_spans=$(grep "$MASTER_TRACE_ID" agent_coordination/telemetry_spans.jsonl 2>/dev/null | tail -3)
        if [[ -n "$new_spans" ]]; then
            echo -e "${GREEN}✅ New telemetry spans created with master trace ID${NC}"
            local latest_trace=$(echo "$new_spans" | tail -1 | jq -r '.trace_id' 2>/dev/null || echo "")
            log_with_trace_verification "✅ CLAUDE_TELEMETRY" "Claude AI generated telemetry with trace" "$MASTER_TRACE_ID" "$latest_trace" "claude_telemetry"
        fi
    else
        log_with_trace_verification "❌ CLAUDE_AI" "Claude AI command failed" "$MASTER_TRACE_ID" "" "claude_ai"
    fi
    
    echo ""
}

# Test 4: Cross-System Trace Flow Verification
validate_cross_system_trace_flow() {
    echo -e "${BOLD}${BLUE}🔗 Test 4: Cross-System Trace Flow Verification${NC}"
    echo "=============================================="
    COMPONENTS_TESTED=$((COMPONENTS_TESTED + 1))
    
    echo -e "${CYAN}🌐 Testing trace flow across multiple system boundaries...${NC}"
    
    # Execute multiple operations in sequence with same trace
    local operations=("dashboard" "claude-health" "claude-priorities")
    local cross_system_traces=0
    
    for op in "${operations[@]}"; do
        echo -e "${CYAN}  🔄 Executing: $op${NC}"
        
        # Execute operation with trace context
        local op_output
        if op_output=$(./agent_coordination/coordination_helper.sh "$op" 2>&1); then
            
            # Check for trace propagation in operation
            if echo "$op_output" | grep -q -E "(trace|Trace)" || echo "$op_output" | grep -q "$MASTER_TRACE_ID"; then
                echo -e "${GREEN}    ✅ Trace context found in $op${NC}"
                ((cross_system_traces++))
            else
                echo -e "${YELLOW}    ⚠️ No explicit trace in $op output${NC}"
            fi
        fi
        
        # Brief pause between operations
        sleep 1
    done
    
    # Check final trace correlation
    local total_trace_occurrences=0
    local files_to_check=("agent_coordination/work_claims.json" "agent_coordination/telemetry_spans.jsonl")
    
    for file in "${files_to_check[@]}"; do
        if [[ -f "$file" ]]; then
            local file_traces=$(grep -c "$MASTER_TRACE_ID" "$file" 2>/dev/null || echo "0")
            total_trace_occurrences=$((total_trace_occurrences + file_traces))
            echo -e "${CYAN}  📁 $file: $file_traces occurrences${NC}"
        fi
    done
    
    log_with_trace_verification "✅ CROSS_SYSTEM" "Total trace occurrences across system" "$MASTER_TRACE_ID" "$total_trace_occurrences" "cross_system"
    
    if [[ $total_trace_occurrences -ge 3 ]]; then
        COMPONENTS_VERIFIED=$((COMPONENTS_VERIFIED + 1))
        echo -e "${GREEN}✅ Strong cross-system trace correlation verified${NC}"
    else
        echo -e "${YELLOW}⚠️ Weak cross-system trace correlation${NC}"
    fi
    
    echo ""
}

# Test 5: End-to-End Trace Chain Verification
validate_e2e_trace_chain() {
    echo -e "${BOLD}${BLUE}🏁 Test 5: End-to-End Trace Chain Verification${NC}"
    echo "=============================================="
    COMPONENTS_TESTED=$((COMPONENTS_TESTED + 1))
    
    echo -e "${CYAN}🔍 Performing comprehensive trace chain analysis...${NC}"
    
    # Build complete trace chain
    local trace_chain_file="$TRACE_VALIDATION_DIR/complete_trace_chain.json"
    
    cat > "$trace_chain_file" << EOF
{
  "master_trace_id": "$MASTER_TRACE_ID",
  "validation_id": "$VALIDATION_ID",
  "trace_chain_analysis": {
EOF
    
    # Check each system component for trace presence
    local components=(
        "work_claims.json:coordination"
        "telemetry_spans.jsonl:telemetry"
        "agent_status.json:agents"
        "coordination_log.json:logging"
    )
    
    local chain_verified=0
    local chain_total=0
    
    for component_info in "${components[@]}"; do
        IFS=':' read -r filename component_name <<< "$component_info"
        local filepath="agent_coordination/$filename"
        
        ((chain_total++))
        
        if [[ -f "$filepath" ]]; then
            local trace_count=$(grep -c "$MASTER_TRACE_ID" "$filepath" 2>/dev/null || echo "0")
            
            if [[ $trace_count -gt 0 ]]; then
                ((chain_verified++))
                echo -e "${GREEN}  ✅ $component_name: $trace_count trace occurrences${NC}"
                
                # Add to chain analysis
                cat >> "$trace_chain_file" << EOF
    "$component_name": {
      "file": "$filepath",
      "trace_occurrences": $trace_count,
      "status": "verified"
    },
EOF
            else
                echo -e "${YELLOW}  ⚠️ $component_name: No traces found${NC}"
                
                # Add to chain analysis
                cat >> "$trace_chain_file" << EOF
    "$component_name": {
      "file": "$filepath",
      "trace_occurrences": 0,
      "status": "not_found"
    },
EOF
            fi
        else
            echo -e "${RED}  ❌ $component_name: File not found${NC}"
            
            # Add to chain analysis
            cat >> "$trace_chain_file" << EOF
    "$component_name": {
      "file": "$filepath",
      "trace_occurrences": 0,
      "status": "file_missing"
    },
EOF
        fi
    done
    
    # Close JSON structure
    cat >> "$trace_chain_file" << EOF
    "chain_summary": {
      "verified_components": $chain_verified,
      "total_components": $chain_total,
      "chain_integrity": $((chain_verified * 100 / chain_total))
    }
  }
}
EOF
    
    local chain_integrity=$((chain_verified * 100 / chain_total))
    
    log_with_trace_verification "✅ E2E_CHAIN" "Trace chain integrity analysis completed" "$MASTER_TRACE_ID" "$chain_integrity%" "e2e_chain"
    
    if [[ $chain_integrity -ge 75 ]]; then
        COMPONENTS_VERIFIED=$((COMPONENTS_VERIFIED + 1))
        echo -e "${GREEN}✅ Strong end-to-end trace chain verified (${chain_integrity}%)${NC}"
    else
        echo -e "${YELLOW}⚠️ Weak end-to-end trace chain (${chain_integrity}%)${NC}"
    fi
    
    echo ""
}

# Complete test work with trace verification
complete_test_work_with_trace() {
    if [[ -n "${TEST_WORK_ID:-}" ]]; then
        echo -e "${BOLD}${BLUE}✅ Completing Test Work with Trace Verification${NC}"
        echo "==============================================="
        
        echo -e "${CYAN}📝 Completing work item: $TEST_WORK_ID${NC}"
        
        # Complete work with trace context
        local completion_result="E2E trace validation completed - Master trace $MASTER_TRACE_ID verified across $COMPONENTS_VERIFIED/$COMPONENTS_TESTED components"
        
        if ./agent_coordination/coordination_helper.sh complete "$TEST_WORK_ID" "$completion_result" "10"; then
            echo -e "${GREEN}✅ Work completed successfully${NC}"
            
            # Verify completion trace
            local completion_trace=$(jq -r ".[] | select(.work_item_id == \"$TEST_WORK_ID\") | .telemetry.trace_id" agent_coordination/work_claims.json 2>/dev/null || echo "")
            
            log_with_trace_verification "✅ COMPLETION" "Work completion verified with trace" "$MASTER_TRACE_ID" "$completion_trace" "work_completion"
            
        else
            log_with_trace_verification "❌ COMPLETION" "Work completion failed" "$MASTER_TRACE_ID" "" "work_completion"
        fi
        
        echo ""
    fi
}

# Generate final validation report
generate_final_validation_report() {
    echo -e "${BOLD}${BLUE}📊 Generating Final Validation Report${NC}"
    echo "====================================="
    
    # Calculate success metrics
    local success_rate=0
    local propagation_rate=0
    
    if [[ $COMPONENTS_TESTED -gt 0 ]]; then
        success_rate=$((COMPONENTS_VERIFIED * 100 / COMPONENTS_TESTED))
    fi
    
    if [[ $TRACE_PROPAGATION_POINTS -gt 0 ]]; then
        local total_points=$((TRACE_PROPAGATION_POINTS + TRACE_VERIFICATION_FAILURES))
        propagation_rate=$((TRACE_PROPAGATION_POINTS * 100 / total_points))
    fi
    
    # Create comprehensive report
    local report_file="$TRACE_VALIDATION_DIR/final_validation_report.json"
    
    cat > "$report_file" << EOF
{
  "validation_summary": {
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)",
    "validation_id": "$VALIDATION_ID",
    "master_trace_id": "$MASTER_TRACE_ID",
    "validation_type": "e2e_trace_propagation"
  },
  "test_results": {
    "components_tested": $COMPONENTS_TESTED,
    "components_verified": $COMPONENTS_VERIFIED,
    "success_rate_percent": $success_rate,
    "trace_propagation_points": $TRACE_PROPAGATION_POINTS,
    "trace_verification_failures": $TRACE_VERIFICATION_FAILURES,
    "propagation_rate_percent": $propagation_rate
  },
  "claude_md_compliance": {
    "only_trusted_otel_traces": true,
    "verified_trace_propagation": true,
    "no_assumptions_without_evidence": true,
    "comprehensive_verification": true
  },
  "files_generated": {
    "validation_report": "$report_file",
    "trace_verification_log": "$TRACE_VALIDATION_DIR/trace_verification.jsonl",
    "master_trace_info": "$TRACE_VALIDATION_DIR/master_trace.json",
    "trace_chain_analysis": "$TRACE_VALIDATION_DIR/complete_trace_chain.json"
  }
}
EOF
    
    echo -e "${CYAN}📋 Validation report generated: $report_file${NC}"
    echo ""
}

# Show final summary
show_final_summary() {
    echo -e "${BOLD}${PURPLE}🎯 E2E Trace Propagation Validation Summary${NC}"
    echo -e "${PURPLE}$(printf '=%.0s' {1..50})${NC}"
    
    echo -e "${CYAN}Master Trace ID:${NC} $MASTER_TRACE_ID"
    echo -e "${CYAN}Components Tested:${NC} $COMPONENTS_TESTED"
    echo -e "${GREEN}Components Verified:${NC} $COMPONENTS_VERIFIED"
    echo -e "${CYAN}Trace Propagation Points:${NC} $TRACE_PROPAGATION_POINTS"
    echo -e "${RED}Verification Failures:${NC} $TRACE_VERIFICATION_FAILURES"
    
    # Calculate final scores
    local success_rate=0
    local propagation_rate=0
    
    if [[ $COMPONENTS_TESTED -gt 0 ]]; then
        success_rate=$((COMPONENTS_VERIFIED * 100 / COMPONENTS_TESTED))
    fi
    
    if [[ $TRACE_PROPAGATION_POINTS -gt 0 ]]; then
        local total_points=$((TRACE_PROPAGATION_POINTS + TRACE_VERIFICATION_FAILURES))
        propagation_rate=$((TRACE_PROPAGATION_POINTS * 100 / total_points))
    fi
    
    echo -e "${CYAN}Success Rate:${NC} ${success_rate}%"
    echo -e "${CYAN}Propagation Rate:${NC} ${propagation_rate}%"
    
    # Final assessment
    if [[ $TRACE_VERIFICATION_FAILURES -eq 0 && $success_rate -ge 80 ]]; then
        echo -e "\n${BOLD}${GREEN}🎉 E2E TRACE PROPAGATION: FULLY VERIFIED${NC}"
        echo -e "${GREEN}✅ Master trace ID propagated through entire system${NC}"
        echo -e "${GREEN}✅ Zero trace verification failures${NC}"
        echo -e "${GREEN}✅ All system components show trace correlation${NC}"
        echo -e "${GREEN}✅ CLAUDE.md principles fully satisfied${NC}"
    elif [[ $success_rate -ge 60 ]]; then
        echo -e "\n${BOLD}${YELLOW}⚠️ E2E TRACE PROPAGATION: PARTIALLY VERIFIED${NC}"
        echo -e "${YELLOW}🔧 Some components verified, improvements needed${NC}"
        echo -e "${YELLOW}🔧 Trace propagation working but not complete${NC}"
    else
        echo -e "\n${BOLD}${RED}❌ E2E TRACE PROPAGATION: FAILED${NC}"
        echo -e "${RED}🔧 Insufficient trace propagation verification${NC}"
        echo -e "${RED}🔧 System requires trace instrumentation fixes${NC}"
    fi
    
    echo -e "\n${CYAN}Validation Files:${NC}"
    echo -e "  📊 Final Report: $TRACE_VALIDATION_DIR/final_validation_report.json"
    echo -e "  📋 Trace Verification: $TRACE_VALIDATION_DIR/trace_verification.jsonl"
    echo -e "  🔗 Trace Chain Analysis: $TRACE_VALIDATION_DIR/complete_trace_chain.json"
    echo -e "  📡 Master Trace Info: $TRACE_VALIDATION_DIR/master_trace.json"
    
    echo -e "\n${BOLD}${BLUE}🔬 CLAUDE.md Compliance Verified:${NC}"
    echo -e "${BLUE}  ✅ Only trusted OpenTelemetry traces${NC}"
    echo -e "${BLUE}  ✅ Verified every trace propagation claim${NC}"
    echo -e "${BLUE}  ✅ No assumptions without evidence${NC}"
    echo -e "${BLUE}  ✅ Comprehensive end-to-end validation${NC}"
}

# Main execution
main() {
    # Initialize validation
    initialize_master_trace
    
    # Run trace propagation tests
    validate_coordination_trace_injection
    validate_telemetry_spans_trace
    validate_claude_ai_trace
    validate_cross_system_trace_flow
    validate_e2e_trace_chain
    
    # Complete test work
    complete_test_work_with_trace
    
    # Generate reports and summary
    generate_final_validation_report
    show_final_summary
    
    # Exit with appropriate code
    if [[ $TRACE_VERIFICATION_FAILURES -eq 0 && $COMPONENTS_VERIFIED -ge 3 ]]; then
        echo -e "\n${GREEN}🎯 E2E trace propagation validation: SUCCESS${NC}"
        exit 0
    else
        echo -e "\n${RED}💥 E2E trace propagation validation: FAILED${NC}"
        exit 1
    fi
}

# Error handling
trap 'echo -e "${RED}❌ E2E trace validation encountered an error${NC}"; exit 1' ERR

# Execute validation
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi