'use strict';

const { registerSummaryReportFunctions } = require('./reports/summary');
const { registerBankContraReportFunctions } = require('./reports/bankContra');
const { registerAppLedgerReportFunctions } = require('./reports/appLedger');

registerSummaryReportFunctions();
registerBankContraReportFunctions();
registerAppLedgerReportFunctions();

console.log('Admin reports cloud functions loaded');
