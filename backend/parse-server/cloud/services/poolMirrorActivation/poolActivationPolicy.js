'use strict';

const POOL_ACTIVATION_SOURCES = Object.freeze({
  ORDER_MIRROR_LEG: 'order_mirror_leg',
  LEGACY_TRADE_AFTER_SAVE: 'legacy_trade_after_save',
});

function normalizeLegType(trade) {
  return String(trade.get('buyLegType') || '').trim().toUpperCase();
}

function hasOrderOrchestrationMarker(trade) {
  return Boolean(String(trade.get('buyOrderId') || '').trim())
    || Boolean(String(trade.get('pairExecutionId') || '').trim());
}

/**
 * SSOT: when pool mirror activation (RSV→PTR, participations) may run.
 *
 * Paired buy: ONLY on MIRROR_POOL leg via Order afterSave (order_mirror_leg).
 * Legacy iOS upsertTrade: ONLY via Trade afterSave when no order orchestration markers.
 */
function resolveLegTypeForActivation(trade, order) {
  let legType = normalizeLegType(trade);
  if (legType !== 'MIRROR_POOL' && order && isMirrorPoolOrderLeg(order)) {
    legType = 'MIRROR_POOL';
  }
  return legType;
}

function resolvePoolActivationDecision(trade, source, options = {}) {
  const { order = null } = options;
  const legType = resolveLegTypeForActivation(trade, order);
  const orchestrated = hasOrderOrchestrationMarker(trade);

  if (source === POOL_ACTIVATION_SOURCES.ORDER_MIRROR_LEG) {
    if (legType !== 'MIRROR_POOL') {
      return { shouldActivate: false, reason: 'order_path_requires_mirror_pool_leg' };
    }
    return { shouldActivate: true, reason: 'paired_buy_mirror_leg' };
  }

  if (source === POOL_ACTIVATION_SOURCES.LEGACY_TRADE_AFTER_SAVE) {
    if (orchestrated) {
      return { shouldActivate: false, reason: 'order_orchestrated_trade' };
    }
    if (legType === 'TRADER') {
      return { shouldActivate: false, reason: 'trader_leg_no_pool' };
    }
    return { shouldActivate: true, reason: 'legacy_client_upsert_trade' };
  }

  return { shouldActivate: false, reason: 'unknown_activation_source' };
}

function isMirrorPoolOrderLeg(order) {
  return String(order.get('legType') || '').trim().toUpperCase() === 'MIRROR_POOL';
}

/** Parse Trade row opened from paired-buy MIRROR_POOL buy leg (pool accounting, not trader depot). */
function isMirrorPoolTradeLeg(trade) {
  return normalizeLegType(trade) === 'MIRROR_POOL';
}

module.exports = {
  POOL_ACTIVATION_SOURCES,
  resolvePoolActivationDecision,
  resolveLegTypeForActivation,
  isMirrorPoolOrderLeg,
  isMirrorPoolTradeLeg,
  normalizeLegType,
  hasOrderOrchestrationMarker,
};
