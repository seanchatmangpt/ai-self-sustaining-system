# System Health Monitoring

**Purpose**: Comprehensive system status and health checks.

```bash
/project:system-health [component]
```

## Health Monitoring Areas

### 1. PostgreSQL Database
- Connection status and pool health
- Active connections and query performance
- Database size and growth trends
- Index efficiency and optimization

### 2. n8n Workflow Engine
- Service status and API accessibility
- Active workflow execution status
- Webhook endpoint availability
- Workflow performance metrics

### 3. Phoenix Application Server
- Server process status and memory usage
- HTTP endpoint response times
- LiveView connection health
- WebSocket connection stability

### 4. Dependencies and Compilation
- Mix dependency resolution status
- Compilation warnings and errors
- Asset compilation status
- Module loading verification

### 5. System Resources
- Disk space availability and trends
- Memory usage and allocation patterns
- CPU utilization and load averages
- Network connectivity and bandwidth

### 6. Error Logs and Monitoring
- Recent error patterns and frequencies
- Log file sizes and rotation status
- Telemetry data collection health
- Alert system functionality

## Health Check Implementation
- **Automated Diagnostics**: Systematic health verification
- **Performance Metrics**: Real-time performance monitoring
- **Trend Analysis**: Historical health trend identification
- **Alert Generation**: Proactive issue notification
- **Recovery Recommendations**: Automated fix suggestions

## Health Status Levels
- **✅ Healthy**: All systems operational
- **⚠️ Warning**: Minor issues detected
- **🔶 Degraded**: Performance impact present
- **❌ Error**: Critical issues requiring attention
- **🚨 Critical**: System failure or unavailable
- **⬇️ Down**: Complete service unavailability

## Usage Examples
```bash
/project:system-health              # Full system health check
/project:system-health database     # Database-specific health
/project:system-health phoenix      # Phoenix application health
/project:system-health n8n          # n8n workflow engine health
```