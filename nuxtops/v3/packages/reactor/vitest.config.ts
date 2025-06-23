/**
 * Vitest configuration for Nuxt Reactor tests
 */

import { defineConfig } from 'vitest/config';
import { resolve } from 'path';

export default defineConfig({
  test: {
    globals: true,
    environment: 'happy-dom',
    setupFiles: ['./test/setup.ts'],
    coverage: {
      provider: 'v8',
      reporter: ['text', 'json', 'html'],
      exclude: [
        'node_modules/',
        'test/',
        'examples/',
        'dist/',
        '**/*.d.ts',
        '**/*.config.*'
      ],
      thresholds: {
        global: {
          branches: 80,
          functions: 80,
          lines: 80,
          statements: 80
        }
      }
    },
    testTimeout: 10000, // 10 seconds for integration tests
    hookTimeout: 10000
  },
  resolve: {
    alias: {
      '#app': resolve(__dirname, './test/mocks/nuxt-app.ts'),
      '#internal/nitro': resolve(__dirname, './test/mocks/nitro.ts'),
      '#internal/nitro/storage': resolve(__dirname, './test/mocks/nitro-storage.ts')
    }
  }
});