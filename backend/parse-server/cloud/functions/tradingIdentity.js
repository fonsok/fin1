'use strict';

const {
  getCanonicalUserId,
  getUserStableId,
  collectLedgerUserIdCandidates,
} = require('../utils/canonicalUserId');

/**
 * Trade IDs linked to this investor via PoolTradeParticipation (for invoice visibility).
 *
 * @param {string} stableId Legacy or canonical investor key (resolved via candidates when possible)
 * @param {string} [parseUserId] Parse `_User.objectId` for the session user
 * @returns {Promise<string[]>}
 */
async function getTradeIdsForInvestorStableId(stableId, parseUserId) {
  const investorKeys = [...new Set(
    [stableId, parseUserId]
      .filter((v) => typeof v === 'string' && v.trim().length > 0)
      .map((v) => v.trim()),
  )];
  if (investorKeys.length === 0) return [];

  const invQuery = new Parse.Query('Investment');
  invQuery.containedIn('investorId', investorKeys);
  invQuery.select('objectId');
  invQuery.limit(3000);

  let investments = [];
  try {
    investments = await invQuery.find({ useMasterKey: true });
  } catch (_e) {
    return [];
  }
  if (investments.length === 0) return [];

  const invIds = investments.map((inv) => inv.id);
  const partQuery = new Parse.Query('PoolTradeParticipation');
  partQuery.containedIn('investmentId', invIds);
  partQuery.select('tradeId');
  partQuery.limit(20000);

  let parts = [];
  try {
    parts = await partQuery.find({ useMasterKey: true });
  } catch (_e) {
    return [];
  }

  const tradeIds = new Set(
    parts
      .map((p) => p.get('tradeId'))
      .filter(Boolean)
      .map((tid) => String(tid)),
  );
  return Array.from(tradeIds);
}

module.exports = {
  getUserStableId,
  getCanonicalUserId,
  collectLedgerUserIdCandidates,
  getTradeIdsForInvestorStableId,
};
