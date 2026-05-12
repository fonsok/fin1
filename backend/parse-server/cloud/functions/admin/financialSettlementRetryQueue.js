'use strict';

const {
  processDueSettlementRetries,
  getSettlementRetryQueueStatus,
} = require('../../utils/accountingHelper/retryQueue');
const { logPermissionCheck } = require('../../utils/permissions');

async function handleRunSettlementRetryQueue(request) {
  const limit = Number(request.params?.limit || 20);
  const result = await processDueSettlementRetries({ limit });

  if (!request.master) {
    await logPermissionCheck(request, 'runSettlementRetryQueue', 'SettlementRetryJob', 'due');
  }

  return {
    success: true,
    processed: result.processed,
    results: result.results,
    ranAt: new Date().toISOString(),
  };
}

async function handleGetSettlementRetryQueueStatus(request) {
  const sampleLimit = Number(request.params?.sampleLimit || 25);
  const status = await getSettlementRetryQueueStatus({ sampleLimit });
  return {
    ...status,
    checkedAt: new Date().toISOString(),
  };
}

module.exports = {
  handleRunSettlementRetryQueue,
  handleGetSettlementRetryQueueStatus,
};
