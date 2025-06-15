#!/bin/bash
# Create Phoenix Application with Ash Framework

set -e

PROJECT_ROOT="/Users/sac/dev/ai-self-sustaining-system"
cd "$PROJECT_ROOT"

echo "🔥 Creating Phoenix Application with Ash Framework"
echo "=============================================="

# Check if Igniter is installed
if ! mix archive | grep -q "igniter_new"; then
    echo "Installing Igniter..."
    mix archive.install hex igniter_new --force
fi

# Create the Phoenix app with all dependencies
echo "Creating Phoenix app with Ash integrations..."

cd phoenix_app

# Use Igniter to create the app with all needed dependencies
mix igniter.new self_sustaining \
  --with phx.new \
  --install ash,ash_postgres,ash_phoenix \
  --install ash_authentication_phoenix,ash_oban \
  --install ash_ai@github:ash-project/ash_ai \
  --install tidewave \
  --yes

echo "✅ Phoenix app created successfully!"
