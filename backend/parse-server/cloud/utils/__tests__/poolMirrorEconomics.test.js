'use strict';

const { computeInvestorBuyLeg } = require('../accountingHelper/legs');
const { round2, round4 } = require('../accountingHelper/shared');
const { investorPoolPiecesAtCostBasis } = require('../poolMirrorInvestorDelta');
const { resolvePoolMirrorTradeCapitalAllocated } = require('../poolMirrorEconomics');
const {
  floorPoolPiecesFromCapital,
  aggregatePoolInvestmentEconomics,
  poolSellQuantityForTraderSellFraction,
  resolvePoolSoldQtyCumulative,
  poolSellDeltaForTraderSellRange,
  computeInvestorPartialSellDelta,
} = require('../poolMirrorEconomics');
const {
  aggregatePoolSellFromTraderSellOrders,
  enumeratePoolSellEventsFromTraderOrders,
} = require('../poolMirrorInvestorDelta');

describe('poolMirrorEconomics', () => {
  test('computeInvestorPartialSellDelta am Einstand: 598 Stück, 50 % → 299', () => {
    const delta = computeInvestorPartialSellDelta({
      investmentCapital: 1000,
      costBasisPerShare: 1.6713,
      tradeBuyPrice: 1.66,
      tradeSellPrice: 2,
      sellFraction: 0.5,
      commissionRate: 0.11,
      feeConfig: {},
    });
    expect(delta).not.toBeNull();
    expect(delta.poolPieces).toBe(598);
    expect(delta.sellLeg.quantity).toBe(299);
  });

  test('computeInvestorPartialSellDelta fallback ohne Einstand nutzt Bid-Solver', () => {
    const delta = computeInvestorPartialSellDelta({
      investmentCapital: 1000,
      tradeBuyPrice: 2.02,
      tradeSellPrice: 3,
      sellFraction: 0.2,
      commissionRate: 0.11,
      feeConfig: {},
    });
    expect(delta).not.toBeNull();
    expect(delta.sellLeg.quantity).toBeGreaterThan(0);
    expect(delta.buyLeg.amount).toBeGreaterThan(0);
  });
});

describe('aggregatePoolInvestmentEconomics (shared with Summary)', () => {
  test('floor @ Einstand (nicht Bid-Solver) wenn costBasisPerShare gesetzt', () => {
    const buyLeg = computeInvestorBuyLeg(1000, 2.02, {});
    const costBasis = round4(
      round2(buyLeg.amount + (buyLeg.fees?.totalFees || 0)) / buyLeg.quantity,
    );
    const atCost = investorPoolPiecesAtCostBasis(1000, costBasis);
    const econ = aggregatePoolInvestmentEconomics(
      [{ investmentStatus: 'active', investmentCapital: 1000, investorId: 'u1' }],
      2.02,
      { buyQuantity: 1000, soldQuantity: 200, costBasisPerShare: costBasis },
      { feeConfig: {}, sellPrice: 3, costBasisPerShare: costBasis },
    );
    expect(econ.impliedBuyQuantityFromPool).toBe(atCost.poolPieces);
    expect(econ.poolCapitalAllocated).toBe(
      resolvePoolMirrorTradeCapitalAllocated(atCost.poolPieces, costBasis),
    );
    expect(econ.poolResidualTotal).toBe(
      Math.max(0, Math.round((1000 - econ.poolCapitalAllocated) * 100) / 100),
    );
    expect(econ.poolSoldQuantityDerived).toBe(98);
  });

  test('poolSellQuantityForTraderSellFraction', () => {
    expect(poolSellQuantityForTraderSellFraction(495, 1)).toBe(495);
    expect(poolSellQuantityForTraderSellFraction(495, 200 / 1000)).toBe(99);
  });

  test('resolvePoolSoldQtyCumulative flushes last piece when trader sold = buy', () => {
    expect(resolvePoolSoldQtyCumulative(598, 1000, 1000)).toBe(598);
    expect(resolvePoolSoldQtyCumulative(598, 999.999999, 1000)).toBe(598);
    expect(resolvePoolSoldQtyCumulative(598, 500, 1000)).toBe(299);
  });

  test('aggregatePoolSellFromTraderSellOrders sums to full pool on trader exit', () => {
    const agg = aggregatePoolSellFromTraderSellOrders({
      investorPieceRows: [{ pieces: 598 }],
      traderSellOrders: [
        { quantity: 333, price: 2, totalAmount: 666 },
        { quantity: 333, price: 2, totalAmount: 666 },
        { quantity: 334, price: 2, totalAmount: 668 },
      ],
      traderBuyQuantity: 1000,
      feeConfig: {},
    });
    expect(agg.poolSoldQuantityDerived).toBe(598);
    expect(poolSellDeltaForTraderSellRange(598, 0, 1000, 1000)).toBe(598);
    expect(agg.poolSellFeesTotal).toBeGreaterThan(0);
    expect(agg.poolNetSellAmount).toBeLessThan(agg.poolSellAmountDerived);
  });

  test('enumeratePoolSellEventsFromTraderOrders: per-order pool fees and net', () => {
    const events = enumeratePoolSellEventsFromTraderOrders({
      investorPieceRows: [{ pieces: 797 }],
      traderSellOrders: [{ quantity: 200, price: 3.74, totalAmount: 748 }],
      traderBuyQuantity: 1000,
      feeConfig: {},
    });
    expect(events).toHaveLength(1);
    expect(events[0].poolSellQuantity).toBe(159);
    expect(events[0].poolSellAmount).toBe(594.66);
    expect(events[0].poolSellFeesTotal).toBeGreaterThan(0);
    expect(events[0].poolNetSellAmount).toBe(
      Math.round((events[0].poolSellAmount - events[0].poolSellFeesTotal) * 100) / 100,
    );
  });

  test('aggregatePoolSellFromTraderSellOrders: Gebühren pro Pool-Order, nicht Trader-Summe', () => {
    const agg = aggregatePoolSellFromTraderSellOrders({
      investorPieceRows: [{ pieces: 797 }],
      traderSellOrders: [{ quantity: 200, price: 3.74, totalAmount: 748 }],
      traderBuyQuantity: 1000,
      feeConfig: {},
    });
    expect(agg.poolSoldQuantityDerived).toBe(159);
    expect(agg.poolSellAmountDerived).toBe(594.66);
    expect(agg.poolSellFeesTotal).toBeLessThan(21.7);
    expect(agg.poolNetSellAmount).toBe(
      Math.round((agg.poolSellAmountDerived - agg.poolSellFeesTotal) * 100) / 100,
    );
  });
});
