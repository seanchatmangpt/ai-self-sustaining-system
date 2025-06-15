Comprehensive system status and health monitoring for the AI Self-Sustaining System.

Health check scope: $ARGUMENTS (optional: specific component or detailed analysis)

System Health Monitoring:
1. **Service Status** (NEVER TRUST - VERIFY WITH TELEMETRY):
   - PostgreSQL database: verify process AND execute test query with timing
   - n8n workflow engine: check port 5678 AND execute API health endpoint
   - Phoenix application server: verify port 4001 AND test /health endpoint with response time
   - OpenTelemetry metrics: verify all services reporting telemetry data
   - Check for crashed services via process monitoring AND log analysis

2. **Phoenix Application Health** (TELEMETRY-DRIVEN VERIFICATION):
   - Server runtime: verify port availability AND execute health check endpoint
   - Dependencies: run `mix deps.get --only prod` AND verify no warnings/errors
   - Compilation: execute `mix compile --warnings-as-errors` for validation
   - Database: run migration status AND execute test queries with timing metrics
   - Crash analysis: check erl_crash.dump AND parse telemetry error patterns
   - OpenTelemetry traces: verify Phoenix requests generating proper spans

3. **n8n Workflow Engine** (OBSERVABILITY-BASED VALIDATION):
   - Service availability: test API response AND measure response times
   - Workflow execution: verify recent executions AND analyze success/failure metrics
   - Node connectivity: test each external connection AND measure latency
   - Container health: check resource usage AND compare against baseline metrics
   - Execution telemetry: verify workflow traces and performance data

4. **Database Status** (PERFORMANCE-MEASURED VALIDATION):
   - PostgreSQL connectivity: execute test queries AND measure response times
   - Migration status: verify current version AND test rollback capability
   - Connection pool: monitor active connections AND measure pool efficiency
   - Query performance: run benchmark queries AND compare against baselines
   - Database telemetry: verify PostgreSQL metrics collection and alerting

5. **System Resources**:
   - Disk space usage and availability
   - Memory usage and potential leaks
   - CPU load and process monitoring
   - Network connectivity on key ports (4001, 5678, 5432)

6. **Application Health Indicators**:
   - Recent error logs and patterns
   - Build artifacts and compilation status
   - Environment configuration validation
   - Large file identification (>10MB)

7. **Network Connectivity**:
   - Test local service endpoints
   - Verify inter-service communication
   - Check external dependency access
   - Port availability and conflicts

Health Summary (METRICS-BASED ASSESSMENT):
- Count warnings and critical issues from telemetry data
- Calculate overall system health score using measured metrics
- Provide benchmark comparisons for performance indicators
- Generate alerts based on OpenTelemetry thresholds
- Suggest immediate actions backed by observability data
- Recommend next steps based on trending metrics and patterns

Integration Points:
- Check Tidewave MCP endpoint availability
- Verify Claude Code CLI integration
- Test n8n workflow execution capabilities
- Validate self-improvement system components

Provide actionable recommendations for any issues found, prioritized by criticality and impact on system functionality.