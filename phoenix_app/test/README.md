# Self-Sustaining AI System - Test Suite Documentation

## Overview

This test suite provides comprehensive validation of the entire self-improvement loop in the AI self-sustaining system. It uses advanced testing techniques including property-based testing, chaos engineering, and long-running stability tests to ensure the system behaves correctly under all conditions.

## Test Architecture

The test suite is organized into several layers:

### 1. **Unit Tests** (`n8n/`, `self_sustaining_web/`)
- Fast, isolated tests for individual components
- DSL compilation, validation, and JSON generation
- Web interface controllers and live views
- Workflow management functions

### 2. **Integration Tests** (`self_sustaining/ai/`)
- Multi-component interaction testing
- Complete improvement cycle validation
- Workflow generation and deployment
- System orchestration testing

### 3. **Property-Based Tests** (`comprehensive_loop_property_test.exs`)
- Generated test cases using StreamData
- System invariant validation
- Edge case discovery
- Performance characteristic validation

### 4. **Chaos Engineering Tests**
- Random failure injection
- Resilience under adverse conditions
- Recovery and degradation testing
- Fault tolerance validation

## Running the Test Suite

### Quick Test Runs

```bash
# Run basic unit and integration tests (default)
mix test

# Run only fast unit tests
TEST_SUITE=unit mix test

# Run unit and integration tests
TEST_SUITE=integration mix test
```

### Comprehensive Testing

```bash
# Run comprehensive system validation
TEST_SUITE=comprehensive mix test

# Run chaos engineering tests
TEST_SUITE=chaos mix test

# Run all tests (slow - allows 2+ hours)
TEST_SUITE=all mix test
```

### Specific Test Categories

```bash
# Run specific test files
mix test test/n8n/reactor_test.exs
mix test test/self_sustaining/ai/self_improvement_loop_test.exs

# Run tests with specific tags
mix test --include property
mix test --include chaos --exclude slow
mix test --only comprehensive
```

### Parallel Testing

```bash
# Run tests in parallel (faster but uses more resources)
mix test --max-cases 4

# Run with specific timeout for slow tests
mix test --timeout 300000  # 5 minutes
```

## Test Categories and Tags

### Test Tags

- `:unit` - Fast unit tests (< 1 second each)
- `:integration` - Integration tests (< 10 seconds each)
- `:slow` - Long-running tests (> 30 seconds each)
- `:chaos` - Chaos engineering tests with failure injection
- `:property` - Property-based tests using StreamData
- `:comprehensive` - Full end-to-end system validation

### Test Types

#### **Unit Tests** 🔹
- **Purpose**: Validate individual components in isolation
- **Speed**: < 1 second per test
- **Examples**: DSL compilation, JSON generation, workflow validation
- **Coverage**: 90%+ of core functionality

#### **Integration Tests** 🔹
- **Purpose**: Validate component interactions and workflows
- **Speed**: 1-10 seconds per test
- **Examples**: Complete improvement cycles, workflow deployment
- **Coverage**: Key integration points and data flows

#### **Property-Based Tests** 🔹
- **Purpose**: Validate system behavior across all possible inputs
- **Speed**: Variable (1-60 seconds per property)
- **Examples**: System invariants, workflow generation validity
- **Coverage**: Edge cases and boundary conditions

#### **Chaos Engineering Tests** 🔹
- **Purpose**: Validate system resilience under failure conditions
- **Speed**: 10-120 seconds per test
- **Examples**: Random failure injection, service outages
- **Coverage**: Error handling and recovery mechanisms

#### **Comprehensive Tests** 🔹
- **Purpose**: End-to-end validation of complete system behavior
- **Speed**: 30-300 seconds per test
- **Examples**: Long-running stability, memory leak detection
- **Coverage**: System-wide behavior and performance

## Key Test Files

### Core Loop Testing
- **`self_improvement_loop_test.exs`** - Main integration tests for the improvement cycle
- **`comprehensive_loop_property_test.exs`** - Property-based and chaos testing
- **`workflow_generator_test.exs`** - AI workflow generation validation

### Component Testing
- **`reactor_test.exs`** - n8n DSL framework testing
- **`workflow_manager_test.exs`** - Workflow compilation and management
- **`workflow_controller_test.exs`** - Web interface testing

### Support Modules
- **`test_workflows.ex`** - Test workflow fixtures and examples
- **`self_improvement_test_helpers.ex`** - Advanced testing utilities

## Test Configuration

### Environment Variables

```bash
# Test suite selection
export TEST_SUITE=comprehensive

# Test timeouts
export TEST_TIMEOUT=300000  # 5 minutes

# Parallel execution
export TEST_MAX_CASES=2

# Logging level during tests
export LOG_LEVEL=warn
```

### Configuration Files

- **`test_helper.exs`** - Main test configuration and setup
- **`test/support/`** - Test utilities and fixtures
- **`config/test.exs`** - Application configuration for testing

## Interpreting Test Results

### Success Indicators ✅

```
🤖 Self-Sustaining AI System Test Suite

✅ Unit Tests: 45 passed, 0 failed
✅ Integration Tests: 12 passed, 0 failed  
✅ Property Tests: 5 properties validated
✅ System Invariants: All maintained
✅ Performance: Within acceptable thresholds
✅ Security: No vulnerabilities detected

Total: 62 tests, 0 failures
```

### Performance Metrics

Tests track and validate:
- **Cycle Duration**: < 30 seconds per improvement cycle
- **Memory Usage**: < 80% of available memory
- **Success Rate**: > 80% for all operations
- **Throughput**: Appropriate for system load
- **Response Times**: < 5 seconds for API calls

### Failure Analysis

Common failure patterns and their meanings:

#### **System Invariant Violations**
```
❌ System invariant violated: Cycle ID decreased from 5 to 3
```
- **Cause**: State corruption or race condition
- **Action**: Check concurrency controls and state management

#### **Performance Regressions**
```
❌ Performance regression: cycle_duration 45000ms exceeds threshold 30000ms
```
- **Cause**: Performance degradation over time
- **Action**: Profile and optimize slow components

#### **Security Vulnerabilities**
```
❌ Security violation: Potential code injection in workflow parameters
```
- **Cause**: Insufficient input sanitization
- **Action**: Review and strengthen input validation

#### **Memory Leaks**
```
❌ Memory leak detected: 150MB growth over 50 cycles
```
- **Cause**: Unreleased resources or accumulating state
- **Action**: Review resource management and cleanup

## Advanced Testing Scenarios

### Chaos Engineering

The chaos tests simulate real-world failure conditions:

```elixir
# Network failures (20% injection rate)
chaos_config = %{
  failure_rate: 0.2,
  failure_types: [:network, :timeout, :resource],
  duration: 15_000
}
```

### Property-Based Testing

Properties validated across all possible inputs:

```elixir
property "system maintains invariants" do
  check all cycle_data <- improvement_cycle_generator() do
    # Test with generated data
    assert_system_invariants(simulate_cycle(cycle_data))
  end
end
```

### Long-Running Stability

Extended operation testing:

```elixir
# Run 100 improvement cycles
test "long-running stability" do
  for cycle <- 1..100 do
    result = execute_improvement_cycle()
    assert_performance_acceptable(result)
  end
end
```

## Performance Benchmarks

### Baseline Performance Targets

| Metric | Target | Threshold |
|--------|--------|-----------|
| Cycle Duration | < 10s | < 30s |
| Memory Usage | < 50% | < 80% |
| Success Rate | > 95% | > 80% |
| API Response | < 1s | < 5s |
| Compilation Time | < 5s | < 15s |

### Load Testing Results

Expected performance under load:

- **1-5 concurrent cycles**: Normal performance
- **6-10 concurrent cycles**: Slight degradation acceptable
- **11-20 concurrent cycles**: Graceful degradation required
- **20+ concurrent cycles**: System should throttle/queue

## Debugging Test Failures

### Enable Detailed Logging

```bash
# Run with debug logging
LOG_LEVEL=debug mix test

# Enable test tracing
MIX_ENV=test iex -S mix
```

### Test Data Inspection

```elixir
# In test files, add debugging
IO.inspect(test_data, label: "Debug")

# Save test artifacts for inspection
File.write!("test_debug.json", Jason.encode!(data, pretty: true))
```

### Isolated Test Runs

```bash
# Run single test
mix test test/path/to/test.exs:line_number

# Run with seed for reproducibility
mix test --seed 12345
```

## Continuous Integration

### CI Pipeline Configuration

Recommended test stages for CI:

1. **Fast Feedback** (< 2 minutes)
   ```bash
   TEST_SUITE=unit mix test
   ```

2. **Integration Validation** (< 10 minutes)
   ```bash
   TEST_SUITE=integration mix test
   ```

3. **Comprehensive Validation** (< 30 minutes)
   ```bash
   TEST_SUITE=comprehensive mix test
   ```

4. **Nightly Chaos Testing** (< 2 hours)
   ```bash
   TEST_SUITE=all mix test
   ```

### Quality Gates

Tests must pass with:
- ✅ 0 test failures
- ✅ > 90% code coverage
- ✅ All performance thresholds met
- ✅ No security vulnerabilities
- ✅ All system invariants maintained

## Contributing New Tests

### Test Development Guidelines

1. **Follow the AAA Pattern**: Arrange, Act, Assert
2. **Use Descriptive Names**: Test names should explain the scenario
3. **Include Edge Cases**: Test boundary conditions and error cases
4. **Mock External Dependencies**: Use Mox for external services
5. **Test Performance**: Include timing and resource usage validation
6. **Document Complex Tests**: Explain non-obvious test logic

### Adding Property-Based Tests

```elixir
property "new system property" do
  check all input_data <- your_generator() do
    result = system_function(input_data)
    assert your_property_holds(result)
  end
end
```

### Adding Chaos Tests

```elixir
test "system survives new failure type" do
  chaos_config = %{
    failure_rate: 0.3,
    failure_types: [:your_new_failure],
    duration: 10_000
  }
  
  chaos_test(chaos_config) do
    # Your test logic here
  end
end
```

---

## Summary

This comprehensive test suite ensures the AI self-sustaining system remains stable, performant, and secure while continuously evolving. The combination of unit, integration, property-based, and chaos testing provides confidence that the system will behave correctly under all conditions.

Run tests frequently during development and always before deploying changes to the self-improvement system.