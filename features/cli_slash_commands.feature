Feature: CLI Commands and Slash Command System
  As an AI Self-Sustaining System user
  I want comprehensive CLI and slash commands for system interaction
  So that I can efficiently manage agents, workflows, and system operations

  Background:
    Given Claude Code CLI is installed and configured
    And slash commands are available in the .claude/commands/ directory
    And agent coordination system is operational
    And all system components are accessible through commands

  @critical @cli
  Scenario: Agent Initialization and Role Assignment
    Given I want to start a new AI agent session
    And the system has existing work or needs new processes
    When I execute /project:init-agent
    Then the system should analyze current work state
    And an appropriate agent role should be assigned automatically
    And the agent should register with a unique session ID
    And role assignment should be recorded in .claude_role_assignment
    And the agent should announce its role and readiness

  @critical @cli  
  Scenario: APS Process Creation and Management
    Given I need to create a new workflow process
    And I want to follow APS coordination protocols
    When I execute /project:create-aps with process details
    Then a new APS YAML specification should be created
    And the specification should include all required sections
    And agent roles should be defined with responsibilities
    And Gherkin scenarios should be included for behavior
    And the process should be ready for agent coordination

  @cli @coordination
  Scenario: Work Claim and Assignment System
    Given multiple APS processes are available for agents
    And I need to claim specific work to avoid conflicts
    When I execute /project:claim-work with a process ID
    Then the work should be claimed atomically
    And work conflicts should be prevented
    And claim metadata should be recorded with timestamps
    And the claiming agent should receive work context
    And other agents should see the work as claimed

  @cli @messaging
  Scenario: Inter-Agent Communication
    Given I need to send a message to another agent
    And the message should follow APS protocol
    When I execute /project:send-message with recipient and content
    Then the message should be structured according to APS format
    And the message should be attached to relevant APS files
    And the recipient should be notified of the new message
    And message delivery should be tracked and confirmed
    And message history should be maintained

  @cli @debugging
  Scenario: AI-Assisted System Debugging
    Given I encounter system issues that need investigation
    And debugging requires analysis across multiple components
    When I execute /project:debug-system
    Then I should be presented with debugging mode options
    And Phoenix/Elixir application debugging should be available
    And n8n workflow debugging should be accessible
    And infrastructure debugging should be comprehensive
    And debugging should provide actionable insights and solutions

  @cli @tdd
  Scenario: Test-Driven Development Workflow
    Given I want to implement new features using TDD methodology
    And test coverage and quality are important
    When I execute /project:tdd-cycle
    Then I should be guided through Red-Green-Refactor cycle
    And test templates should be generated automatically
    And TDD best practices should be enforced
    And test coverage should be tracked and reported
    And test failures should be analyzed and addressed

  @cli @monitoring
  Scenario: System Health and Status Monitoring
    Given I need to check overall system health
    And monitoring should cover all critical components
    When I execute /project:system-health
    Then PostgreSQL database status should be checked
    And Phoenix application health should be verified
    And n8n workflow engine status should be confirmed
    And system resources should be monitored
    And health summary should be comprehensive and actionable

  @cli @enhancement
  Scenario: AI-Powered Enhancement Discovery
    Given the system should continuously improve itself
    And enhancement opportunities should be identified automatically
    When I execute /project:discover-enhancements
    Then AI should analyze system patterns and inefficiencies
    And improvement opportunities should be prioritized
    And enhancement recommendations should be actionable
    And improvement impact should be estimated
    And enhancement tracking should be initiated

  @cli @implementation
  Scenario: Automated Enhancement Implementation
    Given improvement opportunities have been identified
    And enhancements are ready for implementation
    When I execute /project:implement-enhancement
    Then the selected enhancement should be implemented automatically
    And implementation should follow best practices
    And tests should be created and executed
    And quality gates should be enforced
    And implementation should be validated before completion

  @cli @memory
  Scenario: Session Memory and Knowledge Management
    Given I need to maintain context across sessions
    And knowledge should be preserved and documented
    When I execute /project:memory-session
    Then session context should be preserved
    And important patterns should be documented
    And runbooks should be created for common operations
    And knowledge transfer should be facilitated
    And session continuity should be maintained

  @cli @autonomous
  Scenario: Autonomous AI Agent Operation
    Given I want the AI to work autonomously
    And autonomous operation should be safe and controlled
    When I execute /project:auto
    Then the AI should analyze current system state
    And strategic thinking should guide decision-making
    And actions should be taken based on priorities
    And autonomous operation should be transparent
    And human oversight should remain available

  @cli @handoffs
  Scenario: Agent Coordination and Handoff Monitoring
    Given multiple agents are working on different tasks
    And coordination status needs to be monitored
    When I execute /project:check-handoffs
    Then current agent assignments should be displayed
    And processes ready for handoff should be identified
    And unread messages should be highlighted
    And coordination health should be assessed
    And recommendations should be provided

  @cli @workflows
  Scenario: Workflow Health and Performance Monitoring
    Given n8n workflows are executing regularly
    And workflow performance needs monitoring
    When I execute /project:workflow-health
    Then n8n workflow engine health should be checked
    And workflow execution statistics should be provided
    And failed workflows should be identified
    And performance metrics should be available
    And optimization recommendations should be suggested

  @cli @help
  Scenario: Comprehensive Help and Documentation
    Given users need guidance on available commands
    And command usage should be clearly documented
    When I execute /project:help
    Then all available commands should be listed
    And command descriptions should be comprehensive
    And usage examples should be provided
    And command categories should be organized logically
    And help should be context-sensitive when possible

  @cli @error-handling
  Scenario: CLI Command Error Handling and Recovery
    Given CLI commands may encounter errors
    And error handling should be user-friendly
    When a command encounters an error condition
    Then error messages should be clear and actionable
    And error context should be preserved for debugging
    And recovery suggestions should be provided
    And error logging should be comprehensive
    And command state should be recoverable

  @cli @performance
  Scenario: CLI Command Performance and Responsiveness
    Given CLI commands should be responsive
    And performance should meet user expectations
    When commands are executed
    Then simple commands should complete within 2 seconds
    And complex operations should provide progress feedback
    And command performance should be monitored
    And performance optimization should be continuous
    And resource usage should be efficient

  @cli @integration
  Scenario: CLI Integration with System Components
    Given CLI commands integrate with multiple system components
    And integration should be seamless and reliable
    When commands interact with system components
    Then Phoenix application integration should be seamless
    And database operations should be handled properly
    And n8n workflow integration should be reliable
    And Reactor workflow integration should be efficient
    And component failures should be handled gracefully