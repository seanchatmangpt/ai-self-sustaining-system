/**
 * Unit tests for Autonomous Worktree Deployment Reactor
 */

import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { ReactorEngine } from '../../core/reactor-engine';
import { 
  setupTestEnvironment,
  generateMockWorktreeConfigs,
  createAdvancedAssertions,
  TimeProvider,
  PlatformProvider,
  FileSystemProvider
} from './test-fixtures';

// Mock Autonomous Worktree Deployment Reactor with dependency injection
const createMockAutonomousWorktreeDeploymentReactor = (deps: {
  timeProvider: TimeProvider;
  platformProvider: PlatformProvider;
  fileSystemProvider: FileSystemProvider;
  apiMock: any;
}) => {
  const reactor = new ReactorEngine({
    id: `worktree_deployment_${deps.timeProvider.now()}`,
    timeout: 600000,
    maxConcurrency: 5
  });

  // Mock environment registry initialization
  const environmentRegistryInit = {
    name: 'environment-registry-init',
    description: 'Initialize environment registry with port allocation and coordination locks',
    
    async run(input: any, context: any) {
      try {
        const deploymentEnv = {
          registry: {},
          portAllocations: {},
          crossWorktreeLocks: {},
          sharedTelemetry: [],
          coordinationState: 'initializing'
        };
        
        // Allocate ports and prevent conflicts
        const usedPorts = new Set([4000, 4001, 4002]);
        let currentPort = 4003;
        
        for (const worktree of input.worktrees) {
          while (usedPorts.has(currentPort)) {
            currentPort++;
          }
          
          const allocatedPort = worktree.port || currentPort;
          usedPorts.add(allocatedPort);
          
          const worktreeConfig = {
            ...worktree,
            port: allocatedPort,
            healthCheckUrl: `http://localhost:${allocatedPort}/health`
          };
          
          deploymentEnv.registry[worktree.name] = worktreeConfig;
          deploymentEnv.portAllocations[allocatedPort] = worktree.name;
          
          const lockId = `lock_${worktree.name}_${deps.timeProvider.now()}`;
          deploymentEnv.crossWorktreeLocks[worktree.name] = lockId;
          
          currentPort++;
        }
        
        await deps.apiMock.$fetch('/api/worktree/environment-registry', {
          method: 'POST',
          body: {
            registry: deploymentEnv.registry,
            portAllocations: deploymentEnv.portAllocations,
            timestamp: deps.timeProvider.now(),
            coordinationId: context.id
          }
        });
        
        return { success: true, data: deploymentEnv };
      } catch (error) {
        return { success: false, error: error as Error };
      }
    }
  };

  // Mock git worktree creation
  const gitWorktreeCreation = {
    name: 'git-worktree-creation',
    description: 'Create git worktrees in parallel with branch isolation',
    dependencies: ['environment-registry-init'],
    
    async run(input: any, context: any) {
      try {
        const environment = context.results?.get('environment-registry-init')?.data;
        const worktreeConfigs = Object.values(environment.registry);
        
        const worktreeCreationPromises = worktreeConfigs.map(async (config: any) => {
          const worktreePath = `./worktrees/${config.name}`;
          
          const creationResult = await deps.apiMock.$fetch('/api/git/create-worktree', {
            method: 'POST',
            body: {
              name: config.name,
              branch: config.branch,
              path: worktreePath,
              type: config.type,
              port: config.port,
              traceId: context.traceId
            }
          });
          
          const validationResult = await deps.apiMock.$fetch('/api/git/validate-worktree', {
            method: 'POST',
            body: { path: worktreePath, expectedType: config.type }
          });
          
          return {
            name: config.name,
            path: worktreePath,
            config,
            creationResult,
            validationResult,
            status: validationResult.hasCorrectStructure ? 'created' : 'failed'
          };
        });
        
        const worktreeResults = await Promise.allSettled(worktreeCreationPromises);
        
        const successfulWorktrees = worktreeResults
          .filter(result => result.status === 'fulfilled')
          .map(result => (result as any).value)
          .filter(worktree => worktree.status === 'created');
        
        const failedWorktrees = worktreeResults
          .filter(result => result.status === 'rejected' || 
            (result.status === 'fulfilled' && (result as any).value.status === 'failed'));
        
        return { 
          success: true, 
          data: {
            successfulWorktrees,
            failedWorktrees,
            totalWorktrees: worktreeConfigs.length,
            successRate: successfulWorktrees.length / worktreeConfigs.length,
            worktreeDetails: successfulWorktrees
          }
        };
      } catch (error) {
        return { success: false, error: error as Error };
      }
    },
    
    async undo(result: any) {
      for (const worktree of result.successfulWorktrees) {
        await deps.apiMock.$fetch('/api/git/remove-worktree', {
          method: 'DELETE',
          body: { path: worktree.path }
        });
      }
    }
  };

  // Mock dependency resolution and installation
  const dependencyResolutionInstallation = {
    name: 'dependency-resolution-installation',
    description: 'Resolve and install dependencies across worktrees with coordination',
    dependencies: ['git-worktree-creation'],
    timeout: 180000,
    
    async run(input: any, context: any) {
      try {
        const worktreeResult = context.results?.get('git-worktree-creation')?.data;
        const environment = context.results?.get('environment-registry-init')?.data;
        
        // Mock dependency order resolution
        const installationOrder = resolveDependencyOrder(worktreeResult.successfulWorktrees);
        const installationResults = [];
        
        for (const batch of installationOrder) {
          const batchPromises = batch.map(async (worktree: any) => {
            const config = environment.registry[worktree.name];
            
            return deps.apiMock.$fetch('/api/worktree/install-dependencies', {
              method: 'POST',
              body: {
                path: worktree.path,
                command: getInstallCommand(config.type),
                environmentVariables: config.environmentVariables,
                timeout: 120000,
                traceId: context.traceId
              }
            });
          });
          
          const batchResults = await Promise.allSettled(batchPromises);
          installationResults.push(...batchResults);
        }
        
        const successfulInstallations = installationResults
          .filter(result => result.status === 'fulfilled')
          .map(result => (result as any).value);
        
        const failedInstallations = installationResults
          .filter(result => result.status === 'rejected');
        
        return { 
          success: true, 
          data: {
            installationOrder,
            successfulInstallations,
            failedInstallations,
            installationMetrics: calculateInstallationMetrics(successfulInstallations),
            dependencyGraph: buildDependencyGraph(worktreeResult.successfulWorktrees)
          }
        };
      } catch (error) {
        return { success: false, error: error as Error };
      }
    }
  };

  // Mock coordinated service startup
  const coordinatedServiceStartup = {
    name: 'coordinated-service-startup',
    description: 'Start services with coordinated health checks and port management',
    dependencies: ['dependency-resolution-installation'],
    timeout: 120000,
    
    async run(input: any, context: any) {
      try {
        const installationResult = context.results?.get('dependency-resolution-installation')?.data;
        const environment = context.results?.get('environment-registry-init')?.data;
        
        const startupResults = [];
        
        for (const batch of installationResult.installationOrder) {
          const startupPromises = batch.map(async (worktree: any) => {
            const config = environment.registry[worktree.name];
            
            return deps.apiMock.$fetch('/api/worktree/start-service', {
              method: 'POST',
              body: {
                path: worktree.path,
                command: getStartCommand(config.type),
                port: config.port,
                environmentVariables: {
                  ...config.environmentVariables,
                  PORT: config.port.toString(),
                  MIX_ENV: 'dev'
                },
                healthCheckUrl: config.healthCheckUrl,
                traceId: context.traceId
              }
            });
          });
          
          const batchResults = await Promise.allSettled(startupPromises);
          startupResults.push(...batchResults);
          
          // Mock health check wait
          await waitForBatchHealth(batchResults);
        }
        
        // Mock comprehensive health check
        const healthCheckResults = await performComprehensiveHealthCheck(environment);
        
        return { 
          success: true, 
          data: {
            startupResults,
            healthCheckResults,
            runningServices: healthCheckResults.healthyServices,
            failedServices: healthCheckResults.unhealthyServices,
            serviceMetrics: calculateServiceMetrics(healthCheckResults)
          }
        };
      } catch (error) {
        return { success: false, error: error as Error };
      }
    },
    
    async undo(result: any) {
      for (const service of result.runningServices || []) {
        await deps.apiMock.$fetch('/api/worktree/stop-service', {
          method: 'POST',
          body: { path: service.path, port: service.port }
        });
      }
    }
  };

  // Mock cross-worktree telemetry setup
  const crossWorktreeTelemetrySetup = {
    name: 'cross-worktree-telemetry-setup',
    description: 'Setup shared telemetry across all worktree environments',
    dependencies: ['coordinated-service-startup'],
    
    async run(input: any, context: any) {
      try {
        const serviceResult = context.results?.get('coordinated-service-startup')?.data;
        const environment = context.results?.get('environment-registry-init')?.data;
        
        const telemetryConfig = {
          traceId: context.traceId,
          correlationId: `worktree_deployment_${context.id}`,
          services: serviceResult.runningServices.map((service: any) => ({
            name: service.name,
            url: service.url,
            port: service.port,
            type: service.type
          })),
          sharedEndpoint: '/api/telemetry/shared',
          collectionInterval: 30000
        };
        
        const telemetrySetupResults = await Promise.all(
          serviceResult.runningServices.map((service: any) => 
            deps.apiMock.$fetch('/api/telemetry/setup-service', {
              method: 'POST',
              body: {
                serviceName: service.name,
                serviceUrl: service.url,
                telemetryConfig,
                traceId: context.traceId
              }
            })
          )
        );
        
        const aggregationSetup = await deps.apiMock.$fetch('/api/telemetry/initialize-aggregation', {
          method: 'POST',
          body: {
            config: telemetryConfig,
            traceId: context.traceId
          }
        });
        
        environment.sharedTelemetry = telemetrySetupResults;
        environment.coordinationState = 'running';
        
        return { 
          success: true, 
          data: {
            telemetryConfig,
            telemetrySetupResults,
            aggregationSetup,
            environment,
            telemetryEndpoints: telemetrySetupResults.map((r: any) => r.endpoint)
          }
        };
      } catch (error) {
        return { success: false, error: error as Error };
      }
    }
  };

  // Mock autonomous health monitoring
  const autonomousHealthMonitoring = {
    name: 'autonomous-health-monitoring',
    description: 'Setup autonomous health monitoring with auto-recovery',
    dependencies: ['cross-worktree-telemetry-setup'],
    
    async run(input: any, context: any) {
      try {
        const telemetryResult = context.results?.get('cross-worktree-telemetry-setup')?.data;
        const environment = telemetryResult.environment;
        
        const monitoringConfig = {
          services: Object.values(environment.registry),
          healthCheckInterval: 30000,
          failureThreshold: 3,
          autoRecovery: input.enableAutoRecovery !== false,
          alertingEndpoint: '/api/monitoring/alerts',
          dashboardUrl: 'http://localhost:3000/dashboard/worktrees'
        };
        
        const monitoringSetupResults = await Promise.all(
          monitoringConfig.services.map((service: any) => 
            deps.apiMock.$fetch('/api/monitoring/initialize-service', {
              method: 'POST',
              body: {
                service,
                config: monitoringConfig,
                traceId: context.traceId
              }
            })
          )
        );
        
        const coordinationMonitoring = await deps.apiMock.$fetch('/api/monitoring/setup-coordination', {
          method: 'POST',
          body: {
            environment,
            traceId: context.traceId
          }
        });
        
        const monitoringLoop = await deps.apiMock.$fetch('/api/monitoring/start-autonomous-loop', {
          method: 'POST',
          body: {
            config: monitoringConfig,
            traceId: context.traceId
          }
        });
        
        return { 
          success: true, 
          data: {
            monitoringConfig,
            monitoringSetupResults,
            coordinationMonitoring,
            monitoringLoop,
            monitoringDashboard: monitoringConfig.dashboardUrl,
            autonomousFeatures: {
              autoRecovery: monitoringConfig.autoRecovery,
              healthChecks: true,
              crossWorktreeCoordination: true,
              telemetryAggregation: true
            }
          }
        };
      } catch (error) {
        return { success: false, error: error as Error };
      }
    }
  };

  // Add steps to reactor
  reactor.addStep(environmentRegistryInit);
  reactor.addStep(gitWorktreeCreation);
  reactor.addStep(dependencyResolutionInstallation);
  reactor.addStep(coordinatedServiceStartup);
  reactor.addStep(crossWorktreeTelemetrySetup);
  reactor.addStep(autonomousHealthMonitoring);
  
  return reactor;
};

// Helper functions
function resolveDependencyOrder(worktrees: any[]): any[][] {
  // Simple topological sort for testing
  const noDeps = worktrees.filter(w => !w.config.dependencies || w.config.dependencies.length === 0);
  const withDeps = worktrees.filter(w => w.config.dependencies && w.config.dependencies.length > 0);
  
  return [noDeps, withDeps];
}

function getInstallCommand(type: string): string {
  const commands = {
    'phoenix': 'mix deps.get && npm install',
    'xavos': 'mix deps.get && mix ash.setup && npm install',
    'beamops': 'mix deps.get && docker-compose pull',
    'engineering-elixir-apps': 'mix deps.get'
  };
  return commands[type] || 'echo "No dependencies to install"';
}

function getStartCommand(type: string): string {
  const commands = {
    'phoenix': 'mix phx.server',
    'xavos': 'mix phx.server',
    'beamops': 'docker-compose up -d',
    'engineering-elixir-apps': 'mix run --no-halt'
  };
  return commands[type] || 'echo "Service started"';
}

function calculateInstallationMetrics(installations: any[]) {
  return {
    totalInstallations: installations.length,
    averageInstallTime: installations.reduce((sum, inst) => sum + (inst.duration || 30000), 0) / installations.length,
    successRate: installations.filter(inst => inst.success).length / installations.length,
    totalDependencies: installations.reduce((sum, inst) => sum + (inst.dependencyCount || 25), 0)
  };
}

function buildDependencyGraph(worktrees: any[]) {
  const graph = {};
  worktrees.forEach(worktree => {
    graph[worktree.name] = {
      dependencies: worktree.config.dependencies || [],
      dependents: worktrees
        .filter(w => (w.config.dependencies || []).includes(worktree.name))
        .map(w => w.name)
    };
  });
  return graph;
}

async function waitForBatchHealth(batchResults: any[]) {
  // Mock health check wait
  await new Promise(resolve => setTimeout(resolve, 100));
}

async function performComprehensiveHealthCheck(environment: any) {
  const healthChecks = Object.entries(environment.registry).map(([serviceName, config]: any) => ({
    service: serviceName,
    url: config.healthCheckUrl,
    port: config.port,
    status: 'healthy',
    response: { status: 'healthy', timestamp: Date.now() },
    responseTime: Date.now()
  }));
  
  return {
    healthyServices: healthChecks,
    unhealthyServices: [],
    totalServices: healthChecks.length,
    healthRate: 1.0
  };
}

function calculateServiceMetrics(healthCheckResults: any) {
  return {
    totalServices: healthCheckResults.totalServices,
    healthyServices: healthCheckResults.healthyServices.length,
    healthRate: healthCheckResults.healthRate,
    averageResponseTime: healthCheckResults.healthyServices
      .reduce((sum: number, service: any) => sum + (service.responseTime || 0), 0) / 
      healthCheckResults.healthyServices.length || 0
  };
}

describe('Autonomous Worktree Deployment Reactor', () => {
  let testEnv: ReturnType<typeof setupTestEnvironment>;
  let assertions: ReturnType<typeof createAdvancedAssertions>;

  beforeEach(() => {
    vi.useFakeTimers();
    testEnv = setupTestEnvironment();
    assertions = createAdvancedAssertions();
  });

  afterEach(() => {
    vi.useRealTimers();
    testEnv.cleanup();
  });

  describe('Environment Registry Initialization', () => {
    it('should initialize environment registry with port allocation', async () => {
      const reactor = createMockAutonomousWorktreeDeploymentReactor(testEnv);
      const worktrees = generateMockWorktreeConfigs(3);
      
      const result = await reactor.execute({ worktrees });
      
      assertions.expectSuccessfulResult(result);
      
      const registryResult = result.results.get('environment-registry-init');
      const environment = registryResult.data;
      
      expect(environment.coordinationState).toBe('initializing');
      expect(Object.keys(environment.registry)).toHaveLength(3);
      expect(Object.keys(environment.portAllocations)).toHaveLength(3);
      expect(Object.keys(environment.crossWorktreeLocks)).toHaveLength(3);
      
      // Verify port allocation
      const ports = Object.keys(environment.portAllocations).map(Number);
      expect(new Set(ports).size).toBe(ports.length); // All ports unique
      expect(Math.min(...ports)).toBeGreaterThanOrEqual(4000);
    });

    it('should handle port conflicts and allocate sequential ports', async () => {
      const reactor = createMockAutonomousWorktreeDeploymentReactor(testEnv);
      const worktrees = [
        { name: 'worktree-1', branch: 'main', type: 'phoenix', port: 4000 },
        { name: 'worktree-2', branch: 'dev', type: 'xavos', port: 4000 }, // Conflict
        { name: 'worktree-3', branch: 'test', type: 'beamops' } // No specified port
      ];
      
      const result = await reactor.execute({ worktrees });
      
      const registryResult = result.results.get('environment-registry-init');
      const portAllocations = registryResult.data.portAllocations;
      
      // Should resolve conflicts by allocating different ports
      const allocatedPorts = Object.keys(portAllocations).map(Number);
      expect(new Set(allocatedPorts).size).toBe(3);
      expect(allocatedPorts.includes(4000)).toBe(true);
      expect(allocatedPorts.some(port => port !== 4000)).toBe(true);
    });

    it('should create deterministic lock IDs', async () => {
      const reactor = createMockAutonomousWorktreeDeploymentReactor(testEnv);
      const worktrees = generateMockWorktreeConfigs(2);
      
      const result = await reactor.execute({ worktrees });
      
      const registryResult = result.results.get('environment-registry-init');
      const locks = registryResult.data.crossWorktreeLocks;
      
      Object.entries(locks).forEach(([worktreeName, lockId]) => {
        expect(lockId).toMatch(new RegExp(`^lock_${worktreeName}_\\d+$`));
      });
    });

    it('should persist environment registry via API', async () => {
      const reactor = createMockAutonomousWorktreeDeploymentReactor(testEnv);
      const worktrees = generateMockWorktreeConfigs(2);
      
      await reactor.execute({ worktrees });
      
      expect(testEnv.apiMock.$fetch).toHaveBeenCalledWith(
        '/api/worktree/environment-registry',
        expect.objectContaining({
          method: 'POST',
          body: expect.objectContaining({
            registry: expect.any(Object),
            portAllocations: expect.any(Object),
            timestamp: testEnv.timeProvider.now()
          })
        })
      );
    });
  });

  describe('Git Worktree Creation', () => {
    it('should create worktrees in parallel with validation', async () => {
      const reactor = createMockAutonomousWorktreeDeploymentReactor(testEnv);
      const worktrees = generateMockWorktreeConfigs(3);
      
      const result = await reactor.execute({ worktrees });
      
      assertions.expectSuccessfulResult(result);
      assertions.expectWorktreeDeployment(result, 3);
      
      const worktreeResult = result.results.get('git-worktree-creation');
      expect(worktreeResult.data.successRate).toBe(1.0);
      expect(worktreeResult.data.totalWorktrees).toBe(3);
      
      // Verify API calls for each worktree
      expect(testEnv.apiMock.$fetch).toHaveBeenCalledWith(
        '/api/git/create-worktree',
        expect.objectContaining({
          method: 'POST',
          body: expect.objectContaining({
            name: expect.any(String),
            branch: expect.any(String),
            path: expect.stringMatching(/^\.\/worktrees\//),
            type: expect.stringMatching(/^(phoenix|xavos|beamops|engineering-elixir-apps)$/)
          })
        })
      );
      
      expect(testEnv.apiMock.$fetch).toHaveBeenCalledWith(
        '/api/git/validate-worktree',
        expect.objectContaining({
          method: 'POST',
          body: expect.objectContaining({
            path: expect.stringMatching(/^\.\/worktrees\//),
            expectedType: expect.any(String)
          })
        })
      );
    });

    it('should handle worktree creation failures gracefully', async () => {
      // Mock one worktree creation failure
      let callCount = 0;
      testEnv.apiMock.$fetch.mockImplementation((url: string, options?: any) => {
        if (url.includes('create-worktree')) {
          callCount++;
          if (callCount === 2) {
            throw new Error('Git worktree creation failed');
          }
        }
        return testEnv.apiMock.$fetch.getMockImplementation()(url, options);
      });
      
      const reactor = createMockAutonomousWorktreeDeploymentReactor(testEnv);
      const worktrees = generateMockWorktreeConfigs(3);
      
      const result = await reactor.execute({ worktrees });
      
      const worktreeResult = result.results.get('git-worktree-creation');
      expect(worktreeResult.data.successfulWorktrees).toHaveLength(2);
      expect(worktreeResult.data.failedWorktrees).toHaveLength(1);
      expect(worktreeResult.data.successRate).toBeCloseTo(0.67, 1);
    });

    it('should validate worktree structure after creation', async () => {
      // Mock validation failure for one worktree
      testEnv.apiMock.$fetch.mockImplementation((url: string, options?: any) => {
        if (url.includes('validate-worktree')) {
          const path = options?.body?.path;
          if (path?.includes('worktree-2')) {
            return {
              exists: true,
              hasCorrectStructure: false, // Invalid structure
              path,
              branch: 'main',
              detectedType: 'unknown'
            };
          }
        }
        return testEnv.apiMock.$fetch.getMockImplementation()(url, options);
      });
      
      const reactor = createMockAutonomousWorktreeDeploymentReactor(testEnv);
      const worktrees = generateMockWorktreeConfigs(3);
      
      const result = await reactor.execute({ worktrees });
      
      const worktreeResult = result.results.get('git-worktree-creation');
      expect(worktreeResult.data.successfulWorktrees.length).toBeLessThan(3);
      expect(worktreeResult.data.successfulWorktrees.every((w: any) => w.status === 'created')).toBe(true);
    });

    it('should rollback created worktrees on failure', async () => {
      const reactor = createMockAutonomousWorktreeDeploymentReactor(testEnv);
      const worktrees = generateMockWorktreeConfigs(2);
      
      // Mock dependency installation failure
      testEnv.apiMock.$fetch.mockImplementation((url: string, options?: any) => {
        if (url.includes('install-dependencies')) {
          throw new Error('Dependency installation failed');
        }
        return testEnv.apiMock.$fetch.getMockImplementation()(url, options);
      });
      
      const result = await reactor.execute({ worktrees });
      
      expect(result.state).toBe('failed');
      
      // Verify rollback was called
      expect(testEnv.apiMock.$fetch).toHaveBeenCalledWith(
        '/api/git/remove-worktree',
        expect.objectContaining({
          method: 'DELETE',
          body: expect.objectContaining({
            path: expect.stringMatching(/^\.\/worktrees\//)
          })
        })
      );
    });
  });

  describe('Dependency Resolution and Installation', () => {
    it('should resolve dependency order correctly', async () => {
      const reactor = createMockAutonomousWorktreeDeploymentReactor(testEnv);
      const worktrees = [
        { name: 'base', branch: 'main', type: 'phoenix', dependencies: [] },
        { name: 'dependent', branch: 'main', type: 'xavos', dependencies: ['base'] }
      ];
      
      const result = await reactor.execute({ worktrees });
      
      const installationResult = result.results.get('dependency-resolution-installation');
      const installationOrder = installationResult.data.installationOrder;
      
      expect(installationOrder).toHaveLength(2); // Two batches
      expect(installationOrder[0].some((w: any) => w.name === 'base')).toBe(true);
      expect(installationOrder[1].some((w: any) => w.name === 'dependent')).toBe(true);
    });

    it('should install dependencies with correct commands', async () => {
      const reactor = createMockAutonomousWorktreeDeploymentReactor(testEnv);
      const worktrees = [
        { name: 'phoenix-app', branch: 'main', type: 'phoenix' },
        { name: 'xavos-app', branch: 'main', type: 'xavos' }
      ];
      
      const result = await reactor.execute({ worktrees });
      
      // Verify correct install commands were used
      expect(testEnv.apiMock.$fetch).toHaveBeenCalledWith(
        '/api/worktree/install-dependencies',
        expect.objectContaining({
          method: 'POST',
          body: expect.objectContaining({
            command: 'mix deps.get && npm install' // Phoenix command
          })
        })
      );
      
      expect(testEnv.apiMock.$fetch).toHaveBeenCalledWith(
        '/api/worktree/install-dependencies',
        expect.objectContaining({
          method: 'POST',
          body: expect.objectContaining({
            command: 'mix deps.get && mix ash.setup && npm install' // XAVOS command
          })
        })
      );
    });

    it('should calculate installation metrics', async () => {
      const reactor = createMockAutonomousWorktreeDeploymentReactor(testEnv);
      const worktrees = generateMockWorktreeConfigs(3);
      
      const result = await reactor.execute({ worktrees });
      
      const installationResult = result.results.get('dependency-resolution-installation');
      const metrics = installationResult.data.installationMetrics;
      
      expect(metrics.totalInstallations).toBe(3);
      expect(metrics.averageInstallTime).toBeGreaterThan(0);
      expect(metrics.successRate).toBeGreaterThan(0);
      expect(metrics.totalDependencies).toBeGreaterThan(0);
    });

    it('should build dependency graph correctly', async () => {
      const reactor = createMockAutonomousWorktreeDeploymentReactor(testEnv);
      const worktrees = [
        { name: 'base', branch: 'main', type: 'phoenix', dependencies: [] },
        { name: 'dependent', branch: 'main', type: 'xavos', dependencies: ['base'] }
      ];
      
      const result = await reactor.execute({ worktrees });
      
      const installationResult = result.results.get('dependency-resolution-installation');
      const graph = installationResult.data.dependencyGraph;
      
      expect(graph.base.dependencies).toEqual([]);
      expect(graph.base.dependents).toContain('dependent');
      expect(graph.dependent.dependencies).toContain('base');
      expect(graph.dependent.dependents).toEqual([]);
    });
  });

  describe('Coordinated Service Startup', () => {
    it('should start services with health check coordination', async () => {
      const reactor = createMockAutonomousWorktreeDeploymentReactor(testEnv);
      const worktrees = generateMockWorktreeConfigs(2);
      
      const result = await reactor.execute({ worktrees });
      
      const startupResult = result.results.get('coordinated-service-startup');
      expect(startupResult.data.runningServices.length).toBeGreaterThan(0);
      expect(startupResult.data.serviceMetrics.healthRate).toBe(1.0);
      
      // Verify start commands were called
      expect(testEnv.apiMock.$fetch).toHaveBeenCalledWith(
        '/api/worktree/start-service',
        expect.objectContaining({
          method: 'POST',
          body: expect.objectContaining({
            command: expect.stringMatching(/^(mix phx\.server|docker-compose up -d|mix run --no-halt)$/),
            port: expect.any(Number),
            environmentVariables: expect.objectContaining({
              PORT: expect.any(String),
              MIX_ENV: 'dev'
            })
          })
        })
      );
    });

    it('should perform comprehensive health checks', async () => {
      const reactor = createMockAutonomousWorktreeDeploymentReactor(testEnv);
      const worktrees = generateMockWorktreeConfigs(3);
      
      const result = await reactor.execute({ worktrees });
      
      const startupResult = result.results.get('coordinated-service-startup');
      const healthCheck = startupResult.data.healthCheckResults;
      
      expect(healthCheck.totalServices).toBe(3);
      expect(healthCheck.healthyServices).toHaveLength(3);
      expect(healthCheck.unhealthyServices).toHaveLength(0);
      expect(healthCheck.healthRate).toBe(1.0);
    });

    it('should handle service startup failures', async () => {
      // Mock one service startup failure
      let callCount = 0;
      testEnv.apiMock.$fetch.mockImplementation((url: string, options?: any) => {
        if (url.includes('start-service')) {
          callCount++;
          if (callCount === 1) {
            throw new Error('Service startup failed');
          }
        }
        return testEnv.apiMock.$fetch.getMockImplementation()(url, options);
      });
      
      const reactor = createMockAutonomousWorktreeDeploymentReactor(testEnv);
      const worktrees = generateMockWorktreeConfigs(3);
      
      const result = await reactor.execute({ worktrees });
      
      const startupResult = result.results.get('coordinated-service-startup');
      expect(startupResult.data.serviceMetrics.healthRate).toBeLessThan(1.0);
    });

    it('should stop services on rollback', async () => {
      const reactor = createMockAutonomousWorktreeDeploymentReactor(testEnv);
      const worktrees = generateMockWorktreeConfigs(2);
      
      // Mock telemetry setup failure
      testEnv.apiMock.$fetch.mockImplementation((url: string, options?: any) => {
        if (url.includes('telemetry/setup-service')) {
          throw new Error('Telemetry setup failed');
        }
        return testEnv.apiMock.$fetch.getMockImplementation()(url, options);
      });
      
      const result = await reactor.execute({ worktrees });
      
      expect(result.state).toBe('failed');
      
      // Verify service stop was called during rollback
      expect(testEnv.apiMock.$fetch).toHaveBeenCalledWith(
        '/api/worktree/stop-service',
        expect.objectContaining({
          method: 'POST',
          body: expect.objectContaining({
            port: expect.any(Number)
          })
        })
      );
    });
  });

  describe('Cross-Worktree Telemetry Setup', () => {
    it('should setup shared telemetry across services', async () => {
      const reactor = createMockAutonomousWorktreeDeploymentReactor(testEnv);
      const worktrees = generateMockWorktreeConfigs(3);
      
      const result = await reactor.execute({ worktrees });
      
      const telemetryResult = result.results.get('cross-worktree-telemetry-setup');
      const config = telemetryResult.data.telemetryConfig;
      
      expect(config.traceId).toBe(result.context.traceId);
      expect(config.correlationId).toMatch(/^worktree_deployment_/);
      expect(config.services).toHaveLength(3);
      expect(config.sharedEndpoint).toBe('/api/telemetry/shared');
      
      // Verify telemetry setup API calls
      expect(testEnv.apiMock.$fetch).toHaveBeenCalledWith(
        '/api/telemetry/setup-service',
        expect.objectContaining({
          method: 'POST',
          body: expect.objectContaining({
            serviceName: expect.any(String),
            telemetryConfig: config,
            traceId: result.context.traceId
          })
        })
      );
      
      expect(testEnv.apiMock.$fetch).toHaveBeenCalledWith(
        '/api/telemetry/initialize-aggregation',
        expect.objectContaining({
          method: 'POST',
          body: expect.objectContaining({
            config: config,
            traceId: result.context.traceId
          })
        })
      );
    });

    it('should update environment coordination state', async () => {
      const reactor = createMockAutonomousWorktreeDeploymentReactor(testEnv);
      const worktrees = generateMockWorktreeConfigs(2);
      
      const result = await reactor.execute({ worktrees });
      
      const telemetryResult = result.results.get('cross-worktree-telemetry-setup');
      expect(telemetryResult.data.environment.coordinationState).toBe('running');
      expect(telemetryResult.data.environment.sharedTelemetry).toHaveLength(2);
    });

    it('should provide telemetry endpoints for each service', async () => {
      const reactor = createMockAutonomousWorktreeDeploymentReactor(testEnv);
      const worktrees = generateMockWorktreeConfigs(2);
      
      const result = await reactor.execute({ worktrees });
      
      const telemetryResult = result.results.get('cross-worktree-telemetry-setup');
      expect(telemetryResult.data.telemetryEndpoints).toHaveLength(2);
      expect(telemetryResult.data.telemetryEndpoints.every((endpoint: any) => endpoint !== undefined)).toBe(true);
    });
  });

  describe('Autonomous Health Monitoring', () => {
    it('should setup comprehensive monitoring with auto-recovery', async () => {
      const reactor = createMockAutonomousWorktreeDeploymentReactor(testEnv);
      const worktrees = generateMockWorktreeConfigs(2);
      
      const result = await reactor.execute({ worktrees });
      
      const monitoringResult = result.results.get('autonomous-health-monitoring');
      const config = monitoringResult.data.monitoringConfig;
      
      expect(config.services).toHaveLength(2);
      expect(config.healthCheckInterval).toBe(30000);
      expect(config.failureThreshold).toBe(3);
      expect(config.autoRecovery).toBe(true);
      expect(config.dashboardUrl).toContain('dashboard/worktrees');
      
      // Verify monitoring setup API calls
      expect(testEnv.apiMock.$fetch).toHaveBeenCalledWith(
        '/api/monitoring/initialize-service',
        expect.objectContaining({
          method: 'POST',
          body: expect.objectContaining({
            service: expect.any(Object),
            config: config
          })
        })
      );
    });

    it('should enable autonomous features', async () => {
      const reactor = createMockAutonomousWorktreeDeploymentReactor(testEnv);
      const worktrees = generateMockWorktreeConfigs(1);
      
      const result = await reactor.execute({ worktrees });
      
      const monitoringResult = result.results.get('autonomous-health-monitoring');
      const features = monitoringResult.data.autonomousFeatures;
      
      expect(features.autoRecovery).toBe(true);
      expect(features.healthChecks).toBe(true);
      expect(features.crossWorktreeCoordination).toBe(true);
      expect(features.telemetryAggregation).toBe(true);
    });

    it('should start autonomous monitoring loop', async () => {
      const reactor = createMockAutonomousWorktreeDeploymentReactor(testEnv);
      const worktrees = generateMockWorktreeConfigs(1);
      
      const result = await reactor.execute({ worktrees });
      
      expect(testEnv.apiMock.$fetch).toHaveBeenCalledWith(
        '/api/monitoring/start-autonomous-loop',
        expect.objectContaining({
          method: 'POST',
          body: expect.objectContaining({
            config: expect.any(Object),
            traceId: result.context.traceId
          })
        })
      );
    });

    it('should respect auto-recovery configuration', async () => {
      const reactor = createMockAutonomousWorktreeDeploymentReactor(testEnv);
      const worktrees = generateMockWorktreeConfigs(1);
      
      const result = await reactor.execute({ 
        worktrees, 
        enableAutoRecovery: false 
      });
      
      const monitoringResult = result.results.get('autonomous-health-monitoring');
      expect(monitoringResult.data.monitoringConfig.autoRecovery).toBe(false);
      expect(monitoringResult.data.autonomousFeatures.autoRecovery).toBe(false);
    });
  });

  describe('Error Handling and Recovery', () => {
    it('should handle complete deployment failure gracefully', async () => {
      // Mock environment registry failure
      testEnv.apiMock.$fetch.mockImplementation((url: string) => {
        if (url.includes('environment-registry')) {
          throw new Error('Environment registry service unavailable');
        }
        return testEnv.apiMock.$fetch.getMockImplementation()(url);
      });
      
      const reactor = createMockAutonomousWorktreeDeploymentReactor(testEnv);
      const worktrees = generateMockWorktreeConfigs(2);
      
      const result = await reactor.execute({ worktrees });
      
      expect(result.state).toBe('failed');
      expect(result.errors[0].message).toBe('Environment registry service unavailable');
    });

    it('should handle partial deployment with graceful degradation', async () => {
      // Mock service startup failure for one service
      let startupCallCount = 0;
      testEnv.apiMock.$fetch.mockImplementation((url: string, options?: any) => {
        if (url.includes('start-service')) {
          startupCallCount++;
          if (startupCallCount === 1) {
            throw new Error('First service startup failed');
          }
        }
        return testEnv.apiMock.$fetch.getMockImplementation()(url, options);
      });
      
      const reactor = createMockAutonomousWorktreeDeploymentReactor(testEnv);
      const worktrees = generateMockWorktreeConfigs(3);
      
      const result = await reactor.execute({ worktrees });
      
      // Should continue with remaining services
      assertions.expectSuccessfulResult(result);
      
      const startupResult = result.results.get('coordinated-service-startup');
      expect(startupResult.data.serviceMetrics.healthRate).toBeLessThan(1.0);
      expect(startupResult.data.serviceMetrics.healthRate).toBeGreaterThan(0.5);
    });

    it('should perform comprehensive rollback on critical failures', async () => {
      const reactor = createMockAutonomousWorktreeDeploymentReactor(testEnv);
      const worktrees = generateMockWorktreeConfigs(2);
      
      // Mock critical failure in telemetry setup
      testEnv.apiMock.$fetch.mockImplementation((url: string, options?: any) => {
        if (url.includes('telemetry/initialize-aggregation')) {
          throw new Error('Critical telemetry failure');
        }
        return testEnv.apiMock.$fetch.getMockImplementation()(url, options);
      });
      
      const result = await reactor.execute({ worktrees });
      
      expect(result.state).toBe('failed');
      
      // Verify rollback operations
      expect(testEnv.apiMock.$fetch).toHaveBeenCalledWith(
        '/api/worktree/stop-service',
        expect.objectContaining({ method: 'POST' })
      );
      
      expect(testEnv.apiMock.$fetch).toHaveBeenCalledWith(
        '/api/git/remove-worktree',
        expect.objectContaining({ method: 'DELETE' })
      );
    });
  });

  describe('Performance and Scalability', () => {
    it('should handle large number of worktrees efficiently', async () => {
      const reactor = createMockAutonomousWorktreeDeploymentReactor(testEnv);
      const worktrees = generateMockWorktreeConfigs(10);
      
      const start = performance.now();
      const result = await reactor.execute({ worktrees });
      const duration = performance.now() - start;
      
      assertions.expectSuccessfulResult(result);
      assertions.expectWorktreeDeployment(result, 10);
      expect(duration).toBeLessThan(2000); // Should complete in under 2 seconds
    });

    it('should demonstrate parallel processing efficiency', async () => {
      const reactor = createMockAutonomousWorktreeDeploymentReactor(testEnv);
      const worktrees = generateMockWorktreeConfigs(5);
      
      const result = await reactor.execute({ worktrees });
      
      const worktreeResult = result.results.get('git-worktree-creation');
      expect(worktreeResult.data.successRate).toBe(1.0);
      
      // With parallel processing, all worktrees should be processed
      expect(worktreeResult.data.totalWorktrees).toBe(5);
      expect(worktreeResult.data.successfulWorktrees).toHaveLength(5);
    });

    it('should maintain performance with complex dependency graphs', async () => {
      const reactor = createMockAutonomousWorktreeDeploymentReactor(testEnv);
      const worktrees = [
        { name: 'base', branch: 'main', type: 'phoenix', dependencies: [] },
        { name: 'service-a', branch: 'main', type: 'xavos', dependencies: ['base'] },
        { name: 'service-b', branch: 'main', type: 'beamops', dependencies: ['base'] },
        { name: 'integration', branch: 'main', type: 'engineering-elixir-apps', dependencies: ['service-a', 'service-b'] }
      ];
      
      const start = performance.now();
      const result = await reactor.execute({ worktrees });
      const duration = performance.now() - start;
      
      assertions.expectSuccessfulResult(result);
      expect(duration).toBeLessThan(1500);
      
      const installationResult = result.results.get('dependency-resolution-installation');
      expect(installationResult.data.installationOrder.length).toBeGreaterThan(1); // Multiple batches
    });
  });

  describe('Integration and Coordination', () => {
    it('should maintain trace correlation across all operations', async () => {
      const reactor = createMockAutonomousWorktreeDeploymentReactor(testEnv);
      const worktrees = generateMockWorktreeConfigs(2);
      
      const result = await reactor.execute({ worktrees });
      
      // Verify trace ID is consistent across all steps
      const allResults = Array.from(result.results.values());
      const traceId = result.context.traceId;
      
      // Check API calls included trace ID
      const apiCalls = testEnv.apiMock.$fetch.mock.calls;
      const tracedCalls = apiCalls.filter(call => 
        call[1]?.body?.traceId === traceId
      );
      
      expect(tracedCalls.length).toBeGreaterThan(0);
    });

    it('should coordinate port allocation across all services', async () => {
      const reactor = createMockAutonomousWorktreeDeploymentReactor(testEnv);
      const worktrees = generateMockWorktreeConfigs(4);
      
      const result = await reactor.execute({ worktrees });
      
      const registryResult = result.results.get('environment-registry-init');
      const portAllocations = registryResult.data.portAllocations;
      
      const ports = Object.keys(portAllocations).map(Number);
      expect(new Set(ports).size).toBe(ports.length); // All unique
      expect(ports.every(port => port >= 4000)).toBe(true);
    });

    it('should provide comprehensive deployment metrics', async () => {
      const reactor = createMockAutonomousWorktreeDeploymentReactor(testEnv);
      const worktrees = generateMockWorktreeConfigs(3);
      
      const result = await reactor.execute({ worktrees });
      
      // Verify metrics are available at each stage
      const worktreeResult = result.results.get('git-worktree-creation');
      expect(worktreeResult.data.successRate).toBeDefined();
      
      const installationResult = result.results.get('dependency-resolution-installation');
      expect(installationResult.data.installationMetrics).toBeDefined();
      
      const startupResult = result.results.get('coordinated-service-startup');
      expect(startupResult.data.serviceMetrics).toBeDefined();
      
      const monitoringResult = result.results.get('autonomous-health-monitoring');
      expect(monitoringResult.data.monitoringConfig).toBeDefined();
    });
  });
});