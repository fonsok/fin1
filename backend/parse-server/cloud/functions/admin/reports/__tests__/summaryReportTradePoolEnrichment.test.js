'use strict';

const { computeInvestorBuyLeg } = require('../../../../utils/accountingHelper/legs');
const { tradeBuySideMetrics } = require('../../../../utils/accountingHelper/legPriceMetrics');
const { tradeEconomicsSnapshot } = require('../summaryReportTradePoolEnrichment');
const { aggregatePoolInvestmentEconomics } = require('../../../../utils/poolMirrorEconomics');

describe('aggregatePoolInvestmentEconomics (legs.js SSOT)', () => {
  const participations = [
    { investorId: 'inv1', investmentStatus: 'active', investmentCapital: 1000 },
  ];

  test('1000 € @ 2,02 € mit Gebühren (Backend-SSOT)', () => {
    const buyLeg = computeInvestorBuyLeg(1000, 2.02, {});
    const econ = aggregatePoolInvestmentEconomics(participations, 2.02, { buyQuantity: 1000, soldQuantity: 200 }, {
      feeConfig: {},
      sellPrice: 3,
    });
    expect(econ.impliedBuyQuantityFromPool).toBe(buyLeg.quantity);
    expect(econ.poolCapitalAllocated).toBe(buyLeg.amount);
    expect(econ.poolResidualTotal).toBe(buyLeg.residualAmount);
    expect(econ.poolSoldQuantityDerived).toBe(98);
    expect(econ.poolSellAmountDerived).toBe(294);
  });
});

describe('tradeEconomicsSnapshot', () => {
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

  test('pool mirror uses trade-leg Einstand when feeConfig passed', () => {
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
      costBasisPerShare: tradeBuyM.costBasisPerShare,
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
    expect(snap.buyAmount).toBe(poolEcon.poolCapitalAllocated);
    expect(snap.poolResidualTotal).toBe(poolEcon.poolResidualTotal);
    expect(snap.costBasisPerShare).toBe(tradeBuyM.costBasisPerShare);
    expect(snap.totalBuyCost).toBe(tradeBuyM.totalBuyCost);
    expect(snap.soldQuantity).toBe(poolEcon.poolSoldQuantityDerived);
    expect(snap.sellAmount).toBe(poolEcon.poolSellAmountDerived);
  });
});
