#!/bin/bash

# Trace ID Performance Validation Script
# Detects performance issues and inefficiencies in trace ID implementation

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🚀 Trace ID Performance Validation${NC}"
echo -e "${BLUE}==================================${NC}"

# Performance Issue 1: Excessive trace ID generation
echo -e "\n${BLUE}🔍 Checking for excessive trace ID generation...${NC}"
generation_count=$(find . -name "*.ex" -o -name "*.exs" | xargs grep -c "generate.*trace\|trace.*generate" 2>/dev/null | awk -F: '{sum += $2} END {print sum}')
echo -e "${BLUE}ℹ️  INFO: Found $generation_count trace ID generation calls${NC}"

if [[ $generation_count -gt 20 ]]; then
    echo -e "${YELLOW}⚠️  WARNING: High number of trace ID generation calls ($generation_count)${NC}"
    echo -e "   Consider caching or reusing trace IDs where appropriate"
else
    echo -e "${GREEN}✅ Reasonable number of trace ID generation calls${NC}"
fi

# Performance Issue 2: String operations on trace IDs in hot paths
echo -e "\n${BLUE}🔍 Checking for expensive string operations on trace IDs...${NC}"
expensive_ops=$(find . -name "*.ex" -o -name "*.exs" | xargs grep -n "trace_id.*String\.split\|trace_id.*String\.replace\|trace_id.*Regex\." || true)
if [[ -n "$expensive_ops" ]]; then
    echo -e "${YELLOW}⚠️  WARNING: Expensive string operations on trace_id detected${NC}"
    echo "$expensive_ops"
    echo -e "   Consider pre-processing or caching results"
else
    echo -e "${GREEN}✅ No expensive string operations on trace_id found${NC}"
fi

# Performance Issue 3: Trace ID serialization in hot paths
echo -e "\n${BLUE}🔍 Checking for trace ID serialization in performance-critical paths...${NC}"
serialization_ops=$(find . -name "*.ex" -o -name "*.exs" | xargs grep -n -A2 -B2 "Jason\.encode.*trace\|Jason\.decode.*trace" || true)
if [[ -n "$serialization_ops" ]]; then
    echo -e "${YELLOW}⚠️  WARNING: JSON serialization of trace_id detected${NC}"
    echo "$serialization_ops"
    echo -e "   Verify if serialization is necessary in hot paths"
else
    echo -e "${GREEN}✅ No unnecessary trace ID serialization found${NC}"
fi

# Performance Issue 4: Database queries with trace ID in WHERE clauses
echo -e "\n${BLUE}🔍 Checking for trace ID in database queries...${NC}"
db_trace_queries=$(find . -name "*.ex" -o -name "*.exs" | xargs grep -n -i "where.*trace_id\|trace_id.*where" || true)
if [[ -n "$db_trace_queries" ]]; then
    echo -e "${YELLOW}⚠️  WARNING: Database queries filtering by trace_id detected${NC}"
    echo "$db_trace_queries"
    echo -e "   Ensure proper indexing for trace_id columns"
else
    echo -e "${GREEN}✅ No database queries filtering by trace_id found${NC}"
fi

# Performance Issue 5: Telemetry events with large trace contexts
echo -e "\n${BLUE}🔍 Checking for large contexts in telemetry events...${NC}"
large_contexts=$(find . -name "*.ex" -o -name "*.exs" | xargs grep -n -A5 ":telemetry\.execute" | grep -A5 -B5 "trace.*Map\.merge\|Map\.merge.*trace" || true)
if [[ -n "$large_contexts" ]]; then
    echo -e "${YELLOW}⚠️  WARNING: Large context maps in telemetry events${NC}"
    echo "$large_contexts"
    echo -e "   Consider reducing context size for better performance"
else
    echo -e "${GREEN}✅ Telemetry contexts appear reasonably sized${NC}"
fi

# Performance Issue 6: Trace ID validation in every request
echo -e "\n${BLUE}🔍 Checking for trace ID validation frequency...${NC}"
validation_count=$(find . -name "*.ex" -o -name "*.exs" | xargs grep -c "validate.*trace\|trace.*valid" 2>/dev/null | awk -F: '{sum += $2} END {print sum}')
echo -e "${BLUE}ℹ️  INFO: Found $validation_count trace ID validation calls${NC}"

validation_in_loops=$(find . -name "*.ex" -o -name "*.exs" | xargs grep -n -A3 -B3 "Enum\.\|for.*<-" | grep -A3 -B3 "validate.*trace\|trace.*valid" || true)
if [[ -n "$validation_in_loops" ]]; then
    echo -e "${RED}❌ PERFORMANCE ISSUE: Trace ID validation in loops detected${NC}"
    echo "$validation_in_loops"
else
    echo -e "${GREEN}✅ No trace ID validation in loops found${NC}"
fi

# Performance Issue 7: Crypto operations without caching
echo -e "\n${BLUE}🔍 Checking for uncached crypto operations...${NC}"
crypto_calls=$(find . -name "*.ex" -o -name "*.exs" | xargs grep -n ":crypto\.strong_rand_bytes" || true)
crypto_count=$(echo "$crypto_calls" | grep -c "." || echo "0")
echo -e "${BLUE}ℹ️  INFO: Found $crypto_count crypto operations for trace generation${NC}"

if [[ $crypto_count -gt 10 ]]; then
    echo -e "${YELLOW}⚠️  WARNING: Multiple crypto operations for trace generation${NC}"
    echo -e "   Consider using a secure random pool or batch generation"
else
    echo -e "${GREEN}✅ Reasonable use of crypto operations${NC}"
fi

# Performance Issue 8: Trace ID in log messages without guards
echo -e "\n${BLUE}🔍 Checking for unguarded trace ID logging...${NC}"
unguarded_logging=$(find . -name "*.ex" -o -name "*.exs" | xargs grep -n "Logger\." | grep "trace_id" | grep -v "if.*Logger\|unless.*Logger" || true)
unguarded_count=$(echo "$unguarded_logging" | grep -c "." || echo "0")

if [[ $unguarded_count -gt 5 ]]; then
    echo -e "${YELLOW}⚠️  WARNING: Unguarded Logger calls with trace_id ($unguarded_count found)${NC}"
    echo -e "   Consider using Logger level guards for performance"
else
    echo -e "${GREEN}✅ Logger calls with trace_id appear properly guarded${NC}"
fi

# Performance Issue 9: String interpolation in trace contexts
echo -e "\n${BLUE}🔍 Checking for string interpolation in trace contexts...${NC}"
interpolation_in_trace=$(find . -name "*.ex" -o -name "*.exs" | xargs grep -n "#.*trace_id\|trace_id.*#" || true)
if [[ -n "$interpolation_in_trace" ]]; then
    echo -e "${YELLOW}⚠️  WARNING: String interpolation with trace_id detected${NC}"
    echo "$interpolation_in_trace"
    echo -e "   Consider pre-formatting or using structured logging"
else
    echo -e "${GREEN}✅ No problematic string interpolation with trace_id${NC}"
fi

# Performance Issue 10: Trace ID concatenation patterns
echo -e "\n${BLUE}🔍 Checking for inefficient trace ID concatenation...${NC}"
inefficient_concat=$(find . -name "*.ex" -o -name "*.exs" | xargs grep -n "trace_id.*<>.*<>" || true)
if [[ -n "$inefficient_concat" ]]; then
    echo -e "${YELLOW}⚠️  WARNING: Multiple string concatenations with trace_id${NC}"
    echo "$inefficient_concat"
    echo -e "   Consider using IO.iodata_to_binary/1 for better performance"
else
    echo -e "${GREEN}✅ No inefficient trace ID concatenation patterns${NC}"
fi

# Performance Optimization Suggestions
echo -e "\n${BLUE}💡 Performance Optimization Suggestions${NC}"
echo -e "${BLUE}=======================================${NC}"

# Check for potential optimizations
echo -e "\n${BLUE}🔍 Analyzing potential optimizations...${NC}"

# Suggestion 1: Trace ID pooling
trace_generation_frequency=$(find . -name "*.ex" -o -name "*.exs" | xargs grep -c "generate.*trace" 2>/dev/null | sort -nr | head -1 | cut -d: -f2)
if [[ $trace_generation_frequency -gt 5 ]]; then
    echo -e "${YELLOW}💡 SUGGESTION: Consider implementing trace ID pooling${NC}"
    echo -e "   Files with high generation frequency might benefit from pre-generated pools"
fi

# Suggestion 2: Trace context caching
context_merge_count=$(find . -name "*.ex" -o -name "*.exs" | xargs grep -c "Map\.merge.*trace\|trace.*Map\.merge" 2>/dev/null | awk -F: '{sum += $2} END {print sum}')
if [[ $context_merge_count -gt 10 ]]; then
    echo -e "${YELLOW}💡 SUGGESTION: Consider caching merged trace contexts${NC}"
    echo -e "   $context_merge_count context merge operations detected"
fi

# Suggestion 3: Structured logging
structured_logging=$(find . -name "*.ex" -o -name "*.exs" | xargs grep -c "Logger\.metadata.*trace\|trace.*Logger\.metadata" 2>/dev/null | awk -F: '{sum += $2} END {print sum}')
if [[ $structured_logging -lt 3 ]]; then
    echo -e "${YELLOW}💡 SUGGESTION: Consider using Logger.metadata for trace context${NC}"
    echo -e "   Structured logging can improve performance over string interpolation"
fi

# Performance benchmark suggestion
echo -e "\n${BLUE}🏃 Performance Benchmark Recommendations${NC}"
echo -e "${BLUE}========================================${NC}"

benchmark_files=$(find . -name "*benchmark*.exs" | wc -l)
if [[ $benchmark_files -eq 0 ]]; then
    echo -e "${YELLOW}💡 SUGGESTION: Create trace ID performance benchmarks${NC}"
    echo -e "   Benchmark trace generation, validation, and propagation performance"
else
    echo -e "${GREEN}✅ Found $benchmark_files benchmark files${NC}"
fi

# Memory usage check
echo -e "\n${BLUE}🔍 Memory usage considerations...${NC}"
large_trace_contexts=$(find . -name "*.ex" -o -name "*.exs" | xargs grep -n -A10 -B2 "trace.*Map\.put\|Map\.put.*trace" | grep -c "Map\.put" | head -1 || echo "0")
if [[ $large_trace_contexts -gt 20 ]]; then
    echo -e "${YELLOW}⚠️  WARNING: Potentially large trace contexts detected${NC}"
    echo -e "   Consider using selective trace context updates"
else
    echo -e "${GREEN}✅ Trace context sizes appear reasonable${NC}"
fi

echo -e "\n${BLUE}📊 Performance Validation Complete${NC}"
echo -e "${BLUE}==================================${NC}"
echo -e "${GREEN}✅ Review warnings above to optimize trace ID performance${NC}"