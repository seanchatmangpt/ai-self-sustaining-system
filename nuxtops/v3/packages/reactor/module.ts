/**
 * Nuxt Reactor Module
 * Core module definition for Nuxt 3 integration
 */

import { defineNuxtModule, addPlugin, createResolver, addImports } from '@nuxt/kit';
import type { ReactorOptions } from './types';

export interface ModuleOptions extends ReactorOptions {
  /**
   * Enable automatic telemetry collection
   * @default true
   */
  telemetry?: boolean;
  
  /**
   * Enable coordination middleware
   * @default true
   */
  coordination?: boolean;
  
  /**
   * Enable SPR compression
   * @default false
   */
  spr?: boolean;
  
  /**
   * Enable performance monitoring
   * @default false
   */
  monitoring?: boolean;
  
  /**
   * Custom telemetry endpoint
   * @default '/api/telemetry'
   */
  telemetryEndpoint?: string;
  
  /**
   * Enable development logging
   * @default process.env.NODE_ENV === 'development'
   */
  devLogs?: boolean;
}

export default defineNuxtModule<ModuleOptions>({
  meta: {
    name: '@nuxtops/reactor',
    configKey: 'reactor',
    compatibility: {
      nuxt: '^3.8.0'
    }
  },
  defaults: {
    telemetry: true,
    coordination: true,
    spr: false,
    monitoring: false,
    telemetryEndpoint: '/api/telemetry',
    devLogs: process.env.NODE_ENV === 'development',
    maxConcurrency: 5,
    timeout: 300000
  },
  setup(options, nuxt) {
    const resolver = createResolver(import.meta.url);
    
    // Add the plugin
    addPlugin({
      src: resolver.resolve('./integrations/nuxt-plugin.ts'),
      options
    });
    
    // Add composable imports
    addImports([
      {
        name: 'useReactor',
        as: 'useReactor',
        from: resolver.resolve('./composables/useReactor.ts')
      },
      {
        name: 'useReactorCoordination',
        as: 'useReactorCoordination',
        from: resolver.resolve('./composables/useReactorCoordination.ts')
      },
      {
        name: 'useReactorTelemetry',
        as: 'useReactorTelemetry',
        from: resolver.resolve('./composables/useReactorTelemetry.ts')
      },
      {
        name: 'useReactorPerformance',
        as: 'useReactorPerformance',
        from: resolver.resolve('./composables/useReactorPerformance.ts')
      },
      {
        name: 'useReactorSPR',
        as: 'useReactorSPR',
        from: resolver.resolve('./composables/useReactorSPR.ts')
      }
    ]);
    
    // Add Nitro integration for server-side tasks
    if (nuxt.options.nitro) {
      nuxt.options.nitro.experimental = nuxt.options.nitro.experimental || {};
      nuxt.options.nitro.experimental.tasks = true;
      
      // Add task adapter
      nuxt.options.nitro.plugins = nuxt.options.nitro.plugins || [];
      nuxt.options.nitro.plugins.push(
        resolver.resolve('./integrations/nitro-task-adapter.ts')
      );
    }
    
    // Development mode enhancements
    if (nuxt.options.dev && options.devLogs) {
      console.log('🚀 Nuxt Reactor module loaded with options:', {
        telemetry: options.telemetry,
        coordination: options.coordination,
        spr: options.spr,
        monitoring: options.monitoring,
        maxConcurrency: options.maxConcurrency
      });
    }
    
    // Add module types
    nuxt.options.typescript = nuxt.options.typescript || {};
    nuxt.options.typescript.includeWorkspace = true;
  }
});

// Export types for module consumers
export type { ReactorOptions, ModuleOptions };
export * from './types';
export * from './core/reactor-engine';
export * from './core/advanced-coordination';
export * from './middleware';
export * from './composables';
export * from './spr';
export * from './monitoring';