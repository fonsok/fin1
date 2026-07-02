'use strict';

const {
  USER_APP_SERVICE_CHARGE_OVERRIDE_FIELDS,
  normalizeAppServiceChargeRate,
} = require('../../utils/configHelper/index.js');

const REQUEST_TYPE = 'user_app_service_charge_change';

function ratesAreEqual(a, b) {
  const left = normalizeAppServiceChargeRate(a);
  const right = normalizeAppServiceChargeRate(b);
  if (left === null && right === null) {
    return true;
  }
  if (left === null || right === null) {
    return false;
  }
  return left === right;
}

function formatRatePct(rate) {
  return `${(Number(rate) * 100).toFixed(2).replace(/\.?0+$/, '')} %`;
}

async function handleRequestUserAppServiceChargeChange(request) {
  const {
    userId,
    appServiceChargeRate,
    effectiveFrom,
    clearOverride,
    reason,
  } = request.params || {};

  if (!userId || !reason) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'userId and reason are required');
  }

  const targetUser = await new Parse.Query(Parse.User).get(userId, { useMasterKey: true });
  const userRole = String(targetUser.get('role') || '').toLowerCase();
  if (userRole !== 'investor') {
    throw new Parse.Error(
      Parse.Error.INVALID_VALUE,
      'Individuelle App Service Charge gilt nur für Nutzer mit Rolle investor',
    );
  }

  const oldValue = normalizeAppServiceChargeRate(
    targetUser.get(USER_APP_SERVICE_CHARGE_OVERRIDE_FIELDS.rate),
  );

  const shouldClear = Boolean(clearOverride);
  let newValue = null;
  if (!shouldClear) {
    if (appServiceChargeRate === undefined || appServiceChargeRate === null) {
      throw new Parse.Error(
        Parse.Error.INVALID_VALUE,
        'appServiceChargeRate and reason are required',
      );
    }
    newValue = normalizeAppServiceChargeRate(appServiceChargeRate);
    if (newValue === null) {
      throw new Parse.Error(
        Parse.Error.INVALID_VALUE,
        'App Service Charge muss zwischen 0 % und 10 % liegen',
      );
    }
  }

  if (shouldClear && oldValue === null) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Nutzer hat keinen individuellen Service-Charge-Override');
  }
  if (!shouldClear && ratesAreEqual(oldValue, newValue)) {
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
    oldValue,
    newValue,
    clearOverride: shouldClear,
    effectiveFrom: parsedEffectiveFrom ? parsedEffectiveFrom.toISOString() : null,
    reason,
    isCritical: true,
  });
  await fourEyesReq.save(null, { useMasterKey: true });

  const changeSummary = shouldClear
    ? 'Override entfernen (globale Service Charge)'
    : formatRatePct(newValue);

  return {
    success: true,
    requiresApproval: true,
    fourEyesRequestId: fourEyesReq.id,
    message: `Individuelle App Service Charge (${changeSummary}) — 4-Augen-Freigabe erforderlich. Request ID: ${fourEyesReq.id}`,
  };
}

module.exports = {
  REQUEST_TYPE,
  handleRequestUserAppServiceChargeChange,
};
