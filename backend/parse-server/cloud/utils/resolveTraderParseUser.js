'use strict';

/**
 * iOS discovery UI still uses MockTrader UUIDs locally; Parse expects `_User.objectId`.
 * Resolve active trader users by Parse id and/or username (seed: jbecker, awolf, …).
 */

function looksLikeIosMockTraderUuid(id) {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(String(id || '').trim());
}

/**
 * @param {{ traderId?: string, traderUsername?: string, traderDisplayName?: string }} input
 * @param {typeof Parse} Parse
 * @returns {Promise<Parse.User|null>}
 */
async function resolveTraderParseUser(input, Parse) {
  const rawId = String(input.traderId || '').trim();
  const username = String(input.traderUsername || '').trim().toLowerCase();
  const displayName = String(input.traderDisplayName || '').trim();

  async function fetchByObjectId(id) {
    const q = new Parse.Query(Parse.User);
    q.equalTo('objectId', id);
    q.equalTo('role', 'trader');
    q.equalTo('status', 'active');
    return q.first({ useMasterKey: true });
  }

  async function fetchByUsername(name) {
    const q = new Parse.Query(Parse.User);
    q.equalTo('username', name);
    q.equalTo('role', 'trader');
    q.equalTo('status', 'active');
    return q.first({ useMasterKey: true });
  }

  if (rawId && !looksLikeIosMockTraderUuid(rawId)) {
    const byId = await fetchByObjectId(rawId);
    if (byId) return byId;
  }

  if (username) {
    const byUsername = await fetchByUsername(username);
    if (byUsername) return byUsername;
  }

  if (displayName) {
    const byDisplay = await fetchByDisplayName(displayName, Parse, fetchByObjectId);
    if (byDisplay) return byDisplay;
  }

  if (rawId) {
    return fetchByObjectId(rawId);
  }

  return null;
}

/**
 * Match mock catalog names like "Jan Becker" via UserProfile (seed / discoverTraders).
 */
async function fetchByDisplayName(displayName, Parse, fetchByObjectId) {
  const parts = displayName.split(/\s+/).filter(Boolean);
  if (parts.length < 2) return null;
  const firstName = parts[0];
  const lastInitial = parts[parts.length - 1].charAt(0).toLowerCase();

  const pq = new Parse.Query('UserProfile');
  pq.equalTo('firstName', firstName);
  pq.limit(20);
  const profiles = await pq.find({ useMasterKey: true });
  for (const profile of profiles) {
    const lastName = String(profile.get('lastName') || '');
    if (!lastName || lastName.charAt(0).toLowerCase() !== lastInitial) continue;
    const userId = String(profile.get('userId') || '').trim();
    if (!userId) continue;
    const user = await fetchByObjectId(userId);
    if (user) return user;
  }
  return null;
}

module.exports = {
  resolveTraderParseUser,
  looksLikeIosMockTraderUuid,
};
