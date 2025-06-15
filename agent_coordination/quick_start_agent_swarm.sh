#!/bin/bash

# Quick Start Agent Swarm
# One-command setup for complete S@S agent swarm with Claude Code integration

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🚀 QUICK START: S@S AGENT SWARM"
echo "================================"
echo "Setting up complete agent swarm with worktree isolation..."
echo ""

# Step 1: Initialize swarm coordination
echo "📋 Step 1/6: Initializing swarm coordination..."
./agent_swarm_orchestrator.sh init
echo "✅ Swarm coordination initialized"
echo ""

# Step 2: Deploy agent swarm to worktrees
echo "🌳 Step 2/6: Deploying agent swarm..."
./agent_swarm_orchestrator.sh deploy
echo "✅ Agent swarm deployed to worktrees"
echo ""

# Step 3: Verify environment isolation
echo "🔧 Step 3/6: Verifying environment isolation..."
./worktree_environment_manager.sh list
echo "✅ Environment isolation verified"
echo ""

# Step 4: Start coordinated agents
echo "🤖 Step 4/6: Starting coordinated agents..."
./agent_swarm_orchestrator.sh start
echo "✅ Agents started and coordinated"
echo ""

# Step 5: Run initial intelligence analysis
echo "🧠 Step 5/6: Running initial Claude intelligence analysis..."
./coordination_helper.sh claude-analyze-priorities
./coordination_helper.sh claude-health-analysis
echo "✅ Intelligence analysis complete"
echo ""

# Step 6: Show status and next steps
echo "📊 Step 6/6: Agent swarm status..."
./agent_swarm_orchestrator.sh status
echo ""

echo "🎯 AGENT SWARM READY!"
echo "===================="
echo ""
echo "🤖 Active Agents:"
echo "  • Ash Phoenix Migration: worktrees/ash-phoenix-migration/"
echo "  • N8n Improvements: worktrees/n8n-improvements/"
echo "  • Performance Optimization: worktrees/performance-boost/"
echo ""
echo "🌐 Access Points:"
echo "  • Main App: http://localhost:4000"
echo "  • Ash Phoenix: http://localhost:4001"
echo "  • N8n Improvements: http://localhost:4002"
echo "  • Performance: http://localhost:4003"
echo ""
echo "📋 Management Commands:"
echo "  ./manage_worktrees.sh list               # View all worktrees"
echo "  ./agent_swarm_orchestrator.sh status     # Check swarm status"
echo "  ./coordination_helper.sh claude-optimize # Optimize assignments"
echo ""
echo "🔧 Agent Management:"
echo "  cd worktrees/ash-phoenix-migration && ./manage_agent_1.sh status"
echo "  cd worktrees/n8n-improvements && ./manage_agent_1.sh logs"
echo ""
echo "🧠 Intelligence Analysis:"
echo "  ./coordination_helper.sh claude-analyze-priorities"
echo "  ./coordination_helper.sh claude-health-analysis"
echo "  ./coordination_helper.sh claude-team-analysis migration_team"
echo ""
echo "🎯 Start Development:"
echo "  cd worktrees/ash-phoenix-migration/self_sustaining_ash"
echo "  ./scripts/start.sh  # Start Phoenix app"
echo "  claude             # Start Claude Code in this worktree"
echo ""
echo "✨ Your AI agent swarm is now operational with:"
echo "  ✅ Complete environment isolation"
echo "  ✅ S@S coordination protocols"
echo "  ✅ Claude intelligence integration"
echo "  ✅ Real-time monitoring & telemetry"
echo "  ✅ Parallel development capability"