'use strict';

const { requirePermission } = require('../../../utils/permissions');
const { getRequesterIdString } = require('../helpers');

function toApprovalJson(obj) {
  const json = obj.toJSON ? obj.toJSON() : obj;
  if (json.requesterId != null && typeof json.requesterId !== 'string') {
    json.requesterId = json.requesterId.objectId || json.requesterId.id || String(json.requesterId);
  }
  return json;
}

function registerPendingApprovalFunctions() {
  Parse.Cloud.define('getPendingApprovals', async (request) => {
    requirePermission(request, 'getPendingApprovals');

    const userIdStr = String(request.user.id);

    const pendingQuery = new Parse.Query('FourEyesRequest');
    pendingQuery.equalTo('status', 'pending');
    pendingQuery.greaterThan('expiresAt', new Date());
    pendingQuery.descending('createdAt');
    const allPending = await pendingQuery.find({ useMasterKey: true });

    const pendingOthers = [];
    const ownPending = [];
    for (const r of allPending) {
      const rid = getRequesterIdString(r);
      if (rid === userIdStr) {
        ownPending.push(r);
      } else {
        pendingOthers.push(r);
      }
    }

    const historyQuery = new Parse.Query('FourEyesRequest');
    historyQuery.containedIn('status', ['approved', 'rejected', 'expired', 'withdrawn']);
    historyQuery.greaterThan('updatedAt', new Date(Date.now() - 30 * 24 * 60 * 60 * 1000));
    historyQuery.descending('updatedAt');
    historyQuery.limit(50);
    const history = await historyQuery.find({ useMasterKey: true });

    const allQuery = new Parse.Query('FourEyesRequest');
    allQuery.descending('createdAt');
    allQuery.limit(100);
    const allRequests = await allQuery.find({ useMasterKey: true });

    return {
      requests: pendingOthers.map(toApprovalJson),
      ownPending: ownPending.map(toApprovalJson),
      history: history.map(toApprovalJson),
      allRequests: allRequests.map(toApprovalJson),
    };
  });
}

module.exports = {
  registerPendingApprovalFunctions,
};
