#!/bin/bash

# Script to add trace_id to telemetry events that are missing it

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}📡 Adding trace_id to telemetry events${NC}"
echo "======================================"

# Function to add trace_id to telemetry measurements
fix_telemetry_in_file() {
    local file=$1
    echo -e "\n${BLUE}🔍 Processing: $file${NC}"
    
    if [[ ! -f "$file" ]]; then
        echo "  ❌ File not found: $file"
        return 1
    fi
    
    # Count telemetry events before and after
    local before_count=$(grep -c ":telemetry.execute" "$file")
    local trace_before=$(grep -A10 ":telemetry.execute" "$file" | grep -c "trace_id")
    
    if [[ $before_count -eq 0 ]]; then
        echo "  ℹ️  No telemetry events found"
        return 0
    fi
    
    echo "  📊 Found $before_count telemetry events, $trace_before already have trace_id"
    
    # Create backup
    cp "$file" "${file}.bak"
    
    # Look for telemetry.execute patterns and suggest trace_id additions
    echo "  🔧 Analyzing telemetry events..."
    
    # Simple pattern: look for telemetry calls without trace_id in measurements
    local needs_fix=$(grep -A5 ":telemetry.execute" "$file" | grep -B5 -A5 "%{" | grep -v "trace_id:" | grep -c "%{")
    
    if [[ $needs_fix -gt 0 ]]; then
        echo "  ${YELLOW}⚠️  $needs_fix measurement maps potentially missing trace_id${NC}"
        echo "  ${YELLOW}⚠️  Manual review and fix recommended${NC}"
        
        # Show examples for manual fixing
        echo -e "\n  📖 Examples to fix manually:"
        echo "  Before: :telemetry.execute([:event], %{key: value}, %{})"
        echo "  After:  :telemetry.execute([:event], %{key: value, trace_id: trace_id}, %{})"
        echo ""
        echo "  Before: %{status: :success, duration: time}"
        echo "  After:  %{status: :success, duration: time, trace_id: trace_id}"
    else
        echo "  ✅ All telemetry events appear to have proper structure"
    fi
    
    return 0
}

# Find all files with telemetry.execute calls
echo -e "${BLUE}🔍 Finding files with telemetry events...${NC}"

TELEMETRY_FILES=$(find . -name "*.ex" -o -name "*.exs" | xargs grep -l ":telemetry.execute" 2>/dev/null | head -20)

if [[ -z "$TELEMETRY_FILES" ]]; then
    echo "❌ No files with telemetry events found"
    exit 0
fi

echo "Found files with telemetry:"
echo "$TELEMETRY_FILES"

# Process each file
for file in $TELEMETRY_FILES; do
    fix_telemetry_in_file "$file"
done

echo -e "\n${GREEN}✅ Telemetry trace analysis complete${NC}"
echo ""
echo "${YELLOW}📋 Manual Action Required:${NC}"
echo "1. Review files marked with ⚠️"
echo "2. Add trace_id to measurement maps where missing"
echo "3. Ensure trace_id variables are available in scope"
echo "4. Consider adding trace_id as context parameter"
echo ""
echo "Example fixes needed:"
echo "- Add trace_id to middleware telemetry calls"
echo "- Include trace_id in step execution measurements"
echo "- Propagate trace_id through workflow contexts"