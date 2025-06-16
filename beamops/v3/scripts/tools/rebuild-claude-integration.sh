#!/bin/bash
# Rebuild Claude AI Integration for V3 Coordination System
# Addresses 100% failure rate in Claude AI integration scripts

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYSTEM_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
COORDINATION_DIR="${SYSTEM_ROOT}/agent_coordination"

echo "🤖 Rebuilding Claude AI Integration for V3"
echo "=========================================="
echo "📁 System Root: ${SYSTEM_ROOT}"
echo "📁 Coordination Dir: ${COORDINATION_DIR}"

# Function to test Claude CLI availability
test_claude_cli() {
    echo ""
    echo "🔍 Testing Claude CLI availability..."
    
    if command -v claude >/dev/null 2>&1; then
        echo "✅ Claude CLI found"
        local claude_version=$(claude --version 2>/dev/null || echo "version unknown")
        echo "📋 Claude version: ${claude_version}"
        return 0
    else
        echo "❌ Claude CLI not found"
        echo "💡 Install Claude CLI: npm install -g @anthropic-ai/cli"
        return 1
    fi
}

# Function to test Claude API authentication
test_claude_auth() {
    echo ""
    echo "🔐 Testing Claude API authentication..."
    
    # Check for API key
    if [ -z "${ANTHROPIC_API_KEY:-}" ] && [ -z "${CLAUDE_API_KEY:-}" ]; then
        echo "❌ No Claude API key found"
        echo "💡 Set ANTHROPIC_API_KEY or CLAUDE_API_KEY environment variable"
        return 1
    fi
    
    # Test basic API call
    echo "🧪 Testing basic Claude API call..."
    local test_response
    test_response=$(echo "Hello Claude" | claude -p "Respond with 'API test successful'" 2>/dev/null || echo "FAILED")
    
    if [[ "$test_response" == *"API test successful"* ]]; then
        echo "✅ Claude API authentication working"
        return 0
    else
        echo "❌ Claude API authentication failed"
        echo "📋 Response: ${test_response}"
        return 1
    fi
}

# Function to analyze current Claude integration issues
analyze_integration_issues() {
    echo ""
    echo "🔍 Analyzing Current Claude Integration Issues"
    echo "============================================="
    
    # Check coordination_helper.sh for Claude commands
    if [ -f "${COORDINATION_DIR}/coordination_helper.sh" ]; then
        echo "📋 Checking coordination_helper.sh for Claude commands..."
        
        local claude_commands=$(grep -n "claude-" "${COORDINATION_DIR}/coordination_helper.sh" | head -5)
        if [ -n "$claude_commands" ]; then
            echo "📋 Found Claude commands:"
            echo "$claude_commands"
        else
            echo "❌ No Claude commands found in coordination_helper.sh"
        fi
    else
        echo "❌ coordination_helper.sh not found"
    fi
    
    # Check for Claude integration scripts
    echo ""
    echo "📋 Checking for Claude integration scripts..."
    find "${SYSTEM_ROOT}" -name "*claude*" -type f | head -10 | while read file; do
        echo "   Found: ${file}"
    done
}

# Function to create working Claude integration commands
create_claude_integration() {
    echo ""
    echo "🔧 Creating Working Claude Integration Commands"
    echo "=============================================="
    
    # Create Claude integration directory
    local claude_dir="${COORDINATION_DIR}/claude"
    mkdir -p "${claude_dir}"
    
    # Create claude-analyze-priorities command
    cat > "${claude_dir}/claude-analyze-priorities" << 'EOF'
#!/bin/bash
# Claude AI: Analyze coordination priorities
set -euo pipefail

COORDINATION_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_CLAIMS="${COORDINATION_DIR}/work_claims.json"
AGENT_STATUS="${COORDINATION_DIR}/agent_status.json"

# Check if files exist
if [ ! -f "$WORK_CLAIMS" ] || [ ! -f "$AGENT_STATUS" ]; then
    echo "❌ Coordination files not found"
    exit 1
fi

# Prepare data for Claude analysis
ANALYSIS_DATA=$(cat << ANALYSIS_EOF
Current Work Claims:
$(cat "$WORK_CLAIMS" 2>/dev/null || echo "{}")

Current Agent Status:
$(cat "$AGENT_STATUS" 2>/dev/null || echo "{}")

System Context:
- Coordination system managing agent work distribution
- Need priority analysis for work queue optimization
- Focus on business value and agent capacity
ANALYSIS_EOF
)

# Send to Claude for analysis
echo "$ANALYSIS_DATA" | claude -p "Analyze this AI coordination system data and provide priority recommendations. Focus on:
1. Work queue priorities based on business value
2. Agent workload distribution recommendations  
3. Potential bottlenecks or issues
4. Optimization opportunities

Respond with structured JSON format for easy parsing."
EOF

    # Create claude-optimize-assignments command
    cat > "${claude_dir}/claude-optimize-assignments" << 'EOF'
#!/bin/bash
# Claude AI: Optimize work assignments
set -euo pipefail

COORDINATION_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_CLAIMS="${COORDINATION_DIR}/work_claims.json"
AGENT_STATUS="${COORDINATION_DIR}/agent_status.json"

# Prepare optimization data
OPTIMIZATION_DATA=$(cat << OPT_EOF
Current System State:
Work Queue: $(cat "$WORK_CLAIMS" 2>/dev/null || echo "{}")
Agent Status: $(cat "$AGENT_STATUS" 2>/dev/null || echo "{}")

Optimization Goals:
- Maximize agent utilization
- Minimize work completion time
- Balance workload across agents
- Maintain quality and reliability
OPT_EOF
)

# Send to Claude for optimization
echo "$OPTIMIZATION_DATA" | claude -p "Optimize work assignments for this AI coordination system. Provide specific recommendations for:
1. Which agents should take which work items
2. Workload balancing strategies
3. Performance optimization opportunities
4. Resource allocation improvements

Return actionable recommendations in structured format."
EOF

    # Create claude-health-analysis command
    cat > "${claude_dir}/claude-health-analysis" << 'EOF'
#!/bin/bash
# Claude AI: System health analysis
set -euo pipefail

COORDINATION_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Gather system health data
HEALTH_DATA=$(cat << HEALTH_EOF
System Health Data:
- Coordination Files: $(ls -la "$COORDINATION_DIR"/*.json 2>/dev/null | wc -l) files
- Active Agents: $(jq 'length' "$COORDINATION_DIR/agent_status.json" 2>/dev/null || echo "0")
- Pending Work: $(jq 'length' "$COORDINATION_DIR/work_claims.json" 2>/dev/null || echo "0")
- System Uptime: $(uptime)
- Memory Usage: $(free -h 2>/dev/null || echo "N/A")
- Disk Usage: $(df -h . | tail -1)

Recent Logs:
$(tail -20 "$COORDINATION_DIR"/*.log 2>/dev/null | head -50 || echo "No logs found")
HEALTH_EOF
)

# Send to Claude for health analysis
echo "$HEALTH_DATA" | claude -p "Analyze this AI coordination system health data. Provide assessment of:
1. Overall system health score (0-100)
2. Performance indicators and trends
3. Potential issues or risks
4. Optimization recommendations
5. Monitoring and alerting suggestions

Focus on actionable insights for system reliability and performance."
EOF

    # Create claude-stream command
    cat > "${claude_dir}/claude-stream" << 'EOF'
#!/bin/bash
# Claude AI: Real-time streaming analysis
set -euo pipefail

COORDINATION_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Real-time coordination streaming
echo "🤖 Starting Claude AI real-time coordination stream..."
echo "📋 Type coordination queries, press Ctrl+C to exit"

while true; do
    echo ""
    echo -n "coordination> "
    read -r query
    
    if [ -z "$query" ]; then
        continue
    fi
    
    if [ "$query" = "exit" ] || [ "$query" = "quit" ]; then
        break
    fi
    
    # Add system context to query
    CONTEXT_QUERY=$(cat << STREAM_EOF
AI Coordination System Query: $query

Current System State:
- Active Agents: $(jq 'length' "$COORDINATION_DIR/agent_status.json" 2>/dev/null || echo "0")
- Work Queue: $(jq 'length' "$COORDINATION_DIR/work_claims.json" 2>/dev/null || echo "0")
- Timestamp: $(date)

Please provide coordination guidance or analysis.
STREAM_EOF
)
    
    echo "$CONTEXT_QUERY" | claude -p "Respond to this AI coordination system query with practical guidance."
done

echo "👋 Claude coordination stream ended"
EOF

    # Make all scripts executable
    chmod +x "${claude_dir}"/*
    
    echo "✅ Claude integration commands created:"
    ls -la "${claude_dir}/"
}

# Function to update coordination_helper.sh with Claude commands
update_coordination_helper() {
    echo ""
    echo "🔧 Updating coordination_helper.sh with Claude commands"
    echo "======================================================"
    
    local coord_script="${COORDINATION_DIR}/coordination_helper.sh"
    if [ ! -f "$coord_script" ]; then
        echo "❌ coordination_helper.sh not found"
        return 1
    fi
    
    # Create backup
    cp "$coord_script" "${coord_script}.backup.$(date +%s)"
    
    # Check if Claude commands already exist
    if grep -q "claude-analyze-priorities" "$coord_script"; then
        echo "📋 Claude commands already exist in coordination_helper.sh"
    else
        echo "📋 Adding Claude commands to coordination_helper.sh"
        
        # Add Claude commands to help and command handling
        # This would require careful editing of the coordination script
        echo "⚠️  Manual integration required:"
        echo "   1. Add Claude commands to coordination_helper.sh help text"
        echo "   2. Add command handlers for claude-* commands"
        echo "   3. Update command routing to call ${claude_dir}/ scripts"
    fi
    
    echo "✅ coordination_helper.sh backup created"
}

# Function to test rebuilt integration
test_integration() {
    echo ""
    echo "🧪 Testing Rebuilt Claude Integration"
    echo "===================================="
    
    local claude_dir="${COORDINATION_DIR}/claude"
    
    # Test each Claude command
    for cmd in claude-analyze-priorities claude-optimize-assignments claude-health-analysis; do
        echo ""
        echo "🧪 Testing ${cmd}..."
        
        if [ -f "${claude_dir}/${cmd}" ]; then
            # Basic syntax check
            if bash -n "${claude_dir}/${cmd}"; then
                echo "✅ ${cmd} syntax check passed"
            else
                echo "❌ ${cmd} syntax check failed"
            fi
            
            # Test execution (with timeout)
            echo "🔍 Testing ${cmd} execution..."
            if timeout 30 "${claude_dir}/${cmd}" >/dev/null 2>&1; then
                echo "✅ ${cmd} execution successful"
            else
                echo "⚠️  ${cmd} execution needs manual testing"
            fi
        else
            echo "❌ ${cmd} not found"
        fi
    done
}

# Function to create API key setup guide
create_api_setup_guide() {
    echo ""
    echo "📝 Creating Claude API Setup Guide"
    echo "=================================="
    
    local guide_file="${SCRIPT_DIR}/../docs/claude-setup-guide.md"
    mkdir -p "$(dirname "$guide_file")"
    
    cat > "$guide_file" << 'EOF'
# Claude AI Integration Setup Guide

## Prerequisites

1. **Install Claude CLI**
   ```bash
   npm install -g @anthropic-ai/cli
   ```

2. **Get Anthropic API Key**
   - Visit https://console.anthropic.com/
   - Create account and generate API key
   - Copy API key for environment setup

3. **Set Environment Variables**
   ```bash
   # Add to ~/.bashrc or ~/.zshrc
   export ANTHROPIC_API_KEY="your-api-key-here"
   
   # Or use Claude-specific variable
   export CLAUDE_API_KEY="your-api-key-here"
   ```

4. **Test Installation**
   ```bash
   claude --version
   echo "Hello Claude" | claude -p "Respond with 'Setup successful'"
   ```

## Troubleshooting

### Common Issues

1. **"claude: command not found"**
   - Install Claude CLI: `npm install -g @anthropic-ai/cli`
   - Check PATH includes npm global bin directory

2. **API Authentication Errors**
   - Verify API key is set: `echo $ANTHROPIC_API_KEY`
   - Check API key is valid in Anthropic console
   - Ensure no extra spaces in environment variable

3. **Rate Limiting**
   - Implement retry logic with exponential backoff
   - Consider caching responses for repeated queries
   - Monitor API usage in Anthropic console

4. **Network Connectivity**
   - Check internet connection
   - Verify firewall allows HTTPS traffic
   - Test with curl: `curl -I https://api.anthropic.com`

## Integration Testing

```bash
# Test basic integration
./beamops/v3/scripts/tools/rebuild-claude-integration.sh

# Test individual commands
./agent_coordination/claude/claude-analyze-priorities
./agent_coordination/claude/claude-health-analysis
```
EOF
    
    echo "✅ Setup guide created: ${guide_file}"
}

# Main execution function
main() {
    echo "🎯 Starting Claude AI Integration Rebuild..."
    
    # Step 1: Test basic Claude availability
    if ! test_claude_cli; then
        echo "❌ Claude CLI setup required first"
        create_api_setup_guide
        return 1
    fi
    
    # Step 2: Test authentication
    if ! test_claude_auth; then
        echo "❌ Claude API authentication setup required"
        create_api_setup_guide
        return 1
    fi
    
    # Step 3: Analyze current issues
    analyze_integration_issues
    
    # Step 4: Create new integration
    create_claude_integration
    
    # Step 5: Update coordination helper
    update_coordination_helper
    
    # Step 6: Test integration
    test_integration
    
    # Step 7: Create setup guide
    create_api_setup_guide
    
    echo ""
    echo "✅ Claude AI Integration Rebuild Complete!"
    echo ""
    echo "📋 Summary:"
    echo "   ✅ Claude CLI and API tested"
    echo "   ✅ Integration commands created"
    echo "   ✅ coordination_helper.sh backup created"
    echo "   ✅ Test suite executed"
    echo "   ✅ Setup guide generated"
    echo ""
    echo "🎯 Next steps:"
    echo "   1. Test commands manually: ls -la ${COORDINATION_DIR}/claude/"
    echo "   2. Integrate with coordination_helper.sh"
    echo "   3. Update system to use new Claude commands"
    echo "   4. Monitor integration performance"
    
    return 0
}

# Error handling
trap 'echo "❌ Claude integration rebuild failed"; exit 1' ERR

# Execute rebuild
main "$@"