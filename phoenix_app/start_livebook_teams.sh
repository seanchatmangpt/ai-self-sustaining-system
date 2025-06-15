#!/bin/bash

# Livebook Teams Startup Script for AI Self-Sustaining System
# This script starts Livebook Teams with proper integration to the Phoenix application

set -e

# Configuration
LIVEBOOK_PORT=8080
LIVEBOOK_TOKEN=${LIVEBOOK_TOKEN:-"dev-self-sustaining-livebook-token"}
LIVEBOOK_DATA_PATH="priv/livebook_data"
PHOENIX_NODE="self_sustaining@localhost"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Starting Livebook Teams for AI Self-Sustaining System${NC}"

# Check if in correct directory
if [ ! -f "mix.exs" ]; then
    echo -e "${RED}❌ Error: Please run this script from the Phoenix app directory${NC}"
    exit 1
fi

# Create necessary directories
echo -e "${BLUE}📁 Creating Livebook data directories...${NC}"
mkdir -p "$LIVEBOOK_DATA_PATH/dev"
mkdir -p "$LIVEBOOK_DATA_PATH/notebooks"

# Check if Phoenix is running
echo -e "${BLUE}🔍 Checking Phoenix application status...${NC}"
if ! pgrep -f "phoenix" > /dev/null; then
    echo -e "${YELLOW}⚠️  Phoenix application not detected. Starting Phoenix first...${NC}"
    echo "Run: mix phx.server"
    echo "Then restart this script."
    exit 1
fi

# Install dependencies if needed
if [ ! -d "deps/livebook" ]; then
    echo -e "${BLUE}📦 Installing Livebook dependencies...${NC}"
    mix deps.get
fi

# Start Livebook Teams with configuration
echo -e "${GREEN}🎯 Starting Livebook Teams on port $LIVEBOOK_PORT${NC}"

export LIVEBOOK_PORT="$LIVEBOOK_PORT"
export LIVEBOOK_TOKEN="$LIVEBOOK_TOKEN"
export LIVEBOOK_DATA_PATH="$LIVEBOOK_DATA_PATH"
export LIVEBOOK_NODE="$PHOENIX_NODE"

# Enable Teams features
export LIVEBOOK_TEAMS_ENABLED=true
export LIVEBOOK_IFRAME_PORT=4002
export LIVEBOOK_FEATURE_FLAGS="teams,deployment,collaboration,apps"

# Database connection for notebooks
export LIVEBOOK_DATABASE_URL="ecto://sac:dev_password@localhost:5432/self_sustaining_dev"

# Start Livebook with integrated settings
echo -e "${GREEN}📋 Livebook Teams Configuration:${NC}"
echo "  • Port: $LIVEBOOK_PORT"
echo "  • Data Path: $LIVEBOOK_DATA_PATH"
echo "  • Phoenix Integration: Enabled"
echo "  • Teams Features: Enabled"
echo "  • Token: $LIVEBOOK_TOKEN"
echo ""

echo -e "${GREEN}🌐 Access URLs:${NC}"
echo "  • Livebook Teams: http://localhost:$LIVEBOOK_PORT"
echo "  • Phoenix Integration: http://localhost:4001/livebook"
echo "  • API Endpoints: http://localhost:4001/api/livebook/*"
echo ""

echo -e "${BLUE}🔗 Notebooks Available:${NC}"
if [ -d "$LIVEBOOK_DATA_PATH/notebooks" ]; then
    for notebook in "$LIVEBOOK_DATA_PATH/notebooks"/*.livemd; do
        if [ -f "$notebook" ]; then
            basename "$notebook" .livemd | sed 's/_/ /g' | sed 's/\b\w/\u&/g'
        fi
    done
else
    echo "  • No notebooks found in $LIVEBOOK_DATA_PATH/notebooks"
fi

echo ""
echo -e "${GREEN}✅ Starting Livebook Teams...${NC}"

# Start Livebook with all the configuration
livebook server \
    --port "$LIVEBOOK_PORT" \
    --home "$LIVEBOOK_DATA_PATH" \
    --token "$LIVEBOOK_TOKEN" \
    --node "$PHOENIX_NODE" \
    --cookie "self_sustaining_system_cookie" \
    --name "livebook@localhost" \
    --verbose

echo -e "${RED}🛑 Livebook Teams stopped${NC}"