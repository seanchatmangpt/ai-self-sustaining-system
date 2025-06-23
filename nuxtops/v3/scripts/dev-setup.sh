#!/bin/bash
# NuxtOps V3 Development Setup Script
# Quick setup for local development environment

set -euo pipefail

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}Setting up NuxtOps V3 development environment...${NC}"

# Check if init has been run
if [ ! -f "./deployment/secrets/.postgrespassword" ]; then
    echo -e "${YELLOW}Running initialization first...${NC}"
    ./scripts/init-nuxtops-v3.sh
fi

# Start only essential services for development
echo -e "${GREEN}Starting development services...${NC}"
docker-compose up -d db redis

# Wait for services
echo "Waiting for services to be ready..."
sleep 5

# Install dependencies if needed
if [ ! -d "./applications/nuxt-app/node_modules" ]; then
    echo -e "${GREEN}Installing Node dependencies...${NC}"
    cd applications/nuxt-app
    npm install
    cd ../..
fi

# Start Nuxt in development mode
echo -e "${GREEN}Starting Nuxt development server...${NC}"
docker-compose up -d app

echo -e "${GREEN}Development environment ready!${NC}"
echo ""
echo "Services available at:"
echo "  - Nuxt App: http://localhost:3000"
echo "  - Nuxt DevTools: http://localhost:3000/__nuxt_devtools__"
echo "  - Database: localhost:5436"
echo "  - Redis: localhost:6381"
echo ""
echo "Run 'docker-compose logs -f app' to see application logs"