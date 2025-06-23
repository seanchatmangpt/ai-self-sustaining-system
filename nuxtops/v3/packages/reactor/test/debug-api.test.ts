/**
 * Debug test to check API mocking
 */

import { describe, it, expect, vi, beforeEach } from 'vitest';
import { setupTestEnvironment } from './advanced/test-fixtures';

describe('Debug API Mock', () => {
  let testEnv: ReturnType<typeof setupTestEnvironment>;

  beforeEach(() => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date('2022-01-01'));
    testEnv = setupTestEnvironment();
  });

  afterEach(() => {
    vi.useRealTimers();
    testEnv.cleanup();
  });

  it('should mock API calls correctly', async () => {
    // Test direct API mock call
    const response = await testEnv.apiMock.$fetch('/api/claude/analyze-priorities', {
      method: 'POST',
      body: { test: 'data' }
    });

    console.log('API Response:', response);
    expect(response).toBeDefined();
    expect(response.priorities).toBeDefined();
  });

  it('should mock global $fetch', async () => {
    // Test that global.$fetch is set up
    expect(global.$fetch).toBeDefined();
    expect(typeof global.$fetch).toBe('function');
    
    const response = await global.$fetch('/api/claude/analyze-priorities', {
      method: 'POST',
      body: { test: 'data' }
    });

    console.log('Global $fetch Response:', response);
    expect(response).toBeDefined();
  });
});