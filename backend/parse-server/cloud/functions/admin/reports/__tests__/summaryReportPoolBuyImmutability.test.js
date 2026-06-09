'use strict';

const { computeInvestorBuyLeg } = require('../../../../utils/accountingHelper/legs');
const {
  tradeBuySideMetrics,
  resolvePoolMirrorBuyMetricsFromBid,
} = require('../../../../utils/accountingHelper/legPriceMetrics');
const { tradeEconomicsSnapshot } = require('../../../../utils/poolMirrorEconomics/tradeLegEconomics');

describe('pool mirror buy-side immutability (Summary Report)', () => {
  const participations = [
    { investorId: 'e1', investmentStatus: 'active', investmentCapital: 1000 },
  ];
  const traderRef = {
    tradeId: 'trader-1',
    buyQuantity: 1000,
    buyPrice: 1.66,
    bidPricePerShare: 1.66,
    buyAmount: 1660,
    totalBuyCost: 1671.3,
    buyFeesTotal: 11.3,
    costBasisPerShare: 1.6713,
    soldQuantity: 500,
    sellVolumeProgress: 0.5,
  };

  test('corrupted mirror quantity/buyOrder does not change pool buy bid/einstand', () => {
    const buyLeg = computeInvestorBuyLeg(1000, 1.66, {});
    const tradeBuyM = tradeBuySideMetrics({
      quantity: 1000,
      grossAmount: 1660,
      feeConfig: {},
    });

    const mirrorTrade = {
      id: 'pool-1',
      get(key) {
        const data = {
          tradeNumber: 2,
          symbol: 'SG4GTIH',
          status: 'partial',
          quantity: 199,
          soldQuantity: 99,
          buyOrder: { quantity: 199, totalAmount: 992.01, price: 4.99 },
          sellOrders: [{ quantity: 99, totalAmount: 198, price: 2 }],
          traderId: 'trader',
          createdAt: new Date('2026-06-06'),
        };
        return data[key];
      },
    };

    const snap = tradeEconomicsSnapshot(mirrorTrade, participations, {
      traderReference: traderRef,
      applyPoolMirror: true,
      feeConfig: {},
    });

    expect(snap.bidPricePerShare).toBe(traderRef.bidPricePerShare);
    const poolBuyM = resolvePoolMirrorBuyMetricsFromBid({
      poolPieces: snap.buyQuantity,
      bidPricePerShare: traderRef.bidPricePerShare,
      feeConfig: {},
    });
    expect(snap.costBasisPerShare).toBe(poolBuyM.costBasisPerShare);
    expect(snap.costBasisPerShare).not.toBe(traderRef.costBasisPerShare);
    expect(snap.buyFeesTotal).toBe(poolBuyM.buyFeesTotal);
    expect(snap.buyFeesTotal).not.toBe(traderRef.buyFeesTotal);
    expect(snap.buyQuantity).toBeGreaterThan(590);
    expect(snap.poolCapitalAllocated).toBeGreaterThan(990);
    expect(snap.impliedBuyQuantityFromPool).toBe(snap.buyQuantity);
    expect(snap.bidPricePerShare).not.toBe(4.99);
    expect(snap.buyQuantity).not.toBe(199);
  });
});
