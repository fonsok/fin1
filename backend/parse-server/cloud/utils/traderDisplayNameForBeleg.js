'use strict';

/**
 * GoB: Trader-Anzeigename für Beleg-Metadaten (historisch fest beim Erzeugen).
 * Kein SSOT für Beträge — nur Partei-Identifikation auf dem Beleg.
 */

function pickUserDisplayName(user, profile) {
  if (!user) return null;
  const firstName = String(profile?.get?.('firstName') || user.get('firstName') || '').trim();
  const lastName = String(profile?.get?.('lastName') || user.get('lastName') || '').trim();
  const fullName = `${firstName} ${lastName}`.trim();
  if (fullName) return fullName;
  const username = String(user.get('username') || '').trim();
  if (username) return username;
  const customerNumber = String(user.get('customerNumber') || '').trim();
  if (customerNumber) return customerNumber;
  const email = String(user.get('email') || '').trim();
  if (email) return email;
  return null;
}

async function resolveTraderUser(traderId) {
  const raw = String(traderId || '').trim();
  if (!raw) return null;
  if (raw.startsWith('user:')) {
    const email = raw.replace('user:', '');
    return new Parse.Query(Parse.User)
      .equalTo('email', email)
      .first({ useMasterKey: true });
  }
  try {
    return await new Parse.Query(Parse.User).get(raw, { useMasterKey: true });
  } catch {
    return new Parse.Query(Parse.User)
      .equalTo('email', raw)
      .first({ useMasterKey: true });
  }
}

/**
 * @param {string} traderId — Parse User objectId oder legacy `user:email`
 * @returns {Promise<{ traderId: string, traderDisplayName: string|null, traderUsername: string|null }>}
 */
async function resolveTraderDisplayNameForBeleg(traderId) {
  const id = String(traderId || '').trim();
  if (!id) {
    return { traderId: '', traderDisplayName: null, traderUsername: null };
  }

  try {
    const traderUser = await resolveTraderUser(id);
    if (!traderUser) {
      return { traderId: id, traderDisplayName: null, traderUsername: null };
    }

    let profile = null;
    try {
      profile = await new Parse.Query('UserProfile')
        .equalTo('userId', traderUser.id)
        .first({ useMasterKey: true });
    } catch {
      // optional
    }

    return {
      traderId: traderUser.id,
      traderDisplayName: pickUserDisplayName(traderUser, profile),
      traderUsername: String(traderUser.get('username') || '').trim() || null,
    };
  } catch {
    return { traderId: id, traderDisplayName: null, traderUsername: null };
  }
}

module.exports = {
  pickUserDisplayName,
  resolveTraderUser,
  resolveTraderDisplayNameForBeleg,
};
