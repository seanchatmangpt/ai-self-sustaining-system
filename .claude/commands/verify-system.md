OpenTelemetry and benchmark verification for system claims and assertions.

Verification scope: $ARGUMENTS (optional: specific claim, system component, or metric to verify)

System Verification Protocol:
1. **Telemetry Data Validation** (NEVER TRUST - ALWAYS VERIFY):
   - OpenTelemetry traces: verify spans exist AND measure latency distributions
   - Metrics collection: validate data points AND check for anomalies/gaps
   - Distributed tracing: ensure complete request flows AND measure accuracy
   - Error tracking: verify error rates AND correlate with system changes
   - Custom metrics: validate business logic tracking AND measure correctness

2. **Performance Benchmark Validation**:
   - Response times: measure current performance AND compare to baselines
   - Throughput metrics: validate request rates AND capacity measurements
   - Resource utilization: benchmark CPU/memory usage AND trend analysis
   - Database performance: measure query times AND validate optimization claims
   - External service latency: verify SLA compliance AND measure availability

3. **System Health Verification** (EVIDENCE-REQUIRED VALIDATION):
   - Service availability: test endpoints AND measure uptime/downtime patterns
   - Error rates: analyze telemetry data AND validate error pattern claims
   - Capacity metrics: measure actual usage AND verify capacity planning
   - Scalability testing: benchmark load handling AND validate scaling claims
   - Reliability metrics: measure MTBF/MTTR AND verify SLA compliance

4. **Code Quality Verification**:
   - Test coverage: measure actual coverage AND validate quality claims
   - Performance tests: run benchmarks AND verify optimization assertions
   - Static analysis: validate complexity metrics AND code quality scores
   - Security scans: verify vulnerability claims WITH actual scan results
   - Dependency analysis: measure security/performance impact of dependencies

5. **Workflow and Process Verification**:
   - n8n execution metrics: validate workflow success rates AND timing claims
   - Agent coordination: measure handoff times AND verify efficiency claims
   - Process automation: benchmark manual vs automated processes
   - Error recovery: test failure scenarios AND measure recovery times
   - Data accuracy: validate data transformation claims WITH test data

6. **Business Logic Verification**:
   - Feature functionality: test user scenarios AND measure success rates
   - Data consistency: validate database state AND measure data integrity
   - Business rules: verify implementation AND test edge cases
   - User experience: measure actual usage patterns AND performance impact
   - Compliance validation: verify regulatory requirements WITH audit evidence

Verification Commands:
- `mix test --cover` - Validate test coverage claims
- `mix benchmark` - Run performance benchmarks
- OpenTelemetry query validation for metrics claims
- Load testing for capacity and performance assertions
- Security scanning for vulnerability claims
- Database query analysis for performance claims

Anti-Patterns to Eliminate:
- "The system is working" (without telemetry proof)
- "Performance is good" (without benchmark comparison)
- "Tests are passing" (without coverage and quality metrics)
- "No errors detected" (without comprehensive monitoring)
- "Users are satisfied" (without measurable satisfaction metrics)

Verification Requirements:
- ALL claims must be backed by observable data
- Performance assertions require benchmark comparisons
- System health claims need telemetry evidence
- Quality statements require measurable metrics
- Process efficiency claims need timing and success rate data

Success Criteria:
- Verification completes with measurable evidence
- Claims are validated or refuted with data
- Recommendations include specific metrics and thresholds
- Follow-up monitoring is established for ongoing validation
- Telemetry gaps are identified and addressed

The verification system ensures no claim goes unvalidated and all assertions are backed by observable, measurable evidence from telemetry and benchmarking systems.