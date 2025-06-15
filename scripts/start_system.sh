#!/bin/bash
# Start the self-sustaining AI system

set -e

PROJECT_ROOT="/Users/sac/dev/ai-self-sustaining-system"
cd "$PROJECT_ROOT"

echo "🚀 Starting Self-Sustaining AI System"
echo "===================================="

# Load environment variables
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
else
    echo "⚠️  No .env file found. Copy .env.example to .env and configure it."
    exit 1
fi

# Function to check if process is running
is_running() {
    pgrep -f "$1" > /dev/null 2>&1
}

# Start PostgreSQL if not running
if ! pg_isready > /dev/null 2>&1; then
    echo "Starting PostgreSQL..."
    pg_ctl start || brew services start postgresql@14
fi

# Start n8n
if ! is_running "n8n"; then
    echo "Starting n8n..."
    n8n start &
    N8N_PID=$!
    echo "n8n started with PID: $N8N_PID"
    
    # Wait for n8n to be ready
    echo "Waiting for n8n to be ready..."
    until curl -s http://localhost:5678/healthz > /dev/null; do
        sleep 1
    done
    echo "✅ n8n is ready"
fi

# Start Phoenix app
echo "Starting Phoenix application..."
cd phoenix_app/self_sustaining
mix ecto.create
mix ecto.migrate
iex -S mix phx.server &
PHOENIX_PID=$!

echo ""
echo "✅ System started successfully!"
echo ""
echo "Access points:"
echo "- Phoenix: http://localhost:4000"
echo "- n8n: http://localhost:5678"
echo "- MCP endpoint: http://localhost:4000/mcp"
echo "- Tidewave MCP: http://localhost:4000/tidewave/mcp"
echo ""
echo "Press Ctrl+C to stop all services"

# Wait and handle shutdown
trap 'kill $N8N_PID $PHOENIX_PID 2>/dev/null' EXIT
wait
