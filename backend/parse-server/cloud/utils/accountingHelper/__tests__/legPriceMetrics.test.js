'use strict';

const { computeInvestorBuyLeg } = require('../legs');
const {
  costBasisPerShareFromBuyLeg,
  tradeBuySideMetrics,
  tradeSellSideMetrics,
  resolveLegProfitFromMetrics,
  resolveLegReturnPercentage,
  tradeListEconomicsFromParseTrade,
  resolvePoolMirrorBuyMetricsFromBid,
} = require('../legPriceMetrics');

describe('legPriceMetrics', () => {
  test('costBasisPerShare = totalBuyCost / quantity (Bid 1,875 + Gebühren)', () => {
    const metrics = tradeBuySideMetrics({
      quantity: 500,
      grossAmount: 937.5,
      feeConfig: {},
    });
    expect(metrics).not.toBeNull();
    expect(metrics.bidPricePerShare).toBeCloseTo(1.875, 3);
    expect(metrics.totalBuyCost).toBe(945.5);
    expect(metrics.costBasisPerShare).toBeCloseTo(1.891, 3);
  });

  test('matches computeInvestorBuyLeg cost basis', () => {
    const buyLeg = computeInvestorBuyLeg(1000, 2.02, {});
    const fromLeg = costBasisPerShareFromBuyLeg(buyLeg);
    expect(fromLeg).toBeGreaterThan(0);
    const pieces = Math.floor(1000 / fromLeg);
    expect(pieces).toBe(buyLeg.quantity);
  });

  test('net sell price per share after fees', () => {
    const sellM = tradeSellSideMetrics({
      quantity: 98,
      grossAmount: 294,
      feeConfig: {},
    });
    expect(sellM.netSellAmount).toBeLessThanOrEqual(294);
    expect(sellM.netSellPricePerShare).toBeLessThan(sellM.askPricePerShare);
  });

  test('resolveLegProfitFromMetrics: open position P/L = −totalBuyCost', () => {
    const buyM = tradeBuySideMetrics({ quantity: 1000, grossAmount: 3740, feeConfig: {} });
    const profit = resolveLegProfitFromMetrics(
      { totalBuyCost: buyM.totalBuyCost, costBasisPerShare: buyM.costBasisPerShare, buyAmount: 3740 },
      0,
      0,
    );
    expect(profit).toBe(-3761.7);
  });

  test('resolvePoolMirrorBuyMetricsFromBid: pool order independent of trader 1000 Stück', () => {
    const trader = tradeBuySideMetrics({ quantity: 1000, grossAmount: 3740, feeConfig: {} });
    const pool = resolvePoolMirrorBuyMetricsFromBid({
      poolPieces: 797,
      bidPricePerShare: trader.bidPricePerShare,
      feeConfig: {},
    });
    expect(pool.bidPricePerShare).toBe(trader.bidPricePerShare);
    expect(pool.costBasisPerShare).not.toBe(trader.costBasisPerShare);
    expect(pool.buyFeesTotal).toBeLessThan(trader.buyFeesTotal);
    expect(pool.totalBuyCost).toBeLessThan(trader.totalBuyCost);
  });

  test('tradeListEconomicsFromParseTrade matches Einstand list economics', () => {
    const trade = {
      get(key) {
        return {
          quantity: 1000,
          soldQuantity: 0,
          buyOrder: { quantity: 1000, totalAmount: 3740, price: 3.74 },
          sellOrders: [],
        }[key];
      },
    };
    const econ = tradeListEconomicsFromParseTrade(trade, {});
    expect(econ.buyAmount).toBe(3761.7);
    expect(econ.profit).toBe(-3761.7);
    expect(resolveLegReturnPercentage(econ.buyAmount, econ.profit)).toBe(econ.returnPercentage);
  });
});
