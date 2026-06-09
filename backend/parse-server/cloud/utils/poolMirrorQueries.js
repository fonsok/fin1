'use strict';

const { round2 } = require('./accountingHelper/shared');

async function loadParticipationEconomicsRows(poolTradeId) {
  const parts = await new Parse.Query('PoolTradeParticipation')
    .equalTo('tradeId', poolTradeId)
    .limit(500)
    .find({ useMasterKey: true });
  if (!parts.length) return [];

  const investmentIds = [...new Set(parts.map((p) => p.get('investmentId')).filter(Boolean))];
  const invById = new Map();
  if (investmentIds.length) {
    const invRows = await new Parse.Query('Investment')
      .containedIn('objectId', investmentIds)
      .limit(investmentIds.length)
      .find({ useMasterKey: true });
    for (const inv of invRows) invById.set(inv.id, inv);
  }

  return parts.map((p) => {
    const inv = invById.get(p.get('investmentId') || '') || null;
    const buySnapshot = p.get('buySnapshot') || null;
    return {
      investorId: inv?.get('investorId') || p.get('investorId') || '',
      investmentStatus: String(inv?.get('status') || '').toLowerCase(),
      investmentCapital: round2(
        inv?.get('amount')
        || inv?.get('currentValue')
        || p.get('allocatedAmount')
        || p.get('investedAmount')
        || 0,
      ),
      buySnapshot,
      poolPieces: buySnapshot?.poolPieces > 0 ? Number(buySnapshot.poolPieces) : undefined,
    };
  });
}

async function computePoolPiecesForMirrorTrade(mirrorTrade, buyPrice, feeConfig = {}) {
  if (!mirrorTrade?.id || !(buyPrice > 0)) return 0;
  const rows = await loadParticipationEconomicsRows(mirrorTrade.id);
  // Lazy require breaks poolMirrorEconomics ↔ poolMirrorQueries circular dependency.
  const { aggregatePoolInvestmentEconomics } = require('./poolMirrorEconomics');
  const econ = aggregatePoolInvestmentEconomics(rows, buyPrice, null, { feeConfig });
  return Number(econ.impliedBuyQuantityFromPool || 0);
}

async function resolvePoolContextForTraderSell(traderTrade) {
  if (!traderTrade?.id) return null;

  let participations = await new Parse.Query('PoolTradeParticipation')
    .equalTo('tradeId', traderTrade.id)
    .find({ useMasterKey: true });
  if (participations.length) {
    return { poolTrade: traderTrade, traderTrade, participations };
  }

  const { getMirrorTradeForPairedTraderLeg } = require('./pairedTradeMirrorSync');
  const mirror = await getMirrorTradeForPairedTraderLeg(traderTrade);
  if (!mirror) return null;

  participations = await new Parse.Query('PoolTradeParticipation')
    .equalTo('tradeId', mirror.id)
    .find({ useMasterKey: true });
  if (!participations.length) return null;

  return { poolTrade: mirror, traderTrade, participations };
}

module.exports = {
  loadParticipationEconomicsRows,
  computePoolPiecesForMirrorTrade,
  resolvePoolContextForTraderSell,
};
