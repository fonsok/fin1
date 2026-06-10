'use strict';

/** Same keys as backend/scripts/clear-investments-trades-documents.js (INV, CB, CN, EB*, ORD, TXN). */
const TRADING_SEQUENCE_KEY_PATTERNS = [
  /^Investment::investmentNumber::INV::/,
  /^Document::accountingDocumentNumber::(CB|CN|EBP|EBR|EIR|EBT)::\d{4}$/,
  /^Order::orderNumber::ORD::\d{4}$/,
  /^WalletTransaction::transactionNumber::TXN::\d{4}$/,
];

function isTradingSequenceCounterKey(key) {
  const k = String(key || '');
  return TRADING_SEQUENCE_KEY_PATTERNS.some((re) => re.test(k));
}

async function loadTradingSequenceCounters() {
  const q = new Parse.Query('SequenceCounter');
  q.limit(1000);
  const rows = await q.find({ useMasterKey: true });
  return rows.filter((row) => isTradingSequenceCounterKey(row.get('key')));
}

/**
 * After scope=all wipe: delete counter rows so next INV/CB/ORD/TXN starts at 0000001.
 * Partial scopes (sinceHours, testUsers) intentionally skip — legacy rows may still exist.
 */
async function resetTradingSequenceCounters({ dryRun = false } = {}) {
  const rows = await loadTradingSequenceCounters();
  const preview = rows.map((row) => ({
    key: row.get('key'),
    value: row.get('value'),
  }));

  if (dryRun) {
    return { deleted: 0, wouldDelete: rows.length, keys: preview };
  }

  if (rows.length > 0) {
    await Parse.Object.destroyAll(rows, { useMasterKey: true });
  }

  return { deleted: rows.length, wouldDelete: 0, keys: preview };
}

module.exports = {
  TRADING_SEQUENCE_KEY_PATTERNS,
  isTradingSequenceCounterKey,
  resetTradingSequenceCounters,
};
