'use strict';

/**
 * Ops: compare Mongo `UserCashBalance.currentBalance` vs customer merge timeline
 * (same basis as `getAccountStatement` / `getUserCashBalance` display SSOT).
 */

const { computeCustomerClosingBalanceForUserId } = require('./customerClosingBalance');
const { readStoredUserCashBalanceForUser, getUserCashBalanceCollection } = require('./userCashBalanceAtomic');
const { euroToCents, normalizeEuro, withinCentsTolerance } = require('./moneyCents');

/**
 * @param {import('parse/node').Cloud.FunctionRequest['params']} params
 */
async function inspectUserCashBalanceDrift(params = {}) {
  const requestedLimit = Number(params.limitUsers || 500);
  const limitUsers = Math.min(5000, Math.max(1, requestedLimit));
  const previewLimit = Math.min(200, Math.max(1, Number(params.previewLimit || 50)));
  const filterUserId = String(params.userId || '').trim();

  const userQuery = new Parse.Query(Parse.User);
  if (filterUserId) {
    userQuery.equalTo('objectId', filterUserId);
  }
  userQuery.limit(limitUsers);
  userQuery.ascending('createdAt');
  const users = await userQuery.find({ useMasterKey: true });

  const driftedUsers = [];
  const missingRowUsers = [];
  const missingCentsUsers = [];
  const centsMismatchUsers = [];
  const skippedUsers = [];
  let usersProcessed = 0;
  let alignedUsers = 0;
  let drifted = 0;
  let missingRows = 0;
  let missingCents = 0;
  let centsMismatch = 0;

  const balColl = await getUserCashBalanceCollection();

  for (const user of users) {
    usersProcessed += 1;
    const uid = user.id;
    let customerBalance;
    try {
      // eslint-disable-next-line no-await-in-loop
      customerBalance = normalizeEuro(await computeCustomerClosingBalanceForUserId(uid));
    } catch (err) {
      skippedUsers.push({
        userId: uid,
        error: err && err.message ? err.message : String(err),
      });
      continue;
    }

    let storedBalance;
    try {
      // eslint-disable-next-line no-await-in-loop
      storedBalance = await readStoredUserCashBalanceForUser(uid);
    } catch (err) {
      skippedUsers.push({
        userId: uid,
        error: err && err.message ? err.message : String(err),
      });
      continue;
    }

    if (storedBalance == null) {
      missingRows += 1;
      if (missingRowUsers.length < previewLimit) {
        missingRowUsers.push({ userId: uid, customerBalance });
      }
      continue;
    }

    // eslint-disable-next-line no-await-in-loop
    const mongoRow = await balColl.findOne({ userId: uid });
    const storedCentsRaw = mongoRow && mongoRow.currentBalanceCents;
    if (storedCentsRaw === undefined || storedCentsRaw === null) {
      missingCents += 1;
      if (missingCentsUsers.length < previewLimit) {
        missingCentsUsers.push({ userId: uid, currentBalance: normalizeEuro(storedBalance) });
      }
    } else {
      const storedCents = Number(storedCentsRaw);
      const expectedCents = euroToCents(storedBalance);
      if (!Number.isFinite(storedCents) || !withinCentsTolerance(storedCents, expectedCents, 0)) {
        centsMismatch += 1;
        if (centsMismatchUsers.length < previewLimit) {
          centsMismatchUsers.push({
            userId: uid,
            currentBalance: normalizeEuro(storedBalance),
            currentBalanceCents: storedCents,
            expectedCents,
            deltaCents: expectedCents - storedCents,
          });
        }
      }
    }

    const storedEuroCents = euroToCents(storedBalance);
    const customerCents = euroToCents(customerBalance);
    if (withinCentsTolerance(storedEuroCents, customerCents)) {
      alignedUsers += 1;
      continue;
    }

    drifted += 1;
    if (driftedUsers.length < previewLimit) {
      driftedUsers.push({
        userId: uid,
        storedBalance: normalizeEuro(storedBalance),
        customerBalance,
        deltaCents: customerCents - storedEuroCents,
      });
    }
  }

  const examined = usersProcessed;
  const healthy = drifted === 0
    && missingRows === 0
    && missingCents === 0
    && centsMismatch === 0
    && skippedUsers.length === 0;

  return {
    healthy,
    basis: 'customer_timeline',
    examined,
    alignedUsers,
    drifted,
    missingRows,
    missingCents,
    centsMismatch,
    skipped: skippedUsers.length,
    limitUsers,
    filterUserId: filterUserId || null,
    driftedUsers,
    missingRowUsers,
    missingCentsUsers,
    centsMismatchUsers,
    skippedUsers: skippedUsers.slice(0, previewLimit),
    previewTruncated: drifted > driftedUsers.length
      || missingRows > missingRowUsers.length
      || missingCents > missingCentsUsers.length
      || centsMismatch > centsMismatchUsers.length
      || skippedUsers.length > previewLimit,
  };
}

module.exports = {
  inspectUserCashBalanceDrift,
};
