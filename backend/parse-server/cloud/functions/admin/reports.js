'use strict';

const { registerSummaryReportFunctions } = require('./reports/summary');
const { registerBankContraReportFunctions } = require('./reports/bankContra');
const { registerAppLedgerReportFunctions } = require('./reports/appLedger');
const { registerAuditorExportFunctions } = require('./reports/auditorExport');
const { registerFinancialReconciliationFunctions } = require('./reports/financialReconciliation');
const { registerSearchDocumentsFunctions } = require('./reports/searchDocuments');

registerSummaryReportFunctions();
registerBankContraReportFunctions();
registerAppLedgerReportFunctions();
registerAuditorExportFunctions();
registerFinancialReconciliationFunctions();
registerSearchDocumentsFunctions();

console.log('Admin reports cloud functions loaded');
