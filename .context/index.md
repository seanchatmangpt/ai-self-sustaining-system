---
module-name: "AI Self-Sustaining System"
version: "0.1.0"
description: "An autonomous AI system that continuously discovers, implements, and deploys improvements to itself using Claude Code, n8n workflows, Ash Framework, and Tidewave integration. The system operates without human intervention, learning and evolving through automated enhancement cycles."
related-modules:
  - name: "Phoenix Application"
    path: ./phoenix_app
    description: "Core Elixir/Phoenix web application with Ash Framework"
  - name: "n8n Workflows" 
    path: ./n8n_workflows
    description: "Workflow orchestration and automation definitions"
  - name: "System Scripts"
    path: ./scripts
    description: "Setup, monitoring, and management scripts"
  - name: "Documentation"
    path: ./docs
    description: "Project documentation and specifications"
architecture:
  style: "Event-Driven Self-Improving Architecture with APS Agent Swarm"
  components:
    - name: "APS Agent Coordination System"
      description: "Multi-agent swarm using Agile Protocol Specification (APS) for autonomous task coordination"
      patterns:
        - name: "Agent Role Assignment"
          usage: "Automatic role detection and assignment for PM, Architect, Developer, QA, and DevOps agents"
        - name: "APS YAML Protocol"
          usage: "Standardized YAML format for inter-agent communication and workflow definitions"
        - name: "Sequential Agent Pipeline"
          usage: "PM → Architect → Developer → QA → DevOps workflow with parallel support capabilities"
    - name: "Self-Improvement Engine"
      description: "Core AI system that discovers, plans, implements, and tests improvements autonomously"
      patterns:
        - name: "Enhancement Discovery Loop"
          usage: "Continuously monitors system health and performance to identify improvement opportunities"
        - name: "Auto-Implementation Pipeline"
          usage: "Uses Claude Code CLI to generate and apply code changes, migrations, and tests"
        - name: "Meta-Enhancement System"
          usage: "Improves the improvement system itself through recursive self-modification"
    - name: "n8n Workflow Engine"
      description: "Orchestrates complex multi-step processes and integrations"
      patterns:
        - name: "Reactor DSL Integration"
          usage: "Custom DSL for defining workflows that compile to n8n JSON format"
        - name: "MCP Proxy Pattern"
          usage: "Bridges n8n workflows with Ash Framework resources via Model Context Protocol"
    - name: "Phoenix Web Layer"
      description: "Real-time web interface for monitoring and controlling the system"
      patterns:
        - name: "LiveView Dashboard Pattern"
          usage: "Real-time updates of system status, metrics, and active improvements"
        - name: "API Gateway Pattern"
          usage: "Centralized endpoints for health checks, metrics, and webhook handling"
    - name: "Claude Code Integration"
      description: "Direct integration with Claude Code CLI for cost-effective AI operations"
      patterns:
        - name: "CLI Wrapper Pattern"
          usage: "GenServer wrapper around Claude Code CLI with streaming and JSON parsing"
        - name: "Task-Specific Prompting"
          usage: "Specialized prompts for code generation, analysis, and refactoring tasks"
    - name: "Ash Framework Domain Layer"
      description: "Domain modeling and resource management with AI-powered actions"
      patterns:
        - name: "AI-Enhanced Resources"
          usage: "Ash resources with AI-powered actions using ash_ai integration"
        - name: "Enhancement Tracking"
          usage: "Persistent storage and management of discovered and implemented improvements"
technologies:
  primary:
    - name: "Elixir/Phoenix"
      version: "~> 1.7.0"
      purpose: "Main application framework and web server"
    - name: "Ash Framework"
      version: "~> 3.0"
      purpose: "Domain modeling, resource management, and AI integration"
    - name: "n8n"
      version: "latest"
      purpose: "Workflow orchestration and automation"
    - name: "Claude Code CLI"
      version: "latest"
      purpose: "AI code generation and analysis without API costs"
    - name: "PostgreSQL"
      version: "latest"
      purpose: "Primary database for system state and enhancement tracking"
  supporting:
    - name: "Tidewave"
      purpose: "Runtime intelligence and MCP integration"
    - name: "Phoenix LiveView"
      purpose: "Real-time web interface components"
    - name: "Oban"
      purpose: "Background job processing via ash_oban"
    - name: "Telemetry"
      purpose: "System monitoring and metrics collection"
interfaces:
  web:
    - endpoint: "/"
      description: "Main dashboard with system status and controls"
    - endpoint: "/ai/metrics"
      description: "Real-time AI performance metrics display"
    - endpoint: "/ai/improvements" 
      description: "Management interface for discovered and implemented improvements"
    - endpoint: "/ai/tasks"
      description: "Active task monitoring and control interface"
  api:
    - endpoint: "/api/health"
      description: "System health check endpoint"
    - endpoint: "/api/metrics"
      description: "Performance metrics API for external monitoring"
    - endpoint: "/api/webhooks/n8n/:workflow_id"
      description: "Webhook handlers for n8n workflow integration"
    - endpoint: "/mcp"
      description: "Model Context Protocol endpoints for Claude Desktop integration"
key-concepts:
  - name: "APS (Agile Protocol Specification)"
    description: "YAML-based protocol for defining processes, roles, activities, scenarios, and data structures for agent coordination"
  - name: "Agent Role Assignment"
    description: "Automatic detection and assignment of specialized agent roles (PM, Architect, Developer, QA, DevOps) based on current system state"
  - name: "Sequential Agent Pipeline"
    description: "Structured workflow where agents pass work through PM → Architect → Developer → QA → DevOps sequence with parallel support"
  - name: "Enhancement Discovery"
    description: "Automated analysis of system performance, errors, and metrics to identify improvement opportunities"
  - name: "Auto-Implementation"
    description: "Autonomous code generation, testing, and deployment of improvements using Claude Code CLI"
  - name: "Meta-Enhancement"
    description: "Self-improvement of the improvement system itself through recursive enhancement cycles"
  - name: "Workflow Compilation"
    description: "Custom DSL that compiles to n8n workflow JSON for complex process orchestration"
  - name: "MCP Integration"
    description: "Model Context Protocol integration enabling seamless Claude Desktop interaction"
  - name: "Agent Swarm Coordination"
    description: "Multi-agent system with parallel work capabilities and inter-agent communication through APS files"
development:
  setup: "Run ./scripts/setup.sh for complete system initialization"
  start: "Use ./scripts/start_system.sh to start all services (PostgreSQL, n8n, Phoenix)"
  monitor: "Execute ./scripts/monitor.sh for real-time system monitoring"
  test: "Run mix test in phoenix_app directory for application tests"
deployment:
  local: "Complete local development environment with all services"
  services:
    - name: "Phoenix Application"
      port: 4000
      url: "http://localhost:4000"
    - name: "n8n Workflow UI"
      port: 5678
      url: "http://localhost:5678"
    - name: "PostgreSQL Database"
      port: 5432
      description: "Primary data storage"
current-status: "OPERATIONAL - Core APS Workflow Engine deployed and tested successfully. System compiles cleanly and is ready for production agent coordination."
completed-milestones:
  - "✅ APS Workflow Engine implementation completed (001_APS_Workflow_Engine)"
  - "✅ All QA tests passed (3/3 Gherkin scenarios)"
  - "✅ DevOps deployment successful with database migrations"
  - "✅ Agent swarm coordination system operational"
  - "✅ Phoenix application compiles successfully"
  - "✅ PostgreSQL database with AI extensions configured"
  - "✅ Multi-agent parallel work capabilities functional"
next-steps:
  - "Implement discovered system enhancements"
  - "Optimize workflow performance based on telemetry"
  - "Expand autonomous enhancement discovery capabilities"
  - "Add comprehensive integration tests for agent workflows"
  - "Deploy monitoring and alerting for production operations"
---

# AI Self-Sustaining System

This is an innovative autonomous AI system that continuously discovers, implements, and deploys improvements to itself without human intervention. The system combines the power of Claude Code CLI, n8n workflow orchestration, Ash Framework domain modeling, and Phoenix web framework to create a truly self-evolving software system.

## Core Innovation

The fundamental innovation lies in the **self-improvement loop**:

1. **Discovery**: System monitors its own health, performance, and error patterns
2. **Planning**: Claude Code CLI analyzes issues and generates improvement plans
3. **Implementation**: Autonomous code generation, migration creation, and dependency management
4. **Testing**: Automatic test generation and execution for all changes
5. **Deployment**: Safe deployment of successful improvements
6. **Meta-Enhancement**: The improvement system enhances itself recursively

## Architecture Highlights

### Self-Improvement Engine
- `SelfSustaining.SelfImprovement.Supervisor`: Orchestrates the entire enhancement process
- `SelfSustaining.SelfImprovement.EnhancementDiscovery`: AI-powered issue detection and opportunity identification
- `SelfSustaining.SelfImprovement.AutoImplementer`: Autonomous code implementation using Claude Code CLI
- `SelfSustaining.SelfImprovement.AutoTester`: Comprehensive test generation and execution
- `SelfSustaining.SelfImprovement.MetaEnhancer`: Self-improvement of the improvement system

### Integration Layer
- **Claude Code CLI Integration**: Cost-effective AI operations without API charges
- **n8n Workflow Engine**: Complex process orchestration with custom Reactor DSL
- **Ash Framework**: AI-enhanced domain resources with `ash_ai` integration
- **Phoenix LiveView**: Real-time monitoring and control interface

### Advanced Features
- **MCP Protocol Integration**: Seamless Claude Desktop integration
- **Workflow Compilation**: Custom DSL that generates n8n workflow JSON
- **Performance Monitoring**: Real-time system health and improvement tracking
- **Infinite Agentic Enhancement**: Planned evolution to multi-agent parallel improvement system

## Getting Started

```bash
# Complete system setup
./scripts/setup.sh

# Start all services
./scripts/start_system.sh

# Monitor system health
./scripts/monitor.sh

# Access the dashboard
open http://localhost:4000
```

## System Status

Currently **OPERATIONAL** with core APS Workflow Engine deployed and tested successfully. The system is now ready for production agent coordination with:

- ✅ **APS Agent Swarm**: Multi-agent coordination system fully functional
- ✅ **Workflow Engine**: Process automation and handoff management operational  
- ✅ **Database Layer**: PostgreSQL with AI extensions configured and migrated
- ✅ **Phoenix Application**: Web interface and API endpoints ready
- ✅ **Code Quality**: Clean compilation with warnings resolved

The system has successfully transitioned from development to operational status and is actively coordinating multiple AI agents for autonomous improvement cycles.

## Future Vision

The system is designed to evolve toward "Infinite Agentic Enhancement" - a multi-agent system where specialized AI agents work in parallel to continuously improve different aspects of the system, creating an exponentially self-improving AI infrastructure.