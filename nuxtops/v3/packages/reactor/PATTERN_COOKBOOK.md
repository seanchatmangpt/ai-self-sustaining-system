# Nuxt Reactor Pattern Language Cookbook

A comprehensive collection of production-tested patterns for building robust, scalable workflows with Nuxt Reactor. Each pattern includes working examples, use cases, and performance considerations.

## Table of Contents

1. [Core Patterns](#core-patterns)
2. [Coordination Patterns](#coordination-patterns)
3. [Performance Patterns](#performance-patterns)
4. [Error Handling Patterns](#error-handling-patterns)
5. [Integration Patterns](#integration-patterns)
6. [Advanced Patterns](#advanced-patterns)

---

## Core Patterns

### 1. Sequential Pipeline Pattern

**When to use**: Linear workflows where each step depends on the previous one.

```typescript
// examples/patterns/sequential-pipeline.ts
import { useReactor } from '@nuxtops/reactor'

export async function createUserOnboardingPipeline() {
  const { createReactor } = useReactor()
  
  const reactor = createReactor('user-onboarding')
  
  // Input definition
  reactor.addInput({
    name: 'userData',
    type: 'object',
    required: true,
    description: 'User registration data'
  })
  
  // Sequential steps - each depends on previous
  reactor.addStep({
    name: 'validate-user-data',
    description: 'Validate user input data',
    arguments: {
      userData: { type: 'input', name: 'userData' }
    },
    async run({ userData }) {
      const errors = []
      if (!userData.email?.includes('@')) errors.push('Invalid email')
      if (!userData.password || userData.password.length < 8) errors.push('Password too short')
      
      if (errors.length > 0) {
        return { success: false, error: new Error(errors.join(', ')) }
      }
      
      return { success: true, data: { validatedUser: userData } }
    }
  })
  
  reactor.addStep({
    name: 'create-user-account',
    description: 'Create user in database',
    dependencies: ['validate-user-data'],
    arguments: {
      userData: { type: 'step', name: 'validate-user-data' }
    },
    async run({ userData }) {
      // Simulate database creation
      const userId = `user_${Date.now()}`
      await new Promise(resolve => setTimeout(resolve, 100))
      
      return { 
        success: true, 
        data: { 
          userId, 
          email: userData.validatedUser.email,
          createdAt: new Date().toISOString()
        }
      }
    },
    async compensate(error, { userData }) {
      console.log(`Rolling back user creation for ${userData.validatedUser?.email}`)
      return 'abort'
    }
  })
  
  reactor.addStep({
    name: 'send-welcome-email',
    description: 'Send welcome email to user',
    dependencies: ['create-user-account'],
    arguments: {
      user: { type: 'step', name: 'create-user-account' }
    },
    async run({ user }) {
      // Simulate email sending
      await new Promise(resolve => setTimeout(resolve, 200))
      
      return {
        success: true,
        data: { emailSent: true, emailId: `email_${Date.now()}` }
      }
    },
    async compensate(error, { user }) {
      console.log(`Failed to send welcome email to ${user.email}`)
      return 'continue' // Don't abort the whole process for email failure
    }
  })
  
  reactor.setReturn('create-user-account')
  return reactor
}

// Usage example
export async function onboardNewUser(userData: any) {
  const reactor = await createUserOnboardingPipeline()
  const result = await reactor.execute({ userData })
  
  if (result.state === 'completed') {
    return result.returnValue // User data from create-user-account step
  } else {
    throw new Error(`Onboarding failed: ${result.errors[0]?.message}`)
  }
}
```

### 2. Parallel Fan-Out Pattern

**When to use**: Independent operations that can run simultaneously.

```typescript
// examples/patterns/parallel-fanout.ts
import { useReactor, useMonitoring } from '@nuxtops/reactor'

export async function createDataAggregationReactor() {
  const { createReactor } = useReactor()
  const { recordExecution } = useMonitoring()
  
  const reactor = createReactor('data-aggregation')
  
  reactor.addInput({
    name: 'userId',
    type: 'string',
    required: true
  })
  
  // These steps run in parallel - no dependencies
  reactor.addStep({
    name: 'fetch-user-profile',
    description: 'Get user profile data',
    arguments: {
      userId: { type: 'input', name: 'userId' }
    },
    async run({ userId }) {
      await new Promise(resolve => setTimeout(resolve, 150))
      return {
        success: true,
        data: {
          name: 'John Doe',
          email: 'john@example.com',
          preferences: { theme: 'dark', notifications: true }
        }
      }
    }
  })
  
  reactor.addStep({
    name: 'fetch-user-orders',
    description: 'Get user order history',
    arguments: {
      userId: { type: 'input', name: 'userId' }
    },
    async run({ userId }) {
      await new Promise(resolve => setTimeout(resolve, 300))
      return {
        success: true,
        data: {
          orders: [
            { id: 'order1', total: 99.99, status: 'delivered' },
            { id: 'order2', total: 149.99, status: 'processing' }
          ],
          totalSpent: 249.98
        }
      }
    }
  })
  
  reactor.addStep({
    name: 'fetch-user-reviews',
    description: 'Get user reviews',
    arguments: {
      userId: { type: 'input', name: 'userId' }
    },
    async run({ userId }) {
      await new Promise(resolve => setTimeout(resolve, 100))
      return {
        success: true,
        data: {
          reviews: [
            { productId: 'prod1', rating: 5, comment: 'Great product!' }
          ],
          averageRating: 4.8
        }
      }
    }
  })
  
  // This step waits for all parallel steps to complete
  reactor.addStep({
    name: 'aggregate-user-data',
    description: 'Combine all user data',
    dependencies: ['fetch-user-profile', 'fetch-user-orders', 'fetch-user-reviews'],
    arguments: {
      profile: { type: 'step', name: 'fetch-user-profile' },
      orders: { type: 'step', name: 'fetch-user-orders' },
      reviews: { type: 'step', name: 'fetch-user-reviews' }
    },
    async run({ profile, orders, reviews }) {
      const aggregatedData = {
        profile: profile,
        orderSummary: {
          totalOrders: orders.orders.length,
          totalSpent: orders.totalSpent,
          recentOrder: orders.orders[0]
        },
        reviewSummary: {
          totalReviews: reviews.reviews.length,
          averageRating: reviews.averageRating
        },
        lastUpdated: new Date().toISOString()
      }
      
      return { success: true, data: aggregatedData }
    }
  })
  
  reactor.setReturn('aggregate-user-data')
  
  // Add monitoring middleware
  reactor.addMiddleware({
    name: 'performance-monitor',
    async afterReactor(context, result) {
      recordExecution(result)
    }
  })
  
  return reactor
}

// Usage with performance optimization
export async function getUserDashboardData(userId: string) {
  const reactor = await createDataAggregationReactor()
  
  const startTime = performance.now()
  const result = await reactor.execute({ userId })
  const duration = performance.now() - startTime
  
  console.log(`Data aggregation completed in ${duration.toFixed(2)}ms`)
  console.log(`Parallel execution saved ~${(400 - duration).toFixed(0)}ms`)
  
  return result.returnValue
}
```

### 3. Conditional Branch Pattern

**When to use**: Dynamic workflow paths based on runtime conditions.

```typescript
// examples/patterns/conditional-branch.ts
import { useReactor, useErrorBoundary } from '@nuxtops/reactor'

export async function createPaymentProcessingReactor() {
  const { createReactor } = useReactor()
  const { wrapStep } = useErrorBoundary({
    maxRetries: 3,
    retryDelay: 1000,
    enableFallback: true
  })
  
  const reactor = createReactor('payment-processing')
  
  reactor.addInput({
    name: 'orderData',
    type: 'object',
    required: true
  })
  
  // Step 1: Validate order
  reactor.addStep(wrapStep({
    name: 'validate-order',
    description: 'Validate order data and calculate totals',
    arguments: {
      order: { type: 'input', name: 'orderData' }
    },
    async run({ order }) {
      const { items, couponCode, customerType } = order
      
      let total = items.reduce((sum: number, item: any) => sum + (item.price * item.quantity), 0)
      let paymentMethod = 'credit_card' // default
      
      // Apply discounts based on customer type
      if (customerType === 'premium') {
        total *= 0.9 // 10% discount
        paymentMethod = 'priority_payment'
      } else if (customerType === 'enterprise') {
        total *= 0.8 // 20% discount
        paymentMethod = 'invoice'
      }
      
      // Apply coupon
      if (couponCode) {
        total *= 0.95 // 5% additional discount
      }
      
      return {
        success: true,
        data: {
          validatedOrder: order,
          total,
          paymentMethod,
          requiresApproval: total > 1000,
          isExpressEligible: customerType === 'premium' && total < 500
        }
      }
    }
  }))
  
  // Conditional Step 2a: Express processing (premium customers, small orders)
  reactor.addStep(wrapStep({
    name: 'express-payment',
    description: 'Fast payment processing for eligible orders',
    dependencies: ['validate-order'],
    arguments: {
      orderData: { type: 'step', name: 'validate-order' }
    },
    async run({ orderData }) {
      // Only run if express eligible
      if (!orderData.isExpressEligible) {
        return { success: true, data: { skipped: true } }
      }
      
      await new Promise(resolve => setTimeout(resolve, 100)) // Fast processing
      
      return {
        success: true,
        data: {
          paymentId: `express_${Date.now()}`,
          status: 'completed',
          processingTime: 100,
          method: 'express'
        }
      }
    }
  }))
  
  // Conditional Step 2b: Standard payment processing
  reactor.addStep(wrapStep({
    name: 'standard-payment',
    description: 'Standard payment processing',
    dependencies: ['validate-order'],
    arguments: {
      orderData: { type: 'step', name: 'validate-order' }
    },
    async run({ orderData }) {
      // Only run if not express eligible and doesn't require approval
      if (orderData.isExpressEligible || orderData.requiresApproval) {
        return { success: true, data: { skipped: true } }
      }
      
      await new Promise(resolve => setTimeout(resolve, 500)) // Standard processing time
      
      return {
        success: true,
        data: {
          paymentId: `std_${Date.now()}`,
          status: 'completed',
          processingTime: 500,
          method: orderData.paymentMethod
        }
      }
    }
  }))
  
  // Conditional Step 2c: Approval required
  reactor.addStep(wrapStep({
    name: 'request-approval',
    description: 'Request approval for high-value orders',
    dependencies: ['validate-order'],
    arguments: {
      orderData: { type: 'step', name: 'validate-order' }
    },
    async run({ orderData }) {
      // Only run if approval required
      if (!orderData.requiresApproval) {
        return { success: true, data: { skipped: true } }
      }
      
      // Simulate approval process
      await new Promise(resolve => setTimeout(resolve, 2000))
      
      const approved = Math.random() > 0.2 // 80% approval rate
      
      if (!approved) {
        return {
          success: false,
          error: new Error('Order requires manual approval - escalated to finance team')
        }
      }
      
      return {
        success: true,
        data: {
          approvalId: `approval_${Date.now()}`,
          approvedBy: 'system',
          approvalTime: 2000
        }
      }
    }
  }))
  
  // Step 3: Finalize payment (runs after any payment method)
  reactor.addStep(wrapStep({
    name: 'finalize-payment',
    description: 'Finalize payment and send confirmation',
    dependencies: ['express-payment', 'standard-payment', 'request-approval'],
    arguments: {
      orderData: { type: 'step', name: 'validate-order' },
      expressResult: { type: 'step', name: 'express-payment' },
      standardResult: { type: 'step', name: 'standard-payment' },
      approvalResult: { type: 'step', name: 'request-approval' }
    },
    async run({ orderData, expressResult, standardResult, approvalResult }) {
      let paymentResult
      let processingPath
      
      // Determine which path was taken
      if (expressResult && !expressResult.skipped) {
        paymentResult = expressResult
        processingPath = 'express'
      } else if (standardResult && !standardResult.skipped) {
        paymentResult = standardResult
        processingPath = 'standard'
      } else if (approvalResult && !approvalResult.skipped) {
        // Still need to process payment after approval
        await new Promise(resolve => setTimeout(resolve, 800))
        paymentResult = {
          paymentId: `approved_${Date.now()}`,
          status: 'completed',
          processingTime: 800,
          method: orderData.paymentMethod,
          approvalId: approvalResult.approvalId
        }
        processingPath = 'approved'
      } else {
        throw new Error('No payment path was executed')
      }
      
      return {
        success: true,
        data: {
          orderId: `order_${Date.now()}`,
          payment: paymentResult,
          total: orderData.total,
          processingPath,
          completedAt: new Date().toISOString()
        }
      }
    }
  }))
  
  reactor.setReturn('finalize-payment')
  return reactor
}

// Usage example with different customer types
export async function processOrders() {
  const reactor = await createPaymentProcessingReactor()
  
  // Test different scenarios
  const scenarios = [
    {
      name: 'Premium Express',
      orderData: {
        items: [{ price: 100, quantity: 2 }],
        customerType: 'premium',
        couponCode: 'SAVE5'
      }
    },
    {
      name: 'Standard Order',
      orderData: {
        items: [{ price: 50, quantity: 3 }],
        customerType: 'regular'
      }
    },
    {
      name: 'High Value Order',
      orderData: {
        items: [{ price: 800, quantity: 2 }],
        customerType: 'enterprise',
        couponCode: 'ENTERPRISE20'
      }
    }
  ]
  
  for (const scenario of scenarios) {
    console.log(`\n--- Processing ${scenario.name} ---`)
    const result = await reactor.execute(scenario.orderData)
    
    if (result.state === 'completed') {
      const data = result.returnValue
      console.log(`✅ Order processed via ${data.processingPath} path`)
      console.log(`💰 Total: $${data.total}`)
      console.log(`🔄 Processing time: ${data.payment.processingTime}ms`)
    } else {
      console.log(`❌ Order failed: ${result.errors[0]?.message}`)
    }
  }
}
```

---

## Coordination Patterns

### 4. Leader Election Pattern

**When to use**: Distributed systems where one agent needs to coordinate others.

```typescript
// examples/patterns/leader-election.ts
import { useReactor, useErrorBoundary } from '@nuxtops/reactor'

interface AgentInfo {
  id: string
  priority: number
  lastHeartbeat: number
  capabilities: string[]
}

export async function createLeaderElectionReactor() {
  const { createReactor } = useReactor()
  const { wrapStep } = useErrorBoundary()
  
  const reactor = createReactor('leader-election')
  
  reactor.addInput({
    name: 'agents',
    type: 'array',
    required: true,
    description: 'Array of agent information'
  })
  
  reactor.addInput({
    name: 'currentLeader',
    type: 'string',
    required: false,
    description: 'Current leader ID if any'
  })
  
  // Step 1: Health check all agents
  reactor.addStep(wrapStep({
    name: 'health-check-agents',
    description: 'Check health status of all agents',
    arguments: {
      agents: { type: 'input', name: 'agents' }
    },
    async run({ agents }) {
      const healthyAgents: AgentInfo[] = []
      const unhealthyAgents: string[] = []
      const currentTime = Date.now()
      
      for (const agent of agents) {
        const timeSinceHeartbeat = currentTime - agent.lastHeartbeat
        
        if (timeSinceHeartbeat < 30000) { // 30 seconds timeout
          healthyAgents.push(agent)
        } else {
          unhealthyAgents.push(agent.id)
        }
      }
      
      return {
        success: true,
        data: {
          healthyAgents,
          unhealthyAgents,
          totalHealthy: healthyAgents.length
        }
      }
    }
  }))
  
  // Step 2: Validate current leader
  reactor.addStep(wrapStep({
    name: 'validate-current-leader',
    description: 'Check if current leader is still healthy',
    dependencies: ['health-check-agents'],
    arguments: {
      currentLeader: { type: 'input', name: 'currentLeader' },
      healthCheck: { type: 'step', name: 'health-check-agents' }
    },
    async run({ currentLeader, healthCheck }) {
      const { healthyAgents, unhealthyAgents } = healthCheck
      
      let leaderValid = false
      let currentLeaderInfo = null
      
      if (currentLeader) {
        currentLeaderInfo = healthyAgents.find((agent: AgentInfo) => agent.id === currentLeader)
        leaderValid = !!currentLeaderInfo && !unhealthyAgents.includes(currentLeader)
      }
      
      return {
        success: true,
        data: {
          leaderValid,
          currentLeaderInfo,
          needsElection: !leaderValid || !currentLeader
        }
      }
    }
  }))
  
  // Step 3: Conduct election if needed
  reactor.addStep(wrapStep({
    name: 'conduct-election',
    description: 'Elect new leader based on priority and capabilities',
    dependencies: ['validate-current-leader'],
    arguments: {
      healthCheck: { type: 'step', name: 'health-check-agents' },
      leaderValidation: { type: 'step', name: 'validate-current-leader' }
    },
    async run({ healthCheck, leaderValidation }) {
      const { healthyAgents } = healthCheck
      const { needsElection, currentLeaderInfo } = leaderValidation
      
      if (!needsElection) {
        return {
          success: true,
          data: {
            leader: currentLeaderInfo,
            electionConducted: false,
            reason: 'Current leader is healthy'
          }
        }
      }
      
      if (healthyAgents.length === 0) {
        return {
          success: false,
          error: new Error('No healthy agents available for leadership')
        }
      }
      
      // Election algorithm: highest priority, then by capabilities, then by ID (for consistency)
      const candidates = [...healthyAgents].sort((a: AgentInfo, b: AgentInfo) => {
        // First sort by priority (higher is better)
        if (a.priority !== b.priority) {
          return b.priority - a.priority
        }
        
        // Then by number of capabilities (more is better)
        if (a.capabilities.length !== b.capabilities.length) {
          return b.capabilities.length - a.capabilities.length
        }
        
        // Finally by ID for consistency
        return a.id.localeCompare(b.id)
      })
      
      const newLeader = candidates[0]
      
      return {
        success: true,
        data: {
          leader: newLeader,
          electionConducted: true,
          candidates: candidates.length,
          reason: needsElection ? 'Leader election required' : 'Current leader unhealthy'
        }
      }
    }
  }))
  
  // Step 4: Notify agents of leadership change
  reactor.addStep(wrapStep({
    name: 'notify-leadership-change',
    description: 'Inform all agents of the leadership result',
    dependencies: ['conduct-election'],
    arguments: {
      healthCheck: { type: 'step', name: 'health-check-agents' },
      election: { type: 'step', name: 'conduct-election' }
    },
    async run({ healthCheck, election }) {
      const { healthyAgents } = healthCheck
      const { leader, electionConducted } = election
      
      const notifications = []
      
      // Simulate notifying each agent
      for (const agent of healthyAgents) {
        const notification = {
          agentId: agent.id,
          message: electionConducted 
            ? `New leader elected: ${leader.id}` 
            : `Leader confirmed: ${leader.id}`,
          timestamp: Date.now(),
          isLeader: agent.id === leader.id
        }
        
        notifications.push(notification)
        
        // Simulate network delay
        await new Promise(resolve => setTimeout(resolve, 10))
      }
      
      return {
        success: true,
        data: {
          notificationsSent: notifications.length,
          notifications,
          newLeaderId: leader.id
        }
      }
    }
  }))
  
  reactor.setReturn('notify-leadership-change')
  return reactor
}

// Agent coordination system
export class AgentCoordinator {
  private agents: Map<string, AgentInfo> = new Map()
  private currentLeader: string | null = null
  private electionInProgress = false
  
  addAgent(id: string, priority: number, capabilities: string[]) {
    this.agents.set(id, {
      id,
      priority,
      lastHeartbeat: Date.now(),
      capabilities
    })
  }
  
  updateHeartbeat(agentId: string) {
    const agent = this.agents.get(agentId)
    if (agent) {
      agent.lastHeartbeat = Date.now()
    }
  }
  
  async electLeader() {
    if (this.electionInProgress) {
      console.log('Election already in progress')
      return
    }
    
    this.electionInProgress = true
    
    try {
      const reactor = await createLeaderElectionReactor()
      const result = await reactor.execute({
        agents: Array.from(this.agents.values()),
        currentLeader: this.currentLeader
      })
      
      if (result.state === 'completed') {
        const data = result.returnValue
        const previousLeader = this.currentLeader
        this.currentLeader = data.newLeaderId
        
        console.log(`🏆 Leadership result:`)
        console.log(`   Previous: ${previousLeader || 'none'}`)
        console.log(`   Current: ${this.currentLeader}`)
        console.log(`   Election conducted: ${data.election.electionConducted}`)
        console.log(`   Notifications sent: ${data.notificationsSent}`)
        
        return {
          leader: data.newLeaderId,
          changed: previousLeader !== this.currentLeader,
          notifications: data.notifications
        }
      } else {
        throw new Error(`Election failed: ${result.errors[0]?.message}`)
      }
    } finally {
      this.electionInProgress = false
    }
  }
  
  getLeader() {
    return this.currentLeader
  }
  
  getAgents() {
    return Array.from(this.agents.values())
  }
}

// Usage example
export async function demonstrateLeaderElection() {
  const coordinator = new AgentCoordinator()
  
  // Add agents with different priorities and capabilities
  coordinator.addAgent('agent-alpha', 10, ['processing', 'coordination', 'monitoring'])
  coordinator.addAgent('agent-beta', 8, ['processing', 'storage'])
  coordinator.addAgent('agent-gamma', 12, ['coordination', 'analytics'])
  coordinator.addAgent('agent-delta', 6, ['processing'])
  
  console.log('🚀 Initial election:')
  await coordinator.electLeader()
  
  // Simulate heartbeats
  setInterval(() => {
    for (const agent of coordinator.getAgents()) {
      if (Math.random() > 0.1) { // 90% uptime
        coordinator.updateHeartbeat(agent.id)
      }
    }
  }, 5000)
  
  // Periodic re-election check
  setInterval(async () => {
    console.log('\n🔄 Checking leadership...')
    await coordinator.electLeader()
  }, 10000)
}
```

### 5. Work Distribution Pattern

**When to use**: Distributing tasks across multiple agents or workers.

```typescript
// examples/patterns/work-distribution.ts
import { useReactor, useSPR, useMonitoring } from '@nuxtops/reactor'

interface WorkItem {
  id: string
  type: 'cpu_intensive' | 'io_intensive' | 'memory_intensive'
  priority: 'low' | 'medium' | 'high' | 'urgent'
  estimatedDuration: number
  payload: any
}

interface Worker {
  id: string
  capabilities: string[]
  currentLoad: number
  maxCapacity: number
  performance: {
    averageTaskTime: number
    successRate: number
    specializations: string[]
  }
}

export async function createWorkDistributionReactor() {
  const { createReactor } = useReactor()
  const { analyzeWorkflow } = useSPR()
  const { recordExecution } = useMonitoring()
  
  const reactor = createReactor('work-distribution')
  
  reactor.addInput({
    name: 'workItems',
    type: 'array',
    required: true,
    description: 'Array of work items to distribute'
  })
  
  reactor.addInput({
    name: 'workers',
    type: 'array',
    required: true,
    description: 'Available workers'
  })
  
  // Step 1: Analyze work patterns
  reactor.addStep({
    name: 'analyze-work-patterns',
    description: 'Analyze work items for optimal distribution',
    arguments: {
      workItems: { type: 'input', name: 'workItems' }
    },
    async run({ workItems }) {
      const analysis = {
        totalItems: workItems.length,
        byType: {} as Record<string, number>,
        byPriority: {} as Record<string, number>,
        totalEstimatedTime: 0,
        complexityScore: 0
      }
      
      for (const item of workItems) {
        // Count by type
        analysis.byType[item.type] = (analysis.byType[item.type] || 0) + 1
        
        // Count by priority
        analysis.byPriority[item.priority] = (analysis.byPriority[item.priority] || 0) + 1
        
        // Sum estimated time
        analysis.totalEstimatedTime += item.estimatedDuration
        
        // Calculate complexity score
        const priorityWeight = { urgent: 4, high: 3, medium: 2, low: 1 }
        const typeWeight = { cpu_intensive: 3, memory_intensive: 2, io_intensive: 1 }
        
        analysis.complexityScore += priorityWeight[item.priority] * typeWeight[item.type]
      }
      
      return { success: true, data: analysis }
    }
  })
  
  // Step 2: Evaluate worker capabilities
  reactor.addStep({
    name: 'evaluate-workers',
    description: 'Assess worker capabilities and current load',
    dependencies: ['analyze-work-patterns'],
    arguments: {
      workers: { type: 'input', name: 'workers' },
      workAnalysis: { type: 'step', name: 'analyze-work-patterns' }
    },
    async run({ workers, workAnalysis }) {
      const workerEvaluations = workers.map((worker: Worker) => {
        const availableCapacity = worker.maxCapacity - worker.currentLoad
        const utilizationRate = worker.currentLoad / worker.maxCapacity
        
        // Calculate efficiency score based on performance metrics
        const efficiencyScore = (
          worker.performance.successRate * 0.5 +
          (1 / Math.max(worker.performance.averageTaskTime, 1)) * 0.3 +
          worker.capabilities.length * 0.2
        )
        
        // Calculate suitability for current workload
        const suitabilityScore = worker.capabilities.reduce((score, capability) => {
          if (workAnalysis.byType[capability]) {
            return score + (workAnalysis.byType[capability] / workAnalysis.totalItems)
          }
          return score
        }, 0)
        
        return {
          ...worker,
          availableCapacity,
          utilizationRate,
          efficiencyScore,
          suitabilityScore,
          recommendedLoad: Math.floor(availableCapacity * efficiencyScore)
        }
      })
      
      // Sort by overall score (efficiency + suitability - utilization)
      workerEvaluations.sort((a, b) => {
        const scoreA = a.efficiencyScore + a.suitabilityScore - a.utilizationRate
        const scoreB = b.efficiencyScore + b.suitabilityScore - b.utilizationRate
        return scoreB - scoreA
      })
      
      return {
        success: true,
        data: {
          evaluatedWorkers: workerEvaluations,
          totalAvailableCapacity: workerEvaluations.reduce((sum, w) => sum + w.availableCapacity, 0),
          averageUtilization: workerEvaluations.reduce((sum, w) => sum + w.utilizationRate, 0) / workerEvaluations.length
        }
      }
    }
  })
  
  // Step 3: Create optimal work assignments
  reactor.addStep({
    name: 'create-assignments',
    description: 'Distribute work items optimally across workers',
    dependencies: ['evaluate-workers'],
    arguments: {
      workItems: { type: 'input', name: 'workItems' },
      workerEval: { type: 'step', name: 'evaluate-workers' }
    },
    async run({ workItems, workerEval }) {
      const { evaluatedWorkers } = workerEval
      const assignments: Record<string, WorkItem[]> = {}
      const workerLoads: Record<string, number> = {}
      
      // Initialize assignments
      evaluatedWorkers.forEach(worker => {
        assignments[worker.id] = []
        workerLoads[worker.id] = worker.currentLoad
      })
      
      // Sort work items by priority and complexity
      const sortedWorkItems = [...workItems].sort((a, b) => {
        const priorityOrder = { urgent: 4, high: 3, medium: 2, low: 1 }
        const priorityDiff = priorityOrder[b.priority] - priorityOrder[a.priority]
        
        if (priorityDiff !== 0) return priorityDiff
        
        // Secondary sort by estimated duration (longer tasks first for better packing)
        return b.estimatedDuration - a.estimatedDuration
      })
      
      // Assign work items using a smart allocation algorithm
      for (const workItem of sortedWorkItems) {
        let bestWorker = null
        let bestScore = -1
        
        for (const worker of evaluatedWorkers) {
          // Check if worker can handle this work type
          const canHandle = worker.capabilities.includes(workItem.type) || 
                           worker.capabilities.includes('general')
          
          if (!canHandle) continue
          
          // Check if worker has capacity
          const wouldExceedCapacity = workerLoads[worker.id] + workItem.estimatedDuration > worker.maxCapacity
          if (wouldExceedCapacity) continue
          
          // Calculate assignment score
          let score = worker.efficiencyScore + worker.suitabilityScore
          
          // Bonus for specialization
          if (worker.performance.specializations.includes(workItem.type)) {
            score += 0.5
          }
          
          // Penalty for high utilization (load balancing)
          const newUtilization = (workerLoads[worker.id] + workItem.estimatedDuration) / worker.maxCapacity
          score -= newUtilization * 0.3
          
          // Priority bonus
          const priorityBonus = { urgent: 0.3, high: 0.2, medium: 0.1, low: 0 }
          score += priorityBonus[workItem.priority]
          
          if (score > bestScore) {
            bestScore = score
            bestWorker = worker
          }
        }
        
        if (bestWorker) {
          assignments[bestWorker.id].push(workItem)
          workerLoads[bestWorker.id] += workItem.estimatedDuration
        } else {
          // No worker available - this item will be queued
          assignments['queue'] = assignments['queue'] || []
          assignments['queue'].push(workItem)
        }
      }
      
      // Calculate distribution metrics
      const distributionMetrics = {
        assignedItems: Object.values(assignments).flat().length - (assignments['queue']?.length || 0),
        queuedItems: assignments['queue']?.length || 0,
        workerUtilization: Object.entries(workerLoads).map(([workerId, load]) => {
          const worker = evaluatedWorkers.find(w => w.id === workerId)
          return {
            workerId,
            load,
            utilization: worker ? load / worker.maxCapacity : 0,
            assignedTasks: assignments[workerId].length
          }
        }),
        loadBalance: this.calculateLoadBalance(Object.values(workerLoads))
      }
      
      return {
        success: true,
        data: {
          assignments,
          metrics: distributionMetrics,
          optimization: {
            efficiencyScore: this.calculateEfficiencyScore(assignments, evaluatedWorkers),
            balanceScore: distributionMetrics.loadBalance
          }
        }
      }
    },
    
    // Helper methods for the step
    calculateLoadBalance(loads: number[]) {
      if (loads.length === 0) return 1
      
      const mean = loads.reduce((sum, load) => sum + load, 0) / loads.length
      const variance = loads.reduce((sum, load) => sum + Math.pow(load - mean, 2), 0) / loads.length
      
      // Return a score from 0 to 1, where 1 is perfectly balanced
      return Math.max(0, 1 - (Math.sqrt(variance) / mean))
    },
    
    calculateEfficiencyScore(assignments: Record<string, WorkItem[]>, workers: any[]) {
      let totalScore = 0
      let totalItems = 0
      
      for (const worker of workers) {
        const workerTasks = assignments[worker.id] || []
        for (const task of workerTasks) {
          // Score based on worker-task compatibility
          let taskScore = worker.efficiencyScore
          
          if (worker.capabilities.includes(task.type)) {
            taskScore += 0.3
          }
          
          if (worker.performance.specializations.includes(task.type)) {
            taskScore += 0.5
          }
          
          totalScore += taskScore
          totalItems++
        }
      }
      
      return totalItems > 0 ? totalScore / totalItems : 0
    }
  })
  
  // Step 4: Execute work distribution
  reactor.addStep({
    name: 'execute-distribution',
    description: 'Send work assignments to workers and track progress',
    dependencies: ['create-assignments'],
    arguments: {
      assignments: { type: 'step', name: 'create-assignments' }
    },
    async run({ assignments }) {
      const { assignments: workAssignments, metrics } = assignments
      const executionResults = []
      
      // Simulate sending work to each worker
      for (const [workerId, tasks] of Object.entries(workAssignments)) {
        if (workerId === 'queue') continue // Skip queued items
        
        const workerResult = {
          workerId,
          tasksAssigned: tasks.length,
          estimatedDuration: tasks.reduce((sum: number, task: WorkItem) => sum + task.estimatedDuration, 0),
          taskIds: tasks.map((task: WorkItem) => task.id),
          assignedAt: Date.now()
        }
        
        executionResults.push(workerResult)
        
        // Simulate network delay
        await new Promise(resolve => setTimeout(resolve, 10))
      }
      
      return {
        success: true,
        data: {
          distributionComplete: true,
          workersNotified: executionResults.length,
          results: executionResults,
          queuedItems: workAssignments['queue']?.length || 0,
          distributionMetrics: metrics
        }
      }
    }
  })
  
  reactor.setReturn('execute-distribution')
  
  // Add SPR optimization and monitoring
  reactor.addMiddleware({
    name: 'spr-optimization',
    async beforeReactor(context) {
      const compression = await analyzeWorkflow(reactor)
      context.sprOptimization = compression
    }
  })
  
  reactor.addMiddleware({
    name: 'performance-tracking',
    async afterReactor(context, result) {
      recordExecution(result)
    }
  })
  
  return reactor
}

// Usage example with realistic scenario
export async function distributeDataProcessingWork() {
  const reactor = await createWorkDistributionReactor()
  
  // Sample work items
  const workItems: WorkItem[] = [
    { id: 'task-1', type: 'cpu_intensive', priority: 'high', estimatedDuration: 300, payload: { data: 'large_dataset_1' } },
    { id: 'task-2', type: 'io_intensive', priority: 'medium', estimatedDuration: 150, payload: { file: 'process_logs.txt' } },
    { id: 'task-3', type: 'memory_intensive', priority: 'urgent', estimatedDuration: 200, payload: { cache: 'rebuild_index' } },
    { id: 'task-4', type: 'cpu_intensive', priority: 'low', estimatedDuration: 500, payload: { data: 'batch_analysis' } },
    { id: 'task-5', type: 'io_intensive', priority: 'high', estimatedDuration: 100, payload: { sync: 'database_backup' } },
    { id: 'task-6', type: 'cpu_intensive', priority: 'medium', estimatedDuration: 250, payload: { ml: 'model_training' } }
  ]
  
  // Sample workers
  const workers: Worker[] = [
    {
      id: 'worker-cpu-1',
      capabilities: ['cpu_intensive', 'general'],
      currentLoad: 100,
      maxCapacity: 1000,
      performance: {
        averageTaskTime: 180,
        successRate: 0.95,
        specializations: ['cpu_intensive']
      }
    },
    {
      id: 'worker-io-1',
      capabilities: ['io_intensive', 'memory_intensive'],
      currentLoad: 50,
      maxCapacity: 800,
      performance: {
        averageTaskTime: 120,
        successRate: 0.98,
        specializations: ['io_intensive']
      }
    },
    {
      id: 'worker-general-1',
      capabilities: ['general', 'cpu_intensive', 'io_intensive'],
      currentLoad: 200,
      maxCapacity: 1200,
      performance: {
        averageTaskTime: 200,
        successRate: 0.92,
        specializations: []
      }
    },
    {
      id: 'worker-memory-1',
      capabilities: ['memory_intensive', 'cpu_intensive'],
      currentLoad: 0,
      maxCapacity: 600,
      performance: {
        averageTaskTime: 150,
        successRate: 0.97,
        specializations: ['memory_intensive']
      }
    }
  ]
  
  console.log('🚀 Distributing work across workers...')
  
  const result = await reactor.execute({ workItems, workers })
  
  if (result.state === 'completed') {
    const data = result.returnValue
    
    console.log('\n📊 Distribution Results:')
    console.log(`✅ Workers notified: ${data.workersNotified}`)
    console.log(`📋 Items queued: ${data.queuedItems}`)
    console.log(`⚡ Efficiency score: ${data.distributionMetrics.optimization.efficiencyScore.toFixed(2)}`)
    console.log(`⚖️ Balance score: ${data.distributionMetrics.optimization.balanceScore.toFixed(2)}`)
    
    console.log('\n👥 Worker Assignments:')
    data.results.forEach((workerResult: any) => {
      console.log(`   ${workerResult.workerId}: ${workerResult.tasksAssigned} tasks (${workerResult.estimatedDuration}ms estimated)`)
    })
    
    console.log('\n📈 Worker Utilization:')
    data.distributionMetrics.workerUtilization.forEach((util: any) => {
      console.log(`   ${util.workerId}: ${(util.utilization * 100).toFixed(1)}% (${util.assignedTasks} tasks)`)
    })
    
    return data
  } else {
    console.error('❌ Work distribution failed:', result.errors[0]?.message)
    throw new Error('Distribution failed')
  }
}
```

---

## Performance Patterns

### 6. Caching Strategy Pattern

**When to use**: Optimizing repeated operations and expensive computations.

```typescript
// examples/patterns/caching-strategy.ts
import { useReactor, useSPR, useMonitoring } from '@nuxtops/reactor'

interface CacheEntry<T = any> {
  key: string
  value: T
  timestamp: number
  accessCount: number
  lastAccessed: number
  ttl?: number
  tags?: string[]
}

interface CacheStats {
  hits: number
  misses: number
  hitRate: number
  totalSize: number
  evictions: number
}

export class ReactorCache {
  private cache = new Map<string, CacheEntry>()
  private stats: CacheStats = { hits: 0, misses: 0, hitRate: 0, totalSize: 0, evictions: 0 }
  private maxSize: number
  private defaultTTL: number
  
  constructor(maxSize = 1000, defaultTTL = 300000) { // 5 minutes default
    this.maxSize = maxSize
    this.defaultTTL = defaultTTL
  }
  
  get<T>(key: string): T | null {
    const entry = this.cache.get(key)
    
    if (!entry) {
      this.stats.misses++
      this.updateHitRate()
      return null
    }
    
    // Check TTL
    if (entry.ttl && Date.now() - entry.timestamp > entry.ttl) {
      this.cache.delete(key)
      this.stats.misses++
      this.updateHitRate()
      return null
    }
    
    // Update access stats
    entry.accessCount++
    entry.lastAccessed = Date.now()
    this.stats.hits++
    this.updateHitRate()
    
    return entry.value as T
  }
  
  set<T>(key: string, value: T, ttl?: number, tags?: string[]): void {
    // Evict if at capacity
    if (this.cache.size >= this.maxSize) {
      this.evictLRU()
    }
    
    const entry: CacheEntry<T> = {
      key,
      value,
      timestamp: Date.now(),
      accessCount: 1,
      lastAccessed: Date.now(),
      ttl: ttl || this.defaultTTL,
      tags
    }
    
    this.cache.set(key, entry)
    this.stats.totalSize = this.cache.size
  }
  
  invalidateByTag(tag: string): number {
    let invalidated = 0
    
    for (const [key, entry] of this.cache.entries()) {
      if (entry.tags?.includes(tag)) {
        this.cache.delete(key)
        invalidated++
      }
    }
    
    this.stats.totalSize = this.cache.size
    return invalidated
  }
  
  private evictLRU(): void {
    let oldestEntry: [string, CacheEntry] | null = null
    
    for (const entry of this.cache.entries()) {
      if (!oldestEntry || entry[1].lastAccessed < oldestEntry[1].lastAccessed) {
        oldestEntry = entry
      }
    }
    
    if (oldestEntry) {
      this.cache.delete(oldestEntry[0])
      this.stats.evictions++
    }
  }
  
  private updateHitRate(): void {
    const total = this.stats.hits + this.stats.misses
    this.stats.hitRate = total > 0 ? this.stats.hits / total : 0
  }
  
  getStats(): CacheStats {
    return { ...this.stats }
  }
  
  clear(): void {
    this.cache.clear()
    this.stats = { hits: 0, misses: 0, hitRate: 0, totalSize: 0, evictions: 0 }
  }
}

export async function createCachingReactor() {
  const { createReactor } = useReactor()
  const { analyzeWorkflow } = useSPR()
  const { recordExecution } = useMonitoring()
  
  const cache = new ReactorCache(500, 600000) // 500 items, 10-minute TTL
  const reactor = createReactor('caching-strategy')
  
  reactor.addInput({
    name: 'requests',
    type: 'array',
    required: true,
    description: 'Array of data requests to process'
  })
  
  // Step 1: Analyze cache requirements
  reactor.addStep({
    name: 'analyze-cache-requirements',
    description: 'Analyze requests for caching strategy',
    arguments: {
      requests: { type: 'input', name: 'requests' }
    },
    async run({ requests }) {
      const analysis = {
        totalRequests: requests.length,
        uniqueRequests: new Set(requests.map((r: any) => r.key)).size,
        requestTypes: {} as Record<string, number>,
        duplicateRequests: [] as any[],
        cacheableRequests: [] as any[],
        nonCacheableRequests: [] as any[]
      }
      
      const requestCounts = new Map<string, number>()
      
      for (const request of requests) {
        // Count request types
        analysis.requestTypes[request.type] = (analysis.requestTypes[request.type] || 0) + 1
        
        // Track duplicates
        const count = requestCounts.get(request.key) || 0
        requestCounts.set(request.key, count + 1)
        
        if (count > 0) {
          analysis.duplicateRequests.push(request)
        }
        
        // Categorize by cacheability
        if (request.cacheable !== false && request.method !== 'POST') {
          analysis.cacheableRequests.push(request)
        } else {
          analysis.nonCacheableRequests.push(request)
        }
      }
      
      analysis.duplicateRequests = Array.from(requestCounts.entries())
        .filter(([_, count]) => count > 1)
        .map(([key, count]) => ({ key, count }))
      
      return {
        success: true,
        data: {
          ...analysis,
          cacheHitPotential: analysis.duplicateRequests.length / analysis.totalRequests,
          recommendedStrategy: analysis.cacheHitPotential > 0.3 ? 'aggressive' : 'conservative'
        }
      }
    }
  })
  
  // Step 2: Execute requests with caching
  reactor.addStep({
    name: 'execute-with-caching',
    description: 'Process requests using intelligent caching',
    dependencies: ['analyze-cache-requirements'],
    arguments: {
      requests: { type: 'input', name: 'requests' },
      analysis: { type: 'step', name: 'analyze-cache-requirements' }
    },
    async run({ requests, analysis }) {
      const results = []
      const cacheableRequests = analysis.cacheableRequests
      const strategy = analysis.recommendedStrategy
      
      console.log(`🎯 Using ${strategy} caching strategy`)
      
      for (const request of requests) {
        const startTime = performance.now()
        let result
        let fromCache = false
        
        // Check if request is cacheable
        if (cacheableRequests.some((cr: any) => cr.key === request.key)) {
          // Try cache first
          const cached = cache.get(request.key)
          
          if (cached) {
            result = cached
            fromCache = true
          } else {
            // Execute and cache
            result = await this.executeRequest(request)
            
            // Determine TTL based on request type and strategy
            let ttl = 300000 // 5 minutes default
            
            if (strategy === 'aggressive') {
              ttl = request.type === 'user_data' ? 600000 : 1800000 // 10min or 30min
            } else {
              ttl = request.type === 'static_data' ? 3600000 : 300000 // 1hour or 5min
            }
            
            // Set cache tags for easy invalidation
            const tags = [request.type]
            if (request.userId) tags.push(`user:${request.userId}`)
            if (request.category) tags.push(`category:${request.category}`)
            
            cache.set(request.key, result, ttl, tags)
          }
        } else {
          // Execute without caching
          result = await this.executeRequest(request)
        }
        
        const duration = performance.now() - startTime
        
        results.push({
          request: request.key,
          result,
          fromCache,
          duration,
          type: request.type
        })
      }
      
      return {
        success: true,
        data: {
          results,
          cacheStats: cache.getStats(),
          performance: {
            totalTime: results.reduce((sum, r) => sum + r.duration, 0),
            averageTime: results.reduce((sum, r) => sum + r.duration, 0) / results.length,
            cacheHits: results.filter(r => r.fromCache).length,
            cacheMisses: results.filter(r => !r.fromCache).length
          }
        }
      }
    },
    
    // Helper method for request execution
    async executeRequest(request: any) {
      // Simulate different types of expensive operations
      switch (request.type) {
        case 'database_query':
          await new Promise(resolve => setTimeout(resolve, 100 + Math.random() * 200))
          return { data: `DB result for ${request.key}`, timestamp: Date.now() }
          
        case 'api_call':
          await new Promise(resolve => setTimeout(resolve, 200 + Math.random() * 300))
          return { data: `API response for ${request.key}`, timestamp: Date.now() }
          
        case 'file_processing':
          await new Promise(resolve => setTimeout(resolve, 500 + Math.random() * 1000))
          return { data: `Processed file ${request.key}`, size: Math.floor(Math.random() * 10000) }
          
        case 'computation':
          await new Promise(resolve => setTimeout(resolve, 300 + Math.random() * 700))
          return { data: `Computed ${request.key}`, result: Math.random() * 1000 }
          
        default:
          await new Promise(resolve => setTimeout(resolve, 150))
          return { data: `Result for ${request.key}` }
      }
    }
  })
  
  // Step 3: Optimize cache performance
  reactor.addStep({
    name: 'optimize-cache',
    description: 'Analyze and optimize cache performance',
    dependencies: ['execute-with-caching'],
    arguments: {
      execution: { type: 'step', name: 'execute-with-caching' }
    },
    async run({ execution }) {
      const { results, cacheStats, performance } = execution
      
      // Analyze cache effectiveness
      const optimization = {
        currentHitRate: cacheStats.hitRate,
        timesSaved: results.filter((r: any) => r.fromCache).length * 200, // Average time saved per cache hit
        recommendations: [] as string[]
      }
      
      // Generate optimization recommendations
      if (cacheStats.hitRate < 0.3) {
        optimization.recommendations.push('Consider increasing cache TTL for frequently accessed data')
      }
      
      if (cacheStats.evictions > cacheStats.hits * 0.1) {
        optimization.recommendations.push('Consider increasing cache size to reduce evictions')
      }
      
      if (performance.cacheHits < performance.cacheMisses) {
        optimization.recommendations.push('Review cacheability criteria - more requests could be cached')
      }
      
      // Auto-tune cache settings based on patterns
      const tuning = {
        recommendedCacheSize: Math.max(500, cacheStats.totalSize * 1.5),
        recommendedTTL: cacheStats.hitRate > 0.7 ? 900000 : 300000, // Increase TTL if high hit rate
        suggestedInvalidationTags: this.identifyHotTags(results)
      }
      
      return {
        success: true,
        data: {
          optimization,
          tuning,
          performanceGain: `${((optimization.timesSaved / performance.totalTime) * 100).toFixed(1)}%`,
          cacheEfficiency: cacheStats.hitRate
        }
      }
    },
    
    // Helper to identify frequently accessed cache tags
    identifyHotTags(results: any[]) {
      const tagFrequency = new Map<string, number>()
      
      results.forEach(result => {
        if (result.fromCache && result.request.includes(':')) {
          const tag = result.request.split(':')[0]
          tagFrequency.set(tag, (tagFrequency.get(tag) || 0) + 1)
        }
      })
      
      return Array.from(tagFrequency.entries())
        .sort(([, a], [, b]) => b - a)
        .slice(0, 5)
        .map(([tag]) => tag)
    }
  })
  
  reactor.setReturn('optimize-cache')
  
  // Add performance monitoring
  reactor.addMiddleware({
    name: 'cache-monitoring',
    async afterReactor(context, result) {
      const stats = cache.getStats()
      console.log(`📊 Cache Performance: ${(stats.hitRate * 100).toFixed(1)}% hit rate, ${stats.totalSize} items`)
      recordExecution(result)
    }
  })
  
  return { reactor, cache }
}

// Advanced cache invalidation reactor
export async function createCacheInvalidationReactor() {
  const { createReactor } = useReactor()
  
  const reactor = createReactor('cache-invalidation')
  
  reactor.addInput({
    name: 'invalidationRules',
    type: 'array',
    required: true,
    description: 'Rules for cache invalidation'
  })
  
  reactor.addInput({
    name: 'cache',
    type: 'object',
    required: true,
    description: 'Cache instance to invalidate'
  })
  
  reactor.addStep({
    name: 'process-invalidation-rules',
    description: 'Process cache invalidation based on rules',
    arguments: {
      rules: { type: 'input', name: 'invalidationRules' },
      cache: { type: 'input', name: 'cache' }
    },
    async run({ rules, cache }) {
      const invalidationResults = []
      
      for (const rule of rules) {
        let invalidatedCount = 0
        
        switch (rule.type) {
          case 'tag_based':
            invalidatedCount = cache.invalidateByTag(rule.tag)
            break
            
          case 'time_based':
            // Invalidate entries older than specified time
            const cutoffTime = Date.now() - rule.maxAge
            for (const [key, entry] of cache.cache.entries()) {
              if (entry.timestamp < cutoffTime) {
                cache.cache.delete(key)
                invalidatedCount++
              }
            }
            break
            
          case 'pattern_based':
            // Invalidate keys matching pattern
            const regex = new RegExp(rule.pattern)
            for (const key of cache.cache.keys()) {
              if (regex.test(key)) {
                cache.cache.delete(key)
                invalidatedCount++
              }
            }
            break
            
          case 'dependency_based':
            // Invalidate based on data dependencies
            invalidatedCount = cache.invalidateByTag(`depends:${rule.dependency}`)
            break
        }
        
        invalidationResults.push({
          rule: rule.type,
          target: rule.tag || rule.pattern || rule.dependency,
          invalidatedCount,
          timestamp: Date.now()
        })
      }
      
      return {
        success: true,
        data: {
          invalidationResults,
          totalInvalidated: invalidationResults.reduce((sum, r) => sum + r.invalidatedCount, 0),
          newCacheSize: cache.cache.size
        }
      }
    }
  })
  
  reactor.setReturn('process-invalidation-rules')
  return reactor
}

// Usage example demonstrating caching patterns
export async function demonstrateCachingPatterns() {
  const { reactor, cache } = await createCachingReactor()
  
  // Sample requests with various patterns
  const requests = [
    // Duplicate requests (good for caching)
    { key: 'user:123:profile', type: 'user_data', cacheable: true, userId: '123' },
    { key: 'user:123:profile', type: 'user_data', cacheable: true, userId: '123' },
    { key: 'user:456:profile', type: 'user_data', cacheable: true, userId: '456' },
    
    // API calls (good for caching)
    { key: 'api:weather:nyc', type: 'api_call', cacheable: true, category: 'weather' },
    { key: 'api:weather:nyc', type: 'api_call', cacheable: true, category: 'weather' },
    { key: 'api:stock:AAPL', type: 'api_call', cacheable: true, category: 'finance' },
    
    // Database queries
    { key: 'db:products:featured', type: 'database_query', cacheable: true, category: 'products' },
    { key: 'db:products:featured', type: 'database_query', cacheable: true, category: 'products' },
    { key: 'db:orders:recent', type: 'database_query', cacheable: true },
    
    // Non-cacheable requests
    { key: 'transaction:new', type: 'api_call', cacheable: false, method: 'POST' },
    { key: 'log:analytics', type: 'api_call', cacheable: false, method: 'POST' },
    
    // File processing
    { key: 'file:process:large.csv', type: 'file_processing', cacheable: true },
    { key: 'file:process:large.csv', type: 'file_processing', cacheable: true },
    
    // Computations
    { key: 'compute:fibonacci:1000', type: 'computation', cacheable: true },
    { key: 'compute:fibonacci:1000', type: 'computation', cacheable: true }
  ]
  
  console.log('🚀 Testing caching strategy with realistic request patterns...')
  
  const result = await reactor.execute({ requests })
  
  if (result.state === 'completed') {
    const data = result.returnValue
    
    console.log('\n📊 Caching Results:')
    console.log(`✅ Cache hit rate: ${(data.cacheEfficiency * 100).toFixed(1)}%`)
    console.log(`⚡ Performance gain: ${data.performanceGain}`)
    console.log(`💾 Items in cache: ${data.optimization.currentHitRate}`)
    
    console.log('\n🎯 Recommendations:')
    data.optimization.recommendations.forEach((rec: string, i: number) => {
      console.log(`   ${i + 1}. ${rec}`)
    })
    
    console.log('\n⚙️ Auto-tuning suggestions:')
    console.log(`   Recommended cache size: ${data.tuning.recommendedCacheSize}`)
    console.log(`   Recommended TTL: ${data.tuning.recommendedTTL / 1000}s`)
    console.log(`   Hot tags: ${data.tuning.suggestedInvalidationTags.join(', ')}`)
    
    // Demonstrate cache invalidation
    console.log('\n🧹 Testing cache invalidation...')
    const invalidationReactor = await createCacheInvalidationReactor()
    
    const invalidationRules = [
      { type: 'tag_based', tag: 'user_data' },
      { type: 'time_based', maxAge: 300000 }, // 5 minutes
      { type: 'pattern_based', pattern: '^api:weather:.*' }
    ]
    
    const invalidationResult = await invalidationReactor.execute({
      invalidationRules,
      cache
    })
    
    if (invalidationResult.state === 'completed') {
      const invData = invalidationResult.returnValue
      console.log(`   Invalidated ${invData.totalInvalidated} cache entries`)
      console.log(`   New cache size: ${invData.newCacheSize}`)
    }
    
    return data
  } else {
    console.error('❌ Caching demonstration failed:', result.errors[0]?.message)
    throw new Error('Caching test failed')
  }
}
```

---

## Error Handling Patterns

### 7. Circuit Breaker Pattern

**When to use**: Preventing cascade failures in distributed systems.

```typescript
// examples/patterns/circuit-breaker.ts
import { useReactor, useErrorBoundary, useMonitoring } from '@nuxtops/reactor'

enum CircuitState {
  CLOSED = 'CLOSED',     // Normal operation
  OPEN = 'OPEN',         // Failures detected, requests blocked
  HALF_OPEN = 'HALF_OPEN' // Testing if service recovered
}

interface CircuitBreakerConfig {
  failureThreshold: number
  resetTimeout: number
  monitoringWindow: number
  halfOpenMaxCalls: number
  slowCallThreshold: number
  slowCallRateThreshold: number
}

interface ServiceHealth {
  name: string
  failures: number
  successes: number
  slowCalls: number
  totalCalls: number
  lastFailure?: number
  averageResponseTime: number
  state: CircuitState
}

export class AdvancedCircuitBreaker {
  private services = new Map<string, ServiceHealth>()
  private config: CircuitBreakerConfig
  private callHistory = new Map<string, Array<{ timestamp: number; success: boolean; duration: number }>>()
  
  constructor(config: Partial<CircuitBreakerConfig> = {}) {
    this.config = {
      failureThreshold: 5,
      resetTimeout: 60000, // 1 minute
      monitoringWindow: 300000, // 5 minutes
      halfOpenMaxCalls: 3,
      slowCallThreshold: 1000, // 1 second
      slowCallRateThreshold: 0.5, // 50%
      ...config
    }
  }
  
  async call<T>(serviceName: string, operation: () => Promise<T>): Promise<T> {
    const service = this.getOrCreateService(serviceName)
    
    // Check circuit state
    if (service.state === CircuitState.OPEN) {
      if (this.shouldAttemptReset(service)) {
        service.state = CircuitState.HALF_OPEN
        console.log(`🔄 Circuit breaker for ${serviceName} transitioning to HALF_OPEN`)
      } else {
        throw new Error(`Circuit breaker is OPEN for service: ${serviceName}`)
      }
    }
    
    if (service.state === CircuitState.HALF_OPEN) {
      const recentCalls = this.getRecentCalls(serviceName)
      if (recentCalls.length >= this.config.halfOpenMaxCalls) {
        throw new Error(`Circuit breaker HALF_OPEN call limit reached for: ${serviceName}`)
      }
    }
    
    const startTime = Date.now()
    
    try {
      const result = await operation()
      const duration = Date.now() - startTime
      
      this.recordCall(serviceName, true, duration)
      this.updateServiceHealth(serviceName, true, duration)
      
      // Transition from HALF_OPEN to CLOSED if successful
      if (service.state === CircuitState.HALF_OPEN) {
        service.state = CircuitState.CLOSED
        console.log(`✅ Circuit breaker for ${serviceName} reset to CLOSED`)
      }
      
      return result
      
    } catch (error) {
      const duration = Date.now() - startTime
      
      this.recordCall(serviceName, false, duration)
      this.updateServiceHealth(serviceName, false, duration)
      
      // Check if we should open the circuit
      if (this.shouldOpenCircuit(serviceName)) {
        service.state = CircuitState.OPEN
        service.lastFailure = Date.now()
        console.log(`🚨 Circuit breaker OPENED for ${serviceName} - failure threshold exceeded`)
      }
      
      throw error
    }
  }
  
  private getOrCreateService(name: string): ServiceHealth {
    if (!this.services.has(name)) {
      this.services.set(name, {
        name,
        failures: 0,
        successes: 0,
        slowCalls: 0,
        totalCalls: 0,
        averageResponseTime: 0,
        state: CircuitState.CLOSED
      })
      this.callHistory.set(name, [])
    }
    
    return this.services.get(name)!
  }
  
  private recordCall(serviceName: string, success: boolean, duration: number): void {
    const history = this.callHistory.get(serviceName) || []
    const now = Date.now()
    
    history.push({ timestamp: now, success, duration })
    
    // Remove old entries outside monitoring window
    const cutoff = now - this.config.monitoringWindow
    const filtered = history.filter(call => call.timestamp > cutoff)
    
    this.callHistory.set(serviceName, filtered)
  }
  
  private updateServiceHealth(serviceName: string, success: boolean, duration: number): void {
    const service = this.getOrCreateService(serviceName)
    
    service.totalCalls++
    
    if (success) {
      service.successes++
    } else {
      service.failures++
    }
    
    if (duration > this.config.slowCallThreshold) {
      service.slowCalls++
    }
    
    // Update average response time
    service.averageResponseTime = (service.averageResponseTime * (service.totalCalls - 1) + duration) / service.totalCalls
  }
  
  private shouldOpenCircuit(serviceName: string): boolean {
    const recentCalls = this.getRecentCalls(serviceName)
    
    if (recentCalls.length < this.config.failureThreshold) {
      return false
    }
    
    const failures = recentCalls.filter(call => !call.success).length
    const slowCalls = recentCalls.filter(call => call.duration > this.config.slowCallThreshold).length
    
    const failureRate = failures / recentCalls.length
    const slowCallRate = slowCalls / recentCalls.length
    
    // Open circuit if failure threshold exceeded OR slow call rate too high
    return failures >= this.config.failureThreshold || 
           (slowCallRate >= this.config.slowCallRateThreshold && recentCalls.length >= 10)
  }
  
  private shouldAttemptReset(service: ServiceHealth): boolean {
    if (!service.lastFailure) return false
    
    const timeSinceFailure = Date.now() - service.lastFailure
    return timeSinceFailure >= this.config.resetTimeout
  }
  
  private getRecentCalls(serviceName: string): Array<{ timestamp: number; success: boolean; duration: number }> {
    const history = this.callHistory.get(serviceName) || []
    const cutoff = Date.now() - this.config.monitoringWindow
    
    return history.filter(call => call.timestamp > cutoff)
  }
  
  getServiceHealth(serviceName?: string): ServiceHealth | ServiceHealth[] {
    if (serviceName) {
      return this.getOrCreateService(serviceName)
    }
    
    return Array.from(this.services.values())
  }
  
  resetCircuit(serviceName: string): void {
    const service = this.getOrCreateService(serviceName)
    service.state = CircuitState.CLOSED
    service.failures = 0
    service.slowCalls = 0
    delete service.lastFailure
    console.log(`🔄 Circuit breaker manually reset for ${serviceName}`)
  }
}

export async function createCircuitBreakerReactor() {
  const { createReactor } = useReactor()
  const { wrapStep } = useErrorBoundary({
    maxRetries: 2,
    retryDelay: 1000,
    enableFallback: true
  })
  const { recordExecution } = useMonitoring()
  
  const circuitBreaker = new AdvancedCircuitBreaker({
    failureThreshold: 3,
    resetTimeout: 30000, // 30 seconds for demo
    monitoringWindow: 60000, // 1 minute
    halfOpenMaxCalls: 2,
    slowCallThreshold: 500,
    slowCallRateThreshold: 0.6
  })
  
  const reactor = createReactor('circuit-breaker-demo')
  
  reactor.addInput({
    name: 'serviceRequests',
    type: 'array',
    required: true,
    description: 'Array of service requests to process'
  })
  
  // Step 1: Process requests with circuit breaker protection
  reactor.addStep(wrapStep({
    name: 'process-protected-requests',
    description: 'Execute service calls with circuit breaker protection',
    arguments: {
      requests: { type: 'input', name: 'serviceRequests' }
    },
    async run({ requests }) {
      const results = []
      
      for (const request of requests) {
        const startTime = Date.now()
        
        try {
          const result = await circuitBreaker.call(
            request.serviceName,
            () => this.simulateServiceCall(request)
          )
          
          results.push({
            request: request.id,
            service: request.serviceName,
            success: true,
            result,
            duration: Date.now() - startTime,
            circuitState: circuitBreaker.getServiceHealth(request.serviceName).state
          })
          
        } catch (error) {
          results.push({
            request: request.id,
            service: request.serviceName,
            success: false,
            error: error.message,
            duration: Date.now() - startTime,
            circuitState: circuitBreaker.getServiceHealth(request.serviceName).state
          })
        }
      }
      
      return { success: true, data: { results, totalProcessed: results.length } }
    },
    
    // Simulate various service behaviors
    async simulateServiceCall(request: any) {
      const { serviceName, operation, shouldFail, delay } = request
      
      // Add realistic delay
      const actualDelay = delay || 100 + Math.random() * 200
      await new Promise(resolve => setTimeout(resolve, actualDelay))
      
      // Simulate different failure scenarios
      if (shouldFail === 'timeout') {
        await new Promise(resolve => setTimeout(resolve, 2000)) // Long delay
        throw new Error(`Service ${serviceName} timed out`)
      }
      
      if (shouldFail === 'error') {
        throw new Error(`Service ${serviceName} returned an error`)
      }
      
      if (shouldFail === 'slow') {
        await new Promise(resolve => setTimeout(resolve, 1500)) // Slow response
      }
      
      // Random failures based on service reliability
      const failureRate = request.failureRate || 0.1
      if (Math.random() < failureRate) {
        throw new Error(`Random failure in ${serviceName}`)
      }
      
      return {
        service: serviceName,
        operation,
        data: `Result from ${serviceName}`,
        timestamp: Date.now(),
        requestId: request.id
      }
    }
  }))
  
  // Step 2: Analyze circuit breaker effectiveness
  reactor.addStep({
    name: 'analyze-circuit-breaker-performance',
    description: 'Analyze circuit breaker performance and health',
    dependencies: ['process-protected-requests'],
    arguments: {
      requestResults: { type: 'step', name: 'process-protected-requests' }
    },
    async run({ requestResults }) {
      const { results } = requestResults
      
      // Collect service health data
      const serviceHealthData = circuitBreaker.getServiceHealth() as ServiceHealth[]
      
      const analysis = {
        totalRequests: results.length,
        successfulRequests: results.filter((r: any) => r.success).length,
        failedRequests: results.filter((r: any) => !r.success).length,
        circuitBreakerActions: {
          openCircuits: serviceHealthData.filter(s => s.state === CircuitState.OPEN).length,
          halfOpenCircuits: serviceHealthData.filter(s => s.state === CircuitState.HALF_OPEN).length,
          closedCircuits: serviceHealthData.filter(s => s.state === CircuitState.CLOSED).length
        },
        serviceHealth: serviceHealthData.map(service => ({
          name: service.name,
          state: service.state,
          failureRate: service.totalCalls > 0 ? service.failures / service.totalCalls : 0,
          averageResponseTime: service.averageResponseTime,
          totalCalls: service.totalCalls
        })),
        protectionEffectiveness: this.calculateProtectionEffectiveness(results)
      }
      
      return { success: true, data: analysis }
    },
    
    calculateProtectionEffectiveness(results: any[]) {
      const circuitBreakerBlocked = results.filter(r => 
        r.error?.includes('Circuit breaker is OPEN') || 
        r.error?.includes('HALF_OPEN call limit')
      ).length
      
      const totalFailures = results.filter(r => !r.success).length
      const actualServiceFailures = totalFailures - circuitBreakerBlocked
      
      return {
        requestsBlocked: circuitBreakerBlocked,
        actualFailures: actualServiceFailures,
        protectionRate: totalFailures > 0 ? circuitBreakerBlocked / totalFailures : 0,
        timeSaved: circuitBreakerBlocked * 100 // Assume 100ms saved per blocked request
      }
    }
  })
  
  // Step 3: Generate recovery recommendations
  reactor.addStep({
    name: 'generate-recovery-recommendations',
    description: 'Provide recommendations for service recovery',
    dependencies: ['analyze-circuit-breaker-performance'],
    arguments: {
      analysis: { type: 'step', name: 'analyze-circuit-breaker-performance' }
    },
    async run({ analysis }) {
      const recommendations = []
      const { serviceHealth, circuitBreakerActions } = analysis
      
      // Analyze each service
      for (const service of serviceHealth) {
        if (service.state === CircuitState.OPEN) {
          recommendations.push({
            service: service.name,
            priority: 'HIGH',
            action: 'INVESTIGATE_AND_FIX',
            reason: `Service is down (circuit OPEN)`,
            details: `Failure rate: ${(service.failureRate * 100).toFixed(1)}%, Avg response: ${service.averageResponseTime.toFixed(0)}ms`
          })
        } else if (service.failureRate > 0.3) {
          recommendations.push({
            service: service.name,
            priority: 'MEDIUM',
            action: 'MONITOR_CLOSELY',
            reason: `High failure rate detected`,
            details: `Failure rate: ${(service.failureRate * 100).toFixed(1)}%`
          })
        } else if (service.averageResponseTime > 1000) {
          recommendations.push({
            service: service.name,
            priority: 'LOW',
            action: 'OPTIMIZE_PERFORMANCE',
            reason: `Slow response times`,
            details: `Average response: ${service.averageResponseTime.toFixed(0)}ms`
          })
        }
      }
      
      // General system recommendations
      if (circuitBreakerActions.openCircuits > 0) {
        recommendations.push({
          service: 'SYSTEM',
          priority: 'HIGH',
          action: 'ENABLE_DEGRADED_MODE',
          reason: `${circuitBreakerActions.openCircuits} services are unavailable`,
          details: 'Consider fallback mechanisms and user notifications'
        })
      }
      
      return {
        success: true,
        data: {
          recommendations,
          summary: {
            totalRecommendations: recommendations.length,
            highPriority: recommendations.filter(r => r.priority === 'HIGH').length,
            systemStatus: circuitBreakerActions.openCircuits === 0 ? 'HEALTHY' : 'DEGRADED'
          }
        }
      }
    }
  })
  
  reactor.setReturn('generate-recovery-recommendations')
  
  // Add monitoring middleware
  reactor.addMiddleware({
    name: 'circuit-breaker-monitoring',
    async afterReactor(context, result) {
      const healthData = circuitBreaker.getServiceHealth() as ServiceHealth[]
      console.log(`🔐 Circuit Breaker Status:`)
      healthData.forEach(service => {
        console.log(`   ${service.name}: ${service.state} (${service.totalCalls} calls, ${(service.failures / Math.max(service.totalCalls, 1) * 100).toFixed(1)}% failure rate)`)
      })
      
      recordExecution(result)
    }
  })
  
  return { reactor, circuitBreaker }
}

// Usage example with realistic failure scenarios
export async function demonstrateCircuitBreakerPattern() {
  const { reactor, circuitBreaker } = await createCircuitBreakerReactor()
  
  // Simulate various service request scenarios
  const serviceRequests = [
    // Healthy service calls
    { id: 'req-1', serviceName: 'user-service', operation: 'getUserProfile', failureRate: 0.1 },
    { id: 'req-2', serviceName: 'user-service', operation: 'getUserProfile', failureRate: 0.1 },
    { id: 'req-3', serviceName: 'order-service', operation: 'getOrders', failureRate: 0.05 },
    
    // Introduce failures to trigger circuit breaker
    { id: 'req-4', serviceName: 'payment-service', operation: 'processPayment', shouldFail: 'error' },
    { id: 'req-5', serviceName: 'payment-service', operation: 'processPayment', shouldFail: 'error' },
    { id: 'req-6', serviceName: 'payment-service', operation: 'processPayment', shouldFail: 'error' },
    { id: 'req-7', serviceName: 'payment-service', operation: 'processPayment', shouldFail: 'error' },
    
    // These should be blocked by circuit breaker
    { id: 'req-8', serviceName: 'payment-service', operation: 'processPayment' },
    { id: 'req-9', serviceName: 'payment-service', operation: 'processPayment' },
    
    // Slow service calls
    { id: 'req-10', serviceName: 'analytics-service', operation: 'getReport', shouldFail: 'slow', delay: 1200 },
    { id: 'req-11', serviceName: 'analytics-service', operation: 'getReport', shouldFail: 'slow', delay: 1400 },
    { id: 'req-12', serviceName: 'analytics-service', operation: 'getReport', shouldFail: 'slow', delay: 1100 },
    
    // More healthy calls
    { id: 'req-13', serviceName: 'user-service', operation: 'getUserProfile' },
    { id: 'req-14', serviceName: 'order-service', operation: 'getOrders' },
    
    // Test recovery after timeout
    { id: 'req-15', serviceName: 'payment-service', operation: 'processPayment', delay: 100 }
  ]
  
  console.log('🚀 Testing circuit breaker pattern with realistic failure scenarios...')
  
  const result = await reactor.execute({ serviceRequests })
  
  if (result.state === 'completed') {
    const data = result.returnValue
    
    console.log('\n📊 Circuit Breaker Results:')
    console.log(`✅ Successful requests: ${data.analysis.successfulRequests}/${data.analysis.totalRequests}`)
    console.log(`🚨 Failed requests: ${data.analysis.failedRequests}`)
    console.log(`🔐 Open circuits: ${data.analysis.circuitBreakerActions.openCircuits}`)
    console.log(`🔄 Half-open circuits: ${data.analysis.circuitBreakerActions.halfOpenCircuits}`)
    
    console.log('\n🛡️ Protection Effectiveness:')
    const protection = data.analysis.protectionEffectiveness
    console.log(`   Requests blocked: ${protection.requestsBlocked}`)
    console.log(`   Actual failures: ${protection.actualFailures}`)
    console.log(`   Protection rate: ${(protection.protectionRate * 100).toFixed(1)}%`)
    console.log(`   Time saved: ${protection.timeSaved}ms`)
    
    console.log('\n🏥 Service Health:')
    data.analysis.serviceHealth.forEach((service: any) => {
      console.log(`   ${service.name}: ${service.state} (${(service.failureRate * 100).toFixed(1)}% failure, ${service.averageResponseTime.toFixed(0)}ms avg)`)
    })
    
    console.log('\n💡 Recommendations:')
    data.recommendations.forEach((rec: any, i: number) => {
      console.log(`   ${i + 1}. [${rec.priority}] ${rec.service}: ${rec.action}`)
      console.log(`      Reason: ${rec.reason}`)
      console.log(`      Details: ${rec.details}`)
    })
    
    // Demonstrate manual circuit reset
    if (data.analysis.circuitBreakerActions.openCircuits > 0) {
      console.log('\n🔧 Simulating service recovery and circuit reset...')
      
      // Wait a bit then reset circuits manually (simulating service recovery)
      setTimeout(() => {
        const healthData = circuitBreaker.getServiceHealth() as any[]
        healthData.forEach(service => {
          if (service.state === 'OPEN') {
            circuitBreaker.resetCircuit(service.name)
          }
        })
      }, 5000)
    }
    
    return data
  } else {
    console.error('❌ Circuit breaker demonstration failed:', result.errors[0]?.message)
    throw new Error('Circuit breaker test failed')
  }
}
```

This pattern cookbook provides production-ready implementations of the most important reactor patterns with comprehensive examples and real-world usage scenarios. Each pattern includes:

1. **Clear use cases** - When and why to use each pattern
2. **Working code examples** - Complete, runnable implementations
3. **Performance considerations** - SPR optimization and monitoring integration
4. **Error handling** - Robust error boundaries and recovery strategies
5. **Real-world scenarios** - Practical examples with realistic data and edge cases

The patterns can be combined and composed to build complex, resilient workflows that handle real production challenges effectively.