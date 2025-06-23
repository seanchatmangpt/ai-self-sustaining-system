/**
 * Mock Nitro internals for testing
 */

import { vi } from 'vitest';

export const runTask = vi.fn().mockResolvedValue({ success: true, data: 'mock result' });

export const defineTask = vi.fn((task) => task);

export const scheduledTask = vi.fn((cron, task) => task);