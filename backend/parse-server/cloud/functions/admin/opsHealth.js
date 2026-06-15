'use strict';

const { requireAdminRole } = require('../../utils/permissions');
const { handleGetMirrorBasisDriftStatus } = require('./opsHealthMirrorBasisDrift');
const { handleGetTradeSettlementConsistencyStatus } = require('./opsHealthTradeSettlementConsistency');
const { handleRunFinanceConsistencySmoke } = require('./opsHealthFinanceSmoke');
const {
  handleBenchmarkTradeSettlementConsistency,
  handleBenchmarkTradeSettlementConsistencySynthetic,
} = require('./opsHealthBenchmarkSettlement');
const { handleGetPairedBuyPoolIntegrityStatus } = require('./opsHealthPairedBuyPoolIntegrity');
const { handleGetTraderMirrorBookingIntegrityStatus } = require('./opsHealthTraderMirrorBookingIntegrity');
const { handleGetPairedOrderStatusIntegrityStatus } = require('./opsHealthPairedOrderStatusIntegrity');
const { handleGetTraderCashBookingDuplicatesStatus } = require('./opsHealthTraderCashBookingDuplicates');
const { handleGetFinanceIntegrityStatus } = require('./opsHealthFinanceIntegrity');
const { handleGetPairedSellInvestorChainStatus } = require('./opsHealthPairedSellInvestorChain');
const { handleGetFinanceIntegrityPreventionStatus } = require('./opsHealthFinancePrevention');
const { handleGetFinanceRepairCatalog } = require('./financeRepairCatalog');
const { handleGetTraderPoolBidAskContractStatus } = require('./opsHealthTraderPoolBidAskContract');
const { handleBenchmarkSummaryReportTradesPage } = require('./opsHealthSummaryReportBenchmark');
const { handleGetSettlementGLReconciliationStatus } = require('./opsHealthSettlementGLReconciliation');
const { handleGetTraderCollectionBillBelegDriftStatus } = require('./opsHealthTraderCollectionBillBelegDrift');

// ============================================================================
// Admin observability: closed finance integrity (snapshots + live guards).
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

Parse.Cloud.define('getPairedBuyPoolIntegrityStatus', async (request) => {
  ensureAdminOrMaster(request);
  return handleGetPairedBuyPoolIntegrityStatus(request);
});

Parse.Cloud.define('getTraderMirrorBookingIntegrityStatus', async (request) => {
  ensureAdminOrMaster(request);
  return handleGetTraderMirrorBookingIntegrityStatus(request);
});

Parse.Cloud.define('getPairedOrderStatusIntegrityStatus', async (request) => {
  ensureAdminOrMaster(request);
  return handleGetPairedOrderStatusIntegrityStatus(request);
});

Parse.Cloud.define('getTraderCashBookingDuplicatesStatus', async (request) => {
  ensureAdminOrMaster(request);
  return handleGetTraderCashBookingDuplicatesStatus(request);
});

Parse.Cloud.define('getFinanceIntegrityStatus', async (request) => {
  ensureAdminOrMaster(request);
  return handleGetFinanceIntegrityStatus(request);
});

Parse.Cloud.define('getPairedSellInvestorChainStatus', async (request) => {
  ensureAdminOrMaster(request);
  return handleGetPairedSellInvestorChainStatus(request);
});

Parse.Cloud.define('getFinanceIntegrityPreventionStatus', async (request) => {
  ensureAdminOrMaster(request);
  return handleGetFinanceIntegrityPreventionStatus(request);
});

Parse.Cloud.define('getFinanceRepairCatalog', async (request) => {
  ensureAdminOrMaster(request);
  return handleGetFinanceRepairCatalog(request);
});

Parse.Cloud.define('getTraderPoolBidAskContractStatus', async (request) => {
  ensureAdminOrMaster(request);
  return handleGetTraderPoolBidAskContractStatus(request);
});

Parse.Cloud.define('benchmarkSummaryReportTradesPage', async (request) => {
  ensureAdminOrMaster(request);
  return handleBenchmarkSummaryReportTradesPage(request);
});

Parse.Cloud.define('getSettlementGLReconciliationStatus', async (request) => {
  ensureAdminOrMaster(request);
  return handleGetSettlementGLReconciliationStatus(request);
});

Parse.Cloud.define('getTraderCollectionBillBelegDriftStatus', async (request) => {
  ensureAdminOrMaster(request);
  return handleGetTraderCollectionBillBelegDriftStatus(request);
});
