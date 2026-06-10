'use strict';

const { round2 } = require('./shared');
const { collectLedgerUserIdCandidates } = require('../../utils/canonicalUserId');

async function resolveLedgerUserKeysForUserId(userId) {
  const keys = new Set();
  const trimmed = String(userId || '').trim();
  if (!trimmed) return [];
  keys.add(trimmed);
  try {
    const user = await new Parse.Query(Parse.User).get(trimmed, { useMasterKey: true });
    for (const key of collectLedgerUserIdCandidates(user)) {
      keys.add(key);
    }
  } catch (_) {
    // Keep single id when user row is unavailable (tests / legacy rows).
  }
  return Array.from(keys);
}

async function findExistingStatementEntry({
  userId,
  tradeId,
  entryType,
  referenceDocumentId,
}) {
  if (!userId || !tradeId || !entryType) return null;
  const userKeys = await resolveLedgerUserKeysForUserId(userId);
  const keys = userKeys.length ? userKeys : [userId];
  const q = new Parse.Query('AccountStatement');
  if (keys.length === 1) {
    q.equalTo('userId', keys[0]);
  } else {
    q.containedIn('userId', keys);
  }
  q.equalTo('tradeId', tradeId);
  q.equalTo('entryType', entryType);
  q.equalTo('source', 'backend');
  const docRef = String(referenceDocumentId || '').trim();
  if (docRef) {
    q.equalTo('referenceDocumentId', docRef);
  }
  q.ascending('createdAt');
  return q.first({ useMasterKey: true });
}

/**
 * Trader Personenkonto cash legs: dedupe by tradeId, businessCaseId, tradeNumber, or pairExecutionId.
 * Prevents double trade_buy when paired legs created duplicate Trade rows.
 */
async function findExistingTraderTradeCashEntry({
  userId,
  tradeId,
  tradeNumber,
  entryType,
  businessCaseId,
  pairExecutionId,
}) {
  // trade_sell is idempotent per TSC (referenceDocumentId); never dedupe by tradeId alone.
  if (String(entryType || '') === 'trade_sell') {
    return null;
  }

  const direct = await findExistingStatementEntry({ userId, tradeId, entryType });
  if (direct) return direct;

  const userKeys = await resolveLedgerUserKeysForUserId(userId);
  const keys = userKeys.length ? userKeys : [userId];
  const statementForUser = () => {
    const q = new Parse.Query('AccountStatement');
    if (keys.length === 1) q.equalTo('userId', keys[0]);
    else q.containedIn('userId', keys);
    q.equalTo('entryType', entryType);
    q.equalTo('source', 'backend');
    return q;
  };

  const bc = String(businessCaseId || '').trim();
  if (bc) {
    const hit = await statementForUser().equalTo('businessCaseId', bc).first({ useMasterKey: true });
    if (hit) return hit;
  }

  if (tradeNumber !== undefined && tradeNumber !== null && tradeNumber !== '') {
    const hit = await statementForUser()
      .equalTo('tradeNumber', String(tradeNumber))
      .first({ useMasterKey: true });
    if (hit) return hit;
  }

  const pairId = String(pairExecutionId || '').trim();
  if (pairId) {
    const pairedTrades = await new Parse.Query('Trade')
      .equalTo('pairExecutionId', pairId)
      .limit(20)
      .find({ useMasterKey: true });
    const pairedTradeIds = pairedTrades.map((t) => t.id).filter(Boolean);
    if (pairedTradeIds.length) {
      const hit = await statementForUser()
        .containedIn('tradeId', pairedTradeIds)
        .first({ useMasterKey: true });
      if (hit) return hit;
    }
  }

  return null;
}

async function sumStatementAmounts({
  userId,
  userKeys,
  tradeId,
  investmentId,
  entryType,
  absolute = false,
}) {
  const keys = Array.isArray(userKeys) && userKeys.length > 0
    ? userKeys.filter(Boolean)
    : (userId ? [userId] : []);
  if (!keys.length || !tradeId || !entryType) return 0;
  const q = new Parse.Query('AccountStatement');
  if (keys.length === 1) {
    q.equalTo('userId', keys[0]);
  } else {
    q.containedIn('userId', keys);
  }
  q.equalTo('tradeId', tradeId);
  q.equalTo('entryType', entryType);
  q.equalTo('source', 'backend');
  if (investmentId) q.equalTo('investmentId', investmentId);
  const rows = await q.find({ useMasterKey: true });
  const sum = rows.reduce((acc, row) => acc + Number(row.get('amount') || 0), 0);
  return round2(absolute ? Math.abs(sum) : sum);
}

async function getStatementSumsByType({
  userId,
  tradeId,
  investmentId,
  entryTypes,
  absolute = false,
}) {
  if (!userId || !tradeId || !Array.isArray(entryTypes) || entryTypes.length === 0) return {};
  const q = new Parse.Query('AccountStatement');
  q.equalTo('userId', userId);
  q.equalTo('tradeId', tradeId);
  q.equalTo('source', 'backend');
  if (investmentId) q.equalTo('investmentId', investmentId);
  q.containedIn('entryType', entryTypes);
  const rows = await q.find({ useMasterKey: true });

  const sums = {};
  entryTypes.forEach((t) => { sums[t] = 0; });
  for (const row of rows) {
    const t = row.get('entryType');
    if (!Object.prototype.hasOwnProperty.call(sums, t)) continue;
    sums[t] += Number(row.get('amount') || 0);
  }
  Object.keys(sums).forEach((key) => {
    sums[key] = round2(absolute ? Math.abs(sums[key]) : sums[key]);
  });
  return sums;
}

async function prefetchInvestmentsById(participations) {
  const ids = Array.from(new Set(
    (participations || [])
      .map((p) => String(p.get('investmentId') || '').trim())
      .filter(Boolean)
  ));
  if (!ids.length) return new Map();

  const q = new Parse.Query('Investment');
  q.containedIn('objectId', ids);
  q.limit(Math.max(1000, ids.length));
  const rows = await q.find({ useMasterKey: true });
  const byId = new Map();
  for (const inv of rows) byId.set(inv.id, inv);
  return byId;
}

module.exports = {
  resolveLedgerUserKeysForUserId,
  findExistingStatementEntry,
  findExistingTraderTradeCashEntry,
  sumStatementAmounts,
  getStatementSumsByType,
  prefetchInvestmentsById,
};
