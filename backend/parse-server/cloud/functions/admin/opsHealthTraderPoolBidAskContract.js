'use strict';

const QTY_EPS = 0.02;
const PRICE_EPS = 0.0002;
const MONEY_EPS = 0.02;

function legMetricsFromTrade(trade) {
  const snap = trade.get ? trade.get('legEconomicsSnapshot') : trade.legEconomicsSnapshot;
  if (snap?.tradeId) {
    return {
      buyQuantity: Number(snap.buyQuantity || 0),
      bidPricePerShare: Number(snap.bidPricePerShare || snap.buyPrice || 0),
      costBasisPerShare: Number(snap.costBasisPerShare || 0),
      buyFeesTotal: Number(snap.buyFeesTotal || 0),
      source: 'legEconomicsSnapshot',
    };
  }
  const buyOrder = trade.get ? (trade.get('buyOrder') || {}) : (trade.buyOrder || {});
  return {
    buyQuantity: Number(
      (trade.get ? trade.get('quantity') : trade.quantity)
      || buyOrder.quantity
      || 0,
    ),
    bidPricePerShare: Number(
      buyOrder.price
      || (trade.get ? trade.get('buyPrice') : trade.buyPrice)
      || 0,
    ),
    costBasisPerShare: 0,
    buyFeesTotal: 0,
    source: 'trade_fields',
  };
}

function poolPiecesFromParticipations(participations) {
  if (!Array.isArray(participations)) return 0;
  return participations.reduce((sum, p) => {
    const snap = p.get ? p.get('buySnapshot') : p.buySnapshot;
    return sum + Number(snap?.poolPieces || 0);
  }, 0);
}

function poolMetricsFromMirrorLeg(mirrorTrade, participations) {
  const snapMetrics = legMetricsFromTrade(mirrorTrade);
  const piecesFromParts = poolPiecesFromParticipations(participations);
  const buyQuantity = snapMetrics.buyQuantity > 0 ? snapMetrics.buyQuantity : piecesFromParts;
  return {
    ...snapMetrics,
    buyQuantity,
    poolPiecesFromParticipations: piecesFromParts,
  };
}

/**
 * ADR-016 contract: Trader↔Pool only shares Bid/Ask; pool computes own pieces, fees, Einstand.
 */
function detectTraderPoolBidAskViolations({
  pairExecutionId,
  traderTrade,
  mirrorTrade,
  participations = [],
}) {
  const violations = [];
  const trader = legMetricsFromTrade(traderTrade);
  const pool = poolMetricsFromMirrorLeg(mirrorTrade, participations);
  const traderQty = trader.buyQuantity;
  const poolQty = pool.buyQuantity;

  if (!(traderQty > 0) || !(poolQty > 0)) return violations;

  const qtyDiffers = Math.abs(traderQty - poolQty) > QTY_EPS;
  const base = {
    pairExecutionId: pairExecutionId || null,
    traderTradeId: traderTrade.id || traderTrade.objectId,
    mirrorTradeId: mirrorTrade.id || mirrorTrade.objectId,
    traderQuantity: traderQty,
    poolQuantity: poolQty,
  };

  if (qtyDiffers && trader.costBasisPerShare > 0 && pool.costBasisPerShare > 0) {
    if (Math.abs(trader.costBasisPerShare - pool.costBasisPerShare) < PRICE_EPS) {
      violations.push({
        ...base,
        type: 'pool_copied_trader_cost_basis',
        traderCostBasisPerShare: trader.costBasisPerShare,
        poolCostBasisPerShare: pool.costBasisPerShare,
      });
    }
  }

  const basisCopied = qtyDiffers
    && trader.costBasisPerShare > 0
    && pool.costBasisPerShare > 0
    && Math.abs(trader.costBasisPerShare - pool.costBasisPerShare) < PRICE_EPS;

  if (basisCopied && trader.buyFeesTotal > 0 && pool.buyFeesTotal > 0) {
    if (Math.abs(trader.buyFeesTotal - pool.buyFeesTotal) < MONEY_EPS) {
      violations.push({
        ...base,
        type: 'pool_copied_trader_buy_fees',
        traderBuyFeesTotal: trader.buyFeesTotal,
        poolBuyFeesTotal: pool.buyFeesTotal,
      });
    }
  }

  const traderBid = trader.bidPricePerShare;
  const poolBid = pool.bidPricePerShare;
  if (traderBid > 0 && poolBid > 0 && Math.abs(traderBid - poolBid) > PRICE_EPS) {
    violations.push({
      ...base,
      type: 'bid_price_mismatch',
      traderBidPricePerShare: traderBid,
      poolBidPricePerShare: poolBid,
    });
  }

  return violations;
}

async function handleGetTraderPoolBidAskContractStatus(request) {
  const limit = Math.min(200, Math.max(1, Number(request.params?.limit || 100)));

  const mirrorQuery = new Parse.Query('Trade');
  mirrorQuery.equalTo('buyLegType', 'MIRROR_POOL');
  mirrorQuery.exists('pairExecutionId');
  mirrorQuery.descending('updatedAt');
  mirrorQuery.limit(limit);
  const mirrorTrades = await mirrorQuery.find({ useMasterKey: true });

  if (!mirrorTrades.length) {
    return {
      overall: 'healthy',
      checkedPairs: 0,
      violationCount: 0,
      violations: [],
      message: 'No paired mirror_pool trades to check',
      checkedAt: new Date().toISOString(),
    };
  }

  const pairIds = [...new Set(mirrorTrades.map((t) => String(t.get('pairExecutionId') || '').trim()).filter(Boolean))];
  const traderQuery = new Parse.Query('Trade');
  traderQuery.containedIn('pairExecutionId', pairIds);
  traderQuery.notEqualTo('buyLegType', 'MIRROR_POOL');
  traderQuery.limit(Math.max(pairIds.length * 2, limit));
  const traderTrades = await traderQuery.find({ useMasterKey: true });

  const traderByPair = new Map();
  for (const t of traderTrades) {
    const pairId = String(t.get('pairExecutionId') || '').trim();
    if (pairId && !traderByPair.has(pairId)) traderByPair.set(pairId, t);
  }

  const mirrorIds = mirrorTrades.map((t) => t.id);
  const partQuery = new Parse.Query('PoolTradeParticipation');
  partQuery.containedIn('tradeId', mirrorIds);
  partQuery.limit(5000);
  const participations = await partQuery.find({ useMasterKey: true });
  const partsByMirror = new Map();
  for (const p of participations) {
    const tid = p.get('tradeId');
    if (!partsByMirror.has(tid)) partsByMirror.set(tid, []);
    partsByMirror.get(tid).push(p);
  }

  const violations = [];
  for (const mirrorTrade of mirrorTrades) {
    const pairId = String(mirrorTrade.get('pairExecutionId') || '').trim();
    const traderTrade = traderByPair.get(pairId);
    if (!traderTrade) continue;
    violations.push(
      ...detectTraderPoolBidAskViolations({
        pairExecutionId: pairId,
        traderTrade,
        mirrorTrade,
        participations: partsByMirror.get(mirrorTrade.id) || [],
      }),
    );
  }

  return {
    overall: violations.length === 0 ? 'healthy' : 'degraded',
    checkedPairs: mirrorTrades.length,
    violationCount: violations.length,
    violations: violations.slice(0, 50),
    message: violations.length === 0
      ? 'Trader↔Pool Bid/Ask-only contract OK'
      : `${violations.length} Trader↔Pool Bid/Ask contract violation(s)`,
    checkedAt: new Date().toISOString(),
  };
}

module.exports = {
  QTY_EPS,
  PRICE_EPS,
  MONEY_EPS,
  legMetricsFromTrade,
  poolMetricsFromMirrorLeg,
  detectTraderPoolBidAskViolations,
  handleGetTraderPoolBidAskContractStatus,
};
