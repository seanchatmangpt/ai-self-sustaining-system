#!/bin/bash

# Master Trace ID Validation Suite
# Orchestrates all trace validation scripts for comprehensive checking

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALIDATION_SCRIPTS=(
    "validate_trace_implementation.sh"
    "detect_trace_antipatterns.sh"
    "validate_trace_performance.sh"
)

# Global counters
TOTAL_SUITES=0
PASSED_SUITES=0
FAILED_SUITES=0

# Function to run validation script
run_validation_script() {
    local script_name=$1
    local script_path="$SCRIPT_DIR/$script_name"
    
    echo -e "\n${BOLD}${BLUE}🔧 Running: $script_name${NC}"
    echo -e "${BLUE}$(printf '=%.0s' {1..60})${NC}"
    
    TOTAL_SUITES=$((TOTAL_SUITES + 1))
    
    if [[ -f "$script_path" && -x "$script_path" ]]; then
        if "$script_path"; then
            echo -e "${GREEN}✅ $script_name completed successfully${NC}"
            PASSED_SUITES=$((PASSED_SUITES + 1))
            return 0
        else
            echo -e "${RED}❌ $script_name failed${NC}"
            FAILED_SUITES=$((FAILED_SUITES + 1))
            return 1
        fi
    else
        echo -e "${RED}❌ Script not found or not executable: $script_path${NC}"
        FAILED_SUITES=$((FAILED_SUITES + 1))
        return 1
    fi
}

# Function to run quick validation
run_quick_validation() {
    echo -e "${BLUE}🚀 Quick Trace ID Validation${NC}"
    echo -e "${BLUE}============================${NC}"
    
    # Quick checks for critical issues
    local critical_issues=0
    
    # Check 1: Any correlation_id leftovers
    echo -e "\n${BLUE}🔍 Quick check: correlation_id leftovers...${NC}"
    local correlation_refs=$(find . -name "*.ex" -o -name "*.exs" | xargs grep -l "correlation_id" 2>/dev/null | wc -l)
    if [[ $correlation_refs -eq 0 ]]; then
        echo -e "${GREEN}✅ No correlation_id references${NC}"
    else
        echo -e "${RED}❌ Found $correlation_refs files with correlation_id${NC}"
        critical_issues=$((critical_issues + 1))
    fi
    
    # Check 2: Basic trace_id presence
    echo -e "\n${BLUE}🔍 Quick check: trace_id implementation...${NC}"
    local trace_refs=$(find . -name "*.ex" -o -name "*.exs" | xargs grep -l "trace_id" 2>/dev/null | wc -l)
    if [[ $trace_refs -gt 5 ]]; then
        echo -e "${GREEN}✅ Found trace_id in $trace_refs files${NC}"
    else
        echo -e "${RED}❌ Insufficient trace_id implementation ($trace_refs files)${NC}"
        critical_issues=$((critical_issues + 1))
    fi
    
    # Check 3: Test coverage
    echo -e "\n${BLUE}🔍 Quick check: test coverage...${NC}"
    local test_files=$(find . -name "*test*.exs" | xargs grep -l "trace" 2>/dev/null | wc -l)
    if [[ $test_files -gt 3 ]]; then
        echo -e "${GREEN}✅ Found trace tests in $test_files files${NC}"
    else
        echo -e "${YELLOW}⚠️  Limited trace test coverage ($test_files files)${NC}"
    fi
    
    # Check 4: HTTP header support
    echo -e "\n${BLUE}🔍 Quick check: HTTP header support...${NC}"
    local header_support=$(find . -name "*.ex" -o -name "*.exs" | xargs grep -l "X-Trace-ID\|x-trace-id" 2>/dev/null | wc -l)
    if [[ $header_support -gt 0 ]]; then
        echo -e "${GREEN}✅ Found HTTP trace header support${NC}"
    else
        echo -e "${YELLOW}⚠️  No HTTP trace header support found${NC}"
    fi
    
    # Check 5: Telemetry integration
    echo -e "\n${BLUE}🔍 Quick check: telemetry integration...${NC}"
    local telemetry_trace=$(find . -name "*.ex" -o -name "*.exs" | xargs grep ":telemetry\.execute" | grep "trace_id" | wc -l)
    if [[ $telemetry_trace -gt 3 ]]; then
        echo -e "${GREEN}✅ Found $telemetry_trace telemetry events with trace_id${NC}"
    else
        echo -e "${YELLOW}⚠️  Limited telemetry trace integration ($telemetry_trace events)${NC}"
    fi
    
    # Summary
    echo -e "\n${BLUE}📊 Quick Validation Summary${NC}"
    echo -e "${BLUE}===========================${NC}"
    if [[ $critical_issues -eq 0 ]]; then
        echo -e "${GREEN}🎉 No critical issues found - ready for full validation${NC}"
        return 0
    else
        echo -e "${RED}❌ $critical_issues critical issues found - address before full validation${NC}"
        return 1
    fi
}

# Function to generate validation report
generate_report() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local report_file="trace_validation_report_$(date '+%Y%m%d_%H%M%S').txt"
    
    echo -e "\n${BLUE}📊 Generating validation report...${NC}"
    
    cat > "$report_file" << EOF
Trace ID Validation Report
=========================
Generated: $timestamp
Project: Self-Sustaining AI System
Location: $(pwd)

Validation Suite Results:
------------------------
Total validation suites run: $TOTAL_SUITES
Passed suites: $PASSED_SUITES
Failed suites: $FAILED_SUITES
Success rate: $(( PASSED_SUITES * 100 / TOTAL_SUITES ))%

Files Analyzed:
--------------
Total .ex files: $(find . -name "*.ex" | wc -l)
Total .exs files: $(find . -name "*.exs" | wc -l)
Files with trace_id: $(find . -name "*.ex" -o -name "*.exs" | xargs grep -l "trace_id" 2>/dev/null | wc -l)
Test files with trace: $(find . -name "*test*.exs" | xargs grep -l "trace" 2>/dev/null | wc -l)

Implementation Statistics:
-------------------------
Trace ID generation calls: $(find . -name "*.ex" -o -name "*.exs" | xargs grep -c "generate.*trace\|trace.*generate" 2>/dev/null | awk -F: '{sum += $2} END {print sum}')
Telemetry events with trace: $(find . -name "*.ex" -o -name "*.exs" | xargs grep ":telemetry\.execute" | grep "trace_id" | wc -l)
HTTP trace header usage: $(find . -name "*.ex" -o -name "*.exs" | xargs grep -c "X-Trace-ID\|x-trace-id" 2>/dev/null | awk -F: '{sum += $2} END {print sum}')
Logger calls with trace: $(find . -name "*.ex" -o -name "*.exs" | xargs grep "Logger\." | grep "trace_id" | wc -l)

Quality Indicators:
------------------
Correlation ID references: $(find . -name "*.ex" -o -name "*.exs" | xargs grep -l "correlation_id" 2>/dev/null | wc -l)
Hardcoded trace patterns: $(find . -name "*.ex" -o -name "*.exs" | xargs grep -c '".*trace.*-.*-.*"' 2>/dev/null | grep -v "_test\.exs" | awk -F: '{sum += $2} END {print sum}')
Error handling with trace: $(find . -name "*.ex" -o -name "*.exs" | xargs grep -l "rescue\|catch" | xargs grep -l "trace_id" 2>/dev/null | wc -l)

Recommendations:
---------------
EOF

    if [[ $FAILED_SUITES -eq 0 ]]; then
        echo "✅ All validation suites passed successfully" >> "$report_file"
        echo "✅ Trace ID implementation appears to be high quality" >> "$report_file"
        echo "✅ No critical issues detected" >> "$report_file"
    else
        echo "❌ $FAILED_SUITES validation suite(s) failed" >> "$report_file"
        echo "⚠️  Review failed validation output for specific issues" >> "$report_file"
        echo "🔧 Address critical issues before deployment" >> "$report_file"
    fi
    
    echo -e "${GREEN}📄 Report generated: $report_file${NC}"
}

# Function to show usage
show_usage() {
    echo -e "${BOLD}Trace ID Validation Suite${NC}"
    echo -e "Usage: $0 [OPTION]"
    echo -e ""
    echo -e "Options:"
    echo -e "  --full, -f      Run all validation scripts (default)"
    echo -e "  --quick, -q     Run quick validation checks only"
    echo -e "  --report, -r    Generate detailed validation report"
    echo -e "  --list, -l      List available validation scripts"
    echo -e "  --help, -h      Show this help message"
    echo -e ""
    echo -e "Examples:"
    echo -e "  $0                 # Run full validation suite"
    echo -e "  $0 --quick        # Run quick checks only"
    echo -e "  $0 --report       # Run full validation and generate report"
}

# Function to list available scripts
list_scripts() {
    echo -e "${BLUE}Available Validation Scripts:${NC}"
    echo -e "${BLUE}============================${NC}"
    
    for script in "${VALIDATION_SCRIPTS[@]}"; do
        local script_path="$SCRIPT_DIR/$script"
        if [[ -f "$script_path" && -x "$script_path" ]]; then
            echo -e "${GREEN}✅ $script${NC}"
            # Extract description from script
            local description=$(head -3 "$script_path" | grep "^#" | tail -1 | sed 's/^# //')
            echo -e "   ${description}"
        else
            echo -e "${RED}❌ $script (not found or not executable)${NC}"
        fi
        echo ""
    done
}

# Main execution
main() {
    local option=${1:-"--full"}
    
    case $option in
        "--quick"|"-q")
            run_quick_validation
            ;;
        "--report"|"-r")
            echo -e "${BOLD}${BLUE}🔍 Running Full Validation Suite with Report Generation${NC}"
            echo -e "${BLUE}$(printf '=%.0s' {1..60})${NC}"
            
            for script in "${VALIDATION_SCRIPTS[@]}"; do
                run_validation_script "$script" || true  # Continue on failure for report
            done
            
            generate_report
            
            echo -e "\n${BOLD}${BLUE}📊 Final Summary${NC}"
            echo -e "${BLUE}================${NC}"
            echo -e "Validation suites completed: $TOTAL_SUITES"
            echo -e "${GREEN}Passed: $PASSED_SUITES${NC}"
            echo -e "${RED}Failed: $FAILED_SUITES${NC}"
            
            if [[ $FAILED_SUITES -eq 0 ]]; then
                echo -e "\n${GREEN}🎉 All validations passed successfully!${NC}"
                exit 0
            else
                echo -e "\n${RED}❌ Some validations failed - check report for details${NC}"
                exit 1
            fi
            ;;
        "--list"|"-l")
            list_scripts
            ;;
        "--help"|"-h")
            show_usage
            ;;
        "--full"|"-f"|*)
            echo -e "${BOLD}${BLUE}🔍 Running Full Trace ID Validation Suite${NC}"
            echo -e "${BLUE}$(printf '=%.0s' {1..60})${NC}"
            
            for script in "${VALIDATION_SCRIPTS[@]}"; do
                if ! run_validation_script "$script"; then
                    echo -e "\n${RED}❌ Validation suite failed on $script${NC}"
                    exit 1
                fi
            done
            
            echo -e "\n${BOLD}${GREEN}🎉 All validation suites passed successfully!${NC}"
            echo -e "${GREEN}Trace ID implementation is validated and ready for production${NC}"
            ;;
    esac
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi