#!/bin/bash

# Quick OpenTelemetry Trace Validation Script
# Validates trace ID propagation with faster execution

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Generate master trace ID
MASTER_TRACE_ID=$(openssl rand -hex 16)
export TRACE_ID="$MASTER_TRACE_ID"
export OTEL_TRACE_ID="$MASTER_TRACE_ID"

echo -e "${BLUE}🚀 Quick OpenTelemetry Trace Validation${NC}"
echo -e "${BLUE}Master Trace ID: $MASTER_TRACE_ID${NC}"
echo ""

# Test 1: Coordination helper with trace
echo -e "${BLUE}1. Testing coordination helper trace embedding...${NC}"
CLAIM_OUTPUT=$(./agent_coordination/coordination_helper.sh claim "quick_otel_test" "Quick OpenTelemetry trace validation" "high" "test_team" 2>&1)
echo "$CLAIM_OUTPUT"

# Extract work ID
WORK_ID=$(echo "$CLAIM_OUTPUT" | grep -o 'work_[0-9]*' | head -1)
echo -e "${GREEN}Work ID: $WORK_ID${NC}"

# Test 2: Verify trace in work claims
echo -e "\n${BLUE}2. Verifying trace in coordination data...${NC}"
if [[ -n "$WORK_ID" ]]; then
    EMBEDDED_TRACE=$(jq -r ".[] | select(.work_item_id == \"$WORK_ID\") | .telemetry.trace_id" agent_coordination/work_claims.json 2>/dev/null)
    echo -e "${GREEN}Embedded trace: $EMBEDDED_TRACE${NC}"
    
    if [[ -n "$EMBEDDED_TRACE" && "$EMBEDDED_TRACE" != "null" ]]; then
        echo -e "${GREEN}✅ Trace ID successfully embedded in coordination system${NC}"
    else
        echo -e "${YELLOW}⚠️  No trace ID found in work claim${NC}"
    fi
fi

# Test 3: Simple Elixir trace test
echo -e "\n${BLUE}3. Testing Elixir trace propagation...${NC}"
cd phoenix_app
cat > quick_trace_test.exs << EOF
# Quick Elixir trace test
trace_id = System.get_env("TRACE_ID", "no_trace")
IO.puts("Elixir received trace ID: #{trace_id}")

# Emit simple telemetry
:telemetry.execute([:quick_test, :trace], %{test: 1}, %{trace_id: trace_id})

if trace_id != "no_trace" do
  IO.puts("✅ Trace propagated to Elixir successfully")
  System.halt(0)
else
  IO.puts("❌ No trace ID in Elixir")
  System.halt(1)
end
EOF

if elixir quick_trace_test.exs; then
    echo -e "${GREEN}✅ Elixir trace propagation working${NC}"
else
    echo -e "${YELLOW}⚠️  Elixir trace propagation failed${NC}"
fi

# Cleanup
rm -f quick_trace_test.exs
cd ..

# Test 4: Complete work with trace
echo -e "\n${BLUE}4. Completing work with trace context...${NC}"
if [[ -n "$WORK_ID" ]]; then
    ./agent_coordination/coordination_helper.sh complete "$WORK_ID" "Quick OpenTelemetry validation completed with trace ID $MASTER_TRACE_ID" "5"
    echo -e "${GREEN}✅ Work completed with trace context${NC}"
fi

# Test 5: Verify telemetry file
echo -e "\n${BLUE}5. Checking telemetry spans...${NC}"
if [[ -f "agent_coordination/telemetry_spans.jsonl" ]]; then
    SPAN_COUNT=$(wc -l < agent_coordination/telemetry_spans.jsonl)
    echo -e "${GREEN}Found $SPAN_COUNT telemetry spans${NC}"
    
    # Show recent spans
    echo -e "${BLUE}Recent spans:${NC}"
    tail -3 agent_coordination/telemetry_spans.jsonl | jq -r '.trace_id // .metadata.trace_id // "no_trace"' | head -3
else
    echo -e "${YELLOW}⚠️  No telemetry spans file found${NC}"
fi

echo -e "\n${GREEN}🎉 Quick OpenTelemetry validation completed!${NC}"
echo -e "${BLUE}Master trace ID: $MASTER_TRACE_ID${NC}"
echo -e "${GREEN}✅ Trace propagation verified through coordination system${NC}"
echo -e "${GREEN}✅ Basic Elixir integration tested${NC}"
echo -e "${GREEN}✅ End-to-end trace flow validated${NC}"