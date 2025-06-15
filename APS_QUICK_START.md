# APS (Agile Protocol Specification) Quick Start Guide

## Overview
The APS system enables coordinated AI agent swarms to work on complex software projects through structured workflows and communication protocols.

## Quick Start Commands

### 1. Initialize Your Agent Role
```
/aps-init
```
This command will:
- Auto-detect your role based on current system state
- Register your agent session
- Show you what work is available

### 2. Check System Status
```
/aps-status
```
Shows:
- Active agents and their roles
- Current processes and their states
- Pending handoffs and blocked tasks

### 3. Start a New Process (PM_Agent only)
```
/aps-start "User Authentication System"
```
Creates a new APS process with requirements gathering phase.

### 4. Claim Work on Existing Process
```
/aps-claim 001_User_Auth_System
```
Claims an existing process for your agent to work on.

### 5. Hand Off to Next Agent
```
/aps-handoff Architect_Agent
```
Completes your work and notifies the next agent in the pipeline.

## Agent Workflow Pipeline

```
PM_Agent → Architect_Agent → Developer_Agent → QA_Agent → DevOps_Agent
```

Each agent has specific responsibilities:

- **PM_Agent**: Requirements and Gherkin scenarios
- **Architect_Agent**: System design and C4 models  
- **Developer_Agent**: Code implementation and unit tests
- **QA_Agent**: Testing and validation
- **DevOps_Agent**: Deployment and monitoring

## File Structure

APS files follow this naming convention:
- `001_ProcessName_requirements.aps.yaml` - Requirements phase
- `001_ProcessName_architecture.aps.yaml` - Architecture phase
- `001_ProcessName_implementation.aps.yaml` - Development phase
- `001_ProcessName_test_results.aps.yaml` - QA phase
- `001_ProcessName_deployment.aps.yaml` - DevOps phase

## Example Usage Session

```bash
# Initialize as PM Agent (first session)
/aps-init
# Output: PM_AGENT activated

# Start new process
/aps-start "API Rate Limiting"
# Output: Created 001_API_Rate_Limiting_requirements.aps.yaml

# Complete requirements work...
# Hand off to architect
/aps-handoff Architect_Agent

# New session initializes as Architect
/aps-init  
# Output: ARCHITECT_AGENT activated, found work waiting

# Claim the architecture work
/aps-claim 001_API_Rate_Limiting

# Complete architecture work...
# Hand off to developer
/aps-handoff Developer_Agent
```

## Key Features

- **Automatic Role Assignment**: Agents self-assign based on current needs
- **Parallel Work**: Multiple agents can work simultaneously on different processes
- **State Tracking**: All work is tracked and auditable through APS files
- **Communication**: Structured messaging between agents
- **Templates**: Standardized YAML templates for consistency

## Available Commands Reference

| Command | Purpose | Required Role |
|---------|---------|---------------|
| `/aps-init` | Initialize agent and assign role | Any |
| `/aps-status` | Show system status | Any |
| `/aps-start` | Start new process | PM_Agent |
| `/aps-claim` | Claim work on process | Any |
| `/aps-handoff` | Pass work to next agent | Any |
| `/aps-message` | Send message to agent | Any |
| `/aps-implement` | Begin implementation | Developer_Agent |
| `/aps-test` | Execute tests | QA_Agent |
| `/aps-deploy` | Deploy to production | DevOps_Agent |
| `/aps-list` | List all processes | Any |
| `/aps-help` | Show command help | Any |

## Getting Started

1. Run `/aps-init` to get assigned a role
2. Run `/aps-status` to see what work is available
3. Use role-specific commands to complete your tasks
4. Use `/aps-handoff` to pass work to the next agent

The system is designed to be self-organizing - agents will automatically coordinate and work together to complete complex software projects!