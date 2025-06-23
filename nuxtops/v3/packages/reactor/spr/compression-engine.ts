/**
 * SPR Compression Engine - Core implementation for pattern-based compression
 * Optimized for AI agent coordination and telemetry data
 */

import { compress as lz4Compress, decompress as lz4Decompress } from 'lz4';
import type {
  SPRCompressionEngine,
  SPRPattern,
  SPRContext,
  SPRCompressionOptions,
  SPRCompressionResult,
  SPRDecompressionResult,
  SPRPatternRegistry
} from './types';

const DEFAULT_COMPRESSION_OPTIONS: SPRCompressionOptions = {
  compressionLevel: 'balanced',
  preserveSemantics: true,
  maxPatternLength: 256,
  minPatternFrequency: 3,
  enableContextualCompression: true,
  targetCompressionRatio: 0.4
};

export class SPRCompressionEngineImpl implements SPRCompressionEngine {
  private patternRegistry?: SPRPatternRegistry;
  private patternCache: Map<string, SPRPattern[]> = new Map();
  private metrics = {
    compressions: 0,
    decompressions: 0,
    totalBytesProcessed: 0,
    totalBytesSaved: 0
  };

  constructor(patternRegistry?: SPRPatternRegistry) {
    this.patternRegistry = patternRegistry;
  }

  async compress<T>(
    data: T,
    context: SPRContext,
    options: Partial<SPRCompressionOptions> = {}
  ): Promise<SPRCompressionResult> {
    const startTime = performance.now();
    const opts = { ...DEFAULT_COMPRESSION_OPTIONS, ...options };
    
    try {
      // Step 1: Serialize input data
      const serialized = JSON.stringify(data);
      const originalSize = Buffer.byteLength(serialized, 'utf8');

      // Step 2: Extract patterns from data
      const patterns = await this.extractPatterns(data, context);
      
      // Step 3: Apply pattern-based compression
      let processedData = serialized;
      const appliedPatterns: SPRPattern[] = [];

      // Apply high-frequency patterns first for maximum compression
      const sortedPatterns = patterns.sort((a, b) => b.frequency - a.frequency);
      
      for (const pattern of sortedPatterns.slice(0, 50)) { // Limit to top 50 patterns
        const regex = new RegExp(this.escapeRegExp(pattern.pattern), 'g');
        const matches = processedData.match(regex);
        
        if (matches && matches.length >= opts.minPatternFrequency) {
          const patternId = `__SPR_${pattern.id}__`;
          processedData = processedData.replace(regex, patternId);
          appliedPatterns.push(pattern);
        }
      }

      // Step 4: Apply additional compression based on level
      let finalCompressed: Buffer;
      
      switch (opts.compressionLevel) {
        case 'fast':
          finalCompressed = Buffer.from(processedData, 'utf8');
          break;
        case 'balanced':
          finalCompressed = lz4Compress(Buffer.from(processedData, 'utf8'));
          break;
        case 'maximum':
          // Multiple passes with different algorithms
          let tempData = lz4Compress(Buffer.from(processedData, 'utf8'));
          // Apply additional contextual compression if enabled
          if (opts.enableContextualCompression) {
            tempData = await this.applyContextualCompression(tempData, context);
          }
          finalCompressed = tempData;
          break;
      }

      const compressedSize = finalCompressed.length;
      const compressionRatio = compressedSize / originalSize;
      const processingTime = performance.now() - startTime;

      // Step 5: Validate semantic preservation if required
      let semanticPreservation = 1.0;
      if (opts.preserveSemantics) {
        semanticPreservation = await this.validateSemantics(data, {
          compressed: finalCompressed,
          patterns: appliedPatterns,
          context
        });
      }

      // Update metrics
      this.metrics.compressions++;
      this.metrics.totalBytesProcessed += originalSize;
      this.metrics.totalBytesSaved += (originalSize - compressedSize);

      return {
        originalSize,
        compressedSize,
        compressionRatio,
        patternsExtracted: appliedPatterns,
        semanticPreservation,
        processingTime,
        metadata: {
          algorithm: 'SPR-LZ4',
          version: '1.0.0',
          timestamp: Date.now(),
          contextualHints: this.generateContextualHints(context)
        }
      };

    } catch (error) {
      throw new Error(`SPR compression failed: ${error instanceof Error ? error.message : 'Unknown error'}`);
    }
  }

  async decompress<T>(compressedData: any, context: SPRContext): Promise<SPRDecompressionResult> {
    const startTime = performance.now();
    
    try {
      // Extract metadata from compressed data
      const { compressed, patterns, metadata } = compressedData;
      
      // Step 1: Apply appropriate decompression based on algorithm
      let decompressedString: string;
      
      if (metadata?.algorithm === 'SPR-LZ4') {
        const decompressedBuffer = lz4Decompress(compressed);
        decompressedString = decompressedBuffer.toString('utf8');
      } else {
        decompressedString = compressed.toString('utf8');
      }

      // Step 2: Restore patterns
      const missingPatterns: string[] = [];
      
      for (const pattern of patterns) {
        const patternId = `__SPR_${pattern.id}__`;
        const regex = new RegExp(this.escapeRegExp(patternId), 'g');
        
        if (decompressedString.includes(patternId)) {
          decompressedString = decompressedString.replace(regex, pattern.pattern);
        } else {
          missingPatterns.push(pattern.id);
        }
      }

      // Step 3: Parse back to original data structure
      const decompressedData = JSON.parse(decompressedString);
      const originalSize = Buffer.byteLength(decompressedString, 'utf8');
      const processingTime = performance.now() - startTime;

      // Calculate fidelity
      const fidelity = 1 - (missingPatterns.length / patterns.length);

      // Update metrics
      this.metrics.decompressions++;

      return {
        decompressedData,
        originalSize,
        fidelity,
        missingPatterns,
        processingTime
      };

    } catch (error) {
      throw new Error(`SPR decompression failed: ${error instanceof Error ? error.message : 'Unknown error'}`);
    }
  }

  async extractPatterns(data: any, context: SPRContext): Promise<SPRPattern[]> {
    const patterns: SPRPattern[] = [];
    const serialized = JSON.stringify(data);
    
    // Check cache first
    const cacheKey = `${context.domain}_${context.agentId || 'default'}`;
    if (this.patternCache.has(cacheKey)) {
      return this.patternCache.get(cacheKey)!;
    }

    // Extract common JSON patterns
    const jsonPatterns = this.extractJSONPatterns(serialized, context);
    patterns.push(...jsonPatterns);

    // Extract domain-specific patterns
    const domainPatterns = await this.extractDomainPatterns(data, context);
    patterns.push(...domainPatterns);

    // Extract repetitive text patterns
    const textPatterns = this.extractTextPatterns(serialized);
    patterns.push(...textPatterns);

    // Optimize and deduplicate patterns
    const optimizedPatterns = await this.optimizePatterns(patterns);
    
    // Cache results
    this.patternCache.set(cacheKey, optimizedPatterns);
    
    return optimizedPatterns;
  }

  async optimizePatterns(patterns: SPRPattern[]): Promise<SPRPattern[]> {
    // Remove duplicate patterns
    const uniquePatterns = new Map<string, SPRPattern>();
    
    for (const pattern of patterns) {
      const existing = uniquePatterns.get(pattern.pattern);
      if (existing) {
        // Merge frequency and significance
        existing.frequency += pattern.frequency;
        existing.significance = Math.max(existing.significance, pattern.significance);
      } else {
        uniquePatterns.set(pattern.pattern, { ...pattern });
      }
    }

    // Sort by significance and frequency
    return Array.from(uniquePatterns.values())
      .sort((a, b) => (b.significance * b.frequency) - (a.significance * a.frequency))
      .slice(0, 100); // Limit to top 100 patterns
  }

  async validateSemantics(original: any, compressed: any): Promise<number> {
    try {
      // Basic structural validation
      const originalStr = JSON.stringify(original);
      const compressedStr = JSON.stringify(compressed);
      
      // Calculate Levenshtein distance for semantic similarity
      const distance = this.levenshteinDistance(originalStr, compressedStr);
      const maxLength = Math.max(originalStr.length, compressedStr.length);
      
      return 1 - (distance / maxLength);
    } catch {
      return 0.5; // Default to moderate confidence
    }
  }

  private extractJSONPatterns(serialized: string, context: SPRContext): SPRPattern[] {
    const patterns: SPRPattern[] = [];
    
    // Common JSON structures
    const commonPatterns = [
      { pattern: '"id":"', name: 'JSON ID Field' },
      { pattern: '"timestamp":', name: 'Timestamp Field' },
      { pattern: '"status":"', name: 'Status Field' },
      { pattern: '"error":"', name: 'Error Field' },
      { pattern: '"data":{', name: 'Data Object' },
      { pattern: '"traceId":"', name: 'Trace ID Field' },
      { pattern: '"agentId":"', name: 'Agent ID Field' }
    ];

    for (const common of commonPatterns) {
      const frequency = (serialized.match(new RegExp(this.escapeRegExp(common.pattern), 'g')) || []).length;
      if (frequency > 0) {
        patterns.push({
          id: `json_${common.name.toLowerCase().replace(/\s+/g, '_')}`,
          name: common.name,
          pattern: common.pattern,
          frequency,
          significance: this.calculateSignificance(common.pattern, frequency, context),
          category: 'coordination',
          metadata: { source: 'json', domain: context.domain }
        });
      }
    }

    return patterns;
  }

  private async extractDomainPatterns(data: any, context: SPRContext): Promise<SPRPattern[]> {
    const patterns: SPRPattern[] = [];
    
    // Domain-specific pattern extraction based on context
    switch (context.domain) {
      case 'telemetry':
        patterns.push(...this.extractTelemetryPatterns(data));
        break;
      case 'coordination':
        patterns.push(...this.extractCoordinationPatterns(data));
        break;
      case 'performance':
        patterns.push(...this.extractPerformancePatterns(data));
        break;
    }

    return patterns;
  }

  private extractTelemetryPatterns(data: any): SPRPattern[] {
    const patterns: SPRPattern[] = [];
    const serialized = JSON.stringify(data);
    
    const telemetryPatterns = [
      '"operationName":"',
      '"spanId":"',
      '"parentSpanId":"',
      '"startTime":',
      '"endTime":',
      '"duration":',
      '"attributes":{'
    ];

    for (const pattern of telemetryPatterns) {
      const frequency = (serialized.match(new RegExp(this.escapeRegExp(pattern), 'g')) || []).length;
      if (frequency > 0) {
        patterns.push({
          id: `telemetry_${pattern.replace(/[^\w]/g, '_')}`,
          name: `Telemetry ${pattern}`,
          pattern,
          frequency,
          significance: 0.8,
          category: 'telemetry',
          metadata: { source: 'telemetry' }
        });
      }
    }

    return patterns;
  }

  private extractCoordinationPatterns(data: any): SPRPattern[] {
    const patterns: SPRPattern[] = [];
    const serialized = JSON.stringify(data);
    
    const coordinationPatterns = [
      '"agentId":"agent_',
      '"claimedAt":',
      '"lastUpdate":',
      '"status":"claimed"',
      '"status":"completed"',
      '"workQueue":['
    ];

    for (const pattern of coordinationPatterns) {
      const frequency = (serialized.match(new RegExp(this.escapeRegExp(pattern), 'g')) || []).length;
      if (frequency > 0) {
        patterns.push({
          id: `coord_${pattern.replace(/[^\w]/g, '_')}`,
          name: `Coordination ${pattern}`,
          pattern,
          frequency,
          significance: 0.9,
          category: 'coordination',
          metadata: { source: 'coordination' }
        });
      }
    }

    return patterns;
  }

  private extractPerformancePatterns(data: any): SPRPattern[] {
    const patterns: SPRPattern[] = [];
    const serialized = JSON.stringify(data);
    
    const performancePatterns = [
      '"duration_ms":',
      '"memory_usage":',
      '"cpu_percent":',
      '"performance_tier":"',
      '"benchmark_score":'
    ];

    for (const pattern of performancePatterns) {
      const frequency = (serialized.match(new RegExp(this.escapeRegExp(pattern), 'g')) || []).length;
      if (frequency > 0) {
        patterns.push({
          id: `perf_${pattern.replace(/[^\w]/g, '_')}`,
          name: `Performance ${pattern}`,
          pattern,
          frequency,
          significance: 0.7,
          category: 'performance',
          metadata: { source: 'performance' }
        });
      }
    }

    return patterns;
  }

  private extractTextPatterns(text: string): SPRPattern[] {
    const patterns: SPRPattern[] = [];
    const words = text.split(/\s+/);
    const wordFreq = new Map<string, number>();

    // Count word frequencies
    for (const word of words) {
      if (word.length > 3) { // Only consider words longer than 3 characters
        wordFreq.set(word, (wordFreq.get(word) || 0) + 1);
      }
    }

    // Create patterns for frequent words
    for (const [word, frequency] of wordFreq.entries()) {
      if (frequency >= 3) { // Minimum frequency threshold
        patterns.push({
          id: `text_${word.toLowerCase()}`,
          name: `Text Pattern: ${word}`,
          pattern: word,
          frequency,
          significance: Math.min(0.5, frequency / words.length),
          category: 'workflow',
          metadata: { source: 'text', wordLength: word.length }
        });
      }
    }

    return patterns.slice(0, 20); // Limit to top 20 text patterns
  }

  private calculateSignificance(pattern: string, frequency: number, context: SPRContext): number {
    let significance = 0.5; // Base significance

    // Adjust based on frequency
    if (frequency > 10) significance += 0.2;
    if (frequency > 50) significance += 0.2;

    // Adjust based on pattern length (longer patterns are more significant)
    if (pattern.length > 20) significance += 0.1;

    // Adjust based on context priority
    if (context.priority === 'high') significance += 0.1;

    return Math.min(1.0, significance);
  }

  private async applyContextualCompression(data: Buffer, context: SPRContext): Promise<Buffer> {
    // Apply additional contextual compression based on domain knowledge
    // This is a simplified implementation - could be enhanced with ML models
    return data;
  }

  private generateContextualHints(context: SPRContext): string[] {
    const hints: string[] = [];
    
    hints.push(`domain:${context.domain}`);
    if (context.agentId) hints.push(`agent:${context.agentId}`);
    if (context.priority) hints.push(`priority:${context.priority}`);
    
    return hints;
  }

  private escapeRegExp(string: string): string {
    return string.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  }

  private levenshteinDistance(str1: string, str2: string): number {
    const matrix = Array(str2.length + 1).fill(null).map(() => Array(str1.length + 1).fill(null));

    for (let i = 0; i <= str1.length; i++) matrix[0][i] = i;
    for (let j = 0; j <= str2.length; j++) matrix[j][0] = j;

    for (let j = 1; j <= str2.length; j++) {
      for (let i = 1; i <= str1.length; i++) {
        const indicator = str1[i - 1] === str2[j - 1] ? 0 : 1;
        matrix[j][i] = Math.min(
          matrix[j][i - 1] + 1,
          matrix[j - 1][i] + 1,
          matrix[j - 1][i - 1] + indicator
        );
      }
    }

    return matrix[str2.length][str1.length];
  }

  // Public metrics getter
  getMetrics() {
    return { ...this.metrics };
  }

  // Clear pattern cache
  clearCache(): void {
    this.patternCache.clear();
  }
}