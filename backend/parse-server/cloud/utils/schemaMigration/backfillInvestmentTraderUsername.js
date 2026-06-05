'use strict';

const PAGE_SIZE = 100;
const MAX_UPDATES_PER_RUN = 5000;

/**
 * Sets `Investment.traderUsername` from Parse `_User.username` when missing (legacy rows).
 * Idempotent: only touches rows without a non-empty traderUsername.
 *
 * @returns {Promise<{ ok: boolean, updated: number, skipped: number, pages: number, remaining?: number }>}
 */
async function backfillInvestmentTraderUsername() {
  let updated = 0;
  let skipped = 0;
  let pages = 0;
  let skip = 0;

  while (updated + skipped < MAX_UPDATES_PER_RUN) {
    const qMissing = new Parse.Query('Investment');
    qMissing.doesNotExist('traderUsername');
    const qEmpty = new Parse.Query('Investment');
    qEmpty.equalTo('traderUsername', '');
    const q = Parse.Query.or(qMissing, qEmpty);
    q.limit(PAGE_SIZE);
    q.skip(skip);
    q.ascending('createdAt');

    // eslint-disable-next-line no-await-in-loop
    const batch = await q.find({ useMasterKey: true });
    if (!batch.length) break;
    pages += 1;

    const traderIds = [...new Set(
      batch
        .map((inv) => String(inv.get('traderId') || '').trim())
        .filter((id) => id.length > 0),
    )];

    const usernameByTraderId = new Map();
    if (traderIds.length > 0) {
      const userQuery = new Parse.Query(Parse.User);
      userQuery.containedIn('objectId', traderIds);
      userQuery.limit(Math.min(traderIds.length, 1000));
      // eslint-disable-next-line no-await-in-loop
      const users = await userQuery.find({ useMasterKey: true });
      for (const user of users) {
        const username = String(user.get('username') || '').trim().toLowerCase();
        if (username) usernameByTraderId.set(user.id, username);
      }
    }

    const toSave = [];
    for (const inv of batch) {
      const traderId = String(inv.get('traderId') || '').trim();
      const username = usernameByTraderId.get(traderId);
      if (!username) {
        skipped += 1;
        continue;
      }
      inv.set('traderUsername', username);
      toSave.push(inv);
    }

    if (toSave.length > 0) {
      // eslint-disable-next-line no-await-in-loop
      await Parse.Object.saveAll(toSave, { useMasterKey: true });
      updated += toSave.length;
    } else {
      // Unresolvable rows (no _User) — advance skip to avoid an infinite loop.
      skip += batch.length;
    }

    if (batch.length < PAGE_SIZE) break;
  }

  const remainingQuery = Parse.Query.or(
    new Parse.Query('Investment').doesNotExist('traderUsername'),
    new Parse.Query('Investment').equalTo('traderUsername', ''),
  );
  remainingQuery.limit(1);
  const remainingProbe = await remainingQuery.count({ useMasterKey: true });

  return {
    ok: remainingProbe === 0,
    updated,
    skipped,
    pages,
    remaining: remainingProbe > 0 ? remainingProbe : 0,
  };
}

module.exports = {
  backfillInvestmentTraderUsername,
};
