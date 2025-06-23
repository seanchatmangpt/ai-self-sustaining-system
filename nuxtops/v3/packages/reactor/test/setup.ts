/**
 * Test setup and utilities for Nuxt Reactor tests
 */

import { vi } from 'vitest';
import type { ReactorStep, ReactorContext, StepResult } from '../types';

// Mock fetch for API calls
global.$fetch = vi.fn();

// Test utilities
export const delay = (ms: number) => new Promise(resolve => setTimeout(resolve, ms));

export const createMockStep = (
  name: string,
  options: Partial<ReactorStep> = {}
): ReactorStep => ({
  name,
  run: vi.fn().mockResolvedValue({ success: true, data: { name } }),
  ...options
});

export const createFailingStep = (
  name: string,
  error: Error,
  options: Partial<ReactorStep> = {}
): ReactorStep => ({
  name,
  run: vi.fn().mockResolvedValue({ success: false, error }),
  ...options
});

export const createDelayedStep = (
  name: string,
  delayMs: number,
  options: Partial<ReactorStep> = {}
): ReactorStep => ({
  name,
  run: vi.fn().mockImplementation(async () => {
    await delay(delayMs);
    return { success: true, data: { name, delayMs } };
  }),
  ...options
});

export const createConditionalStep = (
  name: string,
  condition: (input: any, context: ReactorContext) => boolean,
  options: Partial<ReactorStep> = {}
): ReactorStep => ({
  name,
  run: vi.fn().mockImplementation(async (input, context) => {
    if (condition(input, context)) {
      return { success: true, data: { name, passed: true } };
    }
    return { success: false, error: new Error('Condition failed') };
  }),
  ...options
});

export const createStepWithUndo = (
  name: string,
  options: Partial<ReactorStep> = {}
): ReactorStep => {
  const undoFn = vi.fn();
  return {
    name,
    run: vi.fn().mockResolvedValue({ success: true, data: { name, hasUndo: true } }),
    undo: undoFn,
    ...options
  };
};

export const createStepWithCompensation = (
  name: string,
  compensationResult: 'retry' | 'skip' | 'abort' | 'continue' = 'retry',
  options: Partial<ReactorStep> = {}
): ReactorStep => ({
  name,
  run: vi.fn().mockResolvedValue({ success: false, error: new Error('Step failed') }),
  compensate: vi.fn().mockResolvedValue(compensationResult),
  ...options
});

// Assertion helpers
export const expectStepCalled = (step: ReactorStep, times = 1) => {
  expect(step.run).toHaveBeenCalledTimes(times);
};

export const expectStepNotCalled = (step: ReactorStep) => {
  expect(step.run).not.toHaveBeenCalled();
};

export const expectStepCalledWith = (step: ReactorStep, input: any) => {
  expect(step.run).toHaveBeenCalledWith(
    input,
    expect.objectContaining({
      id: expect.any(String),
      startTime: expect.any(Number)
    })
  );
};

export const expectUndoCalled = (step: ReactorStep, times = 1) => {
  expect(step.undo).toHaveBeenCalledTimes(times);
};

export const expectCompensateCalled = (step: ReactorStep, times = 1) => {
  expect(step.compensate).toHaveBeenCalledTimes(times);
};

// Mock middleware
export const createMockMiddleware = (name: string) => {
  return {
    name,
    beforeReactor: vi.fn(),
    beforeStep: vi.fn(),
    afterStep: vi.fn(),
    afterReactor: vi.fn(),
    handleError: vi.fn()
  };
};

// Test data generators
export const generateTestInput = () => ({
  id: Math.random().toString(36).substring(7),
  timestamp: Date.now(),
  data: { test: true }
});

export const generateCheckoutData = () => ({
  userId: 'test-user-123',
  cartItems: [
    { id: 'item-1', quantity: 2, price: 29.99 },
    { id: 'item-2', quantity: 1, price: 49.99 }
  ],
  shippingAddress: {
    street: '123 Test St',
    city: 'Test City',
    state: 'TS',
    zip: '12345'
  },
  paymentMethod: {
    type: 'card',
    last4: '4242'
  }
});

// Performance testing utilities
export class PerformanceTracker {
  private marks: Map<string, number> = new Map();
  
  mark(name: string) {
    this.marks.set(name, performance.now());
  }
  
  measure(startMark: string, endMark: string): number {
    const start = this.marks.get(startMark);
    const end = this.marks.get(endMark);
    
    if (!start || !end) {
      throw new Error('Missing performance marks');
    }
    
    return end - start;
  }
  
  clear() {
    this.marks.clear();
  }
}