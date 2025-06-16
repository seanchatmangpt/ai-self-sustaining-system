#!/bin/bash
# 80/20 Implementation Verification Script
# Verifies all three 80/20 fixes provide expected impact

set -euo pipefail

echo "🔍 Verifying 80/20 Implementation Fixes"
echo "======================================="
echo "Target: 160% total impact (80% + 20% + 60%)"

COORD_DIR="/Users/sac/dev/ai-self-sustaining-system/agent_coordination"
COORD_SCRIPT="$COORD_DIR/coordination_helper.sh"

# Initialize impact tracking
total_impact=0
tests_passed=0
tests_failed=0

# Test result tracking
log_test_result() {
    local test_name="$1"
    local result="$2"
    local impact="$3"
    
    if [ "$result" = "PASS" ]; then
        echo "✅ $test_name: PASS (+${impact}% impact)"
        total_impact=$((total_impact + impact))
        ((tests_passed++))
    else
        echo "❌ $test_name: FAIL (0% impact)"
        ((tests_failed++))
    fi
}

# Test 1: Claude AI Integration (Target: 80% impact)
test_claude_integration() {
    echo ""
    echo "🤖 Test 1: Claude AI Integration (Target: 80% impact)"
    echo "=================================================="
    
    # Test 1a: Claude commands exist
    echo "🔍 Testing Claude command files..."
    local claude_commands_exist=true
    for cmd in claude-health-analysis claude-analyze-priorities claude-optimize-assignments claude-stream; do
        if [ -f "$COORD_DIR/claude/$cmd" ]; then
            echo "  ✅ $cmd exists"
        else
            echo "  ❌ $cmd missing"
            claude_commands_exist=false
        fi
    done
    
    if [ "$claude_commands_exist" = true ]; then
        log_test_result "Claude Command Files" "PASS" 20
    else
        log_test_result "Claude Command Files" "FAIL" 0
    fi
    
    # Test 1b: Claude commands integrated in coordination_helper.sh
    echo "🔍 Testing Claude command integration..."
    local claude_help_integration=false
    if [ -f "$COORD_SCRIPT" ] && grep -q "claude-health" "$COORD_SCRIPT"; then
        echo "  ✅ Claude commands integrated in help"
        claude_help_integration=true
    else
        echo "  ❌ Claude commands not integrated in help"
    fi
    
    if [ "$claude_help_integration" = true ]; then
        log_test_result "Claude Help Integration" "PASS" 15
    else
        log_test_result "Claude Help Integration" "FAIL" 0
    fi
    
    # Test 1c: Claude health analysis execution
    echo "🔍 Testing Claude health analysis execution..."
    if timeout 30 "$COORD_SCRIPT" claude-health >/dev/null 2>&1; then
        echo "  ✅ Claude health analysis executes"
        log_test_result "Claude Health Execution" "PASS" 25
    else
        echo "  ⚠️ Claude health analysis execution issues"
        log_test_result "Claude Health Execution" "FAIL" 0
    fi
    
    # Test 1d: Fallback functionality
    echo "🔍 Testing Claude fallback functionality..."
    if [ -f "$COORD_DIR/claude/claude-health-analysis" ]; then
        local fallback_output=$("$COORD_DIR/claude/claude-health-analysis" 2>&1 | head -5)
        if [[ "$fallback_output" == *"Health"* ]]; then
            echo "  ✅ Claude fallback functionality working"
            log_test_result "Claude Fallback Mode" "PASS" 20
        else
            echo "  ❌ Claude fallback functionality issues"
            log_test_result "Claude Fallback Mode" "FAIL" 0
        fi
    else
        log_test_result "Claude Fallback Mode" "FAIL" 0
    fi
}

# Test 2: Environment Portability (Target: 20% impact)
test_environment_portability() {
    echo ""
    echo "🌍 Test 2: Environment Portability (Target: 20% impact)"
    echo "====================================================="
    
    # Test 2a: Environment detection utility exists
    echo "🔍 Testing environment detection utility..."
    if [ -f "$COORD_DIR/lib/s2s-env.sh" ]; then
        echo "  ✅ Environment detection utility exists"
        log_test_result "Environment Detection Utility" "PASS" 5
    else
        echo "  ❌ Environment detection utility missing"
        log_test_result "Environment Detection Utility" "FAIL" 0
    fi
    
    # Test 2b: Portability integration in coordination_helper.sh
    echo "🔍 Testing portability integration..."
    if [ -f "$COORD_SCRIPT" ] && grep -q "s2s-env.sh\|SCRIPT_DIR.*pwd" "$COORD_SCRIPT"; then
        echo "  ✅ Portability integration added"
        log_test_result "Portability Integration" "PASS" 5
    else
        echo "  ❌ Portability integration missing"
        log_test_result "Portability Integration" "FAIL" 0
    fi
    
    # Test 2c: Cross-directory execution
    echo "🔍 Testing cross-directory execution..."
    local original_dir="$PWD"
    local test_passed=false
    
    # Test from /tmp
    if cd /tmp 2>/dev/null; then
        if timeout 10 "$COORD_SCRIPT" help >/dev/null 2>&1; then
            echo "  ✅ Works from /tmp"
            test_passed=true
        else
            echo "  ⚠️ Issues from /tmp"
        fi
        cd "$original_dir"
    fi
    
    if [ "$test_passed" = true ]; then
        log_test_result "Cross-Directory Execution" "PASS" 10
    else
        log_test_result "Cross-Directory Execution" "FAIL" 0
    fi
}

# Test 3: Core Missing Commands (Target: 60% impact)
test_core_commands() {
    echo ""
    echo "📋 Test 3: Core Missing Commands (Target: 60% impact)"
    echo "===================================================="
    
    # Test 3a: New commands in help
    echo "🔍 Testing new commands in help..."
    local help_output=""
    if [ -f "$COORD_SCRIPT" ]; then
        help_output=$("$COORD_SCRIPT" help 2>/dev/null || echo "help failed")
    fi
    
    local expected_commands=("system-health" "agent-count" "work-queue" "performance" "logs" "deploy-status" "backup" "validate" "agent-performance" "config")
    local found_commands=0
    
    for cmd in "${expected_commands[@]}"; do
        if echo "$help_output" | grep -q "$cmd"; then
            echo "  ✅ $cmd found in help"
            ((found_commands++))
        else
            echo "  ❌ $cmd missing from help"
        fi
    done
    
    local help_score=$(( (found_commands * 15) / ${#expected_commands[@]} ))
    log_test_result "Commands in Help ($found_commands/${#expected_commands[@]})" "$([ $found_commands -ge 5 ] && echo "PASS" || echo "FAIL")" $help_score
    
    # Test 3b: Command execution
    echo "🔍 Testing command execution..."
    local executable_commands=("system-health" "agent-count" "config")
    local working_commands=0
    
    for cmd in "${executable_commands[@]}"; do
        if timeout 15 "$COORD_SCRIPT" "$cmd" >/dev/null 2>&1; then
            echo "  ✅ $cmd executes successfully"
            ((working_commands++))
        else
            echo "  ⚠️ $cmd execution issues"
        fi
    done
    
    local execution_score=$(( (working_commands * 20) / ${#executable_commands[@]} ))
    log_test_result "Command Execution ($working_commands/${#executable_commands[@]})" "$([ $working_commands -ge 2 ] && echo "PASS" || echo "FAIL")" $execution_score
    
    # Test 3c: Total command count
    echo "🔍 Testing total command count..."
    local total_commands=$(grep -c 'echo "  [a-z]' "$COORD_SCRIPT" 2>/dev/null || echo "0")
    echo "  📊 Total commands found: $total_commands"
    
    if [ "$total_commands" -ge 25 ]; then
        echo "  🎯 Command count target met (25+)"
        log_test_result "Total Command Count ($total_commands)" "PASS" 25
    elif [ "$total_commands" -ge 20 ]; then
        echo "  📈 Good progress ($total_commands commands)"
        log_test_result "Total Command Count ($total_commands)" "PASS" 15
    else
        echo "  📉 Below target ($total_commands < 20)"
        log_test_result "Total Command Count ($total_commands)" "FAIL" 0
    fi
}

# Test 4: System Integration
test_system_integration() {
    echo ""
    echo "🔗 Test 4: System Integration"
    echo "============================="
    
    # Test 4a: Overall system health
    echo "🔍 Testing overall system health..."
    if timeout 20 "$COORD_SCRIPT" system-health >/dev/null 2>&1; then
        echo "  ✅ System health command works"
        log_test_result "System Health Command" "PASS" 5
    else
        echo "  ⚠️ System health command issues"
        log_test_result "System Health Command" "FAIL" 0
    fi
    
    # Test 4b: File integrity
    echo "🔍 Testing file integrity..."
    local files_ok=true
    for file in coordination_helper.sh lib/s2s-env.sh; do
        if [ -f "$COORD_DIR/$file" ]; then
            echo "  ✅ $file exists"
        else
            echo "  ❌ $file missing"
            files_ok=false
        fi
    done
    
    if [ "$files_ok" = true ]; then
        log_test_result "File Integrity" "PASS" 5
    else
        log_test_result "File Integrity" "FAIL" 0
    fi
}

# Performance baseline test
test_performance_baseline() {
    echo ""
    echo "📊 Test 5: Performance Baseline"
    echo "==============================="
    
    # Test basic coordination operations speed
    echo "🔍 Testing coordination operations speed..."
    local start_time=$(date +%s.%N)
    
    # Run multiple quick operations
    for i in {1..5}; do
        "$COORD_SCRIPT" help >/dev/null 2>&1 || true
    done
    
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "0.5")
    
    echo "  📊 5 operations completed in ${duration}s"
    
    # Check if under 2 seconds (reasonable for 5 operations)
    if (( $(echo "$duration < 2.0" | bc -l 2>/dev/null || echo "1") )); then
        echo "  ✅ Performance acceptable"
        log_test_result "Performance Baseline" "PASS" 5
    else
        echo "  ⚠️ Performance may need optimization"
        log_test_result "Performance Baseline" "FAIL" 0
    fi
}

# Generate impact summary
generate_summary() {
    echo ""
    echo "📊 80/20 Implementation Results Summary"
    echo "======================================"
    echo ""
    echo "📈 Impact Analysis:"
    echo "   Total Impact Achieved: ${total_impact}% (Target: 160%)"
    echo "   Tests Passed: $tests_passed"
    echo "   Tests Failed: $tests_failed"
    echo ""
    
    # Determine success level
    if [ "$total_impact" -ge 140 ]; then
        echo "🎯 80/20 EXCELLENT SUCCESS: High impact achieved with minimal effort"
        echo "✅ Ready for next phase BEAMOps infrastructure implementation"
        echo ""
        echo "🚀 Next Steps:"
        echo "   1. Begin BEAMOps infrastructure chapters (Docker, CI/CD)"
        echo "   2. Implement remaining coordination commands"
        echo "   3. Scale to enterprise deployment"
        return 0
    elif [ "$total_impact" -ge 100 ]; then
        echo "🎯 80/20 GOOD SUCCESS: Significant impact achieved"
        echo "✅ Major improvements completed, minor issues to address"
        echo ""
        echo "🔧 Recommended Next Steps:"
        echo "   1. Address failed test components above"
        echo "   2. Validate Claude integration thoroughly"
        echo "   3. Proceed with infrastructure implementation"
        return 0
    elif [ "$total_impact" -ge 60 ]; then
        echo "⚠️ 80/20 PARTIAL SUCCESS: Some impact achieved"
        echo "🔧 Review failed components and retry fixes"
        echo ""
        echo "🛠️ Priority Actions:"
        echo "   1. Fix Claude AI integration issues"
        echo "   2. Verify environment portability"
        echo "   3. Complete command implementation"
        return 1
    else
        echo "❌ 80/20 IMPLEMENTATION FAILED: Minimal impact achieved"
        echo "🔧 Major issues need resolution before proceeding"
        echo ""
        echo "🚨 Critical Actions Required:"
        echo "   1. Review all fix scripts for errors"
        echo "   2. Verify coordination_helper.sh integrity"
        echo "   3. Check system dependencies"
        return 1
    fi
}

# Main execution
main() {
    echo "🎯 Starting 80/20 Implementation Verification..."
    echo "Target: Verify 160% total impact (80% Claude + 20% Portability + 60% Commands)"
    echo ""
    
    # Run all tests
    test_claude_integration
    test_environment_portability
    test_core_commands
    test_system_integration
    test_performance_baseline
    
    # Generate summary and determine success
    generate_summary
}

# Error handling
trap 'echo "❌ 80/20 verification failed"; exit 1' ERR

# Execute verification
main "$@"