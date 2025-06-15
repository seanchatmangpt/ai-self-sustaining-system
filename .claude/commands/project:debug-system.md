# AI-Assisted System Debugging

**Purpose**: Intelligent debugging across Phoenix, n8n, and infrastructure.

```bash
/project:debug-system [component]
```

## Debugging Modes

### 1. Phoenix/Elixir Application Debug
- Server status and crash dumps
- Compilation errors and warnings
- Database connectivity issues
- Process supervision tree analysis

### 2. n8n Workflow Debug
- Workflow execution status
- Node errors and failures
- API connectivity testing
- Webhook configuration validation

### 3. System Infrastructure Debug
- Service health monitoring
- Disk space and resource usage
- Network connectivity testing
- Port availability checks

### 4. Test Failure Analysis
- Detailed test output examination
- Failure pattern identification
- Test environment configuration
- Coverage analysis

### 5. Performance Investigation
- Resource usage profiling
- Bottleneck identification
- Memory leak detection
- Query optimization analysis

### 6. Stack Trace Analysis
- Error log parsing and interpretation
- Root cause identification
- Exception pattern analysis
- Resolution recommendations

## Implementation Features
- **Automated Diagnostics**: Systematic health checks
- **Visual Analysis**: Screenshot debugging support
- **Context-Aware Fixes**: Environment-specific solutions
- **Telemetry Integration**: OpenTelemetry-based monitoring
- **Recovery Suggestions**: Actionable repair recommendations

## Usage Examples
```bash
/project:debug-system phoenix     # Debug Phoenix application
/project:debug-system n8n         # Debug n8n workflows
/project:debug-system database    # Debug database connectivity
/project:debug-system tests       # Debug test failures
```