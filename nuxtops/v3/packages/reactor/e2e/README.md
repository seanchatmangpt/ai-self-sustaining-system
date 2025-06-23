# Reactor E2E Testing Infrastructure

Comprehensive End-to-End testing framework for Nuxt Reactor with 80/20 coverage analysis, following proven patterns from the BeamOps system.

## 🎯 80/20 Coverage Philosophy

This testing infrastructure implements the Pareto Principle (80/20 rule) for optimal test coverage:

- **Critical 80%**: Core functionality that handles 80% of use cases with strict performance thresholds
- **Edge 20%**: Edge cases and stress scenarios with more lenient thresholds but comprehensive coverage

## 🏗️ Architecture

```
e2e/
├── docker-compose.yml           # Complete test environment
├── playwright.config.ts         # E2E test configuration
├── global-setup.ts             # Test environment initialization
├── global-teardown.ts          # Cleanup and reporting
├── utils/
│   ├── test-helpers.ts         # Test utilities and helpers
│   └── mock-services.ts        # Mock service implementations
├── tests/
│   ├── critical-80/            # Critical path tests (80%)
│   └── edge-20/               # Edge case tests (20%)
├── scripts/
│   ├── 80-20-analyzer.js       # Coverage analysis
│   ├── performance-profiler.js # Performance profiling
│   ├── validate-80-20-coverage.js  # Coverage validation
│   └── validate-performance-thresholds.js # Performance validation
├── monitoring/
│   ├── prometheus.yml          # Metrics configuration
│   └── grafana/               # Dashboards and visualization
└── reports/                   # Generated test reports
```

## 🚀 Quick Start

### Prerequisites

- Node.js 18+
- Docker and Docker Compose
- Git

### Setup

```bash
# Install dependencies
npm install

# Start test environment
npm run env:start

# Run full E2E test suite
npm run test:e2e:full

# View results in Grafana dashboard
npm run monitoring:dashboard
```

## 📊 Testing Categories

### Critical 80% Tests

High-priority tests covering core functionality with strict thresholds:

- **Response Time**: < 100ms average, < 200ms P95
- **Memory Usage**: < 50MB baseline, < 100MB peak
- **Success Rate**: > 95%
- **Error Rate**: < 1%

```bash
# Run only critical path tests
npx playwright test --project=critical-80-chrome
```

### Edge 20% Tests

Stress tests and edge cases with relaxed thresholds:

- **Response Time**: < 1000ms average, < 5000ms P95
- **Memory Usage**: < 200MB baseline, < 500MB peak
- **Success Rate**: > 70%
- **Error Rate**: < 15%

```bash
# Run only edge case tests
npx playwright test --project=edge-20-stress
```

## 🔧 Configuration

### Environment Variables

```bash
# Test configuration
BASE_URL=http://localhost:3000
DATABASE_URL=postgresql://reactor_user:reactor_pass@localhost:5432/reactor_e2e
REDIS_URL=redis://localhost:6379/0

# Monitoring
JAEGER_ENDPOINT=http://localhost:16686
PROMETHEUS_ENDPOINT=http://localhost:9090
GRAFANA_ENDPOINT=http://localhost:3001

# Test execution
CI=false
PLAYWRIGHT_BROWSERS_PATH=~/.cache/playwright
TEST_TIMEOUT=30000
```

### Docker Services

The test environment includes:

- **Nuxt App** (port 3000): Main application under test
- **PostgreSQL** (port 5432): Test data persistence
- **Redis** (port 6379): Caching and sessions
- **Jaeger** (port 16686): Distributed tracing
- **Prometheus** (port 9090): Metrics collection
- **Grafana** (port 3001): Visualization and analysis

## 📈 Performance Analysis

### 80/20 Coverage Analysis

```bash
# Analyze test coverage with 80/20 principles
npm run coverage:8020

# Validate coverage meets thresholds
npm run validation:8020
```

### Performance Profiling

```bash
# Profile performance across all scenarios
npm run performance:profile

# Validate performance thresholds
npm run validation:thresholds
```

## 🎛️ Monitoring and Observability

### Grafana Dashboards

Access real-time monitoring at http://localhost:3001:

- **80/20 Coverage Dashboard**: Success rates, latency distribution, memory usage
- **Performance Metrics**: Throughput, error rates, resource utilization
- **Test Results**: Scenario outcomes, trend analysis

### OpenTelemetry Tracing

View distributed traces at http://localhost:16686:

- End-to-end request tracing
- Performance bottleneck identification
- Error propagation analysis

### Prometheus Metrics

Query metrics at http://localhost:9090:

```promql
# 80% critical path success rate
reactor:critical_success_rate

# 95th percentile latency
reactor:critical_path_latency_p95

# Memory utilization trend
reactor:memory_utilization_trend

# Error rate threshold
reactor:error_rate_threshold
```

## 🧪 Test Development

### Writing Critical 80% Tests

```typescript
import { test, expect } from '@playwright/test';
import { ReactorTestHelpers } from '../utils/test-helpers';

test('Critical path scenario', async ({ browser }) => {
  const testContext = await testHelpers.createTestContext(browser, '80-critical');
  
  const result = await testHelpers.executeReactorScenario(testContext, {
    name: 'critical-workflow',
    endpoint: '/api/reactor/examples/critical',
    assertions: async (page, result) => {
      expect(result.state).toBe('completed');
      expect(result.duration).toBeLessThan(100);
    }
  });

  // Validate performance thresholds
  const performanceValid = testHelpers.validatePerformanceThresholds(testContext, {
    maxResponseTime: 100,
    maxMemoryUsage: 50 * 1024 * 1024,
    maxErrors: 0
  });

  expect(performanceValid).toBe(true);
});
```

### Test Data Generation

```typescript
// Generate test data for different scenarios
const testData = testHelpers.generateTestData('basic-workflow', 'medium');
const stressData = testHelpers.generateTestData('memory-stress', 'large');
```

## 📋 Available Scripts

### Environment Management

```bash
npm run env:start          # Start test environment
npm run env:stop           # Stop test environment
npm run env:clean          # Clean up volumes and containers
npm run env:status         # Check service status
npm run env:logs           # View service logs
```

### Test Execution

```bash
npm run test:e2e           # Run all E2E tests
npm run test:e2e:ui        # Run with Playwright UI
npm run test:e2e:headed    # Run in headed mode
npm run test:e2e:debug     # Run in debug mode
npm run test:e2e:docker    # Run in Docker environment
```

### Analysis and Validation

```bash
npm run coverage:analyze   # Generate coverage analysis
npm run coverage:8020      # 80/20 coverage analysis
npm run performance:analyze # Performance analysis
npm run validation:8020    # Validate 80/20 coverage
npm run validation:thresholds # Validate performance thresholds
```

### Monitoring

```bash
npm run monitoring:start   # Start monitoring stack
npm run monitoring:dashboard # Open Grafana dashboard
npm run telemetry:traces   # Open Jaeger traces
```

## 🔍 Troubleshooting

### Common Issues

1. **Services not starting**: Check Docker resources and port conflicts
2. **Test timeouts**: Increase timeout values in configuration
3. **Memory issues**: Adjust Docker memory limits
4. **Database connection**: Verify PostgreSQL is running and accessible

### Debug Commands

```bash
# Check service health
docker-compose ps
docker-compose logs [service-name]

# Verify network connectivity
curl http://localhost:3000/health
curl http://localhost:9090/-/healthy

# Check database connection
docker-compose exec postgres psql -U reactor_user -d reactor_e2e -c "SELECT 1;"
```

## 📊 Reporting

### Automated Reports

Tests generate comprehensive reports in `reports/`:

- `results.json`: Playwright test results
- `80-20-coverage-report.json`: Coverage analysis
- `performance-profile.json`: Performance profiling
- `80-20-validation-report.json`: Validation results
- `performance-validation-report.json`: Performance validation

### CI/CD Integration

The framework integrates with GitHub Actions for:

- Automated test execution on PR/push
- Performance regression detection
- 80/20 coverage validation
- Deployment readiness assessment

## 🎯 Best Practices

### Test Organization

1. **Critical 80% tests**: Focus on core user journeys and business logic
2. **Edge 20% tests**: Cover error conditions, stress scenarios, and edge cases
3. **Performance tests**: Validate response times, memory usage, and throughput
4. **Integration tests**: Verify external service interactions

### Performance Optimization

1. Use parallel test execution for faster feedback
2. Implement proper test data management
3. Monitor resource usage during tests
4. Cache test environments when possible

### Monitoring Strategy

1. Track key metrics continuously
2. Set up alerts for threshold violations
3. Analyze trends over time
4. Correlate test results with application metrics

## 🚀 Production Readiness

The E2E testing infrastructure validates production readiness through:

- **80/20 coverage validation**: Ensures critical paths are thoroughly tested
- **Performance threshold validation**: Confirms acceptable response times and resource usage
- **Stress testing**: Validates system behavior under load
- **Error recovery testing**: Ensures graceful handling of failures

Success criteria for production deployment:

- Critical 80% tests: 100% pass rate
- Edge 20% tests: >70% pass rate
- Overall 80/20 score: >80%
- Performance thresholds: All met
- Zero critical security vulnerabilities

## 📚 References

- [Playwright Documentation](https://playwright.dev/)
- [Docker Compose Guide](https://docs.docker.com/compose/)
- [Prometheus Configuration](https://prometheus.io/docs/prometheus/latest/configuration/)
- [Grafana Dashboard Setup](https://grafana.com/docs/grafana/latest/dashboards/)
- [OpenTelemetry Tracing](https://opentelemetry.io/docs/)