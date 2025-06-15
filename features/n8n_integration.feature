Feature: N8n Integration and Workflow Automation
  As an AI Self-Sustaining System
  I want to integrate seamlessly with n8n for workflow automation
  So that I can execute complex automation workflows while maintaining pure Reactor patterns

  Background:
    Given the N8nIntegrationReactor is available
    And the n8n integration uses pure Reactor patterns
    And all n8n functionality has been preserved
    And the system can compile, export, and trigger n8n workflows

  @critical @n8n
  Scenario: Compile Workflow Definition to N8n JSON
    Given I have a workflow definition with 3 nodes
    And the workflow has 2 connections between nodes
    And the workflow includes a webhook trigger
    When I compile the workflow to n8n JSON format
    Then the JSON should contain exactly 3 nodes plus 1 trigger
    And all connections should be properly mapped
    And the webhook trigger should have a unique webhook ID
    And the JSON should be valid n8n format

  @critical @n8n
  Scenario: Export Workflow to N8n Instance
    Given I have a compiled n8n workflow JSON
    And the n8n instance is running and accessible
    And I have valid n8n API credentials
    When I export the workflow to the n8n instance
    Then the workflow should be created in n8n successfully
    And n8n should return a workflow ID
    And the workflow should be visible in n8n interface
    And export telemetry should be recorded

  @critical @n8n
  Scenario: Trigger N8n Workflow Execution
    Given I have a workflow deployed in n8n
    And the workflow has a webhook trigger configured
    And the workflow is active in n8n
    When I trigger the workflow execution
    Then n8n should execute the workflow
    And I should receive an execution ID
    And execution status should be "running"
    And trigger telemetry should be captured

  @n8n @validation
  Scenario: Validate N8n Workflow Definition
    Given I have a workflow definition to validate
    And the definition may have missing required fields
    When I validate the workflow definition
    Then validation should check for required name field
    And validation should verify nodes array exists
    And validation should confirm connections are valid
    And validation should return detailed error messages for issues

  @n8n @nodes
  Scenario: Convert Custom Nodes to N8n Format
    Given I have a custom workflow with function nodes
    And the workflow includes HTTP request nodes
    And the workflow has code execution nodes
    When I convert the workflow to n8n format
    Then function nodes should become "n8n-nodes-base.function"
    And HTTP nodes should become "n8n-nodes-base.httpRequest"
    And code nodes should become "n8n-nodes-base.code"
    And all node parameters should be preserved

  @n8n @triggers
  Scenario: Generate N8n Trigger Nodes
    Given I have a workflow with different trigger types
    And the workflow has webhook, schedule, and manual triggers
    When I generate n8n JSON for the workflow
    Then webhook triggers should become "n8n-nodes-base.webhook"
    And schedule triggers should become "n8n-nodes-base.scheduleTrigger"
    And manual triggers should become "n8n-nodes-base.manualTrigger"
    And each trigger should have appropriate parameters

  @n8n @connections
  Scenario: Map Workflow Connections to N8n Format
    Given I have a workflow with complex node connections
    And nodes are connected with different input/output types
    When I generate n8n connection mappings
    Then connections should be grouped by source node
    And each connection should specify target node and type
    And main output connections should be properly indexed
    And connection validation should prevent invalid references

  @n8n @monitoring
  Scenario: Monitor N8n Workflow Execution
    Given I have triggered an n8n workflow
    And the workflow is currently executing
    When I monitor the execution progress
    Then I should receive execution status updates
    And execution telemetry should track progress
    And completion notifications should be available
    And error states should be properly detected

  @n8n @error-handling
  Scenario: Handle N8n Integration Errors
    Given I attempt to export a workflow to n8n
    And the n8n instance is unreachable
    When the export operation fails
    Then the error should be properly caught and logged
    And appropriate error telemetry should be emitted
    And the operation should fail gracefully
    And retry logic should be available for transient errors

  @n8n @batch
  Scenario: Batch Process Multiple N8n Workflows
    Given I have 5 different workflow definitions
    And I want to process them all simultaneously
    When I execute batch workflow processing
    Then all workflows should be processed concurrently
    And each workflow should maintain independent state
    And batch telemetry should track overall progress
    And individual workflow failures should not affect others

  @n8n @compensation
  Scenario: N8n Workflow Compensation and Rollback
    Given I have exported a workflow to n8n
    And the subsequent operation fails
    When compensation logic executes
    Then the exported workflow should be removed from n8n
    And any created resources should be cleaned up
    And compensation telemetry should be recorded
    And the system should return to pre-export state

  @n8n @performance
  Scenario: High-Performance N8n Operations
    Given I need to process 20 workflows rapidly
    And system performance requirements are strict
    When I execute mass n8n operations
    Then all operations should complete within 60 seconds
    And memory usage should remain stable
    And CPU utilization should be optimized
    And performance metrics should meet benchmarks

  @n8n @integration
  Scenario: N8n Integration with Reactor Middleware
    Given I have an n8n workflow using agent coordination
    And the workflow has telemetry middleware enabled
    When I execute the n8n integration workflow
    Then agent coordination should prevent conflicts
    And telemetry should track all n8n operations
    And middleware should enhance n8n execution
    And integration should be seamless

  @n8n @webhooks
  Scenario: N8n Webhook Processing
    Given I have an n8n workflow with webhook triggers
    And the webhook has specific parameter requirements
    When I process webhook requests for the workflow
    Then webhook parameters should be validated
    And workflow execution should be triggered correctly
    And webhook responses should be properly formatted
    And webhook telemetry should track all requests

  @n8n @compatibility
  Scenario: N8n Version Compatibility
    Given I have workflows created for different n8n versions
    And the system needs to maintain compatibility
    When I process workflows with version differences
    Then the system should handle version variations gracefully
    And node type mappings should be version-aware
    And compatibility warnings should be provided
    And migration assistance should be available

  @n8n @security
  Scenario: Secure N8n Credential Handling
    Given I have workflows requiring n8n credentials
    And credentials must be handled securely
    When I process workflows with credentials
    Then credentials should never be logged in plain text
    And credential references should be properly formatted
    And secure credential storage should be maintained
    And credential access should be audited