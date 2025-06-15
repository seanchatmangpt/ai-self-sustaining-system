Feature: Ash Framework Database Operations
  As an AI Self-Sustaining System
  I want comprehensive database operations through Ash Framework
  So that I can manage data with type safety, relationships, and advanced features

  Background:
    Given Ash Framework is configured with AshPostgres
    And PostgreSQL database is running with required extensions
    And Ash domains are properly defined (AIDomain, APSDomain)
    And Ash resources are configured with proper relationships

  @critical @ash
  Scenario: Ash Resource CRUD Operations
    Given I have an Improvement resource in the AI domain
    And the resource has required attributes (title, description, confidence_score)
    When I perform CRUD operations on the Improvement resource
    Then I should be able to create new improvements with validation
    And I should be able to read improvements with proper filtering
    And I should be able to update improvements with change tracking
    And I should be able to delete improvements with proper authorization
    And all operations should maintain data integrity

  @critical @ash
  Scenario: Ash Resource Relationships and Associations
    Given Improvement resource belongs_to Task resource
    And Task resource has_many Improvement resources
    When I work with related resources
    Then I should be able to create improvements linked to tasks
    And I should be able to load tasks with their improvements
    And relationship constraints should be enforced
    And cascading operations should work correctly
    And relationship queries should be optimized

  @ash @migrations
  Scenario: Ash-Generated Database Migrations
    Given I modify an Ash resource definition
    And resource snapshots are properly maintained
    When I generate migrations using mix ash_postgres.generate_migrations
    Then migrations should be generated automatically from resource changes
    And migrations should include all necessary schema changes
    And resource snapshots should be updated in priv/resource_snapshots/
    And migrations should be safe and reversible
    And migration conflicts should be detected and resolved

  @ash @validation
  Scenario: Ash Resource Validation and Constraints
    Given Improvement resource has validation rules
    And validation includes required fields and format constraints
    When I attempt to create or update resources with invalid data
    Then validation should prevent invalid data from being saved
    And validation errors should be clear and actionable
    And custom validation functions should be executed
    And validation should work consistently across all operations
    And validation should be performed at the appropriate level

  @ash @actions
  Scenario: Custom Ash Resource Actions
    Given Improvement resource has custom actions defined
    And I have an "apply" action that changes status to applied
    When I execute the custom action
    Then the action should perform the specified changes
    And action-specific validation should be applied
    And action side effects should be executed correctly
    And action telemetry should be recorded
    And action authorization should be enforced

  @ash @queries
  Scenario: Advanced Ash Queries and Filtering
    Given I need to query improvements with complex criteria
    And filtering includes confidence score ranges and status values
    When I execute Ash queries with filters
    Then queries should support complex filtering conditions
    And query results should be properly paginated
    And query performance should be optimized
    And query aggregations should be available
    And query results should be properly typed

  @ash @aggregates
  Scenario: Ash Resource Aggregates and Calculations
    Given Task resource needs to calculate improvement statistics
    And aggregates include count, average confidence, and success rate
    When I access aggregate values
    Then aggregates should be calculated efficiently
    And aggregate values should be accurate and up-to-date
    And aggregate calculations should be cached appropriately
    And aggregates should work with filtering and pagination
    And aggregate queries should be optimized at the database level

  @ash @extensions
  Scenario: PostgreSQL Extension Integration
    Given PostgreSQL is configured with vector, uuid-ossp, and citext extensions
    And Ash resources use extension-specific data types
    When I work with extension features
    Then UUID primary keys should be generated automatically
    And vector data should be stored and queried efficiently
    And citext fields should provide case-insensitive operations
    And extension features should integrate seamlessly with Ash
    And extension data types should be properly validated

  @ash @transactions
  Scenario: Ash Resource Transactions and Atomicity
    Given I need to perform multiple related database operations
    And operations must be atomic (all succeed or all fail)
    When I execute operations within Ash transactions
    Then all operations should succeed or all should be rolled back
    And transaction isolation should be maintained
    And transaction deadlocks should be handled gracefully
    And transaction performance should be optimized
    And transaction boundaries should be clearly defined

  @ash @authorization
  Scenario: Ash Resource Authorization and Policies
    Given Ash resources have authorization policies defined
    And policies control access based on user context and data
    When I attempt operations with different authorization contexts
    Then unauthorized operations should be rejected
    And authorized operations should proceed normally
    And authorization should be applied consistently
    And authorization rules should be clearly documented
    And authorization should not impact performance significantly

  @ash @changesets
  Scenario: Ash Changeset Management and Validation
    Given I create changesets for resource modifications
    And changesets include validation and transformation logic
    When I work with changesets
    Then changesets should validate data before database operations
    And changeset errors should be comprehensive and helpful
    And changeset transformations should be applied correctly
    And changesets should support complex validation scenarios
    And changeset performance should be optimized

  @ash @domains
  Scenario: Ash Domain Organization and Resource Discovery
    Given resources are organized into AI and APS domains
    And domains provide logical grouping and namespace isolation
    When I work with domain-specific resources
    Then domain isolation should be maintained
    And resource discovery should work within domains
    And cross-domain relationships should be supported
    And domain configuration should be flexible
    And domain-level policies should be enforceable

  @ash @telemetry
  Scenario: Ash Framework Telemetry and Monitoring
    Given Ash telemetry is configured and enabled
    And telemetry events are being collected
    When Ash operations are performed
    Then resource operation telemetry should be captured
    And query performance telemetry should be available
    And authorization telemetry should track access patterns
    And telemetry should integrate with application monitoring
    And telemetry overhead should be minimal

  @ash @performance
  Scenario: Ash Framework Performance Optimization
    Given Ash queries are monitored for performance
    And performance optimization strategies are applied
    When database operations are executed through Ash
    Then N+1 queries should be prevented through proper loading
    And database indexes should be utilized effectively
    And query compilation should be cached where appropriate
    And bulk operations should be supported for large datasets
    And performance should scale with data volume

  @ash @vector-search
  Scenario: AI/ML Vector Search with Ash Framework
    Given Improvement resource has full_text_vector attribute
    And vector extension is configured for similarity search
    When I perform vector similarity searches
    Then vector embeddings should be stored and indexed efficiently
    And similarity searches should return relevant results
    And vector operations should integrate with Ash queries
    And vector search performance should be optimized
    And vector data should support different embedding dimensions

  @ash @backup-recovery
  Scenario: Database Backup and Recovery with Ash
    Given database backup procedures are configured
    And backup includes both schema and data
    When backup and recovery operations are performed
    Then Ash resource snapshots should be included in backups
    And schema migrations should be recoverable
    And data consistency should be maintained during recovery
    And recovery procedures should be tested regularly
    And backup verification should confirm data integrity