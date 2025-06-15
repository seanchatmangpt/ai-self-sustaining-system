#!/bin/bash
# Check installation status

echo "🔍 Checking AI Self-Sustaining System Components"
echo "=============================================="
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Function to check command
check_command() {
    local cmd=$1
    local name=$2
    local version_flag=${3:---version}
    
    if command -v $cmd >/dev/null 2>&1; then
        version=$($cmd $version_flag 2>&1 | head -n 1)
        echo -e "${GREEN}✓${NC} $name: $version"
        return 0
    else
        echo -e "${RED}✗${NC} $name: Not installed"
        return 1
    fi
}

# Check core dependencies
echo "Core Dependencies:"
check_command elixir "Elixir"
check_command psql "PostgreSQL"
check_command node "Node.js"
check_command npm "npm"

echo ""
echo "AI/Automation Tools:"
check_command n8n "n8n" || echo "  → Can use 'npx n8n' instead"
check_command claude "Claude CLI" || echo "  → Check Claude Desktop app"

echo ""
echo "MCP Tools:"
check_command mcp-proxy "MCP Proxy" || echo "  → Install with: cargo install --git https://github.com/tidewave-ai/mcp_proxy_rust"

# Check if n8n-mcp-server is installed
echo ""
if [ -f "/usr/local/lib/node_modules/n8n-mcp-server/build/index.js" ]; then
    echo -e "${GREEN}✓${NC} n8n-mcp-server: Installed globally"
elif [ -f "./node_modules/n8n-mcp-server/build/index.js" ]; then
    echo -e "${GREEN}✓${NC} n8n-mcp-server: Installed locally"
else
    echo -e "${RED}✗${NC} n8n-mcp-server: Not installed"
    echo "  → Install with: sudo npm install -g n8n-mcp-server"
fi

# Check Desktop Commander
echo ""
if npx @wonderwhy-er/desktop-commander --version >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Desktop Commander: Available via npx"
else
    echo -e "${YELLOW}?${NC} Desktop Commander: Status unknown"
    echo "  → Setup with: npx @wonderwhy-er/desktop-commander@latest setup"
fi

# Check PostgreSQL status
echo ""
echo "Services:"
if pg_isready >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} PostgreSQL: Running"
else
    echo -e "${RED}✗${NC} PostgreSQL: Not running"
    echo "  → Start with: brew services start postgresql@14 (macOS)"
fi

# Check for project structure
echo ""
echo "Project Structure:"
dirs=("scripts" "n8n_workflows" "mcp_configs" "docs" "monitoring")
for dir in "${dirs[@]}"; do
    if [ -d "$dir" ]; then
        echo -e "${GREEN}✓${NC} /$dir directory exists"
    else
        echo -e "${RED}✗${NC} /$dir directory missing"
    fi
done

# Summary
echo ""
echo "=============================================="
missing=0
[ ! -x "$(command -v elixir)" ] && ((missing++))
[ ! -x "$(command -v psql)" ] && ((missing++))
[ ! -x "$(command -v node)" ] && ((missing++))

if [ $missing -eq 0 ]; then
    echo -e "${GREEN}✅ Core dependencies satisfied!${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Copy .env.example to .env and configure"
    echo "2. Run: ./scripts/create_phoenix_app.sh"
    echo "3. Configure Claude Desktop with ./scripts/configure_claude.sh"
else
    echo -e "${RED}⚠️  Missing $missing core dependencies${NC}"
    echo ""
    echo "Please install missing dependencies first."
    echo "See: docs/INSTALLATION.md for detailed instructions"
fi
