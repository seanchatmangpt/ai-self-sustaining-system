#!/bin/bash

# =============================================================================
# Makefile Unit Test Suite
# =============================================================================
#
# DESCRIPTION:
#   Comprehensive unit tests for the AI Self-Sustaining System Makefile.
#   Tests target existence, functionality, error handling, and documentation.
#
# USAGE:
#   ./test_makefile.sh              # Run all tests
#   ./test_makefile.sh --verbose    # Run with verbose output
#   ./test_makefile.sh --quick      # Run quick tests only
#
# TEST CATEGORIES:
#   • Basic functionality tests
#   • Help system validation
#   • Target existence verification
#   • Variable validation
#   • Error handling tests
#   • Documentation completeness
#   • Color output verification
#
# REQUIREMENTS:
#   • Bash 4.0+
#   • make command available
#   • Project Makefile present
#   • Basic Unix utilities (grep, awk, etc.)
#
# AUTHORS: AI Self-Sustaining System Team
# VERSION: 1.0.0
# =============================================================================

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAKEFILE_PATH="$SCRIPT_DIR/Makefile"
VERBOSE=false
QUICK=false

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# =============================================================================
# Utility Functions
# =============================================================================

log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

log_verbose() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${CYAN}🔍 $1${NC}"
    fi
}

# Test framework functions
start_test() {
    local test_name="$1"
    TESTS_RUN=$((TESTS_RUN + 1))
    log_verbose "Starting test: $test_name"
}

pass_test() {
    local test_name="$1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    log_success "PASS: $test_name"
}

fail_test() {
    local test_name="$1"
    local reason="$2"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    log_error "FAIL: $test_name - $reason"
}

# =============================================================================
# Test Functions
# =============================================================================

test_makefile_exists() {
    start_test "Makefile existence"
    
    if [[ -f "$MAKEFILE_PATH" ]]; then
        pass_test "Makefile exists at $MAKEFILE_PATH"
    else
        fail_test "Makefile existence" "Makefile not found at $MAKEFILE_PATH"
    fi
}

test_makefile_syntax() {
    start_test "Makefile syntax validation"
    
    if make -f "$MAKEFILE_PATH" --dry-run help >/dev/null 2>&1; then
        pass_test "Makefile syntax is valid"
    else
        fail_test "Makefile syntax validation" "Syntax errors detected"
    fi
}

test_help_target() {
    start_test "Help target functionality"
    
    local help_output
    if help_output=$(make -f "$MAKEFILE_PATH" help 2>/dev/null); then
        if echo "$help_output" | grep -q "AI Self-Sustaining System"; then
            pass_test "Help target works and contains expected content"
        else
            fail_test "Help target functionality" "Help output missing expected content"
        fi
    else
        fail_test "Help target functionality" "Help target failed to execute"
    fi
}

test_phony_targets() {
    start_test "PHONY targets declaration"
    
    if grep -q "^\.PHONY:" "$MAKEFILE_PATH"; then
        local phony_line
        phony_line=$(grep "^\.PHONY:" "$MAKEFILE_PATH")
        log_verbose "Found PHONY declaration: $phony_line"
        pass_test "PHONY targets are properly declared"
    else
        fail_test "PHONY targets declaration" "No .PHONY declaration found"
    fi
}

test_default_goal() {
    start_test "Default goal setting"
    
    if grep -q "^\.DEFAULT_GOAL" "$MAKEFILE_PATH"; then
        local default_goal
        default_goal=$(grep "^\.DEFAULT_GOAL" "$MAKEFILE_PATH" | cut -d' ' -f3)
        log_verbose "Default goal set to: $default_goal"
        pass_test "Default goal is properly set"
    else
        fail_test "Default goal setting" "No .DEFAULT_GOAL found"
    fi
}

test_variables_defined() {
    start_test "Essential variables definition"
    
    local required_vars=("APP_NAME" "PROJECT_ROOT" "PHOENIX_DIR" "MIX" "ELIXIR")
    local missing_vars=()
    
    for var in "${required_vars[@]}"; do
        if ! grep -q "^$var.*:=" "$MAKEFILE_PATH"; then
            missing_vars+=("$var")
        fi
    done
    
    if [[ ${#missing_vars[@]} -eq 0 ]]; then
        pass_test "All essential variables are defined"
    else
        fail_test "Essential variables definition" "Missing variables: ${missing_vars[*]}"
    fi
}

test_color_codes() {
    start_test "Color code definitions"
    
    local color_vars=("RED" "GREEN" "YELLOW" "BLUE" "RESET")
    local missing_colors=()
    
    for color in "${color_vars[@]}"; do
        if ! grep -q "^$color.*:=" "$MAKEFILE_PATH"; then
            missing_colors+=("$color")
        fi
    done
    
    if [[ ${#missing_colors[@]} -eq 0 ]]; then
        pass_test "All color codes are defined"
    else
        fail_test "Color code definitions" "Missing colors: ${missing_colors[*]}"
    fi
}

test_target_categories() {
    start_test "Target category coverage"
    
    local expected_categories=(
        "setup" "dev" "test" "quality"
        "coord-help" "claude-help" "xavos-help"
        "otel-help" "worktree-help" "script-status"
    )
    local missing_targets=()
    
    for target in "${expected_categories[@]}"; do
        if ! grep -q "^$target:" "$MAKEFILE_PATH"; then
            missing_targets+=("$target")
        fi
    done
    
    if [[ ${#missing_targets[@]} -eq 0 ]]; then
        pass_test "All major target categories are present"
    else
        fail_test "Target category coverage" "Missing targets: ${missing_targets[*]}"
    fi
}

test_documentation_completeness() {
    start_test "Documentation completeness"
    
    # Count targets with documentation
    local total_targets
    total_targets=$(grep -c "^[a-zA-Z_-]*:" "$MAKEFILE_PATH" || echo "0")
    
    local documented_targets
    documented_targets=$(grep -c "^[a-zA-Z_-]*:.*##" "$MAKEFILE_PATH" || echo "0")
    
    local doc_percentage=$((documented_targets * 100 / total_targets))
    
    log_verbose "Documented targets: $documented_targets/$total_targets ($doc_percentage%)"
    
    if [[ $doc_percentage -ge 80 ]]; then
        pass_test "Documentation coverage is good ($doc_percentage%)"
    else
        fail_test "Documentation completeness" "Only $doc_percentage% of targets documented"
    fi
}

test_help_sections() {
    start_test "Help section structure"
    
    local help_output
    help_output=$(make -f "$MAKEFILE_PATH" help 2>/dev/null || echo "")
    
    local expected_sections=(
        "Development Workflow"
        "Agent Coordination"
        "Claude AI Intelligence"
        "XAVOS System"
        "OpenTelemetry"
    )
    
    local missing_sections=()
    for section in "${expected_sections[@]}"; do
        if ! echo "$help_output" | grep -q "$section"; then
            missing_sections+=("$section")
        fi
    done
    
    if [[ ${#missing_sections[@]} -eq 0 ]]; then
        pass_test "All expected help sections are present"
    else
        fail_test "Help section structure" "Missing sections: ${missing_sections[*]}"
    fi
}

test_make_dry_run() {
    start_test "Make dry-run capability"
    
    local targets=("help" "version" "check-dependencies")
    local failed_targets=()
    
    for target in "${targets[@]}"; do
        if ! make -f "$MAKEFILE_PATH" --dry-run "$target" >/dev/null 2>&1; then
            failed_targets+=("$target")
        fi
    done
    
    if [[ ${#failed_targets[@]} -eq 0 ]]; then
        pass_test "Dry-run works for basic targets"
    else
        fail_test "Make dry-run capability" "Failed targets: ${failed_targets[*]}"
    fi
}

test_error_handling() {
    start_test "Error handling for invalid targets"
    
    if make -f "$MAKEFILE_PATH" invalid-target-name 2>/dev/null; then
        fail_test "Error handling for invalid targets" "Should fail for invalid target"
    else
        pass_test "Properly handles invalid targets"
    fi
}

test_shell_script_integration() {
    start_test "Shell script integration targets"
    
    local script_targets=(
        "script-status" "script-monitor" "script-configure-claude"
        "coord-help" "claude-help" "xavos-help"
    )
    local missing_script_targets=()
    
    for target in "${script_targets[@]}"; do
        if ! grep -q "^$target:" "$MAKEFILE_PATH"; then
            missing_script_targets+=("$target")
        fi
    done
    
    if [[ ${#missing_script_targets[@]} -eq 0 ]]; then
        pass_test "All shell script integration targets present"
    else
        fail_test "Shell script integration targets" "Missing: ${missing_script_targets[*]}"
    fi
}

test_comprehensive_commands() {
    start_test "Comprehensive system commands"
    
    local comprehensive_targets=(
        "system-overview" "system-health-full" "system-full-test"
        "dev-full" "dev-minimal"
    )
    local missing_comprehensive=()
    
    for target in "${comprehensive_targets[@]}"; do
        if ! grep -q "^$target:" "$MAKEFILE_PATH"; then
            missing_comprehensive+=("$target")
        fi
    done
    
    if [[ ${#missing_comprehensive[@]} -eq 0 ]]; then
        pass_test "All comprehensive system commands present"
    else
        fail_test "Comprehensive system commands" "Missing: ${missing_comprehensive[*]}"
    fi
}

# =============================================================================
# Test Execution
# =============================================================================

run_basic_tests() {
    log_info "Running basic Makefile tests..."
    
    test_makefile_exists
    test_makefile_syntax
    test_help_target
    test_phony_targets
    test_default_goal
    test_variables_defined
    test_color_codes
}

run_functionality_tests() {
    log_info "Running functionality tests..."
    
    test_target_categories
    test_documentation_completeness
    test_help_sections
    test_make_dry_run
    test_error_handling
}

run_integration_tests() {
    log_info "Running integration tests..."
    
    test_shell_script_integration
    test_comprehensive_commands
}

# =============================================================================
# Main Execution
# =============================================================================

main() {
    echo "🧪 Makefile Unit Test Suite"
    echo "==========================="
    echo ""
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --verbose|-v)
                VERBOSE=true
                shift
                ;;
            --quick|-q)
                QUICK=true
                shift
                ;;
            --help|-h)
                echo "Usage: $0 [--verbose] [--quick] [--help]"
                echo ""
                echo "Options:"
                echo "  --verbose, -v    Enable verbose output"
                echo "  --quick, -q      Run quick tests only"
                echo "  --help, -h       Show this help message"
                exit 0
                ;;
            *)
                log_warning "Unknown option: $1"
                shift
                ;;
        esac
    done
    
    log_info "Starting Makefile test suite..."
    log_info "Makefile path: $MAKEFILE_PATH"
    log_info "Verbose mode: $VERBOSE"
    log_info "Quick mode: $QUICK"
    echo ""
    
    # Run test suites
    run_basic_tests
    
    if [[ "$QUICK" != "true" ]]; then
        run_functionality_tests
        run_integration_tests
    fi
    
    # Display results
    echo ""
    echo "📊 Test Results"
    echo "==============="
    echo ""
    echo "Tests run: $TESTS_RUN"
    echo "Tests passed: $TESTS_PASSED"
    echo "Tests failed: $TESTS_FAILED"
    echo ""
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        log_success "All tests passed! 🎉"
        echo ""
        echo "✅ Makefile is ready for production use"
        exit 0
    else
        log_error "Some tests failed!"
        echo ""
        echo "❌ Please fix the failing tests before proceeding"
        exit 1
    fi
}

# Handle script interruption
trap 'echo ""; log_warning "Test suite interrupted"; exit 130' INT TERM

# Run main function with all arguments
main "$@"