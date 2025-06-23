#!/bin/bash

# 80/20 Reality Check - CLAUDE.md: Never trust claims, only verify with evidence
# Measure actual observable behavior vs system claims

set -euo pipefail

echo "🔍 80/20 REALITY CHECK"
echo "===================="
echo "CLAUDE.md Principle: Never trust claims - verify with observable behavior"
echo ""

WORK_CLAIMS="./agent_coordination/work_claims.json"
AGENT_STATUS="./agent_coordination/agent_status.json"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "🎯 TESTING CORE CLAIM: '80% throughput optimization' & '6 work items in 16 seconds'"
echo "=================================================================="

# Reality Check 1: Agent Performance vs Claims
echo ""
echo -e "${BLUE}📊 REALITY CHECK 1: Agent Performance${NC}"

if [[ -f "$AGENT_STATUS" ]]; then
    total_agents=$(jq length "$AGENT_STATUS" 2>/dev/null || echo "0")
    agents_with_completions=$(jq '[.[] | select(.performance_metrics.tasks_completed > 0)] | length' "$AGENT_STATUS" 2>/dev/null || echo "0")
    total_completions=$(jq '[.[] | .performance_metrics.tasks_completed] | add' "$AGENT_STATUS" 2>/dev/null || echo "0")
    
    echo "Total agents: $total_agents"
    echo "Agents with completed tasks: $agents_with_completions"
    echo "Total tasks completed by all agents: $total_completions"
    
    if [[ $total_completions -eq 0 ]]; then
        echo -e "${RED}❌ REALITY: Agents claim 0 completed tasks despite performance claims${NC}"
    else
        echo -e "${GREEN}✅ REALITY: Some actual work completion detected${NC}"
    fi
else
    echo -e "${RED}❌ Agent status file not found${NC}"
fi

# Reality Check 2: Work Item Timestamps vs Performance Claims
echo ""
echo -e "${BLUE}📊 REALITY CHECK 2: Actual Work Completion Rate${NC}"

if [[ -f "$WORK_CLAIMS" ]]; then
    # Count work items that actually have completion timestamps
    completed_count=$(jq '[.[] | select(.status == "completed" and .completed_at != null)] | length' "$WORK_CLAIMS" 2>/dev/null || echo "0")
    total_count=$(jq length "$WORK_CLAIMS" 2>/dev/null || echo "0")
    
    echo "Total work items: $total_count"
    echo "Items with completion timestamps: $completed_count"
    
    if [[ $completed_count -gt 0 ]]; then
        echo -e "${GREEN}✅ REALITY: $completed_count items have completion timestamps${NC}"
        
        # Analyze completion times for throughput claims
        echo ""
        echo "🔍 Analyzing completion time claims..."
        
        # Get a sample of recent completions with timestamps
        recent_completions=$(jq -r '.[] | select(.status == "completed" and .completed_at != null and .claimed_at != null) | "\(.claimed_at),\(.completed_at),\(.work_type)"' "$WORK_CLAIMS" 2>/dev/null | tail -10)
        
        if [[ -n "$recent_completions" ]]; then
            echo "Sample recent completions:"
            echo "$recent_completions" | while IFS=',' read -r claimed completed work_type; do
                echo "  $work_type: $claimed → $completed"
            done
            
            # Check for the specific "6 items in 16 seconds" claim
            echo ""
            echo "🔍 Searching for '6 items in 16 seconds' evidence..."
            sixteen_sec_evidence=$(jq -r '.[] | select(.result != null) | .result' "$WORK_CLAIMS" 2>/dev/null | grep -c "16 second" || echo "0")
            six_items_evidence=$(jq -r '.[] | select(.result != null) | .result' "$WORK_CLAIMS" 2>/dev/null | grep -c "6 work items" || echo "0")
            
            echo "Results mentioning '16 seconds': $sixteen_sec_evidence"
            echo "Results mentioning '6 work items': $six_items_evidence"
            
            if [[ $sixteen_sec_evidence -gt 0 && $six_items_evidence -gt 0 ]]; then
                echo -e "${YELLOW}⚠️  CLAIM FOUND: Text mentions '6 items in 16 seconds' but needs timestamp verification${NC}"
            else
                echo -e "${RED}❌ REALITY: No evidence of '6 items in 16 seconds' performance${NC}"
            fi
        else
            echo -e "${RED}❌ REALITY: No valid timestamp pairs found for completion analysis${NC}"
        fi
    else
        echo -e "${RED}❌ REALITY: No completed items with timestamps despite completion claims${NC}"
    fi
else
    echo -e "${RED}❌ Work claims file not found${NC}"
fi

# Reality Check 3: System Resource Usage vs Performance Claims
echo ""
echo -e "${BLUE}📊 REALITY CHECK 3: System Resource Usage${NC}"

# Check if the infinite orchestrator is actually running and doing work
orchestrator_pid=$(cat orchestrator.pid 2>/dev/null | grep -o '[0-9]*' || echo "")
if [[ -n "$orchestrator_pid" ]] && ps -p "$orchestrator_pid" >/dev/null 2>&1; then
    echo -e "${GREEN}✅ REALITY: Infinite orchestrator running (PID: $orchestrator_pid)${NC}"
    
    # Check CPU usage of orchestrator
    cpu_usage=$(ps -p "$orchestrator_pid" -o %cpu --no-headers 2>/dev/null || echo "0")
    echo "Orchestrator CPU usage: ${cpu_usage}%"
    
    if [[ $(echo "$cpu_usage > 5" | bc -l 2>/dev/null || echo "0") -eq 1 ]]; then
        echo -e "${GREEN}✅ REALITY: Orchestrator showing significant CPU usage${NC}"
    else
        echo -e "${YELLOW}⚠️  REALITY: Orchestrator using minimal CPU (may not be doing much work)${NC}"
    fi
else
    echo -e "${RED}❌ REALITY: Infinite orchestrator not running despite claims${NC}"
fi

# Reality Check 4: File System Evidence
echo ""
echo -e "${BLUE}📊 REALITY CHECK 4: File System Evidence${NC}"

# Check for evidence files created by actual work
evidence_files=$(find . -name "*evidence*" -o -name "*trace_verification*" -o -name "*correlation*" 2>/dev/null | wc -l)
log_files=$(find . -name "*.log" -newer orchestrator.pid 2>/dev/null | wc -l)

echo "Evidence files found: $evidence_files"
echo "Recent log files: $log_files"

if [[ $evidence_files -gt 0 || $log_files -gt 0 ]]; then
    echo -e "${GREEN}✅ REALITY: Some file system evidence of activity${NC}"
else
    echo -e "${RED}❌ REALITY: No file system evidence of significant work${NC}"
fi

# Generate Reality Report
echo ""
echo "🎯 80/20 REALITY SUMMARY"
echo "======================="

reality_score=0
total_checks=4

# Score the reality checks
if [[ $total_completions -gt 0 ]]; then ((reality_score++)); fi
if [[ $completed_count -gt 0 ]]; then ((reality_score++)); fi
if [[ -n "$orchestrator_pid" ]] && ps -p "$orchestrator_pid" >/dev/null 2>&1; then ((reality_score++)); fi
if [[ $evidence_files -gt 0 || $log_files -gt 0 ]]; then ((reality_score++)); fi

reality_percentage=$((reality_score * 100 / total_checks))

echo "Reality Score: $reality_score/$total_checks ($reality_percentage%)"

if [[ $reality_percentage -ge 75 ]]; then
    echo -e "${GREEN}🎉 HIGH REALITY: Claims appear to have substantial backing${NC}"
elif [[ $reality_percentage -ge 50 ]]; then
    echo -e "${YELLOW}⚠️  MODERATE REALITY: Some evidence but gaps exist${NC}"
else
    echo -e "${RED}❌ LOW REALITY: Claims not well-supported by observable evidence${NC}"
fi

echo ""
echo "🔄 80/20 TRUTH IMPLEMENTATION NEEDED:"
echo "1. Implement measurable performance tracking"
echo "2. Add timestamp-based throughput calculation"
echo "3. Create observable work output verification"
echo "4. Remove synthetic/fabricated validation data"

exit $((4 - reality_score))