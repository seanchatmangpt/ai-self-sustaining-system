#!/usr/bin/env bats

# BATS test suite for coordination_helper.sh
# Run with: bats coordination_helper.bats

# Setup and teardown
setup() {
    # Create temporary test directory
    TEST_TEMP_DIR="$(mktemp -d)"
    export COORDINATION_DIR="$TEST_TEMP_DIR"
    
    # Path to script under test
    SCRIPT_PATH="$BATS_TEST_DIRNAME/coordination_helper.sh"
    
    # Ensure script is executable
    chmod +x "$SCRIPT_PATH"
}

teardown() {
    # Cleanup temporary files
    rm -rf "$TEST_TEMP_DIR"
}

# Helper functions
assert_file_exists() {
    [ -f "$1" ]
}

assert_json_valid() {
    if command -v jq >/dev/null 2>&1; then
        jq empty "$1"
    else
        # Fallback: basic JSON syntax check
        grep -q "^[[:space:]]*\[" "$1" && grep -q "\][[:space:]]*$" "$1"
    fi
}

assert_json_contains() {
    local file="$1"
    local query="$2" 
    local expected="$3"
    
    if command -v jq >/dev/null 2>&1; then
        local actual
        actual=$(jq -r "$query" "$file" 2>/dev/null)
        [ "$actual" = "$expected" ]
    else
        # Fallback: grep for expected content
        grep -q "$expected" "$file"
    fi
}

# Test cases

@test "generate agent ID creates unique nanosecond-based IDs" {
    run "$SCRIPT_PATH" generate-id
    [ "$status" -eq 0 ]
    [[ "$output" =~ ^agent_[0-9]+$ ]]
    
    # Test uniqueness
    local id1
    local id2
    id1=$("$SCRIPT_PATH" generate-id)
    id2=$("$SCRIPT_PATH" generate-id)
    [ "$id1" != "$id2" ]
}

@test "claim work creates necessary files with valid JSON" {
    run env AGENT_ID="test_agent_123" "$SCRIPT_PATH" claim "test_work" "Test description" "high" "test_team"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "SUCCESS: Claimed work item" ]]
    
    # Check files exist
    assert_file_exists "$COORDINATION_DIR/work_claims.json"
    assert_file_exists "$COORDINATION_DIR/agent_status.json"
    
    # Check JSON validity
    assert_json_valid "$COORDINATION_DIR/work_claims.json"
    assert_json_valid "$COORDINATION_DIR/agent_status.json"
}

@test "claim work records correct work data" {
    run env AGENT_ID="test_agent_456" "$SCRIPT_PATH" claim "feature_dev" "Implement auth" "critical" "backend_team"
    [ "$status" -eq 0 ]
    
    # Verify work claim content
    assert_json_contains "$COORDINATION_DIR/work_claims.json" '.[] | select(.agent_id == "test_agent_456") | .work_type' "feature_dev"
    assert_json_contains "$COORDINATION_DIR/work_claims.json" '.[] | select(.agent_id == "test_agent_456") | .priority' "critical"
    assert_json_contains "$COORDINATION_DIR/work_claims.json" '.[] | select(.agent_id == "test_agent_456") | .status' "active"
    assert_json_contains "$COORDINATION_DIR/work_claims.json" '.[] | select(.agent_id == "test_agent_456") | .team' "backend_team"
}

@test "claim work registers agent correctly" {
    run env AGENT_ID="test_agent_789" "$SCRIPT_PATH" claim "bugfix" "Fix timeout issue" "medium" "platform_team"
    [ "$status" -eq 0 ]
    
    # Verify agent registration
    assert_json_contains "$COORDINATION_DIR/agent_status.json" '.[] | select(.agent_id == "test_agent_789") | .team' "platform_team"
    assert_json_contains "$COORDINATION_DIR/agent_status.json" '.[] | select(.agent_id == "test_agent_789") | .status' "active"
    assert_json_contains "$COORDINATION_DIR/agent_status.json" '.[] | select(.agent_id == "test_agent_789") | .capacity' "100"
}

@test "progress update modifies work status correctly" {
    # First claim work
    env COORDINATION_DIR="$TEST_TEMP_DIR" AGENT_ID="progress_agent" "$SCRIPT_PATH" claim "progress_test" "Test progress update" >/dev/null
    
    # Get work item ID
    local work_id
    if command -v jq >/dev/null 2>&1 && [ -f "$COORDINATION_DIR/work_claims.json" ]; then
        work_id=$(jq -r '.[] | select(.agent_id == "progress_agent") | .work_item_id' "$COORDINATION_DIR/work_claims.json")
    else
        # Fallback: extract from JSON manually
        work_id=$(grep -A5 '"agent_id": "progress_agent"' "$COORDINATION_DIR/work_claims.json" | grep '"work_item_id"' | cut -d'"' -f4)
    fi
    
    # Skip test if we couldn't get work_id
    [ -n "$work_id" ]
    
    # Update progress
    run env COORDINATION_DIR="$TEST_TEMP_DIR" "$SCRIPT_PATH" progress "$work_id" "75" "testing"
    [ "$status" -eq 0 ]
    # More flexible pattern matching
    [[ "$output" =~ "PROGRESS" ]] && [[ "$output" =~ "75%" ]]
    
    # Verify progress update
    assert_json_contains "$COORDINATION_DIR/work_claims.json" ".[] | select(.work_item_id == \"$work_id\") | .progress" "75"
    assert_json_contains "$COORDINATION_DIR/work_claims.json" ".[] | select(.work_item_id == \"$work_id\") | .status" "testing"
}

@test "complete work updates status and creates log" {
    # First claim work
    env COORDINATION_DIR="$TEST_TEMP_DIR" AGENT_ID="complete_agent" "$SCRIPT_PATH" claim "completion_test" "Test completion flow" >/dev/null
    
    # Get work item ID
    local work_id
    if command -v jq >/dev/null 2>&1 && [ -f "$COORDINATION_DIR/work_claims.json" ]; then
        work_id=$(jq -r '.[] | select(.agent_id == "complete_agent") | .work_item_id' "$COORDINATION_DIR/work_claims.json")
    else
        work_id=$(grep -A5 '"agent_id": "complete_agent"' "$COORDINATION_DIR/work_claims.json" | grep '"work_item_id"' | cut -d'"' -f4)
    fi
    
    # Skip test if we couldn't get work_id
    [ -n "$work_id" ]
    
    # Complete work
    run env COORDINATION_DIR="$TEST_TEMP_DIR" "$SCRIPT_PATH" complete "$work_id" "success" "10"
    [ "$status" -eq 0 ]
    # Check output contains expected elements
    [[ "$output" =~ "COMPLETED" ]] && [[ "$output" =~ "success" ]] && [[ "$output" =~ "10" ]] && [[ "$output" =~ "velocity" ]]
    
    # Verify completion
    assert_json_contains "$COORDINATION_DIR/work_claims.json" ".[] | select(.work_item_id == \"$work_id\") | .status" "completed"
    assert_json_contains "$COORDINATION_DIR/work_claims.json" ".[] | select(.work_item_id == \"$work_id\") | .result" "success"
    
    # Check coordination log
    assert_file_exists "$COORDINATION_DIR/coordination_log.json"
    assert_json_valid "$COORDINATION_DIR/coordination_log.json"
    assert_json_contains "$COORDINATION_DIR/coordination_log.json" ".[] | select(.work_item_id == \"$work_id\") | .velocity_points" "10"
}

@test "dashboard displays correctly formatted output" {
    # Set up some test data
    env AGENT_ID="dashboard_agent" "$SCRIPT_PATH" claim "dashboard_work" "Test dashboard display" >/dev/null
    
    run "$SCRIPT_PATH" dashboard
    [ "$status" -eq 0 ]
    
    # Check for expected dashboard sections
    [[ "$output" =~ "SCRUM AT SCALE DASHBOARD" ]]
    [[ "$output" =~ "CURRENT PROGRAM INCREMENT" ]]
    [[ "$output" =~ "AGENT TEAMS & STATUS" ]]
    [[ "$output" =~ "ACTIVE WORK" ]]
    [[ "$output" =~ "VELOCITY & METRICS" ]]
    [[ "$output" =~ "Active Agents:" ]]
    [[ "$output" =~ "Active Work Items:" ]]
}

@test "concurrent work claims maintain data integrity" {
    # Test concurrent claims don't corrupt JSON
    env COORDINATION_DIR="$TEST_TEMP_DIR" AGENT_ID="concurrent_a" "$SCRIPT_PATH" claim "concurrent_test_a" "Test A" >/dev/null &
    env COORDINATION_DIR="$TEST_TEMP_DIR" AGENT_ID="concurrent_b" "$SCRIPT_PATH" claim "concurrent_test_b" "Test B" >/dev/null &
    wait
    
    # Verify JSON remains valid after concurrent writes
    assert_json_valid "$COORDINATION_DIR/work_claims.json"
    
    # At least one claim should have succeeded
    if command -v jq >/dev/null 2>&1 && [ -f "$COORDINATION_DIR/work_claims.json" ]; then
        local count
        count=$(jq 'length' "$COORDINATION_DIR/work_claims.json")
        [ "$count" -ge 1 ]
    else
        # Fallback: check file exists with content
        [ -s "$COORDINATION_DIR/work_claims.json" ]
    fi
}

@test "error handling for missing work item ID" {
    run "$SCRIPT_PATH" progress "" "50" "in_progress"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "ERROR: No work item ID specified" ]]
    
    run "$SCRIPT_PATH" complete "" "success" "5"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "ERROR: No work item ID specified" ]]
}

@test "error handling for missing work claims file" {
    run "$SCRIPT_PATH" progress "nonexistent_work_id" "50" "in_progress"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "ERROR: Work claims file not found" ]]
}

@test "help command displays usage information" {
    run "$SCRIPT_PATH" help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "SCRUM AT SCALE AGENT COORDINATION HELPER" ]]
    [[ "$output" =~ "Usage:" ]]
    [[ "$output" =~ "Work Management Commands:" ]]
    [[ "$output" =~ "claim" ]]
    [[ "$output" =~ "progress" ]]
    [[ "$output" =~ "complete" ]]
}

@test "PI planning generates correct output" {
    run "$SCRIPT_PATH" pi-planning
    [ "$status" -eq 0 ]
    [[ "$output" =~ "STARTING PI PLANNING SESSION" ]]
    [[ "$output" =~ "PI OBJECTIVES" ]]
    [[ "$output" =~ "TEAM CAPACITY PLANNING" ]]
    [[ "$output" =~ "Business Value" ]]
}

@test "scrum of scrums displays team coordination" {
    run "$SCRIPT_PATH" scrum-of-scrums
    [ "$status" -eq 0 ]
    [[ "$output" =~ "SCRUM OF SCRUMS COORDINATION" ]]
    [[ "$output" =~ "TEAM UPDATES" ]]
    [[ "$output" =~ "COORDINATION TEAM" ]]
    [[ "$output" =~ "DEVELOPMENT TEAM" ]]
    [[ "$output" =~ "PLATFORM TEAM" ]]
}

@test "innovation planning displays IP iteration structure" {
    run "$SCRIPT_PATH" innovation-planning
    [ "$status" -eq 0 ]
    [[ "$output" =~ "INNOVATION AND PLANNING" ]]
    [[ "$output" =~ "ITERATION" ]]
    [[ "$output" =~ "INNOVATION TIME" ]]
    [[ "$output" =~ "PLANNING ACTIVITIES" ]]
    [[ "$output" =~ "INNOVATION BACKLOG ITEMS" ]]
    [[ "$output" =~ "Technical Debt" ]]
}

@test "innovation planning works with short alias 'ip'" {
    run "$SCRIPT_PATH" ip
    [ "$status" -eq 0 ]
    [[ "$output" =~ "INNOVATION AND PLANNING" ]]
    [[ "$output" =~ "ART: AI Self-Sustaining Agile Release Train" ]]
}

@test "system demo displays integrated solution presentation" {
    run "$SCRIPT_PATH" system-demo
    [ "$status" -eq 0 ]
    [[ "$output" =~ "SYSTEM DEMO - INTEGRATED SOLUTION" ]]
    [[ "$output" =~ "PI INCREMENT OBJECTIVES ACHIEVED" ]]
    [[ "$output" =~ "FEATURES DEMONSTRATED" ]]
    [[ "$output" =~ "ART METRICS SUMMARY" ]]
    [[ "$output" =~ "Nanosecond-precision agent coordination" ]]
    [[ "$output" =~ "PI Velocity:" ]]
}

@test "inspect and adapt displays workshop structure" {
    run "$SCRIPT_PATH" inspect-adapt
    [ "$status" -eq 0 ]
    [[ "$output" =~ "INSPECT AND ADAPT" ]]
    [[ "$output" =~ "WORKSHOP" ]]
    [[ "$output" =~ "PI RESULTS AND METRICS" ]]
    [[ "$output" =~ "PROBLEM-SOLVING WORKSHOP" ]]
    [[ "$output" =~ "IMPROVEMENT BACKLOG ITEMS" ]]
    [[ "$output" =~ "Business Value Delivered" ]]
}

@test "inspect and adapt works with short alias 'ia'" {
    run "$SCRIPT_PATH" ia
    [ "$status" -eq 0 ]
    [[ "$output" =~ "INSPECT AND ADAPT" ]]
    [[ "$output" =~ "Root cause analysis" ]]
}

@test "art sync displays cross-team coordination" {
    run "$SCRIPT_PATH" art-sync
    [ "$status" -eq 0 ]
    [[ "$output" =~ "ART SYNC - ALIGNMENT ACROSS TEAMS" ]]
    [[ "$output" =~ "PROGRAM RISKS AND DEPENDENCIES" ]]
    [[ "$output" =~ "CROSS-TEAM DEPENDENCIES" ]]
    [[ "$output" =~ "ART HEALTH METRICS" ]]
    [[ "$output" =~ "HIGH RISK" ]]
    [[ "$output" =~ "Sprint Goal Achievement" ]]
}

@test "portfolio kanban displays epic flow management" {
    run "$SCRIPT_PATH" portfolio-kanban
    [ "$status" -eq 0 ]
    [[ "$output" =~ "PORTFOLIO KANBAN - EPIC FLOW" ]]
    [[ "$output" =~ "PORTFOLIO VISION" ]]
    [[ "$output" =~ "FUNNEL" ]]
    [[ "$output" =~ "ANALYZING" ]]
    [[ "$output" =~ "PORTFOLIO BACKLOG" ]]
    [[ "$output" =~ "IMPLEMENTING" ]]
    [[ "$output" =~ "DONE" ]]
    [[ "$output" =~ "Autonomous AI Development Ecosystem" ]]
}

@test "coach training displays development program" {
    run "$SCRIPT_PATH" coach-training
    [ "$status" -eq 0 ]
    [[ "$output" =~ "SCRUM AT SCALE COACH TRAINING" ]]
    [[ "$output" =~ "TRAINING PROGRAM" ]]
    [[ "$output" =~ "LEARNING OBJECTIVES" ]]
    [[ "$output" =~ "PRACTICAL EXERCISES" ]]
    [[ "$output" =~ "COACHING COMPETENCY AREAS" ]]
    [[ "$output" =~ "SAFe.*Release Train Engineer" ]]
}

@test "value stream mapping displays end-to-end flow analysis" {
    run "$SCRIPT_PATH" value-stream
    [ "$status" -eq 0 ]
    [[ "$output" =~ "VALUE STREAM MAPPING - END-TO-END FLOW" ]]
    [[ "$output" =~ "CURRENT STATE MAP" ]]
    [[ "$output" =~ "CURRENT STATE METRICS" ]]
    [[ "$output" =~ "FUTURE STATE VISION" ]]
    [[ "$output" =~ "IMPROVEMENT OPPORTUNITIES" ]]
    [[ "$output" =~ "Total Lead Time" ]]
    [[ "$output" =~ "Process Efficiency" ]]
}

@test "value stream mapping works with short alias 'vsm'" {
    run "$SCRIPT_PATH" vsm
    [ "$status" -eq 0 ]
    [[ "$output" =~ "VALUE STREAM MAPPING" ]]
    [[ "$output" =~ "From Concept to Production Deployment" ]]
}

@test "help command displays all new scrum at scale commands" {
    run "$SCRIPT_PATH" help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "innovation-planning.*ip" ]]
    [[ "$output" =~ "system-demo" ]]
    [[ "$output" =~ "inspect-adapt.*ia" ]]
    [[ "$output" =~ "art-sync" ]]
    [[ "$output" =~ "portfolio-kanban" ]]
    [[ "$output" =~ "coach-training" ]]
    [[ "$output" =~ "value-stream.*vsm" ]]
}

@test "all new commands have consistent formatting and structure" {
    # Test that all new commands follow consistent output patterns
    local commands=("innovation-planning" "system-demo" "inspect-adapt" "art-sync" "portfolio-kanban" "coach-training" "value-stream")
    
    for cmd in "${commands[@]}"; do
        run "$SCRIPT_PATH" "$cmd"
        [ "$status" -eq 0 ]
        # Each command should have a header with emoji and title
        [[ "$output" =~ ^[[:space:]]*[🎯🎬🔍🔄📊🎓🗺️] ]]
        # Each command should have separator lines
        [[ "$output" =~ "====" ]]
        # Each command should have at least some date/time information
        [[ "$output" =~ "$(date +%Y)" ]]
    done
}

@test "command aliases work correctly" {
    # Test short aliases
    run "$SCRIPT_PATH" ip
    [ "$status" -eq 0 ]
    [[ "$output" =~ "INNOVATION AND PLANNING" ]]
    
    run "$SCRIPT_PATH" ia  
    [ "$status" -eq 0 ]
    [[ "$output" =~ "INSPECT AND ADAPT" ]]
    
    run "$SCRIPT_PATH" vsm
    [ "$status" -eq 0 ]
    [[ "$output" =~ "VALUE STREAM MAPPING" ]]
}