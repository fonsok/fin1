'use strict';

const { requirePermission } = require('../../../utils/permissions');
const {
  FULL_APP_ACCOUNTS,
  getLedgerAccountMappings,
} = require('./shared');
const { buildMappingValidationReport } = require('../../../utils/accountingHelper/accountMappingResolver');
const { handleGetAppLedger } = require('./getAppLedgerHandler');

function registerAppLedgerReportFunctions() {
  Parse.Cloud.define('getLedgerAccountMappings', async (request) => {
    requirePermission(request, 'getFinancialDashboard');
    const { chartCode } = request.params || {};
    const rows = getLedgerAccountMappings();
    return {
      mappings: chartCode ? rows.filter((row) => row.chartCode === chartCode) : rows,
      total: chartCode ? rows.filter((row) => row.chartCode === chartCode).length : rows.length,
    };
  });

  Parse.Cloud.define('getAppLedger', async (request) => {
    requirePermission(request, 'getFinancialDashboard');
    return handleGetAppLedger(request);
  });

  Parse.Cloud.define('getLedgerMappingValidationReport', async (request) => {
    requirePermission(request, 'getFinancialDashboard');
    const report = buildMappingValidationReport(FULL_APP_ACCOUNTS.map((a) => a.code));
    return report;
  });
}

module.exports = { registerAppLedgerReportFunctions };
