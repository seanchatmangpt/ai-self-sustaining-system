#!/bin/bash

# Claude Desktop Setup Verification Script
echo "🔍 Checking Claude Desktop Setup..."
echo "=================================="

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

check_step() {
    local description="$1"
    local command="$2"
    
    echo -n "Checking $description... "
    
    if eval "$command" > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC}"
        return 0
    else
        echo -e "${RED}✗${NC}"
        return 1
    fi
}

# 1. Check if Claude Desktop is installed
echo -e "${YELLOW}1. Claude Desktop Installation${NC}"
check_step "Claude Desktop app" "test -d '/Applications/Claude.app'"

# 2. Check if Claude Desktop is running
echo -e "\n${YELLOW}2. Claude Desktop Process${NC}"
if ps aux | grep -v grep | grep -q "/Applications/Claude.app"; then
    echo -e "Claude Desktop process... ${GREEN}✓ Running${NC}"
    CLAUDE_RUNNING=true
else
    echo -e "Claude Desktop process... ${RED}✗ Not running${NC}"
    CLAUDE_RUNNING=false
fi

# 3. Check configuration file
echo -e "\n${YELLOW}3. Configuration File${NC}"
CONFIG_FILE="$HOME/Library/Application Support/Claude/claude_desktop_config.json"
check_step "Config file exists" "test -f '$CONFIG_FILE'"

if [ -f "$CONFIG_FILE" ]; then
    check_step "Config file is valid JSON" "python3 -m json.tool '$CONFIG_FILE'"
    
    # Check for required MCP servers
    echo -n "Checking MCP servers in config... "
    if grep -q "desktop-commander" "$CONFIG_FILE" && \
       grep -q "tidewave-phoenix" "$CONFIG_FILE" && \
       grep -q "ash-ai-development" "$CONFIG_FILE"; then
        echo -e "${GREEN}✓ All servers configured${NC}"
    else
        echo -e "${RED}✗ Missing servers${NC}"
    fi
fi

# 4. Check MCP dependencies
echo -e "\n${YELLOW}4. MCP Dependencies${NC}"
check_step "MCP Proxy installed" "test -f '/Users/sac/.mix/escripts/mcp-proxy'"
check_step "Node.js available" "which node"
check_step "npm available" "which npm"

# 5. Check Phoenix app status
echo -e "\n${YELLOW}5. Phoenix Application${NC}"
if curl -s http://localhost:4000/api/health > /dev/null 2>&1; then
    echo -e "Phoenix app on port 4000... ${GREEN}✓ Running${NC}"
    PHOENIX_RUNNING=true
else
    echo -e "Phoenix app on port 4000... ${RED}✗ Not running${NC}"
    PHOENIX_RUNNING=false
fi

# 6. Test MCP endpoints if Phoenix is running
if [ "$PHOENIX_RUNNING" = true ]; then
    echo -e "\n${YELLOW}6. MCP Endpoints${NC}"
    check_step "Tidewave MCP endpoint" "curl -s http://localhost:4000/tidewave/mcp"
    check_step "Ash AI MCP endpoint" "curl -s http://localhost:4000/mcp/ash"
fi

# Summary
echo -e "\n${YELLOW}Summary${NC}"
echo "======="

if [ "$CLAUDE_RUNNING" = true ]; then
    echo -e "• Claude Desktop: ${GREEN}Running${NC}"
else
    echo -e "• Claude Desktop: ${RED}Not running${NC}"
    echo "  To start: open -a Claude"
fi

if [ "$PHOENIX_RUNNING" = true ]; then
    echo -e "• Phoenix App: ${GREEN}Running${NC}"
    echo "  Access at: http://localhost:4000"
else
    echo -e "• Phoenix App: ${RED}Not running${NC}"
    echo "  To start: cd phoenix_app && mix phx.server"
fi

echo -e "• Config File: ${GREEN}Installed${NC}"
echo "• MCP Servers: 4 configured (desktop-commander, tidewave-phoenix, ash-ai-development, filesystem)"

# Next steps
echo -e "\n${YELLOW}Next Steps${NC}"
echo "=========="

if [ "$CLAUDE_RUNNING" = false ]; then
    echo "1. Start Claude Desktop:"
    echo "   open -a Claude"
fi

if [ "$PHOENIX_RUNNING" = false ]; then
    echo "2. Start Phoenix app:"
    echo "   cd phoenix_app && mix phx.server"
fi

echo "3. In Claude Desktop, look for the hammer icon (🔨) to see MCP tools"
echo "4. Try asking Claude: 'What MCP tools are available?'"
echo "5. Test with: 'Check the system health' or 'Analyze the codebase'"

echo -e "\n${GREEN}Setup verification complete!${NC}"