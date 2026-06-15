'use strict';

const {
  processDueSettlementOutbox,
  getSettlementOutboxStatus,
  postSettlementGLFromOutbox,
} = require('../../utils/accountingHelper/settlementOutbox');
const { logPermissionCheck } = require('../../utils/permissions');

async function handleRunSettlementGLOutbox(request) {
  const limit = Number(request.params?.limit || 25);
  const result = await processDueSettlementOutbox({ limit });

  if (!request.master) {
    await logPermissionCheck(request, 'runSettlementGLOutbox', 'SettlementOutbox', 'due');
  }

  return {
    success: true,
    processed: result.processed,
    results: result.results,
    ranAt: new Date().toISOString(),
  };
}

async function handleGetSettlementGLOutboxStatus(request) {
  const sampleLimit = Number(request.params?.sampleLimit || 25);
  const status = await getSettlementOutboxStatus({ sampleLimit });
  return {
    ...status,
    checkedAt: new Date().toISOString(),
  };
}

async function handlePostSettlementGLFromOutbox(request) {
  const outboxId = String(request.params?.outboxId || '').trim();
  if (!outboxId) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'outboxId required');
  }

  if (!request.master) {
    await logPermissionCheck(request, 'executeSettlementGLFromOutbox', 'SettlementOutbox', outboxId);
  }

  const row = await new Parse.Query('SettlementOutbox').get(outboxId, { useMasterKey: true });
  const ledgerRows = await postSettlementGLFromOutbox(row);

  row.set('status', 'posted');
  row.set('postedAt', new Date());
  row.set('ledgerRowCount', Array.isArray(ledgerRows) ? ledgerRows.length : 0);
  row.unset('lockToken');
  row.unset('leaseUntil');
  await row.save(null, { useMasterKey: true });

  return {
    success: true,
    outboxId,
    ledgerRowCount: Array.isArray(ledgerRows) ? ledgerRows.length : 0,
    postedAt: new Date().toISOString(),
  };
}

module.exports = {
  handleRunSettlementGLOutbox,
  handleGetSettlementGLOutboxStatus,
  handlePostSettlementGLFromOutbox,
};
