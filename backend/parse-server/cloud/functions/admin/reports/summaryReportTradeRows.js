'use strict';

/**
 * Distinct investor stableIds per trade from pool participation (SSOT).
 * Trade.investorIds is optional legacy; settlement never sets it today — without this,
 * Summary Report showed "0 Investoren" despite PoolTradeParticipation rows.
 */
async function loadDistinctInvestorIdsByTradeId(tradeRows) {
  const tradeIds = tradeRows.map((t) => t.id).filter(Boolean);
  if (tradeIds.length === 0) {
    return new Map();
  }

  const pq = new Parse.Query('PoolTradeParticipation');
  pq.containedIn('tradeId', tradeIds);
  pq.limit(5000);
  const parts = await pq.find({ useMasterKey: true });

  const investmentIdsByTrade = new Map();
  const allInvestmentIds = new Set();
  for (const p of parts) {
    const tid = p.get('tradeId');
    const iid = p.get('investmentId');
    if (!tid || !iid) continue;
    if (!investmentIdsByTrade.has(tid)) investmentIdsByTrade.set(tid, new Set());
    investmentIdsByTrade.get(tid).add(iid);
    allInvestmentIds.add(iid);
  }

  if (allInvestmentIds.size === 0) {
    return new Map();
  }

  const iq = new Parse.Query('Investment');
  iq.containedIn('objectId', Array.from(allInvestmentIds));
  iq.limit(5000);
  const investments = await iq.find({ useMasterKey: true });
  const investorByInvestmentId = new Map();
  for (const inv of investments) {
    const invId = inv.get('investorId');
    if (invId) investorByInvestmentId.set(inv.id, invId);
  }

  const out = new Map();
  for (const [tid, iidSet] of investmentIdsByTrade) {
    const uniq = new Set();
    for (const iid of iidSet) {
      const invStable = investorByInvestmentId.get(iid);
      if (invStable) uniq.add(invStable);
    }
    out.set(tid, Array.from(uniq));
  }
  return out;
}

function mapTradeRow(trade, investorIdsFromPool = null) {
  const buyOrder = trade.get('buyOrder') || {};
  const sellOrder = trade.get('sellOrder') || {};
  const sellOrders = trade.get('sellOrders') || [];

  const buyAmount = buyOrder.totalAmount || 0;
  let sellAmount = sellOrder.totalAmount || 0;
  if (sellOrders.length > 0) {
    sellAmount = sellOrders.reduce((s, o) => s + (o.totalAmount || 0), 0);
  }
  const profit =
    trade.get('calculatedProfit') || trade.get('grossProfit') || sellAmount - buyAmount;

  const fromObject = trade.get('investorIds');
  const investorIds =
    Array.isArray(investorIdsFromPool) && investorIdsFromPool.length > 0
      ? investorIdsFromPool
      : (Array.isArray(fromObject) ? fromObject : []);

  return {
    tradeId: trade.id,
    tradeNumber: trade.get('tradeNumber') || 0,
    symbol: trade.get('symbol') || buyOrder.symbol || 'N/A',
    traderId: trade.get('traderId') || '',
    buyAmount,
    sellAmount,
    profit,
    status: trade.get('status') || 'unknown',
    investorIds,
    createdAt: trade.get('createdAt'),
  };
}

module.exports = {
  loadDistinctInvestorIdsByTradeId,
  mapTradeRow,
};
