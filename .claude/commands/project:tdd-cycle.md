# Test-Driven Development Workflow

**Purpose**: Comprehensive TDD workflow management following best practices.

```bash
/project:tdd-cycle [mode]
```

## TDD Workflows

### 1. Start New Feature with TDD
- Red-Green-Refactor cycle setup
- Test template generation
- Requirement analysis and test planning
- Initial failing test creation

### 2. Add Tests to Existing Code
- Retrospective test coverage analysis
- Legacy code test harness creation
- Characterization test development
- Regression test implementation

### 3. Refactor with Test Safety Net
- Pre-refactor test coverage validation
- Safe code improvement execution
- Continuous test execution during refactor
- Post-refactor verification

### 4. Debug Test Failures
- Failure analysis and root cause identification
- Test environment debugging
- Mock and stub validation
- Test data integrity checks

### 5. Generate Test Documentation
- Comprehensive test guide creation
- Coverage report generation
- Test pattern documentation
- Best practices compilation

### 6. Test Coverage Analysis
- Coverage reporting and analysis
- Gap identification and improvement
- Critical path test validation
- Performance test integration

## Features
- **Automatic Test Templates**: Language-specific test generation
- **TDD Cycle Enforcement**: Red-Green-Refactor validation
- **Coverage Analysis**: Detailed coverage reporting
- **Elixir/Phoenix Patterns**: Framework-specific test patterns
- **Integration Support**: Database and API test helpers

## Elixir/Phoenix Specific Features
- ExUnit test template generation
- Phoenix controller and LiveView test patterns
- Ecto schema and changeset testing
- GenServer and OTP test patterns
- Property-based testing with StreamData

## Usage Examples
```bash
/project:tdd-cycle new             # Start new feature with TDD
/project:tdd-cycle coverage        # Analyze test coverage
/project:tdd-cycle refactor        # Safe refactoring with tests
/project:tdd-cycle debug          # Debug failing tests
```