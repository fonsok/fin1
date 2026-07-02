'use strict';

const {
  getAppServiceChargeRateForAccountType,
  resolveAppServiceChargeRate,
  USER_APP_SERVICE_CHARGE_OVERRIDE_FIELDS,
  normalizeAppServiceChargeRate,
  readUserAppServiceChargeOverride,
} = require('../../utils/configHelper/index.js');
const { isScheduledOverride } = require('../../utils/configHelper/overrideEffectiveFrom');

function formatControlDate(value) {
  if (!value) {
    return null;
  }
  const date = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(date.getTime())) {
    return null;
  }
  return date.toISOString();
}

async function loadUserAppServiceChargeControls(user, formatDate = (v) => v) {
  const role = String(user.get('role') || '').toLowerCase();
  const accountType = user.get('accountType') || 'individual';
  const globalRate = await getAppServiceChargeRateForAccountType(accountType);
  const effectiveFromRaw = user.get(USER_APP_SERVICE_CHARGE_OVERRIDE_FIELDS.effectiveFrom);
  const storedOverride = normalizeAppServiceChargeRate(
    user.get(USER_APP_SERVICE_CHARGE_OVERRIDE_FIELDS.rate),
  );
  const userOverride = readUserAppServiceChargeOverride(user, new Date());
  const pendingOverride = storedOverride !== null
    && userOverride === null
    && isScheduledOverride(effectiveFromRaw)
    ? storedOverride
    : null;
  const applicable = role === 'investor';

  let effectiveRate = null;
  let source = 'global';
  if (applicable) {
    const resolved = await resolveAppServiceChargeRate({
      investorId: user.id,
      accountType,
    });
    effectiveRate = resolved.rate;
    source = resolved.source;
  }

  return {
    globalRate,
    storedOverride,
    userOverride,
    pendingOverride,
    effectiveFrom: formatDate(formatControlDate(effectiveFromRaw)),
    applicable,
    accountType,
    effectiveRate,
    source,
  };
}

module.exports = {
  loadUserAppServiceChargeControls,
};
