/**
 * Mock Nitro storage for testing
 */

import { vi } from 'vitest';

const storage = new Map<string, any>();

export const setItem = vi.fn().mockImplementation(async (key: string, value: any) => {
  storage.set(key, value);
  return Promise.resolve();
});

export const getItem = vi.fn().mockImplementation(async (key: string) => {
  return Promise.resolve(storage.get(key));
});

export const removeItem = vi.fn().mockImplementation(async (key: string) => {
  storage.delete(key);
  return Promise.resolve();
});

export const clear = vi.fn().mockImplementation(async () => {
  storage.clear();
  return Promise.resolve();
});

export const keys = vi.fn().mockImplementation(async () => {
  return Promise.resolve(Array.from(storage.keys()));
});