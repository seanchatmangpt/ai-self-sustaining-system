/**
 * Coordination Middleware for Nuxt Reactor
 * Provides agent coordination and work claiming capabilities
 */

import type { ReactorMiddleware, ReactorContext, ReactorStep, StepResult } from '../types';

interface WorkClaim {
  id: string;
  agentId: string;
  stepName: string;
  claimedAt: number;
  status: 'claimed' | 'in_progress' | 'completed' | 'failed';
  lastUpdate: number;
}

export class CoordinationMiddleware implements ReactorMiddleware {
  name = 'coordination';
  private agentId: string;
  private workClaims: Map<string, WorkClaim> = new Map();
  private onWorkClaim?: (claim: WorkClaim) => void;
  private onWorkComplete?: (claim: WorkClaim) => void;
  
  constructor(options?: { 
    agentId?: string;
    onWorkClaim?: (claim: WorkClaim) => void;
    onWorkComplete?: (claim: WorkClaim) => void;
  }) {
    // Generate unique agent ID with nanosecond precision
    this.agentId = options?.agentId || `agent_${Date.now()}${process.hrtime.bigint().toString().slice(-9)}`;
    this.onWorkClaim = options?.onWorkClaim;
    this.onWorkComplete = options?.onWorkComplete;
  }
  
  async beforeReactor(context: ReactorContext): Promise<void> {
    // Set agent ID in context
    context.agentId = this.agentId;
    
    // Initialize coordination metadata
    context.coordination = {
      agentId: this.agentId,
      startTime: Date.now(),
      claimedSteps: []
    };
  }
  
  async beforeStep(step: ReactorStep, context: ReactorContext): Promise<void> {
    // Attempt to claim work with exponential backoff
    const claim = await this.claimWork(step.name, context);
    
    if (!claim) {
      throw new Error(`Failed to claim work for step: ${step.name}`);
    }
    
    // Track claimed step
    context.coordination.claimedSteps.push(step.name);
    
    // Update claim status to in_progress
    claim.status = 'in_progress';
    claim.lastUpdate = Date.now();
    
    // Emit work claim event
    if (this.onWorkClaim) {
      this.onWorkClaim(claim);
    }
  }
  
  async afterStep(step: ReactorStep, result: StepResult, context: ReactorContext): Promise<void> {
    const claim = this.workClaims.get(step.name);
    if (!claim) return;
    
    // Update claim based on result
    claim.status = result.success ? 'completed' : 'failed';
    claim.lastUpdate = Date.now();
    
    // Add performance metrics
    const duration = claim.lastUpdate - claim.claimedAt;
    context.coordination[`${step.name}_duration`] = duration;
    
    // Emit work complete event
    if (this.onWorkComplete) {
      this.onWorkComplete(claim);
    }
    
    // Clean up completed claim after delay
    setTimeout(() => {
      this.workClaims.delete(step.name);
    }, 60000); // Keep for 1 minute for debugging
  }
  
  private async claimWork(stepName: string, context: ReactorContext): Promise<WorkClaim | null> {
    const maxRetries = 5;
    let retryCount = 0;
    
    while (retryCount < maxRetries) {
      try {
        // Check if work is already claimed
        const existingClaim = await this.checkExistingClaim(stepName);
        
        if (existingClaim && !this.isClaimExpired(existingClaim)) {
          // Work already claimed by another agent
          retryCount++;
          await this.exponentialBackoff(retryCount);
          continue;
        }
        
        // Create new claim
        const claim: WorkClaim = {
          id: `claim_${Date.now()}${process.hrtime.bigint().toString().slice(-9)}`,
          agentId: this.agentId,
          stepName,
          claimedAt: Date.now(),
          status: 'claimed',
          lastUpdate: Date.now()
        };
        
        // Atomic claim operation (in real implementation, this would use file locking or DB transaction)
        this.workClaims.set(stepName, claim);
        
        return claim;
        
      } catch (error) {
        console.error(`Error claiming work for ${stepName}:`, error);
        retryCount++;
        await this.exponentialBackoff(retryCount);
      }
    }
    
    return null;
  }
  
  private async checkExistingClaim(stepName: string): Promise<WorkClaim | null> {
    // In real implementation, this would check shared storage
    return this.workClaims.get(stepName) || null;
  }
  
  private isClaimExpired(claim: WorkClaim): boolean {
    // Claims expire after 5 minutes of no updates
    const expirationTime = 5 * 60 * 1000;
    return Date.now() - claim.lastUpdate > expirationTime;
  }
  
  private async exponentialBackoff(retryCount: number): Promise<void> {
    const baseDelay = 100; // 100ms
    const maxDelay = 5000; // 5 seconds
    const delay = Math.min(baseDelay * Math.pow(2, retryCount), maxDelay);
    
    await new Promise(resolve => setTimeout(resolve, delay));
  }
  
  getAgentId(): string {
    return this.agentId;
  }
  
  getWorkClaims(): WorkClaim[] {
    return Array.from(this.workClaims.values());
  }
  
  async updateProgress(stepName: string, progress: number): Promise<void> {
    const claim = this.workClaims.get(stepName);
    if (!claim) return;
    
    claim.lastUpdate = Date.now();
    
    // In real implementation, this would update shared storage
    // to signal progress to other agents
  }
}