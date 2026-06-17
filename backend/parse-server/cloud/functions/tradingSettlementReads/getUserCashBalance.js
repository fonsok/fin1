'use strict';

const { getUserStableId } = require('../tradingIdentity');
const { readUserCashBalanceForUser } = require('../../utils/accountingHelper/userCashBalanceAtomic');

async function handleGetUserCashBalance(request) {
  const user = request.user;
  if (!user) throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Login required');

  const userId = getUserStableId(user);
  const currentBalance = await readUserCashBalanceForUser(userId);

  return {
    userId,
    currentBalance,
    source: 'UserCashBalance',
  };
}

module.exports = { handleGetUserCashBalance };
