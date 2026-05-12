'use strict';

const { registerSummaryReportFunctions } = require('./summaryReportRegister');
const {
  mapInvestmentRow,
  loadCanonicalReturnByInvestmentId,
} = require('./summaryReportInvestmentRows');
const {
  mapTradeRow,
  loadDistinctInvestorIdsByTradeId,
} = require('./summaryReportTradeRows');

module.exports = {
  registerSummaryReportFunctions,
  __test__: {
    mapInvestmentRow,
    loadCanonicalReturnByInvestmentId,
    mapTradeRow,
    loadDistinctInvestorIdsByTradeId,
  },
};
