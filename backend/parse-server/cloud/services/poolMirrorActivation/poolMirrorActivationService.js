'use strict';

const investmentEscrow = require('../../utils/accountingHelper/investmentEscrow');
const { audit } = require('../../utils/structuredLogger');
const {
  findTraderInvestmentsForActivation,
  selectOneSplitPerInvestorForTrade,
} = require('./investmentSelection');
const {
  POOL_ACTIVATION_SOURCES,
  resolvePoolActivationDecision,
} = require('./poolActivationPolicy');
const { withPoolActivationConcurrencyLimit } = require('../../utils/poolActivationLimiter');
const { readMaxInvestorsPerMirrorTrade } = require('./poolMirrorLimits');
const { loadConfig } = require('../../utils/configHelper/index.js');
const { buildPoolBuySnapshotsProRata } = require('./poolBuySnapshot');
const { syncMirrorTradeBuyFromParticipationSnapshots } = require('./syncMirrorTradeBuyFromSnapshots');

async function activatePoolMirrorForTrade(trade, { source, order = null }) {
  return withPoolActivationConcurrencyLimit(() => activatePoolMirrorForTradeInner(trade, { source, order }));
}

async function activatePoolMirrorForTradeInner(trade, { source, order = null }) {
  const tradeId = trade.id;
  if (!tradeId) {
    return { activated: false, reason: 'missing_trade_id', investmentCount: 0 };
  }

  const decision = resolvePoolActivationDecision(trade, source, { order });
  if (!decision.shouldActivate) {
    audit.info('pool.mirror.activation.skipped', {
      tradeId,
      tradeNumber: trade.get('tradeNumber') || null,
      source,
      reason: decision.reason,
      buyLegType: trade.get('buyLegType') || null,
      pairExecutionId: trade.get('pairExecutionId') || null,
    });
    return { activated: false, reason: decision.reason, investmentCount: 0 };
  }

  const existingParticipation = await new Parse.Query('PoolTradeParticipation')
    .equalTo('tradeId', tradeId)
    .first({ useMasterKey: true });
  if (existingParticipation) {
    return { activated: false, reason: 'participation_already_exists', investmentCount: 0 };
  }

  const buyOrder = trade.get('buyOrder') || {};
  const buyAmount = Number(buyOrder.totalAmount || trade.get('buyAmount') || 0);
  if (!Number.isFinite(buyAmount) || buyAmount <= 0) {
    return { activated: false, reason: 'invalid_buy_amount', investmentCount: 0 };
  }

  let costBasisBuyOrder = buyOrder;
  try {
    const { getTraderTradeForPairedMirrorLeg } = require('../../utils/pairedTradeMirrorSync');
    const traderTrade = await getTraderTradeForPairedMirrorLeg(trade);
    const traderBuyOrder = traderTrade?.get('buyOrder');
    if (traderBuyOrder && Number(traderBuyOrder.quantity || 0) > 0) {
      costBasisBuyOrder = traderBuyOrder;
    }
  } catch (_) {
    void _;
  }

  const traderId = String(trade.get('traderId') || '');
  if (!traderId) {
    return { activated: false, reason: 'missing_trader_id', investmentCount: 0 };
  }

  const candidates = await findTraderInvestmentsForActivation(traderId);
  if (!candidates.length) {
    audit.info('pool.mirror.activation.no_candidates', {
      tradeId,
      tradeNumber: trade.get('tradeNumber') || null,
      traderId,
      source,
    });
    return { activated: false, reason: 'no_candidate_investments', investmentCount: 0 };
  }

  let selected = await selectOneSplitPerInvestorForTrade(candidates, tradeId);
  if (!selected.length) {
    return { activated: false, reason: 'no_eligible_split_per_investor', investmentCount: 0 };
  }

  const maxInvestors = readMaxInvestorsPerMirrorTrade();
  if (selected.length > maxInvestors) {
    audit.warn('pool.mirror.activation.investor_cap_applied', {
      tradeId,
      tradeNumber: trade.get('tradeNumber') || null,
      selectedCount: selected.length,
      maxInvestors,
    });
    selected = selected.slice(0, maxInvestors);
  }

  let totalPool = 0;
  for (const inv of selected) {
    totalPool += Number(inv.get('currentValue') || inv.get('amount') || 0);
  }
  if (!Number.isFinite(totalPool) || totalPool <= 0) {
    return { activated: false, reason: 'empty_pool_capital', investmentCount: 0 };
  }

  const config = await loadConfig();
  const feeConfig = config.financial || {};

  const PoolParticipation = Parse.Object.extend('PoolTradeParticipation');
  const activatedIds = [];
  const investmentsToActivate = [];
  const participationsToCreate = [];
  const invValues = selected.map((inv) =>
    Number(inv.get('currentValue') || inv.get('amount') || 0),
  );
  const buySnapshots = buildPoolBuySnapshotsProRata(
    trade,
    invValues,
    costBasisBuyOrder,
    { feeConfig },
  );

  for (let i = 0; i < selected.length; i += 1) {
    const inv = selected[i];
    if (inv.get('status') === 'reserved') {
      inv.set('status', 'active');
      inv.set('reservationStatus', 'active');
      investmentsToActivate.push(inv);
    }

    const invValue = invValues[i];
    const ownershipPct = totalPool > 0 ? (invValue / totalPool) * 100 : 0;
    const allocatedAmount = buyAmount * (ownershipPct / 100);

    const participation = new PoolParticipation();
    participation.set('investmentId', inv.id);
    participation.set('tradeId', tradeId);
    participation.set('allocatedAmount', allocatedAmount);
    participation.set('ownershipPercentage', ownershipPct);
    participation.set('isSettled', false);
    const snapshot = buySnapshots[i];
    if (snapshot) participation.set('buySnapshot', snapshot);
    participationsToCreate.push(participation);
    activatedIds.push(inv.id);
  }

  if (investmentsToActivate.length > 0) {
    await Parse.Object.saveAll(investmentsToActivate, { useMasterKey: true });
  }
  if (participationsToCreate.length > 0) {
    await Parse.Object.saveAll(participationsToCreate, { useMasterKey: true });
  }

  const syncResult = await syncMirrorTradeBuyFromParticipationSnapshots(trade);
  if (syncResult.synced) {
    audit.warn('pool.mirror.activation.buy_quantity_realigned', {
      tradeId,
      tradeNumber: trade.get('tradeNumber') || null,
      poolPieces: syncResult.poolPieces,
      poolCapital: syncResult.poolCapital,
      message: 'Mirror trade buy qty drifted from pool SSOT — realigned after activation (should be rare)',
    });
  }

  const ESCROW_CONCURRENCY = 4;
  for (let i = 0; i < selected.length; i += ESCROW_CONCURRENCY) {
    const chunk = selected.slice(i, i + ESCROW_CONCURRENCY);
    await Promise.all(chunk.map(async (inv) => {
      try {
        await investmentEscrow.ensureReserveCapitalTradeSplitOnActivation(inv, trade);
      } catch (err) {
        audit.error('pool.mirror.activation.escrow_split_failed', {
          tradeId,
          investmentId: inv.id,
          source,
          error: err && err.message ? err.message : String(err),
        });
      }
    }));
  }

  audit.info('pool.mirror.activation.completed', {
    tradeId,
    tradeNumber: trade.get('tradeNumber') || null,
    source,
    investmentCount: activatedIds.length,
    investmentIds: activatedIds,
    pairExecutionId: trade.get('pairExecutionId') || null,
  });

  try {
    const { getTraderTradeForPairedMirrorLeg } = require('../../utils/pairedTradeMirrorSync');
    const { ensurePoolMirrorExecutionEigenbelegDocument } = require('../../utils/accountingHelper/poolMirrorExecutionEigenbelegBook');
    const traderLeg = await getTraderTradeForPairedMirrorLeg(trade);
    if (traderLeg) {
      await ensurePoolMirrorExecutionEigenbelegDocument({
        traderTrade: traderLeg,
        traderExecutionDoc: null,
        executionType: 'buy',
      });
    }
  } catch (err) {
    audit.warn('pool.mirror.activation.eigenbeleg_failed', {
      tradeId,
      tradeNumber: trade.get('tradeNumber') || null,
      source,
      error: err && err.message ? err.message : String(err),
    });
  }

  return {
    activated: true,
    reason: decision.reason,
    investmentCount: activatedIds.length,
    investmentIds: activatedIds,
  };
}

/** @deprecated Use activatePoolMirrorForTrade with explicit source. Legacy Trade afterSave entry. */
async function ensurePoolActivationForLegacyTrade(trade) {
  return activatePoolMirrorForTrade(trade, {
    source: POOL_ACTIVATION_SOURCES.LEGACY_TRADE_AFTER_SAVE,
  });
}

module.exports = {
  POOL_ACTIVATION_SOURCES,
  activatePoolMirrorForTrade,
  ensurePoolActivationForLegacyTrade,
  findTraderInvestmentsForActivation,
  selectOneSplitPerInvestorForTrade,
  resolvePoolActivationDecision,
};
