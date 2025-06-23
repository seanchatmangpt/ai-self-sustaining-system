/**
 * SPR (Sparse Priming Representation) Compression Pipeline Types
 * Based on research and implementation patterns for AI agent coordination
 */

export interface SPRPattern {
  id: string;
  name: string;
  pattern: string;
  frequency: number;
  significance: number;
  category: 'coordination' | 'telemetry' | 'workflow' | 'error' | 'performance';
  metadata: Record<string, any>;
}

export interface SPRCompressionOptions {
  compressionLevel: 'fast' | 'balanced' | 'maximum';
  preserveSemantics: boolean;
  maxPatternLength: number;
  minPatternFrequency: number;
  enableContextualCompression: boolean;
  targetCompressionRatio: number;
}

export interface SPRCompressionResult {
  originalSize: number;
  compressedSize: number;
  compressionRatio: number;
  patternsExtracted: SPRPattern[];
  semanticPreservation: number;
  processingTime: number;
  metadata: {
    algorithm: string;
    version: string;
    timestamp: number;
    contextualHints: string[];
  };
}

export interface SPRDecompressionResult {
  decompressedData: any;
  originalSize: number;
  fidelity: number;
  missingPatterns: string[];
  processingTime: number;
}

export interface SPRContext {
  domain: string;
  agentId?: string;
  sessionId?: string;
  traceId?: string;
  priority: 'low' | 'medium' | 'high';
  metadata: Record<string, any>;
}

export interface SPRCompressionEngine {
  compress<T>(data: T, context: SPRContext, options?: Partial<SPRCompressionOptions>): Promise<SPRCompressionResult>;
  decompress<T>(compressedData: any, context: SPRContext): Promise<SPRDecompressionResult>;
  extractPatterns(data: any, context: SPRContext): Promise<SPRPattern[]>;
  optimizePatterns(patterns: SPRPattern[]): Promise<SPRPattern[]>;
  validateSemantics(original: any, compressed: any): Promise<number>;
}

export interface SPRPatternRegistry {
  registerPattern(pattern: SPRPattern): Promise<void>;
  getPattern(id: string): Promise<SPRPattern | null>;
  searchPatterns(query: string, category?: SPRPattern['category']): Promise<SPRPattern[]>;
  updatePattern(id: string, updates: Partial<SPRPattern>): Promise<void>;
  deletePattern(id: string): Promise<void>;
  getPatternStats(): Promise<{
    totalPatterns: number;
    categoryDistribution: Record<SPRPattern['category'], number>;
    averageFrequency: number;
    topPatterns: SPRPattern[];
  }>;
}

export interface SPRMiddlewareOptions {
  enabled: boolean;
  compressionThreshold: number;
  contextualCompression: boolean;
  patternRegistry?: SPRPatternRegistry;
  onCompressionComplete?: (result: SPRCompressionResult) => void;
}

export interface SPRMetrics {
  totalCompressions: number;
  totalDecompressions: number;
  averageCompressionRatio: number;
  totalBytesCompressed: number;
  totalBytesSaved: number;
  compressionErrors: number;
  decompressionErrors: number;
  averageProcessingTime: number;
  patternUtilization: Record<string, number>;
}