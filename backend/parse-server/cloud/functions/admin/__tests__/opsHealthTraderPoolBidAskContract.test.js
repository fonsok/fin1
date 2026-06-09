'use strict';

const {
  detectTraderPoolBidAskViolations,
  legMetricsFromTrade,
} = require('../opsHealthTraderPoolBidAskContract');

function mockTrade(fields) {
  return {
    id: fields.id || 'trade-1',
    get(key) {
      return fields[key];
    },
  };
}

describe('opsHealthTraderPoolBidAskContract', () => {
  test('flags pool_copied_trader_cost_basis when quantities differ but Einstand matches', () => {
    const trader = mockTrade({
      id: 'trader-1',
      legEconomicsSnapshot: {
        tradeId: 'trader-1',
        buyQuantity: 1000,
        bidPricePerShare: 3.74,
        costBasisPerShare: 3.7617,
        buyFeesTotal: 21.7,
      },
    });
    const mirror = mockTrade({
      id: 'pool-1',
      legEconomicsSnapshot: {
        tradeId: 'pool-1',
        buyQuantity: 797,
        bidPricePerShare: 3.74,
        costBasisPerShare: 3.7617,
        buyFeesTotal: 21.7,
      },
    });

    const violations = detectTraderPoolBidAskViolations({
      pairExecutionId: 'pair-1',
      traderTrade: trader,
      mirrorTrade: mirror,
      participations: [],
    });

    expect(violations.some((v) => v.type === 'pool_copied_trader_cost_basis')).toBe(true);
    expect(violations.some((v) => v.type === 'pool_copied_trader_buy_fees')).toBe(true);
  });

  test('healthy when pool has distinct Einstand and fees for fewer pieces', () => {
    const trader = mockTrade({
      id: 'trader-1',
      legEconomicsSnapshot: {
        tradeId: 'trader-1',
        buyQuantity: 1000,
        bidPricePerShare: 3.74,
        costBasisPerShare: 3.7617,
        buyFeesTotal: 21.7,
      },
    });
    const mirror = mockTrade({
      id: 'pool-1',
      legEconomicsSnapshot: {
        tradeId: 'pool-1',
        buyQuantity: 797,
        bidPricePerShare: 3.74,
        costBasisPerShare: 3.7625,
        buyFeesTotal: 17.9,
      },
    });

    const violations = detectTraderPoolBidAskViolations({
      pairExecutionId: 'pair-gs4glef',
      traderTrade: trader,
      mirrorTrade: mirror,
      participations: [],
    });

    expect(violations).toHaveLength(0);
  });

  test('does not flag equal min fees when Einstand differs (smoke-trade edge case)', () => {
    const trader = mockTrade({
      id: 'trader-smoke',
      legEconomicsSnapshot: {
        tradeId: 'trader-smoke',
        buyQuantity: 1,
        bidPricePerShare: 10,
        costBasisPerShare: 18,
        buyFeesTotal: 8,
      },
    });
    const mirror = mockTrade({
      id: 'pool-smoke',
      legEconomicsSnapshot: {
        tradeId: 'pool-smoke',
        buyQuantity: 99,
        bidPricePerShare: 10,
        costBasisPerShare: 10.08,
        buyFeesTotal: 8,
      },
    });

    const violations = detectTraderPoolBidAskViolations({
      pairExecutionId: 'pair-smoke',
      traderTrade: trader,
      mirrorTrade: mirror,
      participations: [],
    });

    expect(violations.some((v) => v.type === 'pool_copied_trader_buy_fees')).toBe(false);
  });

  test('flags bid_price_mismatch when only Bid diverges', () => {
    const trader = mockTrade({
      id: 'trader-1',
      legEconomicsSnapshot: {
        tradeId: 'trader-1',
        buyQuantity: 100,
        bidPricePerShare: 3.74,
        costBasisPerShare: 3.76,
        buyFeesTotal: 5,
      },
    });
    const mirror = mockTrade({
      id: 'pool-1',
      legEconomicsSnapshot: {
        tradeId: 'pool-1',
        buyQuantity: 80,
        bidPricePerShare: 3.80,
        costBasisPerShare: 3.81,
        buyFeesTotal: 4,
      },
    });

    const violations = detectTraderPoolBidAskViolations({
      pairExecutionId: 'pair-bid',
      traderTrade: trader,
      mirrorTrade: mirror,
      participations: [],
    });

    expect(violations.some((v) => v.type === 'bid_price_mismatch')).toBe(true);
  });

  test('legMetricsFromTrade prefers legEconomicsSnapshot', () => {
    const metrics = legMetricsFromTrade(mockTrade({
      quantity: 1,
      legEconomicsSnapshot: {
        tradeId: 't1',
        buyQuantity: 99,
        bidPricePerShare: 2.5,
        costBasisPerShare: 2.6,
        buyFeesTotal: 3,
      },
    }));
    expect(metrics.buyQuantity).toBe(99);
    expect(metrics.source).toBe('legEconomicsSnapshot');
  });
});
