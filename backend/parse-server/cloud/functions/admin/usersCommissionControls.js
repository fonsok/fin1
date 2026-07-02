'use strict';

const {
  getCommissionRateBundle,
  resolveCommissionRateBundle,
  USER_COMMISSION_OVERRIDE_FIELDS,
  readUserCommissionRateOverride,
} = require('../../utils/configHelper/index.js');
const { normalizeCommissionRateBundle } = require('../../utils/configHelper/commissionRateBundle');
const { isScheduledOverride } = require('../../utils/configHelper/overrideEffectiveFrom');

function formatCommissionControlDate(value) {
  if (!value) {
    return null;
  }
  const date = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(date.getTime())) {
    return null;
  }
  return date.toISOString();
}

async function loadUserCommissionControls(user, formatDate = (v) => v) {
  const role = String(user.get('role') || '').toLowerCase();
  const globalBundle = await getCommissionRateBundle();
  const globalRates = {
    investorCommissionRateTotal: globalBundle.totalRate,
    traderCommissionRate: globalBundle.traderRate,
    appCommissionRate: globalBundle.appRate,
  };

  const effectiveFromRaw = user.get(USER_COMMISSION_OVERRIDE_FIELDS.effectiveFrom);
  const storedOverride = normalizeCommissionRateBundle(
    user.get(USER_COMMISSION_OVERRIDE_FIELDS.bundle),
  );
  const overrideRole = user.get(USER_COMMISSION_OVERRIDE_FIELDS.role) || null;
  const applicableOverrideRole = role === 'trader' || role === 'investor' ? role : null;

  const effectiveOverrideEntry = applicableOverrideRole
    ? readUserCommissionRateOverride(user, applicableOverrideRole, new Date())
    : null;
  const userOverride = effectiveOverrideEntry?.bundle ?? null;
  const pendingOverride = storedOverride !== null
    && userOverride === null
    && isScheduledOverride(effectiveFromRaw)
    ? storedOverride
    : null;

  let effectiveRates = null;
  if (applicableOverrideRole) {
    const resolved = await resolveCommissionRateBundle({
      traderId: applicableOverrideRole === 'trader' ? user.id : undefined,
      investorId: applicableOverrideRole === 'investor' ? user.id : undefined,
    });
    effectiveRates = {
      investorCommissionRateTotal: resolved.totalRate,
      traderCommissionRate: resolved.traderRate,
      appCommissionRate: resolved.appRate,
      source: resolved.source,
    };
  }

  return {
    globalRates,
    storedOverride,
    userOverride,
    pendingOverride,
    overrideRole,
    effectiveFrom: formatDate(formatCommissionControlDate(effectiveFromRaw)),
    applicableOverrideRole,
    effectiveRates,
  };
}

module.exports = {
  loadUserCommissionControls,
};
