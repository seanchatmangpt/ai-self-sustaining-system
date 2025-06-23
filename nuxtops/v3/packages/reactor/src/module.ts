/**
 * Nuxt Reactor Module
 * Core module definition for Nuxt 3 integration
 */

import { defineNuxtModule, addPlugin, createResolver, addImports } from '@nuxt/kit';
import type { ReactorOptions } from '../types';
import type { ErrorBoundaryOptions } from '../errors/error-boundary';

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
   * Custom telemetry endpoint
   * @default '/api/telemetry'
   */
  telemetryEndpoint?: string;
  
  /**
   * Enable development logging
   * @default process.env.NODE_ENV === 'development'
   */
  devLogs?: boolean;
  
  /**
   * Enable SPR (Sparse PicoReactor) optimization
   * @default true
   */
  sprOptimization?: boolean;
  
  /**
   * Enable performance monitoring
   * @default true
   */
  monitoring?: boolean;
  
  /**
   * Enable DevTools integration
   * @default process.env.NODE_ENV === 'development'
   */
  devtools?: boolean;
  
  /**
   * Enable error boundaries
   * @default true
   */
  errorBoundaries?: boolean;
  
  /**
   * Error boundary configuration
   */
  errorBoundaryOptions?: ErrorBoundaryOptions;
  
  /**
   * Enable auto-export of metrics and patterns
   * @default false
   */
  autoExport?: boolean;
  
  /**
   * Auto-export interval in minutes
   * @default 60
   */
  autoExportInterval?: number;
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
    telemetryEndpoint: '/api/telemetry',
    devLogs: process.env.NODE_ENV === 'development',
    sprOptimization: true,
    monitoring: true,
    devtools: process.env.NODE_ENV === 'development',
    errorBoundaries: true,
    autoExport: false,
    autoExportInterval: 60,
    maxConcurrency: 5,
    timeout: 300000,
    errorBoundaryOptions: {
      maxRetries: 3,
      retryDelay: 1000,
      backoffMultiplier: 2,
      failureThreshold: 5,
      circuitTimeout: 60000,
      enableFallback: true
    }
  },
  setup(options, nuxt) {
    const resolver = createResolver(import.meta.url);
    
    // Add the plugin
    addPlugin({
      src: resolver.resolve('../integrations/nuxt-plugin.ts'),
      options
    });
    
    // Add composable imports
    addImports([
      {
        name: 'useReactor',
        as: 'useReactor',
        from: resolver.resolve('../composables/useReactor.ts')
      }
    ]);
    
    // Add SPR composable if enabled
    if (options.sprOptimization) {
      addImports([
        {
          name: 'useSPR',
          as: 'useSPR',
          from: resolver.resolve('../spr/useSPR.ts')
        }
      ]);
    }
    
    // Add monitoring composable if enabled
    if (options.monitoring) {
      addImports([
        {
          name: 'useMonitoring',
          as: 'useMonitoring',
          from: resolver.resolve('../monitoring/useMonitoring.ts')
        }
      ]);
    }
    
    // Add error boundary composable if enabled
    if (options.errorBoundaries) {
      addImports([
        {
          name: 'useErrorBoundary',
          as: 'useErrorBoundary',
          from: resolver.resolve('../errors/useErrorBoundary.ts')
        }
      ]);
    }
    
    // Add Nitro integration for server-side tasks
    if (nuxt.options.nitro) {
      nuxt.options.nitro.experimental = nuxt.options.nitro.experimental || {};
      nuxt.options.nitro.experimental.tasks = true;
      
      // Add task adapter
      nuxt.options.nitro.plugins = nuxt.options.nitro.plugins || [];
      nuxt.options.nitro.plugins.push(
        resolver.resolve('../integrations/nitro-task-adapter.ts')
      );
    }
    
    // Add DevTools integration if enabled
    if (options.devtools && nuxt.options.dev) {
      // DevTools integration will be handled by the plugin
      console.log('📊 Reactor DevTools integration enabled');
    }
    
    // Add runtime config
    nuxt.options.runtimeConfig = nuxt.options.runtimeConfig || {};
    nuxt.options.runtimeConfig.reactor = {
      telemetryEndpoint: options.telemetryEndpoint,
      sprOptimization: options.sprOptimization,
      monitoring: options.monitoring,
      errorBoundaries: options.errorBoundaries,
      autoExport: options.autoExport,
      autoExportInterval: options.autoExportInterval
    };
    
    // Add public runtime config for client-side access
    nuxt.options.runtimeConfig.public = nuxt.options.runtimeConfig.public || {};
    nuxt.options.runtimeConfig.public.reactor = {
      devtools: options.devtools && nuxt.options.dev,
      devLogs: options.devLogs
    };
    
    // Development mode enhancements
    if (nuxt.options.dev && options.devLogs) {
      console.log('🚀 Nuxt Reactor module loaded with options:', {
        telemetry: options.telemetry,
        coordination: options.coordination,
        sprOptimization: options.sprOptimization,
        monitoring: options.monitoring,
        devtools: options.devtools,
        errorBoundaries: options.errorBoundaries,
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
export * from '../types';
export * from '../core/reactor-engine';
export * from '../middleware/telemetry-middleware';
export * from '../middleware/coordination-middleware';