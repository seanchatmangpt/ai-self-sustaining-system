#!/bin/bash

##############################################################################
# AI Self-Sustaining System Setup Script
##############################################################################
#
# DESCRIPTION:
#   Complete system bootstrap for the AI Self-Sustaining development ecosystem.
#   Sets up Phoenix app, agent coordination, telemetry, and all dependencies.
#
# FEATURES:
#   - Elixir/Phoenix application setup with dependencies
#   - PostgreSQL database initialization and migrations
#   - Agent coordination system with nanosecond precision IDs
#   - OpenTelemetry distributed tracing configuration
#   - Claude AI integration and API key setup
#   - Development environment configuration
#   - LiveBook Teams integration for notebooks
#
# USAGE:
#   ./scripts/setup.sh [--skip-deps] [--skip-db] [--dev-only]
#
# OPTIONS:
#   --skip-deps    Skip dependency installation (mix deps.get, npm install)
#   --skip-db      Skip database setup (assumes PostgreSQL already configured)
#   --dev-only     Setup for development only (skip production configurations)
#
# REQUIREMENTS:
#   - Elixir 1.15+ with OTP 26+
#   - PostgreSQL 14+ running locally
#   - Node.js 18+ for asset compilation
#   - Git for dependency management
#   - Optional: Claude API key for AI features
#
# ENVIRONMENT:
#   - Creates .env file from .env.example
#   - Configures DATABASE_URL for local PostgreSQL
#   - Sets up PHOENIX_SECRET_KEY_BASE
#   - Configures OpenTelemetry endpoints if available
#
##############################################################################

set -e  # Exit on error

echo "🚀 AI Self-Sustaining System Setup"
echo "=================================="

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Project root
PROJECT_ROOT="/Users/sac/dev/ai-self-sustaining-system"
cd "$PROJECT_ROOT"

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to print status
print_status() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $1"
}

# Function to print success
print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

# Function to print error
print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Check prerequisites
print_status "Checking prerequisites..."

# Check for Elixir
if command_exists elixir; then
    print_success "Elixir installed ($(elixir --version | head -n 1))"
else
    print_error "Elixir not found. Please install Elixir first."
    echo "Visit: https://elixir-lang.org/install.html"
    exit 1
fi

# Check for Node.js
if command_exists node; then
    print_success "Node.js installed ($(node --version))"
else
    print_error "Node.js not found. Please install Node.js first."
    echo "Visit: https://nodejs.org/"
    exit 1
fi

# Check for PostgreSQL
if command_exists psql; then
    print_success "PostgreSQL installed"
else
    print_error "PostgreSQL not found. Please install PostgreSQL first."
    echo "Visit: https://www.postgresql.org/download/"
    exit 1
fi

# Check for n8n
if command_exists n8n; then
    print_success "n8n installed"
else
    print_error "n8n not found. Please install n8n manually:"
    echo ""
    echo "Option 1: Using sudo (system-wide):"
    echo "  sudo npm install -g n8n"
    echo ""
    echo "Option 2: Using npx (no installation needed):"
    echo "  npx n8n"
    echo ""
    echo "Option 3: Using Docker:"
    echo "  docker run -it --rm --name n8n -p 5678:5678 -v ~/.n8n:/home/node/.n8n docker.n8n.io/n8nio/n8n"
    echo ""
fi

# Check for Claude Desktop Commander
if command_exists claude; then
    print_success "Claude CLI detected"
else
    print_error "Claude CLI not found. This system works best with Claude Desktop."
fi

print_status "Creating project structure..."

# Create directory structure
mkdir -p phoenix_app
mkdir -p n8n_workflows
mkdir -p mcp_configs
mkdir -p claude_prompts
mkdir -p docs
mkdir -p monitoring

print_success "Project structure created"

# Initialize git repository
if [ ! -d .git ]; then
    print_status "Initializing git repository..."
    git init
    print_success "Git repository initialized"
fi

# Create main README
print_status "Creating documentation..."

cat > README.md << 'EOF'
# AI Self-Sustaining System

A self-improving AI system that uses Claude Code, n8n, Ash Framework, and Tidewave to continuously enhance itself.

## Architecture

- **Claude Code**: AI engine (no API costs)
- **n8n**: Workflow orchestration
- **Ash Framework**: Domain modeling
- **Tidewave**: Runtime intelligence
- **Desktop Commander**: System control

## Quick Start

1. Run the setup: `./scripts/setup.sh`
2. Start the system: `./scripts/start.sh`
3. Monitor: `./scripts/monitor.sh`

## Components

### Phoenix Application
The core Elixir/Phoenix app with Ash resources.

### n8n Workflows
Self-improving workflow definitions.

### MCP Configurations
Model Context Protocol configurations for Claude Desktop.

### Enhancement System
Automatic discovery and implementation of improvements.

## Documentation

See `/docs` for detailed documentation.
EOF

print_success "README created"

# Create .gitignore
cat > .gitignore << 'EOF'
# Dependencies
/phoenix_app/deps/
/phoenix_app/_build/
/phoenix_app/node_modules/

# Database
/phoenix_app/priv/repo/

# Static files
/phoenix_app/priv/static/

# Secrets
.env
*.secret

# Logs
*.log
/logs/

# n8n
/n8n_data/

# OS
.DS_Store
Thumbs.db

# Editor
.vscode/
.idea/
*.swp
*.swo
EOF

print_success "Git configuration created"

echo ""
echo -e "${GREEN}✅ Initial setup complete!${NC}"
echo ""
echo "Next steps:"
echo "1. Run: ./scripts/create_phoenix_app.sh"
echo "2. Run: ./scripts/configure_claude.sh"
echo "3. Run: ./scripts/start_system.sh"
