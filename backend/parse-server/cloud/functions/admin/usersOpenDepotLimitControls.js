'use strict';

const {
  getMaxTraderOpenDepotPositions,
  resolveMaxOpenDepotPositions,
  USER_OPEN_DEPOT_LIMIT_OVERRIDE_FIELDS,
  readUserMaxOpenDepotPositionsOverride,
  normalizeMaxOpenDepotPositions,
} = require('../../utils/configHelper/index.js');
const { isScheduledOverride } = require('../../utils/configHelper/overrideEffectiveFrom');
const { countOpenTraderDepotPositions } = require('../../utils/configHelper/index.js');

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

async function loadUserOpenDepotLimitControls(user, formatDate = (v) => v) {
  const role = String(user.get('role') || '').toLowerCase();
  const globalLimit = await getMaxTraderOpenDepotPositions();
  const effectiveFromRaw = user.get(USER_OPEN_DEPOT_LIMIT_OVERRIDE_FIELDS.effectiveFrom);
  const storedOverride = normalizeMaxOpenDepotPositions(
    user.get(USER_OPEN_DEPOT_LIMIT_OVERRIDE_FIELDS.limit),
  );
  const userOverride = readUserMaxOpenDepotPositionsOverride(user, new Date());
  const pendingOverride = storedOverride !== null
    && userOverride === null
    && isScheduledOverride(effectiveFromRaw)
    ? storedOverride
    : null;
  const applicable = role === 'trader';

  let effectiveLimit = globalLimit;
  let source = 'global';
  let openDepotPositions = 0;

  if (applicable) {
    const resolved = await resolveMaxOpenDepotPositions({ traderId: user.id });
    effectiveLimit = resolved.limit;
    source = resolved.source;
    openDepotPositions = await countOpenTraderDepotPositions(user.id);
  }

  return {
    globalLimit,
    storedOverride,
    userOverride,
    pendingOverride,
    effectiveFrom: formatDate(formatControlDate(effectiveFromRaw)),
    applicable,
    effectiveLimit,
    source,
    openDepotPositions,
  };
}

module.exports = {
  loadUserOpenDepotLimitControls,
};
