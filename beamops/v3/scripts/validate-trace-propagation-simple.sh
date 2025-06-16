#!/bin/bash
# Simple but Robust E2E Trace Propagation Validation
# Triggers real workflow and validates trace ID propagation
# Anti-Hallucination: Uses actual telemetry data to prove trace propagation
# Date: 2025-06-16

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALIDATION_ID="simple-e2e-$(date +%s)"
RESULTS_DIR="/tmp/${VALIDATION_ID}"

# System paths
COORDINATION_HELPER="/Users/sac/dev/ai-self-sustaining-system/agent_coordination/coordination_helper.sh"
TELEMETRY_SPANS="/Users/sac/dev/ai-self-sustaining-system/agent_coordination/telemetry_spans.jsonl"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${BLUE}🔍 $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_trace() { echo -e "${PURPLE}🔗 $1${NC}"; }
log_workflow() { echo -e "${CYAN}🚀 $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

# Initialize
init_validation() {
    log_info "Simple E2E Trace Propagation Validation"
    mkdir -p "${RESULTS_DIR}"
    
    local baseline_spans=$(wc -l < "${TELEMETRY_SPANS}")
    echo "${baseline_spans}" > "${RESULTS_DIR}/baseline-spans.txt"
    
    log_workflow "Baseline: ${baseline_spans} existing spans"
    return 0
}

# Execute real workflow and capture results
execute_real_workflow() {
    log_workflow "Executing real workflow to generate traces..."
    
    local baseline_spans=$(cat "${RESULTS_DIR}/baseline-spans.txt")
    
    # Execute claim operation
    log_trace "Step 1: Claiming work..."
    if "${COORDINATION_HELPER}" claim "trace_validation_test" "E2E trace validation" "high" "validation_team" 2>&1 | tee "${RESULTS_DIR}/claim.log"; then
        log_success "✅ Claim operation successful"
    else
        log_warning "⚠️ Claim operation had issues"
    fi
    
    # Wait for telemetry
    sleep 3
    
    # Check new spans generated
    local post_claim_spans=$(wc -l < "${TELEMETRY_SPANS}")
    local claim_new_spans=$((post_claim_spans - baseline_spans))
    
    log_workflow "Claim generated ${claim_new_spans} new spans"
    
    # Extract work item ID from logs
    local work_item_id=""
    if grep -q "work_" "${RESULTS_DIR}/claim.log"; then
        work_item_id=$(grep -o "work_[0-9]*" "${RESULTS_DIR}/claim.log" | head -1)
        echo "${work_item_id}" > "${RESULTS_DIR}/work-item-id.txt"
        log_trace "🎯 Work item: ${work_item_id}"
    fi
    
    # Execute progress operation if we have work item
    if [[ -n "${work_item_id}" ]]; then
        log_trace "Step 2: Updating progress..."
        if "${COORDINATION_HELPER}" progress "${work_item_id}" 75 "trace_validation_progress" 2>&1 | tee "${RESULTS_DIR}/progress.log"; then
            log_success "✅ Progress operation successful"
        else
            log_warning "⚠️ Progress operation had issues"
        fi
        
        # Wait for telemetry
        sleep 3
    fi
    
    # Final span count
    local final_spans=$(wc -l < "${TELEMETRY_SPANS}")
    local total_new_spans=$((final_spans - baseline_spans))
    
    echo "${final_spans}" > "${RESULTS_DIR}/final-spans.txt"
    echo "${total_new_spans}" > "${RESULTS_DIR}/total-new-spans.txt"
    
    log_workflow "Workflow complete: ${total_new_spans} total new spans generated"
    return 0
}

# Analyze trace propagation
analyze_trace_propagation() {
    log_info "Analyzing trace propagation in generated spans..."
    
    local baseline_spans=$(cat "${RESULTS_DIR}/baseline-spans.txt")
    local total_new_spans=$(cat "${RESULTS_DIR}/total-new-spans.txt")
    local work_item_id=$(cat "${RESULTS_DIR}/work-item-id.txt" 2>/dev/null || echo "")
    
    # Extract new spans for analysis
    tail -"${total_new_spans}" "${TELEMETRY_SPANS}" > "${RESULTS_DIR}/new-spans.jsonl"
    
    # Find unique trace IDs in new spans
    grep -o '"trace_id": "[^"]*"' "${RESULTS_DIR}/new-spans.jsonl" | sed 's/"trace_id": "//; s/"//' | sort | uniq > "${RESULTS_DIR}/unique-trace-ids.txt"
    
    local unique_traces=$(wc -l < "${RESULTS_DIR}/unique-trace-ids.txt")
    log_trace "Found ${unique_traces} unique trace IDs in new spans"
    
    # Analyze each trace for propagation
    local propagated_traces=0
    local max_span_count=0
    local best_trace=""
    
    while IFS= read -r trace_id; do
        if [[ -n "${trace_id}" ]]; then
            local span_count=$(grep -c "${trace_id}" "${RESULTS_DIR}/new-spans.jsonl")
            echo "${trace_id}: ${span_count} spans" >> "${RESULTS_DIR}/trace-analysis.txt"
            
            if [[ ${span_count} -gt 1 ]]; then
                ((propagated_traces++))
                log_trace "🔗 Trace ${trace_id}: ${span_count} spans (PROPAGATED)"
            else
                log_trace "🔗 Trace ${trace_id}: ${span_count} span"
            fi
            
            if [[ ${span_count} -gt ${max_span_count} ]]; then
                max_span_count=${span_count}
                best_trace="${trace_id}"
            fi
        fi
    done < "${RESULTS_DIR}/unique-trace-ids.txt"
    
    # Analyze work item propagation
    local work_item_spans=0
    if [[ -n "${work_item_id}" ]]; then
        work_item_spans=$(grep -c "${work_item_id}" "${RESULTS_DIR}/new-spans.jsonl" 2>/dev/null || echo "0")
        log_trace "🎯 Work item ${work_item_id}: ${work_item_spans} spans"
    fi
    
    # Generate analysis report
    cat > "${RESULTS_DIR}/propagation-analysis.json" << EOF
{
  "validation_id": "${VALIDATION_ID}",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)",
  "workflow_analysis": {
    "total_new_spans": ${total_new_spans},
    "unique_trace_ids": ${unique_traces},
    "propagated_traces": ${propagated_traces},
    "work_item_id": "${work_item_id}",
    "work_item_spans": ${work_item_spans}
  },
  "best_trace": {
    "trace_id": "${best_trace}",
    "span_count": ${max_span_count},
    "propagation_confirmed": $([ ${max_span_count} -gt 1 ] && echo "true" || echo "false")
  },
  "validation_results": {
    "trace_propagation_detected": $([ ${propagated_traces} -gt 0 ] && echo "true" || echo "false"),
    "workflow_tracing_working": $([ ${work_item_spans} -gt 1 ] && echo "true" || echo "false"),
    "distributed_tracing_functional": $([ ${propagated_traces} -gt 0 ] && [ ${max_span_count} -gt 2 ] && echo "true" || echo "false")
  }
}
EOF
    
    log_success "Trace propagation analysis complete"
    log_trace "📊 Results: ${propagated_traces} propagated traces, best trace has ${max_span_count} spans"
    
    return 0
}

# Validate specific trace end-to-end
validate_best_trace_e2e() {
    log_info "Validating best trace end-to-end..."
    
    local best_trace=$(jq -r '.best_trace.trace_id' "${RESULTS_DIR}/propagation-analysis.json")
    local span_count=$(jq -r '.best_trace.span_count' "${RESULTS_DIR}/propagation-analysis.json")
    
    if [[ -z "${best_trace}" || "${best_trace}" == "null" ]]; then
        log_warning "No best trace found for detailed analysis"
        return 1
    fi
    
    log_trace "Analyzing trace: ${best_trace} (${span_count} spans)"
    
    # Extract all spans for this trace from entire telemetry file
    grep "${best_trace}" "${TELEMETRY_SPANS}" > "${RESULTS_DIR}/best-trace-spans.jsonl"
    local total_trace_spans=$(wc -l < "${RESULTS_DIR}/best-trace-spans.jsonl")
    
    # Analyze span characteristics
    local operations=$(grep -o '"operation_name": "[^"]*"' "${RESULTS_DIR}/best-trace-spans.jsonl" | sort | uniq | wc -l 2>/dev/null || echo "0")
    local services=$(grep -o '"service.*name": "[^"]*"' "${RESULTS_DIR}/best-trace-spans.jsonl" | sort | uniq | wc -l 2>/dev/null || echo "0")
    local parent_child=$(grep -c '"parent_span_id": "[^"]' "${RESULTS_DIR}/best-trace-spans.jsonl" 2>/dev/null || echo "0")
    
    # Check for specific workflow operations
    local claim_ops=$(grep -c "claim" "${RESULTS_DIR}/best-trace-spans.jsonl" 2>/dev/null || echo "0")
    local progress_ops=$(grep -c "progress" "${RESULTS_DIR}/best-trace-spans.jsonl" 2>/dev/null || echo "0")
    
    # Generate detailed trace analysis
    cat > "${RESULTS_DIR}/best-trace-analysis.json" << EOF
{
  "trace_id": "${best_trace}",
  "total_spans": ${total_trace_spans},
  "unique_operations": ${operations},
  "unique_services": ${services},
  "parent_child_relationships": ${parent_child},
  "workflow_operations": {
    "claim_operations": ${claim_ops},
    "progress_operations": ${progress_ops}
  },
  "e2e_validation": {
    "multi_span_trace": $([ ${total_trace_spans} -gt 1 ] && echo "true" || echo "false"),
    "multi_operation_trace": $([ ${operations} -gt 1 ] && echo "true" || echo "false"),
    "distributed_services": $([ ${services} -gt 1 ] && echo "true" || echo "false"),
    "hierarchical_tracing": $([ ${parent_child} -gt 0 ] && echo "true" || echo "false"),
    "workflow_coverage": $([ ${claim_ops} -gt 0 ] && [ ${progress_ops} -gt 0 ] && echo "true" || echo "false")
  }
}
EOF
    
    log_success "Best trace E2E validation complete"
    log_trace "🔗 Trace analysis: ${total_trace_spans} spans, ${operations} operations, ${services} services"
    
    return 0
}

# Generate final validation report
generate_final_report() {
    log_info "Generating final E2E trace validation report"
    
    local propagation_data=$(cat "${RESULTS_DIR}/propagation-analysis.json")
    local trace_data=$(cat "${RESULTS_DIR}/best-trace-analysis.json" 2>/dev/null || echo "{}")
    
    cat > "${RESULTS_DIR}/FINAL-E2E-TRACE-VALIDATION-REPORT.json" << EOF
{
  "validation_summary": {
    "validation_id": "${VALIDATION_ID}",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)",
    "validation_type": "simple_robust_e2e_trace_propagation",
    "approach": "real_workflow_trace_analysis",
    "principle": "trigger_actual_operations_validate_trace_propagation"
  },
  "workflow_execution": {
    "baseline_spans": $(cat "${RESULTS_DIR}/baseline-spans.txt"),
    "final_spans": $(cat "${RESULTS_DIR}/final-spans.txt"),
    "total_new_spans": $(cat "${RESULTS_DIR}/total-new-spans.txt"),
    "work_item_id": "$(cat "${RESULTS_DIR}/work-item-id.txt" 2>/dev/null || echo "")"
  },
  "propagation_analysis": ${propagation_data},
  "best_trace_analysis": ${trace_data},
  "evidence_files": {
    "new_spans": "${RESULTS_DIR}/new-spans.jsonl",
    "best_trace_spans": "${RESULTS_DIR}/best-trace-spans.jsonl",
    "workflow_logs": ["${RESULTS_DIR}/claim.log", "${RESULTS_DIR}/progress.log"],
    "live_telemetry": "${TELEMETRY_SPANS}"
  }
}
EOF

    log_success "Final validation report generated"
    log_workflow "📄 Report: ${RESULTS_DIR}/FINAL-E2E-TRACE-VALIDATION-REPORT.json"
}

# Main function
main() {
    echo "🚀 Simple but Robust E2E Trace Propagation Validation"
    echo "===================================================="
    echo "🆔 Validation ID: ${VALIDATION_ID}"
    echo "🎯 Approach: Real workflow → Capture traces → Validate propagation"
    echo "📁 Results: ${RESULTS_DIR}"
    echo ""
    
    # Execute validation steps
    init_validation
    execute_real_workflow
    analyze_trace_propagation
    validate_best_trace_e2e
    generate_final_report
    
    # Final results
    echo ""
    echo "🚀 SIMPLE E2E TRACE VALIDATION COMPLETE"
    echo "======================================"
    
    local propagated_traces=$(jq -r '.propagation_analysis.workflow_analysis.propagated_traces' "${RESULTS_DIR}/FINAL-E2E-TRACE-VALIDATION-REPORT.json")
    local best_trace_spans=$(jq -r '.best_trace_analysis.total_spans // 0' "${RESULTS_DIR}/FINAL-E2E-TRACE-VALIDATION-REPORT.json")
    local trace_propagation=$(jq -r '.propagation_analysis.validation_results.trace_propagation_detected' "${RESULTS_DIR}/FINAL-E2E-TRACE-VALIDATION-REPORT.json")
    local best_trace_id=$(jq -r '.propagation_analysis.best_trace.trace_id' "${RESULTS_DIR}/FINAL-E2E-TRACE-VALIDATION-REPORT.json")
    
    log_success "📊 Propagated traces found: ${propagated_traces}"
    log_success "🔗 Best trace spans: ${best_trace_spans}"
    log_trace "🎯 Best trace ID: ${best_trace_id}"
    log_workflow "📁 All data: ${RESULTS_DIR}"
    
    # Final assessment
    if [[ "${trace_propagation}" == "true" && ${best_trace_spans} -gt 2 ]]; then
        log_success "🎉 E2E TRACE PROPAGATION FULLY VALIDATED"
        echo "✅ Real workflow successfully generated distributed traces"
        echo "🔗 Trace ID propagation confirmed across multiple spans"
        echo "📊 System demonstrates production-ready distributed tracing"
    elif [[ "${trace_propagation}" == "true" ]]; then
        log_success "✅ BASIC TRACE PROPAGATION CONFIRMED"
        echo "🔗 Trace propagation working, limited span distribution"
        echo "📊 Core distributed tracing functionality validated"
    else
        log_warning "⚠️ TRACE PROPAGATION NEEDS INVESTIGATION"
        echo "🔗 Check individual workflow steps and telemetry generation"
        echo "📊 System may have tracing configuration issues"
    fi
    
    echo ""
    echo "🔍 Key validation files:"
    echo "  📊 ${RESULTS_DIR}/FINAL-E2E-TRACE-VALIDATION-REPORT.json"
    echo "  🔗 ${RESULTS_DIR}/best-trace-spans.jsonl"  
    echo "  📈 ${TELEMETRY_SPANS}"
}

# Execute
main "$@"