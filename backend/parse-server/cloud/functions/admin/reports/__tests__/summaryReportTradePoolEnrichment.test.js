'use strict';

const { computeInvestorBuyLeg } = require('../../../../utils/accountingHelper/legs');
const { round2, round4 } = require('../../../../utils/accountingHelper/shared');
const {
  tradeBuySideMetrics,
  resolvePoolMirrorBuyMetricsFromBid,
} = require('../../../../utils/accountingHelper/legPriceMetrics');
const { investorPoolPiecesAtCostBasis } = require('../../../../utils/poolMirrorInvestorDelta');
const { resolvePoolMirrorTradeCapitalAllocated } = require('../../../../utils/poolMirrorEconomics');
const { tradeEconomicsSnapshot } = require('../../../../utils/poolMirrorEconomics/tradeLegEconomics');
const { aggregatePoolInvestmentEconomics } = require('../../../../utils/poolMirrorEconomics');

describe('aggregatePoolInvestmentEconomics (legs.js SSOT)', () => {
  const participations = [
    { investorId: 'inv1', investmentStatus: 'active', investmentCapital: 1000 },
  ];

  test('1000 € @ Einstand floor (nicht Bid-Solver)', () => {
    const buyLeg = computeInvestorBuyLeg(1000, 2.02, {});
    const costBasis = round4(
      round2(buyLeg.amount + (buyLeg.fees?.totalFees || 0)) / buyLeg.quantity,
    );
    const atCost = investorPoolPiecesAtCostBasis(1000, costBasis);
    const econ = aggregatePoolInvestmentEconomics(
      participations,
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
    expect(econ.poolSellAmountDerived).toBe(294);
  });
});

describe('tradeEconomicsSnapshot', () => {
  test('trader open position: P/L = −Kaufvolumen (Einstand), nicht −Bid', () => {
    const trade = {
      id: 't1',
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
    expect(snap.buyQuantity).toBe(1000);
    expect(snap.totalBuyCost).toBe(3761.7);
    expect(snap.profit).toBe(-3761.7);
    expect(snap.bidPricePerShare).toBe(3.74);
    expect(snap.costBasisPerShare).toBeCloseTo(3.7617, 3);
  });

  test('aggregates sell orders and quantity progress (trader leg)', () => {
    const trade = {
      id: 'mirror-1',
      get(key) {
        const data = {
          tradeNumber: 42,
          symbol: 'DAX',
          status: 'active',
          quantity: 1000,
          soldQuantity: 200,
          buyOrder: { quantity: 1000, totalAmount: 10000, symbol: 'DAX', price: 10 },
          sellOrders: [{ quantity: 200, totalAmount: 2500, price: 12.5 }],
          traderId: 'user:trader@test.de',
          createdAt: new Date('2026-01-01'),
        };
        return data[key];
      },
    };

    const snap = tradeEconomicsSnapshot(trade);
    expect(snap.tradeNumber).toBe(42);
    expect(snap.buyQuantity).toBe(1000);
    expect(snap.soldQuantity).toBe(200);
    expect(snap.sellVolumeProgress).toBe(0.2);
  });

  test('pool mirror: nur Bid vom Trader, Einstand/Gebühren aus Pool-Order', () => {
    const tradeBuyM = tradeBuySideMetrics({
      quantity: 1000,
      grossAmount: 2020,
      feeConfig: {},
    });
    const participations = [
      { investorId: 'e1', investmentStatus: 'active', investmentCapital: 1000 },
    ];
    const traderRef = { buyQuantity: 1000, soldQuantity: 200, buyPrice: 2.02 };
    const poolEcon = aggregatePoolInvestmentEconomics(participations, 2.02, traderRef, {
      feeConfig: {},
      sellPrice: 3,
    });
    const trade = {
      id: 'pool-1',
      get(key) {
        const data = {
          tradeNumber: 1,
          symbol: 'BN6G7QV',
          status: 'partial',
          quantity: 1000,
          soldQuantity: 200,
          buyOrder: { quantity: 1000, totalAmount: 2020, price: 2.02 },
          sellOrders: [{ quantity: 200, totalAmount: 600, price: 3 }],
          traderId: 'trader',
          createdAt: new Date('2026-01-01'),
        };
        return data[key];
      },
    };
    const snap = tradeEconomicsSnapshot(trade, participations, {
      traderReference: traderRef,
      applyPoolMirror: true,
      feeConfig: {},
    });
    expect(snap.buyQuantity).toBe(poolEcon.impliedBuyQuantityFromPool);
    expect(snap.poolCapitalAllocated).toBe(poolEcon.poolCapitalAllocated);
    expect(snap.poolResidualTotal).toBe(poolEcon.poolResidualTotal);
    const poolBuyM = resolvePoolMirrorBuyMetricsFromBid({
      poolPieces: snap.buyQuantity,
      bidPricePerShare: tradeBuyM.bidPricePerShare,
      feeConfig: {},
    });
    expect(snap.costBasisPerShare).toBe(poolBuyM.costBasisPerShare);
    expect(snap.bidPricePerShare).toBe(tradeBuyM.bidPricePerShare);
    expect(snap.totalBuyCost).toBe(poolBuyM.totalBuyCost);
    expect(snap.buyFeesTotal).toBe(poolBuyM.buyFeesTotal);
    expect(snap.soldQuantity).toBe(poolEcon.poolSoldQuantityDerived);
    expect(snap.sellAmount).toBe(poolEcon.poolSellAmountDerived);
    const displayBasis = Math.round(snap.costBasisPerShare * 100) / 100;
    expect(snap.sellFeesTotal).toBe(poolEcon.poolSellFeesTotal);
    expect(snap.netSellAmount).toBe(poolEcon.poolNetSellAmount);
    expect(snap.profit).toBe(
      Math.round((poolEcon.poolNetSellAmount - poolEcon.poolSoldQuantityDerived * displayBasis) * 100) / 100,
    );
  });

  test('pool mirror ohne Verkauf: P/L = −Pool-Einlage (Σ Stück × Einstand)', () => {
    const participations = [
      { investorId: 'e1', investmentStatus: 'active', investmentCapital: 1485 },
      { investorId: 'e2', investmentStatus: 'active', investmentCapital: 1515 },
    ];
    const traderRef = {
      buyQuantity: 1000,
      soldQuantity: 0,
      bidPricePerShare: 6.9,
      costBasisPerShare: 6.93769,
      buyFeesTotal: 37.69,
    };
    const trade = {
      id: 'pool-2',
      get(key) {
        return {
          tradeNumber: 2,
          symbol: 'UB4PQLG',
          status: 'active',
          quantity: 432,
          soldQuantity: 0,
          buyOrder: { quantity: 432, totalAmount: 2980.8, price: 6.9 },
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
    expect(snap.soldQuantity).toBe(0);
    expect(snap.impliedBuyQuantityFromPool).toBe(432);
    expect(snap.poolCapitalAllocated).toBe(2998.08);
    expect(snap.poolResidualTotal).toBe(1.92);
    expect(snap.profit).toBe(-2998.08);
  });
});
