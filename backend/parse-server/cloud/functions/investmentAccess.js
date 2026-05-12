'use strict';

/**
 * Match Investment.investorId to session user (objectId or stableId / email pattern).
 */
function investorOwnsInvestment(investment, user) {
  const invId = investment.get('investorId');
  if (!invId || !user) return false;
  const email = (user.get('email') || user.get('username') || '').toLowerCase();
  const stable = user.get('stableId') || (email ? `user:${email}` : '');
  return invId === user.id || (!!stable && invId === stable) || (!!email && invId === email);
}

/** Investment.traderId may be Parse _User id or stable id string used by the app. */
function traderOwnsInvestment(investment, user) {
  const tid = investment.get('traderId');
  if (!tid || !user) return false;
  if (tid === user.id) return true;
  const rawEmail = (user.get('email') || '').toLowerCase();
  const rawUsername = (user.get('username') || '').toLowerCase();
  const emailLocalPart = rawEmail.includes('@') ? rawEmail.split('@')[0] : '';
  const stableId = user.get('stableId');
  const candidates = new Set([
    rawEmail,
    rawUsername,
    emailLocalPart,
    stableId || '',
    rawEmail ? `user:${rawEmail}` : '',
    rawUsername ? `user:${rawUsername}` : '',
  ].filter(Boolean));

  return candidates.has(String(tid).toLowerCase());
}

async function resolveInvestorAccountType(investorId, fallback = 'individual') {
  if (!investorId || typeof investorId !== 'string') return fallback;
  try {
    const q = new Parse.Query(Parse.User);
    if (investorId.startsWith('user:')) {
      q.equalTo('email', investorId.slice(5));
      const byEmail = await q.first({ useMasterKey: true });
      return (byEmail && byEmail.get('accountType')) || fallback;
    }
    try {
      const byId = await new Parse.Query(Parse.User).get(investorId, { useMasterKey: true });
      return byId.get('accountType') || fallback;
    } catch {
      const byEmail = await new Parse.Query(Parse.User)
        .equalTo('email', investorId)
        .first({ useMasterKey: true });
      return (byEmail && byEmail.get('accountType')) || fallback;
    }
  } catch {
    return fallback;
  }
}

module.exports = {
  investorOwnsInvestment,
  traderOwnsInvestment,
  resolveInvestorAccountType,
};
