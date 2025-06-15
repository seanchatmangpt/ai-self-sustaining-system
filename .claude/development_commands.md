# Development & Debugging Commands

## `/debug-with-claude` - AI-Assisted Debugging

**Purpose**: Intelligent debugging across Phoenix, n8n, and infrastructure.

```bash
/debug-with-claude
```

**Debugging Modes**:
1. **Phoenix/Elixir Application Debug** - Server status, crash dumps, compilation
2. **n8n Workflow Debug** - Workflow execution, node errors, API connectivity
3. **System Infrastructure Debug** - Services, disk space, network connectivity
4. **Test Failure Analysis** - Detailed test output and failure patterns
5. **Performance Investigation** - Resource usage and bottleneck identification
6. **Stack Trace Analysis** - Error log parsing and root cause analysis
7. **General Code Review** - Code quality and maintenance issues

**Based on Anthropic Teams' Practices**:
- Screenshot analysis for visual debugging
- Stack trace interpretation and guidance
- Kubernetes operations assistance
- Performance bottleneck identification

## `/tdd-workflow` - Test-Driven Development

**Purpose**: Comprehensive TDD workflow management following Security Engineering team practices.

```bash
/tdd-workflow
```

**TDD Workflows**:
1. **Start New Feature with TDD** - Red-Green-Refactor cycle setup
2. **Add Tests to Existing Code** - Retrospective test coverage
3. **Refactor with Test Safety Net** - Safe code improvement
4. **Debug Test Failures** - Failure analysis and resolution
5. **Generate Test Documentation** - Comprehensive test guides
6. **Test Coverage Analysis** - Coverage reporting and improvement

**Features**:
- Automatic test template generation
- TDD cycle enforcement (Red-Green-Refactor)
- Test coverage analysis and reporting
- Elixir/Phoenix-specific patterns
- Integration with mix test commands

## `/system-status` - System Health Monitoring

**Purpose**: Comprehensive system status and health checks.

```bash
/system-status
```

**Monitors**:
- PostgreSQL database status and connectivity
- n8n workflow engine health
- Phoenix application server status
- Dependencies and compilation
- Crash dumps and error logs
- Disk space and system resources
- Network connectivity on key ports

## `/analyze-health` - Detailed System Diagnostics

**Purpose**: Deep system analysis for troubleshooting.

```bash
/analyze-health
```

**Features**:
- Comprehensive system diagnostics
- Performance bottleneck identification
- Resource usage analysis
- Error pattern detection
- Dependency conflict resolution

## `/workflow-health` - n8n Workflow Monitoring

**Purpose**: Specialized n8n workflow diagnostics.

```bash
/workflow-health
```

**Features**:
- n8n workflow execution monitoring
- Node error analysis
- API connectivity checks
- Workflow performance metrics
- Execution history analysis