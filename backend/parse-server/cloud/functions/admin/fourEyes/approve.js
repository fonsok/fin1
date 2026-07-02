'use strict';

const { requirePermission } = require('../../../utils/permissions');
const {
  validateConfigValue,
  validateTransactionLimitOrdering,
  validateInvestmentAmountOrdering,
  validateInvestorCommissionRateTotalMatch,
  loadConfig,
} = require('../../../utils/configHelper/index.js');
const { applyConfigurationChange: persistConfigurationChange, applyCommissionRateBundle } = require('../../configuration/shared');
const {
  validateCommissionRateBundle,
  COMMISSION_RATE_BUNDLE_PARAMETER_NAME,
  normalizeCommissionRateBundle,
} = require('../../../utils/configHelper/commissionRateBundle');
const { USER_COMMISSION_OVERRIDE_FIELDS } = require('../../../utils/configHelper/index.js');
const { REQUEST_TYPE: USER_COMMISSION_REQUEST_TYPE } = require('../usersRequestCommissionRateBundle');
const { REQUEST_TYPE: USER_APP_SERVICE_CHARGE_REQUEST_TYPE } = require('../usersRequestAppServiceCharge');
const { REQUEST_TYPE: USER_OPEN_DEPOT_LIMIT_REQUEST_TYPE } = require('../usersRequestOpenDepotLimit');
const {
  USER_APP_SERVICE_CHARGE_OVERRIDE_FIELDS,
  normalizeAppServiceChargeRate,
  USER_OPEN_DEPOT_LIMIT_OVERRIDE_FIELDS,
  normalizeMaxOpenDepotPositions,
} = require('../../../utils/configHelper/index.js');
const {
  saveFourEyesAudit,
  saveConfigurationAuditLog,
  saveCorrectionAuditLog,
} = require('./audit');
const { sendApprovalNotification } = require('./notifications');
const { applyCorrectionRequest } = require('./corrections');

async function applyConfigurationChange({ req, requestId, request }) {
  const metadata = req.get('metadata') || {};
  const { parameterName, newValue, oldValue } = metadata;

  if (parameterName === COMMISSION_RATE_BUNDLE_PARAMETER_NAME) {
    const validation = validateCommissionRateBundle(newValue);
    if (!validation.valid) {
      throw new Parse.Error(Parse.Error.INVALID_VALUE, `Value no longer valid: ${validation.error}`);
    }

    await applyCommissionRateBundle(validation.bundle, request.user.id);

    await saveConfigurationAuditLog({
      action: 'configuration_change_approved',
      userId: request.user.id,
      userRole: request.user.get('role'),
      parameterName,
      oldValue,
      newValue: validation.bundle,
      metadata: {
        fourEyesRequestId: requestId,
        requesterId: req.get('requesterId'),
        reason: metadata.reason,
        isCritical: true,
        ip: request.ip,
      },
    });

    console.log(`✅ Commission rate bundle updated via 4-eyes approval by ${request.user.id}`);
    return true;
  }

  const validation = validateConfigValue(parameterName, newValue);
  if (!validation.valid) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, `Value no longer valid: ${validation.error}`);
  }

  const currentConfig = await loadConfig(true);
  const limitOrder = validateTransactionLimitOrdering(parameterName, newValue, currentConfig.limits);
  if (!limitOrder.valid) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, limitOrder.error);
  }
  const investmentOrder = validateInvestmentAmountOrdering(parameterName, newValue, currentConfig.limits);
  if (!investmentOrder.valid) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, investmentOrder.error);
  }
  const commissionOrder = validateInvestorCommissionRateTotalMatch(
    parameterName,
    newValue,
    currentConfig.financial,
  );
  if (!commissionOrder.valid) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, commissionOrder.error);
  }

  await persistConfigurationChange(parameterName, newValue, request.user.id);

  await saveConfigurationAuditLog({
    action: 'configuration_change_approved',
    userId: request.user.id,
    userRole: request.user.get('role'),
    parameterName,
    oldValue,
    newValue,
    metadata: {
      fourEyesRequestId: requestId,
      requesterId: req.get('requesterId'),
      reason: metadata.reason,
      isCritical: true,
      ip: request.ip,
    },
  });

  console.log(`✅ Configuration '${parameterName}' updated to ${newValue} via 4-eyes approval by ${request.user.id}`);
  return true;
}

async function applyUserWalletActionModeChange({ req, requestId, request }) {
  const metadata = req.get('metadata') || {};
  const { targetUserId, newMode, oldMode } = metadata;
  const allowedModes = new Set(['disabled', 'deposit_only', 'withdrawal_only', 'deposit_and_withdrawal']);
  if (!targetUserId || !allowedModes.has(newMode)) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Invalid user wallet action mode change request');
  }

  const targetUser = await new Parse.Query(Parse.User).get(targetUserId, { useMasterKey: true });
  targetUser.set('walletActionModeOverride', newMode);
  targetUser.set('walletActionModeOverrideUpdatedAt', new Date());
  targetUser.set('walletActionModeOverrideUpdatedBy', request.user.id);
  await targetUser.save(null, { useMasterKey: true });

  await saveConfigurationAuditLog({
    action: 'user_wallet_action_mode_change_approved',
    userId: request.user.id,
    userRole: request.user.get('role'),
    parameterName: 'walletActionModeOverride',
    oldValue: oldMode || null,
    newValue: newMode,
    metadata: {
      fourEyesRequestId: requestId,
      targetUserId,
      targetUserEmail: metadata.targetUserEmail || null,
      requesterId: req.get('requesterId'),
      reason: metadata.reason,
      isCritical: true,
      ip: request.ip,
    },
  });

  return true;
}

async function applyUserCommissionRateBundleChange({ req, requestId, request }) {
  const metadata = req.get('metadata') || {};
  const {
    targetUserId,
    overrideRole,
    newValue,
    oldValue,
    clearOverride,
    effectiveFrom,
  } = metadata;

  if (!targetUserId || !overrideRole) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Invalid user commission rate bundle change request');
  }

  const targetUser = await new Parse.Query(Parse.User).get(targetUserId, { useMasterKey: true });

  if (clearOverride) {
    targetUser.unset(USER_COMMISSION_OVERRIDE_FIELDS.bundle);
    targetUser.unset(USER_COMMISSION_OVERRIDE_FIELDS.role);
    targetUser.unset(USER_COMMISSION_OVERRIDE_FIELDS.effectiveFrom);
  } else {
    const validation = validateCommissionRateBundle(newValue);
    if (!validation.valid || !validation.bundle) {
      throw new Parse.Error(Parse.Error.INVALID_VALUE, `Value no longer valid: ${validation.error}`);
    }
    const effectiveAt = effectiveFrom ? new Date(effectiveFrom) : new Date();
    if (Number.isNaN(effectiveAt.getTime())) {
      throw new Parse.Error(Parse.Error.INVALID_VALUE, 'effectiveFrom is invalid');
    }
    targetUser.set(USER_COMMISSION_OVERRIDE_FIELDS.bundle, validation.bundle);
    targetUser.set(USER_COMMISSION_OVERRIDE_FIELDS.role, overrideRole);
    targetUser.set(USER_COMMISSION_OVERRIDE_FIELDS.effectiveFrom, effectiveAt);
  }

  targetUser.set('commissionRateOverrideUpdatedAt', new Date());
  targetUser.set('commissionRateOverrideUpdatedBy', request.user.id);
  await targetUser.save(null, { useMasterKey: true });

  await saveConfigurationAuditLog({
    action: 'user_commission_rate_bundle_change_approved',
    userId: request.user.id,
    userRole: request.user.get('role'),
    parameterName: 'commissionRateBundleOverride',
    oldValue: oldValue || null,
    newValue: clearOverride ? null : normalizeCommissionRateBundle(newValue),
    metadata: {
      fourEyesRequestId: requestId,
      targetUserId,
      targetUserEmail: metadata.targetUserEmail || null,
      overrideRole,
      clearOverride: Boolean(clearOverride),
      effectiveFrom: effectiveFrom || null,
      requesterId: req.get('requesterId'),
      reason: metadata.reason,
      isCritical: true,
      ip: request.ip,
    },
  });

  return true;
}

async function applyUserAppServiceChargeChange({ req, requestId, request }) {
  const metadata = req.get('metadata') || {};
  const {
    targetUserId,
    newValue,
    oldValue,
    clearOverride,
    effectiveFrom,
  } = metadata;

  if (!targetUserId) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Invalid user app service charge change request');
  }

  const targetUser = await new Parse.Query(Parse.User).get(targetUserId, { useMasterKey: true });

  if (clearOverride) {
    targetUser.unset(USER_APP_SERVICE_CHARGE_OVERRIDE_FIELDS.rate);
    targetUser.unset(USER_APP_SERVICE_CHARGE_OVERRIDE_FIELDS.effectiveFrom);
  } else {
    const normalized = normalizeAppServiceChargeRate(newValue);
    if (normalized === null) {
      throw new Parse.Error(Parse.Error.INVALID_VALUE, 'App Service Charge value no longer valid');
    }
    const effectiveAt = effectiveFrom ? new Date(effectiveFrom) : new Date();
    if (Number.isNaN(effectiveAt.getTime())) {
      throw new Parse.Error(Parse.Error.INVALID_VALUE, 'effectiveFrom is invalid');
    }
    targetUser.set(USER_APP_SERVICE_CHARGE_OVERRIDE_FIELDS.rate, normalized);
    targetUser.set(USER_APP_SERVICE_CHARGE_OVERRIDE_FIELDS.effectiveFrom, effectiveAt);
  }

  targetUser.set('appServiceChargeOverrideUpdatedAt', new Date());
  targetUser.set('appServiceChargeOverrideUpdatedBy', request.user.id);
  await targetUser.save(null, { useMasterKey: true });

  await saveConfigurationAuditLog({
    action: 'user_app_service_charge_change_approved',
    userId: request.user.id,
    userRole: request.user.get('role'),
    parameterName: 'appServiceChargeRateOverride',
    oldValue: oldValue ?? null,
    newValue: clearOverride ? null : normalizeAppServiceChargeRate(newValue),
    metadata: {
      fourEyesRequestId: requestId,
      targetUserId,
      targetUserEmail: metadata.targetUserEmail || null,
      clearOverride: Boolean(clearOverride),
      effectiveFrom: effectiveFrom || null,
      requesterId: req.get('requesterId'),
      reason: metadata.reason,
      isCritical: true,
      ip: request.ip,
    },
  });

  return true;
}

async function applyUserOpenDepotLimitChange({ req, requestId, request }) {
  const metadata = req.get('metadata') || {};
  const {
    targetUserId,
    newValue,
    oldValue,
    clearOverride,
    effectiveFrom,
  } = metadata;

  if (!targetUserId) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Invalid user open depot limit change request');
  }

  const targetUser = await new Parse.Query(Parse.User).get(targetUserId, { useMasterKey: true });

  if (clearOverride) {
    targetUser.unset(USER_OPEN_DEPOT_LIMIT_OVERRIDE_FIELDS.limit);
    targetUser.unset(USER_OPEN_DEPOT_LIMIT_OVERRIDE_FIELDS.effectiveFrom);
  } else {
    const normalized = normalizeMaxOpenDepotPositions(newValue);
    if (normalized === null) {
      throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Depot-Positions-Limit value no longer valid');
    }
    const effectiveAt = effectiveFrom ? new Date(effectiveFrom) : new Date();
    if (Number.isNaN(effectiveAt.getTime())) {
      throw new Parse.Error(Parse.Error.INVALID_VALUE, 'effectiveFrom is invalid');
    }
    targetUser.set(USER_OPEN_DEPOT_LIMIT_OVERRIDE_FIELDS.limit, normalized);
    targetUser.set(USER_OPEN_DEPOT_LIMIT_OVERRIDE_FIELDS.effectiveFrom, effectiveAt);
  }

  targetUser.set('maxOpenDepotPositionsOverrideUpdatedAt', new Date());
  targetUser.set('maxOpenDepotPositionsOverrideUpdatedBy', request.user.id);
  await targetUser.save(null, { useMasterKey: true });

  await saveConfigurationAuditLog({
    action: 'user_open_depot_limit_change_approved',
    userId: request.user.id,
    userRole: request.user.get('role'),
    parameterName: 'maxOpenDepotPositionsOverride',
    oldValue: oldValue ?? null,
    newValue: clearOverride ? null : normalizeMaxOpenDepotPositions(newValue),
    metadata: {
      fourEyesRequestId: requestId,
      targetUserId,
      targetUserEmail: metadata.targetUserEmail || null,
      clearOverride: Boolean(clearOverride),
      effectiveFrom: effectiveFrom || null,
      requesterId: req.get('requesterId'),
      reason: metadata.reason,
      isCritical: true,
      ip: request.ip,
    },
  });

  return true;
}

function registerApproveApprovalFunctions() {
  Parse.Cloud.define('approveRequest', async (request) => {
    requirePermission(request, 'approveRequest');

    const { requestId, notes } = request.params;
    if (!requestId) {
      throw new Parse.Error(Parse.Error.INVALID_VALUE, 'requestId required');
    }

    const FourEyesRequest = Parse.Object.extend('FourEyesRequest');
    const req = await new Parse.Query(FourEyesRequest).get(requestId, { useMasterKey: true });

    if (req.get('requesterId') === request.user.id) {
      throw new Parse.Error(
        Parse.Error.OPERATION_FORBIDDEN,
        'Cannot approve own request (4-eyes principle)'
      );
    }

    if (req.get('status') !== 'pending') {
      throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Request is not pending');
    }

    if (req.get('expiresAt') < new Date()) {
      req.set('status', 'expired');
      await req.save(null, { useMasterKey: true });
      throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Request has expired');
    }

    const requestType = req.get('requestType');
    const metadata = req.get('metadata') || {};
    let applied = false;

    if (requestType === 'configuration_change') {
      applied = await applyConfigurationChange({ req, requestId, request });
    }
    if (requestType === 'user_wallet_action_mode_change') {
      applied = await applyUserWalletActionModeChange({ req, requestId, request });
    }
    if (requestType === USER_COMMISSION_REQUEST_TYPE) {
      applied = await applyUserCommissionRateBundleChange({ req, requestId, request });
    }
    if (requestType === USER_APP_SERVICE_CHARGE_REQUEST_TYPE) {
      applied = await applyUserAppServiceChargeChange({ req, requestId, request });
    }
    if (requestType === USER_OPEN_DEPOT_LIMIT_REQUEST_TYPE) {
      applied = await applyUserOpenDepotLimitChange({ req, requestId, request });
    }

    if (requestType === 'correction') {
      const correction = await applyCorrectionRequest({
        metadata,
        requestId,
        approverId: request.user.id,
      });
      applied = correction.applied;

      await saveCorrectionAuditLog({
        userId: request.user.id,
        userRole: request.user.get('role'),
        requestId,
        correctionType: correction.correctionType,
        targetId: correction.targetId,
        amount: correction.amount,
        reason: correction.reason,
        applied,
        ip: request.ip,
      });
    }

    req.set('status', 'approved');
    req.set('approverId', request.user.id);
    req.set('approverRole', request.user.get('role'));
    req.set('approverEmail', request.user.get('email'));
    req.set('approverNotes', notes);
    req.set('approvedAt', new Date());
    await req.save(null, { useMasterKey: true });

    await saveFourEyesAudit({
      requestId,
      action: 'approved',
      requestType,
      performedBy: request.user.id,
      performedByRole: request.user.get('role'),
      notes,
      metadata,
    });

    await sendApprovalNotification(req, requestType, metadata);

    return {
      success: true,
      requestType,
      applied,
      message: applied
        ? requestType === 'configuration_change'
          ? `Konfiguration '${metadata.parameterName}' wurde auf ${metadata.newValue} gesetzt.`
          : requestType === 'user_wallet_action_mode_change'
            ? `Nutzerbezogener Konto-Aktionsmodus wurde auf ${metadata.newMode} gesetzt.`
            : requestType === USER_COMMISSION_REQUEST_TYPE
              ? metadata.clearOverride
                ? 'Individuelle Erfolgsprovision wurde entfernt (globale Provision gilt wieder).'
                : 'Individuelle Erfolgsprovision wurde für den Nutzer gesetzt.'
              : requestType === USER_APP_SERVICE_CHARGE_REQUEST_TYPE
                ? metadata.clearOverride
                  ? 'Individuelle App Service Charge wurde entfernt (globale Rate gilt wieder).'
                  : 'Individuelle App Service Charge wurde für den Nutzer gesetzt.'
                : requestType === USER_OPEN_DEPOT_LIMIT_REQUEST_TYPE
                  ? metadata.clearOverride
                    ? 'Individuelles Depot-Positionslimit wurde entfernt (globales Limit gilt wieder).'
                    : 'Individuelles Depot-Positionslimit wurde für den Nutzer gesetzt.'
                  : `Korrektur (${metadata.correctionType || requestType}) wurde ausgeführt.`
        : 'Anfrage genehmigt (manuelle Ausführung erforderlich).',
    };
  });
}

module.exports = {
  registerApproveApprovalFunctions,
};
