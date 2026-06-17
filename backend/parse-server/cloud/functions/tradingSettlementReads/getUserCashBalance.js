'use strict';

const { getUserStableId } = require('../tradingIdentity');
const {
  computeCustomerClosingBalanceForUser,
  auditUserCashBalanceDriftIfNeeded,
} = require('../../utils/accountingHelper/customerClosingBalance');
const { readStoredUserCashBalanceForUser } = require('../../utils/accountingHelper/userCashBalanceAtomic');

async function handleGetUserCashBalance(request) {
  const user = request.user;
  if (!user) throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Login required');

  const userId = getUserStableId(user);
  const currentBalance = await computeCustomerClosingBalanceForUser(user);

  try {
    const stored = await readStoredUserCashBalanceForUser(userId);
    if (stored != null) {
      auditUserCashBalanceDriftIfNeeded(userId, stored, currentBalance);
    }
  } catch {
    // drift audit is best-effort
  }

  return {
    userId,
    currentBalance,
    source: 'customer_timeline',
  };
}

module.exports = { handleGetUserCashBalance };
