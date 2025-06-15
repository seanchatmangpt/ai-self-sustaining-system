# C4 Architecture Diagrams - Complete System Documentation

This directory contains comprehensive C4 diagrams for the AI Self-Sustaining System, capturing the complete architecture with zero information loss across all four C4 levels.

## C4 Model Overview

The C4 model provides a hierarchical approach to documenting software architecture:
- **Level 1 (Context)**: System landscape and external interactions
- **Level 2 (Container)**: High-level technology and responsibility areas
- **Level 3 (Component)**: Internal structure of containers
- **Level 4 (Code)**: Detailed implementation of critical components

## Diagram Files

### Level 1: Context Diagram
**File**: `c4-context.mmd`
- **Scope**: Complete system landscape
- **Shows**: AI Self-Sustaining System interactions with external systems and users
- **External Systems**: Claude Code CLI, PostgreSQL, n8n, Qdrant, Ollama, OpenAI API, GitHub
- **Users**: Developers/Operators, Claude Code Users

### Level 2: Container Diagram
**File**: `c4-container.mmd`
- **Scope**: High-level technical architecture
- **Shows**: Major containers and their technology choices
- **Key Containers**:
  - Phoenix Web Application (Elixir/Phoenix + Ash Framework)
  - APS Workflow Engine (Elixir GenServer)
  - AI Self-Improvement Orchestrator (Elixir GenServer)
  - N8N Workflow Compiler (Elixir Reactor DSL)
  - MCP Protocol Server (Elixir/Phoenix)
  - Data Layer (PostgreSQL, Qdrant, File System)

### Level 3: Component Diagrams

#### Phoenix Application Components
**File**: `c4-component-phoenix.mmd`
- **Scope**: Internal structure of Phoenix Web Application
- **Key Components**:
  - Web Layer: Controllers, LiveViews, Router, Endpoint
  - AI Domain Layer: Ash resources, AI processing modules
  - APS Layer: Workflow engine, agent assignment, process state
  - n8n Integration Layer: Workflow manager, Reactor DSL, transformers
  - Integration Layer: MCP router, Claude Code integration, PubSub

#### APS Engine Components
**File**: `c4-component-aps.mmd`
- **Scope**: Detailed APS (Agile Protocol Specification) system
- **Key Components**:
  - Agent Coordination System: Role assignment, session management, work claiming
  - Process Management: State tracking, handoff management, status broadcasting
  - Inter-Agent Communication: Message bus, notification system, coordination protocol
  - Workflow Execution: Sequential pipeline, parallel coordination, stage transitions
  - File Operations: APS file management, file watching, backup management
  - Validation & Quality: YAML validation, Gherkin processing, dependency checking

#### AI Domain Components
**File**: `c4-component-ai-domain.mmd`
- **Scope**: AI-powered core functionality
- **Key Components**:
  - AI Resources: Improvement, Task, Metric, CodeAnalysis (Ash Resources)
  - AI Processing: Self-improvement orchestrator, enhancement discovery, auto-implementer
  - AI Intelligence: Embedding model, workflow generator, Claude Code wrapper
  - Data Processing: Vector operations, semantic search, trend analysis
  - AI-Enhanced Actions: Plan generation, risk assessment, impact prediction
  - Supervision Tree: Process supervision and fault tolerance

### Level 4: Code Diagrams

#### APS Workflow Engine Code
**File**: `c4-code-aps-workflow.mmd`
- **Scope**: Detailed implementation of APS workflow coordination
- **Key Functions**:
  - GenServer callbacks for workflow execution
  - APS YAML parsing and validation
  - Agent assignment and role detection logic
  - Process state management and transitions
  - File system operations and monitoring
- **Data Structures**: State maps, process structs, assignment schemas
- **Database Schema**: PostgreSQL tables with relationships

#### Self-Improvement Orchestrator Code
**File**: `c4-code-self-improvement.mmd`
- **Scope**: Detailed implementation of autonomous improvement system
- **Key Functions**:
  - Improvement discovery and analysis
  - Autonomous implementation and testing
  - Claude Code CLI integration
  - Workflow generation and optimization
  - Meta-enhancement capabilities
- **GenServer Implementation**: State management, cycle execution, external integrations
- **External Dependencies**: Claude CLI process, n8n API, vector databases

## Architecture Insights

### System Complexity
- **Total Components Mapped**: 50+ components across all levels
- **External Integrations**: 8 external systems
- **Data Stores**: 3 different database technologies (PostgreSQL, Qdrant, File System)
- **Programming Languages**: Primarily Elixir with some JavaScript (n8n)

### Key Architectural Patterns
1. **Actor Model**: Extensive use of GenServer processes for concurrent operations
2. **Domain-Driven Design**: Ash Framework domain modeling with AI-enhanced resources
3. **Event-Driven Architecture**: PubSub for real-time updates and coordination
4. **Pipeline Architecture**: Sequential agent workflows with parallel support
5. **CLI Integration**: Direct process communication with Claude Code CLI
6. **DSL Compilation**: Custom Reactor DSL compiling to n8n JSON workflows

### Technology Stack Mapping
- **Web Framework**: Phoenix with LiveView for real-time UI
- **Domain Layer**: Ash Framework with AI integration
- **Workflow Engine**: Custom Reactor DSL + n8n execution
- **AI Integration**: Claude Code CLI + OpenAI embeddings
- **Data Layer**: PostgreSQL + Qdrant + File System
- **Monitoring**: Telemetry + PubSub event system

### Critical Dependencies
1. **Claude Code CLI**: Central to all AI operations
2. **PostgreSQL**: Primary data persistence with extensions
3. **n8n**: Workflow orchestration and automation
4. **Qdrant**: Vector operations for semantic search
5. **File System**: APS coordination state management

## Diagram Usage

### For Development
- Use Component diagrams to understand module responsibilities
- Reference Code diagrams for implementation details
- Follow data flow patterns for integration work

### For Operations
- Context diagram shows external dependencies for monitoring
- Container diagram identifies deployment units and scaling targets
- Component diagrams help with troubleshooting and performance analysis

### For Documentation
- Complete traceability from high-level concepts to code implementation
- Zero information loss across all architectural levels
- Detailed mapping of all external integrations and data flows

## Maintenance

These diagrams should be updated when:
1. New external systems are integrated
2. Major containers are added or modified
3. Component responsibilities change significantly
4. Critical code implementations are refactored

The diagrams use Mermaid C4 syntax and can be rendered in most modern documentation platforms that support Mermaid, including GitHub, GitLab, and various documentation generators.