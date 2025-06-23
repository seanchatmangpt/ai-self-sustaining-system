/**
 * Nuxt Plugin for Reactor Integration
 * Provides $reactor helper and Pinia store integration
 */

import { defineNuxtPlugin } from '#app';
import { ReactorEngine } from '../core/reactor-engine';
import { TelemetryMiddleware } from '../middleware/telemetry-middleware';
import { CoordinationMiddleware } from '../middleware/coordination-middleware';
import type { ReactorOptions, ReactorStep } from '../types';

export default defineNuxtPlugin(async (nuxtApp) => {
  // Create reactor factory
  const createReactor = (options?: ReactorOptions) => {
    const reactor = new ReactorEngine({
      ...options,
      middleware: [
        new TelemetryMiddleware({
          onSpanEnd: (span) => {
            // Send telemetry to server or console in dev
            if (process.dev) {
              console.log('[Telemetry]', span);
            }
            
            // In production, send to telemetry endpoint
            if (!process.dev && process.client) {
              $fetch('/api/telemetry', {
                method: 'POST',
                body: { span }
              }).catch(console.error);
            }
          }
        }),
        new CoordinationMiddleware({
          onWorkClaim: (claim) => {
            // Track work claims in Pinia store if available
            const store = nuxtApp.$pinia?.state.value.reactor;
            if (store) {
              store.workClaims.push(claim);
            }
          },
          onWorkComplete: (claim) => {
            // Update work status in Pinia store
            const store = nuxtApp.$pinia?.state.value.reactor;
            if (store) {
              const index = store.workClaims.findIndex(c => c.id === claim.id);
              if (index !== -1) {
                store.workClaims[index] = claim;
              }
            }
          }
        }),
        ...(options?.middleware || [])
      ]
    });
    
    return reactor;
  };
  
  // Provide reactor factory
  nuxtApp.provide('reactor', createReactor);
  
  // Also provide convenient step builders
  nuxtApp.provide('reactorSteps', {
    // API call step builder
    apiCall: (name: string, url: string, options?: any): ReactorStep => ({
      name,
      description: `API call to ${url}`,
      async run(input, context) {
        try {
          const response = await $fetch(url, {
            ...options,
            headers: {
              ...options?.headers,
              'X-Trace-Id': context.traceId,
              'X-Span-Id': context.spanId
            }
          });
          
          return { success: true, data: response };
        } catch (error) {
          return { success: false, error: error as Error };
        }
      },
      async compensate(error, input, context) {
        console.error(`API call to ${url} failed:`, error);
        return 'retry';
      }
    }),
    
    // State update step builder (for Pinia)
    stateUpdate: (name: string, storeName: string, mutation: (store: any, data: any) => void): ReactorStep => ({
      name,
      description: `Update ${storeName} store`,
      async run(input, context) {
        try {
          const store = nuxtApp.$pinia?.state.value[storeName];
          if (!store) {
            throw new Error(`Store ${storeName} not found`);
          }
          
          const previousState = { ...store };
          mutation(store, input);
          
          return { success: true, data: { previousState, newState: store } };
        } catch (error) {
          return { success: false, error: error as Error };
        }
      },
      async undo(result, input, context) {
        const store = nuxtApp.$pinia?.state.value[storeName];
        if (store && result.previousState) {
          Object.assign(store, result.previousState);
        }
      }
    }),
    
    // File upload step builder
    fileUpload: (name: string, endpoint: string): ReactorStep => ({
      name,
      description: `Upload file to ${endpoint}`,
      timeout: 60000, // 1 minute
      async run(input: { file: File }, context) {
        try {
          const formData = new FormData();
          formData.append('file', input.file);
          
          const response = await $fetch(endpoint, {
            method: 'POST',
            body: formData,
            headers: {
              'X-Trace-Id': context.traceId,
              'X-Span-Id': context.spanId
            }
          });
          
          return { success: true, data: response };
        } catch (error) {
          return { success: false, error: error as Error };
        }
      },
      async compensate(error, input, context) {
        // Could implement file deletion here
        return 'abort';
      }
    }),
    
    // Validation step builder
    validate: (name: string, validator: (data: any) => boolean | string): ReactorStep => ({
      name,
      description: 'Validation step',
      async run(input, context) {
        try {
          const result = validator(input);
          
          if (result === true) {
            return { success: true, data: input };
          } else {
            const message = typeof result === 'string' ? result : 'Validation failed';
            return { success: false, error: new Error(message) };
          }
        } catch (error) {
          return { success: false, error: error as Error };
        }
      }
    })
  });
});