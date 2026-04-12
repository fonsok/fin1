'use strict';

const { requirePermission } = require('../../../utils/permissions');
const { saveFourEyesAudit } = require('./audit');

function registerWithdrawApprovalFunctions() {
  Parse.Cloud.define('withdrawRequest', async (request) => {
    requirePermission(request, 'getPendingApprovals');

    const { requestId, reason } = request.params;
    if (!requestId) {
      throw new Parse.Error(Parse.Error.INVALID_VALUE, 'requestId required');
    }

    const FourEyesRequest = Parse.Object.extend('FourEyesRequest');
    const req = await new Parse.Query(FourEyesRequest).get(requestId, { useMasterKey: true });

    if (req.get('requesterId') !== request.user.id) {
      throw new Parse.Error(
        Parse.Error.OPERATION_FORBIDDEN,
        'Only the original requester can withdraw this request'
      );
    }

    if (req.get('status') !== 'pending') {
      throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Only pending requests can be withdrawn');
    }

    req.set('status', 'withdrawn');
    req.set('withdrawnAt', new Date());
    req.set('withdrawnReason', reason || 'Vom Antragsteller zurückgezogen');
    await req.save(null, { useMasterKey: true });

    await saveFourEyesAudit({
      requestId,
      action: 'withdrawn',
      requestType: req.get('requestType'),
      performedBy: request.user.id,
      performedByRole: request.user.get('role'),
      notes: reason || 'Vom Antragsteller zurückgezogen',
      metadata: req.get('metadata'),
    });

    return { success: true, message: 'Antrag zurückgezogen.' };
  });
}

module.exports = {
  registerWithdrawApprovalFunctions,
};
