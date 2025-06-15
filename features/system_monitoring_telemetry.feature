Feature: System Monitoring and Telemetry
  As an AI Self-Sustaining System
  I want comprehensive monitoring and telemetry across all components
  So that I can maintain system health, performance visibility, and proactive issue detection

  Background:
    Given OpenTelemetry is configured and active
    And telemetry middleware is enabled for all Reactor workflows
    And system health monitoring is operational
    And metrics collection is configured for Phoenix, n8n, and PostgreSQL

  @critical @monitoring
  Scenario: Real-time System Health Dashboard
    Given the system has been running for at least 30 minutes
    And all core components are operational (Phoenix, PostgreSQL, n8n)
    When I query the system health dashboard
    Then Phoenix application health should be GREEN
    And PostgreSQL database health should be GREEN  
    And n8n workflow engine health should be GREEN
    And system resource utilization should be within normal ranges
    And alert status should show no critical issues

  @critical @telemetry
  Scenario: OpenTelemetry Span Creation for Reactor Workflows
    Given I execute a SelfImprovementReactor workflow
    And OpenTelemetry tracing is enabled
    When the workflow executes with telemetry middleware
    Then a root span should be created for the workflow
    And each Reactor step should have its own span
    And spans should be properly nested with parent-child relationships
    And span attributes should include reactor ID, step name, and execution context
    And spans should be exported to the telemetry backend

  @monitoring @performance
  Scenario: Performance Metrics Collection and Analysis
    Given the system has processed 100+ workflow executions
    And performance metrics are being collected
    When I analyze system performance metrics
    Then average workflow execution time should be calculated
    And P95 and P99 latency percentiles should be available
    And throughput metrics should show requests per second
    And resource utilization trends should be visible
    And performance regression detection should be active

  @monitoring @alerting
  Scenario: Proactive System Alerting
    Given system monitoring with alerting is configured
    And alert thresholds are defined for critical metrics
    When system metrics exceed alerting thresholds
    Then alerts should be triggered within 30 seconds
    And alert notifications should include context and severity
    And alert escalation should follow defined procedures
    And alert correlation should prevent notification storms
    And alert resolution should be tracked automatically

  @telemetry @metrics
  Scenario: Custom Business Metrics Tracking
    Given I want to track AI agent coordination efficiency
    And custom metrics are configured for agent activities
    When agents execute coordination workflows
    Then agent utilization rates should be measured
    And work claim conflict rates should be tracked
    And handoff completion times should be recorded
    And success rates should be calculated per agent type
    And custom metrics should be available in dashboards

  @monitoring @database
  Scenario: PostgreSQL Database Monitoring
    Given PostgreSQL is running with monitoring enabled
    And database performance metrics are being collected
    When I check database health and performance
    Then connection pool status should be healthy
    And query performance metrics should be within thresholds
    And database locks and waits should be minimal
    And storage utilization should be tracked
    And backup status should be verified

  @monitoring @phoenix
  Scenario: Phoenix Application Monitoring
    Given the Phoenix application is running with telemetry
    And Phoenix LiveDashboard is accessible
    When I monitor Phoenix application health
    Then HTTP request metrics should show healthy response times
    And process count should be within expected ranges
    And memory usage should be stable
    And error rates should be below threshold
    And Phoenix telemetry events should be captured

  @telemetry @distributed
  Scenario: Distributed Tracing Across Components
    Given I have a workflow that spans Phoenix, n8n, and database operations
    And distributed tracing is enabled
    When the workflow executes end-to-end
    Then a distributed trace should connect all components
    And trace context should propagate between services
    And each component should contribute spans to the trace
    And the complete request path should be visualizable
    And cross-service dependencies should be clear

  @monitoring @n8n
  Scenario: N8n Workflow Engine Monitoring
    Given n8n workflows are executing regularly
    And n8n monitoring is configured
    When I check n8n system health
    Then n8n service availability should be confirmed
    And workflow execution statistics should be available
    And failed workflow rates should be tracked
    And n8n resource usage should be monitored
    And workflow performance trends should be visible

  @telemetry @errors
  Scenario: Error Tracking and Analysis
    Given comprehensive error tracking is enabled
    And errors are instrumented with telemetry
    When system errors occur during operation
    Then errors should be captured with full context
    And error rates should be tracked by component
    And error patterns should be analyzed for trends
    And error impact should be measured and reported
    And error resolution should be tracked

  @monitoring @capacity
  Scenario: System Capacity Planning and Forecasting
    Given system usage metrics are collected over time
    And capacity planning analysis is enabled
    When I perform capacity planning analysis
    Then current resource utilization trends should be analyzed
    And future capacity needs should be forecasted
    And scaling recommendations should be provided
    And capacity bottlenecks should be identified
    And growth projections should be updated regularly

  @telemetry @slo
  Scenario: Service Level Objectives (SLO) Monitoring
    Given SLOs are defined for critical system functions
    And SLO monitoring is configured
    When I track SLO compliance
    Then workflow execution success rate should meet 99.5% SLO
    And system response time should meet P95 < 2s SLO
    And system availability should meet 99.9% uptime SLO
    And SLO burn rate should be monitored for early warning
    And SLO compliance reports should be generated

  @monitoring @security
  Scenario: Security Monitoring and Audit Logging
    Given security monitoring is enabled
    And audit logging is configured
    When security-relevant events occur
    Then authentication attempts should be logged
    And authorization failures should be tracked
    And suspicious activity patterns should be detected
    And security metrics should be available in dashboards
    And compliance audit trails should be maintained

  @telemetry @business
  Scenario: Business Intelligence and Usage Analytics
    Given business metrics tracking is enabled
    And usage analytics are configured
    When I analyze system usage patterns
    Then user interaction patterns should be analyzed
    And feature usage statistics should be available
    And workflow success rates should be tracked
    And business value metrics should be calculated
    And usage trends should inform product decisions

  @monitoring @infrastructure
  Scenario: Infrastructure Monitoring and Resource Tracking
    Given infrastructure monitoring is configured
    And system resources are being tracked
    When I monitor infrastructure health
    Then CPU, memory, and disk usage should be tracked
    And network performance should be monitored
    And container/process health should be verified
    And infrastructure costs should be tracked
    And resource optimization opportunities should be identified

  @telemetry @integration
  Scenario: Third-party Integration Monitoring
    Given the system integrates with external services
    And integration monitoring is enabled
    When external integrations are used
    Then integration availability should be monitored
    And integration response times should be tracked
    And integration error rates should be measured
    And integration dependency health should be verified
    And integration SLA compliance should be monitored