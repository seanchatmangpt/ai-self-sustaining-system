import { defineConfig, devices } from '@playwright/test';
import { config } from 'dotenv';

// Load environment variables
config();

/**
 * Playwright E2E Configuration for Nuxt Reactor
 * Optimized for 80/20 coverage analysis and performance testing
 */
export default defineConfig({
  // Test directory structure
  testDir: './tests',
  
  // Output directories
  outputDir: './test-results',
  
  // Run tests in files in parallel
  fullyParallel: true,
  
  // Fail the build on CI if you accidentally left test.only in the source code
  forbidOnly: !!process.env.CI,
  
  // Retry on CI only
  retries: process.env.CI ? 2 : 0,
  
  // Opt out of parallel tests on CI
  workers: process.env.CI ? 1 : undefined,
  
  // Reporter configuration for comprehensive analysis
  reporter: [
    ['html', { outputFolder: 'reports/html', open: 'never' }],
    ['json', { outputFile: 'reports/results.json' }],
    ['junit', { outputFile: 'reports/junit.xml' }],
    ['line'],
    ['./reporters/80-20-reporter.ts'],
    ['./reporters/performance-reporter.ts'],
    ['./reporters/telemetry-reporter.ts']
  ],
  
  // Global setup and teardown
  globalSetup: require.resolve('./global-setup.ts'),
  globalTeardown: require.resolve('./global-teardown.ts'),
  
  // Shared settings for all tests
  use: {
    // Base URL for testing
    baseURL: process.env.BASE_URL || 'http://localhost:3000',
    
    // Collect trace on retry
    trace: 'on-first-retry',
    
    // Take screenshot on failure
    screenshot: 'only-on-failure',
    
    // Record video on retry
    video: 'retain-on-failure',
    
    // Custom test timeout
    actionTimeout: 30000,
    navigationTimeout: 30000,
    
    // Extra HTTP headers
    extraHTTPHeaders: {
      'X-Test-Suite': 'reactor-e2e',
      'X-Test-Environment': 'docker',
      'X-Coverage-Mode': '80-20'
    },
    
    // Custom user agent
    userAgent: 'Reactor-E2E-Playwright/1.0'
  },
  
  // Test timeout
  timeout: 60000,
  
  // Expect timeout
  expect: {
    timeout: 10000,
    toHaveScreenshot: { threshold: 0.3 },
    toMatchScreenshot: { threshold: 0.3 }
  },
  
  // Projects for different test categories
  projects: [
    // Critical 80% - Core functionality tests
    {
      name: 'critical-80-chrome',
      use: { 
        ...devices['Desktop Chrome'],
        channel: 'chrome'
      },
      testMatch: /.*critical.*\.spec\.ts/,
      metadata: {
        coverage: 'critical-80',
        priority: 'high',
        category: 'functional'
      }
    },
    
    // Critical 80% - Performance tests
    {
      name: 'critical-80-performance',
      use: { 
        ...devices['Desktop Chrome'],
        channel: 'chrome'
      },
      testMatch: /.*performance.*\.spec\.ts/,
      metadata: {
        coverage: 'critical-80',
        priority: 'high',
        category: 'performance'
      }
    },
    
    // Edge 20% - Stress and failure tests
    {
      name: 'edge-20-stress',
      use: { 
        ...devices['Desktop Chrome'],
        channel: 'chrome'
      },
      testMatch: /.*stress.*\.spec\.ts/,
      retries: 3,
      metadata: {
        coverage: 'edge-20',
        priority: 'medium',
        category: 'stress'
      }
    },
    
    // Edge 20% - Browser compatibility
    {
      name: 'edge-20-firefox',
      use: { ...devices['Desktop Firefox'] },
      testMatch: /.*compatibility.*\.spec\.ts/,
      metadata: {
        coverage: 'edge-20',
        priority: 'medium',
        category: 'compatibility'
      }
    },
    
    // Edge 20% - Mobile testing
    {
      name: 'edge-20-mobile',
      use: { ...devices['Pixel 5'] },
      testMatch: /.*mobile.*\.spec\.ts/,
      metadata: {
        coverage: 'edge-20',
        priority: 'low',
        category: 'mobile'
      }
    },
    
    // API testing
    {
      name: 'api-tests',
      testMatch: /.*api.*\.spec\.ts/,
      use: {
        baseURL: process.env.BASE_URL || 'http://localhost:3000'
      },
      metadata: {
        coverage: 'critical-80',
        priority: 'high',
        category: 'api'
      }
    }
  ],
  
  // Web server configuration
  webServer: process.env.CI ? undefined : {
    command: 'npm run dev',
    port: 3000,
    cwd: '../playground',
    reuseExistingServer: !process.env.CI,
    env: {
      NODE_ENV: 'test',
      NITRO_PORT: '3000'
    }
  }
});