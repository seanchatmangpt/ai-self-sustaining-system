/**
 * useReactorCoordination - Composable for agent coordination functionality
 */

import { ref, computed, type Ref } from 'vue';
import { AdvancedCoordinationEngine, type AgentFormation, type WorkItem, type CoordinationMetrics } from '../core/advanced-coordination';

export interface UseReactorCoordinationOptions {
  formationId?: string;
  autoStart?: boolean;
  enableMetrics?: boolean;
}

export default function useReactorCoordination(options: UseReactorCoordinationOptions = {}) {
  const coordinationEngine = new AdvancedCoordinationEngine();
  
  // Reactive state
  const currentFormation: Ref<AgentFormation | null> = ref(null);
  const formations: Ref<AgentFormation[]> = ref([]);
  const metrics: Ref<CoordinationMetrics | null> = ref(null);
  const isCoordinating = ref(false);
  const coordinationError: Ref<Error | null> = ref(null);

  // Computed properties
  const totalAgents = computed(() => 
    formations.value.reduce((sum, f) => sum + f.agents.length, 0)
  );

  const activeAgents = computed(() => 
    formations.value.reduce((sum, f) => sum + f.agents.filter(a => a.currentLoad > 0).length, 0)
  );

  const totalWorkItems = computed(() => 
    formations.value.reduce((sum, f) => sum + f.workQueue.length, 0)
  );

  const systemEfficiency = computed(() => {
    if (!metrics.value) return 0;
    return metrics.value.coordinationEfficiency * 100;
  });

  // Formation management
  const createFormation = async (
    formationId: string,
    agents: Partial<any>[],
    strategy: any = 'specialization'
  ) => {
    try {
      coordinationError.value = null;
      
      const formation = await coordinationEngine.createAgentFormation(formationId, agents, strategy);
      currentFormation.value = formation;
      
      await refreshFormations();
      
      return formation;
    } catch (error) {
      coordinationError.value = error as Error;
      throw error;
    }
  };

  const spawnAdaptiveAgents = async (
    formationId: string,
    workloadAnalysis: {
      totalWork: number;
      workTypes: Record<string, number>;
      urgency: 'low' | 'medium' | 'high';
      complexity: 'simple' | 'moderate' | 'complex';
    }
  ) => {
    try {
      coordinationError.value = null;
      
      const agents = await coordinationEngine.spawnAdaptiveAgents(formationId, workloadAnalysis);
      await refreshFormations();
      
      return agents;
    } catch (error) {
      coordinationError.value = error as Error;
      throw error;
    }
  };

  // Work distribution
  const distributeWork = async (
    formationId: string,
    workItems: WorkItem[],
    context: any
  ) => {
    try {
      coordinationError.value = null;
      
      const distribution = await coordinationEngine.distributeWork(formationId, workItems, context);
      await refreshFormations();
      
      return distribution;
    } catch (error) {
      coordinationError.value = error as Error;
      throw error;
    }
  };

  const claimWork = async (
    formationId: string,
    workItemId: string,
    agentId: string
  ) => {
    try {
      coordinationError.value = null;
      
      const success = await coordinationEngine.claimWorkAtomically(formationId, workItemId, agentId);
      
      if (success) {
        await refreshFormations();
      }
      
      return success;
    } catch (error) {
      coordinationError.value = error as Error;
      throw error;
    }
  };

  // Execution control
  const startCoordinatedExecution = async (formationId: string, context: any) => {
    try {
      isCoordinating.value = true;
      coordinationError.value = null;
      
      await coordinationEngine.startCoordinatedExecution(formationId, context);
      await refreshFormations();
    } catch (error) {
      coordinationError.value = error as Error;
      throw error;
    } finally {
      isCoordinating.value = false;
    }
  };

  const optimizeFormation = async (formationId: string) => {
    try {
      coordinationError.value = null;
      
      const result = await coordinationEngine.optimizeFormation(formationId);
      await refreshFormations();
      
      return result;
    } catch (error) {
      coordinationError.value = error as Error;
      throw error;
    }
  };

  // Data management
  const refreshFormations = async () => {
    formations.value = coordinationEngine.getAllFormations();
    
    if (options.enableMetrics) {
      metrics.value = coordinationEngine.getMetrics();
    }
  };

  const getFormation = (formationId: string) => {
    return coordinationEngine.getFormation(formationId);
  };

  const terminateFormation = async (formationId: string) => {
    try {
      coordinationError.value = null;
      
      await coordinationEngine.terminateFormation(formationId);
      
      if (currentFormation.value?.id === formationId) {
        currentFormation.value = null;
      }
      
      await refreshFormations();
    } catch (error) {
      coordinationError.value = error as Error;
      throw error;
    }
  };

  // Utility functions
  const createWorkItem = (
    id: string,
    type: string,
    priority: 'high' | 'medium' | 'low' = 'medium',
    estimatedDuration: number = 1000,
    dependencies: string[] = []
  ): WorkItem => {
    return {
      id,
      type,
      priority,
      estimatedDuration,
      dependencies,
      metadata: {},
      status: 'pending',
      lastUpdate: Date.now()
    };
  };

  const createAgentCapability = (
    id: string,
    type: any = 'general',
    efficiency: number = 0.8,
    concurrency: number = 3,
    specializations: string[] = []
  ) => {
    return {
      id,
      type,
      efficiency,
      concurrency,
      specializations,
      currentLoad: 0,
      maxLoad: concurrency,
      priority: 1
    };
  };

  // Monitoring and analytics
  const getFormationHealth = (formationId: string) => {
    const formation = getFormation(formationId);
    if (!formation) return null;

    const totalCapacity = formation.agents.reduce((sum, a) => sum + a.maxLoad, 0);
    const currentLoad = formation.agents.reduce((sum, a) => sum + a.currentLoad, 0);
    const utilization = totalCapacity > 0 ? currentLoad / totalCapacity : 0;

    return {
      utilization,
      agentCount: formation.agents.length,
      activeAgents: formation.agents.filter(a => a.currentLoad > 0).length,
      workQueueSize: formation.workQueue.length,
      completedTasks: formation.performance.completedTasks,
      failedTasks: formation.performance.failedTasks,
      throughput: formation.performance.throughput
    };
  };

  const exportFormationConfig = (formationId: string) => {
    const formation = getFormation(formationId);
    if (!formation) return null;

    return {
      id: formation.id,
      agents: formation.agents.map(a => ({
        id: a.id,
        type: a.type,
        efficiency: a.efficiency,
        concurrency: a.concurrency,
        specializations: a.specializations
      })),
      coordinationStrategy: formation.coordinationStrategy,
      performance: formation.performance
    };
  };

  // Initialize if auto-start is enabled
  if (options.autoStart) {
    const defaultFormationId = options.formationId || `formation_${Date.now()}`;
    createFormation(defaultFormationId, [
      createAgentCapability(`agent_1`, 'general'),
      createAgentCapability(`agent_2`, 'analysis'),
      createAgentCapability(`agent_3`, 'optimization')
    ]).catch(console.error);
  }

  return {
    // State
    currentFormation: readonly(currentFormation),
    formations: readonly(formations),
    metrics: readonly(metrics),
    isCoordinating: readonly(isCoordinating),
    coordinationError: readonly(coordinationError),

    // Computed
    totalAgents,
    activeAgents,
    totalWorkItems,
    systemEfficiency,

    // Formation management
    createFormation,
    spawnAdaptiveAgents,
    getFormation,
    terminateFormation,
    optimizeFormation,

    // Work management
    distributeWork,
    claimWork,
    createWorkItem,

    // Execution
    startCoordinatedExecution,

    // Utilities
    createAgentCapability,
    refreshFormations,
    getFormationHealth,
    exportFormationConfig,

    // Direct engine access (for advanced use cases)
    coordinationEngine
  };
}