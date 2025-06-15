# 🚀 Quick Start Guide

## Prerequisites Check

Before starting, ensure you have:
- [ ] Elixir installed (`elixir --version`)
- [ ] Node.js installed (`node --version`) 
- [ ] PostgreSQL installed (`psql --version`)
- [ ] Claude Desktop installed
- [ ] Desktop Commander configured in Claude

## Step 1: Run Initial Setup

```bash
cd /Users/sac/dev/ai-self-sustaining-system
./scripts/setup.sh
```

This will:
- Check all prerequisites
- Create project structure
- Initialize git repository

## Step 2: Configure Environment

```bash
cp .env.example .env
# Edit .env with your values
```

Key configurations needed:
- Database credentials
- n8n API key (will be generated)
- Secret key base for Phoenix

## Step 3: Install n8n MCP Server

```bash
npm install -g n8n-mcp-server
```

## Step 4: Create Phoenix Application

```bash
./scripts/create_phoenix_app.sh
```

This will create a Phoenix app with:
- Ash Framework
- Ash AI
- Tidewave
- All necessary dependencies

## Step 5: Configure Claude Desktop

```bash
./scripts/configure_claude.sh
```

Then copy the config:
```bash
cp mcp_configs/claude_desktop_config.json ~/Library/Application\ Support/Claude/claude_desktop_config.json
```

Restart Claude Desktop after copying.

## Step 6: Start the System

```bash
./scripts/start_system.sh
```

This will start:
- PostgreSQL
- n8n (on port 5678)
- Phoenix app (on port 4000)

## Step 7: Import n8n Workflows

1. Open n8n at http://localhost:5678
2. Import the workflow from `n8n_workflows/master_controller.json`
3. Activate the workflow

## Step 8: Monitor the System

In a new terminal:
```bash
./scripts/monitor.sh
```

## Verification

The system is running correctly when:
- Phoenix responds at http://localhost:4000
- n8n UI is accessible at http://localhost:5678
- Claude Desktop shows the MCP tools connected
- The monitor shows all services green

## First Enhancement

To trigger the first self-improvement:
1. Open Claude Desktop
2. Type: "Analyze the system and suggest an enhancement"
3. The system will discover, implement, and test it automatically

## Troubleshooting

If services don't start:
- Check PostgreSQL: `pg_ctl status`
- Check n8n logs: `n8n start --tunnel`
- Check Phoenix logs: `cd phoenix_app/self_sustaining && mix phx.server`
