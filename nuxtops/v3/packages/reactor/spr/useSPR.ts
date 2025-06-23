/**
 * SPR (Sparse PicoReactor) Composable
 * Vue composable for 80/20 pattern optimization in Nuxt applications
 */

import { ref, computed, reactive } from 'vue';
import { useNuxtApp } from '#app';
import { SPREngine, type SPRPattern, type SPRCompression } from './spr-engine';
import type { ReactorEngine } from '../core/reactor-engine';

export interface SPRStats {
  totalPatterns: number;
  criticalPatterns: number;
  optimizablePatterns: number;
  averageCompressionRatio: number;
  averagePerformanceGain: number;
  lastOptimization: Date | null;
}

export function useSPR() {
  const nuxtApp = useNuxtApp();
  const sprEngine = new SPREngine();
  
  // Reactive state
  const isAnalyzing = ref(false);
  const isOptimizing = ref(false);
  const patterns = ref<Record<string, SPRPattern>>({});
  const compressions = reactive<Map<string, SPRCompression>>(new Map());
  
  // Computed stats
  const stats = computed<SPRStats>(() => {
    const patternValues = Object.values(patterns.value);
    const compressionValues = Array.from(compressions.values());
    
    return {
      totalPatterns: patternValues.length,
      criticalPatterns: patternValues.filter(p => p.weight > 0.7).length,
      optimizablePatterns: patternValues.filter(p => p.weight <= 0.7).length,
      averageCompressionRatio: compressionValues.length > 0 
        ? compressionValues.reduce((sum, c) => sum + c.compressionRatio, 0) / compressionValues.length 
        : 0,
      averagePerformanceGain: compressionValues.length > 0
        ? compressionValues.reduce((sum, c) => sum + c.performanceGain, 0) / compressionValues.length
        : 0,
      lastOptimization: compressionValues.length > 0 ? new Date() : null
    };
  });
  
  /**
   * Analyze a reactor workflow for SPR patterns
   */
  const analyzeWorkflow = async (reactor: ReactorEngine): Promise<SPRCompression> => {
    isAnalyzing.value = true;
    
    try {
      const compression = await sprEngine.analyzeWorkflow(reactor);
      compressions.set(reactor.id, compression);
      
      // Update patterns
      patterns.value = sprEngine.exportPatterns();
      
      return compression;
    } finally {
      isAnalyzing.value = false;
    }
  };
  
  /**
   * Optimize a reactor workflow using SPR
   */
  const optimizeWorkflow = async (reactor: ReactorEngine): Promise<ReactorEngine> => {
    isOptimizing.value = true;
    
    try {
      const optimizedReactor = await sprEngine.compressWorkflow(reactor);
      
      // Store optimization in session storage for persistence
      if (process.client) {
        const optimizationData = {
          originalId: reactor.id,
          optimizedId: optimizedReactor.id,
          compression: compressions.get(reactor.id),
          timestamp: Date.now()
        };
        
        sessionStorage.setItem(
          `spr_optimization_${reactor.id}`, 
          JSON.stringify(optimizationData)
        );
      }
      
      return optimizedReactor;
    } finally {
      isOptimizing.value = false;
    }
  };
  
  /**
   * Get critical 20% patterns
   */
  const getCriticalPatterns = (): SPRPattern[] => {
    return sprEngine.getCriticalSteps();
  };
  
  /**
   * Get optimizable 80% patterns
   */
  const getOptimizablePatterns = (): SPRPattern[] => {
    return sprEngine.getOptimizableSteps();
  };
  
  /**
   * Export SPR patterns for backup/analysis
   */
  const exportPatterns = (): Record<string, SPRPattern> => {
    return sprEngine.exportPatterns();
  };
  
  /**
   * Import SPR patterns from backup
   */
  const importPatterns = (patternsData: Record<string, SPRPattern>): void => {
    sprEngine.importPatterns(patternsData);
    patterns.value = patternsData;
  };
  
  /**
   * Reset all SPR data
   */
  const reset = (): void => {
    patterns.value = {};
    compressions.clear();
    
    if (process.client) {
      // Clear session storage
      Object.keys(sessionStorage).forEach(key => {
        if (key.startsWith('spr_optimization_')) {
          sessionStorage.removeItem(key);
        }
      });
    }
  };
  
  /**
   * Auto-optimize reactors based on usage patterns
   */
  const enableAutoOptimization = (threshold: number = 0.2): void => {
    // Set up automatic optimization when performance gains exceed threshold
    const checkOptimization = () => {
      const avgGain = stats.value.averagePerformanceGain;
      if (avgGain < threshold && stats.value.totalPatterns > 5) {
        console.log(`🚀 SPR Auto-optimization triggered (${avgGain.toFixed(2)} < ${threshold})`);
        // Could trigger automatic re-analysis of workflows
      }
    };
    
    // Check every 5 minutes in development, 30 minutes in production
    const interval = process.env.NODE_ENV === 'development' ? 5 * 60 * 1000 : 30 * 60 * 1000;
    setInterval(checkOptimization, interval);
  };
  
  /**
   * Get SPR recommendations for a reactor
   */
  const getRecommendations = (reactor: ReactorEngine): string[] => {
    const recommendations: string[] = [];
    const compression = compressions.get(reactor.id);
    
    if (!compression) {
      recommendations.push('Run analysis first to get optimization recommendations');
      return recommendations;
    }
    
    if (compression.compressionRatio > 0.8) {
      recommendations.push('Consider breaking down large steps into smaller, parallelizable operations');
    }
    
    if (compression.performanceGain < 0.1) {
      recommendations.push('Add more caching to frequently accessed operations');
    }
    
    if (compression.criticalPath.length > compression.originalSteps * 0.3) {
      recommendations.push('Too many critical steps - consider making some operations optional or async');
    }
    
    const criticalPatterns = getCriticalPatterns();
    const lowSuccessRate = criticalPatterns.filter(p => p.successRate < 0.8);
    if (lowSuccessRate.length > 0) {
      recommendations.push(`Improve error handling for: ${lowSuccessRate.map(p => p.name).join(', ')}`);
    }
    
    return recommendations;
  };
  
  // Initialize from session storage if available
  if (process.client) {
    const savedPatterns = localStorage.getItem('spr_patterns');
    if (savedPatterns) {
      try {
        const parsed = JSON.parse(savedPatterns);
        importPatterns(parsed);
      } catch (e) {
        console.warn('Failed to load saved SPR patterns:', e);
      }
    }
  }
  
  // Auto-save patterns periodically
  if (process.client) {
    setInterval(() => {
      if (Object.keys(patterns.value).length > 0) {
        localStorage.setItem('spr_patterns', JSON.stringify(patterns.value));
      }
    }, 60000); // Save every minute
  }
  
  return {
    // State
    isAnalyzing: readonly(isAnalyzing),
    isOptimizing: readonly(isOptimizing),
    patterns: readonly(patterns),
    stats: readonly(stats),
    
    // Methods
    analyzeWorkflow,
    optimizeWorkflow,
    getCriticalPatterns,
    getOptimizablePatterns,
    getRecommendations,
    exportPatterns,
    importPatterns,
    reset,
    enableAutoOptimization
  };
}