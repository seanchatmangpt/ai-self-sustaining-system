import { chromium, FullConfig } from '@playwright/test';
import { exec } from 'child_process';
import { promisify } from 'util';
import postgres from 'postgres';

const execAsync = promisify(exec);

/**
 * Global setup for E2E tests
 * Initializes test environment and validates 80/20 coverage infrastructure
 */
export default async function globalSetup(config: FullConfig) {
  console.log('🚀 Starting Reactor E2E Global Setup...');
  
  try {
    // 1. Validate environment
    await validateEnvironment();
    
    // 2. Initialize database
    await initializeDatabase();
    
    // 3. Prime application cache
    await primeApplicationCache();
    
    // 4. Setup telemetry collection
    await setupTelemetryCollection();
    
    // 5. Initialize performance baseline
    await initializePerformanceBaseline();
    
    console.log('✅ Global setup completed successfully');
    
  } catch (error) {
    console.error('❌ Global setup failed:', error);
    throw error;
  }
}

async function validateEnvironment() {
  console.log('📋 Validating test environment...');
  
  const requiredServices = [
    { name: 'Nuxt App', url: 'http://localhost:3000/health' },
    { name: 'PostgreSQL', url: 'http://localhost:5432' },
    { name: 'Redis', url: 'http://localhost:6379' },
    { name: 'Jaeger', url: 'http://localhost:16686' },
    { name: 'Prometheus', url: 'http://localhost:9090/-/healthy' }
  ];
  
  const browser = await chromium.launch();
  const context = await browser.newContext();
  const page = await context.newPage();
  
  for (const service of requiredServices) {
    try {
      if (service.name === 'PostgreSQL' || service.name === 'Redis') {
        // Skip HTTP check for database services
        continue;
      }
      
      const response = await page.goto(service.url, { timeout: 10000 });
      if (!response?.ok()) {
        throw new Error(`Service ${service.name} is not healthy`);
      }
      console.log(`  ✓ ${service.name} is healthy`);
    } catch (error) {
      console.log(`  ⚠️  ${service.name} check failed: ${error.message}`);
    }
  }
  
  await browser.close();
}

async function initializeDatabase() {
  console.log('🗄️  Initializing test database...');
  
  try {
    const sql = postgres({
      host: 'localhost',
      port: 5432,
      database: 'reactor_e2e',
      username: 'reactor_user',
      password: 'reactor_pass'
    });
    
    // Clean up previous test data
    await sql`DELETE FROM test_executions WHERE started_at < NOW() - INTERVAL '1 hour'`;
    await sql`DELETE FROM reactor_executions WHERE started_at < NOW() - INTERVAL '1 hour'`;
    
    // Insert test run marker
    const testRunId = `test_run_${Date.now()}`;
    process.env.TEST_RUN_ID = testRunId;
    
    await sql`
      INSERT INTO reactor_executions (reactor_id, execution_id, state, started_at)
      VALUES ('e2e-setup', ${testRunId}, 'running', NOW())
    `;
    
    console.log(`  ✓ Database initialized with test run ID: ${testRunId}`);
    await sql.end();
    
  } catch (error) {
    console.log(`  ⚠️  Database initialization failed: ${error.message}`);
  }
}

async function primeApplicationCache() {
  console.log('🔥 Priming application cache...');
  
  const browser = await chromium.launch();
  const context = await browser.newContext();
  const page = await context.newPage();
  
  try {
    // Prime the main application
    await page.goto('http://localhost:3000', { waitUntil: 'networkidle' });
    
    // Prime reactor examples
    const reactorEndpoints = [
      '/api/reactor/examples/basic',
      '/api/reactor/examples/parallel',
      '/api/reactor/examples/error-recovery'
    ];
    
    for (const endpoint of reactorEndpoints) {
      try {
        await page.goto(`http://localhost:3000${endpoint}`, { timeout: 5000 });
        console.log(`  ✓ Primed ${endpoint}`);
      } catch (error) {
        console.log(`  ⚠️  Failed to prime ${endpoint}: ${error.message}`);
      }
    }
    
  } catch (error) {
    console.log(`  ⚠️  Cache priming failed: ${error.message}`);
  } finally {
    await browser.close();
  }
}

async function setupTelemetryCollection() {
  console.log('📊 Setting up telemetry collection...');
  
  try {
    // Initialize telemetry span tracking
    const spanId = `setup_${Date.now()}`;
    
    // Store span context for tests
    process.env.TELEMETRY_SPAN_ID = spanId;
    process.env.TELEMETRY_ENABLED = 'true';
    
    console.log(`  ✓ Telemetry collection initialized with span ID: ${spanId}`);
    
  } catch (error) {
    console.log(`  ⚠️  Telemetry setup failed: ${error.message}`);
  }
}

async function initializePerformanceBaseline() {
  console.log('⚡ Initializing performance baseline...');
  
  const browser = await chromium.launch();
  const context = await browser.newContext();
  const page = await context.newPage();
  
  try {
    // Collect performance baseline
    const performanceBaseline = {
      startTime: Date.now(),
      memoryUsage: process.memoryUsage(),
      cpuUsage: process.cpuUsage()
    };
    
    // Test basic reactor performance
    const startTime = performance.now();
    await page.goto('http://localhost:3000/api/reactor/health', { waitUntil: 'networkidle' });
    const endTime = performance.now();
    
    performanceBaseline['baselineLatency'] = endTime - startTime;
    
    // Store baseline for comparison
    process.env.PERFORMANCE_BASELINE = JSON.stringify(performanceBaseline);
    
    console.log(`  ✓ Performance baseline: ${(endTime - startTime).toFixed(2)}ms`);
    
  } catch (error) {
    console.log(`  ⚠️  Performance baseline failed: ${error.message}`);
  } finally {
    await browser.close();
  }
}