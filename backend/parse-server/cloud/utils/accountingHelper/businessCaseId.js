'use strict';

const crypto = require('crypto');

/**
 * Stable correlation id for auditors: ties Document, AccountStatement,
 * WalletTransaction metadata, AppLedgerEntry metadata, and Invoice rows
 * for one economic case.
 */
function newBusinessCaseId() {
  if (typeof crypto.randomUUID === 'function') {
    return crypto.randomUUID();
  }
  return crypto.randomBytes(16).toString('hex');
}

/**
 * New Trades get `businessCaseId` in beforeSave. Legacy rows: persist once.
 */
async function ensureBusinessCaseIdForTrade(trade) {
  if (!trade || !trade.id) {
    return '';
  }
  let id = trade.get('businessCaseId');
  if (id) {
    return String(id);
  }
  const Trade = Parse.Object.extend('Trade');
  let fresh;
  try {
    fresh = await new Parse.Query(Trade).get(trade.id, { useMasterKey: true });
  } catch {
    return '';
  }
  id = fresh.get('businessCaseId');
  if (id) {
    trade.set('businessCaseId', id);
    return String(id);
  }
  const generated = newBusinessCaseId();
  fresh.set('businessCaseId', generated);
  await fresh.save(null, { useMasterKey: true });
  trade.set('businessCaseId', generated);
  return generated;
}

module.exports = {
  newBusinessCaseId,
  ensureBusinessCaseIdForTrade,
};
