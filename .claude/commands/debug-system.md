AI-assisted debugging across Phoenix, n8n, and system infrastructure.

Debug target: $ARGUMENTS (optional: specific component or issue type)

Debugging Modes:
1. **Phoenix/Elixir Application** (EVIDENCE-BASED DEBUGGING):
   - Phoenix server: test port 4001 AND execute health endpoint with timing
   - Crash dumps: analyze erl_crash.dump AND correlate with telemetry error spikes
   - Compilation: run `mix compile --warnings-as-errors` AND verify no hidden issues
   - Database connectivity: execute test queries AND measure response times
   - Error logs: parse with timestamps AND correlate with performance metrics
   - OpenTelemetry traces: analyze request spans for bottlenecks and failures

2. **n8n Workflow Engine** (TELEMETRY-VERIFIED DEBUGGING):
   - Service status: test port 5678 AND execute API health check with response time
   - Workflow execution: analyze logs AND measure success/failure rates over time
   - JSON syntax: validate AND test execution with performance benchmarks
   - API connectivity: test credentials AND measure external service response times
   - Container logs: parse for errors AND correlate with resource usage metrics
   - Workflow telemetry: verify execution traces and performance data collection

3. **System Infrastructure**:
   - Monitor PostgreSQL, n8n, Phoenix services
   - Check disk space and memory usage
   - Verify network connectivity on key ports
   - Scan for resource bottlenecks

4. **Test Failure Analysis** (BENCHMARK-DRIVEN VALIDATION):
   - Test suite: run `mix test --trace` AND measure execution times vs. baselines
   - Failure patterns: analyze AND correlate with recent code changes via metrics
   - Test data: verify setup AND measure database state consistency
   - Async conflicts: identify via timing analysis AND resource contention metrics
   - Test telemetry: verify test execution traces and performance indicators

5. **Performance Investigation** (OBSERVABILITY-DRIVEN ANALYSIS):
   - System resources: monitor real-time usage AND compare against baseline metrics
   - Memory leaks: analyze heap dumps AND track memory usage trends over time
   - Database performance: execute benchmark queries AND measure vs. historical data
   - External dependencies: measure timeout rates AND analyze response time distributions
   - APM metrics: leverage OpenTelemetry data for performance bottleneck identification

6. **Stack Trace Analysis**:
   - Parse error logs and crash dumps
   - Interpret Elixir/Phoenix stack traces
   - Correlate errors with recent code changes
   - Provide root cause analysis

7. **Code Review Analysis**:
   - Scan for TODO/FIXME comments
   - Identify large files needing refactoring
   - Find unused or backup files
   - Check code quality patterns

Based on Anthropic teams' debugging practices:
- Use screenshots for visual debugging
- Leverage stack trace interpretation
- Provide Kubernetes operations guidance
- Focus on practical problem resolution

Provide specific commands and solutions for identified issues.