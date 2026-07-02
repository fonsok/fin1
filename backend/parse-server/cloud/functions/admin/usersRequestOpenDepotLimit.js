'use strict';

const {
  USER_OPEN_DEPOT_LIMIT_OVERRIDE_FIELDS,
  normalizeMaxOpenDepotPositions,
} = require('../../utils/configHelper/index.js');

const REQUEST_TYPE = 'user_open_depot_limit_change';

function limitsAreEqual(a, b) {
  const left = normalizeMaxOpenDepotPositions(a);
  const right = normalizeMaxOpenDepotPositions(b);
  if (left === null && right === null) {
    return true;
  }
  if (left === null || right === null) {
    return false;
  }
  return left === right;
}

async function handleRequestUserOpenDepotLimitChange(request) {
  const {
    userId,
    maxOpenDepotPositions,
    effectiveFrom,
    clearOverride,
    reason,
  } = request.params || {};

  if (!userId || !reason) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'userId and reason are required');
  }

  const targetUser = await new Parse.Query(Parse.User).get(userId, { useMasterKey: true });
  const userRole = String(targetUser.get('role') || '').toLowerCase();
  if (userRole !== 'trader') {
    throw new Parse.Error(
      Parse.Error.INVALID_VALUE,
      'Individuelles Depot-Positions-Limit gilt nur für Nutzer mit Rolle trader',
    );
  }

  const oldValue = normalizeMaxOpenDepotPositions(
    targetUser.get(USER_OPEN_DEPOT_LIMIT_OVERRIDE_FIELDS.limit),
  );

  const shouldClear = Boolean(clearOverride);
  let newValue = null;
  if (!shouldClear) {
    if (maxOpenDepotPositions === undefined || maxOpenDepotPositions === null) {
      throw new Parse.Error(
        Parse.Error.INVALID_VALUE,
        'maxOpenDepotPositions and reason are required',
      );
    }
    newValue = normalizeMaxOpenDepotPositions(maxOpenDepotPositions);
    if (newValue === null) {
      throw new Parse.Error(
        Parse.Error.INVALID_VALUE,
        'Max. offene Depot-Positionen muss eine ganze Zahl zwischen 1 und 50 sein',
      );
    }
  }

  if (shouldClear && oldValue === null) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Nutzer hat keinen individuellen Depot-Limit-Override');
  }
  if (!shouldClear && limitsAreEqual(oldValue, newValue)) {
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
    ? 'Override entfernen (globales Limit)'
    : `${newValue} Position${newValue === 1 ? '' : 'en'}`;

  return {
    success: true,
    requiresApproval: true,
    fourEyesRequestId: fourEyesReq.id,
    message: `Individuelles Depot-Positions-Limit (${changeSummary}) — 4-Augen-Freigabe erforderlich. Request ID: ${fourEyesReq.id}`,
  };
}

module.exports = {
  REQUEST_TYPE,
  handleRequestUserOpenDepotLimitChange,
};
