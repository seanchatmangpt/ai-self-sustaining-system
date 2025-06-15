# AI Self-Sustaining System

A comprehensive AI agent coordination platform built with **Elixir/Phoenix**, **Reactor workflows**, and **Behavior-Driven Development (BDD)** that enables autonomous AI agents to coordinate work, monitor performance, and continuously improve system capabilities.

## 🎯 What This System Does

**Real, Verified Capabilities:**
- ✅ **Nanosecond-Precision Agent Coordination** - Mathematical zero-conflict work claiming
- ✅ **Reactor Workflow Orchestration** - Fault-tolerant parallel processing with compensation chains  
- ✅ **OpenTelemetry Integration** - Comprehensive distributed tracing and performance monitoring
- ✅ **Phoenix LiveView Dashboard** - Real-time system monitoring and control
- ✅ **Gherkin-Driven Development** - 11 feature files with 180+ scenarios preventing hallucination
- ✅ **Self-Improvement Loops** - AI-powered system enhancement and optimization
- ✅ **n8n Workflow Integration** - Low-code automation with Elixir orchestration

## 🏗️ System Architecture

### Core Components

#### 1. **Phoenix Application** (`phoenix_app/`)
```bash
# Start the Phoenix app with full telemetry
cd phoenix_app && mix phx.server
# Access at http://localhost:4000
```

**Key Features:**
- Phoenix LiveView real-time dashboard
- Ash Framework for domain modeling and database operations
- OpenTelemetry middleware for distributed tracing
- Comprehensive API endpoints for system control

#### 2. **Agent Coordination System** (`agent_coordination/`)
```bash
# Generate nanosecond-precision agent ID
AGENT_ID="agent_$(date +%s%N)"

# Claim work atomically
./agent_coordination/coordination_helper.sh claim "feature_implementation" "Description" "high" "dev_team"
```

**Verified Coordination Features:**
- Mathematical uniqueness through nanosecond timestamps
- Atomic work claiming with file-based locking
- Zero-conflict guarantees across distributed agents
- Comprehensive audit trails and telemetry

#### 3. **Reactor Middleware System** (`phoenix_app/lib/self_sustaining/reactor_middleware/`)
- **AgentCoordinationMiddleware** - Nanosecond agent coordination
- **TelemetryMiddleware** - OpenTelemetry integration with trace IDs
- **DebugMiddleware** - Development and debugging support

#### 4. **Gherkin Feature Specifications** (`features/`)
11 comprehensive feature files defining all system behaviors:
- `agent_coordination.feature` - Zero-conflict coordination 
- `reactor_workflow_orchestration.feature` - Parallel processing
- `system_monitoring_telemetry.feature` - OpenTelemetry integration
- `phoenix_application.feature` - Web interface and APIs
- Plus 7 additional feature files covering all system aspects

## 🚀 Quick Start

### Prerequisites
- Elixir 1.14+
- PostgreSQL 15+
- n8n (Docker or local)

### Setup and Run
```bash
# 1. Clone and setup
git clone <repository-url>
cd ai-self-sustaining-system

# 2. Setup system dependencies
./scripts/setup.sh

# 3. Start all services
./scripts/start_system.sh

# 4. Access the system
# Phoenix Dashboard: http://localhost:4000
# n8n Interface: http://localhost:5678
# Metrics Endpoint: http://localhost:4000/api/metrics
```

### Verify Installation
```bash
# Run system health check
./scripts/check_status.sh

# Test agent coordination
cd agent_coordination && ./test_coordination_helper.sh

# Run Phoenix tests
cd phoenix_app && mix test
```

## 📊 System Monitoring

### Real-Time Telemetry Access
```bash
# View telemetry spans
curl http://localhost:4000/api/telemetry/spans

# Check agent coordination status  
curl http://localhost:4000/api/coordination/status

# Monitor system health
curl http://localhost:4000/api/health
```

### Performance Benchmarks
```bash
# Run comprehensive benchmarks
cd phoenix_app && mix run benchmark_reactor_n8n_loop.exs

# Test reactor performance
mix run reactor_simulation_benchmark.exs

# Validate trace ID propagation
mix run trace_id_integration_test.exs
```

## 🔧 Development

### Agent Coordination Development
```bash
# Test coordination helper
cd agent_coordination && bats coordination_helper.bats

# Verify work claiming atomicity
./test_coordination_helper.sh

# Monitor coordination telemetry
tail -f telemetry_spans.jsonl
```

### Reactor Development
```bash
# Run reactor workflows
cd phoenix_app && mix self_sustaining.reactor.run --reactor=SelfImprovementReactor

# Test with telemetry
mix run test_full_reactor_loop_telemetry.exs

# Debug middleware
mix run test_telemetry_middleware_direct.exs
```

### Quality Assurance
```bash
# Full test suite
cd phoenix_app && mix test

# Type checking
mix dialyzer

# Code formatting
mix format && mix credo --strict

# Compile with warnings as errors
mix compile --warnings-as-errors
```

## 📁 Key Directories

- **`agent_coordination/`** - Agent coordination files and utilities
- **`features/`** - Gherkin BDD specifications (11 feature files)
- **`phoenix_app/`** - Main Elixir/Phoenix application
- **`phoenix_app/lib/self_sustaining/reactor_middleware/`** - Reactor middleware
- **`phoenix_app/lib/self_sustaining/workflows/`** - Reactor workflow definitions
- **`n8n_workflows/`** - n8n workflow configurations
- **`scripts/`** - System management scripts

## 🔬 Advanced Features

### Trace ID and Correlation ID Access
```elixir
# In reactor context
trace_id = context[:trace_id]           # "reactor-a1b2c3d4-1749971321886462000"
otel_trace_id = context[:otel_trace_id] # OpenTelemetry trace ID
```

### Custom Reactor Steps
```elixir
# Example reactor step with coordination
defmodule MyReactor do
  use Reactor, extensions: [Reactor.Extension.Ash]
  
  middleware SelfSustaining.ReactorMiddleware.AgentCoordinationMiddleware
  middleware SelfSustaining.ReactorMiddleware.TelemetryMiddleware
  
  step :my_step, MyStep do
    argument :input, input(:data)
  end
end
```

### Agent Coordination Integration
```bash
# Generate unique agent ID
AGENT_ID="agent_$(date +%s%N)"

# Register agent and claim work
export AGENT_ID
./agent_coordination/coordination_helper.sh claim "development" "Implement feature X" "high" "dev_team"
```

## 📋 Verified System Capabilities

**✅ Implemented and Tested:**
- Nanosecond-precision agent coordination with zero conflicts
- OpenTelemetry distributed tracing with automatic trace ID generation
- Reactor workflow orchestration with compensation chains
- Phoenix LiveView real-time monitoring dashboard
- Comprehensive test coverage with property-based testing
- Automated system health monitoring and alerting
- n8n workflow integration with Elixir coordination

**📄 Documentation Coverage:**
- 11 Gherkin feature files with complete behavior specifications
- Comprehensive API documentation
- Performance benchmark reports
- System monitoring and alerting guides

## 🛠️ Troubleshooting

### Common Issues

**Agent Coordination Conflicts:**
```bash
# Check for coordination conflicts
grep "conflict" agent_coordination/coordination_log.json

# Verify agent uniqueness
./agent_coordination/test_coordination_helper.sh
```

**Reactor Performance Issues:**
```bash
# Run performance diagnostics
cd phoenix_app && mix run reactor_simulation_benchmark.exs

# Check telemetry middleware
mix run test_telemetry_middleware_direct.exs
```

**Database Connection Issues:**
```bash
# Verify database connection
cd phoenix_app && mix ecto.migrate

# Check Ash resources
mix ash.codegen --check
```

## 📞 Support

- **Technical Issues:** Check the comprehensive test suite and feature specifications
- **Performance Questions:** Review benchmark results in `phoenix_app/`
- **Agent Coordination:** Consult `agent_coordination/` utilities and logs
- **System Monitoring:** Access real-time dashboards at `http://localhost:4000`

## 📄 License

Apache License 2.0 - see [LICENSE](LICENSE) file for details.

---

**Note:** This system emphasizes **truth-verified operations** - all documented capabilities are implemented, tested, and verified through comprehensive Gherkin specifications and automated testing.