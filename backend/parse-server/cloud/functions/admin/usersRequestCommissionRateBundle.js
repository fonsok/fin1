'use strict';

const {
  USER_COMMISSION_OVERRIDE_FIELDS,
  COMMISSION_OVERRIDE_ROLES,
} = require('../../utils/configHelper/index.js');
const {
  validateCommissionRateBundle,
  normalizeCommissionRateBundle,
  formatCommissionRateBundle,
} = require('../../utils/configHelper/commissionRateBundle');

const REQUEST_TYPE = 'user_commission_rate_bundle_change';

function bundlesAreEqual(a, b) {
  const left = normalizeCommissionRateBundle(a);
  const right = normalizeCommissionRateBundle(b);
  if (!left && !right) {
    return true;
  }
  if (!left || !right) {
    return false;
  }
  return (
    left.investorCommissionRateTotal === right.investorCommissionRateTotal
    && left.traderCommissionRate === right.traderCommissionRate
    && left.appCommissionRate === right.appCommissionRate
  );
}

async function handleRequestUserCommissionRateBundleChange(request) {
  const {
    userId,
    investorCommissionRateTotal,
    traderCommissionRate,
    appCommissionRate,
    effectiveFrom,
    clearOverride,
    reason,
  } = request.params || {};

  if (!userId || !reason) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'userId and reason are required');
  }

  const targetUser = await new Parse.Query(Parse.User).get(userId, { useMasterKey: true });
  const userRole = String(targetUser.get('role') || '').toLowerCase();
  if (!COMMISSION_OVERRIDE_ROLES.has(userRole)) {
    throw new Parse.Error(
      Parse.Error.INVALID_VALUE,
      'Individuelle Erfolgsprovision gilt nur für Nutzer mit Rolle trader oder investor',
    );
  }

  const overrideRole = userRole;
  const oldValue = normalizeCommissionRateBundle(
    targetUser.get(USER_COMMISSION_OVERRIDE_FIELDS.bundle),
  );

  const shouldClear = Boolean(clearOverride);
  let newValue = null;
  if (!shouldClear) {
    if (
      investorCommissionRateTotal === undefined
      || traderCommissionRate === undefined
      || appCommissionRate === undefined
    ) {
      throw new Parse.Error(
        Parse.Error.INVALID_VALUE,
        'investorCommissionRateTotal, traderCommissionRate, appCommissionRate, and reason are required',
      );
    }
    const validation = validateCommissionRateBundle({
      investorCommissionRateTotal,
      traderCommissionRate,
      appCommissionRate,
    });
    if (!validation.valid) {
      throw new Parse.Error(Parse.Error.INVALID_VALUE, validation.error);
    }
    newValue = validation.bundle;
  }

  if (shouldClear && !oldValue) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Nutzer hat keinen individuellen Provisions-Override');
  }
  if (!shouldClear && bundlesAreEqual(oldValue, newValue)) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Keine Änderung gegenüber dem aktuellen Override');
  }

  let parsedEffectiveFrom = null;
  if (!shouldClear && effectiveFrom) {
    parsedEffectiveFrom = new Date(effectiveFrom);
    if (Number.isNaN(parsedEffectiveFrom.getTime())) {
      throw new Parse.Error(Parse.Error.INVALID_VALUE, 'effectiveFrom ist kein gültiges Datum');
    }
  }

  const FourEyesRequest = Parse.Object.extend('FourEyesRequest');
  const fourEyesReq = new FourEyesRequest();
  fourEyesReq.set('requestType', REQUEST_TYPE);
  fourEyesReq.set('requesterId', request.user.id);
  fourEyesReq.set('requesterRole', request.user.get('role'));
  fourEyesReq.set('requesterEmail', request.user.get('email'));
  fourEyesReq.set('status', 'pending');
  fourEyesReq.set('expiresAt', new Date(Date.now() + 7 * 24 * 60 * 60 * 1000));
  fourEyesReq.set('metadata', {
    targetUserId: userId,
    targetUserEmail: targetUser.get('email') || null,
    overrideRole,
    oldValue,
    newValue,
    clearOverride: shouldClear,
    effectiveFrom: parsedEffectiveFrom ? parsedEffectiveFrom.toISOString() : null,
    reason,
    isCritical: true,
  });
  await fourEyesReq.save(null, { useMasterKey: true });

  const changeSummary = shouldClear
    ? 'Override entfernen (globale Provision)'
    : formatCommissionRateBundle(newValue);

  return {
    success: true,
    requiresApproval: true,
    fourEyesRequestId: fourEyesReq.id,
    message: `Individuelle Erfolgsprovision (${overrideRole}) ${changeSummary} — 4-Augen-Freigabe erforderlich. Request ID: ${fourEyesReq.id}`,
  };
}

module.exports = {
  REQUEST_TYPE,
  handleRequestUserCommissionRateBundleChange,
};
