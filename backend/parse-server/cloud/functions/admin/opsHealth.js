'use strict';

const { requireAdminRole } = require('../../utils/permissions');
const { handleGetMirrorBasisDriftStatus } = require('./opsHealthMirrorBasisDrift');
const { handleGetTradeSettlementConsistencyStatus } = require('./opsHealthTradeSettlementConsistency');
const { handleRunFinanceConsistencySmoke } = require('./opsHealthFinanceSmoke');
const {
  handleBenchmarkTradeSettlementConsistency,
  handleBenchmarkTradeSettlementConsistencySynthetic,
} = require('./opsHealthBenchmarkSettlement');

// ============================================================================
// Admin observability: mirror-basis drift, settlement consistency, finance smokes.
// See module headers under opsHealth*.js for behaviour notes.
// ============================================================================

function ensureAdminOrMaster(request) {
  if (!request.master) {
    requireAdminRole(request);
  }
}

Parse.Cloud.define('getMirrorBasisDriftStatus', async (request) => {
  ensureAdminOrMaster(request);
  return handleGetMirrorBasisDriftStatus(request);
});

Parse.Cloud.define('getTradeSettlementConsistencyStatus', async (request) => {
  ensureAdminOrMaster(request);
  return handleGetTradeSettlementConsistencyStatus(request);
});

Parse.Cloud.define('runFinanceConsistencySmoke', async (request) => {
  ensureAdminOrMaster(request);
  return handleRunFinanceConsistencySmoke(request);
});

Parse.Cloud.define('benchmarkTradeSettlementConsistency', async (request) => {
  ensureAdminOrMaster(request);
  return handleBenchmarkTradeSettlementConsistency(request);
});

Parse.Cloud.define('benchmarkTradeSettlementConsistencySynthetic', async (request) => {
  ensureAdminOrMaster(request);
  return handleBenchmarkTradeSettlementConsistencySynthetic(request);
});
