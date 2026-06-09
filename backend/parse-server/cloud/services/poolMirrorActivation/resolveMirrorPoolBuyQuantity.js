'use strict';

const { round2 } = require('../../utils/accountingHelper/shared');
const { computeTradeLevelPoolBuyTotalsFromBid } = require('../../utils/poolMirrorEconomics/proRataAllocation');
const {
  findTraderInvestmentsForActivation,
  selectOneSplitPerInvestorForTrade,
} = require('./investmentSelection');
const { readMaxInvestorsPerMirrorTrade } = require('./poolMirrorLimits');

/** Placeholder tradeId before mirror Trade exists (participation blocking on other trades only). */
const PENDING_MIRROR_TRADE_ID = '__pending_mirror_trade__';

/**
 * SSOT: Pool-Stück = max n mit n × Pool-Einstand(n) ≤ Σ Reserved.
 * Nur Bid vom TRADER-Leg; Pool-Gebühren/Einstand aus eigener Stückzahl (nicht Trader-Einstand).
 */
async function resolveMirrorPoolBuyQuantityFromReservedPool({
  traderId,
  traderBuyOrder,
  poolTradeId = PENDING_MIRROR_TRADE_ID,
  feeConfig = {},
}) {
  const tid = String(traderId || '').trim();
  if (!tid) {
    return { poolPieces: 0, poolCapitalAllocated: 0, costBasisPerShare: 0, investorCount: 0, reason: 'missing_trader_id' };
  }

  const buyQty = Number(traderBuyOrder?.quantity || 0);
  const buyGross = Number(
    traderBuyOrder?.totalAmount || traderBuyOrder?.grossAmount || 0,
  );
  if (!(buyQty > 0) || !(buyGross > 0)) {
    return { poolPieces: 0, poolCapitalAllocated: 0, costBasisPerShare: 0, investorCount: 0, reason: 'missing_trader_buy_order' };
  }

  const bidPrice = Number(
    traderBuyOrder?.price || (buyGross > 0 && buyQty > 0 ? buyGross / buyQty : 0),
  );
  if (!(bidPrice > 0)) {
    return { poolPieces: 0, poolCapitalAllocated: 0, costBasisPerShare: 0, investorCount: 0, reason: 'no_bid_price' };
  }

  const candidates = await findTraderInvestmentsForActivation(tid);
  let selected = await selectOneSplitPerInvestorForTrade(candidates, poolTradeId);
  const maxInvestors = readMaxInvestorsPerMirrorTrade();
  if (selected.length > maxInvestors) {
    selected = selected.slice(0, maxInvestors);
  }

  let poolReserved = 0;
  for (const inv of selected) {
    poolReserved += Number(inv.get('currentValue') || inv.get('amount') || 0);
  }
  const tradeTotals = computeTradeLevelPoolBuyTotalsFromBid(poolReserved, bidPrice, feeConfig);
  const poolPieces = Number(tradeTotals?.impliedBuyQuantityFromPool || 0);
  const poolCapital = round2(tradeTotals?.poolCapitalAllocated || 0);

  return {
    poolPieces,
    poolCapitalAllocated: poolCapital,
    costBasisPerShare: Number(tradeTotals?.costBasisPerShare || 0),
    investorCount: selected.length,
    reason: poolPieces > 0 ? 'ok' : 'no_eligible_pool_capital',
  };
}

async function loadTraderBuyOrderForPairedMirrorOrder(mirrorOrder) {
  const pairId = String(mirrorOrder?.get?.('pairExecutionId') || '').trim();
  if (!pairId) return null;

  const traderLeg = await new Parse.Query('Order')
    .equalTo('pairExecutionId', pairId)
    .equalTo('legType', 'TRADER')
    .equalTo('side', 'buy')
    .first({ useMasterKey: true });
  if (!traderLeg || String(traderLeg.get('status') || '') !== 'executed') {
    return null;
  }

  const tradeId = String(traderLeg.get('tradeId') || '').trim();
  if (!tradeId) return null;

  try {
    const trade = await new Parse.Query('Trade').get(tradeId, { useMasterKey: true });
    return trade.get('buyOrder') || null;
  } catch (_) {
    return null;
  }
}

/**
 * Before MIRROR_POOL leg → executed: rewrite order qty/amount from pool SSOT (not client brief-max).
 */
async function applyResolvedMirrorPoolBuyQuantityToOrder(mirrorOrder, { feeConfig = {} } = {}) {
  if (!mirrorOrder?.get) {
    return { ok: false, reason: 'missing_order' };
  }

  const traderBuyOrder = await loadTraderBuyOrderForPairedMirrorOrder(mirrorOrder);
  if (!traderBuyOrder) {
    return { ok: false, reason: 'trader_leg_not_ready' };
  }

  const resolved = await resolveMirrorPoolBuyQuantityFromReservedPool({
    traderId: mirrorOrder.get('traderId'),
    traderBuyOrder,
    poolTradeId: String(mirrorOrder.get('tradeId') || PENDING_MIRROR_TRADE_ID),
    feeConfig,
  });

  if (!(resolved.poolPieces > 0)) {
    return { ok: false, reason: resolved.reason || 'zero_pool_pieces', resolved };
  }

  const bidPrice = Number(mirrorOrder.get('price') || traderBuyOrder.price || 0);
  mirrorOrder.set('quantity', resolved.poolPieces);
  mirrorOrder.set('totalAmount', resolved.poolCapitalAllocated);
  mirrorOrder.set('grossAmount', resolved.poolCapitalAllocated);
  if (bidPrice > 0) {
    mirrorOrder.set('price', bidPrice);
  }

  return { ok: true, resolved };
}

module.exports = {
  PENDING_MIRROR_TRADE_ID,
  resolveMirrorPoolBuyQuantityFromReservedPool,
  loadTraderBuyOrderForPairedMirrorOrder,
  applyResolvedMirrorPoolBuyQuantityToOrder,
};
