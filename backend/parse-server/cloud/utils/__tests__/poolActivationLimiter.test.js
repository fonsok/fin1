'use strict';

const {
  withPoolActivationConcurrencyLimit,
  getPoolActivationLimiterStats,
} = require('../poolActivationLimiter');

describe('poolActivationLimiter', () => {
  const originalEnv = process.env.POOL_MIRROR_MAX_CONCURRENT_ACTIVATIONS;

  afterEach(() => {
    if (originalEnv === undefined) {
      delete process.env.POOL_MIRROR_MAX_CONCURRENT_ACTIVATIONS;
    } else {
      process.env.POOL_MIRROR_MAX_CONCURRENT_ACTIVATIONS = originalEnv;
    }
  });

  it('runs fn and tracks active count', async () => {
    process.env.POOL_MIRROR_MAX_CONCURRENT_ACTIVATIONS = '2';
    const result = await withPoolActivationConcurrencyLimit(async () => 42);
    expect(result).toBe(42);
    const stats = await getPoolActivationLimiterStats();
    expect(stats.active).toBe(0);
    expect(stats.maxConcurrent).toBe(2);
  });

  it('queues when max concurrent is reached', async () => {
    process.env.POOL_MIRROR_MAX_CONCURRENT_ACTIVATIONS = '1';
    let releaseFirst;
    const firstStarted = new Promise((resolve) => {
      releaseFirst = resolve;
    });

    const first = withPoolActivationConcurrencyLimit(async () => {
      await firstStarted;
      return 'first';
    });

    const second = withPoolActivationConcurrencyLimit(async () => 'second');

    await new Promise((r) => setTimeout(r, 20));
    expect((await getPoolActivationLimiterStats()).queued).toBeGreaterThanOrEqual(1);

    releaseFirst();
    const [a, b] = await Promise.all([first, second]);
    expect(a).toBe('first');
    expect(b).toBe('second');
    expect((await getPoolActivationLimiterStats()).queued).toBe(0);
  });
});
