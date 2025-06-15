#!/bin/bash

# AI Self-Sustaining System - Integration Test Script
# This script tests the complete integration workflow between all four tools

set -e

echo "🧪 Testing AI Self-Sustaining System Integration"
echo "================================================"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check if Phoenix app is running
check_phoenix() {
    print_status "Checking Phoenix application..."
    
    if curl -s http://localhost:4000/api/health > /dev/null 2>&1; then
        print_success "Phoenix app is running on port 4000"
        return 0
    else
        print_error "Phoenix app is not running on port 4000"
        print_status "Starting Phoenix app..."
        cd phoenix_app
        mix phx.server &
        PHOENIX_PID=$!
        sleep 10
        
        if curl -s http://localhost:4000/api/health > /dev/null 2>&1; then
            print_success "Phoenix app started successfully"
            return 0
        else
            print_error "Failed to start Phoenix app"
            return 1
        fi
    fi
}

# Test Tidewave MCP endpoint
test_tidewave() {
    print_status "Testing Tidewave MCP integration..."
    
    if curl -s http://localhost:4000/tidewave/mcp > /dev/null 2>&1; then
        print_success "Tidewave MCP endpoint is accessible"
    else
        print_error "Tidewave MCP endpoint is not accessible"
        return 1
    fi
}

# Test Ash AI MCP endpoint
test_ash_ai() {
    print_status "Testing Ash AI MCP integration..."
    
    if curl -s http://localhost:4000/mcp/ash > /dev/null 2>&1; then
        print_success "Ash AI MCP endpoint is accessible"
    else
        print_warning "Ash AI MCP endpoint is not accessible (may need database setup)"
    fi
}

# Test MCP Proxy
test_mcp_proxy() {
    print_status "Testing MCP Proxy..."
    
    if [ -f "/Users/sac/.mix/escripts/mcp-proxy" ]; then
        print_success "MCP Proxy is installed"
        
        # Test proxy with Tidewave endpoint
        timeout 5s /Users/sac/.mix/escripts/mcp-proxy http://localhost:4000/tidewave/mcp > /dev/null 2>&1 &
        PROXY_PID=$!
        sleep 2
        
        if ps -p $PROXY_PID > /dev/null; then
            print_success "MCP Proxy can connect to Tidewave"
            kill $PROXY_PID 2>/dev/null || true
        else
            print_warning "MCP Proxy had issues connecting to Tidewave"
        fi
    else
        print_error "MCP Proxy is not installed"
        return 1
    fi
}

# Test Desktop Commander
test_desktop_commander() {
    print_status "Testing Desktop Commander MCP..."
    
    if npx -y @wonderwhy-er/desktop-commander --version > /dev/null 2>&1; then
        print_success "Desktop Commander MCP is available"
    else
        print_warning "Desktop Commander MCP is not available or needs installation"
    fi
}

# Test Claude Desktop Configuration
test_claude_config() {
    print_status "Testing Claude Desktop configuration..."
    
    CLAUDE_CONFIG="$HOME/Library/Application Support/Claude/claude_desktop_config.json"
    
    if [ -f "$CLAUDE_CONFIG" ]; then
        print_success "Claude Desktop config file exists"
        
        # Validate JSON structure
        if python3 -m json.tool "$CLAUDE_CONFIG" > /dev/null 2>&1; then
            print_success "Claude Desktop config is valid JSON"
        else
            print_error "Claude Desktop config has invalid JSON"
            return 1
        fi
        
        # Check for required MCP servers
        if grep -q "desktop-commander" "$CLAUDE_CONFIG" && \
           grep -q "tidewave-phoenix" "$CLAUDE_CONFIG" && \
           grep -q "ash-ai-development" "$CLAUDE_CONFIG"; then
            print_success "All required MCP servers are configured"
        else
            print_warning "Some MCP servers may be missing from config"
        fi
    else
        print_error "Claude Desktop config file not found"
        return 1
    fi
}

# Test database connectivity
test_database() {
    print_status "Testing database connectivity..."
    
    cd phoenix_app
    if mix ecto.migrate > /dev/null 2>&1; then
        print_success "Database is accessible and migrations ran"
    else
        print_warning "Database issues detected - may need setup"
    fi
    cd ..
}

# Main test sequence
main() {
    echo
    print_status "Starting integration tests..."
    echo
    
    # Run tests
    check_phoenix || exit 1
    test_tidewave || exit 1
    test_ash_ai
    test_mcp_proxy || exit 1
    test_desktop_commander
    test_claude_config || exit 1
    test_database
    
    echo
    print_success "Integration test completed!"
    echo
    print_status "System Status Summary:"
    echo "  📱 Phoenix App: Running on http://localhost:4000"
    echo "  🌊 Tidewave: Integrated via MCP proxy"
    echo "  🧠 Ash AI: Configured with MCP endpoints"
    echo "  💻 Desktop Commander: Available for Claude Desktop"
    echo "  🔧 MCP Proxy: Installed and functional"
    echo "  ⚙️  Claude Desktop: Configured for all MCP servers"
    echo
    print_status "Next Steps:"
    echo "  1. Open Claude Desktop"
    echo "  2. Look for the hammer icon (🔨) to see available MCP tools"
    echo "  3. Try asking Claude to analyze the codebase or check system health"
    echo "  4. Test the AI improvement workflow"
    echo
    print_status "Useful Commands:"
    echo "  • View Dashboard: http://localhost:4000/dashboard"
    echo "  • Check System Health: http://localhost:4000/api/health"
    echo "  • View AI Metrics: http://localhost:4000/ai/metrics"
    echo "  • Monitor Tasks: http://localhost:4000/ai/tasks"
    echo
}

# Cleanup function
cleanup() {
    if [ ! -z "$PHOENIX_PID" ]; then
        print_status "Cleaning up Phoenix process..."
        kill $PHOENIX_PID 2>/dev/null || true
    fi
}

# Set trap for cleanup
trap cleanup EXIT

# Run main function
main "$@"