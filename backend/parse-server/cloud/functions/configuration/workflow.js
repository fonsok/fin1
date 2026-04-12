'use strict';

const { requirePermissionWithTestAuth } = require('../../utils/testAuthMiddleware');
const {
  loadConfig,
  validateConfigValue,
  isCriticalParameter,
  validateTransactionLimitOrdering,
  validateInvestmentAmountOrdering,
} = require('../../utils/configHelper/index.js');
const { applyConfigurationChange, formatValue, getOldValueFromConfig } = require('./shared');
const {
  logConfigurationChangeRequest,
  logConfigurationChange,
  logConfigurationChangeApproval,
  logConfigurationChangeRejection,
} = require('./audit');
const {
  notifyApproversOfPendingRequest,
  notifyRequesterOfApproval,
  notifyRequesterOfRejection,
} = require('./notifications');

function registerConfigurationWorkflowFunctions() {
  Parse.Cloud.define('requestConfigurationChange', async (request) => {
    await requirePermissionWithTestAuth(request, 'createCorrectionRequest');

    const { parameterName, newValue, reason } = request.params;
    if (!parameterName || newValue === undefined || !reason) {
      throw new Parse.Error(Parse.Error.INVALID_VALUE, 'parameterName, newValue, and reason are required');
    }

    const validation = validateConfigValue(parameterName, newValue);
    if (!validation.valid) {
      throw new Parse.Error(Parse.Error.INVALID_VALUE, validation.error);
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
    const oldValue = getOldValueFromConfig(currentConfig, parameterName);

    if (isCriticalParameter(parameterName)) {
      const FourEyesRequest = Parse.Object.extend('FourEyesRequest');
      const fourEyesReq = new FourEyesRequest();

      fourEyesReq.set('requestType', 'configuration_change');
      fourEyesReq.set('requesterId', request.user.id);
      fourEyesReq.set('requesterRole', request.user.get('role'));
      fourEyesReq.set('requesterEmail', request.user.get('email'));
      fourEyesReq.set('status', 'pending');
      fourEyesReq.set('expiresAt', new Date(Date.now() + 7 * 24 * 60 * 60 * 1000));
      fourEyesReq.set('metadata', {
        parameterName,
        oldValue,
        newValue,
        reason,
        isCritical: true,
      });

      await fourEyesReq.save(null, { useMasterKey: true });

      await logConfigurationChangeRequest(request, parameterName, oldValue, newValue, reason, fourEyesReq.id);
      await notifyApproversOfPendingRequest(fourEyesReq, parameterName, newValue, reason);

      return {
        success: true,
        requiresApproval: true,
        fourEyesRequestId: fourEyesReq.id,
        message: `Configuration change for '${parameterName}' requires 4-eyes approval. Request ID: ${fourEyesReq.id}`,
      };
    }

    const valueToApply = parameterName === 'walletFeatureEnabled'
      ? Boolean(Number(newValue))
      : newValue;

    await applyConfigurationChange(parameterName, valueToApply, request.user.id);
    await logConfigurationChange(request, parameterName, oldValue, newValue, reason, null);

    return {
      success: true,
      requiresApproval: false,
      message: `Configuration '${parameterName}' updated successfully.`,
    };
  });

  Parse.Cloud.define('approveConfigurationChange', async (request) => {
    await requirePermissionWithTestAuth(request, 'approveRequest');

    const { requestId, notes } = request.params;
    if (!requestId) {
      throw new Parse.Error(Parse.Error.INVALID_VALUE, 'requestId is required');
    }

    const FourEyesRequest = Parse.Object.extend('FourEyesRequest');
    const req = await new Parse.Query(FourEyesRequest).get(requestId, { useMasterKey: true });
    if (!req) {
      throw new Parse.Error(Parse.Error.OBJECT_NOT_FOUND, 'Request not found');
    }
    if (req.get('requestType') !== 'configuration_change') {
      throw new Parse.Error(Parse.Error.INVALID_VALUE, 'This is not a configuration change request');
    }
    if (req.get('requesterId') === request.user.id) {
      throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, 'Cannot approve your own request (4-eyes principle)');
    }
    if (req.get('status') !== 'pending') {
      throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Request is not pending');
    }
    if (req.get('expiresAt') < new Date()) {
      req.set('status', 'expired');
      await req.save(null, { useMasterKey: true });
      throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Request has expired');
    }

    const metadata = req.get('metadata');
    const { parameterName, newValue, oldValue } = metadata;

    await applyConfigurationChange(parameterName, newValue, request.user.id);

    req.set('status', 'approved');
    req.set('approverId', request.user.id);
    req.set('approverRole', request.user.get('role'));
    req.set('approverEmail', request.user.get('email'));
    req.set('approverNotes', notes);
    req.set('approvedAt', new Date());
    await req.save(null, { useMasterKey: true });

    await logConfigurationChangeApproval(request, req, parameterName, oldValue, newValue);
    await notifyRequesterOfApproval(req, parameterName, newValue);

    return {
      success: true,
      message: `Configuration '${parameterName}' has been updated to ${formatValue(newValue)}.`,
      appliedValue: newValue,
    };
  });

  Parse.Cloud.define('rejectConfigurationChange', async (request) => {
    await requirePermissionWithTestAuth(request, 'rejectRequest');

    const { requestId, reason } = request.params;
    if (!requestId || !reason) {
      throw new Parse.Error(Parse.Error.INVALID_VALUE, 'requestId and reason are required');
    }

    const FourEyesRequest = Parse.Object.extend('FourEyesRequest');
    const req = await new Parse.Query(FourEyesRequest).get(requestId, { useMasterKey: true });
    if (!req) {
      throw new Parse.Error(Parse.Error.OBJECT_NOT_FOUND, 'Request not found');
    }
    if (req.get('requestType') !== 'configuration_change') {
      throw new Parse.Error(Parse.Error.INVALID_VALUE, 'This is not a configuration change request');
    }
    if (req.get('status') !== 'pending') {
      throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Request is not pending');
    }

    const metadata = req.get('metadata');

    req.set('status', 'rejected');
    req.set('approverId', request.user.id);
    req.set('approverRole', request.user.get('role'));
    req.set('rejectionReason', reason);
    req.set('rejectedAt', new Date());
    await req.save(null, { useMasterKey: true });

    await logConfigurationChangeRejection(request, req, metadata.parameterName, reason);
    await notifyRequesterOfRejection(req, metadata.parameterName, reason);

    return {
      success: true,
      message: `Configuration change request for '${metadata.parameterName}' has been rejected.`,
    };
  });
}

module.exports = { registerConfigurationWorkflowFunctions };
