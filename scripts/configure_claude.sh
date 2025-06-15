#!/bin/bash
# Configure Claude Desktop for the self-sustaining system

set -e

echo "🤖 Configuring Claude Desktop MCP"
echo "================================"

PROJECT_ROOT="/Users/sac/dev/ai-self-sustaining-system"

# Create MCP configuration
cat > "$PROJECT_ROOT/mcp_configs/claude_desktop_config.json" << 'EOF'
{
  "mcpServers": {
    "desktop-commander": {
      "command": "npx",
      "args": ["-y", "@wonderwhy-er/desktop-commander"],
      "autoApprove": ["read_file", "write_file", "list_directory", "search_files"]
    },
    
    "n8n-controller": {
      "command": "node",
      "args": ["/usr/local/lib/node_modules/n8n-mcp-server/build/index.js"],
      "env": {
        "N8N_API_URL": "http://localhost:5678/api/v1",
        "N8N_API_KEY": "WILL_BE_SET_LATER",
        "N8N_WEBHOOK_USERNAME": "webhook_user",
        "N8N_WEBHOOK_PASSWORD": "webhook_pass"
      }
    },
    
    "self-sustaining-system": {
      "command": "/usr/local/bin/mcp-proxy",
      "args": ["http://localhost:4000/mcp"],
      "env": {
        "API_KEY": "WILL_BE_SET_LATER"
      }
    },
    
    "tidewave": {
      "command": "/usr/local/bin/mcp-proxy", 
      "args": ["http://localhost:4000/tidewave/mcp"],
      "autoApprove": ["execute_elixir"]
    }
  }
}
EOF

echo "✅ MCP configuration created"
echo ""
echo "To apply this configuration:"
echo "1. Copy to Claude Desktop config location:"
echo "   cp $PROJECT_ROOT/mcp_configs/claude_desktop_config.json ~/Library/Application\\ Support/Claude/claude_desktop_config.json"
echo "2. Restart Claude Desktop"
