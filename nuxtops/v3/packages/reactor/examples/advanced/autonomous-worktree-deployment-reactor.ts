/**
 * Autonomous Worktree Deployment Reactor
 * Advanced scenario based on multi-worktree coordination and XAVOS deployment patterns
 * Implements intelligent environment management with port allocation and cross-worktree coordination
 */

import { ReactorEngine } from '../../core/reactor-engine';
import { TelemetryMiddleware } from '../../middleware/telemetry-middleware';
import { CoordinationMiddleware } from '../../middleware/coordination-middleware';
import type { ReactorStep } from '../../types';

interface WorktreeConfig {
  name: string;
  branch: string;
  type: 'phoenix' | 'xavos' | 'beamops' | 'engineering-elixir-apps';
  port: number;
  dependencies: string[];
  environmentVariables: Record<string, string>;
  healthCheckUrl: string;
}

interface DeploymentEnvironment {
  registry: Record<string, WorktreeConfig>;
  portAllocations: Record<number, string>;
  crossWorktreeLocks: Record<string, string>;
  sharedTelemetry: any[];
  coordinationState: 'initializing' | 'deploying' | 'running' | 'failed';
}

interface DeploymentStrategy {
  parallelDeployment: boolean;
  healthCheckTimeout: number;
  rollbackOnFailure: boolean;
  crossWorktreeCoordination: boolean;
}

// Step 1: Environment Registry Initialization (based on environment_registry.json)
const environmentRegistryInit: ReactorStep<{ worktrees: WorktreeConfig[] }, DeploymentEnvironment> = {
  name: 'environment-registry-init',
  description: 'Initialize environment registry with port allocation and coordination locks',
  
  async run(input, context) {
    try {
      // Initialize environment registry following shared/environment_registry.json patterns
      const deploymentEnv: DeploymentEnvironment = {
        registry: {},
        portAllocations: {},
        crossWorktreeLocks: {},
        sharedTelemetry: [],
        coordinationState: 'initializing'
      };
      
      // Allocate ports and prevent conflicts
      const usedPorts = new Set([4000, 4001, 4002]); // Reserve known ports
      let currentPort = 4003;
      
      for (const worktree of input.worktrees) {
        // Find next available port
        while (usedPorts.has(currentPort)) {
          currentPort++;
        }
        
        const allocatedPort = worktree.port || currentPort;
        usedPorts.add(allocatedPort);
        
        // Register worktree in environment registry
        const worktreeConfig: WorktreeConfig = {
          ...worktree,
          port: allocatedPort,
          healthCheckUrl: `http://localhost:${allocatedPort}/health`
        };
        
        deploymentEnv.registry[worktree.name] = worktreeConfig;
        deploymentEnv.portAllocations[allocatedPort] = worktree.name;
        
        // Initialize cross-worktree lock
        const lockId = `lock_${worktree.name}_${Date.now()}`;
        deploymentEnv.crossWorktreeLocks[worktree.name] = lockId;
        
        currentPort++;
      }
      
      // Persist environment registry
      await $fetch('/api/worktree/environment-registry', {
        method: 'POST',
        body: {
          registry: deploymentEnv.registry,
          portAllocations: deploymentEnv.portAllocations,
          timestamp: Date.now(),
          coordinationId: context.id
        }
      });
      
      return { 
        success: true, 
        data: deploymentEnv
      };
      
    } catch (error) {
      return { success: false, error: error as Error };
    }
  }
};

// Step 2: Git Worktree Creation (parallel worktree setup)
const gitWorktreeCreation: ReactorStep<any, any> = {
  name: 'git-worktree-creation',
  description: 'Create git worktrees in parallel with branch isolation',
  dependencies: ['environment-registry-init'],
  
  async run(input, context) {
    try {
      const environment = context.results?.get('environment-registry-init')?.data;
      const worktreeConfigs = Object.values(environment.registry);
      
      // Create worktrees in parallel
      const worktreeCreationPromises = worktreeConfigs.map(async (config) => {
        const worktreePath = `./worktrees/${config.name}`;
        
        // Create git worktree following create_ash_phoenix_worktree.sh patterns
        const creationResult = await $fetch('/api/git/create-worktree', {
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
        
        // Validate worktree creation
        const validationResult = await validateWorktreeCreation(worktreePath, config);
        
        return {
          name: config.name,
          path: worktreePath,
          config,
          creationResult,
          validationResult,
          status: validationResult.valid ? 'created' : 'failed'
        };
      });
      
      const worktreeResults = await Promise.allSettled(worktreeCreationPromises);
      
      // Analyze worktree creation results
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
  
  async undo(result, input, context) {
    // Cleanup created worktrees on failure
    for (const worktree of result.successfulWorktrees) {
      await $fetch('/api/git/remove-worktree', {
        method: 'DELETE',
        body: { path: worktree.path }
      });
    }
  }
};

// Step 3: Dependency Resolution and Installation
const dependencyResolutionInstallation: ReactorStep<any, any> = {
  name: 'dependency-resolution-installation',
  description: 'Resolve and install dependencies across worktrees with coordination',
  dependencies: ['git-worktree-creation'],
  timeout: 180000, // 3 minutes
  
  async run(input, context) {
    try {
      const worktreeResult = context.results?.get('git-worktree-creation')?.data;
      const environment = context.results?.get('environment-registry-init')?.data;
      
      // Resolve dependency order based on worktree dependencies
      const installationOrder = resolveDependencyOrder(worktreeResult.successfulWorktrees);
      
      const installationResults = [];
      
      // Install dependencies in dependency order
      for (const batch of installationOrder) {
        const batchPromises = batch.map(async (worktree) => {
          const config = environment.registry[worktree.name];
          
          // Install dependencies based on worktree type
          return installWorktreeDependencies(worktree, config, context);
        });
        
        const batchResults = await Promise.allSettled(batchPromises);
        installationResults.push(...batchResults);
      }
      
      // Analyze installation results
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

// Step 4: Coordinated Service Startup
const coordinatedServiceStartup: ReactorStep<any, any> = {
  name: 'coordinated-service-startup',
  description: 'Start services with coordinated health checks and port management',
  dependencies: ['dependency-resolution-installation'],
  timeout: 120000, // 2 minutes
  
  async run(input, context) {
    try {
      const installationResult = context.results?.get('dependency-resolution-installation')?.data;
      const environment = context.results?.get('environment-registry-init')?.data;
      
      // Start services in dependency order
      const startupResults = [];
      
      for (const batch of installationResult.installationOrder) {
        const startupPromises = batch.map(async (worktree) => {
          const config = environment.registry[worktree.name];
          
          // Start service with health check coordination
          return startWorktreeService(worktree, config, context);
        });
        
        const batchResults = await Promise.allSettled(startupPromises);
        startupResults.push(...batchResults);
        
        // Wait for batch to be healthy before starting next batch
        await waitForBatchHealth(batchResults, environment);
      }
      
      // Validate all services are running
      const healthCheckResults = await performComprehensiveHealthCheck(
        startupResults,
        environment
      );
      
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
  
  async undo(result, input, context) {
    // Stop all started services
    for (const service of result.runningServices || []) {
      await stopWorktreeService(service);
    }
  }
};

// Step 5: Cross-Worktree Telemetry Setup
const crossWorktreeTelemetrySetup: ReactorStep<any, any> = {
  name: 'cross-worktree-telemetry-setup',
  description: 'Setup shared telemetry across all worktree environments',
  dependencies: ['coordinated-service-startup'],
  
  async run(input, context) {
    try {
      const serviceResult = context.results?.get('coordinated-service-startup')?.data;
      const environment = context.results?.get('environment-registry-init')?.data;
      
      // Setup shared telemetry configuration
      const telemetryConfig = {
        traceId: context.traceId,
        correlationId: `worktree_deployment_${context.id}`,
        services: serviceResult.runningServices.map(service => ({
          name: service.name,
          url: service.url,
          port: service.port,
          type: service.type
        })),
        sharedEndpoint: '/api/telemetry/shared',
        collectionInterval: 30000 // 30 seconds
      };
      
      // Configure telemetry for each service
      const telemetrySetupResults = await Promise.all(
        serviceResult.runningServices.map(service => 
          setupServiceTelemetry(service, telemetryConfig, context)
        )
      );
      
      // Initialize shared telemetry aggregation
      const aggregationSetup = await initializeSharedTelemetryAggregation(
        telemetryConfig,
        context
      );
      
      // Update environment with telemetry configuration
      environment.sharedTelemetry = telemetrySetupResults;
      environment.coordinationState = 'running';
      
      return { 
        success: true, 
        data: {
          telemetryConfig,
          telemetrySetupResults,
          aggregationSetup,
          environment,
          telemetryEndpoints: telemetrySetupResults.map(r => r.endpoint)
        }
      };
      
    } catch (error) {
      return { success: false, error: error as Error };
    }
  }
};

// Step 6: Autonomous Health Monitoring
const autonomousHealthMonitoring: ReactorStep<any, any> = {
  name: 'autonomous-health-monitoring',
  description: 'Setup autonomous health monitoring with auto-recovery',
  dependencies: ['cross-worktree-telemetry-setup'],
  
  async run(input, context) {
    try {
      const telemetryResult = context.results?.get('cross-worktree-telemetry-setup')?.data;
      const environment = telemetryResult.environment;
      
      // Setup health monitoring for all services
      const monitoringConfig = {
        services: Object.values(environment.registry),
        healthCheckInterval: 30000, // 30 seconds
        failureThreshold: 3,
        autoRecovery: input.enableAutoRecovery !== false,
        alertingEndpoint: '/api/monitoring/alerts',
        dashboardUrl: 'http://localhost:3000/dashboard/worktrees'
      };
      
      // Initialize monitoring for each service
      const monitoringSetupResults = await Promise.all(
        monitoringConfig.services.map(service => 
          initializeServiceMonitoring(service, monitoringConfig, context)
        )
      );
      
      // Setup cross-worktree coordination monitoring
      const coordinationMonitoring = await setupCoordinationMonitoring(
        environment,
        context
      );
      
      // Start autonomous monitoring loop
      const monitoringLoop = await startAutonomousMonitoringLoop(
        monitoringConfig,
        context
      );
      
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

/**
 * Helper Functions (implementing worktree_environment_manager.sh patterns)
 */

async function validateWorktreeCreation(path: string, config: WorktreeConfig) {
  try {
    // Validate worktree structure
    const validation = await $fetch('/api/git/validate-worktree', {
      method: 'POST',
      body: { path, expectedType: config.type }
    });
    
    return {
      valid: validation.exists && validation.hasCorrectStructure,
      path: validation.path,
      branch: validation.branch,
      type: validation.detectedType
    };
  } catch (error) {
    return { valid: false, error: error.message };
  }
}

function resolveDependencyOrder(worktrees: any[]): any[][] {
  const dependencyGraph = new Map();
  const inDegree = new Map();
  
  // Build dependency graph
  worktrees.forEach(worktree => {
    dependencyGraph.set(worktree.name, worktree.config.dependencies || []);
    inDegree.set(worktree.name, 0);
  });
  
  // Calculate in-degrees
  worktrees.forEach(worktree => {
    (worktree.config.dependencies || []).forEach(dep => {
      if (inDegree.has(dep)) {
        inDegree.set(dep, inDegree.get(dep) + 1);
      }
    });
  });
  
  // Topological sort into batches
  const result = [];
  const remaining = new Set(worktrees.map(w => w.name));
  
  while (remaining.size > 0) {
    const batch = [];
    
    for (const worktree of worktrees) {
      if (remaining.has(worktree.name) && inDegree.get(worktree.name) === 0) {
        batch.push(worktree);
        remaining.delete(worktree.name);
      }
    }
    
    if (batch.length === 0) {
      // Handle circular dependencies
      const remainingWorktrees = worktrees.filter(w => remaining.has(w.name));
      result.push(remainingWorktrees);
      break;
    }
    
    result.push(batch);
    
    // Update in-degrees
    batch.forEach(worktree => {
      (worktree.config.dependencies || []).forEach(dep => {
        if (inDegree.has(dep)) {
          inDegree.set(dep, inDegree.get(dep) - 1);
        }
      });
    });
  }
  
  return result;
}

async function installWorktreeDependencies(worktree: any, config: WorktreeConfig, context: any) {
  const installCommands = {
    'phoenix': 'mix deps.get && npm install',
    'xavos': 'mix deps.get && mix ash.setup && npm install',
    'beamops': 'mix deps.get && docker-compose pull',
    'engineering-elixir-apps': 'mix deps.get'
  };
  
  const command = installCommands[config.type] || 'echo "No dependencies to install"';
  
  return $fetch('/api/worktree/install-dependencies', {
    method: 'POST',
    body: {
      path: worktree.path,
      command,
      environmentVariables: config.environmentVariables,
      timeout: 120000,
      traceId: context.traceId
    }
  });
}

function calculateInstallationMetrics(installations: any[]) {
  return {
    totalInstallations: installations.length,
    averageInstallTime: installations.reduce((sum, inst) => sum + (inst.duration || 0), 0) / installations.length,
    successRate: installations.filter(inst => inst.success).length / installations.length,
    totalDependencies: installations.reduce((sum, inst) => sum + (inst.dependencyCount || 0), 0)
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

async function startWorktreeService(worktree: any, config: WorktreeConfig, context: any) {
  const startCommands = {
    'phoenix': 'mix phx.server',
    'xavos': 'mix phx.server',
    'beamops': 'docker-compose up -d',
    'engineering-elixir-apps': 'mix run --no-halt'
  };
  
  const command = startCommands[config.type] || 'echo "Service started"';
  
  return $fetch('/api/worktree/start-service', {
    method: 'POST',
    body: {
      path: worktree.path,
      command,
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
}

async function waitForBatchHealth(batchResults: any[], environment: DeploymentEnvironment) {
  const healthyServices = batchResults
    .filter(result => result.status === 'fulfilled')
    .map(result => (result as any).value)
    .filter(service => service.started);
  
  // Wait for all services in batch to be healthy
  const healthCheckPromises = healthyServices.map(service => 
    waitForServiceHealth(service.healthCheckUrl, 30000)
  );
  
  await Promise.allSettled(healthCheckPromises);
}

async function waitForServiceHealth(healthCheckUrl: string, timeout: number): Promise<boolean> {
  const startTime = Date.now();
  
  while (Date.now() - startTime < timeout) {
    try {
      const response = await $fetch(healthCheckUrl);
      if (response.status === 'healthy') {
        return true;
      }
    } catch (error) {
      // Service not ready yet
    }
    
    await new Promise(resolve => setTimeout(resolve, 1000));
  }
  
  return false;
}

async function performComprehensiveHealthCheck(startupResults: any[], environment: DeploymentEnvironment) {
  const healthChecks = [];
  
  for (const [serviceName, config] of Object.entries(environment.registry)) {
    try {
      const healthResponse = await $fetch(config.healthCheckUrl, { timeout: 5000 });
      
      healthChecks.push({
        service: serviceName,
        url: config.healthCheckUrl,
        port: config.port,
        status: 'healthy',
        response: healthResponse,
        responseTime: Date.now()
      });
    } catch (error) {
      healthChecks.push({
        service: serviceName,
        url: config.healthCheckUrl,
        port: config.port,
        status: 'unhealthy',
        error: error.message,
        responseTime: Date.now()
      });
    }
  }
  
  return {
    healthyServices: healthChecks.filter(hc => hc.status === 'healthy'),
    unhealthyServices: healthChecks.filter(hc => hc.status === 'unhealthy'),
    totalServices: healthChecks.length,
    healthRate: healthChecks.filter(hc => hc.status === 'healthy').length / healthChecks.length
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

async function stopWorktreeService(service: any) {
  return $fetch('/api/worktree/stop-service', {
    method: 'POST',
    body: { path: service.path, port: service.port }
  });
}

async function setupServiceTelemetry(service: any, telemetryConfig: any, context: any) {
  return $fetch('/api/telemetry/setup-service', {
    method: 'POST',
    body: {
      serviceName: service.name,
      serviceUrl: service.url,
      telemetryConfig,
      traceId: context.traceId
    }
  });
}

async function initializeSharedTelemetryAggregation(telemetryConfig: any, context: any) {
  return $fetch('/api/telemetry/initialize-aggregation', {
    method: 'POST',
    body: {
      config: telemetryConfig,
      traceId: context.traceId
    }
  });
}

async function initializeServiceMonitoring(service: WorktreeConfig, monitoringConfig: any, context: any) {
  return $fetch('/api/monitoring/initialize-service', {
    method: 'POST',
    body: {
      service,
      config: monitoringConfig,
      traceId: context.traceId
    }
  });
}

async function setupCoordinationMonitoring(environment: DeploymentEnvironment, context: any) {
  return $fetch('/api/monitoring/setup-coordination', {
    method: 'POST',
    body: {
      environment,
      traceId: context.traceId
    }
  });
}

async function startAutonomousMonitoringLoop(monitoringConfig: any, context: any) {
  return $fetch('/api/monitoring/start-autonomous-loop', {
    method: 'POST',
    body: {
      config: monitoringConfig,
      traceId: context.traceId
    }
  });
}

/**
 * Create Autonomous Worktree Deployment Reactor
 */
export function createAutonomousWorktreeDeploymentReactor(options?: {
  enableAutoRecovery?: boolean;
  parallelDeployment?: boolean;
  healthCheckTimeout?: number;
}) {
  const reactor = new ReactorEngine({
    id: `worktree_deployment_${Date.now()}`,
    timeout: 600000, // 10 minutes
    maxConcurrency: options?.parallelDeployment ? 5 : 1,
    middleware: [
      new TelemetryMiddleware({
        onSpanEnd: (span) => {
          // Track deployment-specific metrics
          if (span.operationName.includes('worktree')) {
            console.log(`🚀 Worktree Deployment: ${span.operationName} - ${span.duration}ms`);
          }
        }
      }),
      new CoordinationMiddleware({
        onWorkClaim: (claim) => {
          console.log(`🔧 Deploying: ${claim.stepName}`);
        },
        onWorkComplete: (claim) => {
          console.log(`✅ Deployed: ${claim.stepName}`);
        }
      })
    ]
  });
  
  // Add all deployment steps
  reactor.addStep(environmentRegistryInit);
  reactor.addStep(gitWorktreeCreation);
  reactor.addStep(dependencyResolutionInstallation);
  reactor.addStep(coordinatedServiceStartup);
  reactor.addStep(crossWorktreeTelemetrySetup);
  reactor.addStep(autonomousHealthMonitoring);
  
  return reactor;
}