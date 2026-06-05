'use strict';

const { getUserStableId } = require('./tradingIdentity');
const { advancePairedOrderLegsStatus } = require('../utils/pairedOrderStatusCoupling');

async function handleAdvancePairedOrderStatus(request) {
  const user = request.user;
  if (!user) {
    throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Login required');
  }
  if (user.get('role') !== 'trader') {
    throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, 'Trader role required');
  }

  const { pairExecutionId, status } = request.params || {};
  if (!pairExecutionId || typeof pairExecutionId !== 'string') {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'pairExecutionId required');
  }
  if (!status || typeof status !== 'string') {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'status required');
  }

  return advancePairedOrderLegsStatus(
    pairExecutionId.trim(),
    getUserStableId(user),
    status.trim(),
  );
}

module.exports = {
  handleAdvancePairedOrderStatus,
};
