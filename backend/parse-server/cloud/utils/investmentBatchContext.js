'use strict';

/**
 * In-process marker: createInvestmentSplits validated pool-mirror cap for the
 * full batch sum — beforeSave can skip per-split cap queries for the same batch.
 */
const validatedBatchKeys = new Map();
const TTL_MS = 5 * 60 * 1000;

function batchKey(investorId, batchId) {
  return `${String(investorId || '').trim()}:${String(batchId || '').trim()}`;
}

function markBatchPoolCapValidated(investorId, batchId) {
  const key = batchKey(investorId, batchId);
  if (!key || key === ':') return;
  validatedBatchKeys.set(key, Date.now());
}

function isBatchPoolCapValidated(investorId, batchId) {
  const key = batchKey(investorId, batchId);
  const at = validatedBatchKeys.get(key);
  if (!at) return false;
  if (Date.now() - at > TTL_MS) {
    validatedBatchKeys.delete(key);
    return false;
  }
  return true;
}

function clearBatchPoolCapValidated(investorId, batchId) {
  validatedBatchKeys.delete(batchKey(investorId, batchId));
}

module.exports = {
  markBatchPoolCapValidated,
  isBatchPoolCapValidated,
  clearBatchPoolCapValidated,
};
