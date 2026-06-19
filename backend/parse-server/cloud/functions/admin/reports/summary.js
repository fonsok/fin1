'use strict';

const { registerSummaryReportFunctions } = require('./summaryReportRegister');
const {
  mapInvestmentRow,
  loadCanonicalReturnByInvestmentId,
} = require('./summaryReportInvestmentRows');
const {
  resolveInvestmentDisplayAmount,
  resolveInvestmentPositionAmountFromFields,
  resolveInvestmentPositionAmount,
} = require('../../../utils/investmentDisplayAmount');
const {
  mapTradeRow,
  loadDistinctInvestorIdsByTradeId,
} = require('./summaryReportTradeRows');

module.exports = {
  registerSummaryReportFunctions,
  __test__: {
    mapInvestmentRow,
    loadCanonicalReturnByInvestmentId,
    resolveInvestmentDisplayAmount,
    resolveInvestmentPositionAmountFromFields,
    resolveInvestmentPositionAmount,
    mapTradeRow,
    loadDistinctInvestorIdsByTradeId,
  },
};
