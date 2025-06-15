# AI Self-Sustaining System - Technical Documentation

## Overview

This documentation provides comprehensive technical details for the AI Self-Sustaining System, an autonomous software system with APS Agent Swarm coordination that continuously discovers, implements, and deploys improvements to itself using cutting-edge AI and workflow technologies.

## APS Agent Swarm Architecture

The system implements a sophisticated multi-agent coordination system using the Agile Protocol Specification (APS). This enables autonomous task management through specialized AI agents that communicate via standardized YAML files.

### Agent Roles
- **PM_Agent**: Requirements analysis and Gherkin scenario generation
- **Architect_Agent**: System architecture design with C4 models and tech stack decisions
- **Developer_Agent**: Code implementation, testing, and version control
- **QA_Agent**: Quality assurance, validation against Gherkin scenarios
- **DevOps_Agent**: Deployment, monitoring, and telemetry analysis

### APS Protocol
All agents communicate through standardized YAML files following the APS specification:
- Process definitions with roles, activities, and scenarios
- Inter-agent messaging with timestamps and artifact tracking
- Work claiming protocol for parallel agent coordination
- Status management for process tracking and handoffs

See `/context/aps-agent-coordination.md` for detailed APS documentation.

## System Architecture

### Core Components

#### 1. Phoenix Application Layer
**Location**: `phoenix_app/`
**Purpose**: Main web application framework providing API endpoints, real-time UI, and system orchestration

**Key Files**:
- `lib/self_sustaining/application.ex`: Application supervisor and startup configuration
- `lib/self_sustaining_web/router.ex`: Route definitions for web and API endpoints
- `lib/self_sustaining_web/controllers/`: API controllers for health, metrics, and webhooks
- `lib/self_sustaining_web/live/`: LiveView components for real-time UI

**Architecture Patterns**:
- **Supervisor Pattern**: Fault-tolerant process management with proper restart strategies
- **LiveView Pattern**: Real-time UI updates without JavaScript complexity
- **API Gateway Pattern**: Centralized endpoint management for external integrations

#### 2. Self-Improvement Engine
**Location**: `phoenix_app/lib/self_sustaining/self_improvement/`
**Purpose**: Core AI system for autonomous improvement discovery and implementation

**Key Components**:
- `supervisor.ex`: Main supervisor orchestrating all improvement processes
- `enhancement_discovery.ex`: Ash resource for tracking and managing discovered improvements
- `auto_implementer.ex`: Autonomous code implementation using Claude Code CLI
- `auto_tester.ex`: Comprehensive test generation and execution
- `meta_enhancer.ex`: Self-improvement of the improvement system itself

**Enhancement Workflow**:
1. **Discovery Phase**: System analyzes performance metrics, error logs, and health indicators
2. **Planning Phase**: Claude Code CLI generates detailed improvement plans with code examples
3. **Implementation Phase**: Autonomous code generation, file modifications, and migration creation
4. **Testing Phase**: Comprehensive test generation and execution for all changes
5. **Deployment Phase**: Safe deployment with rollback capabilities
6. **Meta-Enhancement Phase**: Recursive improvement of the improvement system

#### 3. Claude Code Integration
**Location**: `phoenix_app/lib/self_sustaining/claude_code.ex`
**Purpose**: Direct integration with Claude Code CLI for cost-effective AI operations

**Features**:
- **CLI Wrapper**: GenServer wrapper around Claude Code CLI with proper error handling
- **Streaming Support**: Handle large responses with streaming for complex code generation
- **JSON Parsing**: Structured output parsing for integration with Ash resources
- **Task-Specific Commands**: Specialized prompts for different types of AI tasks
- **Parallel Execution**: Support for concurrent AI operations

**Integration Benefits**:
- **No API Costs**: Direct CLI usage eliminates API charges
- **Local Processing**: Secure local AI processing without external dependencies
- **High Performance**: Direct process communication with optimized resource usage

#### 4. n8n Workflow Engine
**Location**: `phoenix_app/lib/self_sustaining/n8n/` and `n8n_workflows/`
**Purpose**: Complex workflow orchestration and automation

**Key Components**:
- `reactor.ex`: Base module for workflow definitions using custom DSL
- `workflow_manager.ex`: Workflow compilation and deployment
- `mcp_proxy.ex`: Model Context Protocol proxy for n8n integration
- Custom DSL transformers for workflow optimization

**Workflow DSL Features**:
- **Declarative Syntax**: Human-readable workflow definitions
- **Compilation Target**: Generates standard n8n workflow JSON
- **Type Safety**: Compile-time validation of workflow definitions
- **Integration Points**: Seamless integration with Ash resources and Phoenix endpoints

#### 5. Ash Framework Domain Layer
**Location**: `phoenix_app/lib/self_sustaining/`
**Purpose**: Domain modeling and resource management with AI-powered actions

**Key Resources**:
- `SelfImprovement` domain with enhancement tracking
- `Workflows` domain for n8n workflow management
- AI-powered actions using `ash_ai` integration
- PostgreSQL backend with `ash_postgres`

**AI-Enhanced Features**:
- **Smart Actions**: Actions that use AI to generate implementations
- **Auto-Documentation**: AI-generated documentation for resources and actions
- **Intelligent Validation**: AI-powered validation rules and constraints
- **Dynamic Relationships**: AI-driven relationship discovery and optimization

### Data Flow Architecture

#### Enhancement Discovery Flow
```
System Metrics → Performance Monitor → Enhancement Discovery → Claude Code Analysis → Improvement Plans
```

#### Implementation Flow
```
Improvement Plans → Auto Implementer → Code Generation → File Modifications → Migration Creation → Testing
```

#### Deployment Flow
```
Tested Changes → Deployment Pipeline → System Update → Health Verification → Success/Rollback
```

#### Meta-Enhancement Flow
```
System Analysis → Meta-Enhancer → Improvement System Updates → Enhanced Capabilities → Recursive Loop
```

## Technology Stack

### Primary Technologies
- **Elixir/Phoenix (~> 1.7.0)**: Main application framework with actor model concurrency
- **Ash Framework (~> 3.0)**: Domain modeling, resource management, and AI integration
- **PostgreSQL**: Primary database with advanced querying and indexing
- **n8n**: Workflow orchestration with visual editing and extensive integrations
- **Claude Code CLI**: Local AI processing without API costs

### Supporting Technologies
- **Phoenix LiveView**: Real-time UI components without JavaScript complexity
- **Tidewave**: Runtime intelligence and MCP integration
- **Oban (via ash_oban)**: Background job processing with reliability guarantees
- **Telemetry**: Comprehensive system monitoring and metrics collection
- **PubSub**: Event-driven communication between system components

## API Reference

### Web Endpoints

#### Dashboard and Monitoring
- `GET /`: Main dashboard with real-time system status
- `GET /ai/metrics`: AI performance metrics visualization
- `GET /ai/improvements`: Improvement management interface
- `GET /ai/tasks`: Active task monitoring and control

#### Health and Metrics API
- `GET /api/health`: System health check with detailed component status
- `GET /api/metrics`: Performance metrics API for external monitoring tools
- `POST /api/metrics/custom`: Submit custom metrics for tracking

#### Webhook Integration
- `POST /api/webhooks/n8n/:workflow_id`: n8n workflow webhook handlers
- `POST /api/webhooks/github`: GitHub integration for code repository events
- `POST /api/webhooks/system`: System event notifications

#### MCP Protocol
- `POST /mcp`: Model Context Protocol endpoints for Claude Desktop integration
- `GET /mcp/status`: MCP service status and capabilities
- `POST /mcp/tools`: Available MCP tools and their descriptions

### Internal APIs

#### Enhancement Discovery API
- Discovery triggers and scheduling
- Enhancement priority management
- Implementation status tracking
- Success/failure metrics

#### Claude Code Integration API
- Task execution and monitoring
- Streaming response handling
- Error recovery and retry logic
- Performance optimization

## Configuration

### Environment Variables
- `DATABASE_URL`: PostgreSQL connection string
- `SECRET_KEY_BASE`: Phoenix application secret key
- `N8N_API_KEY`: n8n API authentication key
- `CLAUDE_CODE_PATH`: Path to Claude Code CLI executable
- `MCP_PROXY_PORT`: MCP proxy server port

### Development Configuration
- `config/dev.exs`: Development environment settings
- `config/test.exs`: Testing environment configuration
- `config/prod.exs`: Production deployment settings
- `config/runtime.exs`: Runtime configuration resolution

## Development Workflow

### Setup Process
1. **Environment Setup**: Run `./scripts/setup.sh` for complete system initialization
2. **Service Startup**: Use `./scripts/start_system.sh` to start all required services
3. **Development Server**: Phoenix application runs on `http://localhost:4000`
4. **n8n Interface**: Workflow editor available at `http://localhost:5678`

### Development Commands
```bash
# Phoenix application development
cd phoenix_app
mix setup                    # Initial setup
mix phx.server              # Start development server
iex -S mix phx.server       # Interactive development

# Database operations
mix ecto.create             # Create database
mix ecto.migrate            # Run migrations
mix ecto.reset              # Reset database

# Testing
mix test                    # Run test suite
mix test --cover            # Run tests with coverage

# Asset management
mix assets.build            # Build frontend assets
mix assets.deploy           # Deploy production assets
```

### Monitoring and Debugging
```bash
# System monitoring
./scripts/monitor.sh        # Real-time system monitoring
./scripts/check_status.sh   # System health verification

# Log analysis
tail -f log/dev.log         # Development logs
grep "ERROR" log/prod.log   # Error analysis
```

## Testing Strategy

### Test Categories
- **Unit Tests**: Individual module and function testing
- **Integration Tests**: Component interaction testing
- **End-to-End Tests**: Complete workflow testing
- **Property Tests**: Automated test case generation
- **Performance Tests**: System performance benchmarking

### Automated Testing
- **AI-Generated Tests**: Auto-generated test suites for new features
- **Continuous Testing**: Background test execution during development
- **Regression Testing**: Automated testing of enhancement implementations
- **Performance Regression**: Automated performance impact analysis

## Security Considerations

### Data Protection
- **Credential Management**: Secure storage of API keys and database credentials
- **Data Encryption**: Encryption of sensitive system data
- **Access Control**: Role-based access control for system administration
- **Audit Logging**: Comprehensive logging of all system modifications

### AI Security
- **Prompt Injection Prevention**: Input validation and sanitization
- **Code Execution Safety**: Sandboxed execution of AI-generated code
- **Model Access Control**: Controlled access to AI capabilities
- **Output Validation**: Verification of AI-generated content

## Performance Optimization

### System Performance
- **Elixir Concurrency**: Actor model for efficient concurrent processing
- **Database Optimization**: Optimized queries and proper indexing
- **Caching Strategy**: Multi-layer caching for frequently accessed data
- **Resource Management**: Efficient memory and CPU utilization

### AI Performance
- **Local Processing**: CLI-based AI processing eliminates network latency
- **Streaming Responses**: Efficient handling of large AI responses
- **Parallel Execution**: Concurrent AI task processing
- **Result Caching**: Intelligent caching of AI-generated content

## Troubleshooting

### Common Issues
- **Service Startup**: PostgreSQL and n8n dependency issues
- **Database Connections**: Connection pool and migration problems
- **AI Integration**: Claude Code CLI path and permission issues
- **Performance**: Memory usage and process management

### Diagnostic Tools
- **Health Checks**: Comprehensive system health verification
- **Metrics Dashboard**: Real-time performance monitoring
- **Log Analysis**: Structured logging and error tracking
- **Process Monitoring**: GenServer and supervisor status tracking

## Future Roadmap

### Planned Enhancements
- **Infinite Agentic Enhancement**: Multi-agent parallel improvement system
- **Advanced AI Integration**: Enhanced AI capabilities and model diversity
- **Distributed Architecture**: Multi-node deployment and scalability
- **Advanced Monitoring**: Predictive analytics and anomaly detection

### Research Areas
- **Emergent Behaviors**: Study of emergent system behaviors
- **AI Safety**: Research into AI safety and control mechanisms
- **Performance Optimization**: Advanced optimization techniques
- **Integration Patterns**: New integration patterns and protocols

## Contributing

### Development Guidelines
- **Code Style**: Follow Elixir and Phoenix conventions
- **Testing Requirements**: Comprehensive test coverage for all changes
- **Documentation**: Maintain up-to-date documentation
- **Security**: Security review for all AI-related modifications

### Contribution Process
1. **Issue Creation**: Document enhancement opportunities and bugs
2. **Design Discussion**: Architectural discussions for major changes
3. **Implementation**: Follow established patterns and conventions
4. **Testing**: Comprehensive testing of all modifications
5. **Review**: Code review and security assessment
6. **Deployment**: Staged deployment with monitoring

This system represents a significant advancement in autonomous AI systems, combining cutting-edge technologies with innovative architectural patterns to create a truly self-improving software system.