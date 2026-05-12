'use strict';

const { getInitialAccountBalance } = require('../../../utils/configHelper/index.js');
const { round2 } = require('../../../utils/accountingHelper/shared');

/**
 * One completed deposit per investor/trader so getWalletBalance matches Configuration.initialAccountBalance.
 * Two-step save (pending → completed) so WalletTransaction afterSave runs GoB receipt + AccountStatement.
 */
async function seedInitialBalancesFromConfig() {
  const amount = round2(Number(await getInitialAccountBalance()) || 0);
  if (amount <= 0) {
    return {
      amountPerUser: 0,
      seededUsers: 0,
      note: 'initialAccountBalance is 0 — no wallet rows created.',
    };
  }

  const userQuery = new Parse.Query(Parse.User);
  userQuery.containedIn('role', ['investor', 'trader']);
  userQuery.limit(1000);
  const users = await userQuery.find({ useMasterKey: true });

  const WalletTransaction = Parse.Object.extend('WalletTransaction');
  let seededUsers = 0;
  const errors = [];

  for (const u of users) {
    const uid = u.id;
    try {
      const tx = new WalletTransaction();
      tx.set('userId', uid);
      tx.set('transactionType', 'deposit');
      tx.set('amount', amount);
      tx.set('status', 'pending');
      tx.set('description', 'Startguthaben (Konfiguration initialAccountBalance) nach DEV-Reset');
      await tx.save(null, { useMasterKey: true });
      tx.set('status', 'completed');
      await tx.save(null, { useMasterKey: true });
      seededUsers += 1;
    } catch (err) {
      errors.push({ userId: uid, message: err.message || String(err) });
    }
  }

  return {
    amountPerUser: amount,
    seededUsers,
    eligibleUsers: users.length,
    errors: errors.length ? errors : undefined,
  };
}

module.exports = {
  seedInitialBalancesFromConfig,
};
