/**
 * Nuxt Reactor Async Patterns - Equivalent to Elixir Reactor
 * Based on: https://hexdocs.pm/reactor/03-async-workflows.html
 */

import { ReactorEngine } from '../core/reactor-engine';
import { ReactorStep } from '../types';

// Example 1: Parallel Data Fetching (Default Async Behavior)
export const createParallelDataFetchReactor = () => {
  const reactor = new ReactorEngine({
    id: 'parallel-data-fetch',
    maxConcurrency: 10
  });

  // Independent async steps that run in parallel
  const fetchUserProfile: ReactorStep = {
    name: 'fetch-user-profile',
    async run(args) {
      // Simulate API call
      await new Promise(resolve => setTimeout(resolve, 100));
      return {
        success: true,
        data: {
          profile: {
            id: args.user_id,
            name: 'John Doe',
            email: 'john@example.com'
          }
        }
      };
    }
  };

  const fetchUserPreferences: ReactorStep = {
    name: 'fetch-user-preferences',
    async run(args) {
      // Simulate API call
      await new Promise(resolve => setTimeout(resolve, 80));
      return {
        success: true,
        data: {
          preferences: {
            theme: 'dark',
            language: 'en',
            notifications: true
          }
        }
      };
    }
  };

  const fetchUserActivity: ReactorStep = {
    name: 'fetch-user-activity',
    async run(args) {
      // Simulate API call
      await new Promise(resolve => setTimeout(resolve, 120));
      return {
        success: true,
        data: {
          activity: {
            last_login: new Date().toISOString(),
            login_count: 42,
            last_action: 'view_dashboard'
          }
        }
      };
    }
  };

  // Aggregation step waits for all fetch steps
  const aggregateUserData: ReactorStep = {
    name: 'aggregate-user-data',
    dependencies: ['fetch-user-profile', 'fetch-user-preferences', 'fetch-user-activity'],
    async run(args, context) {
      const profile = context.results.get('fetch-user-profile').data;
      const preferences = context.results.get('fetch-user-preferences').data;
      const activity = context.results.get('fetch-user-activity').data;

      return {
        success: true,
        data: {
          user: {
            ...profile.profile,
            preferences: preferences.preferences,
            activity: activity.activity,
            aggregated_at: new Date().toISOString()
          }
        }
      };
    }
  };

  reactor.addStep(fetchUserProfile);
  reactor.addStep(fetchUserPreferences);
  reactor.addStep(fetchUserActivity);
  reactor.addStep(aggregateUserData);
  reactor.setReturn('aggregate-user-data');

  return reactor;
};

// Example 2: Error Handling with Compensation Strategies
export const createResilientWorkflowReactor = () => {
  const reactor = new ReactorEngine({
    id: 'resilient-workflow',
    maxConcurrency: 5
  });

  // Step that might fail but has fallback
  const fetchExternalData: ReactorStep = {
    name: 'fetch-external-data',
    timeout: 5000,
    retries: 2,
    async run(args) {
      // Simulate potential API failure
      if (Math.random() < 0.7) {
        throw new Error('External service unavailable');
      }
      return {
        success: true,
        data: { external: 'real-data' }
      };
    },
    async compensate(error, args, context) {
      console.log(`External service failed: ${error.message}, using fallback`);
      return { continue: { external: 'fallback-data', fallback: true } };
    }
  };

  // Step with retry strategy
  const processWithRetry: ReactorStep = {
    name: 'process-with-retry',
    dependencies: ['fetch-external-data'],
    retries: 3,
    async run(args, context) {
      const externalData = context.results.get('fetch-external-data').data;
      
      // Simulate processing that might fail
      if (Math.random() < 0.5) {
        throw new Error('Processing failed');
      }
      
      return {
        success: true,
        data: {
          processed: externalData.external.toUpperCase(),
          processing_time: Date.now()
        }
      };
    },
    async compensate(error, args, context) {
      console.log(`Processing failed: ${error.message}, retrying...`);
      return 'retry';
    }
  };

  // Step that can be skipped if needed
  const optionalEnrichment: ReactorStep = {
    name: 'optional-enrichment',
    dependencies: ['process-with-retry'],
    timeout: 2000,
    async run(args, context) {
      const processedData = context.results.get('process-with-retry').data;
      
      // Simulate enrichment service
      if (Math.random() < 0.3) {
        throw new Error('Enrichment service timeout');
      }
      
      return {
        success: true,
        data: {
          ...processedData,
          enriched: true,
          metadata: { source: 'enrichment-service' }
        }
      };
    },
    async compensate(error, args, context) {
      console.log(`Enrichment failed: ${error.message}, skipping...`);
      return 'skip';
    }
  };

  // Final aggregation that handles optional data
  const finalizeResult: ReactorStep = {
    name: 'finalize-result',
    dependencies: ['optional-enrichment'],
    async run(args, context) {
      const enrichmentResult = context.results.get('optional-enrichment');
      const processedResult = context.results.get('process-with-retry');
      
      // Use enriched data if available, otherwise use processed data
      const finalData = enrichmentResult.data 
        ? enrichmentResult.data 
        : { ...processedResult.data, enriched: false };
      
      return {
        success: true,
        data: {
          result: finalData,
          workflow_id: context.id,
          completed_at: new Date().toISOString()
        }
      };
    }
  };

  reactor.addStep(fetchExternalData);
  reactor.addStep(processWithRetry);
  reactor.addStep(optionalEnrichment);
  reactor.addStep(finalizeResult);
  reactor.setReturn('finalize-result');

  return reactor;
};

// Example 3: High Concurrency I/O Workflow
export const createHighConcurrencyIOReactor = () => {
  const reactor = new ReactorEngine({
    id: 'high-concurrency-io',
    maxConcurrency: 20 // High concurrency for I/O operations
  });

  // Parallel data source fetching
  const dataSources = ['users', 'orders', 'products', 'analytics', 'logs'];
  
  dataSources.forEach(source => {
    const fetchStep: ReactorStep = {
      name: `fetch-${source}`,
      async run(args) {
        // Simulate database/API call with varying latencies
        const latency = Math.random() * 200 + 50;
        await new Promise(resolve => setTimeout(resolve, latency));
        
        return {
          success: true,
          data: {
            source,
            records: Math.floor(Math.random() * 1000) + 100,
            fetch_time: latency
          }
        };
      }
    };
    reactor.addStep(fetchStep);
  });

  // Parallel processing steps
  dataSources.forEach(source => {
    const processStep: ReactorStep = {
      name: `process-${source}`,
      dependencies: [`fetch-${source}`],
      async run(args, context) {
        const fetchResult = context.results.get(`fetch-${source}`);
        const data = fetchResult.data;
        
        // Simulate CPU processing (lighter load)
        await new Promise(resolve => setTimeout(resolve, 20));
        
        return {
          success: true,
          data: {
            source: data.source,
            processed_records: data.records,
            summary: {
              total: data.records,
              avg_processing_time: 20,
              status: 'completed'
            }
          }
        };
      }
    };
    reactor.addStep(processStep);
  });

  // Final aggregation
  const aggregateResults: ReactorStep = {
    name: 'aggregate-results',
    dependencies: dataSources.map(source => `process-${source}`),
    async run(args, context) {
      const results = dataSources.map(source => 
        context.results.get(`process-${source}`).data
      );
      
      const totalRecords = results.reduce((sum, result) => 
        sum + result.processed_records, 0
      );
      
      const avgFetchTime = dataSources.reduce((sum, source) => 
        sum + context.results.get(`fetch-${source}`).data.fetch_time, 0
      ) / dataSources.length;

      return {
        success: true,
        data: {
          sources_processed: dataSources.length,
          total_records: totalRecords,
          avg_fetch_time: avgFetchTime,
          processing_summary: results.map(r => r.summary),
          completed_at: new Date().toISOString()
        }
      };
    }
  };

  reactor.addStep(aggregateResults);
  reactor.setReturn('aggregate-results');

  return reactor;
};

// Example 4: CPU-Intensive with Limited Concurrency
export const createCPUIntensiveReactor = () => {
  const reactor = new ReactorEngine({
    id: 'cpu-intensive',
    maxConcurrency: 4 // Limited concurrency for CPU-intensive tasks
  });

  const dataPrep: ReactorStep = {
    name: 'data-preparation',
    async run(args) {
      return {
        success: true,
        data: {
          datasets: Array.from({ length: 10 }, (_, i) => ({
            id: `dataset-${i}`,
            size: Math.floor(Math.random() * 10000) + 1000,
            complexity: Math.random()
          }))
        }
      };
    }
  };

  // CPU-intensive processing steps with limited concurrency
  for (let i = 0; i < 10; i++) {
    const computeStep: ReactorStep = {
      name: `compute-${i}`,
      dependencies: ['data-preparation'],
      async run(args, context) {
        const datasets = context.results.get('data-preparation').data.datasets;
        const dataset = datasets[i];
        
        // Simulate CPU-intensive computation
        let result = 0;
        for (let j = 0; j < dataset.size; j++) {
          result += Math.sin(j * dataset.complexity) * Math.cos(j);
        }
        
        return {
          success: true,
          data: {
            dataset_id: dataset.id,
            computation_result: result,
            operations: dataset.size,
            complexity: dataset.complexity
          }
        };
      }
    };
    reactor.addStep(computeStep);
  }

  // Results aggregation
  const aggregateComputations: ReactorStep = {
    name: 'aggregate-computations',
    dependencies: Array.from({ length: 10 }, (_, i) => `compute-${i}`),
    async run(args, context) {
      const computeResults = Array.from({ length: 10 }, (_, i) => 
        context.results.get(`compute-${i}`).data
      );
      
      const totalOperations = computeResults.reduce((sum, result) => 
        sum + result.operations, 0
      );
      
      const finalResult = computeResults.reduce((sum, result) => 
        sum + result.computation_result, 0
      );

      return {
        success: true,
        data: {
          total_operations: totalOperations,
          final_result: finalResult,
          datasets_processed: computeResults.length,
          avg_complexity: computeResults.reduce((sum, r) => sum + r.complexity, 0) / computeResults.length
        }
      };
    }
  };

  reactor.addStep(dataPrep);
  reactor.addStep(aggregateComputations);
  reactor.setReturn('aggregate-computations');

  return reactor;
};

// Usage examples
export const runAsyncPatternExamples = async () => {
  console.log('🚀 Running Nuxt Reactor Async Pattern Examples...\n');

  try {
    // Example 1: Parallel Data Fetching
    console.log('1. Parallel Data Fetching:');
    const parallelReactor = createParallelDataFetchReactor();
    const parallelResult = await parallelReactor.execute({ user_id: '123' });
    console.log(`   ✅ Completed in ${parallelResult.duration}ms`);
    console.log(`   📊 User: ${parallelResult.returnValue.user.name}`);
    console.log(`   🎨 Theme: ${parallelResult.returnValue.user.preferences.theme}\n`);

    // Example 2: Resilient Workflow
    console.log('2. Resilient Workflow with Compensation:');
    const resilientReactor = createResilientWorkflowReactor();
    const resilientResult = await resilientReactor.execute({});
    console.log(`   ✅ Completed in ${resilientResult.duration}ms`);
    console.log(`   📈 Processed: ${resilientResult.returnValue.result.processed || 'N/A'}`);
    console.log(`   🔄 Enriched: ${resilientResult.returnValue.result.enriched}\n`);

    // Example 3: High Concurrency I/O
    console.log('3. High Concurrency I/O:');
    const ioReactor = createHighConcurrencyIOReactor();
    const ioResult = await ioReactor.execute({});
    console.log(`   ✅ Completed in ${ioResult.duration}ms`);
    console.log(`   📊 Sources: ${ioResult.returnValue.sources_processed}`);
    console.log(`   📈 Records: ${ioResult.returnValue.total_records}`);
    console.log(`   ⏱️  Avg Fetch: ${ioResult.returnValue.avg_fetch_time.toFixed(2)}ms\n`);

    // Example 4: CPU Intensive
    console.log('4. CPU Intensive (Limited Concurrency):');
    const cpuReactor = createCPUIntensiveReactor();
    const cpuResult = await cpuReactor.execute({});
    console.log(`   ✅ Completed in ${cpuResult.duration}ms`);
    console.log(`   🧮 Operations: ${cpuResult.returnValue.total_operations}`);
    console.log(`   📊 Datasets: ${cpuResult.returnValue.datasets_processed}`);
    console.log(`   🎯 Avg Complexity: ${cpuResult.returnValue.avg_complexity.toFixed(3)}\n`);

    console.log('🎉 All async pattern examples completed successfully!');
    console.log('✨ Nuxt Reactor supports all Elixir Reactor async workflow patterns');

  } catch (error) {
    console.error('❌ Error running examples:', error);
  }
};

// Export for testing
export {
  createParallelDataFetchReactor,
  createResilientWorkflowReactor,
  createHighConcurrencyIOReactor,
  createCPUIntensiveReactor
};