# BeamOps V2 - Engineering Elixir Applications Integration

BeamOps V2 integrates best practices from the "Engineering Elixir Applications" book by Ellie and Pep, providing a comprehensive development and production environment for Elixir applications with enterprise-grade monitoring and coordination.

## Overview

This implementation combines:
- **Phoenix LiveView application** with production-ready Docker setup
- **Complete observability stack** (Prometheus, Grafana, Loki, Alloy)
- **Custom PromEx metrics** for application monitoring
- **Distributed Erlang** capabilities for multi-node coordination
- **Agent coordination system** inherited from V3 architecture
- **OpenTelemetry integration** for distributed tracing
- **CI/CD pipelines** with GitHub Actions

## Architecture

```
BeamOps V2
├── app/                     # Main Phoenix application
├── compose.yaml            # Development environment
├── docker/                 # Docker configurations
├── instrumentation/        # Monitoring and metrics
├── scripts/               # Automation and deployment
├── terraform/             # Infrastructure as code
└── .github/               # CI/CD workflows
```

## Quick Start

```bash
# Initialize development environment
./scripts/dev-setup.sh

# Start the full stack
docker compose up

# Access services
open http://localhost:4000    # Phoenix app
open http://localhost:3000    # Grafana
open http://localhost:9090    # Prometheus
```

## Features

### 🔧 Development Environment
- **Hot reloading** Phoenix application
- **PostgreSQL** with persistent data
- **Complete monitoring stack** out of the box
- **Secrets management** for secure configuration

### 📊 Observability
- **Custom PromEx plugins** for application metrics
- **Grafana dashboards** for visualization
- **Loki** for log aggregation
- **Prometheus** for metrics collection
- **OpenTelemetry** distributed tracing

### 🚀 Production Ready
- **Multi-stage Docker builds** for optimized images
- **Health checks** and restart policies
- **Automatic rollbacks** on deployment failures
- **Load balancing** and autoscaling support

### 🤖 Agent Coordination
- **Distributed coordination** across multiple nodes
- **Work item management** with atomic operations
- **Telemetry integration** for coordination monitoring
- **Real-time status tracking** and reporting

## Integration with V3

BeamOps V2 serves as the foundation layer, while V3 provides advanced features:
- V2: Core application, monitoring, and coordination
- V3: Advanced OpenTelemetry validation, master trace orchestration
- Shared: Agent coordination system and telemetry infrastructure

## Getting Started

1. **Prerequisites**: Docker, Docker Compose, Elixir 1.14+
2. **Setup**: Run `./scripts/dev-setup.sh`
3. **Development**: Use `docker compose up` for local development
4. **Monitoring**: Access Grafana at http://localhost:3000
5. **Coordination**: Use coordination helper scripts for agent management

## Documentation

- [Application Architecture](./docs/architecture.md)
- [Monitoring Guide](./docs/monitoring.md)
- [Deployment Guide](./docs/deployment.md)
- [Agent Coordination](./docs/coordination.md)

---

Built with ❤️ using patterns from "Engineering Elixir Applications" by Ellie & Pep.