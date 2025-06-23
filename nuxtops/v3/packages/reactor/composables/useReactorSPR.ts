/**
 * useReactorSPR - Composable for SPR compression functionality
 */

import { ref, computed, type Ref } from 'vue';
import { 
  createSPREngine,
  createPatternRegistry,
  createSPRContext,
  type SPRCompressionEngine,
  type SPRPatternRegistry,
  type SPRContext,
  type SPRCompressionResult,
  type SPRDecompressionResult,
  type SPRPattern
} from '../spr';

export interface UseReactorSPROptions {
  enablePatternRegistry?: boolean;
  enableCompression?: boolean;
  compressionLevel?: 'fast' | 'balanced' | 'maximum';
  targetCompressionRatio?: number;
  autoOptimizePatterns?: boolean;
}

export default function useReactorSPR(options: UseReactorSPROptions = {}) {
  // Initialize SPR components
  const patternRegistry = options.enablePatternRegistry ? createPatternRegistry() : undefined;
  const compressionEngine = createSPREngine(patternRegistry);

  // Reactive state
  const isCompressing = ref(false);
  const isDecompressing = ref(false);
  const compressionError: Ref<Error | null> = ref(null);

  const compressionResults: Ref<SPRCompressionResult[]> = ref([]);
  const decompressionResults: Ref<SPRDecompressionResult[]> = ref([]);
  const patterns: Ref<SPRPattern[]> = ref([]);
  const compressionMetrics: Ref<{
    totalCompressions: number;
    totalDecompressions: number;
    averageCompressionRatio: number;
    totalBytesCompressed: number;
    totalBytesSaved: number;
    patternUtilization: Record<string, number>;
  }> = ref({
    totalCompressions: 0,
    totalDecompressions: 0,
    averageCompressionRatio: 0,
    totalBytesCompressed: 0,
    totalBytesSaved: 0,
    patternUtilization: {}
  });

  // Computed properties
  const totalBytesProcessed = computed(() => 
    compressionResults.value.reduce((sum, r) => sum + r.originalSize, 0)
  );

  const totalBytesSaved = computed(() => 
    compressionResults.value.reduce((sum, r) => sum + (r.originalSize - r.compressedSize), 0)
  );

  const averageCompressionRatio = computed(() => {
    if (compressionResults.value.length === 0) return 0;
    
    const totalRatio = compressionResults.value.reduce((sum, r) => sum + r.compressionRatio, 0);
    return totalRatio / compressionResults.value.length;
  });

  const compressionEfficiency = computed(() => {
    if (totalBytesProcessed.value === 0) return 0;
    return (totalBytesSaved.value / totalBytesProcessed.value) * 100;
  });

  const patternStats = computed(() => {
    const stats = {
      totalPatterns: patterns.value.length,
      categoryDistribution: {} as Record<string, number>,
      averageFrequency: 0,
      topPatterns: [] as SPRPattern[]
    };

    if (patterns.value.length === 0) return stats;

    // Calculate category distribution
    for (const pattern of patterns.value) {
      stats.categoryDistribution[pattern.category] = 
        (stats.categoryDistribution[pattern.category] || 0) + 1;
    }

    // Calculate average frequency
    stats.averageFrequency = patterns.value.reduce((sum, p) => sum + p.frequency, 0) / patterns.value.length;

    // Get top patterns
    stats.topPatterns = patterns.value
      .sort((a, b) => (b.significance * b.frequency) - (a.significance * a.frequency))
      .slice(0, 10);

    return stats;
  });

  const recentCompressions = computed(() => 
    compressionResults.value.slice(-20).reverse()
  );

  const compressionInsights = computed(() => {
    const insights: string[] = [];
    
    if (averageCompressionRatio.value > 0.8) {
      insights.push('Low compression efficiency - consider optimizing patterns');
    }
    
    if (compressionResults.value.some(r => r.semanticPreservation < 0.9)) {
      insights.push('Some compressions have low semantic preservation');
    }
    
    if (patterns.value.length > 1000) {
      insights.push('Large pattern registry - consider optimization');
    }
    
    const slowCompressions = compressionResults.value.filter(r => r.processingTime > 1000);
    if (slowCompressions.length > 0) {
      insights.push(`${slowCompressions.length} slow compressions detected`);
    }
    
    return insights;
  });

  // Compression operations
  const compressData = async <T>(
    data: T,
    context: Partial<SPRContext> = {},
    compressionOptions: any = {}
  ): Promise<SPRCompressionResult> => {
    try {
      isCompressing.value = true;
      compressionError.value = null;

      const sprContext = createSPRContext({
        domain: context.domain || 'reactor',
        agentId: context.agentId,
        sessionId: context.sessionId,
        traceId: context.traceId,
        priority: context.priority || 'medium',
        metadata: context.metadata || {}
      });

      const defaultOptions = {
        compressionLevel: options.compressionLevel || 'balanced',
        preserveSemantics: true,
        targetCompressionRatio: options.targetCompressionRatio || 0.4,
        ...compressionOptions
      };

      const result = await compressionEngine.compress(data, sprContext, defaultOptions);
      
      // Store result
      compressionResults.value.push(result);
      
      // Update metrics
      updateCompressionMetrics();
      
      // Auto-optimize patterns if enabled
      if (options.autoOptimizePatterns && patternRegistry) {
        await optimizePatterns();
      }

      console.log(`🗜️ Compression completed: ${(result.compressionRatio * 100).toFixed(1)}% ratio`);
      return result;
    } catch (error) {
      compressionError.value = error as Error;
      throw error;
    } finally {
      isCompressing.value = false;
    }
  };

  const decompressData = async <T>(
    compressedData: any,
    context: Partial<SPRContext> = {}
  ): Promise<SPRDecompressionResult> => {
    try {
      isDecompressing.value = true;
      compressionError.value = null;

      const sprContext = createSPRContext({
        domain: context.domain || 'reactor',
        agentId: context.agentId,
        sessionId: context.sessionId,
        traceId: context.traceId,
        priority: context.priority || 'medium',
        metadata: context.metadata || {}
      });

      const result = await compressionEngine.decompress<T>(compressedData, sprContext);
      
      // Store result
      decompressionResults.value.push(result);
      
      // Update metrics
      updateCompressionMetrics();

      console.log(`📤 Decompression completed: ${result.fidelity * 100}% fidelity`);
      return result;
    } catch (error) {
      compressionError.value = error as Error;
      throw error;
    } finally {
      isDecompressing.value = false;
    }
  };

  // Pattern management
  const extractPatterns = async (
    data: any,
    context: Partial<SPRContext> = {}
  ): Promise<SPRPattern[]> => {
    try {
      compressionError.value = null;

      const sprContext = createSPRContext({
        domain: context.domain || 'reactor',
        ...context
      });

      const extractedPatterns = await compressionEngine.extractPatterns(data, sprContext);
      
      // Store patterns
      if (patternRegistry) {
        for (const pattern of extractedPatterns) {
          await patternRegistry.registerPattern(pattern);
        }
        await refreshPatterns();
      }

      console.log(`🔍 Extracted ${extractedPatterns.length} patterns`);
      return extractedPatterns;
    } catch (error) {
      compressionError.value = error as Error;
      throw error;
    }
  };

  const optimizePatterns = async (): Promise<SPRPattern[]> => {
    if (!patternRegistry) {
      throw new Error('Pattern registry not enabled');
    }

    try {
      compressionError.value = null;

      const allPatterns = await patternRegistry.exportPatterns();
      const optimizedPatterns = await compressionEngine.optimizePatterns(allPatterns);
      
      // Clear and re-register optimized patterns
      for (const pattern of allPatterns) {
        await patternRegistry.deletePattern(pattern.id);
      }
      
      for (const pattern of optimizedPatterns) {
        await patternRegistry.registerPattern(pattern);
      }

      await refreshPatterns();
      
      console.log(`⚡ Optimized patterns: ${allPatterns.length} → ${optimizedPatterns.length}`);
      return optimizedPatterns;
    } catch (error) {
      compressionError.value = error as Error;
      throw error;
    }
  };

  const refreshPatterns = async () => {
    if (!patternRegistry) return;

    try {
      patterns.value = await patternRegistry.exportPatterns();
    } catch (error) {
      console.error('Failed to refresh patterns:', error);
    }
  };

  const searchPatterns = async (
    query: string,
    category?: SPRPattern['category']
  ): Promise<SPRPattern[]> => {
    if (!patternRegistry) return [];

    try {
      return await patternRegistry.searchPatterns(query, category);
    } catch (error) {
      compressionError.value = error as Error;
      return [];
    }
  };

  const deletePattern = async (patternId: string): Promise<void> => {
    if (!patternRegistry) return;

    try {
      await patternRegistry.deletePattern(patternId);
      await refreshPatterns();
      console.log(`🗑️ Pattern deleted: ${patternId}`);
    } catch (error) {
      compressionError.value = error as Error;
      throw error;
    }
  };

  // Analytics and reporting
  const generateCompressionReport = () => {
    const report = {
      generatedAt: Date.now(),
      summary: {
        totalCompressions: compressionResults.value.length,
        totalDecompressions: decompressionResults.value.length,
        averageCompressionRatio: averageCompressionRatio.value,
        compressionEfficiency: compressionEfficiency.value,
        totalBytesProcessed: totalBytesProcessed.value,
        totalBytesSaved: totalBytesSaved.value
      },
      patterns: patternStats.value,
      performance: {
        averageCompressionTime: compressionResults.value.length > 0
          ? compressionResults.value.reduce((sum, r) => sum + r.processingTime, 0) / compressionResults.value.length
          : 0,
        averageDecompressionTime: decompressionResults.value.length > 0
          ? decompressionResults.value.reduce((sum, r) => sum + r.processingTime, 0) / decompressionResults.value.length
          : 0,
        slowOperations: [
          ...compressionResults.value.filter(r => r.processingTime > 1000).map(r => ({
            type: 'compression',
            processingTime: r.processingTime,
            originalSize: r.originalSize
          })),
          ...decompressionResults.value.filter(r => r.processingTime > 1000).map(r => ({
            type: 'decompression', 
            processingTime: r.processingTime,
            originalSize: r.originalSize
          }))
        ]
      },
      insights: compressionInsights.value,
      recommendations: generateRecommendations()
    };

    return report;
  };

  const generateRecommendations = (): string[] => {
    const recommendations: string[] = [];
    
    if (averageCompressionRatio.value > 0.8) {
      recommendations.push('Consider using maximum compression level for better ratios');
    }
    
    if (patterns.value.length < 10) {
      recommendations.push('Extract more patterns to improve compression efficiency');
    }
    
    if (compressionResults.value.some(r => r.processingTime > 5000)) {
      recommendations.push('Optimize large data compression by chunking or preprocessing');
    }
    
    const lowSemanticResults = compressionResults.value.filter(r => r.semanticPreservation < 0.9);
    if (lowSemanticResults.length > 0) {
      recommendations.push('Review semantic preservation settings for critical data');
    }
    
    return recommendations;
  };

  const exportData = (format: 'json' | 'csv' = 'json') => {
    const data = {
      compressionResults: compressionResults.value,
      decompressionResults: decompressionResults.value,
      patterns: patterns.value,
      metrics: compressionMetrics.value,
      timestamp: Date.now()
    };

    if (format === 'json') {
      return JSON.stringify(data, null, 2);
    } else {
      // Simple CSV export for compression results
      const headers = ['timestamp', 'originalSize', 'compressedSize', 'compressionRatio', 'processingTime'];
      const csvContent = [
        headers.join(','),
        ...compressionResults.value.map(r => [
          r.metadata.timestamp,
          r.originalSize,
          r.compressedSize,
          r.compressionRatio.toFixed(3),
          r.processingTime.toFixed(0)
        ].join(','))
      ].join('\n');
      
      return csvContent;
    }
  };

  // Compression testing utilities
  const testCompressionRatio = async (
    testData: any[],
    context: Partial<SPRContext> = {}
  ) => {
    const results = [];
    
    for (const data of testData) {
      try {
        const result = await compressData(data, context);
        results.push({
          dataSize: result.originalSize,
          compressionRatio: result.compressionRatio,
          processingTime: result.processingTime,
          semanticPreservation: result.semanticPreservation
        });
      } catch (error) {
        results.push({
          dataSize: 0,
          compressionRatio: 1,
          processingTime: 0,
          semanticPreservation: 0,
          error: error instanceof Error ? error.message : 'Unknown error'
        });
      }
    }
    
    return {
      testResults: results,
      averageRatio: results.reduce((sum, r) => sum + r.compressionRatio, 0) / results.length,
      averageTime: results.reduce((sum, r) => sum + r.processingTime, 0) / results.length,
      successRate: results.filter(r => !r.error).length / results.length
    };
  };

  // Helper functions
  const updateCompressionMetrics = () => {
    compressionMetrics.value = {
      totalCompressions: compressionResults.value.length,
      totalDecompressions: decompressionResults.value.length,
      averageCompressionRatio: averageCompressionRatio.value,
      totalBytesCompressed: totalBytesProcessed.value,
      totalBytesSaved: totalBytesSaved.value,
      patternUtilization: calculatePatternUtilization()
    };
  };

  const calculatePatternUtilization = () => {
    const utilization: Record<string, number> = {};
    
    for (const result of compressionResults.value) {
      for (const pattern of result.patternsExtracted) {
        utilization[pattern.id] = (utilization[pattern.id] || 0) + 1;
      }
    }
    
    return utilization;
  };

  const clearData = () => {
    compressionResults.value = [];
    decompressionResults.value = [];
    compressionMetrics.value = {
      totalCompressions: 0,
      totalDecompressions: 0,
      averageCompressionRatio: 0,
      totalBytesCompressed: 0,
      totalBytesSaved: 0,
      patternUtilization: {}
    };
    console.log('🧹 SPR data cleared');
  };

  // Initialize patterns if registry is enabled
  if (patternRegistry) {
    refreshPatterns();
  }

  return {
    // State
    isCompressing: readonly(isCompressing),
    isDecompressing: readonly(isDecompressing),
    compressionError: readonly(compressionError),
    compressionResults: readonly(compressionResults),
    decompressionResults: readonly(decompressionResults),
    patterns: readonly(patterns),
    compressionMetrics: readonly(compressionMetrics),

    // Computed
    totalBytesProcessed,
    totalBytesSaved,
    averageCompressionRatio,
    compressionEfficiency,
    patternStats,
    recentCompressions,
    compressionInsights,

    // Compression operations
    compressData,
    decompressData,

    // Pattern management
    extractPatterns,
    optimizePatterns,
    refreshPatterns,
    searchPatterns,
    deletePattern,

    // Analysis
    generateCompressionReport,
    generateRecommendations,
    exportData,
    testCompressionRatio,

    // Utilities
    clearData,

    // Direct engine access
    compressionEngine,
    patternRegistry
  };
}