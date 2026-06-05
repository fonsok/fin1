'use strict';

/**
 * Admin health: paired-buy pool integrity (TRADER leg must not carry pool participations).
 */
async function handleGetPairedBuyPoolIntegrityStatus() {
  const trades = await new Parse.Query('Trade')
    .containedIn('buyLegType', ['TRADER', 'MIRROR_POOL'])
    .descending('createdAt')
    .limit(500)
    .find({ useMasterKey: true });

  const violations = [];
  const tradeIds = trades.map((t) => t.id);
  if (tradeIds.length === 0) {
    return {
      overall: 'healthy',
      checkedTrades: 0,
      violations: [],
      message: 'No paired-buy trades to check',
    };
  }

  const participations = await new Parse.Query('PoolTradeParticipation')
    .containedIn('tradeId', tradeIds)
    .limit(5000)
    .find({ useMasterKey: true });

  const partsByTrade = new Map();
  for (const p of participations) {
    const tid = p.get('tradeId');
    if (!partsByTrade.has(tid)) partsByTrade.set(tid, []);
    partsByTrade.get(tid).push(p);
  }

  for (const trade of trades) {
    const leg = String(trade.get('buyLegType') || '').toUpperCase();
    const parts = partsByTrade.get(trade.id) || [];

    if (leg === 'TRADER' && parts.length > 0) {
      violations.push({
        type: 'trader_leg_has_pool_participations',
        tradeId: trade.id,
        tradeNumber: trade.get('tradeNumber') || null,
        pairExecutionId: trade.get('pairExecutionId') || null,
        participationCount: parts.length,
      });
    }

    if (leg === 'MIRROR_POOL' && parts.length > 0) {
      const investmentIds = parts.map((p) => p.get('investmentId')).filter(Boolean);
      const investments = investmentIds.length
        ? await new Parse.Query('Investment')
          .containedIn('objectId', investmentIds)
          .find({ useMasterKey: true })
        : [];
      const byInvestor = new Map();
      for (const inv of investments) {
        const investorId = inv.get('investorId');
        if (!investorId) continue;
        if (!byInvestor.has(investorId)) byInvestor.set(investorId, []);
        byInvestor.get(investorId).push(inv.id);
      }
      for (const [investorId, invIds] of byInvestor.entries()) {
        if (invIds.length > 1) {
          violations.push({
            type: 'mirror_leg_multiple_splits_per_investor',
            tradeId: trade.id,
            tradeNumber: trade.get('tradeNumber') || null,
            pairExecutionId: trade.get('pairExecutionId') || null,
            investorId,
            investmentIds: invIds,
          });
        }
      }
    }
  }

  return {
    overall: violations.length === 0 ? 'healthy' : 'degraded',
    checkedTrades: trades.length,
    violationCount: violations.length,
    violations: violations.slice(0, 50),
    message: violations.length === 0
      ? 'Paired-buy pool integrity OK'
      : `${violations.length} paired-buy pool integrity violation(s)`,
  };
}

module.exports = {
  handleGetPairedBuyPoolIntegrityStatus,
};
