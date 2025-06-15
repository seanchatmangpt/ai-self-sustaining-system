#!/bin/bash

# Script to automatically add trace_id support to reactor files

BLUE='\033[0;34m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔧 Adding trace_id support to reactor files${NC}"
echo "================================================"

# List of reactor files that need trace_id support
REACTOR_FILES=(
    "lib/self_sustaining/workflows/aps_reactor.ex"
    "lib/self_sustaining/benchmarks/reactor_performance_benchmark.ex"
    "lib/self_sustaining/benchmarks/test_reactor.ex"
    "lib/self_sustaining/benchmarks/simple_test_reactor.ex"
    "lib/self_sustaining/telemetry_pipeline/otlp_data_pipeline_reactor.ex"
    "lib/mix/tasks/self_sustaining.reactor.run.ex"
)

add_trace_input_if_missing() {
    local file=$1
    echo -e "\n${BLUE}🔍 Processing: $file${NC}"
    
    if [[ ! -f "$file" ]]; then
        echo "  ❌ File not found: $file"
        return 1
    fi
    
    # Check if trace_id input already exists
    if grep -q "input :trace_id" "$file"; then
        echo "  ✅ trace_id input already exists"
        return 0
    fi
    
    # Add trace_id input after the last input
    if grep -q "input :" "$file"; then
        # Find the last input line and add trace_id after it
        local last_input_line=$(grep -n "input :" "$file" | tail -1 | cut -d: -f1)
        sed -i "${last_input_line}a\\  input :trace_id" "$file"
        echo "  ✅ Added trace_id input"
    else
        echo "  ⚠️  No input declarations found - manual intervention needed"
    fi
}

fix_logger_calls() {
    local file=$1
    echo "  🔧 Fixing Logger calls..."
    
    # Count current logger calls without trace_id
    local before_count=$(grep -c "Logger\." "$file" 2>/dev/null || echo "0")
    local trace_calls_before=$(grep -c "trace_id:" "$file" 2>/dev/null || echo "0")
    
    # Add trace_id to Logger calls that don't have it
    # This is a simplified approach - more complex cases may need manual fixes
    if [[ $before_count -gt 0 ]]; then
        echo "    Found $before_count Logger calls, $trace_calls_before already have trace_id"
        echo "    ⚠️  Manual review recommended for Logger calls"
    fi
}

update_telemetry_events() {
    local file=$1
    echo "  📡 Checking telemetry events..."
    
    local telemetry_count=$(grep -c ":telemetry.execute" "$file" 2>/dev/null || echo "0")
    local trace_telemetry_count=$(grep -A5 ":telemetry.execute" "$file" | grep -c "trace_id" 2>/dev/null || echo "0")
    
    if [[ $telemetry_count -gt 0 ]]; then
        echo "    Found $telemetry_count telemetry events, $trace_telemetry_count include trace_id"
        if [[ $trace_telemetry_count -lt $telemetry_count ]]; then
            echo "    ⚠️  Some telemetry events may be missing trace_id"
        fi
    fi
}

# Process each reactor file
for file in "${REACTOR_FILES[@]}"; do
    if add_trace_input_if_missing "$file"; then
        fix_logger_calls "$file"
        update_telemetry_events "$file"
    fi
done

echo -e "\n${GREEN}✅ Trace support addition complete${NC}"
echo "⚠️  Manual review recommended for:"
echo "   - Logger calls parameter addition"
echo "   - Telemetry event trace_id inclusion"
echo "   - Step argument trace_id propagation"