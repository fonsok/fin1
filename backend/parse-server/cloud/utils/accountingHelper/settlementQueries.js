'use strict';

const { round2 } = require('./shared');

async function findExistingStatementEntry({
  userId,
  tradeId,
  entryType,
}) {
  if (!userId || !tradeId || !entryType) return null;
  return new Parse.Query('AccountStatement')
    .equalTo('userId', userId)
    .equalTo('tradeId', tradeId)
    .equalTo('entryType', entryType)
    .equalTo('source', 'backend')
    .first({ useMasterKey: true });
}

async function sumStatementAmounts({
  userId,
  tradeId,
  investmentId,
  entryType,
  absolute = false,
}) {
  if (!userId || !tradeId || !entryType) return 0;
  const q = new Parse.Query('AccountStatement');
  q.equalTo('userId', userId);
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
  findExistingStatementEntry,
  sumStatementAmounts,
  getStatementSumsByType,
  prefetchInvestmentsById,
};
