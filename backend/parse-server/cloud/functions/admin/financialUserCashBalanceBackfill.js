'use strict';

/**
 * Admin: `UserCashBalance.currentBalance` aus dem letzten `AccountStatement` pro User
 * nachziehen (Reconciliation / Post-Migration). Read-heavy; nutzt Mongo Aggregation
 * auf derselben DB wie Phase 3b.
 */

const { round2 } = require('../../utils/accountingHelper/shared');
const { audit } = require('../../utils/structuredLogger');
const { getAccountStatementMongoCollection, getUserCashBalanceCollection } = require('../../utils/accountingHelper/userCashBalanceAtomic');

/**
 * @param {import('parse/node').Cloud.FunctionRequest} request
 */
async function handleBackfillUserCashBalanceFromStatements(request) {
  const dryRun = request.params?.dryRun !== false;
  const requestedLimit = Number(request.params?.limitUsers || 500);
  const limitUsers = Math.min(5000, Math.max(1, requestedLimit));

  const stmtColl = await getAccountStatementMongoCollection();
  const balColl = await getUserCashBalanceCollection();

  const userIds = await stmtColl
    .distinct('userId', { userId: { $exists: true, $nin: [null, ''] } });
  const limitedUserIds = userIds.slice(0, limitUsers);

  const preview = [];
  let writesPerformed = 0;
  const targets = [];

  for (const userId of limitedUserIds) {
    const uid = String(userId || '').trim();
    if (!uid) continue;
    // eslint-disable-next-line no-await-in-loop
    const lastRow = await stmtColl
      .find({ userId: uid })
      .project({ balanceAfter: 1, _created_at: 1, _id: 1 })
      .sort({ _created_at: -1, _id: -1 })
      .limit(1)
      .next();
    if (!lastRow) continue;
    const target = round2(Number(lastRow.balanceAfter || 0));
    targets.push({ userId: uid, currentBalanceTarget: target });

    if (dryRun) {
      if (preview.length < 20) {
        preview.push({ userId: uid, currentBalanceTarget: target });
      }
      continue;
    }

    // eslint-disable-next-line no-await-in-loop
    await balColl.updateOne(
      { userId: uid },
      { $set: { userId: uid, currentBalance: target } },
      { upsert: true },
    );
    writesPerformed += 1;
  }

  audit.info('admin.userCashBalance.backfill', {
    dryRun,
    limitUsers,
    usersProcessed: limitedUserIds.length,
    writesPerformed,
    message: 'backfillUserCashBalanceFromStatements completed',
  });

  return {
    dryRun,
    limitUsers,
    usersProcessed: limitedUserIds.length,
    writesPerformed,
    preview,
  };
}

module.exports = {
  handleBackfillUserCashBalanceFromStatements,
};
