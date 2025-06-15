Test-Driven Development workflow following Anthropic Security Engineering team practices.

TDD target: $ARGUMENTS (feature name, existing code, or workflow type)

TDD Workflow Options:
1. **Start New Feature with TDD**:
   - Create test and implementation file structure
   - Generate test template with Red-Green-Refactor guidance
   - Set up Elixir ExUnit test patterns
   - Establish TDD cycle checkpoints

2. **Add Tests to Existing Code**:
   - Scan for modules without corresponding tests
   - Generate comprehensive test templates
   - Analyze existing functions for test coverage
   - Create test patterns for public APIs

3. **Refactor with Test Safety Net** (BENCHMARK-VERIFIED SAFETY):
   - Run full test suite AND measure baseline performance metrics
   - Ensure all tests pass AND benchmark execution times before refactoring
   - Provide refactoring guidelines with measurable quality improvements
   - Monitor test status AND performance metrics throughout changes
   - Verify no performance regression with automated benchmarks

4. **Debug Test Failures** (EVIDENCE-BASED DEBUGGING):
   - Run tests with detailed output AND measure timing patterns
   - Analyze failure patterns AND correlate with system metrics
   - Provide debugging guidance backed by telemetry data
   - Suggest fixes validated through measurable test improvements
   - Benchmark test execution times to identify performance issues

5. **Generate Test Documentation**:
   - Create test suite overview and statistics
   - Generate testing guidelines and best practices
   - Document test patterns and examples
   - Provide test running instructions

6. **Test Coverage Analysis** (METRICS-DRIVEN VALIDATION):
   - Run coverage analysis AND benchmark against quality standards
   - Identify uncovered code paths with criticality scoring
   - Set measurable coverage goals with automated enforcement
   - Suggest improvements with impact metrics and ROI analysis
   - Track coverage trends over time with quality gates

TDD Best Practices (MEASURABLE OUTCOMES):
- 🔴 **RED**: Write failing tests first with clear success criteria
- 🟢 **GREEN**: Write minimal code to pass tests AND meet performance benchmarks
- 🔵 **REFACTOR**: Improve code while maintaining test success AND performance metrics
- 🔁 **REPEAT**: Continue cycle with measurable progress tracking
- 📊 **MEASURE**: Track test execution time, coverage, and quality metrics

Test Patterns:
- Arrange-Act-Assert structure
- Edge case and error condition testing
- Test independence and isolation
- Descriptive test names and clear assertions

Integration with Phoenix/Elixir:
- ExUnit test framework patterns
- Mix task integration
- Database testing with Ecto
- LiveView component testing

Follow the "design doc → test → implement → refactor" pattern instead of traditional "design → code → give up on tests" approach.