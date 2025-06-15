# AI Self-Sustaining System - Technical Guide

This file provides technical guidance for working with the AI self-sustaining system's n8n DSL framework and comprehensive testing suite.

## Project Overview

This is an AI self-sustaining system that uses Claude Code, n8n, Ash Framework, and Tidewave to continuously enhance itself. The system monitors its own health, discovers improvements, implements changes, and learns from results.

## Architecture

- **Phoenix Application** (`phoenix_app/`): Core Elixir/Phoenix app using Ash Framework for domain modeling
- **n8n Workflows** (`n8n_workflows/`): Workflow orchestration for self-improvement processes
- **Scripts** (`scripts/`): System management and monitoring scripts
- **MCP Integration**: Model Context Protocol configurations for Claude Desktop integration

## Development Commands

### System Setup and Management
```bash
# Initial system setup
./scripts/setup.sh

# Start all services (PostgreSQL, n8n, Phoenix)
./scripts/start_system.sh

# Monitor system health and metrics
./scripts/monitor.sh

# Check system status
./scripts/check_status.sh

# Configure Claude Desktop MCP
./scripts/configure_claude.sh
```

### Phoenix Application
```bash
cd phoenix_app/self_sustaining

# Setup application
mix setup

# Start development server
mix phx.server

# Interactive development
iex -S mix phx.server

# Database operations
mix ecto.create
mix ecto.migrate
mix ecto.reset

# Run tests
mix test

# Assets
mix assets.build
mix assets.deploy
```

### n8n Workflow Management
```bash
# Start n8n (if not using system start script)
n8n start

# Or using npx if not globally installed
npx n8n start

# Access n8n UI at http://localhost:5678
```

### n8n DSL Framework
```bash
# Compile workflows using DSL
iex -S mix
N8n.WorkflowManager.compile_all_workflows()

# Validate workflows
N8n.WorkflowManager.validate_all_workflows()

# Export specific workflow
N8n.WorkflowManager.compile_and_export_workflow(SelfSustaining.Workflows.SelfImprovement)

# Import workflow to n8n
N8n.WorkflowManager.import_to_n8n(SelfSustaining.Workflows.HealthCheck)

# Generate new workflow with AI
SelfSustaining.AI.WorkflowGenerator.generate_workflow(%{type: :monitoring, priority: :high})

# Start self-improvement orchestrator
SelfSustaining.AI.SelfImprovementOrchestrator.trigger_improvement_cycle()

# Run workflow tests
mix test test/n8n/
```

## Key Components

### Self-Improvement System
The core self-improvement functionality is orchestrated through:
- `SelfSustaining.SelfImprovement.Supervisor`: Main supervisor for enhancement processes
- `SelfSustaining.ClaudeCode.Server`: Integration with Claude Code CLI (no API costs)
- `SelfSustaining.N8n.McpProxy`: MCP proxy for n8n integration
- `SelfSustaining.PerformanceMonitor`: System performance monitoring
- `SelfSustaining.AI.SelfImprovementOrchestrator`: Main orchestrator for improvement cycles
- `SelfSustaining.AI.WorkflowGenerator`: AI-powered workflow generation and optimization

### Claude Code Integration
The system uses Claude Code CLI instead of API calls via `SelfSustaining.ClaudeCode`:
- Located at `/usr/local/bin/claude` by default
- Supports streaming for large tasks
- Handles JSON output parsing
- Task-specific command building (generate_code, analyze, refactor)

### n8n Workflow DSL Framework
Comprehensive DSL framework for defining n8n workflows in Elixir:
- **Core DSL**: `N8n.Reactor.Dsl` - Spark-based DSL for workflow definitions
- **Transformers**: Compile-time validation, optimization, and JSON generation
- **Workflow Manager**: `N8n.WorkflowManager` - Handles compilation, export, and n8n integration
- **Type Safety**: Compile-time validation of nodes, connections, and parameters
- **Auto-generation**: Automatic connection generation from node dependencies
- **Optimization**: Built-in workflow optimization and performance tuning
- **Testing**: Comprehensive test framework for workflow validation

#### DSL Features
- Declarative workflow definitions with type-safe parameters
- Automatic node positioning and connection optimization
- Support for all major n8n node types (HTTP, Code, Triggers, Conditions)
- Manual and automatic connection management
- Compile-to-JSON with n8n-compatible output
- Real-time validation and error reporting

### Ash Framework Integration
Using Ash 3.0+ with:
- `ash_postgres` for database operations
- `ash_phoenix` for web integration
- `ash_authentication` for auth features
- `ash_ai` for AI capabilities
- `ash_oban` for background jobs

## Environment Configuration

Copy `.env.example` to `.env` and configure:
- Database credentials
- n8n API key (auto-generated)
- Secret key base for Phoenix
- MCP proxy settings

## Service Endpoints

- Phoenix Application: http://localhost:4000
- n8n Workflow UI: http://localhost:5678
- MCP Endpoint: http://localhost:4000/mcp
- Tidewave MCP: http://localhost:4000/tidewave/mcp

## Development Workflow

1. Use `./scripts/setup.sh` for initial setup
2. Start services with `./scripts/start_system.sh`
3. Monitor with `./scripts/monitor.sh`
4. Phoenix app development follows standard Elixir/Phoenix patterns
5. n8n workflows are stored in `n8n_workflows/` as JSON files
6. System automatically discovers and implements improvements

## Testing

### Comprehensive Test Suite
The system includes a sophisticated testing framework for validating the entire self-improvement loop:

```bash
# Basic testing
mix test                    # Unit and integration tests
mix test test/n8n/         # n8n DSL framework tests

# Comprehensive testing
TEST_SUITE=comprehensive mix test    # Full system validation
TEST_SUITE=chaos mix test           # Chaos engineering tests
TEST_SUITE=all mix test             # All tests (slow)

# Property-based testing
mix test --include property         # Property-based validation

# Specific test categories
mix test --only integration         # Integration tests only
mix test --include slow            # Include long-running tests
```

### Test Categories
- **Unit Tests**: Fast component tests (< 1s each)
- **Integration Tests**: Multi-component interaction tests (< 10s each)
- **Property-Based Tests**: Generated test cases with StreamData
- **Chaos Engineering**: Random failure injection and resilience testing
- **Comprehensive Tests**: Full end-to-end system validation (30-300s each)
- **Long-Running Tests**: Stability and memory leak detection

### Key Test Features
- **System Invariant Validation**: Ensures core properties always hold
- **Memory Leak Detection**: Long-running stability testing
- **Performance Regression Testing**: Automated performance monitoring
- **Security Validation**: Generated workflow security testing
- **Chaos Engineering**: Random failure injection for resilience testing
- **Backwards Compatibility**: Workflow evolution safety testing
- **Concurrency Testing**: Race condition and deadlock detection

### Test Documentation
See `/phoenix_app/test/README.md` for complete testing documentation

### Test Execution Examples

```bash
# Run the complete self-improvement loop test
mix test test/self_sustaining/ai/self_improvement_loop_test.exs

# Run property-based tests with chaos engineering
mix test test/self_sustaining/ai/comprehensive_loop_property_test.exs

# Run n8n DSL framework tests
mix test test/n8n/reactor_test.exs
mix test test/n8n/workflow_manager_test.exs

# Run with specific performance thresholds
TEST_PERFORMANCE_STRICT=true mix test
```

## DSL Usage Examples

### Basic Workflow Definition
```elixir
defmodule MyWorkflow do
  use N8n.Reactor
  
  workflow do
    name "My Workflow"
    active true
    tags ["ai", "automation"]
  end
  
  node "fetch_data", "n8n-nodes-base.httpRequest" do
    name "Fetch Data"
    parameters %{"method" => "GET", "url" => "https://api.example.com"}
  end
  
  node "process", "n8n-nodes-base.code" do
    name "Process Data"
    depends_on ["fetch_data"]
    parameters %{"jsCode" => "return items.map(item => ({json: {...item.json, processed: true}}));"}
  end
end
```

### Advanced Workflow with Error Handling
```elixir
defmodule AdvancedWorkflow do
  use N8n.Reactor
  
  workflow do
    name "Advanced Error Handling Workflow"
    active true
    tags ["production", "error-handling"]
  end
  
  trigger :webhook do
    type :webhook
    parameters %{"path" => "advanced-webhook"}
  end
  
  node "validate_input", "n8n-nodes-base.code" do
    name "Validate Input"
    parameters %{
      "jsCode" => """
        if (!items[0]?.json?.required_field) {
          throw new Error('Missing required field');
        }
        return items;
      """
    }
    continue_on_fail false
    retry_on_fail true
  end
  
  node "process_data", "n8n-nodes-base.httpRequest" do
    name "Process Data"
    depends_on ["validate_input"]
    parameters %{
      "method" => "POST",
      "url" => "https://api.example.com/process",
      "timeout" => 30000
    }
  end
  
  node "handle_error", "n8n-nodes-base.httpRequest" do
    name "Error Handler"
    parameters %{
      "method" => "POST",
      "url" => "https://api.example.com/error",
      "sendBody" => true
    }
  end
end
```

## Dependencies

- **Elixir**: ~> 1.14
- **Phoenix**: ~> 1.7.0
- **Node.js**: 20.15+ (for n8n)
- **PostgreSQL**: Any recent version
- **Claude Desktop**: For MCP integration

## Common Issues

- Ensure PostgreSQL is running before starting Phoenix
- n8n requires Node.js 20.15+
- MCP proxy may need PATH updates after Rust installation
- Check `./scripts/check_status.sh` for missing dependencies

## Self-Improvement Cycle

The system operates in continuous improvement cycles:

1. **Discovery**: Analyze system performance and identify opportunities
2. **Generation**: Use AI to generate workflow improvements
3. **Validation**: Compile and validate generated workflows
4. **Deployment**: Deploy workflows to n8n
5. **Monitoring**: Track performance and gather metrics
6. **Learning**: Learn from results to improve future cycles

Each cycle is thoroughly tested through the comprehensive test suite to ensure system stability and correctness.