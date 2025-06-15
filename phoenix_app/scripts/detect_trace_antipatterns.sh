#!/bin/bash

# Trace ID Anti-pattern Detection Script
# Detects common poor implementations and anti-patterns in trace ID usage

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔍 Detecting Trace ID Anti-patterns${NC}"
echo -e "${BLUE}===================================${NC}"

# Anti-pattern 1: Trace ID generation in loops
echo -e "\n${BLUE}🔍 Checking for trace ID generation in loops...${NC}"
loop_generation=$(find . -name "*.ex" -o -name "*.exs" | xargs grep -n -A5 -B5 "Enum\.\|for.*<-" | grep -A5 -B5 "generate.*trace\|trace.*generate" || true)
if [[ -n "$loop_generation" ]]; then
    echo -e "${RED}❌ ANTI-PATTERN: Trace ID generation in loops detected${NC}"
    echo "$loop_generation"
else
    echo -e "${GREEN}✅ No trace ID generation in loops found${NC}"
fi

# Anti-pattern 2: Trace ID mutation
echo -e "\n${BLUE}🔍 Checking for trace ID mutation...${NC}"
trace_mutation=$(find . -name "*.ex" -o -name "*.exs" | xargs grep -n "trace_id.*=.*Map\.put\|Map\.put.*trace_id\|trace_id.*String\.replace" || true)
if [[ -n "$trace_mutation" ]]; then
    echo -e "${RED}❌ ANTI-PATTERN: Trace ID mutation detected${NC}"
    echo "$trace_mutation"
else
    echo -e "${GREEN}✅ No trace ID mutation found${NC}"
fi

# Anti-pattern 3: Synchronous trace ID operations in async contexts
echo -e "\n${BLUE}🔍 Checking for synchronous trace operations in async contexts...${NC}"
async_trace_issues=$(find . -name "*.ex" -o -name "*.exs" | xargs grep -n -A3 -B3 "Task\.async" | grep -A3 -B3 "trace_id.*File\.\|trace_id.*GenServer\.call" || true)
if [[ -n "$async_trace_issues" ]]; then
    echo -e "${YELLOW}⚠️  WARNING: Potentially blocking trace operations in async contexts${NC}"
    echo "$async_trace_issues"
else
    echo -e "${GREEN}✅ No blocking trace operations in async contexts${NC}"
fi

# Anti-pattern 4: Missing trace context in error tuples
echo -e "\n${BLUE}🔍 Checking for error tuples without trace context...${NC}"
error_without_trace=$(find . -name "*.ex" -o -name "*.exs" | xargs grep -n -A2 -B2 "{:error," | grep -v "trace_id\|trace" | head -10 || true)
if [[ -n "$error_without_trace" ]]; then
    echo -e "${YELLOW}⚠️  WARNING: Error tuples without trace context found${NC}"
    echo "$error_without_trace"
    echo "... (showing first 10 matches)"
else
    echo -e "${GREEN}✅ Error tuples include appropriate trace context${NC}"
fi

# Anti-pattern 5: String concatenation for trace IDs
echo -e "\n${BLUE}🔍 Checking for string concatenation in trace ID generation...${NC}"
string_concat_trace=$(find . -name "*.ex" -o -name "*.exs" | xargs grep -n "trace_id.*<>\|<>.*trace_id" | grep -v "generate_trace_id" || true)
if [[ -n "$string_concat_trace" ]]; then
    echo -e "${YELLOW}⚠️  WARNING: String concatenation with trace_id found${NC}"
    echo "$string_concat_trace"
else
    echo -e "${GREEN}✅ No problematic string concatenation with trace_id${NC}"
fi

# Anti-pattern 6: Trace ID in GenServer state without proper handling
echo -e "\n${BLUE}🔍 Checking for trace ID in GenServer state...${NC}"
genserver_trace_state=$(find . -name "*.ex" -o -name "*.exs" | xargs grep -n -A5 -B5 "defmodule.*GenServer\|use GenServer" | grep -A10 -B10 "trace_id" || true)
if [[ -n "$genserver_trace_state" ]]; then
    echo -e "${YELLOW}⚠️  WARNING: Trace ID in GenServer state - ensure proper lifecycle management${NC}"
    echo "$genserver_trace_state"
else
    echo -e "${GREEN}✅ No trace ID in GenServer state detected${NC}"
fi

# Anti-pattern 7: Trace ID comparison using == instead of proper validation
echo -e "\n${BLUE}🔍 Checking for unsafe trace ID comparisons...${NC}"
unsafe_comparisons=$(find . -name "*.ex" -o -name "*.exs" | xargs grep -n "trace_id.*==.*\"" | grep -v "_test\.exs" || true)
if [[ -n "$unsafe_comparisons" ]]; then
    echo -e "${YELLOW}⚠️  WARNING: Direct string comparison of trace_id in production code${NC}"
    echo "$unsafe_comparisons"
else
    echo -e "${GREEN}✅ No unsafe trace ID comparisons found${NC}"
fi

# Anti-pattern 8: Missing trace context in multi-process communication
echo -e "\n${BLUE}🔍 Checking for missing trace context in process communication...${NC}"
process_comm_without_trace=$(find . -name "*.ex" -o -name "*.exs" | xargs grep -n -A3 -B3 "GenServer\.call\|GenServer\.cast\|send(" | grep -v "trace_id\|trace" | head -5 || true)
if [[ -n "$process_comm_without_trace" ]]; then
    echo -e "${YELLOW}⚠️  INFO: Process communication without explicit trace context${NC}"
    echo "$process_comm_without_trace"
    echo "... (showing first 5 matches - verify if trace context needed)"
else
    echo -e "${GREEN}✅ Process communication includes trace context where appropriate${NC}"
fi

# Anti-pattern 9: Hardcoded trace ID formats
echo -e "\n${BLUE}🔍 Checking for hardcoded trace ID formats...${NC}"
hardcoded_formats=$(find . -name "*.ex" -o -name "*.exs" | xargs grep -n "\".*-.*-.*\"" | grep -v "_test\.exs" | grep "trace\|reactor" || true)
if [[ -n "$hardcoded_formats" ]]; then
    echo -e "${RED}❌ ANTI-PATTERN: Hardcoded trace ID formats detected${NC}"
    echo "$hardcoded_formats"
else
    echo -e "${GREEN}✅ No hardcoded trace ID formats found${NC}"
fi

# Anti-pattern 10: Trace ID in function names (should be parameters)
echo -e "\n${BLUE}🔍 Checking for trace ID in function names...${NC}"
trace_in_function_names=$(find . -name "*.ex" -o -name "*.exs" | xargs grep -n "def.*trace_id.*(" | grep -v "generate_trace_id\|extract_trace_id\|validate_trace_id" || true)
if [[ -n "$trace_in_function_names" ]]; then
    echo -e "${YELLOW}⚠️  WARNING: Functions with trace_id in name - consider parameters instead${NC}"
    echo "$trace_in_function_names"
else
    echo -e "${GREEN}✅ Function names follow good trace ID patterns${NC}"
fi

# Anti-pattern 11: Missing trace propagation in pipe operations
echo -e "\n${BLUE}🔍 Checking for missing trace context in pipe operations...${NC}"
pipe_without_trace=$(find . -name "*.ex" -o -name "*.exs" | xargs grep -n -A5 -B1 "|>" | grep -A5 -B1 "context\|trace" | grep -B1 -A5 "|>" | grep -v "trace_id\|context" | head -5 || true)
if [[ -n "$pipe_without_trace" ]]; then
    echo -e "${BLUE}ℹ️  INFO: Pipe operations detected - verify trace context propagation${NC}"
    echo "Manual review recommended for complex pipe chains"
else
    echo -e "${GREEN}✅ Pipe operations appear to handle context appropriately${NC}"
fi

# Anti-pattern 12: Trace ID validation without proper error handling
echo -e "\n${BLUE}🔍 Checking for trace ID validation without error handling...${NC}"
validation_without_errors=$(find . -name "*.ex" -o -name "*.exs" | xargs grep -n -A3 -B1 "String\.starts_with.*trace\|String\.contains.*trace" | grep -v "rescue\|catch\|{:error" || true)
if [[ -n "$validation_without_errors" ]]; then
    echo -e "${YELLOW}⚠️  WARNING: Trace ID validation without error handling${NC}"
    echo "$validation_without_errors"
else
    echo -e "${GREEN}✅ Trace ID validation includes proper error handling${NC}"
fi

echo -e "\n${BLUE}📊 Anti-pattern Detection Complete${NC}"
echo -e "${BLUE}===================================${NC}"
echo -e "${GREEN}✅ Review any warnings above to improve trace ID implementation quality${NC}"