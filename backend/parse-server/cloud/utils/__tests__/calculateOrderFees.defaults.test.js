'use strict';

const { calculateOrderFees } = require('../helpers');
const { DEFAULT_CONFIG } = require('../configHelper/defaultConfig');

describe('calculateOrderFees — SSOT defaults', () => {
  const D = DEFAULT_CONFIG.financial;

  test('uses DEFAULT_CONFIG.financial when no config provided (non-foreign)', () => {
    const fees = calculateOrderFees(0, false);
    expect(fees.orderFee).toBe(D.orderFeeMin);
    expect(fees.exchangeFee).toBe(D.exchangeFeeMin);
    expect(fees.foreignCosts).toBe(0);
    expect(fees.totalFees).toBe(
      Math.round((D.orderFeeMin + D.exchangeFeeMin) * 100) / 100,
    );
  });

  test('uses DEFAULT_CONFIG.financial.foreignCosts when isForeign=true and no config', () => {
    const fees = calculateOrderFees(0, true);
    expect(fees.foreignCosts).toBe(D.foreignCosts);
  });

  test('respects explicit config override (per call)', () => {
    const fees = calculateOrderFees(0, true, {
      orderFeeMin: 7,
      exchangeFeeMin: 0.25,
      foreignCosts: 9.99,
    });
    expect(fees.orderFee).toBe(7);
    expect(fees.exchangeFee).toBe(0.25);
    expect(fees.foreignCosts).toBe(9.99);
  });

  test('explicit 0 in config is honored (not replaced by default)', () => {
    const fees = calculateOrderFees(1000, true, {
      orderFeeRate: 0,
      orderFeeMin: 0,
      orderFeeMax: 0,
      exchangeFeeRate: 0,
      exchangeFeeMin: 0,
      exchangeFeeMax: 0,
      foreignCosts: 0,
    });
    expect(fees.orderFee).toBe(0);
    expect(fees.exchangeFee).toBe(0);
    expect(fees.foreignCosts).toBe(0);
    expect(fees.totalFees).toBe(0);
  });

  test('caps order and exchange fees at percentage-based amount', () => {
    const fees = calculateOrderFees(10000, false);
    expect(fees.orderFee).toBe(
      Math.min(D.orderFeeMax, Math.max(D.orderFeeMin, 10000 * D.orderFeeRate)),
    );
    expect(fees.exchangeFee).toBe(
      Math.min(D.exchangeFeeMax, Math.max(D.exchangeFeeMin, 10000 * D.exchangeFeeRate)),
    );
  });
});
