'use strict';

const { tradeEconomicsSnapshot } = require('../tradeLegEconomics');
const {
  tradeBuySideMetrics,
  resolvePoolMirrorBuyMetricsFromBid,
} = require('../../accountingHelper/legPriceMetrics');

describe('tradeLegEconomics (domain SSOT)', () => {
  test('trader leg: open P/L = −totalBuyCost', () => {
    const trade = {
      id: 't-trader',
      get(key) {
        return {
          tradeNumber: 1,
          symbol: 'GS4GLEF',
          status: 'active',
          quantity: 1000,
          soldQuantity: 0,
          buyOrder: { quantity: 1000, totalAmount: 3740, price: 3.74 },
          sellOrders: [],
          traderId: 'trader',
          createdAt: new Date('2026-06-09'),
        }[key];
      },
    };
    const snap = tradeEconomicsSnapshot(trade, null, { feeConfig: {} });
    expect(snap.totalBuyCost).toBe(3761.7);
    expect(snap.profit).toBe(-3761.7);
  });

  test('pool mirror: nur Bid vom Trader, eigene Gebühren/Einstand', () => {
    const traderBuyM = tradeBuySideMetrics({ quantity: 1000, grossAmount: 3740, feeConfig: {} });
    const participations = [
      { investorId: 'i1', investmentStatus: 'active', investmentCapital: 1500 },
      { investorId: 'i2', investmentStatus: 'active', investmentCapital: 1500 },
    ];
    const traderRef = {
      buyQuantity: 1000,
      soldQuantity: 0,
      bidPricePerShare: 3.74,
      buyPrice: 3.74,
      sellOrders: [],
    };
    const trade = {
      id: 't-pool',
      get(key) {
        return {
          tradeNumber: 2,
          symbol: 'GS4GLEF',
          status: 'active',
          quantity: 1000,
          soldQuantity: 0,
          buyOrder: { quantity: 1000, totalAmount: 3740, price: 3.74 },
          sellOrders: [],
          traderId: 'trader',
          createdAt: new Date('2026-06-09'),
        }[key];
      },
    };
    const snap = tradeEconomicsSnapshot(trade, participations, {
      traderReference: traderRef,
      applyPoolMirror: true,
      feeConfig: {},
    });
    expect(snap.buyQuantity).not.toBe(1000);
    expect(snap.bidPricePerShare).toBe(traderBuyM.bidPricePerShare);
    const poolBuyM = resolvePoolMirrorBuyMetricsFromBid({
      poolPieces: snap.buyQuantity,
      bidPricePerShare: snap.bidPricePerShare,
      feeConfig: {},
    });
    expect(snap.costBasisPerShare).toBe(poolBuyM.costBasisPerShare);
    expect(snap.buyFeesTotal).toBe(poolBuyM.buyFeesTotal);
    expect(snap.buyFeesTotal).not.toBe(traderBuyM.buyFeesTotal);
  });
});
