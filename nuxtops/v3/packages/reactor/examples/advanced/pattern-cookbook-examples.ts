/**
 * Pattern Cookbook Examples
 * Executable demonstrations of all patterns from the cookbook
 */

import { useReactor, useSPR, useMonitoring, useErrorBoundary } from '@nuxtops/reactor'

/**
 * Run all pattern demonstrations
 */
export async function runAllPatternExamples() {
  console.log('🚀 Starting Pattern Cookbook Demonstrations\n')
  
  try {
    // 1. Sequential Pipeline Pattern
    console.log('📋 1. Sequential Pipeline Pattern')
    console.log('================================')
    await demonstrateSequentialPipeline()
    
    // 2. Parallel Fan-Out Pattern
    console.log('\n🔀 2. Parallel Fan-Out Pattern')
    console.log('===============================')
    await demonstrateParallelFanOut()
    
    // 3. Conditional Branch Pattern
    console.log('\n🔀 3. Conditional Branch Pattern')
    console.log('=================================')
    await demonstrateConditionalBranch()
    
    // 4. Caching Strategy Pattern
    console.log('\n💾 4. Caching Strategy Pattern')
    console.log('===============================')
    await demonstrateCachingStrategy()
    
    // 5. Error Handling Pattern
    console.log('\n🛡️ 5. Error Handling Pattern')
    console.log('==============================')
    await demonstrateErrorHandling()
    
    console.log('\n✅ All pattern demonstrations completed successfully!')
    
  } catch (error) {
    console.error('❌ Pattern demonstration failed:', error)
    throw error
  }
}

/**
 * 1. Sequential Pipeline Pattern - User Onboarding
 */
async function demonstrateSequentialPipeline() {
  const { createReactor } = useReactor()
  const reactor = createReactor('user-onboarding-demo')
  
  // Input definition
  reactor.addInput({
    name: 'userData',
    type: 'object',
    required: true,
    description: 'User registration data'
  })
  
  // Sequential steps
  reactor.addStep({
    name: 'validate-user-data',
    description: 'Validate user input data',
    arguments: {
      userData: { type: 'input', name: 'userData' }
    },
    async run({ userData }) {
      console.log('   🔍 Validating user data...')
      
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
      console.log('   👤 Creating user account...')
      
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
      console.log(`   🔄 Rolling back user creation for ${userData.validatedUser?.email}`)
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
      console.log('   📧 Sending welcome email...')
      
      // Simulate email sending
      await new Promise(resolve => setTimeout(resolve, 150))
      
      return {
        success: true,
        data: { emailSent: true, emailId: `email_${Date.now()}` }
      }
    },
    async compensate(error, { user }) {
      console.log(`   ⚠️ Failed to send welcome email to ${user.email}`)
      return 'continue' // Don't abort the whole process for email failure
    }
  })
  
  reactor.setReturn('create-user-account')
  
  // Test with valid user data
  const validUser = {
    email: 'john@example.com',
    password: 'securepassword123',
    name: 'John Doe'
  }
  
  const result = await reactor.execute({ userData: validUser })
  
  if (result.state === 'completed') {
    console.log(`   ✅ User onboarded: ${result.returnValue.email} (ID: ${result.returnValue.userId})`)
    console.log(`   ⏱️ Total time: ${result.duration}ms`)
  } else {
    console.log(`   ❌ Onboarding failed: ${result.errors[0]?.message}`)
  }
}

/**
 * 2. Parallel Fan-Out Pattern - Data Aggregation
 */
async function demonstrateParallelFanOut() {
  const { createReactor } = useReactor()
  const { recordExecution } = useMonitoring()
  
  const reactor = createReactor('data-aggregation-demo')
  
  reactor.addInput({
    name: 'userId',
    type: 'string',
    required: true
  })
  
  // Parallel data fetching steps
  reactor.addStep({
    name: 'fetch-user-profile',
    description: 'Get user profile data',
    arguments: {
      userId: { type: 'input', name: 'userId' }
    },
    async run({ userId }) {
      console.log('   👤 Fetching user profile...')
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
      console.log('   📦 Fetching user orders...')
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
      console.log('   ⭐ Fetching user reviews...')
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
  
  // Aggregation step waits for all parallel steps
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
      console.log('   🔗 Aggregating data...')
      
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
  
  const startTime = performance.now()
  const result = await reactor.execute({ userId: 'user123' })
  const duration = performance.now() - startTime
  
  if (result.state === 'completed') {
    console.log(`   ✅ Data aggregated for user: ${result.returnValue.profile.name}`)
    console.log(`   📊 Orders: ${result.returnValue.orderSummary.totalOrders}, Reviews: ${result.returnValue.reviewSummary.totalReviews}`)
    console.log(`   ⚡ Parallel execution completed in ${duration.toFixed(2)}ms`)
    console.log(`   🚀 Performance gain: ~${(550 - duration).toFixed(0)}ms saved through parallelization`)
  }
}

/**
 * 3. Conditional Branch Pattern - Payment Processing
 */
async function demonstrateConditionalBranch() {
  const { createReactor } = useReactor()
  const { wrapStep } = useErrorBoundary({
    maxRetries: 2,
    retryDelay: 500,
    enableFallback: true
  })
  
  const reactor = createReactor('payment-processing-demo')
  
  reactor.addInput({
    name: 'orderData',
    type: 'object',
    required: true
  })
  
  // Step 1: Validate order and determine processing path
  reactor.addStep(wrapStep({
    name: 'validate-order',
    description: 'Validate order and calculate routing',
    arguments: {
      order: { type: 'input', name: 'orderData' }
    },
    async run({ order }) {
      console.log('   🔍 Validating order...')
      
      const { items, couponCode, customerType } = order
      
      let total = items.reduce((sum: number, item: any) => sum + (item.price * item.quantity), 0)
      let paymentMethod = 'credit_card'
      
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
        total *= 0.95
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
  
  // Conditional processing paths
  reactor.addStep(wrapStep({
    name: 'express-payment',
    description: 'Fast payment for eligible orders',
    dependencies: ['validate-order'],
    arguments: {
      orderData: { type: 'step', name: 'validate-order' }
    },
    async run({ orderData }) {
      if (!orderData.isExpressEligible) {
        return { success: true, data: { skipped: true } }
      }
      
      console.log('   ⚡ Processing express payment...')
      await new Promise(resolve => setTimeout(resolve, 100))
      
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
  
  reactor.addStep(wrapStep({
    name: 'standard-payment',
    description: 'Standard payment processing',
    dependencies: ['validate-order'],
    arguments: {
      orderData: { type: 'step', name: 'validate-order' }
    },
    async run({ orderData }) {
      if (orderData.isExpressEligible || orderData.requiresApproval) {
        return { success: true, data: { skipped: true } }
      }
      
      console.log('   💳 Processing standard payment...')
      await new Promise(resolve => setTimeout(resolve, 500))
      
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
  
  reactor.addStep(wrapStep({
    name: 'request-approval',
    description: 'Request approval for high-value orders',
    dependencies: ['validate-order'],
    arguments: {
      orderData: { type: 'step', name: 'validate-order' }
    },
    async run({ orderData }) {
      if (!orderData.requiresApproval) {
        return { success: true, data: { skipped: true } }
      }
      
      console.log('   📋 Requesting approval for high-value order...')
      await new Promise(resolve => setTimeout(resolve, 1000))
      
      const approved = Math.random() > 0.2 // 80% approval rate
      
      if (!approved) {
        return {
          success: false,
          error: new Error('Order requires manual approval')
        }
      }
      
      return {
        success: true,
        data: {
          approvalId: `approval_${Date.now()}`,
          approvedBy: 'system',
          approvalTime: 1000
        }
      }
    }
  }))
  
  // Final step combines results
  reactor.addStep(wrapStep({
    name: 'finalize-payment',
    description: 'Finalize payment processing',
    dependencies: ['express-payment', 'standard-payment', 'request-approval'],
    arguments: {
      orderData: { type: 'step', name: 'validate-order' },
      expressResult: { type: 'step', name: 'express-payment' },
      standardResult: { type: 'step', name: 'standard-payment' },
      approvalResult: { type: 'step', name: 'request-approval' }
    },
    async run({ orderData, expressResult, standardResult, approvalResult }) {
      console.log('   ✅ Finalizing payment...')
      
      let paymentResult
      let processingPath
      
      if (expressResult && !expressResult.skipped) {
        paymentResult = expressResult
        processingPath = 'express'
      } else if (standardResult && !standardResult.skipped) {
        paymentResult = standardResult
        processingPath = 'standard'
      } else if (approvalResult && !approvalResult.skipped) {
        // Process payment after approval
        await new Promise(resolve => setTimeout(resolve, 600))
        paymentResult = {
          paymentId: `approved_${Date.now()}`,
          status: 'completed',
          processingTime: 600,
          method: orderData.paymentMethod,
          approvalId: approvalResult.approvalId
        }
        processingPath = 'approved'
      } else {
        throw new Error('No valid payment path was executed')
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
  
  // Test different order scenarios
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
      name: 'High Value Order',
      orderData: {
        items: [{ price: 800, quantity: 2 }],
        customerType: 'enterprise',
        couponCode: 'ENTERPRISE20'
      }
    }
  ]
  
  for (const scenario of scenarios) {
    console.log(`   📋 Testing ${scenario.name}:`)
    const result = await reactor.execute(scenario.orderData)
    
    if (result.state === 'completed') {
      const data = result.returnValue
      console.log(`   ✅ Processed via ${data.processingPath} path: $${data.total.toFixed(2)}`)
    } else {
      console.log(`   ❌ Failed: ${result.errors[0]?.message}`)
    }
  }
}

/**
 * 4. Caching Strategy Pattern
 */
async function demonstrateCachingStrategy() {
  const { createReactor } = useReactor()
  const { analyzeWorkflow } = useSPR()
  
  // Simple cache implementation
  const cache = new Map<string, { value: any; timestamp: number; ttl: number }>()
  
  const reactor = createReactor('caching-demo')
  
  reactor.addInput({
    name: 'requests',
    type: 'array',
    required: true
  })
  
  reactor.addStep({
    name: 'process-with-caching',
    description: 'Process requests using intelligent caching',
    arguments: {
      requests: { type: 'input', name: 'requests' }
    },
    async run({ requests }) {
      console.log('   💾 Processing requests with caching...')
      
      const results = []
      let cacheHits = 0
      let cacheMisses = 0
      
      for (const request of requests) {
        const startTime = performance.now()
        let result
        let fromCache = false
        
        // Check cache first
        const cached = cache.get(request.key)
        
        if (cached && Date.now() - cached.timestamp < cached.ttl) {
          result = cached.value
          fromCache = true
          cacheHits++
        } else {
          // Execute and cache
          result = await this.executeRequest(request)
          cache.set(request.key, {
            value: result,
            timestamp: Date.now(),
            ttl: request.cacheable ? 300000 : 0 // 5 minutes
          })
          cacheMisses++
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
          cacheStats: {
            hits: cacheHits,
            misses: cacheMisses,
            hitRate: cacheHits / (cacheHits + cacheMisses),
            totalSize: cache.size
          }
        }
      }
    },
    
    async executeRequest(request: any) {
      // Simulate different request types
      const delay = request.type === 'database' ? 200 : 100
      await new Promise(resolve => setTimeout(resolve, delay))
      
      return {
        data: `Result for ${request.key}`,
        timestamp: Date.now(),
        type: request.type
      }
    }
  })
  
  reactor.setReturn('process-with-caching')
  
  // Test requests with duplicates
  const requests = [
    { key: 'user:123', type: 'database', cacheable: true },
    { key: 'user:123', type: 'database', cacheable: true }, // Duplicate
    { key: 'api:weather', type: 'api', cacheable: true },
    { key: 'api:weather', type: 'api', cacheable: true }, // Duplicate
    { key: 'compute:heavy', type: 'computation', cacheable: true },
    { key: 'transaction:new', type: 'api', cacheable: false } // Not cacheable
  ]
  
  const result = await reactor.execute({ requests })
  
  if (result.state === 'completed') {
    const data = result.returnValue
    console.log(`   ✅ Processed ${data.results.length} requests`)
    console.log(`   📊 Cache hit rate: ${(data.cacheStats.hitRate * 100).toFixed(1)}%`)
    console.log(`   💾 Cache size: ${data.cacheStats.totalSize} items`)
    
    const totalTime = data.results.reduce((sum: number, r: any) => sum + r.duration, 0)
    const cacheHits = data.results.filter((r: any) => r.fromCache).length
    console.log(`   ⚡ Total time: ${totalTime.toFixed(2)}ms, Cache hits: ${cacheHits}`)
  }
}

/**
 * 5. Error Handling Pattern
 */
async function demonstrateErrorHandling() {
  const { createReactor } = useReactor()
  const { wrapStep } = useErrorBoundary({
    maxRetries: 3,
    retryDelay: 200,
    backoffMultiplier: 2,
    enableFallback: true
  })
  
  const reactor = createReactor('error-handling-demo')
  
  reactor.addInput({
    name: 'operations',
    type: 'array',
    required: true
  })
  
  reactor.addStep(wrapStep({
    name: 'execute-operations',
    description: 'Execute operations with error handling',
    arguments: {
      operations: { type: 'input', name: 'operations' }
    },
    async run({ operations }) {
      console.log('   🛡️ Executing operations with error handling...')
      
      const results = []
      
      for (const operation of operations) {
        try {
          const result = await this.executeOperation(operation)
          results.push({
            operation: operation.name,
            success: true,
            result,
            attempts: 1
          })
          console.log(`   ✅ ${operation.name}: Success`)
        } catch (error) {
          results.push({
            operation: operation.name,
            success: false,
            error: error.message,
            attempts: operation.maxRetries || 1
          })
          console.log(`   ❌ ${operation.name}: ${error.message}`)
        }
      }
      
      return { success: true, data: { results } }
    },
    
    async executeOperation(operation: any) {
      if (operation.shouldFail) {
        if (operation.failureType === 'timeout') {
          await new Promise(resolve => setTimeout(resolve, 2000))
          throw new Error('Operation timed out')
        } else if (operation.failureType === 'network') {
          throw new Error('Network connection failed')
        } else {
          throw new Error('Operation failed')
        }
      }
      
      await new Promise(resolve => setTimeout(resolve, 100))
      return { data: `Success result for ${operation.name}` }
    },
    
    async compensate(error, { operations }) {
      console.log(`   🔄 Compensating for error: ${error.message}`)
      
      if (error.message.includes('timeout')) {
        return 'retry' // Retry timeouts
      } else if (error.message.includes('network')) {
        return 'retry' // Retry network errors
      } else {
        return 'continue' // Skip other errors
      }
    }
  }))
  
  reactor.setReturn('execute-operations')
  
  // Test operations with different failure scenarios
  const operations = [
    { name: 'operation-1', shouldFail: false },
    { name: 'operation-2', shouldFail: true, failureType: 'network', maxRetries: 2 },
    { name: 'operation-3', shouldFail: false },
    { name: 'operation-4', shouldFail: true, failureType: 'timeout', maxRetries: 1 },
    { name: 'operation-5', shouldFail: false }
  ]
  
  const result = await reactor.execute({ operations })
  
  if (result.state === 'completed') {
    const data = result.returnValue
    const successful = data.results.filter((r: any) => r.success).length
    const failed = data.results.filter((r: any) => !r.success).length
    
    console.log(`   📊 Results: ${successful} successful, ${failed} failed`)
    console.log(`   🛡️ Error handling prevented cascade failures`)
    console.log(`   ⏱️ Total execution time: ${result.duration}ms`)
  }
}

// Export for use in other examples
export {
  demonstrateSequentialPipeline,
  demonstrateParallelFanOut,
  demonstrateConditionalBranch,
  demonstrateCachingStrategy,
  demonstrateErrorHandling
}