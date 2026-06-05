'use strict';

const { round2 } = require('./accountingHelper/shared');
const { loadConfig, DEFAULT_CONFIG } = require('./configHelper/index.js');

/** Investments waiting for the trader's next pool-mirror buy. */
const POOL_QUEUE_STATUSES = ['reserved'];

/** Proactive investor UI when reserved pool / cap ≥ this ratio (e.g. 96 % / 100 %). */
const POOL_NEARLY_FULL_RATIO = 0.95;

/**
 * Admin limit (EUR gross per pool-mirror buy leg). 0 = cap disabled.
 * @param {object} [config] optional preloaded config
 * @returns {Promise<number>}
 */
async function getMaxPoolMirrorBuyOrderAmount(config = null) {
  const cfg = config || (await loadConfig(true));
  const raw = cfg.limits?.maxPoolMirrorBuyOrderAmount
    ?? cfg.financial?.maxPoolMirrorBuyOrderAmount;
  const fallback = DEFAULT_CONFIG.limits.maxPoolMirrorBuyOrderAmount ?? 0;
  const n = Number(raw ?? fallback);
  if (!Number.isFinite(n) || n < 0) return 0;
  return round2(n);
}

/**
 * Sum of principal (EUR) reserved for the next mirror trade with this trader.
 * @param {string} traderId
 * @returns {Promise<number>}
 */
async function sumTraderPoolQueueCapital(traderId) {
  const tid = String(traderId || '').trim();
  if (!tid) return 0;

  const q = new Parse.Query('Investment');
  q.equalTo('traderId', tid);
  q.containedIn('status', POOL_QUEUE_STATUSES);
  q.limit(1000);
  const rows = await q.find({ useMasterKey: true });

  let total = 0;
  for (const inv of rows) {
    total += Number(inv.get('currentValue') || inv.get('amount') || 0);
  }
  return round2(total);
}

/**
 * Capacity snapshot for investor UI and validation.
 * @param {string} traderId
 * @param {object} [options]
 * @param {number} [options.additionalAmount] EUR to add (new investment batch)
 * @param {object} [options.config]
 * @returns {Promise<object>}
 */
async function assessPoolMirrorCapacity(traderId, options = {}) {
  const config = options.config || (await loadConfig(true));
  const maxAmount = await getMaxPoolMirrorBuyOrderAmount(config);
  const reservedTotal = await sumTraderPoolQueueCapital(traderId);
  const additional = round2(Number(options.additionalAmount || 0));
  const capEnabled = maxAmount > 0;

  const minInv = Number(config.limits?.minInvestment);
  const minInvestment = Number.isFinite(minInv) && minInv > 0
    ? minInv
    : DEFAULT_CONFIG.limits.minInvestment;

  const remaining = capEnabled ? round2(Math.max(0, maxAmount - reservedTotal)) : null;
  const maxInvestableAmountForNextTrade = remaining;
  const wouldExceed = capEnabled && additional > 0
    ? round2(reservedTotal + additional) > maxAmount + 0.005
    : false;
  const poolUtilizationRatio = capEnabled && maxAmount > 0
    ? Math.min(1, reservedTotal / maxAmount)
    : null;
  const isFull = capEnabled && remaining !== null
    && (remaining <= 0.005 || remaining < minInvestment);
  const isPoolNearlyFull = capEnabled && poolUtilizationRatio !== null
    && (poolUtilizationRatio >= POOL_NEARLY_FULL_RATIO || isFull);

  return {
    capEnabled,
    maxPoolMirrorBuyOrderAmount: maxAmount,
    reservedPoolCapital: reservedTotal,
    remainingCapacity: remaining,
    maxInvestableAmountForNextTrade,
    minInvestment,
    poolUtilizationRatio,
    poolNearlyFullThreshold: POOL_NEARLY_FULL_RATIO,
    isPoolNearlyFull,
    isFull,
    wouldExceed,
    additionalAmount: additional,
  };
}

/**
 * Validate a new reservation against the pool-mirror cap.
 * @param {string} traderId
 * @param {number} additionalAmount
 * @returns {Promise<{ valid: boolean, error?: string, capacity?: object }>}
 */
async function validatePoolMirrorReservationCapacity(traderId, additionalAmount) {
  const capacity = await assessPoolMirrorCapacity(traderId, { additionalAmount });
  if (!capacity.capEnabled) {
    return { valid: true, capacity };
  }

  if (capacity.isPoolNearlyFull) {
    return {
      valid: false,
      capacity,
      error: 'Aktuell ist ein Investment in den nächsten Trade nicht möglich.',
    };
  }

  if (!capacity.wouldExceed) {
    return { valid: true, capacity };
  }

  const remainingLabel = formatEuroDe(Math.max(0, capacity.maxInvestableAmountForNextTrade || 0));

  return {
    valid: false,
    capacity,
    error:
      `Für das nächste Trade mit diesem Trader ist derzeit nur ein Investment von maximal ${remainingLabel} möglich.`,
  };
}

/**
 * Clamp mirror-pool buy quantity for executePairedBuy (integer units).
 * @param {object} params
 * @param {number} params.mirrorPoolQuantity
 * @param {number} params.price
 * @param {string} params.traderId
 * @param {object} [params.config]
 * @returns {Promise<{ mirrorPoolQuantity: number, capped: boolean, maxGrossAllowed: number }>}
 */
async function capMirrorPoolQuantityForBuy({ mirrorPoolQuantity, price, traderId, config }) {
  const qty = Number(mirrorPoolQuantity || 0);
  const px = Number(price || 0);
  if (!Number.isInteger(qty) || qty <= 0 || !(px > 0)) {
    return { mirrorPoolQuantity: 0, capped: false, maxGrossAllowed: 0 };
  }

  const poolCapital = await sumTraderPoolQueueCapital(traderId);
  const maxCap = await getMaxPoolMirrorBuyOrderAmount(config);
  let maxGross = poolCapital;
  if (maxCap > 0) {
    maxGross = Math.min(maxGross, maxCap);
  }

  const maxQty = Math.floor(maxGross / px);
  const cappedQty = Math.min(qty, Math.max(0, maxQty));
  return {
    mirrorPoolQuantity: cappedQty,
    capped: cappedQty < qty,
    maxGrossAllowed: round2(maxGross),
  };
}

function formatEuroDe(n) {
  return new Intl.NumberFormat('de-DE', { style: 'currency', currency: 'EUR' }).format(n);
}

module.exports = {
  POOL_QUEUE_STATUSES,
  POOL_NEARLY_FULL_RATIO,
  getMaxPoolMirrorBuyOrderAmount,
  sumTraderPoolQueueCapital,
  assessPoolMirrorCapacity,
  validatePoolMirrorReservationCapacity,
  capMirrorPoolQuantityForBuy,
  formatEuroDe,
};
