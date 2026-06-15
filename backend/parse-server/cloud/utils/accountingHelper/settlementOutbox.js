'use strict';

/**
 * ADR-017 Phase +1: Settlement GL Outbox — AccountStatement + outbox row atomically;
 * AppLedger pairs posted asynchronously by worker (at-least-once, idempotent legs).
 */

const { loadConfig } = require('../configHelper/index.js');
const { audit } = require('../structuredLogger');

const OUTBOX_KIND = 'settlement_gl';
const RETRY_SCHEDULE_MINUTES = [1, 5, 15, 60, 180, 720];
const DEFAULT_MAX_ATTEMPTS = RETRY_SCHEDULE_MINUTES.length;
const PROCESSING_LEASE_MS = 5 * 60 * 1000;

function nowDate() {
  return new Date();
}

function computeNextRetryAt(attempt) {
  const idx = Math.max(0, Math.min(RETRY_SCHEDULE_MINUTES.length - 1, attempt - 1));
  const minutes = RETRY_SCHEDULE_MINUTES[idx];
  return new Date(Date.now() + (minutes * 60 * 1000));
}

function serializeError(err) {
  if (!err) return 'unknown error';
  return err && err.message ? err.message : String(err);
}

function createLockToken() {
  return `lock_${Date.now()}_${Math.random().toString(36).slice(2, 10)}`;
}

function isLeaseActive(row) {
  const leaseUntil = row.get('leaseUntil');
  if (!leaseUntil) return false;
  return new Date(leaseUntil).getTime() > Date.now();
}

async function isSettlementGLOutboxEnabled() {
  const config = await loadConfig(true);
  return config.display?.settlementGLOutboxEnabled === true;
}

function buildSettlementGLOutboxIdempotencyKey({ tradeId, entryType, investmentId, userId }) {
  const inv = String(investmentId || '').trim() || 'none';
  const uid = String(userId || '').trim();
  const tid = String(tradeId || '').trim();
  const et = String(entryType || '').trim();
  return `gl_outbox:${uid}:${tid}:${et}:${inv}`;
}

function buildSettlementOutboxObject({ idempotencyKey, payload }) {
  const Outbox = Parse.Object.extend('SettlementOutbox');
  const row = new Outbox();
  row.set('kind', OUTBOX_KIND);
  row.set('idempotencyKey', idempotencyKey);
  row.set('status', 'pending');
  row.set('attempts', 0);
  row.set('maxAttempts', DEFAULT_MAX_ATTEMPTS);
  row.set('nextRetryAt', nowDate());
  row.set('payload', payload);
  if (payload.tradeId) row.set('tradeId', payload.tradeId);
  if (payload.entryType) row.set('entryType', payload.entryType);
  if (payload.investmentId) row.set('investmentId', payload.investmentId);
  if (payload.userId) row.set('userId', payload.userId);
  return row;
}

/**
 * Persist AccountStatement + SettlementOutbox in one Mongo transaction (ADR-017).
 */
async function saveAccountStatementWithOutbox(entry, outboxPayload) {
  const idempotencyKey = buildSettlementGLOutboxIdempotencyKey(outboxPayload);

  const existingOutbox = await new Parse.Query('SettlementOutbox')
    .equalTo('idempotencyKey', idempotencyKey)
    .containedIn('status', ['pending', 'processing', 'posted'])
    .first({ useMasterKey: true });

  if (existingOutbox) {
    await entry.save(null, { useMasterKey: true });
    return { entry, outbox: existingOutbox, reusedOutbox: true };
  }

  const outbox = buildSettlementOutboxObject({ idempotencyKey, payload: outboxPayload });

  try {
    await Parse.Object.saveAll([entry, outbox], { useMasterKey: true, transaction: true });
  } catch (err) {
    audit.error('settlement.outbox.transactionFailure', {
      idempotencyKey,
      tradeId: outboxPayload.tradeId || null,
      entryType: outboxPayload.entryType || null,
      error: serializeError(err),
      message: 'saveAccountStatementWithOutbox: Mongo transaction failed',
    });
    throw err;
  }

  outbox.set('accountStatementId', entry.id);
  const payloadWithStmt = Object.assign({}, outboxPayload, { accountStatementId: entry.id });
  outbox.set('payload', payloadWithStmt);
  await outbox.save(null, { useMasterKey: true });

  audit.info('settlement.outbox.enqueued', {
    outboxId: outbox.id,
    accountStatementId: entry.id,
    idempotencyKey,
    tradeId: outboxPayload.tradeId || null,
    entryType: outboxPayload.entryType || null,
    message: 'SettlementOutbox row created with AccountStatement',
  });

  return { entry, outbox, reusedOutbox: false };
}

async function claimSettlementOutboxRow(outboxId) {
  const current = await new Parse.Query('SettlementOutbox').get(outboxId, { useMasterKey: true });
  const status = String(current.get('status') || 'pending');

  if (status === 'posted' || status === 'failed') return null;
  if (status === 'processing' && isLeaseActive(current)) return null;

  const attempts = Number(current.get('attempts') || 0) + 1;
  const maxAttempts = Math.max(1, Number(current.get('maxAttempts') || DEFAULT_MAX_ATTEMPTS));
  const lockToken = createLockToken();

  current.set('status', 'processing');
  current.set('attempts', attempts);
  current.set('startedAt', nowDate());
  current.set('lockToken', lockToken);
  current.set('leaseUntil', new Date(Date.now() + PROCESSING_LEASE_MS));
  await current.save(null, { useMasterKey: true });

  const owned = await new Parse.Query('SettlementOutbox').get(outboxId, { useMasterKey: true });
  if (String(owned.get('lockToken') || '') !== lockToken || String(owned.get('status') || '') !== 'processing') {
    return null;
  }

  return { row: owned, attempts, maxAttempts, lockToken };
}

/**
 * Post AppLedger pair(s) for a single outbox row (idempotent via postLedgerPair legs).
 */
async function postSettlementGLFromOutbox(outboxRow) {
  const payload = outboxRow.get('payload');
  if (!payload || typeof payload !== 'object') {
    throw new Error('SettlementOutbox missing payload');
  }

  const { postSettlementGLPair } = require('./settlementGLPoster');
  const accountStatementId = outboxRow.get('accountStatementId') || payload.accountStatementId || '';

  return postSettlementGLPair({
    userId: payload.userId,
    userRole: payload.userRole,
    entryType: payload.entryType,
    amount: payload.amount,
    tradeId: payload.tradeId,
    tradeNumber: payload.tradeNumber,
    investmentId: payload.investmentId,
    investmentNumber: payload.investmentNumber,
    description: payload.description,
    referenceDocumentId: payload.referenceDocumentId,
    referenceDocumentNumber: payload.referenceDocumentNumber,
    feeBreakdown: payload.feeBreakdown,
    ledgerReference: payload.ledgerReference,
    accountStatementId,
    businessCaseId: payload.businessCaseId,
  });
}

async function processSingleSettlementOutboxRow(claimed) {
  const row = claimed.row;
  const attempts = claimed.attempts;
  const maxAttempts = claimed.maxAttempts;
  const lockToken = claimed.lockToken;
  const outboxId = row.id;

  try {
    audit.info('settlement.outbox.process.start', {
      outboxId,
      attempts,
      maxAttempts,
      tradeId: row.get('tradeId') || null,
      entryType: row.get('entryType') || null,
      message: 'Processing SettlementOutbox row',
    });

    const ledgerRows = await postSettlementGLFromOutbox(row);

    row.set('status', 'posted');
    row.set('postedAt', nowDate());
    row.set('lastError', null);
    row.set('ledgerRowCount', Array.isArray(ledgerRows) ? ledgerRows.length : 0);
    row.unset('lockToken');
    row.unset('leaseUntil');
    await row.save(null, { useMasterKey: true });

    audit.info('settlement.outbox.process.done', {
      outboxId,
      attempts,
      ledgerRowCount: Array.isArray(ledgerRows) ? ledgerRows.length : 0,
      message: 'SettlementOutbox row posted',
    });

    return {
      id: outboxId,
      status: 'posted',
      attempts,
      ledgerRowCount: Array.isArray(ledgerRows) ? ledgerRows.length : 0,
    };
  } catch (err) {
    const terminal = attempts >= maxAttempts;
    const errMsg = serializeError(err);

    const latest = await new Parse.Query('SettlementOutbox').get(outboxId, { useMasterKey: true });
    if (String(latest.get('lockToken') || '') === lockToken) {
      latest.set('status', terminal ? 'failed' : 'pending');
      latest.set('lastError', errMsg);
      latest.set('failedAt', nowDate());
      if (!terminal) {
        latest.set('nextRetryAt', computeNextRetryAt(attempts));
      }
      latest.unset('lockToken');
      latest.unset('leaseUntil');
      await latest.save(null, { useMasterKey: true });
    }

    if (terminal) {
      audit.error('settlement.outbox.process.terminal', {
        outboxId,
        attempts,
        maxAttempts,
        error: errMsg,
        message: 'SettlementOutbox row failed permanently',
      });
    } else {
      audit.warn('settlement.outbox.process.reschedule', {
        outboxId,
        attempts,
        maxAttempts,
        error: errMsg,
        message: 'SettlementOutbox row rescheduled',
      });
    }

    return {
      id: outboxId,
      status: terminal ? 'failed' : 'pending',
      attempts,
      error: errMsg,
    };
  }
}

async function processDueSettlementOutbox({ limit = 25 } = {}) {
  const effectiveLimit = Math.max(1, Math.min(200, Number(limit) || 25));
  const now = nowDate();

  const pendingRows = await new Parse.Query('SettlementOutbox')
    .equalTo('kind', OUTBOX_KIND)
    .equalTo('status', 'pending')
    .lessThanOrEqualTo('nextRetryAt', now)
    .ascending('nextRetryAt')
    .limit(effectiveLimit * 2)
    .find({ useMasterKey: true });

  const staleProcessing = await new Parse.Query('SettlementOutbox')
    .equalTo('kind', OUTBOX_KIND)
    .equalTo('status', 'processing')
    .lessThanOrEqualTo('leaseUntil', now)
    .ascending('updatedAt')
    .limit(effectiveLimit * 2)
    .find({ useMasterKey: true });

  const dueRows = [...pendingRows, ...staleProcessing].slice(0, effectiveLimit * 2);
  const results = [];

  for (const row of dueRows) {
    // eslint-disable-next-line no-await-in-loop
    const claimed = await claimSettlementOutboxRow(row.id);
    if (!claimed) continue;
    // eslint-disable-next-line no-await-in-loop
    const result = await processSingleSettlementOutboxRow(claimed);
    results.push(result);
    if (results.length >= effectiveLimit) break;
  }

  if (results.length > 0) {
    audit.info('settlement.outbox.batch', {
      processed: results.length,
      outboxIds: results.map((r) => r.id).filter(Boolean),
      message: 'Settlement GL outbox batch finished',
    });
  }

  return { processed: results.length, results };
}

async function getSettlementOutboxStatus({ sampleLimit = 25 } = {}) {
  const counts = {};
  for (const status of ['pending', 'processing', 'posted', 'failed']) {
    // eslint-disable-next-line no-await-in-loop
    counts[status] = await new Parse.Query('SettlementOutbox')
      .equalTo('kind', OUTBOX_KIND)
      .equalTo('status', status)
      .count({ useMasterKey: true });
  }

  const samples = await new Parse.Query('SettlementOutbox')
    .equalTo('kind', OUTBOX_KIND)
    .containedIn('status', ['pending', 'processing', 'failed'])
    .ascending('nextRetryAt')
    .descending('updatedAt')
    .limit(Math.max(1, Math.min(100, Number(sampleLimit) || 25)))
    .find({ useMasterKey: true });

  return {
    kind: OUTBOX_KIND,
    enabled: await isSettlementGLOutboxEnabled(),
    counts,
    samples: samples.map((row) => ({
      id: row.id,
      idempotencyKey: row.get('idempotencyKey') || null,
      tradeId: row.get('tradeId') || null,
      entryType: row.get('entryType') || null,
      accountStatementId: row.get('accountStatementId') || null,
      status: row.get('status') || null,
      attempts: Number(row.get('attempts') || 0),
      maxAttempts: Number(row.get('maxAttempts') || DEFAULT_MAX_ATTEMPTS),
      nextRetryAt: row.get('nextRetryAt') ? new Date(row.get('nextRetryAt')).toISOString() : null,
      lastError: row.get('lastError') || null,
      updatedAt: row.updatedAt ? row.updatedAt.toISOString() : null,
    })),
  };
}

module.exports = {
  OUTBOX_KIND,
  isSettlementGLOutboxEnabled,
  buildSettlementGLOutboxIdempotencyKey,
  saveAccountStatementWithOutbox,
  postSettlementGLFromOutbox,
  processDueSettlementOutbox,
  getSettlementOutboxStatus,
};
