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
} = require('./financialSettlementRepair');
const {
  handleRunSettlementRetryQueue,
  handleGetSettlementRetryQueueStatus,
} = require('./financialSettlementRetryQueue');
const { handleCleanupLegacyDocumentsAllUsers } = require('./financialCleanupLegacyDocuments');
const { handleReconcileAccountStatementDocumentReferences } = require('./financialReconcileStatementRefs');

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
