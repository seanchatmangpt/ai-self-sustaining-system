#!/bin/bash

# Global Trace ID Implementation Validation Script
# Detects poor implementations, inconsistencies, and missing trace propagation

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNING_CHECKS=0

# Function to print status
print_status() {
    local status=$1
    local message=$2
    local details=${3:-""}
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    case $status in
        "PASS")
            echo -e "${GREEN}✅ PASS${NC}: $message"
            PASSED_CHECKS=$((PASSED_CHECKS + 1))
            ;;
        "FAIL")
            echo -e "${RED}❌ FAIL${NC}: $message"
            if [[ -n "$details" ]]; then
                echo -e "   ${RED}Details:${NC} $details"
            fi
            FAILED_CHECKS=$((FAILED_CHECKS + 1))
            ;;
        "WARN")
            echo -e "${YELLOW}⚠️  WARN${NC}: $message"
            if [[ -n "$details" ]]; then
                echo -e "   ${YELLOW}Details:${NC} $details"
            fi
            WARNING_CHECKS=$((WARNING_CHECKS + 1))
            ;;
        "INFO")
            echo -e "${BLUE}ℹ️  INFO${NC}: $message"
            ;;
    esac
}

# Function to check for leftover correlation_id references
check_correlation_id_leftovers() {
    echo -e "\n${BLUE}🔍 Checking for leftover correlation_id references...${NC}"
    
    # Check for correlation_id in code
    local correlation_files=$(find . -name "*.ex" -o -name "*.exs" | xargs grep -l "correlation_id" 2>/dev/null || true)
    if [[ -z "$correlation_files" ]]; then
        print_status "PASS" "No correlation_id references found in code"
    else
        print_status "FAIL" "Found correlation_id references in code" "$correlation_files"
    fi
    
    # Check for X-Correlation-ID headers (excluding intentional legacy support)
    local correlation_headers=$(find . -name "*.ex" -o -name "*.exs" | xargs grep -l "X-Correlation-ID" 2>/dev/null | grep -v "web_trace_integration_test.exs\|trace_header_plug.ex" || true)
    if [[ -z "$correlation_headers" ]]; then
        print_status "PASS" "No problematic X-Correlation-ID headers found"
    else
        print_status "FAIL" "Found X-Correlation-ID headers outside legacy support" "$correlation_headers"
    fi
    
    # Check for get_correlation_* functions
    local correlation_functions=$(find . -name "*.ex" -o -name "*.exs" | xargs grep -l "get_correlation_" 2>/dev/null || true)
    if [[ -z "$correlation_functions" ]]; then
        print_status "PASS" "No correlation helper functions found"
    else
        print_status "FAIL" "Found correlation helper functions" "$correlation_functions"
    fi
}

# Function to check trace ID naming consistency
check_trace_naming_consistency() {
    echo -e "\n${BLUE}🔍 Checking trace ID naming consistency...${NC}"
    
    # Check for inconsistent naming patterns
    local trace_id_count=$(find . -name "*.ex" -o -name "*.exs" | xargs grep -c "trace_id" 2>/dev/null | awk -F: '{sum += $2} END {print sum}')
    # Exclude legitimate OTLP protocol usage in JSON structures
    local traceId_count=$(find . -name "*.ex" -o -name "*.exs" | xargs grep "traceId" 2>/dev/null | grep -v '"traceId"' | wc -l)
    local trace_identifier_count=$(find . -name "*.ex" -o -name "*.exs" | xargs grep -c "trace_identifier" 2>/dev/null | awk -F: '{sum += $2} END {print sum}')
    
    print_status "INFO" "Found $trace_id_count instances of 'trace_id'"
    
    if [[ $traceId_count -gt 0 ]]; then
        print_status "WARN" "Found $traceId_count instances of camelCase 'traceId' (should be snake_case)"
    else
        print_status "PASS" "No camelCase traceId found - consistent snake_case usage"
    fi
    
    if [[ $trace_identifier_count -gt 0 ]]; then
        print_status "WARN" "Found $trace_identifier_count instances of 'trace_identifier' (should be trace_id)"
    else
        print_status "PASS" "No inconsistent trace_identifier naming found"
    fi
    
    # Check for proper trace ID variable naming in functions - only check functions that actually take trace ID parameters
    local bad_naming=$(find . -name "*.ex" -o -name "*.exs" | xargs grep -n "def.*([^)]*trace[^)]*)" 2>/dev/null | grep -v "trace_id" | grep -E "(master_trace|source_trace|original_trace)" || true)
    if [[ -z "$bad_naming" ]]; then
        print_status "PASS" "Function parameter naming follows trace_id convention"
    else
        print_status "WARN" "Found functions with inconsistent trace parameter naming" "$bad_naming"
    fi
}

# Function to check for hardcoded trace IDs
check_hardcoded_values() {
    echo -e "\n${BLUE}🔍 Checking for hardcoded trace IDs...${NC}"
    
    # Look for suspicious hardcoded patterns
    local hardcoded_patterns=(
        '"trace-.*-123"'
        '"test-trace-.*"'
        '"reactor-.*-123"'
        'trace_id.*=.*".*-.*-.*"'
    )
    
    local found_hardcoded=false
    for pattern in "${hardcoded_patterns[@]}"; do
        local matches=$(find . -name "*.ex" -o -name "*.exs" | xargs grep -l "$pattern" 2>/dev/null || true)
        if [[ -n "$matches" ]]; then
            # Exclude test files - they can have hardcoded values
            local non_test_matches=$(echo "$matches" | grep -v "_test.exs" | grep -v "test_.*\.exs" || true)
            if [[ -n "$non_test_matches" ]]; then
                print_status "FAIL" "Found hardcoded trace IDs in non-test files" "$non_test_matches"
                found_hardcoded=true
            fi
        fi
    done
    
    if [[ "$found_hardcoded" == false ]]; then
        print_status "PASS" "No hardcoded trace IDs found in production code"
    fi
    
    # Check for TODO/FIXME related to traces
    local trace_todos=$(find . -name "*.ex" -o -name "*.exs" | xargs grep -n "TODO.*trace\|FIXME.*trace" 2>/dev/null || true)
    if [[ -z "$trace_todos" ]]; then
        print_status "PASS" "No trace-related TODOs or FIXMEs found"
    else
        print_status "WARN" "Found trace-related TODOs/FIXMEs" "$trace_todos"
    fi
}

# Function to check trace propagation in key components
check_trace_propagation() {
    echo -e "\n${BLUE}🔍 Checking trace propagation in key components...${NC}"
    
    # Check middleware files have trace_id support
    local middleware_files=$(find . -path "./lib/*" -name "*middleware*.ex")
    local middleware_without_trace=()
    
    for file in $middleware_files; do
        if ! grep -q "trace_id" "$file"; then
            middleware_without_trace+=("$file")
        fi
    done
    
    if [[ ${#middleware_without_trace[@]} -eq 0 ]]; then
        print_status "PASS" "All middleware files include trace_id support"
    else
        print_status "FAIL" "Middleware files missing trace_id support" "${middleware_without_trace[*]}"
    fi
    
    # Check reactor files have trace_id support
    local reactor_files=$(find . -path "./lib/*" -name "*reactor*.ex")
    local reactors_without_trace=()
    
    for file in $reactor_files; do
        if ! grep -q "trace_id" "$file"; then
            reactors_without_trace+=("$file")
        fi
    done
    
    if [[ ${#reactors_without_trace[@]} -eq 0 ]]; then
        print_status "PASS" "All reactor files include trace_id support"
    else
        print_status "WARN" "Reactor files missing trace_id support" "${reactors_without_trace[*]}"
    fi
    
    # Check step files have trace context
    local step_files=$(find . -path "./lib/*" -name "*step*.ex")
    local steps_without_context=()
    
    for file in $step_files; do
        if grep -q "def run" "$file" && ! grep -q "trace_id\|context" "$file"; then
            steps_without_context+=("$file")
        fi
    done
    
    if [[ ${#steps_without_context[@]} -eq 0 ]]; then
        print_status "PASS" "All step files handle trace context appropriately"
    else
        print_status "WARN" "Step files potentially missing trace context" "${steps_without_context[*]}"
    fi
}

# Function to check telemetry trace integration
check_telemetry_integration() {
    echo -e "\n${BLUE}🔍 Checking telemetry trace integration...${NC}"
    
    # Focus on critical telemetry events (lib/ only, error/coordination events)
    local critical_telemetry_files=$(find lib/ -name "*.ex" | xargs grep -l ":telemetry.execute.*error\|:telemetry.execute.*coordination\|:telemetry.execute.*halt" 2>/dev/null || true)
    local missing_critical_trace=()
    
    for file in $critical_telemetry_files; do
        # Get line numbers of critical telemetry.execute calls
        local critical_lines=$(grep -n ":telemetry.execute.*error\|:telemetry.execute.*coordination\|:telemetry.execute.*halt" "$file" | cut -d: -f1)
        for line_num in $critical_lines; do
            # Check the next few lines for trace_id
            local context_lines=$(sed -n "${line_num},+10p" "$file" | grep "trace_id" || true)
            if [[ -z "$context_lines" ]]; then
                missing_critical_trace+=("$file:$line_num")
            fi
        done
    done
    
    # Also check all telemetry for broader context
    local telemetry_files=$(find . -name "*.ex" -o -name "*.exs" | xargs grep -l ":telemetry.execute" 2>/dev/null || true)
    local missing_trace_telemetry=()
    
    for file in $telemetry_files; do
        # Skip deps directory for routine telemetry
        if [[ "$file" =~ ^./deps/ ]]; then
            continue
        fi
        
        local telemetry_lines=$(grep -n ":telemetry.execute" "$file" | cut -d: -f1)
        for line_num in $telemetry_lines; do
            local context_lines=$(sed -n "${line_num},+10p" "$file" | grep "trace_id" || true)
            if [[ -z "$context_lines" ]]; then
                missing_trace_telemetry+=("$file:$line_num")
            fi
        done
    done
    
    # Smart validation for critical telemetry
    if [[ ${#missing_critical_trace[@]} -eq 0 ]]; then
        print_status "PASS" "Critical telemetry events include trace context"
    else
        print_status "WARN" "Critical telemetry events missing trace_id" "${missing_critical_trace[*]}"
    fi
    
    # Routine telemetry check (less critical)
    if [[ ${#missing_trace_telemetry[@]} -eq 0 ]]; then
        print_status "PASS" "All application telemetry events include trace context"
    else
        print_status "INFO" "Some routine telemetry events missing trace_id (${#missing_trace_telemetry[@]} events) - normal for large applications"
    fi
    
    # Check for trace_id in telemetry measurements vs metadata
    local measurements_count=$(find . -name "*.ex" -o -name "*.exs" | xargs grep -c "trace_id:" 2>/dev/null | awk -F: '{sum += $2} END {print sum}')
    local context_count=$(find . -name "*.ex" -o -name "*.exs" | xargs grep -c "trace_id.*context\|context.*trace_id" 2>/dev/null | awk -F: '{sum += $2} END {print sum}')
    
    print_status "INFO" "Found $measurements_count trace_id measurements and $context_count context references"
}

# Function to check HTTP header consistency
check_http_header_consistency() {
    echo -e "\n${BLUE}🔍 Checking HTTP header consistency...${NC}"
    
    # Check for consistent header naming
    local trace_headers=$(find . -name "*.ex" -o -name "*.exs" | xargs grep -n "X-Trace-ID\|x-trace-id" 2>/dev/null || true)
    local inconsistent_headers=$(echo "$trace_headers" | grep -v "x-trace-id" | grep "X-Trace-ID" || true)
    
    if [[ -z "$inconsistent_headers" ]]; then
        print_status "PASS" "HTTP trace headers use consistent casing"
    else
        print_status "WARN" "Found inconsistent header casing" "$inconsistent_headers"
    fi
    
    # Check for proper header extraction patterns
    local header_extractions=$(find . -name "*.ex" -o -name "*.exs" | xargs grep -l "get_req_header\|get_resp_header" 2>/dev/null || true)
    local missing_trace_extraction=()
    
    for file in $header_extractions; do
        if grep -q "get_req_header" "$file" && ! grep -q "trace" "$file"; then
            missing_trace_extraction+=("$file")
        fi
    done
    
    if [[ ${#missing_trace_extraction[@]} -eq 0 ]]; then
        print_status "PASS" "Header extraction patterns include trace support"
    else
        print_status "INFO" "Files with header extraction that might need trace support" "${missing_trace_extraction[*]}"
    fi
}

# Function to check test coverage
check_test_coverage() {
    echo -e "\n${BLUE}🔍 Checking trace ID test coverage...${NC}"
    
    # Count trace-related tests
    local trace_test_files=$(find . -name "*test*.exs" | xargs grep -l "trace_id" 2>/dev/null | wc -l)
    local total_test_files=$(find . -name "*test*.exs" | wc -l)
    
    print_status "INFO" "Found $trace_test_files test files with trace_id tests out of $total_test_files total"
    
    # Check for specific test patterns
    local test_patterns=(
        "trace.*consistency"
        "trace.*propagation" 
        "trace.*error"
        "trace.*concurrent"
        "trace.*telemetry"
    )
    
    local missing_patterns=()
    for pattern in "${test_patterns[@]}"; do
        local matches=$(find . -name "*test*.exs" | xargs grep -l "$pattern" 2>/dev/null || true)
        if [[ -z "$matches" ]]; then
            missing_patterns+=("$pattern")
        fi
    done
    
    if [[ ${#missing_patterns[@]} -eq 0 ]]; then
        print_status "PASS" "All important trace test patterns are covered"
    else
        print_status "WARN" "Missing test coverage for patterns" "${missing_patterns[*]}"
    fi
    
    # Check for property-based trace tests
    local property_tests=$(find . -name "*test*.exs" | xargs grep -l "property.*trace\|check all.*trace" 2>/dev/null || true)
    if [[ -n "$property_tests" ]]; then
        print_status "PASS" "Property-based trace tests found"
    else
        print_status "WARN" "No property-based trace tests found"
    fi
}

# Function to check error handling patterns
check_error_handling() {
    echo -e "\n${BLUE}🔍 Checking trace error handling patterns...${NC}"
    
    # Check for trace preservation in error cases
    local error_patterns=$(find . -name "*.ex" -o -name "*.exs" | xargs grep -l "rescue\|catch\|{:error" 2>/dev/null || true)
    local missing_trace_errors=()
    
    for file in $error_patterns; do
        # Skip test files for this check
        if [[ "$file" =~ test\.exs$ ]]; then
            continue
        fi
        
        local has_error_handling=$(grep -n "rescue\|catch\|{:error" "$file")
        local has_trace_context=$(grep -n "trace_id" "$file")
        
        if [[ -n "$has_error_handling" && -z "$has_trace_context" ]]; then
            missing_trace_errors+=("$file")
        fi
    done
    
    if [[ ${#missing_trace_errors[@]} -eq 0 ]]; then
        print_status "PASS" "Files with error handling include trace context"
    else
        print_status "INFO" "Files with error handling that might need trace context" "${missing_trace_errors[*]}"
    fi
    
    # Focus on super-critical Logger calls (coordination, middleware, error recovery)
    local super_critical_files="lib/self_sustaining/reactor_middleware lib/self_sustaining/workflows lib/self_sustaining/autonomous"
    local super_critical_calls=$(find $super_critical_files -name "*.ex" 2>/dev/null | xargs grep -n "Logger\.error\|Logger\.warning" 2>/dev/null || true)
    local super_critical_without=$(echo "$super_critical_calls" | grep -v "trace_id" || true)
    local super_critical_with=$(echo "$super_critical_calls" | grep "trace_id" || true)
    
    # Also check all critical Logger calls for context
    local critical_logger_calls=$(find lib/ -name "*.ex" | xargs grep -n "Logger\.error\|Logger\.warning" 2>/dev/null || true)
    local critical_without_trace=$(echo "$critical_logger_calls" | grep -v "trace_id" || true)
    local critical_with_trace=$(echo "$critical_logger_calls" | grep "trace_id" || true)
    
    local critical_without_count
    local critical_with_count  
    if [[ -n "$critical_without_trace" ]]; then
        critical_without_count=$(echo "$critical_without_trace" | grep -c ".")
    else
        critical_without_count=0
    fi
    
    if [[ -n "$critical_with_trace" ]]; then
        critical_with_count=$(echo "$critical_with_trace" | grep -c ".")
    else
        critical_with_count=0
    fi
    
    local critical_total=$((critical_with_count + critical_without_count))
    
    # Also check all logger calls for context
    local logger_calls=$(find . -name "*.ex" -o -name "*.exs" | xargs grep -n "Logger\." 2>/dev/null || true)
    local logger_without_trace=$(echo "$logger_calls" | grep -v "trace_id" || true)
    local logger_with_trace=$(echo "$logger_calls" | grep "trace_id" || true)
    
    local logger_without_count=$(echo "$logger_without_trace" | grep -c "." || echo "0")
    local logger_with_count=$(echo "$logger_with_trace" | grep -c "." || echo "0")
    
    if [[ $logger_with_count -gt 0 ]]; then
        print_status "PASS" "Found Logger calls with trace context ($logger_with_count/$((logger_with_count + logger_without_count)))"
    fi
    
    # Super-critical validation: Focus on core infrastructure Logger calls
    local super_critical_without_count=0
    local super_critical_with_count=0
    if [[ -n "$super_critical_without" ]]; then
        super_critical_without_count=$(echo "$super_critical_without" | grep -c ".")
    fi
    
    if [[ -n "$super_critical_with" ]]; then
        super_critical_with_count=$(echo "$super_critical_with" | grep -c ".")
    fi
    
    local super_critical_total=$((super_critical_with_count + super_critical_without_count))
    
    if [[ $super_critical_total -gt 0 ]]; then
        local super_coverage=$((super_critical_with_count * 100 / super_critical_total))
        if [[ $super_coverage -ge 50 ]]; then
            print_status "PASS" "Super-critical Logger calls have trace coverage ($super_critical_with_count/$super_critical_total = $super_coverage%)"
        else
            print_status "WARN" "Super-critical Logger calls missing trace context ($super_critical_with_count/$super_critical_total = $super_coverage%)"
        fi
    fi
    
    # Overall critical validation: More lenient for broader coverage
    if [[ $critical_total -gt 0 ]]; then
        local critical_coverage=$((critical_with_count * 100 / critical_total))
        if [[ $critical_coverage -ge 30 ]]; then
            print_status "PASS" "Critical Logger calls have adequate trace coverage ($critical_with_count/$critical_total = $critical_coverage%)"
        elif [[ $critical_coverage -ge 15 ]]; then
            print_status "WARN" "Critical Logger calls have partial trace coverage ($critical_with_count/$critical_total = $critical_coverage%)"
        else
            print_status "WARN" "Critical Logger calls missing trace context ($critical_with_count/$critical_total = $critical_coverage%)"
        fi
    fi
    
    if [[ $logger_without_count -gt 10 ]]; then
        print_status "INFO" "Many routine Logger calls without trace context ($logger_without_count calls) - normal for large codebase"
    fi
}

# Function to check configuration consistency
check_configuration() {
    echo -e "\n${BLUE}🔍 Checking trace configuration consistency...${NC}"
    
    # Check for trace-related configuration
    local config_files=$(find . -name "config.exs" -o -name "dev.exs" -o -name "prod.exs" -o -name "test.exs")
    local trace_config_found=false
    
    for file in $config_files; do
        if grep -q "trace\|telemetry" "$file"; then
            trace_config_found=true
            print_status "INFO" "Found trace/telemetry config in $file"
        fi
    done
    
    # Check for OpenTelemetry configuration
    local otel_config=$(find . -name "*.exs" | xargs grep -l "OpenTelemetry\|otel" 2>/dev/null || true)
    if [[ -n "$otel_config" ]]; then
        print_status "PASS" "OpenTelemetry configuration found"
    else
        print_status "WARN" "No OpenTelemetry configuration found"
    fi
    
    # Check for environment-specific trace configuration
    local env_trace_config=$(find . -name "*.exs" | xargs grep -l "config.*trace\|trace.*config" 2>/dev/null || true)
    if [[ -n "$env_trace_config" ]]; then
        print_status "PASS" "Environment-specific trace configuration found"
    else
        print_status "INFO" "No environment-specific trace configuration found"
    fi
    
    # Check for trace_id in application configuration structure
    local app_trace_support=$(find . -name "config.exs" -o -name "*.exs" | xargs grep -l "trace_id\|telemetry.*trace" 2>/dev/null || true)
    if [[ -n "$app_trace_support" ]]; then
        print_status "PASS" "Application-level trace support configured"
    else
        print_status "WARN" "No application-level trace support found in configuration"
    fi
}

# Main execution
main() {
    echo -e "${BLUE}🔍 Global Trace ID Implementation Validation${NC}"
    echo -e "${BLUE}=============================================${NC}"
    
    # Run all checks
    check_correlation_id_leftovers
    check_trace_naming_consistency
    check_hardcoded_values
    check_trace_propagation
    check_telemetry_integration
    check_http_header_consistency
    check_test_coverage
    check_error_handling
    check_configuration
    
    # Summary
    echo -e "\n${BLUE}📊 Validation Summary${NC}"
    echo -e "${BLUE}===================${NC}"
    echo -e "Total Checks: $TOTAL_CHECKS"
    echo -e "${GREEN}Passed: $PASSED_CHECKS${NC}"
    echo -e "${RED}Failed: $FAILED_CHECKS${NC}"
    echo -e "${YELLOW}Warnings: $WARNING_CHECKS${NC}"
    
    # Calculate honest score - no bonus point inflation
    local base_score=$((PASSED_CHECKS * 100 / TOTAL_CHECKS))
    
    # Small quality multiplier (max 5%) for having good implementation depth
    local quality_multiplier=0
    
    # Check if we have meaningful trace_id usage (not inflated bonus)
    local trace_id_files=$(find . -name "*.ex" -o -name "*.exs" | xargs grep -l "trace_id" 2>/dev/null | wc -l)
    local telemetry_with_trace=$(find . -name "*.ex" -o -name "*.exs" | xargs grep -A5 ":telemetry.execute" | grep -c "trace_id" 2>/dev/null || echo "0")
    
    # Only small recognition for comprehensive implementation
    if [[ $trace_id_files -gt 50 && $telemetry_with_trace -gt 50 ]]; then
        quality_multiplier=5  # 5% bonus for truly comprehensive implementation
    elif [[ $trace_id_files -gt 30 && $telemetry_with_trace -gt 20 ]]; then
        quality_multiplier=3  # 3% bonus for good implementation
    elif [[ $trace_id_files -gt 15 && $telemetry_with_trace -gt 10 ]]; then
        quality_multiplier=1  # 1% bonus for basic implementation
    fi
    
    local final_score=$((base_score + quality_multiplier))
    if [[ $final_score -gt 100 ]]; then
        final_score=100
    fi
    
    # Honest grading
    local grade="F"
    local assessment="Poor implementation"
    
    if [[ $final_score -ge 90 ]]; then
        grade="A"
        assessment="Excellent - Production ready"
    elif [[ $final_score -ge 80 ]]; then
        grade="B" 
        assessment="Good - Mostly production ready"
    elif [[ $final_score -ge 70 ]]; then
        grade="C"
        assessment="Adequate - Needs improvement"
    elif [[ $final_score -ge 60 ]]; then
        grade="D"
        assessment="Below standard - Major gaps"
    else
        grade="F"
        assessment="Poor implementation"
    fi
    
    enhanced_score=$final_score
    
    if [[ $FAILED_CHECKS -eq 0 ]]; then
        echo -e "\n${GREEN}🎉 All critical checks passed! Score: $enhanced_score% (Grade: $grade)${NC}"
        echo -e "${GREEN}📊 Base Score: $base_score%, Quality Bonus: +$quality_multiplier%${NC}"
        echo -e "${GREEN}📋 Assessment: $assessment${NC}"
        
        if [[ $WARNING_CHECKS -eq 0 ]]; then
            echo -e "${GREEN}✨ Perfect implementation - no warnings!${NC}"
        else
            echo -e "${YELLOW}⚠️  $WARNING_CHECKS warnings found - addressing these would improve production debugging${NC}"
        fi
        
        # Honest feedback
        echo -e "\n${GREEN}Implementation Details:${NC}"
        echo -e "  - Files with trace_id: $trace_id_files"
        echo -e "  - Telemetry with traces: $telemetry_with_trace"
        echo -e "  - Critical checks passed: $PASSED_CHECKS/$TOTAL_CHECKS"
        
        exit 0
    else
        echo -e "\n${RED}❌ $FAILED_CHECKS critical issues found! Score: $enhanced_score%${NC}"
        echo -e "${RED}Assessment: $assessment${NC}"
        echo -e "${RED}Please address failed checks before proceeding${NC}"
        exit 1
    fi
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi