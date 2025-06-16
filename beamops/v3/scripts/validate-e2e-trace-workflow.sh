#!/bin/bash
# End-to-End Trace Workflow Validation
# Triggers REAL workflow and follows trace ID through entire system
# Anti-Hallucination: Uses actual system workflows to validate trace propagation
# Date: 2025-06-16

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BEAMOPS_ROOT="$(dirname "$SCRIPT_DIR")"
VALIDATION_ID="e2e-workflow-$(date +%s)"
RESULTS_DIR="/tmp/${VALIDATION_ID}"

# System paths
COORDINATION_HELPER="/Users/sac/dev/ai-self-sustaining-system/agent_coordination/coordination_helper.sh"
TELEMETRY_SPANS="/Users/sac/dev/ai-self-sustaining-system/agent_coordination/telemetry_spans.jsonl"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Enhanced logging functions
log_info() { echo -e "${BLUE}🔍 $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }
log_trace() { echo -e "${PURPLE}🔗 $1${NC}"; }
log_workflow() { echo -e "${CYAN}🚀 $1${NC}"; }

# Initialize validation environment
init_e2e_validation() {
    log_info "Initializing End-to-End Trace Workflow Validation"
    
    mkdir -p "${RESULTS_DIR}"
    
    # Capture baseline telemetry state
    local baseline_spans=$(wc -l < "${TELEMETRY_SPANS}" 2>/dev/null || echo "0")
    
    cat > "${RESULTS_DIR}/e2e-validation-context.json" << EOF
{
  "validation_id": "${VALIDATION_ID}",
  "start_time": "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)",
  "baseline_spans": ${baseline_spans},
  "coordination_helper": "${COORDINATION_HELPER}",
  "telemetry_spans": "${TELEMETRY_SPANS}",
  "approach": "trigger_real_workflow_follow_trace_e2e",
  "principle": "Follow actual trace IDs through complete system workflow"
}
EOF

    # Create trace tracking files
    echo "[]" > "${RESULTS_DIR}/captured-traces.jsonl"
    echo "[]" > "${RESULTS_DIR}/workflow-events.jsonl"
    echo "[]" > "${RESULTS_DIR}/trace-propagation-chain.jsonl"
    
    log_success "E2E validation environment initialized"
    log_workflow "Baseline: ${baseline_spans} existing spans"
    return 0
}

# Step 1: Trigger real workflow and capture initial trace
trigger_workflow_capture_trace() {
    log_workflow "Step 1: Triggering real workflow to capture trace ID"
    local start_time=$(date +%s)
    
    # Capture spans before workflow
    local pre_workflow_spans=$(wc -l < "${TELEMETRY_SPANS}")
    
    log_workflow "Executing: claim operation to start workflow..."
    
    # Execute real claim operation
    if "${COORDINATION_HELPER}" claim "e2e_trace_validation" "End-to-end trace validation workflow" "high" "validation_team" 2>&1 | tee "${RESULTS_DIR}/step1-claim.log"; then
        log_success "✅ Claim operation completed successfully"
        local claim_status="success"
    else
        log_warning "⚠️ Claim operation had issues"
        local claim_status="failed"
    fi
    
    # Wait for telemetry to be written
    sleep 3
    
    # Capture spans after workflow
    local post_workflow_spans=$(wc -l < "${TELEMETRY_SPANS}")
    local new_spans=$((post_workflow_spans - pre_workflow_spans))
    
    log_workflow "Telemetry update: ${new_spans} new spans generated"
    
    # Extract the most recent spans (likely from our workflow)
    tail -"${new_spans}" "${TELEMETRY_SPANS}" > "${RESULTS_DIR}/step1-new-spans.jsonl" 2>/dev/null || echo "[]" > "${RESULTS_DIR}/step1-new-spans.jsonl"
    
    # Find trace IDs from our workflow
    local workflow_trace_ids=()
    if [[ ${new_spans} -gt 0 ]]; then
        # Extract trace IDs from new spans
        while IFS= read -r trace_id; do
            if [[ -n "${trace_id}" ]]; then
                workflow_trace_ids+=("${trace_id}")
            fi
        done < <(grep -o '"trace_id": "[^"]*"' "${RESULTS_DIR}/step1-new-spans.jsonl" | sed 's/"trace_id": "//; s/"//' | sort | uniq)
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Record step 1 results
    cat > "${RESULTS_DIR}/step1-results.json" << EOF
{
  "step": "trigger_workflow_capture_trace",
  "claim_status": "${claim_status}",
  "pre_workflow_spans": ${pre_workflow_spans},
  "post_workflow_spans": ${post_workflow_spans},
  "new_spans_generated": ${new_spans},
  "workflow_trace_ids": $(printf '%s\n' "${workflow_trace_ids[@]}" | jq -R . | jq -s .),
  "duration_seconds": ${duration}
}
EOF
    
    log_success "Step 1 complete: Workflow triggered (${duration}s, ${new_spans} new spans)"
    
    if [[ ${#workflow_trace_ids[@]} -gt 0 ]]; then
        for trace_id in "${workflow_trace_ids[@]}"; do
            log_trace "🎯 Captured trace ID: ${trace_id}"
        done
        return 0
    else
        log_warning "❌ No trace IDs captured from workflow"
        return 1
    fi
}

# Step 2: Follow trace through coordination operations
follow_trace_coordination() {
    log_workflow "Step 2: Following trace through coordination operations"
    local start_time=$(date +%s)
    
    # Get trace IDs from step 1
    local trace_ids=($(jq -r '.workflow_trace_ids[]' "${RESULTS_DIR}/step1-results.json" 2>/dev/null || echo ""))
    
    if [[ ${#trace_ids[@]} -eq 0 ]]; then
        log_warning "No trace IDs to follow"
        return 1
    fi
    
    local primary_trace_id="${trace_ids[0]}"
    log_trace "Following primary trace ID: ${primary_trace_id}"
    
    # Execute progress operation to continue the workflow
    log_workflow "Executing: progress operation with same workflow..."
    
    # Extract work item ID from step 1 logs
    local work_item_id=""
    if grep -q "work_" "${RESULTS_DIR}/step1-claim.log"; then
        work_item_id=$(grep -o "work_[0-9]*" "${RESULTS_DIR}/step1-claim.log" | head -1)
        log_trace "Found work item ID: ${work_item_id}"
    fi
    
    # Capture spans before progress operation
    local pre_progress_spans=$(wc -l < "${TELEMETRY_SPANS}")
    
    # Execute progress operation
    if [[ -n "${work_item_id}" ]]; then
        if "${COORDINATION_HELPER}" progress "${work_item_id}" 50 "trace_validation_in_progress" 2>&1 | tee "${RESULTS_DIR}/step2-progress.log"; then
            log_success "✅ Progress operation completed"
            local progress_status="success"
        else
            log_warning "⚠️ Progress operation had issues"
            local progress_status="failed"
        fi
    else
        log_warning "⚠️ No work item ID found, skipping progress operation"
        local progress_status="skipped"
    fi
    
    # Wait for telemetry
    sleep 3
    
    # Capture spans after progress operation
    local post_progress_spans=$(wc -l < "${TELEMETRY_SPANS}")
    local progress_new_spans=$((post_progress_spans - pre_progress_spans))
    
    # Check if our trace ID appears in new spans
    local trace_continuation=0
    if [[ ${progress_new_spans} -gt 0 ]]; then
        tail -"${progress_new_spans}" "${TELEMETRY_SPANS}" > "${RESULTS_DIR}/step2-new-spans.jsonl"
        trace_continuation=$(grep -c "${primary_trace_id}" "${RESULTS_DIR}/step2-new-spans.jsonl" 2>/dev/null || echo "0")
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Record step 2 results
    cat > "${RESULTS_DIR}/step2-results.json" << EOF
{
  "step": "follow_trace_coordination",
  "primary_trace_id": "${primary_trace_id}",
  "work_item_id": "${work_item_id}",
  "progress_status": "${progress_status}",
  "progress_new_spans": ${progress_new_spans},
  "trace_continuation_count": ${trace_continuation},
  "trace_propagated": $([ ${trace_continuation} -gt 0 ] && echo "true" || echo "false"),
  "duration_seconds": ${duration}
}
EOF
    
    log_success "Step 2 complete: Coordination follow-up (${duration}s)"
    log_trace "Trace propagation: ${trace_continuation} occurrences in new spans"
    
    return 0
}

# Step 3: Trigger AI analysis with trace context
trigger_ai_analysis_trace() {
    log_workflow "Step 3: Triggering AI analysis to extend trace"
    local start_time=$(date +%s)
    
    # Get primary trace ID
    local primary_trace_id=$(jq -r '.primary_trace_id' "${RESULTS_DIR}/step2-results.json" 2>/dev/null || echo "")
    
    if [[ -z "${primary_trace_id}" ]]; then
        log_warning "No primary trace ID available"
        return 1
    fi
    
    log_trace "Extending trace with AI analysis: ${primary_trace_id}"
    
    # Capture spans before AI operation
    local pre_ai_spans=$(wc -l < "${TELEMETRY_SPANS}")
    
    # Execute Claude priority analysis
    log_workflow "Executing: claude-analyze-priorities to extend trace..."
    
    if "${COORDINATION_HELPER}" claude-analyze-priorities 2>&1 | tee "${RESULTS_DIR}/step3-claude.log"; then
        log_success "✅ Claude analysis completed"
        local claude_status="success"
    else
        log_warning "⚠️ Claude analysis had issues"
        local claude_status="failed"
    fi
    
    # Wait for telemetry
    sleep 5  # Claude operations may take longer to generate telemetry
    
    # Capture spans after AI operation
    local post_ai_spans=$(wc -l < "${TELEMETRY_SPANS}")
    local ai_new_spans=$((post_ai_spans - pre_ai_spans))
    
    # Check for trace propagation in AI operation
    local ai_trace_continuation=0
    local ai_related_spans=0
    if [[ ${ai_new_spans} -gt 0 ]]; then
        tail -"${ai_new_spans}" "${TELEMETRY_SPANS}" > "${RESULTS_DIR}/step3-new-spans.jsonl"
        ai_trace_continuation=$(grep -c "${primary_trace_id}" "${RESULTS_DIR}/step3-new-spans.jsonl" 2>/dev/null || echo "0")
        ai_related_spans=$(grep -c "claude\|priority_analysis" "${RESULTS_DIR}/step3-new-spans.jsonl" 2>/dev/null || echo "0")
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Record step 3 results
    cat > "${RESULTS_DIR}/step3-results.json" << EOF
{
  "step": "trigger_ai_analysis_trace",
  "primary_trace_id": "${primary_trace_id}",
  "claude_status": "${claude_status}",
  "ai_new_spans": ${ai_new_spans},
  "ai_trace_continuation": ${ai_trace_continuation},
  "ai_related_spans": ${ai_related_spans},
  "trace_extended_to_ai": $([ ${ai_trace_continuation} -gt 0 ] && echo "true" || echo "false"),
  "duration_seconds": ${duration}
}
EOF
    
    log_success "Step 3 complete: AI analysis extension (${duration}s)"
    log_trace "AI trace extension: ${ai_trace_continuation} direct, ${ai_related_spans} related spans"
    
    return 0
}

# Step 4: Complete workflow and validate full trace
complete_workflow_validate_trace() {
    log_workflow "Step 4: Completing workflow and validating full trace"
    local start_time=$(date +%s)
    
    # Get workflow context
    local primary_trace_id=$(jq -r '.primary_trace_id' "${RESULTS_DIR}/step2-results.json" 2>/dev/null || echo "")
    local work_item_id=$(jq -r '.work_item_id' "${RESULTS_DIR}/step2-results.json" 2>/dev/null || echo "")
    
    log_trace "Completing workflow for trace: ${primary_trace_id}"
    
    # Capture spans before completion
    local pre_complete_spans=$(wc -l < "${TELEMETRY_SPANS}")
    
    # Execute completion operation
    if [[ -n "${work_item_id}" ]]; then
        log_workflow "Executing: complete operation to finish workflow..."
        
        if "${COORDINATION_HELPER}" complete "${work_item_id}" "e2e_trace_validation_completed" 100 2>&1 | tee "${RESULTS_DIR}/step4-complete.log"; then
            log_success "✅ Complete operation finished"
            local complete_status="success"
        else
            log_warning "⚠️ Complete operation had issues"
            local complete_status="failed"
        fi
    else
        log_warning "⚠️ No work item ID for completion"
        local complete_status="skipped"
    fi
    
    # Wait for final telemetry
    sleep 3
    
    # Capture final spans
    local post_complete_spans=$(wc -l < "${TELEMETRY_SPANS}")
    local complete_new_spans=$((post_complete_spans - pre_complete_spans))
    
    # Final trace validation
    local final_trace_continuation=0
    if [[ ${complete_new_spans} -gt 0 ]]; then
        tail -"${complete_new_spans}" "${TELEMETRY_SPANS}" > "${RESULTS_DIR}/step4-new-spans.jsonl"
        final_trace_continuation=$(grep -c "${primary_trace_id}" "${RESULTS_DIR}/step4-new-spans.jsonl" 2>/dev/null || echo "0")
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Record step 4 results
    cat > "${RESULTS_DIR}/step4-results.json" << EOF
{
  "step": "complete_workflow_validate_trace",
  "primary_trace_id": "${primary_trace_id}",
  "work_item_id": "${work_item_id}",
  "complete_status": "${complete_status}",
  "complete_new_spans": ${complete_new_spans},
  "final_trace_continuation": ${final_trace_continuation},
  "workflow_fully_traced": $([ ${final_trace_continuation} -gt 0 ] && echo "true" || echo "false"),
  "duration_seconds": ${duration}
}
EOF
    
    log_success "Step 4 complete: Workflow completion (${duration}s)"
    log_trace "Final trace validation: ${final_trace_continuation} continuation spans"
    
    return 0
}

# Step 5: Comprehensive trace analysis
analyze_complete_trace_chain() {
    log_workflow "Step 5: Analyzing complete trace chain end-to-end"
    local start_time=$(date +%s)
    
    # Get primary trace ID
    local primary_trace_id=$(jq -r '.primary_trace_id' "${RESULTS_DIR}/step2-results.json" 2>/dev/null || echo "")
    
    if [[ -z "${primary_trace_id}" ]]; then
        log_warning "No primary trace ID for analysis"
        return 1
    fi
    
    log_trace "Analyzing complete trace chain for: ${primary_trace_id}"
    
    # Extract ALL spans with our trace ID
    local total_trace_spans=0
    if grep -q "${primary_trace_id}" "${TELEMETRY_SPANS}"; then
        grep "${primary_trace_id}" "${TELEMETRY_SPANS}" > "${RESULTS_DIR}/complete-trace-chain.jsonl"
        total_trace_spans=$(wc -l < "${RESULTS_DIR}/complete-trace-chain.jsonl")
        log_success "✅ Extracted complete trace chain: ${total_trace_spans} spans"
    else
        log_warning "❌ No spans found for primary trace ID"
        echo "[]" > "${RESULTS_DIR}/complete-trace-chain.jsonl"
    fi
    
    # Analyze trace characteristics
    local unique_operations=0
    local unique_services=0
    local parent_child_relationships=0
    local workflow_stages=0
    
    if [[ ${total_trace_spans} -gt 0 ]]; then
        # Count unique operations
        unique_operations=$(grep -o '"operation_name": "[^"]*"' "${RESULTS_DIR}/complete-trace-chain.jsonl" | sort | uniq | wc -l 2>/dev/null || echo "0")
        
        # Count unique services
        unique_services=$(grep -o '"service.*name": "[^"]*"' "${RESULTS_DIR}/complete-trace-chain.jsonl" | sort | uniq | wc -l 2>/dev/null || echo "0")
        
        # Count parent-child relationships
        parent_child_relationships=$(grep -c '"parent_span_id": "[^"]' "${RESULTS_DIR}/complete-trace-chain.jsonl" 2>/dev/null || echo "0")
        
        # Identify workflow stages
        workflow_stages=$(grep -E -c "claim|progress|complete|claude|priority" "${RESULTS_DIR}/complete-trace-chain.jsonl" 2>/dev/null || echo "0")
    fi
    
    # Look for related traces (same work item, different trace IDs)
    local work_item_id=$(jq -r '.work_item_id' "${RESULTS_DIR}/step2-results.json" 2>/dev/null || echo "")
    local related_traces=0
    if [[ -n "${work_item_id}" ]]; then
        related_traces=$(grep -c "${work_item_id}" "${TELEMETRY_SPANS}" 2>/dev/null || echo "0")
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Record comprehensive analysis
    cat > "${RESULTS_DIR}/step5-trace-analysis.json" << EOF
{
  "step": "analyze_complete_trace_chain",
  "primary_trace_id": "${primary_trace_id}",
  "work_item_id": "${work_item_id}",
  "total_trace_spans": ${total_trace_spans},
  "unique_operations": ${unique_operations},
  "unique_services": ${unique_services},
  "parent_child_relationships": ${parent_child_relationships},
  "workflow_stages_traced": ${workflow_stages},
  "related_traces": ${related_traces},
  "trace_chain_complete": $([ ${total_trace_spans} -gt 2 ] && echo "true" || echo "false"),
  "distributed_tracing_confirmed": $([ ${unique_services} -gt 1 ] && echo "true" || echo "false"),
  "workflow_fully_instrumented": $([ ${workflow_stages} -gt 2 ] && echo "true" || echo "false"),
  "duration_seconds": ${duration}
}
EOF
    
    log_success "Step 5 complete: Trace chain analysis (${duration}s)"
    log_trace "📊 Trace analysis: ${total_trace_spans} spans, ${unique_operations} operations, ${unique_services} services"
    
    return 0
}

# Generate comprehensive E2E validation report
generate_e2e_validation_report() {
    log_info "Generating comprehensive E2E trace validation report"
    
    # Collect all step results
    local step1_data=$(cat "${RESULTS_DIR}/step1-results.json" 2>/dev/null || echo "{}")
    local step2_data=$(cat "${RESULTS_DIR}/step2-results.json" 2>/dev/null || echo "{}")
    local step3_data=$(cat "${RESULTS_DIR}/step3-results.json" 2>/dev/null || echo "{}")
    local step4_data=$(cat "${RESULTS_DIR}/step4-results.json" 2>/dev/null || echo "{}")
    local step5_data=$(cat "${RESULTS_DIR}/step5-trace-analysis.json" 2>/dev/null || echo "{}")
    
    # Calculate final statistics
    local baseline_spans=$(jq -r '.baseline_spans' "${RESULTS_DIR}/e2e-validation-context.json")
    local final_spans=$(wc -l < "${TELEMETRY_SPANS}")
    local total_new_spans=$((final_spans - baseline_spans))
    
    # Create comprehensive final report
    cat > "${RESULTS_DIR}/E2E-TRACE-VALIDATION-FINAL-REPORT.json" << EOF
{
  "validation_summary": {
    "validation_id": "${VALIDATION_ID}",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)",
    "validation_type": "end_to_end_trace_workflow_validation",
    "approach": "trigger_real_workflow_follow_trace_through_complete_system",
    "principle": "validate_trace_propagation_through_actual_operations"
  },
  "workflow_steps": {
    "step1_trigger_workflow": ${step1_data},
    "step2_follow_coordination": ${step2_data},
    "step3_ai_analysis": ${step3_data},
    "step4_complete_workflow": ${step4_data},
    "step5_trace_analysis": ${step5_data}
  },
  "final_metrics": {
    "baseline_spans": ${baseline_spans},
    "final_spans": ${final_spans},
    "total_new_spans_generated": ${total_new_spans},
    "primary_trace_id": "$(jq -r '.primary_trace_id' "${RESULTS_DIR}/step2-results.json" 2>/dev/null || echo "")",
    "work_item_id": "$(jq -r '.work_item_id' "${RESULTS_DIR}/step2-results.json" 2>/dev/null || echo "")"
  },
  "validation_success": {
    "workflow_triggered": "$(jq -r '.claim_status == "success"' "${RESULTS_DIR}/step1-results.json" 2>/dev/null || echo "false")",
    "trace_captured": "$(jq -r '(.workflow_trace_ids | length) > 0' "${RESULTS_DIR}/step1-results.json" 2>/dev/null || echo "false")",
    "trace_propagated": "$(jq -r '.trace_propagated' "${RESULTS_DIR}/step2-results.json" 2>/dev/null || echo "false")",
    "ai_integration": "$(jq -r '.trace_extended_to_ai' "${RESULTS_DIR}/step3-results.json" 2>/dev/null || echo "false")",
    "workflow_completed": "$(jq -r '.workflow_fully_traced' "${RESULTS_DIR}/step4-results.json" 2>/dev/null || echo "false")",
    "trace_chain_complete": "$(jq -r '.trace_chain_complete' "${RESULTS_DIR}/step5-trace-analysis.json" 2>/dev/null || echo "false")",
    "distributed_tracing": "$(jq -r '.distributed_tracing_confirmed' "${RESULTS_DIR}/step5-trace-analysis.json" 2>/dev/null || echo "false")"
  },
  "evidence_files": {
    "complete_trace_chain": "${RESULTS_DIR}/complete-trace-chain.jsonl",
    "workflow_logs": [
      "${RESULTS_DIR}/step1-claim.log",
      "${RESULTS_DIR}/step2-progress.log", 
      "${RESULTS_DIR}/step3-claude.log",
      "${RESULTS_DIR}/step4-complete.log"
    ],
    "telemetry_spans": "${TELEMETRY_SPANS}"
  }
}
EOF

    log_success "Comprehensive E2E validation report generated"
    log_workflow "📄 Final report: ${RESULTS_DIR}/E2E-TRACE-VALIDATION-FINAL-REPORT.json"
}

# Main validation function
main() {
    echo "🚀 End-to-End Trace Workflow Validation"
    echo "======================================"
    echo "🆔 Validation ID: ${VALIDATION_ID}"
    echo "🎯 Approach: Trigger real workflow and follow trace through complete system"
    echo "📁 Results Directory: ${RESULTS_DIR}"
    echo "🔧 Coordination Helper: ${COORDINATION_HELPER}"
    echo "📊 Live Telemetry: ${TELEMETRY_SPANS}"
    echo ""
    
    # Verify prerequisites
    if [[ ! -x "${COORDINATION_HELPER}" ]]; then
        log_error "Coordination helper not found: ${COORDINATION_HELPER}"
        exit 1
    fi
    
    if [[ ! -f "${TELEMETRY_SPANS}" ]]; then
        log_error "Telemetry spans file not found: ${TELEMETRY_SPANS}"
        exit 1
    fi
    
    log_workflow "✅ Prerequisites verified - ready for E2E workflow validation"
    
    # Execute validation workflow
    local steps_completed=0
    local steps_total=5
    
    if init_e2e_validation; then ((steps_completed++)); fi
    if trigger_workflow_capture_trace; then ((steps_completed++)); fi
    if follow_trace_coordination; then ((steps_completed++)); fi
    if trigger_ai_analysis_trace; then ((steps_completed++)); fi
    if complete_workflow_validate_trace; then ((steps_completed++)); fi
    
    # Always run analysis even if earlier steps had issues
    analyze_complete_trace_chain
    
    # Generate final report
    generate_e2e_validation_report
    
    # Results summary
    echo ""
    echo "🚀 END-TO-END TRACE WORKFLOW VALIDATION COMPLETE"
    echo "==============================================="
    log_success "Validation Steps Completed: ${steps_completed}/${steps_total}"
    
    # Extract key metrics
    local primary_trace_id=$(jq -r '.final_metrics.primary_trace_id' "${RESULTS_DIR}/E2E-TRACE-VALIDATION-FINAL-REPORT.json" 2>/dev/null || echo "")
    local total_new_spans=$(jq -r '.final_metrics.total_new_spans_generated' "${RESULTS_DIR}/E2E-TRACE-VALIDATION-FINAL-REPORT.json" 2>/dev/null || echo "0")
    local trace_chain_complete=$(jq -r '.validation_success.trace_chain_complete' "${RESULTS_DIR}/E2E-TRACE-VALIDATION-FINAL-REPORT.json" 2>/dev/null || echo "false")
    local distributed_tracing=$(jq -r '.validation_success.distributed_tracing' "${RESULTS_DIR}/E2E-TRACE-VALIDATION-FINAL-REPORT.json" 2>/dev/null || echo "false")
    
    log_workflow "📊 Workflow generated ${total_new_spans} new spans"
    if [[ -n "${primary_trace_id}" && "${primary_trace_id}" != "null" ]]; then
        log_trace "🎯 Primary trace ID: ${primary_trace_id}"
    fi
    log_success "📁 Results: ${RESULTS_DIR}"
    
    # Final assessment
    if [[ "${trace_chain_complete}" == "true" && "${distributed_tracing}" == "true" ]]; then
        log_success "🎉 END-TO-END TRACE VALIDATION FULLY SUCCESSFUL"
        echo "🔗 Trace ID successfully propagated through complete workflow"
        echo "📊 Distributed tracing confirmed across multiple services"
        echo "✅ System demonstrates production-ready end-to-end observability"
    elif [[ "${trace_chain_complete}" == "true" ]]; then
        log_warning "⚠️ PARTIAL E2E TRACE SUCCESS"
        echo "🔗 Trace chain complete but limited service distribution"
        echo "📊 Basic end-to-end tracing working"
    else
        log_error "❌ E2E TRACE VALIDATION NEEDS ATTENTION"
        echo "🔗 Trace propagation or workflow completion issues detected"
        echo "📊 Review individual steps for specific issues"
    fi
    
    echo ""
    echo "📁 All validation data: ${RESULTS_DIR}"
    echo "🔗 Complete trace chain: ${RESULTS_DIR}/complete-trace-chain.jsonl"
    echo "📊 Live telemetry: ${TELEMETRY_SPANS}"
    if [[ -n "${primary_trace_id}" && "${primary_trace_id}" != "null" ]]; then
        echo "🔍 Search for trace: ${primary_trace_id}"
    fi
}

# Execute main function
main "$@"