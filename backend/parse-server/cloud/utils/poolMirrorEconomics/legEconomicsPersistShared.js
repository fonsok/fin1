'use strict';

const { resolveLegReturnPercentage } = require('../accountingHelper/legPriceMetrics');
const { totalSellQuantity } = require('../../triggers/tradeSellQuantityHelpers');

const LEG_ECONOMICS_SNAPSHOT_VERSION = 1;

function resolveLiveSoldQuantity(trade) {
  return Number(trade.get('soldQuantity') || 0) || totalSellQuantity(trade);
}

function toPersistedLegEconomics(snapshot) {
  if (!snapshot?.tradeId) return null;
  const totalBuyCost = Number(snapshot.totalBuyCost ?? snapshot.buyAmount ?? 0);
  const profit = Number(snapshot.profit ?? 0);
  return {
    snapshotVersion: LEG_ECONOMICS_SNAPSHOT_VERSION,
    snapshotAt: new Date().toISOString(),
    soldQuantityAtSnapshot: Number(snapshot.soldQuantity || 0),
    returnPercentage: resolveLegReturnPercentage(totalBuyCost, profit),
    tradeId: snapshot.tradeId,
    tradeNumber: snapshot.tradeNumber || 0,
    symbol: snapshot.symbol || 'N/A',
    description: snapshot.description || '',
    traderId: snapshot.traderId || '',
    wkn: snapshot.wkn ?? null,
    isin: snapshot.isin ?? null,
    wknOrIsin: snapshot.wknOrIsin ?? null,
    underlyingAsset: snapshot.underlyingAsset ?? null,
    issuer: snapshot.issuer ?? null,
    optionDirection: snapshot.optionDirection ?? null,
    strikePrice: snapshot.strikePrice ?? null,
    buyQuantity: Number(snapshot.buyQuantity || 0),
    soldQuantity: Number(snapshot.soldQuantity || 0),
    sellVolumeProgress: Number(snapshot.sellVolumeProgress || 0),
    buyPrice: Number(snapshot.buyPrice || 0),
    sellPrice: Number(snapshot.sellPrice || 0),
    buyAmount: Number(snapshot.buyAmount || 0),
    sellAmount: Number(snapshot.sellAmount || 0),
    profit: Number(snapshot.profit || 0),
    bidPricePerShare: snapshot.bidPricePerShare ?? null,
    buyFeesTotal: Number(snapshot.buyFeesTotal || 0),
    totalBuyCost,
    costBasisPerShare: Number(snapshot.costBasisPerShare || 0),
    askPricePerShare: snapshot.askPricePerShare ?? null,
    sellFeesTotal: Number(snapshot.sellFeesTotal || 0),
    netSellAmount: Number(snapshot.netSellAmount || 0),
    netSellPricePerShare: snapshot.netSellPricePerShare ?? null,
    poolCapitalAllocated: Number(snapshot.poolCapitalAllocated || 0),
    poolReservedCapitalTotal: Number(snapshot.poolReservedCapitalTotal || 0),
    poolResidualTotal: Number(snapshot.poolResidualTotal || 0),
    poolInvestorCount: Number(snapshot.poolInvestorCount || 0),
    impliedBuyQuantityFromPool: snapshot.impliedBuyQuantityFromPool ?? null,
    sellOrders: Array.isArray(snapshot.sellOrders)
      ? snapshot.sellOrders.map((o) => ({
        quantity: Number(o?.quantity || 0),
        totalAmount: Number(o?.totalAmount || 0),
        price: Number(o?.price || 0),
      }))
      : [],
  };
}

function isPersistedLegEconomicsCurrent(persisted, trade) {
  if (!persisted || !trade?.id) return false;
  if (Number(persisted.snapshotVersion || 0) !== LEG_ECONOMICS_SNAPSHOT_VERSION) return false;
  if (String(persisted.tradeId || '') !== String(trade.id)) return false;
  const liveSold = resolveLiveSoldQuantity(trade);
  if (Number(persisted.soldQuantityAtSnapshot || 0) !== liveSold) return false;
  return true;
}

function legEconomicsFromPersisted(persisted, trade) {
  if (!persisted) return null;
  return {
    ...persisted,
    status: trade.get('status') || persisted.status || 'unknown',
    completedAt: trade.get('completedAt') || null,
    createdAt: trade.get('createdAt') || null,
  };
}

module.exports = {
  LEG_ECONOMICS_SNAPSHOT_VERSION,
  resolveLiveSoldQuantity,
  toPersistedLegEconomics,
  isPersistedLegEconomicsCurrent,
  legEconomicsFromPersisted,
};
