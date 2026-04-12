'use strict';

const { requirePermission } = require('../../../utils/permissions');
const { saveFourEyesAudit, saveConfigurationAuditLog } = require('./audit');
const { sendRejectionNotification } = require('./notifications');

function registerRejectApprovalFunctions() {
  Parse.Cloud.define('rejectRequest', async (request) => {
    requirePermission(request, 'rejectRequest');

    const { requestId, reason } = request.params;
    if (!requestId || !reason) {
      throw new Parse.Error(Parse.Error.INVALID_VALUE, 'requestId and reason required');
    }

    const FourEyesRequest = Parse.Object.extend('FourEyesRequest');
    const req = await new Parse.Query(FourEyesRequest).get(requestId, { useMasterKey: true });

    if (req.get('status') !== 'pending') {
      throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Request is not pending');
    }

    const requestType = req.get('requestType');
    const metadata = req.get('metadata') || {};

    req.set('status', 'rejected');
    req.set('approverId', request.user.id);
    req.set('approverRole', request.user.get('role'));
    req.set('approverEmail', request.user.get('email'));
    req.set('rejectionReason', reason);
    req.set('rejectedAt', new Date());
    await req.save(null, { useMasterKey: true });

    await saveFourEyesAudit({
      requestId,
      action: 'rejected',
      requestType,
      performedBy: request.user.id,
      performedByRole: request.user.get('role'),
      notes: reason,
      metadata,
    });

    if (requestType === 'configuration_change') {
      await saveConfigurationAuditLog({
        action: 'configuration_change_rejected',
        userId: request.user.id,
        userRole: request.user.get('role'),
        parameterName: metadata.parameterName,
        metadata: {
          fourEyesRequestId: requestId,
          requesterId: req.get('requesterId'),
          originalReason: metadata.reason,
          rejectionReason: reason,
          isCritical: true,
          ip: request.ip,
        },
      });
    }

    await sendRejectionNotification(req, requestType, metadata, reason);
    return { success: true };
  });
}

module.exports = {
  registerRejectApprovalFunctions,
};
