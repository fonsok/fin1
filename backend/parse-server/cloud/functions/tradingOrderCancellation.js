'use strict';

const { getUserStableId } = require('./tradingIdentity');
const { cancelTraderOrder } = require('../utils/pairedOrderCancellation');

async function handleCancelOrder(request) {
  const user = request.user;
  if (!user) {
    throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Login required');
  }
  if (user.get('role') !== 'trader') {
    throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, 'Trader role required');
  }

  const { orderId } = request.params || {};
  if (!orderId || typeof orderId !== 'string') {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'orderId required');
  }

  const traderId = getUserStableId(user);
  return cancelTraderOrder(orderId.trim(), traderId);
}

module.exports = {
  handleCancelOrder,
};
