/**
 * SPR Pattern Registry - Manages pattern storage and retrieval
 * Optimized for distributed agent coordination scenarios
 */

import type { SPRPattern, SPRPatternRegistry } from './types';

export class InMemoryPatternRegistry implements SPRPatternRegistry {
  private patterns: Map<string, SPRPattern> = new Map();
  private categoryIndex: Map<SPRPattern['category'], Set<string>> = new Map();
  private frequencyIndex: Map<number, Set<string>> = new Map();

  constructor() {
    // Initialize category indices
    const categories: SPRPattern['category'][] = ['coordination', 'telemetry', 'workflow', 'error', 'performance'];
    for (const category of categories) {
      this.categoryIndex.set(category, new Set());
    }
  }

  async registerPattern(pattern: SPRPattern): Promise<void> {
    // Store pattern
    this.patterns.set(pattern.id, pattern);
    
    // Update category index
    const categorySet = this.categoryIndex.get(pattern.category) || new Set();
    categorySet.add(pattern.id);
    this.categoryIndex.set(pattern.category, categorySet);

    // Update frequency index
    const freqRange = this.getFrequencyRange(pattern.frequency);
    const freqSet = this.frequencyIndex.get(freqRange) || new Set();
    freqSet.add(pattern.id);
    this.frequencyIndex.set(freqRange, freqSet);
  }

  async getPattern(id: string): Promise<SPRPattern | null> {
    return this.patterns.get(id) || null;
  }

  async searchPatterns(query: string, category?: SPRPattern['category']): Promise<SPRPattern[]> {
    const results: SPRPattern[] = [];
    const queryLower = query.toLowerCase();

    // Get patterns from category if specified
    const searchSet = category 
      ? this.categoryIndex.get(category) || new Set()
      : new Set(this.patterns.keys());

    for (const patternId of searchSet) {
      const pattern = this.patterns.get(patternId);
      if (pattern) {
        // Search in name and pattern content
        if (pattern.name.toLowerCase().includes(queryLower) ||
            pattern.pattern.toLowerCase().includes(queryLower)) {
          results.push(pattern);
        }
      }
    }

    // Sort by significance and frequency
    return results.sort((a, b) => (b.significance * b.frequency) - (a.significance * a.frequency));
  }

  async updatePattern(id: string, updates: Partial<SPRPattern>): Promise<void> {
    const existing = this.patterns.get(id);
    if (!existing) {
      throw new Error(`Pattern not found: ${id}`);
    }

    // If category is changing, update indices
    if (updates.category && updates.category !== existing.category) {
      // Remove from old category
      const oldCategorySet = this.categoryIndex.get(existing.category);
      if (oldCategorySet) {
        oldCategorySet.delete(id);
      }

      // Add to new category
      const newCategorySet = this.categoryIndex.get(updates.category) || new Set();
      newCategorySet.add(id);
      this.categoryIndex.set(updates.category, newCategorySet);
    }

    // Update frequency index if frequency changed
    if (updates.frequency !== undefined && updates.frequency !== existing.frequency) {
      // Remove from old frequency range
      const oldFreqRange = this.getFrequencyRange(existing.frequency);
      const oldFreqSet = this.frequencyIndex.get(oldFreqRange);
      if (oldFreqSet) {
        oldFreqSet.delete(id);
      }

      // Add to new frequency range
      const newFreqRange = this.getFrequencyRange(updates.frequency);
      const newFreqSet = this.frequencyIndex.get(newFreqRange) || new Set();
      newFreqSet.add(id);
      this.frequencyIndex.set(newFreqRange, newFreqSet);
    }

    // Update the pattern
    const updatedPattern = { ...existing, ...updates, id }; // Preserve ID
    this.patterns.set(id, updatedPattern);
  }

  async deletePattern(id: string): Promise<void> {
    const pattern = this.patterns.get(id);
    if (!pattern) {
      return; // Pattern doesn't exist
    }

    // Remove from main storage
    this.patterns.delete(id);

    // Remove from category index
    const categorySet = this.categoryIndex.get(pattern.category);
    if (categorySet) {
      categorySet.delete(id);
    }

    // Remove from frequency index
    const freqRange = this.getFrequencyRange(pattern.frequency);
    const freqSet = this.frequencyIndex.get(freqRange);
    if (freqSet) {
      freqSet.delete(id);
    }
  }

  async getPatternStats(): Promise<{
    totalPatterns: number;
    categoryDistribution: Record<SPRPattern['category'], number>;
    averageFrequency: number;
    topPatterns: SPRPattern[];
  }> {
    const totalPatterns = this.patterns.size;
    
    // Calculate category distribution
    const categoryDistribution: Record<SPRPattern['category'], number> = {
      coordination: 0,
      telemetry: 0,
      workflow: 0,
      error: 0,
      performance: 0
    };

    let totalFrequency = 0;
    const allPatterns: SPRPattern[] = [];

    for (const pattern of this.patterns.values()) {
      categoryDistribution[pattern.category]++;
      totalFrequency += pattern.frequency;
      allPatterns.push(pattern);
    }

    const averageFrequency = totalPatterns > 0 ? totalFrequency / totalPatterns : 0;

    // Get top 10 patterns by significance * frequency
    const topPatterns = allPatterns
      .sort((a, b) => (b.significance * b.frequency) - (a.significance * a.frequency))
      .slice(0, 10);

    return {
      totalPatterns,
      categoryDistribution,
      averageFrequency,
      topPatterns
    };
  }

  // Additional utility methods
  async getPatternsByCategory(category: SPRPattern['category']): Promise<SPRPattern[]> {
    const categoryIds = this.categoryIndex.get(category) || new Set();
    const patterns: SPRPattern[] = [];

    for (const id of categoryIds) {
      const pattern = this.patterns.get(id);
      if (pattern) {
        patterns.push(pattern);
      }
    }

    return patterns.sort((a, b) => b.frequency - a.frequency);
  }

  async getHighFrequencyPatterns(minFrequency: number = 10): Promise<SPRPattern[]> {
    const patterns: SPRPattern[] = [];

    for (const pattern of this.patterns.values()) {
      if (pattern.frequency >= minFrequency) {
        patterns.push(pattern);
      }
    }

    return patterns.sort((a, b) => b.frequency - a.frequency);
  }

  async getPatternsBySignificance(minSignificance: number = 0.7): Promise<SPRPattern[]> {
    const patterns: SPRPattern[] = [];

    for (const pattern of this.patterns.values()) {
      if (pattern.significance >= minSignificance) {
        patterns.push(pattern);
      }
    }

    return patterns.sort((a, b) => b.significance - a.significance);
  }

  // Pattern analytics
  async analyzePatternUsage(): Promise<{
    mostUsedPatterns: SPRPattern[];
    leastUsedPatterns: SPRPattern[];
    categoryEfficiency: Record<SPRPattern['category'], number>;
    recommendedOptimizations: string[];
  }> {
    const allPatterns = Array.from(this.patterns.values());
    
    const mostUsedPatterns = allPatterns
      .sort((a, b) => b.frequency - a.frequency)
      .slice(0, 5);

    const leastUsedPatterns = allPatterns
      .sort((a, b) => a.frequency - b.frequency)
      .slice(0, 5);

    // Calculate category efficiency (significance * frequency)
    const categoryEfficiency: Record<SPRPattern['category'], number> = {
      coordination: 0,
      telemetry: 0,
      workflow: 0,
      error: 0,
      performance: 0
    };

    const categoryCounts: Record<SPRPattern['category'], number> = {
      coordination: 0,
      telemetry: 0,
      workflow: 0,
      error: 0,
      performance: 0
    };

    for (const pattern of allPatterns) {
      categoryEfficiency[pattern.category] += pattern.significance * pattern.frequency;
      categoryCounts[pattern.category]++;
    }

    // Normalize by category count
    for (const category in categoryEfficiency) {
      const cat = category as SPRPattern['category'];
      if (categoryCounts[cat] > 0) {
        categoryEfficiency[cat] /= categoryCounts[cat];
      }
    }

    // Generate recommendations
    const recommendedOptimizations: string[] = [];
    
    if (leastUsedPatterns.some(p => p.frequency < 2)) {
      recommendedOptimizations.push('Remove patterns with frequency < 2 to reduce registry size');
    }

    const lowSignificancePatterns = allPatterns.filter(p => p.significance < 0.3);
    if (lowSignificancePatterns.length > allPatterns.length * 0.2) {
      recommendedOptimizations.push('Review and optimize low-significance patterns');
    }

    const dominantCategory = Object.entries(categoryCounts)
      .sort(([,a], [,b]) => b - a)[0][0] as SPRPattern['category'];
    
    if (categoryCounts[dominantCategory] > allPatterns.length * 0.6) {
      recommendedOptimizations.push(`Consider balancing pattern categories (${dominantCategory} dominates)`);
    }

    return {
      mostUsedPatterns,
      leastUsedPatterns,
      categoryEfficiency,
      recommendedOptimizations
    };
  }

  // Batch operations
  async importPatterns(patterns: SPRPattern[]): Promise<{ imported: number; skipped: number; errors: string[] }> {
    let imported = 0;
    let skipped = 0;
    const errors: string[] = [];

    for (const pattern of patterns) {
      try {
        if (this.patterns.has(pattern.id)) {
          skipped++;
          continue;
        }

        await this.registerPattern(pattern);
        imported++;
      } catch (error) {
        errors.push(`Failed to import pattern ${pattern.id}: ${error instanceof Error ? error.message : 'Unknown error'}`);
      }
    }

    return { imported, skipped, errors };
  }

  async exportPatterns(category?: SPRPattern['category']): Promise<SPRPattern[]> {
    if (category) {
      return this.getPatternsByCategory(category);
    }

    return Array.from(this.patterns.values());
  }

  // Maintenance operations
  async optimizeRegistry(): Promise<{
    patternsRemoved: number;
    indicesRebuilt: boolean;
    optimizationDetails: string[];
  }> {
    const details: string[] = [];
    let patternsRemoved = 0;

    // Remove patterns with very low frequency and significance
    const patternsToRemove: string[] = [];
    
    for (const [id, pattern] of this.patterns.entries()) {
      if (pattern.frequency < 2 && pattern.significance < 0.2) {
        patternsToRemove.push(id);
      }
    }

    for (const id of patternsToRemove) {
      await this.deletePattern(id);
      patternsRemoved++;
    }

    if (patternsRemoved > 0) {
      details.push(`Removed ${patternsRemoved} low-value patterns`);
    }

    // Rebuild indices for consistency
    await this.rebuildIndices();
    details.push('Rebuilt all indices for optimal performance');

    return {
      patternsRemoved,
      indicesRebuilt: true,
      optimizationDetails: details
    };
  }

  private async rebuildIndices(): Promise<void> {
    // Clear existing indices
    this.categoryIndex.clear();
    this.frequencyIndex.clear();

    // Rebuild indices
    const categories: SPRPattern['category'][] = ['coordination', 'telemetry', 'workflow', 'error', 'performance'];
    for (const category of categories) {
      this.categoryIndex.set(category, new Set());
    }

    for (const pattern of this.patterns.values()) {
      // Rebuild category index
      const categorySet = this.categoryIndex.get(pattern.category) || new Set();
      categorySet.add(pattern.id);
      this.categoryIndex.set(pattern.category, categorySet);

      // Rebuild frequency index
      const freqRange = this.getFrequencyRange(pattern.frequency);
      const freqSet = this.frequencyIndex.get(freqRange) || new Set();
      freqSet.add(pattern.id);
      this.frequencyIndex.set(freqRange, freqSet);
    }
  }

  private getFrequencyRange(frequency: number): number {
    // Group frequencies into ranges for indexing
    if (frequency < 5) return 0;
    if (frequency < 10) return 5;
    if (frequency < 50) return 10;
    if (frequency < 100) return 50;
    return 100;
  }

  // Debug/development helpers
  async getRegistryHealth(): Promise<{
    status: 'healthy' | 'warning' | 'critical';
    issues: string[];
    recommendations: string[];
  }> {
    const issues: string[] = [];
    const recommendations: string[] = [];
    
    const stats = await this.getPatternStats();
    
    // Check for issues
    if (stats.totalPatterns === 0) {
      issues.push('No patterns registered');
      return { status: 'critical', issues, recommendations: ['Register initial patterns'] };
    }

    if (stats.averageFrequency < 3) {
      issues.push('Low average pattern frequency');
      recommendations.push('Review pattern extraction criteria');
    }

    // Check category balance
    const maxCategorySize = Math.max(...Object.values(stats.categoryDistribution));
    const minCategorySize = Math.min(...Object.values(stats.categoryDistribution));
    
    if (maxCategorySize > minCategorySize * 10) {
      issues.push('Unbalanced category distribution');
      recommendations.push('Balance pattern categories for optimal performance');
    }

    // Check for orphaned indices
    let totalIndexedPatterns = 0;
    for (const categorySet of this.categoryIndex.values()) {
      totalIndexedPatterns += categorySet.size;
    }

    if (totalIndexedPatterns !== stats.totalPatterns) {
      issues.push('Index inconsistency detected');
      recommendations.push('Run registry optimization to rebuild indices');
    }

    const status = issues.length === 0 ? 'healthy' : issues.length <= 2 ? 'warning' : 'critical';
    
    return { status, issues, recommendations };
  }
}