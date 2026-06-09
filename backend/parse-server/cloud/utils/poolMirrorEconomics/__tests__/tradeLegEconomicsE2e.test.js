'use strict';

/**
 * Regression anchor: GS4GLEF Trader #001 (1000 Stück) + Pool #002 (797 Stück, 3000 € reserved), 1 Teilverkauf.
 * Bid/Ask-only-Link; Pool-Kauf/Verkauf unabhängig vom Trader-Leg.
 */
const { tradeEconomicsSnapshot } = require('../tradeLegEconomics');
const { tradeListEconomicsFromParseTrade } = require('../../accountingHelper/legPriceMetrics');
const {
  enumeratePoolSellEventsFromTraderOrders,
  aggregatePoolSellFromTraderSellOrders,
  resolveInvestorPieceRowsForPoolSell,
} = require('../../poolMirrorInvestorDelta');
const { buildPartialSellEvents } = require('../../../functions/admin/reports/summaryReportPartialSellEvents');

const FEE_CONFIG = {};

const GS4GLEF_E2E = {
  trader: {
    buyQuantity: 1000,
    bid: 3.74,
    buyGross: 3740,
    totalBuyCost: 3761.7,
    buyFeesTotal: 21.7,
    costBasisPerShare: 3.7617,
    openProfit: -3761.7,
    sellOrder: { quantity: 200, price: 3.74, gross: 748, sellFeesTotal: 8 },
    partialProfit: -12,
  },
  pool: {
    reserved: 3000,
    buyQuantity: 797,
    bid: 3.74,
    buyFeesTotal: 17.9,
    costBasisPerShare: 3.7625,
    poolCapitalAllocated: 2996.72,
    poolResidualTotal: 3.28,
    investorCount: 2,
    sellDeltaQuantity: 159,
    sellGross: 594.66,
    sellFeesTotal: 8,
    sellNet: 586.66,
    partialProfit: -11.18,
  },
};

function mockTraderParseTrade({ soldQuantity = 0, sellOrders = [] } = {}) {
  return {
    id: 'trader-gs4glef',
    get(key) {
      return {
        tradeNumber: 1,
        symbol: 'GS4GLEF',
        status: soldQuantity > 0 ? 'partial' : 'active',
        quantity: GS4GLEF_E2E.trader.buyQuantity,
        soldQuantity,
        buyOrder: {
          quantity: GS4GLEF_E2E.trader.buyQuantity,
          totalAmount: GS4GLEF_E2E.trader.buyGross,
          price: GS4GLEF_E2E.trader.bid,
        },
        sellOrders,
        traderId: 'trader',
        createdAt: new Date('2026-06-09'),
      }[key];
    },
  };
}

function mockPoolParseTrade() {
  return {
    id: 'pool-gs4glef',
    get(key) {
      return {
        tradeNumber: 2,
        symbol: 'GS4GLEF',
        status: 'active',
        quantity: 1000,
        soldQuantity: 0,
        buyOrder: {
          quantity: 1000,
          totalAmount: GS4GLEF_E2E.trader.buyGross,
          price: GS4GLEF_E2E.trader.bid,
        },
        sellOrders: [],
        traderId: 'trader',
        createdAt: new Date('2026-06-09'),
      }[key];
    },
  };
}

const PARTICIPATIONS_3000 = [
  {
    investorId: 'inv-a',
    investmentNumber: '001',
    investorName: 'Investor A',
    investmentStatus: 'active',
    investmentCapital: 1500,
  },
  {
    investorId: 'inv-b',
    investmentNumber: '002',
    investorName: 'Investor B',
    investmentStatus: 'active',
    investmentCapital: 1500,
  },
];

describe('GS4GLEF E2E regression (Trader 1000 / Pool 797 / 1 Sell)', () => {
  test('trader leg: open position Einstand-Basis', () => {
    const trade = mockTraderParseTrade();
    const snap = tradeEconomicsSnapshot(trade, null, { feeConfig: FEE_CONFIG });
    const list = tradeListEconomicsFromParseTrade(trade, FEE_CONFIG);

    expect(snap.buyQuantity).toBe(GS4GLEF_E2E.trader.buyQuantity);
    expect(snap.bidPricePerShare).toBe(GS4GLEF_E2E.trader.bid);
    expect(snap.totalBuyCost).toBe(GS4GLEF_E2E.trader.totalBuyCost);
    expect(snap.buyFeesTotal).toBe(GS4GLEF_E2E.trader.buyFeesTotal);
    expect(snap.costBasisPerShare).toBe(GS4GLEF_E2E.trader.costBasisPerShare);
    expect(snap.profit).toBe(GS4GLEF_E2E.trader.openProfit);
    expect(list.buyAmount).toBe(GS4GLEF_E2E.trader.totalBuyCost);
    expect(list.profit).toBe(GS4GLEF_E2E.trader.openProfit);
  });

  test('pool mirror: nur Bid gemeinsam; Stück/Gebühren/Einlage eigenständig', () => {
    const traderTrade = mockTraderParseTrade();
    const poolTrade = mockPoolParseTrade();
    const traderSnap = tradeEconomicsSnapshot(traderTrade, null, { feeConfig: FEE_CONFIG });
    const poolSnap = tradeEconomicsSnapshot(poolTrade, PARTICIPATIONS_3000, {
      traderReference: traderSnap,
      applyPoolMirror: true,
      feeConfig: FEE_CONFIG,
    });

    expect(poolSnap.bidPricePerShare).toBe(GS4GLEF_E2E.pool.bid);
    expect(poolSnap.buyQuantity).toBe(GS4GLEF_E2E.pool.buyQuantity);
    expect(poolSnap.impliedBuyQuantityFromPool).toBe(GS4GLEF_E2E.pool.buyQuantity);
    expect(poolSnap.buyFeesTotal).toBe(GS4GLEF_E2E.pool.buyFeesTotal);
    expect(poolSnap.buyFeesTotal).not.toBe(traderSnap.buyFeesTotal);
    expect(poolSnap.costBasisPerShare).toBe(GS4GLEF_E2E.pool.costBasisPerShare);
    expect(poolSnap.costBasisPerShare).not.toBe(traderSnap.costBasisPerShare);
    expect(poolSnap.poolReservedCapitalTotal).toBe(GS4GLEF_E2E.pool.reserved);
    expect(poolSnap.poolCapitalAllocated).toBe(GS4GLEF_E2E.pool.poolCapitalAllocated);
    expect(poolSnap.poolResidualTotal).toBe(GS4GLEF_E2E.pool.poolResidualTotal);
    expect(poolSnap.poolInvestorCount).toBe(GS4GLEF_E2E.pool.investorCount);
    expect(poolSnap.soldQuantity).toBe(0);
  });

  test('sell SSOT: enumerate, aggregate und partial-sell events stimmen überein', () => {
    const sellOrders = [GS4GLEF_E2E.trader.sellOrder];
    const pieceRows = [{ pieces: GS4GLEF_E2E.pool.buyQuantity }];
    const params = {
      investorPieceRows: pieceRows,
      traderSellOrders: sellOrders,
      traderBuyQuantity: GS4GLEF_E2E.trader.buyQuantity,
      feeConfig: FEE_CONFIG,
    };

    const events = enumeratePoolSellEventsFromTraderOrders(params);
    const agg = aggregatePoolSellFromTraderSellOrders(params);

    expect(events).toHaveLength(1);
    expect(events[0].traderSellQuantity).toBe(GS4GLEF_E2E.trader.sellOrder.quantity);
    expect(events[0].traderSellPrice).toBe(GS4GLEF_E2E.trader.sellOrder.price);
    expect(events[0].poolSellQuantity).toBe(GS4GLEF_E2E.pool.sellDeltaQuantity);
    expect(events[0].poolSellAmount).toBe(GS4GLEF_E2E.pool.sellGross);
    expect(events[0].poolSellFeesTotal).toBe(GS4GLEF_E2E.pool.sellFeesTotal);
    expect(events[0].poolNetSellAmount).toBe(GS4GLEF_E2E.pool.sellNet);

    expect(agg.poolSoldQuantityDerived).toBe(GS4GLEF_E2E.pool.sellDeltaQuantity);
    expect(agg.poolSellAmountDerived).toBe(GS4GLEF_E2E.pool.sellGross);
    expect(agg.poolSellFeesTotal).toBe(GS4GLEF_E2E.pool.sellFeesTotal);
    expect(agg.poolNetSellAmount).toBe(GS4GLEF_E2E.pool.sellNet);
  });

  test('nach 1 Trader-Sell: Domain-Snapshot und Partial-Sell-Panel konsistent', () => {
    const sellOrder = {
      quantity: GS4GLEF_E2E.trader.sellOrder.quantity,
      totalAmount: GS4GLEF_E2E.trader.sellOrder.gross,
      price: GS4GLEF_E2E.trader.sellOrder.price,
    };
    const traderTrade = mockTraderParseTrade({
      soldQuantity: sellOrder.quantity,
      sellOrders: [sellOrder],
    });
    const poolTrade = mockPoolParseTrade();

    const traderSnap = tradeEconomicsSnapshot(traderTrade, null, { feeConfig: FEE_CONFIG });
    const poolSnap = tradeEconomicsSnapshot(poolTrade, PARTICIPATIONS_3000, {
      traderReference: traderSnap,
      applyPoolMirror: true,
      feeConfig: FEE_CONFIG,
    });
    const panelEvents = buildPartialSellEvents({
      traderTrade,
      poolTrade,
      poolMirrorSnap: poolSnap,
      participations: PARTICIPATIONS_3000,
      feeConfig: FEE_CONFIG,
      commissionRate: 0.1,
    });

    expect(traderSnap.profit).toBe(GS4GLEF_E2E.trader.partialProfit);
    expect(traderSnap.sellFeesTotal).toBe(GS4GLEF_E2E.trader.sellOrder.sellFeesTotal);

    expect(poolSnap.soldQuantity).toBe(GS4GLEF_E2E.pool.sellDeltaQuantity);
    expect(poolSnap.sellAmount).toBe(GS4GLEF_E2E.pool.sellGross);
    expect(poolSnap.sellFeesTotal).toBe(GS4GLEF_E2E.pool.sellFeesTotal);
    expect(poolSnap.netSellAmount).toBe(GS4GLEF_E2E.pool.sellNet);
    expect(poolSnap.profit).toBe(GS4GLEF_E2E.pool.partialProfit);

    expect(panelEvents).toHaveLength(1);
    expect(panelEvents[0].poolSellQuantity).toBe(GS4GLEF_E2E.pool.sellDeltaQuantity);
    expect(panelEvents[0].poolSellAmount).toBe(GS4GLEF_E2E.pool.sellGross);
    expect(panelEvents[0].poolSellFeesTotal).toBe(GS4GLEF_E2E.pool.sellFeesTotal);
    expect(panelEvents[0].poolNetSellAmount).toBe(GS4GLEF_E2E.pool.sellNet);

    const pieceRows = resolveInvestorPieceRowsForPoolSell(PARTICIPATIONS_3000, poolSnap.buyQuantity);
    const ssot = enumeratePoolSellEventsFromTraderOrders({
      investorPieceRows: pieceRows,
      traderSellOrders: [sellOrder],
      traderBuyQuantity: GS4GLEF_E2E.trader.buyQuantity,
      feeConfig: FEE_CONFIG,
    });
    expect(panelEvents[0].poolSellQuantity).toBe(ssot[0].poolSellQuantity);
    expect(panelEvents[0].poolSellAmount).toBe(ssot[0].poolSellAmount);
  });
});
