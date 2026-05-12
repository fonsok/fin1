'use strict';

const { requirePermission } = require('../../../utils/permissions');
const {
  validateConfigValue,
  validateTransactionLimitOrdering,
  validateInvestmentAmountOrdering,
  loadConfig,
} = require('../../../utils/configHelper/index.js');
const { applyConfigurationChange: persistConfigurationChange } = require('../../configuration/shared');
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
          : `Korrektur (${metadata.correctionType || requestType}) wurde ausgeführt.`
        : 'Anfrage genehmigt (manuelle Ausführung erforderlich).',
    };
  });
}

module.exports = {
  registerApproveApprovalFunctions,
};
