'use strict';

/** Pre-execution order statuses that may be cancelled together (paired or single). */
const CANCELLABLE_STATUSES = new Set(['pending', 'submitted', 'suspended']);

const PAIRED_STATUS_BATCH_CONTEXT_KEY = 'pairedStatusBatch';

function normalizeStatus(status) {
  return String(status || '').toLowerCase().trim();
}

function isCancellableStatus(status) {
  return CANCELLABLE_STATUSES.has(normalizeStatus(status));
}

/** Parse save context: skip single-leg beforeSave guards during coupled saveAll/sequential saves. */
function pairedStatusBatchContext() {
  return { [PAIRED_STATUS_BATCH_CONTEXT_KEY]: true };
}

module.exports = {
  CANCELLABLE_STATUSES,
  PAIRED_STATUS_BATCH_CONTEXT_KEY,
  normalizeStatus,
  isCancellableStatus,
  pairedStatusBatchContext,
};
