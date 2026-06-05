'use strict';

const { round2 } = require('./accountingHelper/shared');
const {
  formatCurrency,
  createNotification,
  logComplianceEvent,
} = require('../triggers/investmentTriggerHelpers');

const TTL_MS = 5 * 60 * 1000;

/** @type {Map<string, { investorId: string, batchId: string, traderId: string, splits: Array<{ investmentId: string, amount: number, investmentNumber: string }>, startedAt: number }>} */
const deferredBuckets = new Map();

function batchKey(investorId, batchId) {
  return `${String(investorId || '').trim()}:${String(batchId || '').trim()}`;
}

function pruneExpired() {
  const now = Date.now();
  for (const [key, bucket] of deferredBuckets.entries()) {
    if (now - bucket.startedAt > TTL_MS) {
      deferredBuckets.delete(key);
    }
  }
}

/**
 * Marks a batch create in progress — afterSave skips per-split push notifications.
 */
function beginBatchNotificationDefer(investorId, batchId, traderId) {
  const key = batchKey(investorId, batchId);
  if (!key || key === ':') return;
  pruneExpired();
  deferredBuckets.set(key, {
    investorId: String(investorId || '').trim(),
    batchId: String(batchId || '').trim(),
    traderId: String(traderId || '').trim(),
    splits: [],
    startedAt: Date.now(),
  });
}

function shouldDeferInvestmentCreatedNotifications(investorId, batchId) {
  pruneExpired();
  return deferredBuckets.has(batchKey(investorId, batchId));
}

/**
 * Called from afterSave when notifications are deferred for this batch split.
 */
function recordDeferredSplitNotification(investorId, batchId, split) {
  const key = batchKey(investorId, batchId);
  const bucket = deferredBuckets.get(key);
  if (!bucket) return;
  bucket.splits.push({
    investmentId: String(split.investmentId || '').trim(),
    amount: round2(Number(split.amount) || 0),
    investmentNumber: String(split.investmentNumber || '').trim(),
  });
}

function discardDeferredBatchNotifications(investorId, batchId) {
  deferredBuckets.delete(batchKey(investorId, batchId));
}

function buildDigestMessages(bucket) {
  const count = bucket.splits.length;
  const total = round2(bucket.splits.reduce((sum, s) => round2(sum + s.amount), 0));
  const totalFmt = formatCurrency(total);
  const anteile = count === 1 ? '1 Anteil' : `${count} Anteile`;

  const investorTitle = count === 1 ? 'Investment reserviert' : 'Investments reserviert';
  const investorBody = count === 1
    ? `Ihr Investment über ${totalFmt} wurde reserviert. Bitte bestätigen Sie innerhalb von 24 Stunden.`
    : `${anteile} (${totalFmt} gesamt) wurden reserviert. Bitte bestätigen Sie innerhalb von 24 Stunden.`;

  const traderTitle = count === 1 ? 'Neues Investment' : 'Neue Pool-Investition';
  const traderBody = count === 1
    ? `Ein Investor hat ${totalFmt} in Ihren Pool investiert.`
    : `Ein Investor hat ${anteile} mit insgesamt ${totalFmt} in Ihren Pool investiert.`;

  return { investorTitle, investorBody, traderTitle, traderBody, count, total };
}

/**
 * Sends one investor + one trader notification (digest) after successful batch commit.
 */
async function flushBatchCreatedNotifications(investorId, batchId) {
  const key = batchKey(investorId, batchId);
  const bucket = deferredBuckets.get(key);
  if (!bucket || bucket.splits.length === 0) {
    deferredBuckets.delete(key);
    return;
  }

  const { investorTitle, investorBody, traderTitle, traderBody, count, total } = buildDigestMessages(bucket);

  try {
    await createNotification(
      bucket.investorId,
      'investment_created',
      'investment',
      investorTitle,
      investorBody,
    );
    await createNotification(
      bucket.traderId,
      'investment_created',
      'investment',
      traderTitle,
      traderBody,
    );
    await logComplianceEvent(
      bucket.investorId,
      'order_placed',
      'info',
      `Investment batch created: ${count} split(s), total ${formatCurrency(total)}`,
      {
        batchId: bucket.batchId,
        traderId: bucket.traderId,
        splitCount: count,
        totalAmount: total,
        investmentIds: bucket.splits.map((s) => s.investmentId).filter(Boolean),
      },
    );
  } catch (err) {
    console.error(
      `⚠️ flushBatchCreatedNotifications ${bucket.batchId}:`,
      err && err.message ? err.message : err,
    );
  } finally {
    deferredBuckets.delete(key);
  }
}

module.exports = {
  beginBatchNotificationDefer,
  shouldDeferInvestmentCreatedNotifications,
  recordDeferredSplitNotification,
  flushBatchCreatedNotifications,
  discardDeferredBatchNotifications,
  buildDigestMessages,
};
