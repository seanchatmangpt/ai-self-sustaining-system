Feature: Reactor Workflow Orchestration
  As an AI Self-Sustaining System
  I want to orchestrate all workflows using pure Reactor patterns
  So that I can achieve enterprise-grade reliability and performance

  Background:
    Given the system is using Reactor framework version 0.8+
    And all custom GenServer workflows have been replaced
    And the system has zero custom workflow implementations

  @critical @reactor
  Scenario: Execute Self-Improvement Reactor Workflow
    Given I have a self-improvement request with priority "high"
    And the system baseline metrics are available
    When I execute the SelfImprovementReactor workflow
    Then the workflow should complete successfully
    And I should receive improvement recommendations
    And the execution should use pure Reactor patterns
    And telemetry should track all workflow steps

  @critical @reactor
  Scenario: Execute N8n Integration Reactor Workflow
    Given I have an n8n workflow definition with 3 nodes
    And the n8n configuration is valid
    When I execute the N8nIntegrationReactor with action "compile"
    Then the workflow should compile to valid n8n JSON
    And the JSON should contain all 3 nodes
    And the compilation should complete within 30 seconds
    And telemetry should record compilation metrics

  @critical @reactor
  Scenario: Execute APS Coordination Reactor Workflow
    Given I have an APS process definition for "Feature_Implementation"
    And the process has roles ["PM_Agent", "Developer_Agent", "QA_Agent"]
    When I execute the APSReactor workflow with action "initialize"
    Then the process should be initialized successfully
    And agent roles should be defined correctly
    And the process state should be "pending"
    And coordination telemetry should be recorded

  @performance @reactor
  Scenario: Parallel Reactor Workflow Execution
    Given I have 5 different reactor workflows ready to execute
    And the system load is below 70%
    When I execute all workflows concurrently
    Then all workflows should complete successfully
    And the total execution time should be less than sequential execution
    And no workflow conflicts should occur
    And resource utilization should be optimal

  @error-handling @reactor
  Scenario: Reactor Workflow Error Recovery
    Given I have a reactor workflow that will fail at step 3
    And the workflow has compensation logic defined
    When I execute the workflow
    Then the workflow should fail at step 3
    And compensation should automatically trigger
    And all completed steps should be rolled back
    And the system should return to the original state
    And error telemetry should be comprehensive

  @middleware @reactor
  Scenario: Reactor Middleware Integration
    Given I have a reactor workflow with telemetry middleware
    And the workflow has agent coordination middleware
    When I execute the workflow
    Then telemetry middleware should track all execution events
    And agent coordination middleware should manage work claims
    And OpenTelemetry spans should be created for all steps
    And coordination conflicts should be prevented

  @async @reactor
  Scenario: Asynchronous Reactor Step Execution
    Given I have a reactor workflow with async steps enabled
    And the workflow has 4 independent parallel steps
    When I execute the workflow
    Then all 4 steps should execute concurrently
    And the total execution time should be approximately the longest step
    And each step should have proper process isolation
    And async telemetry should track process boundaries

  @compensation @reactor
  Scenario: Reactor Compensation Chain Execution
    Given I have a multi-step reactor workflow
    And each step has compensation logic defined
    And step 4 will fail during execution
    When I execute the workflow
    Then steps 1, 2, and 3 should complete successfully
    And step 4 should fail as expected
    And compensation should execute in reverse order (3, 2, 1)
    And all side effects should be undone
    And the final state should match the initial state

  @validation @reactor
  Scenario: Reactor Input Validation
    Given I have a reactor workflow with required inputs
    And the workflow expects inputs: workflow_data, config, action
    When I execute the workflow with missing "config" input
    Then the workflow should fail immediately with validation error
    And the error should specify "config input is required"
    And no workflow steps should execute
    And validation telemetry should be recorded

  @timeout @reactor
  Scenario: Reactor Step Timeout Handling
    Given I have a reactor workflow with a step timeout of 30 seconds
    And one step will take 45 seconds to execute
    When I execute the workflow
    Then the long-running step should timeout after 30 seconds
    And compensation should trigger for any completed steps
    And timeout telemetry should be recorded
    And the workflow should fail with timeout error

  @retry @reactor
  Scenario: Reactor Step Retry Logic
    Given I have a reactor workflow with retry logic enabled
    And one step is configured with max_retries: 3
    And the step will fail twice then succeed
    When I execute the workflow
    Then the failing step should retry exactly 2 times
    And the step should succeed on the 3rd attempt
    And the workflow should complete successfully
    And retry telemetry should track all attempts

  @integration @reactor
  Scenario: Reactor Integration with Ash Framework
    Given I have a reactor workflow that uses Ash resources
    And the workflow needs to create and read data
    When I execute the workflow
    Then the workflow should successfully interact with Ash resources
    And data should be persisted correctly
    And Ash operations should not interfere with Reactor execution
    And both Ash and Reactor telemetry should be captured