#!/bin/bash

# Unit Tests for coordination_helper.sh
# Can be run with: bash test_coordination_helper.sh

# Test configuration
TEST_DIR="$(mktemp -d)"
export COORDINATION_DIR="$TEST_DIR"
SCRIPT_PATH="$(dirname "$0")/coordination_helper.sh"

# Test counter
TESTS_RUN=0
TESTS_PASSED=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test utilities
assert_equals() {
    local expected="$1"
    local actual="$2"
    local test_name="$3"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if [ "$expected" = "$actual" ]; then
        echo -e "${GREEN}✅ PASS${NC}: $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}❌ FAIL${NC}: $test_name"
        echo "  Expected: '$expected'"
        echo "  Actual: '$actual'"
    fi
}

assert_file_exists() {
    local file_path="$1"
    local test_name="$2"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if [ -f "$file_path" ]; then
        echo -e "${GREEN}✅ PASS${NC}: $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}❌ FAIL${NC}: $test_name"
        echo "  File not found: $file_path"
    fi
}

assert_json_valid() {
    local file_path="$1"
    local test_name="$2"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if command -v jq >/dev/null 2>&1 && jq empty "$file_path" 2>/dev/null; then
        echo -e "${GREEN}✅ PASS${NC}: $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}❌ FAIL${NC}: $test_name"
        echo "  Invalid JSON in: $file_path"
    fi
}

assert_json_contains() {
    local file_path="$1"
    local jq_query="$2"
    local expected_value="$3"
    local test_name="$4"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if command -v jq >/dev/null 2>&1; then
        local actual_value=$(jq -r "$jq_query" "$file_path" 2>/dev/null)
        if [ "$actual_value" = "$expected_value" ]; then
            echo -e "${GREEN}✅ PASS${NC}: $test_name"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            echo -e "${RED}❌ FAIL${NC}: $test_name"
            echo "  Query: $jq_query"
            echo "  Expected: '$expected_value'"
            echo "  Actual: '$actual_value'"
        fi
    else
        echo -e "${YELLOW}⚠️ SKIP${NC}: $test_name (jq not available)"
    fi
}

# Setup function
setup_test() {
    rm -rf "$TEST_DIR"/*
    mkdir -p "$TEST_DIR"
}

# Cleanup function
cleanup_test() {
    rm -rf "$TEST_DIR"
}

# Test runner
run_test() {
    local test_name="$1"
    echo -e "\n${YELLOW}🧪 Testing: $test_name${NC}"
    setup_test
}

# Test Functions

test_generate_agent_id() {
    run_test "Agent ID generation"
    
    local agent_id1=$("$SCRIPT_PATH" generate-id)
    local agent_id2=$("$SCRIPT_PATH" generate-id)
    
    # Should start with "agent_"
    assert_equals "agent_" "${agent_id1:0:6}" "Agent ID has correct prefix"
    
    # Should be unique (nanosecond precision)
    if [ "$agent_id1" != "$agent_id2" ]; then
        echo -e "${GREEN}✅ PASS${NC}: Agent IDs are unique"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}❌ FAIL${NC}: Agent IDs are not unique"
    fi
    TESTS_RUN=$((TESTS_RUN + 1))
}

test_claim_work_basic() {
    run_test "Basic work claiming"
    
    # Claim work
    AGENT_ID="test_agent_123" "$SCRIPT_PATH" claim "test_work" "Test description" "high" "test_team" >/dev/null 2>&1
    
    # Check files were created
    assert_file_exists "$TEST_DIR/work_claims.json" "Work claims file created"
    assert_file_exists "$TEST_DIR/agent_status.json" "Agent status file created"
    
    # Check JSON validity
    assert_json_valid "$TEST_DIR/work_claims.json" "Work claims JSON is valid"
    assert_json_valid "$TEST_DIR/agent_status.json" "Agent status JSON is valid"
    
    # Check work claim content
    assert_json_contains "$TEST_DIR/work_claims.json" '.[] | select(.agent_id == "test_agent_123") | .work_type' "test_work" "Work type recorded correctly"
    assert_json_contains "$TEST_DIR/work_claims.json" '.[] | select(.agent_id == "test_agent_123") | .priority' "high" "Priority recorded correctly"
    assert_json_contains "$TEST_DIR/work_claims.json" '.[] | select(.agent_id == "test_agent_123") | .status' "active" "Status set to active"
}

test_progress_update() {
    run_test "Progress update"
    
    # First claim work
    AGENT_ID="test_agent_456" "$SCRIPT_PATH" claim "progress_test" "Test progress update" >/dev/null 2>&1
    
    # Get work item ID
    local work_id=$(jq -r '.[] | select(.agent_id == "test_agent_456") | .work_item_id' "$TEST_DIR/work_claims.json" 2>/dev/null)
    
    # Update progress
    "$SCRIPT_PATH" progress "$work_id" "50" "in_progress" >/dev/null 2>&1
    
    # Check progress was updated
    assert_json_contains "$TEST_DIR/work_claims.json" ".[] | select(.work_item_id == \"$work_id\") | .progress" "50" "Progress updated to 50"
    assert_json_contains "$TEST_DIR/work_claims.json" ".[] | select(.work_item_id == \"$work_id\") | .status" "in_progress" "Status updated to in_progress"
}

test_complete_work() {
    run_test "Work completion"
    
    # First claim work
    AGENT_ID="test_agent_789" "$SCRIPT_PATH" claim "complete_test" "Test completion" >/dev/null 2>&1
    
    # Get work item ID
    local work_id=$(jq -r '.[] | select(.agent_id == "test_agent_789") | .work_item_id' "$TEST_DIR/work_claims.json" 2>/dev/null)
    
    # Complete work
    "$SCRIPT_PATH" complete "$work_id" "success" "5" >/dev/null 2>&1
    
    # Check completion
    assert_json_contains "$TEST_DIR/work_claims.json" ".[] | select(.work_item_id == \"$work_id\") | .status" "completed" "Status updated to completed"
    assert_json_contains "$TEST_DIR/work_claims.json" ".[] | select(.work_item_id == \"$work_id\") | .result" "success" "Result recorded as success"
    
    # Check coordination log
    assert_file_exists "$TEST_DIR/coordination_log.json" "Coordination log created"
    assert_json_valid "$TEST_DIR/coordination_log.json" "Coordination log is valid JSON"
    assert_json_contains "$TEST_DIR/coordination_log.json" ".[] | select(.work_item_id == \"$work_id\") | .velocity_points" "5" "Velocity points recorded"
}

test_dashboard_functionality() {
    run_test "Dashboard functionality"
    
    # Claim some work
    AGENT_ID="dashboard_agent" "$SCRIPT_PATH" claim "dashboard_test" "Test dashboard" >/dev/null 2>&1
    
    # Run dashboard and capture output
    local dashboard_output=$("$SCRIPT_PATH" dashboard 2>/dev/null)
    
    # Check dashboard contains expected sections
    if echo "$dashboard_output" | grep -q "SCRUM AT SCALE DASHBOARD"; then
        echo -e "${GREEN}✅ PASS${NC}: Dashboard header present"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}❌ FAIL${NC}: Dashboard header missing"
    fi
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if echo "$dashboard_output" | grep -q "Active Agents:"; then
        echo -e "${GREEN}✅ PASS${NC}: Agent status section present"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}❌ FAIL${NC}: Agent status section missing"
    fi
    TESTS_RUN=$((TESTS_RUN + 1))
}

test_concurrent_claims() {
    run_test "Concurrent work claims (basic)"
    
    # Simulate concurrent claims
    AGENT_ID="agent_A" "$SCRIPT_PATH" claim "concurrent_A" "Test A" >/dev/null 2>&1 &
    AGENT_ID="agent_B" "$SCRIPT_PATH" claim "concurrent_B" "Test B" >/dev/null 2>&1 &
    wait
    
    # Check both claims were successful
    local count=$(jq 'length' "$TEST_DIR/work_claims.json" 2>/dev/null || echo "0")
    assert_equals "2" "$count" "Both concurrent claims recorded"
    
    # Check JSON is still valid after concurrent writes
    assert_json_valid "$TEST_DIR/work_claims.json" "JSON remains valid after concurrent writes"
}

# Main test execution
main() {
    echo -e "${YELLOW}🚀 Starting Coordination Helper Unit Tests${NC}"
    echo "Test directory: $TEST_DIR"
    echo "Script path: $SCRIPT_PATH"
    
    # Check if script exists
    if [ ! -f "$SCRIPT_PATH" ]; then
        echo -e "${RED}❌ ERROR${NC}: Script not found at $SCRIPT_PATH"
        exit 1
    fi
    
    # Run all tests
    test_generate_agent_id
    test_claim_work_basic
    test_progress_update
    test_complete_work
    test_dashboard_functionality
    test_concurrent_claims
    
    # Cleanup
    cleanup_test
    
    # Final report
    echo -e "\n${YELLOW}📊 Test Results${NC}"
    echo "Tests run: $TESTS_RUN"
    echo "Tests passed: $TESTS_PASSED"
    echo "Tests failed: $((TESTS_RUN - TESTS_PASSED))"
    
    if [ "$TESTS_PASSED" -eq "$TESTS_RUN" ]; then
        echo -e "${GREEN}🎉 All tests passed!${NC}"
        exit 0
    else
        echo -e "${RED}💥 Some tests failed!${NC}"
        exit 1
    fi
}

# Run tests if script is executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi