'use strict';

const {
  DEFAULT_MAX_INVESTORS_PER_MIRROR_TRADE,
  readMaxInvestorsPerMirrorTrade,
} = require('../poolMirrorLimits');

describe('poolMirrorLimits', () => {
  const originalEnv = process.env.POOL_MIRROR_MAX_INVESTORS_PER_TRADE;

  afterEach(() => {
    if (originalEnv === undefined) {
      delete process.env.POOL_MIRROR_MAX_INVESTORS_PER_TRADE;
    } else {
      process.env.POOL_MIRROR_MAX_INVESTORS_PER_TRADE = originalEnv;
    }
  });

  test('default cap supports 1000+ investors per mirror trade', () => {
    expect(DEFAULT_MAX_INVESTORS_PER_MIRROR_TRADE).toBeGreaterThanOrEqual(2000);
  });

  test('readMaxInvestorsPerMirrorTrade uses env override', () => {
    process.env.POOL_MIRROR_MAX_INVESTORS_PER_TRADE = '3000';
    expect(readMaxInvestorsPerMirrorTrade()).toBe(3000);
  });

  test('readMaxInvestorsPerMirrorTrade falls back on invalid env', () => {
    process.env.POOL_MIRROR_MAX_INVESTORS_PER_TRADE = 'nope';
    expect(readMaxInvestorsPerMirrorTrade()).toBe(DEFAULT_MAX_INVESTORS_PER_MIRROR_TRADE);
  });
});
