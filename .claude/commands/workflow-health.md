Monitor and analyze n8n workflow engine health and execution status.

Workflow scope: $ARGUMENTS (optional: specific workflow or detailed analysis)

Workflow Health Assessment:
1. **n8n Service Status** (TELEMETRY-VERIFIED HEALTH):
   - Service availability: test port 5678 AND execute API health check with timing
   - Container health: monitor resource usage AND compare against baseline metrics
   - API responsiveness: measure endpoint response times AND track error rates
   - Service stability: analyze uptime metrics AND measure restart frequency
   - OpenTelemetry integration: verify n8n service reporting metrics and traces

2. **Workflow Execution Analysis** (PERFORMANCE-MEASURED VALIDATION):
   - Execution outcomes: analyze success/failure rates AND trend analysis over time
   - Failed workflows: identify patterns AND measure failure recovery times
   - Execution performance: benchmark run times AND compare against historical data
   - Error patterns: correlate with system metrics AND identify root cause trends
   - Workflow telemetry: verify execution traces and performance data collection

3. **Node Connectivity and Configuration**:
   - Validate node configurations and settings
   - Test external API connections and credentials
   - Verify webhook endpoints and triggers
   - Check for missing or invalid parameters

4. **Data Flow and Processing**:
   - Analyze data transformation accuracy
   - Monitor data volume and processing rates
   - Identify data quality issues or corruption
   - Verify input/output format compliance

5. **Integration Points** (CONNECTIVITY-BENCHMARKED TESTING):
   - Phoenix webhooks: test integration AND measure response times vs. SLA
   - Database operations: execute test queries AND benchmark performance
   - External services: measure API response times AND track availability metrics
   - MCP endpoints: test communication AND verify telemetry data flow
   - Integration telemetry: monitor cross-service traces and error correlation

6. **Error Analysis and Debugging**:
   - Parse n8n error logs for patterns
   - Identify common failure modes
   - Suggest fixes for configuration issues
   - Provide troubleshooting guidance

7. **Performance Monitoring**:
   - Measure workflow execution times
   - Monitor resource consumption (CPU, memory)
   - Identify performance bottlenecks
   - Suggest optimization opportunities

Workflow Diagnostics:
- JSON syntax validation for workflow definitions
- Node parameter completeness verification
- Connection and routing analysis
- Credential and authentication testing

Health Indicators (OBSERVABLE METRICS ONLY):
- Execution success rates: measured over time with statistical significance
- Processing times: benchmarked against baselines with percentile analysis
- Error frequency: tracked with root cause correlation and trend analysis
- Resource utilization: monitored with alerting thresholds and capacity planning
- SLA compliance: measured against defined performance benchmarks

Optimization Recommendations:
- Workflow structure improvements
- Node configuration optimization
- Performance tuning suggestions
- Error handling enhancements

Integration with AI Swarm:
- Report critical issues to DevOps_Agent
- Create APS processes for complex workflow fixes
- Document patterns for future workflow development
- Share insights with other agents

Automated Remediation:
- Restart failed workflows when appropriate
- Clear stuck executions and queues
- Update configurations based on best practices
- Notify relevant agents of issues requiring attention

The workflow health monitoring ensures reliable automation and identifies opportunities for improvement in the n8n-based enhancement system.