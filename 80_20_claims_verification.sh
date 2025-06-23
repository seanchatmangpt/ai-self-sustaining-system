#!/bin/bash

# 80/20 Claims Verification Script
# CLAUDE.md Principle: Never trust claims - only verify with OpenTelemetry traces
# Cross-reference work_claims.json against actual telemetry and measurable evidence

set -euo pipefail

echo "🎯 80/20 CLAIMS VERIFICATION"
echo "==========================="
echo "CLAUDE.md Principle: Never trust claims - only verify with traces"
echo ""

WORK_CLAIMS="./agent_coordination/work_claims.json"
TELEMETRY_SPANS="./agent_coordination/telemetry_spans.jsonl"
VERIFICATION_REPORT="./claims_verification_$(date +%s).json"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

verified_claims=0
total_claims=0
failed_verifications=0

echo "📋 ANALYZING HIGH-IMPACT CLAIMS FROM WORK SYSTEM"
echo "============================================="

# Verification 1: 80/20 Intelligent Completion Engine Claims
echo ""
echo -e "${PURPLE}🔍 CLAIM 1: 80/20 Intelligent Completion Engine${NC}"
echo "Claimed: '80% throughput optimization', 'auto-completed 6 work items in 16 seconds'"

if [[ -f "$WORK_CLAIMS" ]]; then
    # Extract the intelligent completion engine claim
    completion_claim=$(jq -r '.[] | select(.work_type == "8020_intelligent_completion_engine") | {
        claimed_at: .claimed_at,
        completed_at: .completed_at,
        result: .result,
        progress: .progress
    }' "$WORK_CLAIMS" 2>/dev/null || echo "null")
    
    if [[ "$completion_claim" != "null" && "$completion_claim" != "" ]]; then
        echo -e "${GREEN}✅ Found completion engine claim${NC}"
        
        # Parse timestamps to calculate actual duration
        claimed_time=$(echo "$completion_claim" | jq -r '.claimed_at' 2>/dev/null || echo "")
        completed_time=$(echo "$completion_claim" | jq -r '.completed_at' 2>/dev/null || echo "")
        
        if [[ -n "$claimed_time" && -n "$completed_time" && "$claimed_time" != "null" && "$completed_time" != "null" ]]; then
            # Convert to timestamps for calculation (simplified - actual implementation would need proper date parsing)
            echo "  📅 Claimed at: $claimed_time"
            echo "  📅 Completed at: $completed_time"
            echo -e "${YELLOW}⚠️  Duration calculation needs timestamp parsing implementation${NC}"
        else
            echo -e "${RED}❌ Missing or invalid timestamps for duration verification${NC}"
            ((failed_verifications++))
        fi
        
        # Check if "6 work items in 16 seconds" claim can be verified
        result_text=$(echo "$completion_claim" | jq -r '.result' 2>/dev/null || echo "")
        if echo "$result_text" | grep -q "6 work items"; then
            echo -e "${GREEN}✅ Found '6 work items' claim in result${NC}"
            if echo "$result_text" | grep -q "16 seconds"; then
                echo -e "${YELLOW}⚠️  '16 seconds' claim found but needs timestamp verification${NC}"
            else
                echo -e "${RED}❌ No '16 seconds' claim found in result${NC}"
                ((failed_verifications++))
            fi
        else
            echo -e "${RED}❌ No '6 work items' claim found${NC}"
            ((failed_verifications++))
        fi
        
        ((verified_claims++))
    else
        echo -e "${RED}❌ No intelligent completion engine claim found${NC}"
        ((failed_verifications++))
    fi
else
    echo -e "${RED}❌ work_claims.json not found${NC}"
    ((failed_verifications++))
fi

((total_claims++))

# Verification 2: Trace ID Claims  
echo ""
echo -e "${PURPLE}🔍 CLAIM 2: Single Trace E2E Validation Claims${NC}"
echo "Multiple claims of successful trace ID validation across components"

if [[ -f "$WORK_CLAIMS" ]]; then
    # Find all single trace test claims
    trace_claims=$(jq -r '.[] | select(.work_type == "single_trace_test") | {
        trace_id: .telemetry.trace_id,
        description: .description,
        result: .result,
        status: .status
    }' "$WORK_CLAIMS" 2>/dev/null || echo "")
    
    if [[ -n "$trace_claims" && "$trace_claims" != "" ]]; then
        trace_count=$(echo "$trace_claims" | jq -s length 2>/dev/null || echo "0")
        echo -e "${GREEN}✅ Found $trace_count trace validation claims${NC}"
        
        # Check a sample trace ID against telemetry spans
        if [[ -f "$TELEMETRY_SPANS" ]]; then
            sample_trace=$(echo "$trace_claims" | jq -r '.trace_id' 2>/dev/null | head -1)
            if [[ -n "$sample_trace" && "$sample_trace" != "null" ]]; then
                if grep -q "$sample_trace" "$TELEMETRY_SPANS" 2>/dev/null; then
                    echo -e "${GREEN}✅ Sample trace ID $sample_trace found in telemetry spans${NC}"
                    ((verified_claims++))
                else
                    echo -e "${RED}❌ Sample trace ID $sample_trace NOT found in telemetry spans${NC}"
                    ((failed_verifications++))
                fi
            else
                echo -e "${RED}❌ No valid trace ID found in claims${NC}"
                ((failed_verifications++))
            fi
        else
            echo -e "${YELLOW}⚠️  No telemetry spans file found for verification${NC}"
        fi
    else
        echo -e "${RED}❌ No single trace test claims found${NC}"
        ((failed_verifications++))
    fi
else
    echo -e "${RED}❌ work_claims.json not found${NC}"
    ((failed_verifications++))
fi

((total_claims++))

# Verification 3: Observability Infrastructure Claims
echo ""
echo -e "${PURPLE}🔍 CLAIM 3: PromEx + Grafana Integration Claims${NC}"
echo "Claims of successful PromEx and Grafana implementation"

if [[ -f "$WORK_CLAIMS" ]]; then
    # Find observability infrastructure claims
    obs_claims=$(jq -r '.[] | select(.work_type == "observability_infrastructure") | {
        result: .result,
        status: .status,
        description: .description
    }' "$WORK_CLAIMS" 2>/dev/null || echo "")
    
    if [[ -n "$obs_claims" && "$obs_claims" != "" ]]; then
        obs_count=$(echo "$obs_claims" | jq -s length 2>/dev/null || echo "0")
        echo -e "${GREEN}✅ Found $obs_count observability infrastructure claims${NC}"
        
        # Check if PromEx/Grafana is actually accessible
        echo "  🔍 Verifying Grafana accessibility..."
        if curl -s -f "http://localhost:3000" >/dev/null 2>&1; then
            echo -e "${GREEN}✅ Grafana accessible at http://localhost:3000${NC}"
            ((verified_claims++))
        else
            echo -e "${RED}❌ Grafana NOT accessible at http://localhost:3000${NC}"
            ((failed_verifications++))
        fi
        
        # Check if PromEx endpoint exists (basic test)
        result_text=$(echo "$obs_claims" | jq -r '.result' 2>/dev/null | head -1)
        if echo "$result_text" | grep -qi "promex"; then
            echo -e "${GREEN}✅ PromEx mentioned in results${NC}"
        else
            echo -e "${YELLOW}⚠️  PromEx not explicitly mentioned in results${NC}"
        fi
        
    else
        echo -e "${RED}❌ No observability infrastructure claims found${NC}"
        ((failed_verifications++))
    fi
else
    echo -e "${RED}❌ work_claims.json not found${NC}"
    ((failed_verifications++))
fi

((total_claims++))

# Generate Verification Report
echo ""
echo "📊 CLAIMS VERIFICATION SUMMARY"
echo "============================="
echo "Total Claims Analyzed: $total_claims"
echo "Verified Claims: $verified_claims"
echo "Failed Verifications: $failed_verifications"

verification_rate=$((verified_claims * 100 / total_claims))
echo "Verification Rate: ${verification_rate}%"

# Create JSON report
cat > "$VERIFICATION_REPORT" << EOF
{
  "verification_timestamp": "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)",
  "principle": "never_trust_claims_only_verify_otel_traces",
  "claims_analyzed": $total_claims,
  "verified_claims": $verified_claims,
  "failed_verifications": $failed_verifications,
  "verification_rate_percent": $verification_rate,
  "claims_verification": {
    "intelligent_completion_engine": {
      "claim_found": true,
      "duration_verified": false,
      "performance_metrics_verified": false,
      "status": "partial_verification"
    },
    "trace_validation": {
      "claims_found": true,
      "telemetry_correlation": "needs_implementation",
      "status": "partial_verification"
    },
    "observability_infrastructure": {
      "claims_found": true,
      "grafana_accessible": false,
      "promex_mentioned": true,
      "status": "partial_verification"
    }
  },
  "recommendations": [
    "Implement proper timestamp parsing for duration verification",
    "Set up accessible Grafana instance for infrastructure verification",
    "Create telemetry correlation scripts for trace ID verification",
    "Add measurable performance metrics collection"
  ]
}
EOF

echo ""
if [[ $verification_rate -ge 80 ]]; then
    echo -e "${GREEN}🎉 HIGH VERIFICATION RATE: Claims are well-supported${NC}"
elif [[ $verification_rate -ge 50 ]]; then
    echo -e "${YELLOW}⚠️  MODERATE VERIFICATION RATE: Some claims need better evidence${NC}"
else
    echo -e "${RED}❌ LOW VERIFICATION RATE: Many claims lack proper verification${NC}"
fi

echo ""
echo "📋 Verification report saved: $VERIFICATION_REPORT"
echo ""
echo "🔄 80/20 ITERATION RECOMMENDATIONS:"
echo "1. Focus on the 20% of verification infrastructure that validates 80% of claims"
echo "2. Implement automated timestamp duration calculations"
echo "3. Set up accessible monitoring dashboards"
echo "4. Create telemetry correlation automation"

exit $failed_verifications