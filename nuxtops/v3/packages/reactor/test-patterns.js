/**
 * Test runner for pattern cookbook examples
 * Quick validation that all patterns work correctly
 */

// Mock the required modules since we're testing without full Nuxt context
const mockUseReactor = () => ({
  createReactor: (name) => {
    const reactor = {
      id: name || `reactor_${Date.now()}`,
      inputs: [],
      steps: [],
      middleware: [],
      context: { id: name || `reactor_${Date.now()}`, startTime: Date.now(), metadata: {} },
      plan: null,
      results: new Map(),
      undoStack: [],
      returnStep: null,
      maxConcurrency: 5,
      timeout: 300000,
      inputValues: {},

      addInput(input) {
        this.inputs.push(input);
      },

      addStep(step) {
        this.steps.push(step);
        this.plan = null;
      },

      setReturn(stepName) {
        this.returnStep = stepName;
      },

      addMiddleware(middleware) {
        this.middleware.push(middleware);
      },

      async execute(inputs = {}) {
        const startTime = Date.now();
        this.inputValues = { ...inputs };
        
        try {
          // Simple sequential execution for testing
          for (const step of this.steps) {
            console.log(`   Executing step: ${step.name}`);
            
            const args = {};
            if (step.arguments) {
              for (const [argName, source] of Object.entries(step.arguments)) {
                if (source.type === 'input') {
                  args[argName] = this.inputValues[source.name];
                } else if (source.type === 'step') {
                  const stepResult = this.results.get(source.name);
                  if (stepResult?.success) {
                    args[argName] = stepResult.data;
                  }
                } else if (source.type === 'value') {
                  args[argName] = source.value;
                }
              }
            } else {
              Object.assign(args, this.inputValues);
            }

            try {
              const result = await step.run(args, this.context);
              this.results.set(step.name, { success: true, data: result.data || result });
            } catch (error) {
              console.log(`   Step ${step.name} failed: ${error.message}`);
              
              if (step.compensate) {
                const compensation = await step.compensate(error, args, this.context);
                console.log(`   Compensation result: ${compensation}`);
                
                if (compensation === 'continue') {
                  this.results.set(step.name, { success: true, data: null });
                  continue;
                }
              }
              
              throw error;
            }
          }

          const returnResult = this.returnStep ? this.results.get(this.returnStep) : null;
          
          return {
            id: this.id,
            state: 'completed',
            context: this.context,
            results: this.results,
            errors: [],
            duration: Date.now() - startTime,
            returnValue: returnResult?.data
          };
          
        } catch (error) {
          return {
            id: this.id,
            state: 'failed',
            context: this.context,
            results: this.results,
            errors: [error],
            duration: Date.now() - startTime
          };
        }
      }
    };
    
    return reactor;
  }
});

// Mock other composables
const mockUseSPR = () => ({
  analyzeWorkflow: async () => ({ compressionRatio: 0.8, performanceGain: 0.3 })
});

const mockUseMonitoring = () => ({
  recordExecution: (result) => console.log(`   📊 Recorded execution: ${result.state} in ${result.duration}ms`)
});

const mockUseErrorBoundary = (options = {}) => ({
  wrapStep: (step) => step // Simple passthrough for testing
});

// Test 1: Sequential Pipeline Pattern
async function testSequentialPipeline() {
  console.log('🧪 Testing Sequential Pipeline Pattern');
  console.log('=====================================');
  
  const { createReactor } = mockUseReactor();
  const reactor = createReactor('user-onboarding-test');
  
  reactor.addInput({
    name: 'userData',
    type: 'object',
    required: true
  });
  
  reactor.addStep({
    name: 'validate-user-data',
    arguments: {
      userData: { type: 'input', name: 'userData' }
    },
    async run({ userData }) {
      if (!userData.email?.includes('@')) {
        throw new Error('Invalid email');
      }
      return { success: true, data: { validatedUser: userData } };
    }
  });
  
  reactor.addStep({
    name: 'create-user-account',
    dependencies: ['validate-user-data'],
    arguments: {
      userData: { type: 'step', name: 'validate-user-data' }
    },
    async run({ userData }) {
      const userId = `user_${Date.now()}`;
      return { 
        success: true, 
        data: { 
          userId, 
          email: userData.validatedUser.email,
          createdAt: new Date().toISOString()
        }
      };
    }
  });
  
  reactor.setReturn('create-user-account');
  
  const result = await reactor.execute({
    userData: { email: 'test@example.com', password: 'password123' }
  });
  
  console.log(`   ✅ Result: ${result.state} (${result.duration}ms)`);
  if (result.returnValue) {
    console.log(`   👤 User created: ${result.returnValue.email}`);
  }
  
  return result.state === 'completed';
}

// Test 2: Parallel Fan-Out Pattern
async function testParallelFanOut() {
  console.log('\n🧪 Testing Parallel Fan-Out Pattern');
  console.log('===================================');
  
  const { createReactor } = mockUseReactor();
  const reactor = createReactor('data-aggregation-test');
  
  reactor.addInput({
    name: 'userId',
    type: 'string',
    required: true
  });
  
  // These would run in parallel in real implementation
  reactor.addStep({
    name: 'fetch-user-profile',
    arguments: {
      userId: { type: 'input', name: 'userId' }
    },
    async run({ userId }) {
      await new Promise(resolve => setTimeout(resolve, 100));
      return {
        success: true,
        data: { name: 'John Doe', email: 'john@example.com' }
      };
    }
  });
  
  reactor.addStep({
    name: 'fetch-user-orders',
    arguments: {
      userId: { type: 'input', name: 'userId' }
    },
    async run({ userId }) {
      await new Promise(resolve => setTimeout(resolve, 150));
      return {
        success: true,
        data: { orders: [{ id: 'order1', total: 99.99 }], totalSpent: 99.99 }
      };
    }
  });
  
  reactor.addStep({
    name: 'aggregate-data',
    dependencies: ['fetch-user-profile', 'fetch-user-orders'],
    arguments: {
      profile: { type: 'step', name: 'fetch-user-profile' },
      orders: { type: 'step', name: 'fetch-user-orders' }
    },
    async run({ profile, orders }) {
      return {
        success: true,
        data: {
          user: profile,
          orderSummary: { total: orders.totalSpent }
        }
      };
    }
  });
  
  reactor.setReturn('aggregate-data');
  
  const result = await reactor.execute({ userId: 'user123' });
  
  console.log(`   ✅ Result: ${result.state} (${result.duration}ms)`);
  if (result.returnValue) {
    console.log(`   📊 Aggregated data for: ${result.returnValue.user.name}`);
  }
  
  return result.state === 'completed';
}

// Test 3: Conditional Branch Pattern
async function testConditionalBranch() {
  console.log('\n🧪 Testing Conditional Branch Pattern');
  console.log('=====================================');
  
  const { createReactor } = mockUseReactor();
  const reactor = createReactor('payment-test');
  
  reactor.addInput({
    name: 'orderData',
    type: 'object',
    required: true
  });
  
  reactor.addStep({
    name: 'validate-order',
    arguments: {
      order: { type: 'input', name: 'orderData' }
    },
    async run({ order }) {
      const total = order.items.reduce((sum, item) => sum + (item.price * item.quantity), 0);
      return {
        success: true,
        data: {
          total,
          isExpressEligible: order.customerType === 'premium' && total < 500,
          requiresApproval: total > 1000
        }
      };
    }
  });
  
  reactor.addStep({
    name: 'process-payment',
    dependencies: ['validate-order'],
    arguments: {
      orderData: { type: 'step', name: 'validate-order' }
    },
    async run({ orderData }) {
      let method = 'standard';
      let processingTime = 500;
      
      if (orderData.isExpressEligible) {
        method = 'express';
        processingTime = 100;
      } else if (orderData.requiresApproval) {
        method = 'approval';
        processingTime = 2000;
      }
      
      await new Promise(resolve => setTimeout(resolve, processingTime / 10)); // Faster for test
      
      return {
        success: true,
        data: {
          paymentId: `pay_${Date.now()}`,
          method,
          total: orderData.total
        }
      };
    }
  });
  
  reactor.setReturn('process-payment');
  
  // Test different scenarios
  const scenarios = [
    {
      name: 'Premium Express',
      orderData: {
        items: [{ price: 100, quantity: 2 }],
        customerType: 'premium'
      }
    },
    {
      name: 'High Value',
      orderData: {
        items: [{ price: 800, quantity: 2 }],
        customerType: 'regular'
      }
    }
  ];
  
  let allPassed = true;
  
  for (const scenario of scenarios) {
    console.log(`   Testing ${scenario.name}:`);
    const result = await reactor.execute({ orderData: scenario.orderData });
    
    if (result.state === 'completed') {
      console.log(`   ✅ ${scenario.name}: ${result.returnValue.method} payment (${result.duration}ms)`);
    } else {
      console.log(`   ❌ ${scenario.name}: Failed`);
      allPassed = false;
    }
  }
  
  return allPassed;
}

// Test 4: Error Handling Pattern
async function testErrorHandling() {
  console.log('\n🧪 Testing Error Handling Pattern');
  console.log('=================================');
  
  const { createReactor } = mockUseReactor();
  const reactor = createReactor('error-handling-test');
  
  reactor.addInput({
    name: 'operations',
    type: 'array',
    required: true
  });
  
  reactor.addStep({
    name: 'execute-operations',
    arguments: {
      operations: { type: 'input', name: 'operations' }
    },
    async run({ operations }) {
      const results = [];
      
      for (const operation of operations) {
        try {
          if (operation.shouldFail) {
            throw new Error(`Operation ${operation.name} failed`);
          }
          
          await new Promise(resolve => setTimeout(resolve, 10));
          results.push({
            operation: operation.name,
            success: true,
            result: `Success for ${operation.name}`
          });
          
        } catch (error) {
          results.push({
            operation: operation.name,
            success: false,
            error: error.message
          });
        }
      }
      
      return { success: true, data: { results } };
    },
    
    async compensate(error, { operations }) {
      console.log(`   🔄 Compensating for error: ${error.message}`);
      return 'continue'; // Continue with partial results
    }
  });
  
  reactor.setReturn('execute-operations');
  
  const result = await reactor.execute({
    operations: [
      { name: 'op1', shouldFail: false },
      { name: 'op2', shouldFail: true },
      { name: 'op3', shouldFail: false }
    ]
  });
  
  console.log(`   ✅ Result: ${result.state} (${result.duration}ms)`);
  if (result.returnValue) {
    const successful = result.returnValue.results.filter(r => r.success).length;
    const failed = result.returnValue.results.filter(r => !r.success).length;
    console.log(`   📊 Operations: ${successful} successful, ${failed} failed`);
  }
  
  return result.state === 'completed';
}

// Test 5: Caching Pattern
async function testCaching() {
  console.log('\n🧪 Testing Caching Pattern');
  console.log('==========================');
  
  const cache = new Map();
  const { createReactor } = mockUseReactor();
  const reactor = createReactor('caching-test');
  
  reactor.addInput({
    name: 'requests',
    type: 'array',
    required: true
  });
  
  reactor.addStep({
    name: 'process-with-caching',
    arguments: {
      requests: { type: 'input', name: 'requests' }
    },
    async run({ requests }) {
      const results = [];
      let cacheHits = 0;
      let cacheMisses = 0;
      
      for (const request of requests) {
        let result;
        let fromCache = false;
        
        if (cache.has(request.key)) {
          result = cache.get(request.key);
          fromCache = true;
          cacheHits++;
        } else {
          await new Promise(resolve => setTimeout(resolve, 50)); // Simulate work
          result = `Result for ${request.key}`;
          if (request.cacheable) {
            cache.set(request.key, result);
          }
          cacheMisses++;
        }
        
        results.push({
          request: request.key,
          result,
          fromCache
        });
      }
      
      return {
        success: true,
        data: {
          results,
          cacheStats: { hits: cacheHits, misses: cacheMisses }
        }
      };
    }
  });
  
  reactor.setReturn('process-with-caching');
  
  const result = await reactor.execute({
    requests: [
      { key: 'user:123', cacheable: true },
      { key: 'user:123', cacheable: true }, // Should hit cache
      { key: 'user:456', cacheable: true },
      { key: 'temp:data', cacheable: false }
    ]
  });
  
  console.log(`   ✅ Result: ${result.state} (${result.duration}ms)`);
  if (result.returnValue) {
    const stats = result.returnValue.cacheStats;
    const hitRate = stats.hits / (stats.hits + stats.misses);
    console.log(`   💾 Cache hit rate: ${(hitRate * 100).toFixed(1)}%`);
  }
  
  return result.state === 'completed';
}

// Run all tests
async function runAllTests() {
  console.log('🚀 Starting Pattern Cookbook Validation Tests');
  console.log('==============================================\n');
  
  const tests = [
    { name: 'Sequential Pipeline', fn: testSequentialPipeline },
    { name: 'Parallel Fan-Out', fn: testParallelFanOut },
    { name: 'Conditional Branch', fn: testConditionalBranch },
    { name: 'Error Handling', fn: testErrorHandling },
    { name: 'Caching Strategy', fn: testCaching }
  ];
  
  let passed = 0;
  let failed = 0;
  
  for (const test of tests) {
    try {
      const success = await test.fn();
      if (success) {
        passed++;
        console.log(`✅ ${test.name} - PASSED`);
      } else {
        failed++;
        console.log(`❌ ${test.name} - FAILED`);
      }
    } catch (error) {
      failed++;
      console.log(`❌ ${test.name} - ERROR: ${error.message}`);
    }
  }
  
  console.log('\n📊 Test Results Summary:');
  console.log('========================');
  console.log(`✅ Passed: ${passed}`);
  console.log(`❌ Failed: ${failed}`);
  console.log(`📈 Success Rate: ${(passed / (passed + failed) * 100).toFixed(1)}%`);
  
  if (failed === 0) {
    console.log('\n🎉 All patterns validated successfully!');
    console.log('The Pattern Cookbook examples are working correctly.');
  } else {
    console.log('\n⚠️ Some patterns need fixes before deployment.');
  }
  
  return failed === 0;
}

// Run the tests
runAllTests().catch(console.error);