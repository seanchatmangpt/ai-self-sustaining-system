/**
 * Unit tests for SPR Pipeline Optimization Reactor
 */

import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { ReactorEngine } from '../../core/reactor-engine';
import { 
  setupTestEnvironment,
  generateMockSPRContent,
  createAdvancedAssertions,
  TimeProvider,
  PlatformProvider,
  FileSystemProvider
} from './test-fixtures';

// Mock SPR Pipeline Optimization Reactor with dependency injection
const createMockSPRPipelineOptimizationReactor = (deps: {
  timeProvider: TimeProvider;
  platformProvider: PlatformProvider;
  fileSystemProvider: FileSystemProvider;
  apiMock: any;
}) => {
  const reactor = new ReactorEngine({
    id: `spr_pipeline_${deps.timeProvider.now()}`,
    timeout: 300000
  });

  // Mock content analysis step
  const contentAnalysis = {
    name: 'content-analysis',
    description: 'Analyze content structure and determine optimal SPR strategy',
    
    async run(input: any, context: any) {
      try {
        const content = input.content;
        const wordCount = content.split(/\s+/).length;
        
        // Mock content classification
        const contentType = classifyContentType(content);
        const complexity = analyzeComplexity(content, wordCount);
        const domain = extractDomain(content);
        
        const sprContent = {
          original: content,
          type: contentType,
          metadata: {
            wordCount,
            complexity,
            domain,
            language: 'english'
          },
          optimizationStrategy: {
            targetRatio: input.targetRatio || 0.3,
            qualityThreshold: complexity === 'high' ? 0.9 : 0.8,
            adaptiveFormatting: true,
            batchProcessing: false
          },
          analysisTimestamp: deps.timeProvider.now()
        };
        
        return { success: true, data: sprContent };
      } catch (error) {
        return { success: false, error: error as Error };
      }
    }
  };

  // Mock multi-format compression step
  const multiFormatCompression = {
    name: 'multi-format-compression',
    description: 'Compress content using multiple SPR formats in parallel',
    dependencies: ['content-analysis'],
    
    async run(input: any, context: any) {
      try {
        const analysisResult = context.results?.get('content-analysis')?.data;
        const content = analysisResult.original;
        
        // Mock parallel compression
        const compressionResults = [
          {
            format: 'minimal' as const,
            compressed: `SPR_MINIMAL: ${content.substring(0, Math.floor(content.length * 0.15))}...`,
            ratio: 0.15,
            quality: 0.7,
            metrics: {
              originalSize: content.length,
              compressedSize: Math.floor(content.length * 0.15),
              compressionTime: 150,
              informationRetention: 0.7
            }
          },
          {
            format: 'standard' as const,
            compressed: `SPR_STANDARD: ${content.substring(0, Math.floor(content.length * 0.25))}...`,
            ratio: 0.25,
            quality: 0.8,
            metrics: {
              originalSize: content.length,
              compressedSize: Math.floor(content.length * 0.25),
              compressionTime: 200,
              informationRetention: 0.8
            }
          },
          {
            format: 'extended' as const,
            compressed: `SPR_EXTENDED: ${content.substring(0, Math.floor(content.length * 0.4))}...`,
            ratio: 0.4,
            quality: 0.9,
            metrics: {
              originalSize: content.length,
              compressedSize: Math.floor(content.length * 0.4),
              compressionTime: 300,
              informationRetention: 0.9
            }
          }
        ];
        
        // Select optimal format based on strategy
        const strategy = analysisResult.optimizationStrategy;
        const optimal = compressionResults.reduce((best, current) => {
          const bestScore = calculateCompressionScore(best, strategy);
          const currentScore = calculateCompressionScore(current, strategy);
          return currentScore > bestScore ? current : best;
        });
        
        return { 
          success: true, 
          data: {
            allFormats: compressionResults,
            optimal,
            selectionReasoning: `Selected ${optimal.format} for optimal balance`,
            compressionMetrics: {
              averageRatio: compressionResults.reduce((sum, r) => sum + r.ratio, 0) / compressionResults.length,
              averageQuality: compressionResults.reduce((sum, r) => sum + r.quality, 0) / compressionResults.length,
              bestRatio: Math.min(...compressionResults.map(r => r.ratio)),
              bestQuality: Math.max(...compressionResults.map(r => r.quality))
            }
          }
        };
      } catch (error) {
        return { success: false, error: error as Error };
      }
    }
  };

  // Mock quality validation step
  const qualityValidation = {
    name: 'quality-validation',
    description: 'Validate compression quality through roundtrip testing',
    dependencies: ['multi-format-compression'],
    
    async run(input: any, context: any) {
      try {
        const compressionResult = context.results?.get('multi-format-compression')?.data;
        const analysisResult = context.results?.get('content-analysis')?.data;
        
        const optimalCompression = compressionResult.optimal;
        
        // Mock roundtrip testing
        const decompressionTests = [
          {
            expansion: 'brief',
            decompressed: `DECOMPRESSED_BRIEF: ${analysisResult.original.substring(0, Math.floor(analysisResult.original.length * 0.6))}...`,
            quality: optimalCompression.quality * 0.9,
            informationRecovery: optimalCompression.quality * 0.85,
            structuralIntegrity: optimalCompression.quality * 0.95,
            semanticAccuracy: optimalCompression.quality * 0.88
          },
          {
            expansion: 'detailed',
            decompressed: `DECOMPRESSED_DETAILED: ${analysisResult.original.substring(0, Math.floor(analysisResult.original.length * 0.8))}...`,
            quality: optimalCompression.quality * 0.95,
            informationRecovery: optimalCompression.quality * 0.92,
            structuralIntegrity: optimalCompression.quality * 0.98,
            semanticAccuracy: optimalCompression.quality * 0.93
          },
          {
            expansion: 'comprehensive',
            decompressed: `DECOMPRESSED_COMPREHENSIVE: ${analysisResult.original}`,
            quality: optimalCompression.quality,
            informationRecovery: optimalCompression.quality * 0.98,
            structuralIntegrity: optimalCompression.quality,
            semanticAccuracy: optimalCompression.quality * 0.96
          }
        ];
        
        // Calculate quality metrics
        const qualityMetrics = {
          averageQuality: decompressionTests.reduce((sum, test) => sum + test.quality, 0) / decompressionTests.length,
          informationRetention: decompressionTests.reduce((sum, test) => sum + test.informationRecovery, 0) / decompressionTests.length,
          structuralIntegrity: decompressionTests.reduce((sum, test) => sum + test.structuralIntegrity, 0) / decompressionTests.length,
          semanticAccuracy: decompressionTests.reduce((sum, test) => sum + test.semanticAccuracy, 0) / decompressionTests.length,
          consistencyScore: 0.85,
          overallScore: optimalCompression.quality * 0.92
        };
        
        const validationResult = {
          overall: qualityMetrics.overallScore,
          passesThreshold: qualityMetrics.overallScore >= analysisResult.optimizationStrategy.qualityThreshold,
          informationRetention: qualityMetrics.informationRetention >= 0.8,
          structuralIntegrity: qualityMetrics.structuralIntegrity >= 0.75,
          semanticAccuracy: qualityMetrics.semanticAccuracy >= 0.8,
          consistency: qualityMetrics.consistencyScore >= 0.7
        };
        
        return { 
          success: true, 
          data: {
            decompressionTests,
            qualityMetrics,
            validationResult,
            passesQualityGate: validationResult.passesThreshold,
            recommendedImprovements: generateQualityImprovements(qualityMetrics)
          }
        };
      } catch (error) {
        return { success: false, error: error as Error };
      }
    },
    
    async compensate() {
      return 'retry';
    }
  };

  // Mock adaptive optimization step
  const adaptiveOptimization = {
    name: 'adaptive-optimization',
    description: 'Apply 80/20 optimization principles to improve compression',
    dependencies: ['quality-validation'],
    
    async run(input: any, context: any) {
      try {
        const qualityResult = context.results?.get('quality-validation')?.data;
        const compressionResult = context.results?.get('multi-format-compression')?.data;
        
        if (qualityResult.passesQualityGate) {
          return { 
            success: true, 
            data: {
              optimizationApplied: false,
              reason: 'quality_threshold_met',
              finalResult: compressionResult.optimal
            }
          };
        }
        
        // Apply 80/20 optimization
        const optimizedCompression = {
          ...compressionResult.optimal,
          quality: Math.min(compressionResult.optimal.quality * 1.15, 1.0),
          compressed: compressionResult.optimal.compressed + '\n[CRITICAL_SECTIONS_PRESERVED]'
        };
        
        const optimizedQuality = {
          quality: optimizedCompression.quality,
          informationRecovery: optimizedCompression.quality * 0.95,
          semanticAccuracy: optimizedCompression.quality * 0.93
        };
        
        return { 
          success: true, 
          data: {
            optimizationApplied: true,
            originalQuality: qualityResult.qualityMetrics,
            optimizedQuality,
            improvement: {
              qualityImprovement: optimizedQuality.quality - qualityResult.qualityMetrics.averageQuality,
              informationRetentionImprovement: optimizedQuality.informationRecovery - qualityResult.qualityMetrics.informationRetention,
              semanticAccuracyImprovement: optimizedQuality.semanticAccuracy - qualityResult.qualityMetrics.semanticAccuracy
            },
            finalResult: optimizedCompression,
            optimizationTechniques: ['critical_section_preservation', 'semantic_prioritization', 'structural_optimization']
          }
        };
      } catch (error) {
        return { success: false, error: error as Error };
      }
    }
  };

  // Mock batch processing step
  const batchProcessingCoordination = {
    name: 'batch-processing-coordination',
    description: 'Coordinate batch processing of multiple documents',
    dependencies: ['adaptive-optimization'],
    
    async run(input: any, context: any) {
      try {
        const optimizationResult = context.results?.get('adaptive-optimization')?.data;
        
        if (!input.batchDocuments || input.batchDocuments.length === 0) {
          return { 
            success: true, 
            data: {
              batchProcessing: false,
              singleDocument: optimizationResult.finalResult
            }
          };
        }
        
        // Mock batch processing
        const batchResults = input.batchDocuments.map((doc: any, index: number) => ({
          documentId: doc.id,
          compressionRatio: optimizationResult.finalResult.ratio + (deps.timeProvider.random() - 0.5) * 0.1,
          quality: optimizationResult.optimizedQuality?.quality || optimizationResult.finalResult.quality,
          processingTime: deps.timeProvider.random() * 1000 + 500
        }));
        
        const batchMetrics = {
          averageRatio: batchResults.reduce((sum, r) => sum + r.compressionRatio, 0) / batchResults.length,
          averageQuality: batchResults.reduce((sum, r) => sum + r.quality, 0) / batchResults.length,
          totalProcessingTime: batchResults.reduce((sum, r) => sum + r.processingTime, 0),
          successfulDocuments: batchResults.filter(r => r.quality > 0.7).length
        };
        
        return { 
          success: true, 
          data: {
            batchProcessing: true,
            batchResults,
            batchMetrics,
            totalDocuments: input.batchDocuments.length,
            averageCompressionRatio: batchMetrics.averageRatio,
            averageQuality: batchMetrics.averageQuality
          }
        };
      } catch (error) {
        return { success: false, error: error as Error };
      }
    }
  };

  // Mock results export step
  const resultsExportPersistence = {
    name: 'results-export-persistence',
    description: 'Export results and update coordination logs',
    dependencies: ['batch-processing-coordination'],
    
    async run(input: any, context: any) {
      try {
        const batchResult = context.results?.get('batch-processing-coordination')?.data;
        const optimizationResult = context.results?.get('adaptive-optimization')?.data;
        
        // Mock export to multiple formats
        const exportFormats = input.exportFormats || ['json', 'jsonl', 'csv'];
        const exportResults = {
          exports: {},
          paths: exportFormats.map(format => deps.fileSystemProvider.createTempPath('spr_results', format))
        };
        
        exportFormats.forEach(format => {
          switch (format) {
            case 'json':
              exportResults.exports[format] = JSON.stringify(batchResult, null, 2);
              break;
            case 'jsonl':
              exportResults.exports[format] = JSON.stringify(batchResult);
              break;
            case 'csv':
              exportResults.exports[format] = convertToCSV(batchResult);
              break;
          }
        });
        
        // Mock coordination log update
        const coordinationLogEntry = {
          operation_id: context.id,
          operation_type: 'spr_pipeline_optimization',
          timestamp: deps.timeProvider.now(),
          agent_id: context.agentId,
          trace_id: context.traceId,
          results: {
            documents_processed: batchResult.batchProcessing ? batchResult.totalDocuments : 1,
            average_compression_ratio: batchResult.averageCompressionRatio || optimizationResult.finalResult.ratio,
            average_quality_score: batchResult.averageQuality || optimizationResult.optimizedQuality?.quality,
            optimization_applied: optimizationResult.optimizationApplied,
            total_duration: deps.timeProvider.now() - context.startTime
          }
        };
        
        await deps.apiMock.$fetch('/api/coordination/log-entry', {
          method: 'POST',
          body: coordinationLogEntry
        });
        
        return { 
          success: true, 
          data: {
            exportResults,
            coordinationLogEntry,
            persistenceComplete: true,
            exportPaths: exportResults.paths
          }
        };
      } catch (error) {
        return { success: false, error: error as Error };
      }
    }
  };

  // Add steps to reactor
  reactor.addStep(contentAnalysis);
  reactor.addStep(multiFormatCompression);
  reactor.addStep(qualityValidation);
  reactor.addStep(adaptiveOptimization);
  reactor.addStep(batchProcessingCoordination);
  reactor.addStep(resultsExportPersistence);
  
  return reactor;
};

// Helper functions
function classifyContentType(content: string): 'technical' | 'business' | 'scientific' | 'documentation' {
  const contentLower = content.toLowerCase();
  if (contentLower.includes('technical') || contentLower.includes('algorithm')) return 'technical';
  if (contentLower.includes('business') || contentLower.includes('revenue')) return 'business';
  if (contentLower.includes('research') || contentLower.includes('hypothesis')) return 'scientific';
  return 'documentation';
}

function analyzeComplexity(content: string, wordCount: number): 'low' | 'medium' | 'high' {
  const sentences = content.split(/[.!?]+/).length;
  const avgWordsPerSentence = wordCount / sentences;
  
  if (avgWordsPerSentence > 25) return 'high';
  if (avgWordsPerSentence > 15) return 'medium';
  return 'low';
}

function extractDomain(content: string): string {
  const contentLower = content.toLowerCase();
  if (contentLower.includes('technology')) return 'technology';
  if (contentLower.includes('finance')) return 'finance';
  return 'general';
}

function calculateCompressionScore(result: any, strategy: any): number {
  const ratioScore = Math.abs(result.ratio - strategy.targetRatio) < 0.1 ? 1.0 : 0.5;
  const qualityScore = result.quality >= strategy.qualityThreshold ? 1.0 : result.quality / strategy.qualityThreshold;
  return (ratioScore * 0.4) + (qualityScore * 0.6);
}

function generateQualityImprovements(metrics: any): string[] {
  const improvements = [];
  if (metrics.informationRetention < 0.8) improvements.push('Improve information retention');
  if (metrics.structuralIntegrity < 0.75) improvements.push('Enhance structural preservation');
  if (metrics.semanticAccuracy < 0.8) improvements.push('Refine semantic analysis');
  return improvements;
}

function convertToCSV(data: any): string {
  if (data.batchResults) {
    const headers = 'documentId,compressionRatio,quality,processingTime\n';
    const rows = data.batchResults.map((r: any) => 
      `${r.documentId},${r.compressionRatio},${r.quality},${r.processingTime}`
    ).join('\n');
    return headers + rows;
  }
  return 'compressionRatio,quality\n' + `${data.finalResult.ratio},${data.finalResult.quality}`;
}

describe('SPR Pipeline Optimization Reactor', () => {
  let testEnv: ReturnType<typeof setupTestEnvironment>;
  let assertions: ReturnType<typeof createAdvancedAssertions>;

  beforeEach(() => {
    vi.useFakeTimers();
    testEnv = setupTestEnvironment();
    assertions = createAdvancedAssertions();
  });

  afterEach(() => {
    vi.useRealTimers();
    testEnv.cleanup();
  });

  describe('Content Analysis', () => {
    it('should analyze content and determine optimal strategy', async () => {
      const reactor = createMockSPRPipelineOptimizationReactor(testEnv);
      const input = generateMockSPRContent();
      
      const result = await reactor.execute(input);
      
      assertions.expectSuccessfulResult(result);
      
      const analysisResult = result.results.get('content-analysis');
      expect(analysisResult.data.type).toBe('technical');
      expect(analysisResult.data.metadata.wordCount).toBeGreaterThan(0);
      expect(analysisResult.data.metadata.complexity).toMatch(/^(low|medium|high)$/);
      expect(analysisResult.data.optimizationStrategy.targetRatio).toBe(0.3);
    });

    it('should classify different content types correctly', async () => {
      const testCases = [
        { content: 'This document contains technical algorithms and implementation details', expectedType: 'technical' },
        { content: 'Business strategy and revenue optimization for market growth', expectedType: 'business' },
        { content: 'Scientific research methodology and hypothesis testing', expectedType: 'scientific' },
        { content: 'Documentation for user guidance and tutorials', expectedType: 'documentation' }
      ];
      
      for (const testCase of testCases) {
        const reactor = createMockSPRPipelineOptimizationReactor(testEnv);
        const result = await reactor.execute({ content: testCase.content });
        
        const analysisResult = result.results.get('content-analysis');
        expect(analysisResult.data.type).toBe(testCase.expectedType);
      }
    });

    it('should adjust strategy based on content complexity', async () => {
      const complexContent = {
        content: 'This is an extremely complex technical document with sophisticated algorithms, intricate implementation details, advanced mathematical concepts, and comprehensive system architecture patterns that require extensive explanation and detailed analysis.'
      };
      
      const reactor = createMockSPRPipelineOptimizationReactor(testEnv);
      const result = await reactor.execute(complexContent);
      
      const analysisResult = result.results.get('content-analysis');
      expect(analysisResult.data.metadata.complexity).toBe('high');
      expect(analysisResult.data.optimizationStrategy.qualityThreshold).toBe(0.9);
    });
  });

  describe('Multi-Format Compression', () => {
    it('should compress content in multiple formats simultaneously', async () => {
      const reactor = createMockSPRPipelineOptimizationReactor(testEnv);
      const input = generateMockSPRContent();
      
      const result = await reactor.execute(input);
      
      const compressionResult = result.results.get('multi-format-compression');
      expect(compressionResult.data.allFormats).toHaveLength(3);
      
      const formats = compressionResult.data.allFormats.map((f: any) => f.format);
      expect(formats).toContain('minimal');
      expect(formats).toContain('standard');
      expect(formats).toContain('extended');
      
      // Verify compression ratios are in expected ranges
      const minimal = compressionResult.data.allFormats.find((f: any) => f.format === 'minimal');
      const standard = compressionResult.data.allFormats.find((f: any) => f.format === 'standard');
      const extended = compressionResult.data.allFormats.find((f: any) => f.format === 'extended');
      
      expect(minimal.ratio).toBeLessThan(standard.ratio);
      expect(standard.ratio).toBeLessThan(extended.ratio);
      expect(minimal.quality).toBeLessThan(extended.quality);
    });

    it('should select optimal format based on strategy', async () => {
      const reactor = createMockSPRPipelineOptimizationReactor(testEnv);
      const input = { ...generateMockSPRContent(), targetRatio: 0.25 };
      
      const result = await reactor.execute(input);
      
      const compressionResult = result.results.get('multi-format-compression');
      expect(compressionResult.data.optimal).toBeDefined();
      expect(compressionResult.data.selectionReasoning).toContain('optimal balance');
      
      // Optimal should be one of the available formats
      const formatNames = compressionResult.data.allFormats.map((f: any) => f.format);
      expect(formatNames).toContain(compressionResult.data.optimal.format);
    });

    it('should calculate compression metrics correctly', async () => {
      const reactor = createMockSPRPipelineOptimizationReactor(testEnv);
      const input = generateMockSPRContent();
      
      const result = await reactor.execute(input);
      
      const compressionResult = result.results.get('multi-format-compression');
      const metrics = compressionResult.data.compressionMetrics;
      
      expect(metrics.averageRatio).toBeGreaterThan(0);
      expect(metrics.averageRatio).toBeLessThan(1);
      expect(metrics.averageQuality).toBeGreaterThan(0);
      expect(metrics.averageQuality).toBeLessThanOrEqual(1);
      expect(metrics.bestRatio).toBeLessThanOrEqual(metrics.averageRatio);
      expect(metrics.bestQuality).toBeGreaterThanOrEqual(metrics.averageQuality);
    });
  });

  describe('Quality Validation', () => {
    it('should perform roundtrip testing with multiple expansions', async () => {
      const reactor = createMockSPRPipelineOptimizationReactor(testEnv);
      const input = generateMockSPRContent();
      
      const result = await reactor.execute(input);
      
      const qualityResult = result.results.get('quality-validation');
      expect(qualityResult.data.decompressionTests).toHaveLength(3);
      
      const expansions = qualityResult.data.decompressionTests.map((t: any) => t.expansion);
      expect(expansions).toContain('brief');
      expect(expansions).toContain('detailed');
      expect(expansions).toContain('comprehensive');
      
      // Quality should generally improve with more comprehensive expansion
      const brief = qualityResult.data.decompressionTests.find((t: any) => t.expansion === 'brief');
      const comprehensive = qualityResult.data.decompressionTests.find((t: any) => t.expansion === 'comprehensive');
      expect(comprehensive.quality).toBeGreaterThanOrEqual(brief.quality);
    });

    it('should validate quality against thresholds', async () => {
      const reactor = createMockSPRPipelineOptimizationReactor(testEnv);
      const input = generateMockSPRContent();
      
      const result = await reactor.execute(input);
      
      const qualityResult = result.results.get('quality-validation');
      const validation = qualityResult.data.validationResult;
      
      expect(validation.overall).toBeGreaterThan(0);
      expect(validation.passesThreshold).toBeDefined();
      expect(validation.informationRetention).toBeDefined();
      expect(validation.structuralIntegrity).toBeDefined();
      expect(validation.semanticAccuracy).toBeDefined();
      expect(validation.consistency).toBeDefined();
    });

    it('should generate quality improvement recommendations', async () => {
      const reactor = createMockSPRPipelineOptimizationReactor(testEnv);
      const input = generateMockSPRContent();
      
      const result = await reactor.execute(input);
      
      const qualityResult = result.results.get('quality-validation');
      expect(qualityResult.data.recommendedImprovements).toBeInstanceOf(Array);
      
      if (qualityResult.data.recommendedImprovements.length > 0) {
        expect(qualityResult.data.recommendedImprovements[0]).toContain('Improve');
      }
    });

    it('should handle quality validation failure with compensation', async () => {
      // Mock a scenario where quality validation consistently fails
      const reactor = createMockSPRPipelineOptimizationReactor(testEnv);
      
      // Override the quality validation to always fail
      const originalStep = reactor.steps.find(s => s.name === 'quality-validation');
      if (originalStep) {
        const originalRun = originalStep.run;
        originalStep.run = async function(input, context) {
          const result = await originalRun.call(this, input, context);
          if (result.success) {
            result.data.passesQualityGate = false;
            result.data.validationResult.passesThreshold = false;
          }
          return result;
        };
      }
      
      const input = generateMockSPRContent();
      const result = await reactor.execute(input);
      
      // Should still complete but trigger optimization
      assertions.expectSuccessfulResult(result);
      const optimizationResult = result.results.get('adaptive-optimization');
      expect(optimizationResult.data.optimizationApplied).toBe(true);
    });
  });

  describe('Adaptive Optimization', () => {
    it('should skip optimization when quality threshold is met', async () => {
      const reactor = createMockSPRPipelineOptimizationReactor(testEnv);
      const input = generateMockSPRContent();
      
      const result = await reactor.execute(input);
      
      const optimizationResult = result.results.get('adaptive-optimization');
      
      if (optimizationResult.data.optimizationApplied === false) {
        expect(optimizationResult.data.reason).toBe('quality_threshold_met');
        expect(optimizationResult.data.finalResult).toBeDefined();
      }
    });

    it('should apply 80/20 optimization when quality is insufficient', async () => {
      const reactor = createMockSPRPipelineOptimizationReactor(testEnv);
      
      // Mock low quality scenario by overriding quality validation
      const qualityStep = reactor.steps.find(s => s.name === 'quality-validation');
      if (qualityStep) {
        const originalRun = qualityStep.run;
        qualityStep.run = async function(input, context) {
          const result = await originalRun.call(this, input, context);
          if (result.success) {
            result.data.passesQualityGate = false;
            result.data.qualityMetrics.overallScore = 0.6; // Below threshold
          }
          return result;
        };
      }
      
      const input = generateMockSPRContent();
      const result = await reactor.execute(input);
      
      const optimizationResult = result.results.get('adaptive-optimization');
      expect(optimizationResult.data.optimizationApplied).toBe(true);
      expect(optimizationResult.data.optimizationTechniques).toContain('critical_section_preservation');
      expect(optimizationResult.data.improvement.qualityImprovement).toBeGreaterThan(0);
    });

    it('should preserve critical sections in optimization', async () => {
      const reactor = createMockSPRPipelineOptimizationReactor(testEnv);
      
      // Force optimization by mocking low quality
      const qualityStep = reactor.steps.find(s => s.name === 'quality-validation');
      if (qualityStep) {
        const originalRun = qualityStep.run;
        qualityStep.run = async function(input, context) {
          const result = await originalRun.call(this, input, context);
          if (result.success) {
            result.data.passesQualityGate = false;
          }
          return result;
        };
      }
      
      const input = generateMockSPRContent();
      const result = await reactor.execute(input);
      
      const optimizationResult = result.results.get('adaptive-optimization');
      if (optimizationResult.data.optimizationApplied) {
        expect(optimizationResult.data.finalResult.compressed).toContain('[CRITICAL_SECTIONS_PRESERVED]');
        expect(optimizationResult.data.finalResult.quality).toBeGreaterThan(0.8);
      }
    });
  });

  describe('Batch Processing', () => {
    it('should handle single document processing', async () => {
      const reactor = createMockSPRPipelineOptimizationReactor(testEnv);
      const input = generateMockSPRContent();
      
      const result = await reactor.execute(input);
      
      const batchResult = result.results.get('batch-processing-coordination');
      expect(batchResult.data.batchProcessing).toBe(false);
      expect(batchResult.data.singleDocument).toBeDefined();
    });

    it('should process multiple documents in batch', async () => {
      const reactor = createMockSPRPipelineOptimizationReactor(testEnv);
      const input = {
        ...generateMockSPRContent(),
        batchDocuments: [
          { id: 'doc1', content: 'Technical document 1' },
          { id: 'doc2', content: 'Technical document 2' },
          { id: 'doc3', content: 'Technical document 3' }
        ]
      };
      
      const result = await reactor.execute(input);
      
      const batchResult = result.results.get('batch-processing-coordination');
      expect(batchResult.data.batchProcessing).toBe(true);
      expect(batchResult.data.totalDocuments).toBe(3);
      expect(batchResult.data.batchResults).toHaveLength(3);
      
      // Verify each document has required fields
      batchResult.data.batchResults.forEach((docResult: any) => {
        expect(docResult.documentId).toBeDefined();
        expect(docResult.compressionRatio).toBeGreaterThan(0);
        expect(docResult.quality).toBeGreaterThan(0);
        expect(docResult.processingTime).toBeGreaterThan(0);
      });
    });

    it('should calculate accurate batch metrics', async () => {
      const reactor = createMockSPRPipelineOptimizationReactor(testEnv);
      const input = {
        ...generateMockSPRContent(),
        batchDocuments: [
          { id: 'doc1', content: 'Document 1' },
          { id: 'doc2', content: 'Document 2' }
        ]
      };
      
      const result = await reactor.execute(input);
      
      const batchResult = result.results.get('batch-processing-coordination');
      const metrics = batchResult.data.batchMetrics;
      
      expect(metrics.averageRatio).toBeGreaterThan(0);
      expect(metrics.averageQuality).toBeGreaterThan(0);
      expect(metrics.totalProcessingTime).toBeGreaterThan(0);
      expect(metrics.successfulDocuments).toBeGreaterThanOrEqual(0);
      expect(metrics.successfulDocuments).toBeLessThanOrEqual(input.batchDocuments.length);
    });
  });

  describe('Results Export and Persistence', () => {
    it('should export results in multiple formats', async () => {
      const reactor = createMockSPRPipelineOptimizationReactor(testEnv);
      const input = {
        ...generateMockSPRContent(),
        exportFormats: ['json', 'jsonl', 'csv']
      };
      
      const result = await reactor.execute(input);
      
      const exportResult = result.results.get('results-export-persistence');
      expect(exportResult.data.exportResults.exports).toHaveProperty('json');
      expect(exportResult.data.exportResults.exports).toHaveProperty('jsonl');
      expect(exportResult.data.exportResults.exports).toHaveProperty('csv');
      expect(exportResult.data.exportResults.paths).toHaveLength(3);
      
      // Verify file system provider was called
      expect(testEnv.fileSystemProvider.createTempPath).toHaveBeenCalledWith('spr_results', 'json');
      expect(testEnv.fileSystemProvider.createTempPath).toHaveBeenCalledWith('spr_results', 'csv');
    });

    it('should update coordination logs with operation metrics', async () => {
      const reactor = createMockSPRPipelineOptimizationReactor(testEnv);
      const input = generateMockSPRContent();
      
      const result = await reactor.execute(input);
      
      const exportResult = result.results.get('results-export-persistence');
      const logEntry = exportResult.data.coordinationLogEntry;
      
      expect(logEntry.operation_type).toBe('spr_pipeline_optimization');
      expect(logEntry.operation_id).toBe(result.id);
      expect(logEntry.results.documents_processed).toBeGreaterThanOrEqual(1);
      expect(logEntry.results.average_compression_ratio).toBeGreaterThan(0);
      expect(logEntry.results.total_duration).toBeGreaterThan(0);
      
      // Verify coordination log API was called
      expect(testEnv.apiMock.$fetch).toHaveBeenCalledWith(
        '/api/coordination/log-entry',
        expect.objectContaining({
          method: 'POST',
          body: logEntry
        })
      );
    });

    it('should handle export format variations', async () => {
      const testCases = [
        { exportFormats: ['json'] },
        { exportFormats: ['csv'] },
        { exportFormats: ['json', 'csv'] },
        { exportFormats: undefined } // Should use defaults
      ];
      
      for (const testCase of testCases) {
        const reactor = createMockSPRPipelineOptimizationReactor(testEnv);
        const input = { ...generateMockSPRContent(), ...testCase };
        
        const result = await reactor.execute(input);
        
        const exportResult = result.results.get('results-export-persistence');
        expect(exportResult.data.persistenceComplete).toBe(true);
        expect(exportResult.data.exportPaths.length).toBeGreaterThan(0);
      }
    });
  });

  describe('Error Handling and Edge Cases', () => {
    it('should handle empty content gracefully', async () => {
      const reactor = createMockSPRPipelineOptimizationReactor(testEnv);
      const input = { content: '', targetRatio: 0.3 };
      
      const result = await reactor.execute(input);
      
      // Should handle empty content without crashing
      const analysisResult = result.results.get('content-analysis');
      expect(analysisResult.data.metadata.wordCount).toBe(1); // Empty string splits to 1 empty element
    });

    it('should handle very large content efficiently', async () => {
      const reactor = createMockSPRPipelineOptimizationReactor(testEnv);
      const largeContent = 'Large content '.repeat(10000); // ~130KB content
      const input = { content: largeContent, targetRatio: 0.3 };
      
      const result = await reactor.execute(input);
      
      assertions.expectSuccessfulResult(result);
      const compressionResult = result.results.get('multi-format-compression');
      expect(compressionResult.data.optimal.metrics.originalSize).toBeGreaterThan(100000);
    });

    it('should handle API failures in coordination logging', async () => {
      testEnv.apiMock.$fetch.mockImplementation((url: string) => {
        if (url.includes('/api/coordination/log-entry')) {
          throw new Error('Coordination service unavailable');
        }
        return testEnv.apiMock.$fetch.getMockImplementation()(url);
      });
      
      const reactor = createMockSPRPipelineOptimizationReactor(testEnv);
      const input = generateMockSPRContent();
      
      const result = await reactor.execute(input);
      
      expect(result.state).toBe('failed');
      expect(result.errors[0].message).toBe('Coordination service unavailable');
    });

    it('should validate compression ratio bounds', async () => {
      const reactor = createMockSPRPipelineOptimizationReactor(testEnv);
      const input = { ...generateMockSPRContent(), targetRatio: 1.5 }; // Invalid ratio > 1
      
      const result = await reactor.execute(input);
      
      // Should handle invalid target ratio gracefully
      const analysisResult = result.results.get('content-analysis');
      expect(analysisResult.data.optimizationStrategy.targetRatio).toBeLessThanOrEqual(1.0);
    });
  });

  describe('Performance and Optimization', () => {
    it('should complete processing within reasonable time bounds', async () => {
      const reactor = createMockSPRPipelineOptimizationReactor(testEnv);
      const input = generateMockSPRContent();
      
      const start = performance.now();
      const result = await reactor.execute(input);
      const duration = performance.now() - start;
      
      expect(result.state).toBe('completed');
      expect(duration).toBeLessThan(1000); // Should complete in under 1 second
    });

    it('should demonstrate SPR optimization effectiveness', async () => {
      const reactor = createMockSPRPipelineOptimizationReactor(testEnv);
      const input = generateMockSPRContent();
      
      const result = await reactor.execute(input);
      
      const compressionResult = result.results.get('multi-format-compression');
      assertions.expectSPROptimization(result, 0.7);
      
      // Verify compression achieves target ratio
      expect(compressionResult.data.optimal.ratio).toBeLessThan(0.5);
      expect(compressionResult.data.optimal.quality).toBeGreaterThan(0.7);
    });
  });
});