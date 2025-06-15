#!/bin/bash

# Test XAVOS Commands - Using Exact Commands as Specified
# This script tests the exact command sequence provided

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DIR="$SCRIPT_DIR/xavos_test"

echo "🧪 TESTING XAVOS COMMANDS"
echo "========================"
echo "Testing the exact command sequence provided"
echo ""

# Cleanup function
cleanup() {
    if [ -d "$TEST_DIR" ]; then
        echo "🧹 Cleaning up test directory..."
        rm -rf "$TEST_DIR"
    fi
}

# Set trap for cleanup
trap cleanup EXIT

# Create test directory
echo "📁 Creating test directory..."
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"

echo "📍 Working directory: $(pwd)"
echo ""

# Step 1: Install archives
echo "📦 Step 1/4: Installing archives..."
echo "Running: mix archive.install hex igniter_new --force"
mix archive.install hex igniter_new --force

echo "Running: mix archive.install hex phx_new 1.8.0-rc.3 --force"  
mix archive.install hex phx_new 1.8.0-rc.3 --force

echo "✅ Archives installed"
echo ""

# Step 2: Generate XAVOS project
echo "🔥 Step 2/4: Generating XAVOS project..."
echo "Running the massive igniter.new command..."
echo ""

# EXACT COMMAND AS SPECIFIED
mix igniter.new xavos --with phx.new --install ash,ash_phoenix \
  --install ash_json_api,ash_postgres \
  --install ash_sqlite,ash_authentication \
  --install ash_authentication_phoenix,ash_admin \
  --install ash_oban,oban_web --install ash_state_machine,ash_events \
  --install ash_money,ash_double_entry --install ash_archival,live_debugger \
  --install mishka_chelekom,tidewave --install ash_paper_trail,ash_ai \
  --install cloak,ash_cloak --install beacon,beacon_live_admin \
  --auth-strategy password --auth-strategy magic_link \
  --auth-strategy api_key --beacon.site cms \
  --beacon-live-admin.path /cms/admin --yes

echo "✅ XAVOS project generated"
echo ""

# Step 3: Run ash.setup  
echo "🏗️ Step 3/4: Running ash.setup..."
echo "Running: cd xavos && mix ash.setup"

# EXACT COMMAND AS SPECIFIED
cd xavos && mix ash.setup

echo "✅ Ash setup completed"
echo ""

# Step 4: Verify installation
echo "🔍 Step 4/4: Verifying installation..."

# Check if key files exist
echo "Checking generated files:"
[ -f "mix.exs" ] && echo "  ✅ mix.exs exists" || echo "  ❌ mix.exs missing"
[ -f "config/config.exs" ] && echo "  ✅ config.exs exists" || echo "  ❌ config.exs missing"  
[ -d "lib/xavos" ] && echo "  ✅ lib/xavos directory exists" || echo "  ❌ lib/xavos missing"
[ -f "lib/xavos_web/router.ex" ] && echo "  ✅ router.ex exists" || echo "  ❌ router.ex missing"

echo ""

# Check dependencies in mix.exs
echo "Checking key dependencies in mix.exs:"
grep -q "ash.*~>" mix.exs && echo "  ✅ ash dependency found" || echo "  ❌ ash dependency missing"
grep -q "ash_phoenix.*~>" mix.exs && echo "  ✅ ash_phoenix dependency found" || echo "  ❌ ash_phoenix dependency missing"
grep -q "ash_authentication.*~>" mix.exs && echo "  ✅ ash_authentication dependency found" || echo "  ❌ ash_authentication dependency missing"
grep -q "beacon.*~>" mix.exs && echo "  ✅ beacon dependency found" || echo "  ❌ beacon dependency missing"

echo ""

# Test compilation
echo "🔧 Testing compilation..."
if mix compile; then
    echo "✅ Project compiles successfully"
else
    echo "❌ Compilation failed"
    exit 1
fi

echo ""

# Test basic functionality
echo "🧪 Testing basic functionality..."
if mix run -e "IO.puts('XAVOS test successful!')"; then
    echo "✅ Basic functionality test passed"
else
    echo "❌ Basic functionality test failed"
    exit 1
fi

echo ""

# Show project structure
echo "📋 Generated project structure:"
find . -maxdepth 3 -type f -name "*.ex" | head -10 | while read file; do
    echo "  📄 $file"
done

echo ""

# Show final status
echo "🎯 COMMAND TEST RESULTS"
echo "======================="
echo "✅ Archive installation: SUCCESS"
echo "✅ Project generation: SUCCESS"  
echo "✅ Ash setup: SUCCESS"
echo "✅ Compilation: SUCCESS"
echo "✅ Basic functionality: SUCCESS"
echo ""
echo "🌟 ALL COMMANDS WORK AS EXPECTED!"
echo ""
echo "📍 Generated project location: $TEST_DIR/xavos"
echo "🚀 Ready for development!"

# Don't cleanup on success - let user examine the generated project
trap - EXIT
echo ""
echo "💡 Test project preserved at: $TEST_DIR/xavos"
echo "   Examine the generated code to see what igniter created"
echo "   Run 'rm -rf $TEST_DIR' to clean up when done"