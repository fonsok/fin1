'use strict';

const { requirePermission, requireAdminRole } = require('../../utils/permissions');
const { handleGetFinancialDashboard } = require('./financialGetFinancialDashboard');
const {
  handleGetRoundingDifferences,
  handleCreateCorrectionRequest,
  handleGetCorrectionRequests,
} = require('./financialRoundingAndCorrections');
const {
  handleRepairTradeSettlement,
  handleBackfillTradeSettlement,
  handleBackfillTradingResidualEscrow,
  handleEnsureCapitalSplitOnActivation,
} = require('./financialSettlementRepair');
const {
  handleRunSettlementRetryQueue,
  handleGetSettlementRetryQueueStatus,
} = require('./financialSettlementRetryQueue');
const { handleReconcileStaleSettlementRetryJobs } = require('./financialSettlementRetryRepair');
const { handleCleanupLegacyDocumentsAllUsers } = require('./financialCleanupLegacyDocuments');
const { handleReconcileAccountStatementDocumentReferences } = require('./financialReconcileStatementRefs');
const { handleVerifyAccountStatementChain } = require('./financialVerifyAccountStatementChain');
const { handleBackfillUserCashBalanceFromStatements } = require('./financialUserCashBalanceBackfill');
const { handleBackfillTraderCollectionBillBeleg } = require('./financialTraderCollectionBillBelegBackfill');
const { handleBackfillPoolMirrorExecutionEigenbeleg } = require('./financialPoolMirrorExecutionEigenbelegBackfill');
const { handleBackfillTradeSummaryFlags } = require('./financialBackfillTradeSummaryFlags');

Parse.Cloud.define('getFinancialDashboard', async (request) => {
  requirePermission(request, 'getFinancialDashboard');
  return handleGetFinancialDashboard(request);
});

Parse.Cloud.define('getRoundingDifferences', async (request) => {
  requirePermission(request, 'getRoundingDifferences');
  return handleGetRoundingDifferences(request);
});

Parse.Cloud.define('createCorrectionRequest', async (request) => {
  requirePermission(request, 'createCorrectionRequest');
  return handleCreateCorrectionRequest(request);
});

Parse.Cloud.define('getCorrectionRequests', async (request) => {
  requirePermission(request, 'getCorrectionRequests');
  return handleGetCorrectionRequests(request);
});

Parse.Cloud.define('repairTradeSettlement', async (request) => {
  if (!request.master) {
    requireAdminRole(request);
  }
  return handleRepairTradeSettlement(request);
});

Parse.Cloud.define('backfillTradeSettlement', async (request) => {
  if (!request.master) {
    requireAdminRole(request);
  }
  return handleBackfillTradeSettlement(request);
});

Parse.Cloud.define('backfillTradingResidualEscrow', async (request) => {
  if (!request.master) {
    requireAdminRole(request);
  }
  return handleBackfillTradingResidualEscrow(request);
});

Parse.Cloud.define('ensureCapitalSplitOnActivation', async (request) => {
  if (!request.master) {
    requireAdminRole(request);
  }
  return handleEnsureCapitalSplitOnActivation(request);
});

Parse.Cloud.define('runSettlementRetryQueue', async (request) => {
  if (!request.master) {
    requireAdminRole(request);
  }
  return handleRunSettlementRetryQueue(request);
});

Parse.Cloud.define('getSettlementRetryQueueStatus', async (request) => {
  if (!request.master) {
    requireAdminRole(request);
  }
  return handleGetSettlementRetryQueueStatus(request);
});

Parse.Cloud.define('reconcileStaleSettlementRetryJobs', async (request) => {
  if (!request.master) {
    requireAdminRole(request);
  }
  return handleReconcileStaleSettlementRetryJobs(request);
});

Parse.Cloud.define('cleanupLegacyDocumentsAllUsers', async (request) => {
  if (!request.master) {
    requireAdminRole(request);
  }
  return handleCleanupLegacyDocumentsAllUsers(request);
});

Parse.Cloud.define('reconcileAccountStatementDocumentReferences', async (request) => {
  if (!request.master) {
    requireAdminRole(request);
  }
  return handleReconcileAccountStatementDocumentReferences(request);
});

Parse.Cloud.define('verifyAccountStatementChain', async (request) => {
  if (!request.master) {
    requireAdminRole(request);
  }
  return handleVerifyAccountStatementChain(request);
});

Parse.Cloud.define('backfillUserCashBalanceFromStatements', async (request) => {
  if (!request.master) {
    requireAdminRole(request);
  }
  return handleBackfillUserCashBalanceFromStatements(request);
});

Parse.Cloud.define('backfillTraderCollectionBillBeleg', async (request) => {
  if (!request.master) {
    requireAdminRole(request);
  }
  return handleBackfillTraderCollectionBillBeleg(request);
});

Parse.Cloud.define('backfillPoolMirrorExecutionEigenbeleg', async (request) => {
  if (!request.master) {
    requireAdminRole(request);
  }
  return handleBackfillPoolMirrorExecutionEigenbeleg(request);
});

Parse.Cloud.define('backfillTradeSummaryFlags', async (request) => {
  if (!request.master) {
    requireAdminRole(request);
  }
  return handleBackfillTradeSummaryFlags(request);
});
