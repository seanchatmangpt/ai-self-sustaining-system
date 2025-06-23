/**
 * Advanced Agent Coordination System
 * Enhanced patterns from coordination_helper.sh for distributed reactor execution
 */

import type { ReactorContext } from '../types';

export interface AgentCapability {
  id: string;
  type: 'analysis' | 'optimization' | 'coordination' | 'validation' | 'general';
  efficiency: number;
  concurrency: number;
  specializations: string[];
  currentLoad: number;
  maxLoad: number;
  priority: number;
}

export interface WorkItem {
  id: string;
  type: string;
  priority: 'high' | 'medium' | 'low';
  estimatedDuration: number;
  dependencies: string[];
  metadata: Record<string, any>;
  assignedAgent?: string;
  status: 'pending' | 'claimed' | 'in_progress' | 'completed' | 'failed';
  claimedAt?: number;
  lastUpdate: number;
}

export interface AgentFormation {
  id: string;
  agents: AgentCapability[];
  workQueue: WorkItem[];
  coordinationStrategy: 'round_robin' | 'load_based' | 'specialization' | 'priority';
  performance: {
    totalTasks: number;
    completedTasks: number;
    failedTasks: number;
    averageLatency: number;
    throughput: number;
  };
}

export interface CoordinationPattern {
  name: string;
  description: string;
  applicableScenarios: string[];
  implementation: (formation: AgentFormation, context: ReactorContext) => Promise<WorkDistribution>;
}

export interface WorkDistribution {
  assignments: Array<{
    agentId: string;
    workItems: WorkItem[];
    estimatedCompletion: number;
    priority: number;
  }>;
  distributionScore: number;
  strategy: string;
  metadata: Record<string, any>;
}

export interface CoordinationMetrics {
  totalAgents: number;
  activeAgents: number;
  totalWorkItems: number;
  completedWorkItems: number;
  averageAgentUtilization: number;
  systemThroughput: number;
  coordinationEfficiency: number;
  conflictResolutions: number;
  adaptiveOptimizations: number;
}

export class AdvancedCoordinationEngine {
  private formations: Map<string, AgentFormation> = new Map();
  private patterns: Map<string, CoordinationPattern> = new Map();
  private metrics: CoordinationMetrics = {
    totalAgents: 0,
    activeAgents: 0,
    totalWorkItems: 0,
    completedWorkItems: 0,
    averageAgentUtilization: 0,
    systemThroughput: 0,
    coordinationEfficiency: 0,
    conflictResolutions: 0,
    adaptiveOptimizations: 0
  };

  constructor() {
    this.initializeCoordinationPatterns();
  }

  /**
   * Agent Formation and Management
   */
  async createAgentFormation(
    formationId: string,
    agents: Partial<AgentCapability>[],
    strategy: AgentFormation['coordinationStrategy'] = 'specialization'
  ): Promise<AgentFormation> {
    const enhancedAgents: AgentCapability[] = agents.map((agent, index) => ({
      id: agent.id || `agent_${Date.now()}_${index}_${process.hrtime.bigint().toString().slice(-9)}`,
      type: agent.type || 'general',
      efficiency: agent.efficiency || 0.8,
      concurrency: agent.concurrency || 3,
      specializations: agent.specializations || [],
      currentLoad: 0,
      maxLoad: agent.concurrency || 3,
      priority: agent.priority || 1
    }));

    const formation: AgentFormation = {
      id: formationId,
      agents: enhancedAgents,
      workQueue: [],
      coordinationStrategy: strategy,
      performance: {
        totalTasks: 0,
        completedTasks: 0,
        failedTasks: 0,
        averageLatency: 0,
        throughput: 0
      }
    };

    this.formations.set(formationId, formation);
    this.updateMetrics();

    console.log(`🤖 Agent formation created: ${formationId} with ${enhancedAgents.length} agents`);
    return formation;
  }

  async spawnAdaptiveAgents(
    formationId: string,
    workloadAnalysis: {
      totalWork: number;
      workTypes: Record<string, number>;
      urgency: 'low' | 'medium' | 'high';
      complexity: 'simple' | 'moderate' | 'complex';
    }
  ): Promise<AgentCapability[]> {
    const formation = this.formations.get(formationId);
    if (!formation) {
      throw new Error(`Formation not found: ${formationId}`);
    }

    // Calculate optimal agent count based on workload
    const baseAgentCount = formation.agents.length;
    const optimalAgentCount = this.calculateOptimalAgentCount(workloadAnalysis);
    
    if (optimalAgentCount <= baseAgentCount) {
      return formation.agents;
    }

    // Spawn additional specialized agents
    const additionalAgents: AgentCapability[] = [];
    const agentsToSpawn = optimalAgentCount - baseAgentCount;

    for (let i = 0; i < agentsToSpawn; i++) {
      const specialization = this.determineOptimalSpecialization(workloadAnalysis.workTypes);
      
      const newAgent: AgentCapability = {
        id: `adaptive_agent_${Date.now()}_${i}_${process.hrtime.bigint().toString().slice(-9)}`,
        type: specialization,
        efficiency: this.calculateAdaptiveEfficiency(workloadAnalysis),
        concurrency: this.calculateAdaptiveConcurrency(workloadAnalysis),
        specializations: [specialization],
        currentLoad: 0,
        maxLoad: this.calculateAdaptiveConcurrency(workloadAnalysis),
        priority: workloadAnalysis.urgency === 'high' ? 3 : workloadAnalysis.urgency === 'medium' ? 2 : 1
      };

      additionalAgents.push(newAgent);
      formation.agents.push(newAgent);
    }

    this.updateMetrics();
    console.log(`🚀 Spawned ${additionalAgents.length} adaptive agents for formation ${formationId}`);
    
    return additionalAgents;
  }

  /**
   * Intelligent Work Distribution
   */
  async distributeWork(
    formationId: string,
    workItems: WorkItem[],
    context: ReactorContext
  ): Promise<WorkDistribution> {
    const formation = this.formations.get(formationId);
    if (!formation) {
      throw new Error(`Formation not found: ${formationId}`);
    }

    // Select coordination pattern based on workload characteristics
    const pattern = this.selectOptimalPattern(workItems, formation, context);
    
    // Execute distribution using selected pattern
    const distribution = await pattern.implementation(formation, context);
    
    // Apply assignments atomically
    await this.applyWorkDistribution(formation, distribution, workItems);
    
    // Update performance metrics
    this.updateFormationPerformance(formation, distribution);
    
    return distribution;
  }

  async claimWorkAtomically(
    formationId: string,
    workItemId: string,
    agentId: string
  ): Promise<boolean> {
    const formation = this.formations.get(formationId);
    if (!formation) return false;

    const workItem = formation.workQueue.find(w => w.id === workItemId);
    const agent = formation.agents.find(a => a.id === agentId);
    
    if (!workItem || !agent || workItem.status !== 'pending') return false;
    
    // Check agent capacity
    if (agent.currentLoad >= agent.maxLoad) return false;

    // Atomic claim operation
    workItem.status = 'claimed';
    workItem.assignedAgent = agentId;
    workItem.claimedAt = Date.now();
    workItem.lastUpdate = Date.now();
    
    agent.currentLoad++;
    
    console.log(`🎯 Work claimed: ${workItemId} by agent ${agentId}`);
    return true;
  }

  /**
   * Real-time Coordination and Monitoring
   */
  async startCoordinatedExecution(
    formationId: string,
    context: ReactorContext
  ): Promise<void> {
    const formation = this.formations.get(formationId);
    if (!formation) {
      throw new Error(`Formation not found: ${formationId}`);
    }

    console.log(`🎬 Starting coordinated execution for formation ${formationId}`);
    
    // Start real-time monitoring
    const monitoringInterval = setInterval(() => {
      this.monitorFormationHealth(formation, context);
    }, 1000);

    // Store interval for cleanup
    context.metadata.monitoringInterval = monitoringInterval;
    
    // Execute work items
    const executionPromises = formation.workQueue
      .filter(w => w.status === 'claimed')
      .map(workItem => this.executeWorkItem(formation, workItem, context));

    await Promise.allSettled(executionPromises);
    
    // Cleanup monitoring
    clearInterval(monitoringInterval);
    delete context.metadata.monitoringInterval;
    
    console.log(`✅ Coordinated execution completed for formation ${formationId}`);
  }

  private async executeWorkItem(
    formation: AgentFormation,
    workItem: WorkItem,
    context: ReactorContext
  ): Promise<void> {
    const agent = formation.agents.find(a => a.id === workItem.assignedAgent);
    if (!agent) return;

    try {
      workItem.status = 'in_progress';
      workItem.lastUpdate = Date.now();

      // Simulate work execution with agent efficiency
      const executionTime = workItem.estimatedDuration / agent.efficiency;
      await new Promise(resolve => setTimeout(resolve, executionTime));

      workItem.status = 'completed';
      workItem.lastUpdate = Date.now();
      
      formation.performance.completedTasks++;
      agent.currentLoad--;
      
      console.log(`✅ Work completed: ${workItem.id} by agent ${agent.id}`);
      
    } catch (error) {
      workItem.status = 'failed';
      workItem.lastUpdate = Date.now();
      
      formation.performance.failedTasks++;
      agent.currentLoad--;
      
      console.error(`❌ Work failed: ${workItem.id} by agent ${agent.id}`, error);
    }
  }

  /**
   * Performance Optimization and Adaptation
   */
  async optimizeFormation(formationId: string): Promise<{
    optimizationsApplied: string[];
    performanceImprovement: number;
    newConfiguration: AgentFormation;
  }> {
    const formation = this.formations.get(formationId);
    if (!formation) {
      throw new Error(`Formation not found: ${formationId}`);
    }

    const optimizations: string[] = [];
    const originalThroughput = formation.performance.throughput;

    // Agent load balancing
    if (this.needsLoadBalancing(formation)) {
      await this.rebalanceAgentLoads(formation);
      optimizations.push('Load balancing applied');
    }

    // Specialization optimization
    if (this.needsSpecializationOptimization(formation)) {
      await this.optimizeAgentSpecializations(formation);
      optimizations.push('Agent specializations optimized');
    }

    // Dynamic scaling
    const scalingDecision = this.analyzeScalingNeeds(formation);
    if (scalingDecision.action !== 'none') {
      await this.applyDynamicScaling(formation, scalingDecision);
      optimizations.push(`Dynamic scaling: ${scalingDecision.action}`);
    }

    // Strategy adaptation
    const optimalStrategy = this.analyzeOptimalStrategy(formation);
    if (optimalStrategy !== formation.coordinationStrategy) {
      formation.coordinationStrategy = optimalStrategy;
      optimizations.push(`Strategy changed to: ${optimalStrategy}`);
    }

    // Update metrics
    this.updateFormationPerformance(formation, {
      assignments: [],
      distributionScore: 0,
      strategy: formation.coordinationStrategy,
      metadata: {}
    });

    const newThroughput = formation.performance.throughput;
    const performanceImprovement = newThroughput - originalThroughput;

    this.metrics.adaptiveOptimizations++;

    console.log(`🚀 Formation optimized: ${formationId}, improvements: ${optimizations.join(', ')}`);

    return {
      optimizationsApplied: optimizations,
      performanceImprovement,
      newConfiguration: formation
    };
  }

  /**
   * Coordination Patterns Implementation
   */
  private initializeCoordinationPatterns(): void {
    // 80/20 Optimization Pattern
    this.patterns.set('8020_optimization', {
      name: '80/20 Optimization Pattern',
      description: 'Focus 80% of resources on 20% of critical tasks',
      applicableScenarios: ['high_priority_tasks', 'resource_constraints', 'critical_deadlines'],
      implementation: async (formation, context) => {
        const sortedWork = formation.workQueue
          .sort((a, b) => {
            const priorityWeight = { high: 3, medium: 2, low: 1 };
            return priorityWeight[b.priority] - priorityWeight[a.priority];
          });

        const criticalTasks = sortedWork.slice(0, Math.ceil(sortedWork.length * 0.2));
        const remainingTasks = sortedWork.slice(Math.ceil(sortedWork.length * 0.2));

        // Assign top 80% of agents to critical 20% of tasks
        const topAgents = formation.agents
          .sort((a, b) => b.efficiency - a.efficiency)
          .slice(0, Math.ceil(formation.agents.length * 0.8));

        const assignments = [];
        
        // Distribute critical tasks to top agents
        for (let i = 0; i < criticalTasks.length; i++) {
          const agent = topAgents[i % topAgents.length];
          assignments.push({
            agentId: agent.id,
            workItems: [criticalTasks[i]],
            estimatedCompletion: criticalTasks[i].estimatedDuration / agent.efficiency,
            priority: 3
          });
        }

        // Distribute remaining tasks to all agents
        const remainingAgents = formation.agents.filter(a => !topAgents.includes(a));
        for (let i = 0; i < remainingTasks.length; i++) {
          const agent = remainingAgents[i % remainingAgents.length] || topAgents[i % topAgents.length];
          assignments.push({
            agentId: agent.id,
            workItems: [remainingTasks[i]],
            estimatedCompletion: remainingTasks[i].estimatedDuration / agent.efficiency,
            priority: 1
          });
        }

        return {
          assignments,
          distributionScore: 0.85,
          strategy: '8020_optimization',
          metadata: { criticalTasks: criticalTasks.length, totalTasks: sortedWork.length }
        };
      }
    });

    // Specialization-based Pattern
    this.patterns.set('specialization_based', {
      name: 'Specialization-based Distribution',
      description: 'Assign tasks based on agent specializations',
      applicableScenarios: ['diverse_task_types', 'specialized_requirements', 'quality_focus'],
      implementation: async (formation, context) => {
        const assignments = [];
        const unassignedWork: WorkItem[] = [...formation.workQueue];

        // First pass: perfect matches
        for (const agent of formation.agents) {
          const matchingWork = unassignedWork.filter(work => 
            agent.specializations.includes(work.type) && agent.currentLoad < agent.maxLoad
          );

          if (matchingWork.length > 0) {
            const workForAgent = matchingWork.slice(0, agent.maxLoad - agent.currentLoad);
            assignments.push({
              agentId: agent.id,
              workItems: workForAgent,
              estimatedCompletion: workForAgent.reduce((sum, w) => sum + w.estimatedDuration, 0) / agent.efficiency,
              priority: 2
            });

            // Remove assigned work
            workForAgent.forEach(work => {
              const index = unassignedWork.indexOf(work);
              if (index > -1) unassignedWork.splice(index, 1);
            });
          }
        }

        // Second pass: remaining work to available agents
        for (const work of unassignedWork) {
          const availableAgent = formation.agents.find(a => a.currentLoad < a.maxLoad);
          if (availableAgent) {
            assignments.push({
              agentId: availableAgent.id,
              workItems: [work],
              estimatedCompletion: work.estimatedDuration / availableAgent.efficiency,
              priority: 1
            });
          }
        }

        return {
          assignments,
          distributionScore: 0.9,
          strategy: 'specialization_based',
          metadata: { specializationMatches: assignments.length - unassignedWork.length }
        };
      }
    });
  }

  private selectOptimalPattern(
    workItems: WorkItem[],
    formation: AgentFormation,
    context: ReactorContext
  ): CoordinationPattern {
    // Analyze workload characteristics
    const highPriorityRatio = workItems.filter(w => w.priority === 'high').length / workItems.length;
    const typeVariety = new Set(workItems.map(w => w.type)).size;
    const agentSpecializationRatio = formation.agents.filter(a => a.specializations.length > 0).length / formation.agents.length;

    // Pattern selection logic
    if (highPriorityRatio > 0.3 || context.priority === 'high') {
      return this.patterns.get('8020_optimization')!;
    }

    if (typeVariety > 2 && agentSpecializationRatio > 0.5) {
      return this.patterns.get('specialization_based')!;
    }

    // Default to specialization-based
    return this.patterns.get('specialization_based')!;
  }

  private async applyWorkDistribution(
    formation: AgentFormation,
    distribution: WorkDistribution,
    workItems: WorkItem[]
  ): Promise<void> {
    for (const assignment of distribution.assignments) {
      const agent = formation.agents.find(a => a.id === assignment.agentId);
      if (!agent) continue;

      for (const workItem of assignment.workItems) {
        const fullWorkItem = workItems.find(w => w.id === workItem.id);
        if (fullWorkItem) {
          fullWorkItem.assignedAgent = agent.id;
          fullWorkItem.status = 'claimed';
          fullWorkItem.claimedAt = Date.now();
          fullWorkItem.lastUpdate = Date.now();
          
          formation.workQueue.push(fullWorkItem);
          agent.currentLoad++;
        }
      }
    }
  }

  // Helper methods for optimization
  private calculateOptimalAgentCount(workloadAnalysis: any): number {
    const baseCount = Math.ceil(workloadAnalysis.totalWork / 10);
    const complexityMultiplier = workloadAnalysis.complexity === 'complex' ? 1.5 : 
                                 workloadAnalysis.complexity === 'moderate' ? 1.2 : 1;
    const urgencyMultiplier = workloadAnalysis.urgency === 'high' ? 1.3 : 
                             workloadAnalysis.urgency === 'medium' ? 1.1 : 1;
    
    return Math.ceil(baseCount * complexityMultiplier * urgencyMultiplier);
  }

  private determineOptimalSpecialization(workTypes: Record<string, number>): AgentCapability['type'] {
    const sorted = Object.entries(workTypes).sort(([,a], [,b]) => b - a);
    const topType = sorted[0]?.[0];
    
    switch (topType) {
      case 'analysis': return 'analysis';
      case 'optimization': return 'optimization';
      case 'coordination': return 'coordination';
      case 'validation': return 'validation';
      default: return 'general';
    }
  }

  private calculateAdaptiveEfficiency(workloadAnalysis: any): number {
    let efficiency = 0.8; // Base efficiency
    
    if (workloadAnalysis.urgency === 'high') efficiency += 0.1;
    if (workloadAnalysis.complexity === 'simple') efficiency += 0.1;
    
    return Math.min(efficiency, 1.0);
  }

  private calculateAdaptiveConcurrency(workloadAnalysis: any): number {
    let concurrency = 3; // Base concurrency
    
    if (workloadAnalysis.urgency === 'high') concurrency += 2;
    if (workloadAnalysis.complexity === 'simple') concurrency += 1;
    
    return Math.min(concurrency, 8);
  }

  private needsLoadBalancing(formation: AgentFormation): boolean {
    const loads = formation.agents.map(a => a.currentLoad / a.maxLoad);
    const avgLoad = loads.reduce((sum, load) => sum + load, 0) / loads.length;
    const variance = loads.reduce((sum, load) => sum + Math.pow(load - avgLoad, 2), 0) / loads.length;
    
    return variance > 0.3; // Threshold for load imbalance
  }

  private async rebalanceAgentLoads(formation: AgentFormation): Promise<void> {
    // Implementation for load rebalancing
    const overloadedAgents = formation.agents.filter(a => a.currentLoad > a.maxLoad * 0.8);
    const underloadedAgents = formation.agents.filter(a => a.currentLoad < a.maxLoad * 0.4);
    
    // Move work from overloaded to underloaded agents
    for (const overloaded of overloadedAgents) {
      for (const underloaded of underloadedAgents) {
        if (overloaded.currentLoad > 0 && underloaded.currentLoad < underloaded.maxLoad) {
          // Transfer one work item
          overloaded.currentLoad--;
          underloaded.currentLoad++;
          break;
        }
      }
    }
  }

  private needsSpecializationOptimization(formation: AgentFormation): boolean {
    // Check if specializations match current work types
    const workTypes = new Set(formation.workQueue.map(w => w.type));
    const specializations = new Set(formation.agents.flatMap(a => a.specializations));
    
    const coverage = Array.from(workTypes).filter(type => specializations.has(type)).length / workTypes.size;
    return coverage < 0.7; // 70% coverage threshold
  }

  private async optimizeAgentSpecializations(formation: AgentFormation): Promise<void> {
    const workTypeCounts = formation.workQueue.reduce((counts, work) => {
      counts[work.type] = (counts[work.type] || 0) + 1;
      return counts;
    }, {} as Record<string, number>);

    // Reassign specializations based on work patterns
    const sortedWorkTypes = Object.entries(workTypeCounts).sort(([,a], [,b]) => b - a);
    
    formation.agents.forEach((agent, index) => {
      const primaryType = sortedWorkTypes[index % sortedWorkTypes.length]?.[0];
      if (primaryType) {
        agent.specializations = [primaryType];
      }
    });
  }

  private analyzeScalingNeeds(formation: AgentFormation): { action: 'scale_up' | 'scale_down' | 'none'; factor: number } {
    const avgUtilization = formation.agents.reduce((sum, a) => sum + (a.currentLoad / a.maxLoad), 0) / formation.agents.length;
    
    if (avgUtilization > 0.9) {
      return { action: 'scale_up', factor: 1.5 };
    } else if (avgUtilization < 0.3 && formation.agents.length > 2) {
      return { action: 'scale_down', factor: 0.7 };
    }
    
    return { action: 'none', factor: 1 };
  }

  private async applyDynamicScaling(formation: AgentFormation, decision: { action: string; factor: number }): Promise<void> {
    if (decision.action === 'scale_up') {
      const newAgentCount = Math.ceil(formation.agents.length * decision.factor) - formation.agents.length;
      for (let i = 0; i < newAgentCount; i++) {
        const newAgent: AgentCapability = {
          id: `scaled_agent_${Date.now()}_${i}_${process.hrtime.bigint().toString().slice(-9)}`,
          type: 'general',
          efficiency: 0.8,
          concurrency: 3,
          specializations: [],
          currentLoad: 0,
          maxLoad: 3,
          priority: 1
        };
        formation.agents.push(newAgent);
      }
    } else if (decision.action === 'scale_down') {
      const targetsToRemove = formation.agents.length - Math.ceil(formation.agents.length * decision.factor);
      const idleAgents = formation.agents.filter(a => a.currentLoad === 0);
      const agentsToRemove = idleAgents.slice(0, targetsToRemove);
      
      formation.agents = formation.agents.filter(a => !agentsToRemove.includes(a));
    }
  }

  private analyzeOptimalStrategy(formation: AgentFormation): AgentFormation['coordinationStrategy'] {
    const workTypeVariety = new Set(formation.workQueue.map(w => w.type)).size;
    const priorityVariety = new Set(formation.workQueue.map(w => w.priority)).size;
    const avgAgentSpecialization = formation.agents.reduce((sum, a) => sum + a.specializations.length, 0) / formation.agents.length;

    if (priorityVariety > 1 && formation.workQueue.some(w => w.priority === 'high')) {
      return 'priority';
    } else if (workTypeVariety > 2 && avgAgentSpecialization > 1) {
      return 'specialization';
    } else if (formation.agents.some(a => a.currentLoad > a.maxLoad * 0.8)) {
      return 'load_based';
    }
    
    return 'round_robin';
  }

  private monitorFormationHealth(formation: AgentFormation, context: ReactorContext): void {
    const activeAgents = formation.agents.filter(a => a.currentLoad > 0).length;
    const avgUtilization = formation.agents.reduce((sum, a) => sum + (a.currentLoad / a.maxLoad), 0) / formation.agents.length;
    
    // Update real-time metrics
    formation.performance.throughput = formation.performance.completedTasks / ((Date.now() - context.startTime) / 1000);
    
    // Health checks
    if (avgUtilization > 0.95) {
      console.warn(`⚠️ Formation ${formation.id} overloaded: ${(avgUtilization * 100).toFixed(1)}% utilization`);
    }
    
    if (activeAgents === 0 && formation.workQueue.some(w => w.status === 'pending')) {
      console.warn(`⚠️ Formation ${formation.id} has pending work but no active agents`);
    }
  }

  private updateFormationPerformance(formation: AgentFormation, distribution: WorkDistribution): void {
    formation.performance.totalTasks = formation.workQueue.length;
    formation.performance.averageLatency = formation.workQueue
      .filter(w => w.status === 'completed')
      .reduce((sum, w) => sum + (w.lastUpdate - (w.claimedAt || w.lastUpdate)), 0) /
      Math.max(formation.performance.completedTasks, 1);
  }

  private updateMetrics(): void {
    this.metrics.totalAgents = Array.from(this.formations.values()).reduce((sum, f) => sum + f.agents.length, 0);
    this.metrics.activeAgents = Array.from(this.formations.values()).reduce((sum, f) => 
      sum + f.agents.filter(a => a.currentLoad > 0).length, 0);
    this.metrics.totalWorkItems = Array.from(this.formations.values()).reduce((sum, f) => sum + f.workQueue.length, 0);
    this.metrics.completedWorkItems = Array.from(this.formations.values()).reduce((sum, f) => sum + f.performance.completedTasks, 0);
    
    if (this.metrics.totalAgents > 0) {
      this.metrics.averageAgentUtilization = this.metrics.activeAgents / this.metrics.totalAgents;
    }
    
    if (this.metrics.totalWorkItems > 0) {
      this.metrics.coordinationEfficiency = this.metrics.completedWorkItems / this.metrics.totalWorkItems;
    }
  }

  // Public API methods
  getFormation(formationId: string): AgentFormation | undefined {
    return this.formations.get(formationId);
  }

  getMetrics(): CoordinationMetrics {
    this.updateMetrics();
    return { ...this.metrics };
  }

  getAllFormations(): AgentFormation[] {
    return Array.from(this.formations.values());
  }

  async terminateFormation(formationId: string): Promise<void> {
    const formation = this.formations.get(formationId);
    if (formation) {
      console.log(`🔄 Terminating formation: ${formationId}`);
      this.formations.delete(formationId);
      this.updateMetrics();
    }
  }
}