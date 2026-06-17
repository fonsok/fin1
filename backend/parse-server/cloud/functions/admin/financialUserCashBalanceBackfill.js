'use strict';

/**
 * Admin: reconcile `UserCashBalance.currentBalance` to customer merge timeline
 * (same basis as `getAccountStatement` / Admin „Kundensicht“).
 */

const { audit } = require('../../utils/structuredLogger');
const { getUserCashBalanceCollection } = require('../../utils/accountingHelper/userCashBalanceAtomic');
const { computeCustomerClosingBalanceForUserId } = require('../../utils/accountingHelper/customerClosingBalance');
const { normalizeEuro, euroToCents } = require('../../utils/accountingHelper/moneyCents');

/**
 * @param {import('parse/node').Cloud.FunctionRequest} request
 */
async function handleBackfillUserCashBalanceFromStatements(request) {
  const dryRun = request.params?.dryRun !== false;
  const requestedLimit = Number(request.params?.limitUsers || 500);
  const limitUsers = Math.min(5000, Math.max(1, requestedLimit));

  const balColl = await getUserCashBalanceCollection();

  const userQuery = new Parse.Query(Parse.User);
  userQuery.limit(limitUsers);
  userQuery.ascending('createdAt');
  const users = await userQuery.find({ useMasterKey: true });

  const preview = [];
  let writesPerformed = 0;
  let usersProcessed = 0;
  let skipped = 0;

  for (const user of users) {
    usersProcessed += 1;
    const uid = user.id;
    let target;
    try {
      // eslint-disable-next-line no-await-in-loop
      target = normalizeEuro(await computeCustomerClosingBalanceForUserId(uid));
    } catch (err) {
      skipped += 1;
      audit.warn('admin.userCashBalance.backfill.skip', {
        userId: uid,
        error: err && err.message ? err.message : String(err),
      });
      continue;
    }

    if (dryRun) {
      if (preview.length < 20) {
        preview.push({ userId: uid, currentBalanceTarget: target });
      }
      continue;
    }

    // eslint-disable-next-line no-await-in-loop
    await balColl.updateOne(
      { userId: uid },
      {
        $set: {
          userId: uid,
          currentBalance: target,
          currentBalanceCents: euroToCents(target),
        },
      },
      { upsert: true },
    );
    writesPerformed += 1;
  }

  audit.info('admin.userCashBalance.backfill', {
    dryRun,
    limitUsers,
    usersProcessed,
    writesPerformed,
    skipped,
    basis: 'customer_timeline',
    message: 'backfillUserCashBalanceFromStatements completed',
  });

  return {
    dryRun,
    limitUsers,
    usersProcessed,
    writesPerformed,
    skipped,
    basis: 'customer_timeline',
    preview,
  };
}

module.exports = {
  handleBackfillUserCashBalanceFromStatements,
};
