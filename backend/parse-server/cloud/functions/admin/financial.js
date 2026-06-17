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
  handleBackfillMissingSettlementGL,
  handleRepairPartialSellEscrow,
} = require('./financialSettlementRepair');
const {
  handleRunSettlementRetryQueue,
  handleGetSettlementRetryQueueStatus,
} = require('./financialSettlementRetryQueue');
const {
  handleRunSettlementGLOutbox,
  handleGetSettlementGLOutboxStatus,
  handlePostSettlementGLFromOutbox,
} = require('./financialSettlementGLOutbox');
const { handleReconcileStaleSettlementRetryJobs } = require('./financialSettlementRetryRepair');
const { handleCleanupLegacyDocumentsAllUsers } = require('./financialCleanupLegacyDocuments');
const { handleReconcileAccountStatementDocumentReferences } = require('./financialReconcileStatementRefs');
const { handleVerifyAccountStatementChain } = require('./financialVerifyAccountStatementChain');
const { handleBackfillUserCashBalanceFromStatements } = require('./financialUserCashBalanceBackfill');
const { handleInspectUserCashBalanceDrift } = require('./financialUserCashBalanceDrift');
const { handleInspectAccountStatementCentAlignment } = require('./financialAccountStatementCentAlignment');
const { handleBackfillTraderCollectionBillBeleg } = require('./financialTraderCollectionBillBelegBackfill');
const { handleInspectTraderCollectionBillBelegDrift } = require('./financialTraderCollectionBillBelegDrift');
const { handleBackfillPoolMirrorExecutionEigenbeleg } = require('./financialPoolMirrorExecutionEigenbelegBackfill');
const { handleBackfillAppCommissionEigenbeleg } = require('./financialAppCommissionEigenbelegBackfill');
const { handleRepairMirrorPoolBuyQuantity } = require('./financialMirrorPoolBuyQuantityRepair');
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

Parse.Cloud.define('backfillMissingSettlementGL', async (request) => {
  if (!request.master) {
    requireAdminRole(request);
  }
  return handleBackfillMissingSettlementGL(request);
});

Parse.Cloud.define('repairPartialSellEscrow', async (request) => {
  if (!request.master) {
    requireAdminRole(request);
  }
  return handleRepairPartialSellEscrow(request);
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

Parse.Cloud.define('runSettlementGLOutbox', async (request) => {
  if (!request.master) {
    requireAdminRole(request);
  }
  return handleRunSettlementGLOutbox(request);
});

Parse.Cloud.define('getSettlementGLOutboxStatus', async (request) => {
  if (!request.master) {
    requireAdminRole(request);
  }
  return handleGetSettlementGLOutboxStatus(request);
});

Parse.Cloud.define('executeSettlementGLFromOutbox', async (request) => {
  if (!request.master) {
    requireAdminRole(request);
  }
  return handlePostSettlementGLFromOutbox(request);
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

Parse.Cloud.define('checkUserCashBalanceDrift', async (request) => {
  if (!request.master) {
    requireAdminRole(request);
  }
  return handleInspectUserCashBalanceDrift(request);
});

Parse.Cloud.define('checkAccountStatementCentAlignment', async (request) => {
  if (!request.master) {
    requireAdminRole(request);
  }
  return handleInspectAccountStatementCentAlignment(request);
});

Parse.Cloud.define('backfillTraderCollectionBillBeleg', async (request) => {
  if (!request.master) {
    requireAdminRole(request);
  }
  return handleBackfillTraderCollectionBillBeleg(request);
});

Parse.Cloud.define('checkTraderCollectionBillBelegDrift', async (request) => {
  if (!request.master) {
    requireAdminRole(request);
  }
  return handleInspectTraderCollectionBillBelegDrift(request);
});

Parse.Cloud.define('backfillPoolMirrorExecutionEigenbeleg', async (request) => {
  if (!request.master) {
    requireAdminRole(request);
  }
  return handleBackfillPoolMirrorExecutionEigenbeleg(request);
});

Parse.Cloud.define('backfillAppCommissionEigenbeleg', async (request) => {
  if (!request.master) {
    requireAdminRole(request);
  }
  return handleBackfillAppCommissionEigenbeleg(request);
});

Parse.Cloud.define('repairMirrorPoolBuyQuantity', async (request) => {
  if (!request.master) {
    requireAdminRole(request);
  }
  return handleRepairMirrorPoolBuyQuantity(request);
});

Parse.Cloud.define('backfillTradeSummaryFlags', async (request) => {
  if (!request.master) {
    requireAdminRole(request);
  }
  return handleBackfillTradeSummaryFlags(request);
});
