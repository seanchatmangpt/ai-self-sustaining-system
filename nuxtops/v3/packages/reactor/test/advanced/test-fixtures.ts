/**
 * Test fixtures and utilities for advanced reactor scenarios
 */

import { vi } from 'vitest';

// Time and randomness providers for deterministic testing
export interface TimeProvider {
  now(): number;
  random(): number;
  hrtime(): bigint;
}

export const createMockTimeProvider = (baseTime = 1640995200000): TimeProvider => ({
  now: vi.fn(() => baseTime),
  random: vi.fn(() => 0.5),
  hrtime: vi.fn(() => BigInt('123456789'))
});

// Platform abstraction for Node.js/browser compatibility
export interface PlatformProvider {
  getHighResolutionTime(): bigint;
  getProcessEnv(): Record<string, string>;
}

export const createMockPlatformProvider = (): PlatformProvider => ({
  getHighResolutionTime: vi.fn(() => BigInt('123456789')),
  getProcessEnv: vi.fn(() => ({ NODE_ENV: 'test' }))
});

// Browser API abstraction
export interface BrowserProvider {
  pushEvent?(event: string, data: any): void;
  hasLiveSocket(): boolean;
  hasVueApp(): boolean;
}

export const createMockBrowserProvider = (): BrowserProvider => ({
  pushEvent: vi.fn(),
  hasLiveSocket: vi.fn(() => false),
  hasVueApp: vi.fn(() => false)
});

// File system abstraction
export interface FileSystemProvider {
  createTempPath(prefix: string, extension: string): string;
  validatePath(path: string): Promise<boolean>;
  writeTempFile(path: string, content: string): Promise<void>;
}

export const createMockFileSystemProvider = (): FileSystemProvider => ({
  createTempPath: vi.fn((prefix, ext) => `/mock/temp/${prefix}_123.${ext}`),
  validatePath: vi.fn(() => Promise.resolve(true)),
  writeTempFile: vi.fn(() => Promise.resolve())
});

// Comprehensive API mock factory
export const createAPICallMock = (scenario: string) => {
  const mockResponses: Record<string, any> = {
    // Claude AI responses
    '/api/claude/analyze-priorities': {
      priorities: [
        { id: 'task1', priority: 'high', estimatedDuration: 1000 },
        { id: 'task2', priority: 'medium', estimatedDuration: 2000 }
      ],
      confidence: 0.85,
      reasoning: 'Mock AI analysis',
      recommended_agents: 3
    },
    
    // Coordination responses
    '/api/coordination/register-agent': { success: true, registered: true },
    '/api/coordination/deregister-agent': { success: true, deregistered: true },
    '/api/coordination/claim-work': { success: true, claimed: true },
    '/api/coordination/log-entry': { success: true, logged: true },
    
    // Agent execution responses
    '/api/agents/execute-task': { 
      success: true, 
      duration: 1500,
      result: 'Task completed successfully'
    },
    
    // Telemetry responses
    '/api/telemetry/collect-spans': {
      spans: [
        { operationName: 'step.test', duration: 100, status: 'ok' },
        { operationName: 'step.another', duration: 200, status: 'ok' }
      ],
      totalSpans: 2
    },
    '/api/telemetry/register-trace': { success: true, registered: true },
    '/api/telemetry/correlate-cross-system': {
      spans: [],
      correlationData: { systems: ['reactor', 'phoenix', 'n8n'] }
    },
    
    // Phoenix system responses
    'http://localhost:4000/api/reactor/execute': {
      success: true,
      liveview_updates: ['update1', 'update2'],
      context: { system: 'phoenix' }
    },
    
    // N8n workflow responses
    'http://localhost:5678/webhook/reactor-integration': {
      execution_id: 'exec_123',
      status: 'completed',
      result: { processed: true }
    },
    
    // XAVOS system responses
    'http://localhost:4002/api/coordination/execute': {
      success: true,
      ash_operations: ['op1', 'op2'],
      coordination_metrics: { efficiency: 0.95 }
    },
    
    // Health check responses
    '/health': { status: 'healthy', timestamp: Date.now() },
    
    // Worktree responses
    '/api/worktree/environment-registry': { success: true, registered: true },
    '/api/git/create-worktree': { success: true, path: '/mock/worktree' },
    '/api/git/validate-worktree': { 
      exists: true, 
      hasCorrectStructure: true,
      path: '/mock/worktree',
      branch: 'main',
      detectedType: 'phoenix'
    },
    '/api/worktree/install-dependencies': {
      success: true,
      duration: 30000,
      dependencyCount: 25
    },
    '/api/worktree/start-service': {
      started: true,
      port: 4000,
      healthCheckUrl: 'http://localhost:4000/health'
    },
    
    // Dashboard responses
    '/api/dashboard/broadcast-update': { success: true, broadcasted: true },
    '/api/dashboard/subscriber-count': { count: 5 }
  };
  
  return {
    $fetch: vi.fn().mockImplementation(async (url: string, options?: any) => {
      // Handle URL patterns
      for (const [pattern, response] of Object.entries(mockResponses)) {
        if (url.includes(pattern) || url === pattern) {
          return response;
        }
      }
      
      // Handle dynamic URLs with patterns
      if (url.includes('/health')) {
        return { status: 'healthy', timestamp: Date.now() };
      }
      
      if (url.includes('/api/coordination/deregister-agent/')) {
        return { success: true, deregistered: true };
      }
      
      if (url.includes('/api/dashboard/subscriber-count/')) {
        return { count: Math.floor(Math.random() * 10) + 1 };
      }
      
      // Default response for unknown URLs
      console.warn(`Mock API call to unknown URL: ${url}`);
      return { success: true, mock: true, url };
    })
  };
};

// Async test utilities
export const createAsyncTestUtils = () => ({
  // Mock Promise.allSettled with controllable results
  mockPromiseAllSettled: (results: any[]) => {
    return results.map((result, index) => ({
      status: result.success !== false ? 'fulfilled' : 'rejected',
      value: result.success !== false ? result : undefined,
      reason: result.success === false ? new Error(`Mock error ${index}`) : undefined
    }));
  },
  
  // Mock health check with configurable behavior
  mockHealthCheck: (healthy: boolean, delay: number = 0) => {
    return vi.fn().mockImplementation(() => 
      new Promise(resolve => 
        setTimeout(() => resolve({ 
          status: healthy ? 'healthy' : 'unhealthy',
          timestamp: Date.now()
        }), delay)
      )
    );
  },
  
  // Deterministic delay function
  deterministicDelay: (ms: number) => {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
});

// Mock data generators
export const generateMockSwarmTasks = (count: number = 3) => {
  return Array.from({ length: count }, (_, i) => ({
    id: `task-${i + 1}`,
    type: ['analysis', 'optimization', 'coordination', 'validation'][i % 4],
    priority: ['high', 'medium', 'low'][i % 3],
    payload: { data: `Mock task ${i + 1} data` },
    dependencies: i > 0 ? [`task-${i}`] : [],
    estimatedDuration: (i + 1) * 1000
  }));
};

export const generateMockWorktreeConfigs = (count: number = 2) => {
  const types = ['phoenix', 'xavos', 'beamops', 'engineering-elixir-apps'];
  
  return Array.from({ length: count }, (_, i) => ({
    name: `worktree-${i + 1}`,
    branch: i === 0 ? 'main' : 'development',
    type: types[i % types.length] as any,
    port: 4000 + i,
    dependencies: i > 0 ? [`worktree-${i}`] : [],
    environmentVariables: {
      MIX_ENV: 'test',
      PORT: (4000 + i).toString()
    },
    healthCheckUrl: `http://localhost:${4000 + i}/health`
  }));
};

export const generateMockSPRContent = () => ({
  content: `
    # Technical Documentation
    
    This is a comprehensive technical document that demonstrates various concepts
    including algorithms, implementation details, and system architecture patterns.
    
    The content includes function definitions, code examples, and detailed explanations
    of complex technical processes that would benefit from SPR compression.
    
    Key concepts covered:
    - Algorithm implementation
    - System design patterns
    - Performance optimization
    - Error handling strategies
  `,
  type: 'technical' as const,
  targetRatio: 0.3
});

// Test environment setup
export const setupTestEnvironment = () => {
  const timeProvider = createMockTimeProvider();
  const platformProvider = createMockPlatformProvider();
  const browserProvider = createMockBrowserProvider();
  const fileSystemProvider = createMockFileSystemProvider();
  const apiMock = createAPICallMock('test');
  const asyncUtils = createAsyncTestUtils();
  
  // Setup global mocks
  global.$fetch = apiMock.$fetch;
  
  // Mock browser objects
  Object.defineProperty(window, 'liveSocket', {
    value: { pushEvent: vi.fn() },
    writable: true
  });
  
  Object.defineProperty(window, 'vueApp', {
    value: { $emit: vi.fn() },
    writable: true
  });
  
  return {
    timeProvider,
    platformProvider,
    browserProvider,
    fileSystemProvider,
    apiMock,
    asyncUtils,
    cleanup: () => {
      vi.clearAllMocks();
      try {
        if (typeof window !== 'undefined') {
          if ('liveSocket' in window) delete (window as any).liveSocket;
          if ('vueApp' in window) delete (window as any).vueApp;
        }
        if (typeof global !== 'undefined' && '$fetch' in global) {
          delete (global as any).$fetch;
        }
      } catch (error) {
        // Ignore cleanup errors in test environment
      }
    }
  };
};

// Performance test utilities
export const createPerformanceTestUtils = () => ({
  measureExecutionTime: async (fn: () => Promise<any>) => {
    const start = performance.now();
    const result = await fn();
    const end = performance.now();
    
    return {
      result,
      duration: end - start,
      start,
      end
    };
  },
  
  simulateSlowOperation: (baseDelay: number, variance: number = 0) => {
    const delay = baseDelay + (Math.random() - 0.5) * variance;
    return new Promise(resolve => setTimeout(resolve, delay));
  }
});

// Assertion helpers for advanced scenarios
export const createAdvancedAssertions = () => ({
  expectSuccessfulResult: (result: any) => {
    expect(result.state).toBe('completed');
    expect(result.results).toBeDefined();
    expect(result.errors).toHaveLength(0);
  },
  
  expectTraceCorrelation: (result: any, expectedTraceId: string) => {
    expect(result.data.traceContext?.traceId).toBe(expectedTraceId);
    expect(result.data.traceContext?.correlationId).toBeDefined();
  },
  
  expectAgentCoordination: (result: any, expectedAgentCount: number) => {
    const formationResult = result.results.get('agent-formation');
    expect(formationResult).toBeDefined();
    expect(formationResult.success).toBe(true);
    expect(formationResult.data.agents).toHaveLength(expectedAgentCount);
    expect(formationResult.data.agents.every((agent: any) => agent.id.startsWith('agent_'))).toBe(true);
  },
  
  expectWorktreeDeployment: (result: any, expectedWorktreeCount: number) => {
    expect(result.data.successfulWorktrees).toHaveLength(expectedWorktreeCount);
    expect(result.data.successRate).toBeGreaterThan(0.8);
  },
  
  expectSPROptimization: (result: any, minQuality: number = 0.7) => {
    expect(result.data.optimal?.quality).toBeGreaterThanOrEqual(minQuality);
    expect(result.data.optimal?.ratio).toBeGreaterThan(0);
    expect(result.data.optimal?.ratio).toBeLessThan(1);
  }
});