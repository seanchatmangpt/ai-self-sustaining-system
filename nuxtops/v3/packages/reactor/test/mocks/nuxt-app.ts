/**
 * Mock Nuxt app composables for testing
 */

import { vi } from 'vitest';

export const useNuxtApp = vi.fn(() => ({
  $reactor: vi.fn(),
  $reactorSteps: {
    apiCall: vi.fn(),
    stateUpdate: vi.fn(),
    fileUpload: vi.fn(),
    validate: vi.fn()
  },
  $pinia: {
    state: {
      value: {
        reactor: {
          activeReactors: new Map(),
          results: new Map(),
          workClaims: []
        }
      }
    }
  }
}));

export const useState = vi.fn((key, init) => {
  const value = init ? init() : null;
  return { value };
});

export const useAsyncData = vi.fn((key, handler, options) => ({
  data: { value: null },
  pending: { value: false },
  error: { value: null },
  refresh: vi.fn()
}));

export const navigateTo = vi.fn();

export const defineNuxtPlugin = vi.fn((plugin) => plugin);

export const $fetch = vi.fn();