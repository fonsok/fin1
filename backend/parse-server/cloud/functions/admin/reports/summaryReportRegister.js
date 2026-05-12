'use strict';

const { requirePermission } = require('../../../utils/permissions');
const { getTraderCommissionRate } = require('../../../utils/configHelper/index.js');
const { applyQuerySort } = require('../../../utils/applyQuerySort');

const { MAX_PAGE_SIZE } = require('./summaryReportConstants');
const {
  buildInvestmentMatch,
  buildTradeMatch,
  applyInvestmentQueryFilters,
  applyTradeQueryFilters,
} = require('./summaryReportQueryHelpers');
const {
  investmentAggPipeline,
  tradeAggPipeline,
  firstAggRow,
} = require('./summaryReportAggPipelines');
const {
  mapInvestmentRow,
  loadCanonicalReturnByInvestmentId,
} = require('./summaryReportInvestmentRows');
const {
  mapTradeRow,
  loadDistinctInvestorIdsByTradeId,
} = require('./summaryReportTradeRows');

async function handleGetSummaryReport(request) {
  const { dateFrom, dateTo, investorId, traderId } = request.params || {};
  const filters = { dateFrom, dateTo, investorId, traderId };
  const commissionRate = await getTraderCommissionRate();

  const invMatch = buildInvestmentMatch(filters);
  const tradeMatch = buildTradeMatch(filters);

  const invQuery = new Parse.Query('Investment');
  applyInvestmentQueryFilters(invQuery, filters);

  const tradeQuery = new Parse.Query('Trade');
  applyTradeQueryFilters(tradeQuery, filters);

  const invPipeline = investmentAggPipeline(invMatch);
  const tradePipeline = tradeAggPipeline(tradeMatch);

  const [totalInvestments, totalTrades, invAggRows, tradeAggRows] = await Promise.all([
    invQuery.count({ useMasterKey: true }),
    tradeQuery.count({ useMasterKey: true }),
    new Parse.Query('Investment').aggregate(invPipeline, { useMasterKey: true }),
    new Parse.Query('Trade').aggregate(tradePipeline, { useMasterKey: true }),
  ]);

  const invAgg = firstAggRow(invAggRows);
  const tradeAgg = firstAggRow(tradeAggRows);

  const totalInvestedAmount = Number(invAgg.totalInvestedAmount) || 0;
  const totalCurrentValue = Number(invAgg.totalCurrentValue) || 0;
  const totalGrossProfit = Number(invAgg.totalGrossProfit) || 0;
  const positiveGrossSum = Number(invAgg.positiveGrossSum) || 0;
  const totalCommission = positiveGrossSum * commissionRate;

  const totalTradeVolume = Number(tradeAgg.totalTradeVolume) || 0;
  const totalTradeProfit = Number(tradeAgg.totalTradeProfit) || 0;

  return {
    summary: {
      totalInvestments,
      totalTrades,
      totalInvestedAmount,
      totalCurrentValue,
      totalGrossProfit,
      totalCommission,
      totalTradeVolume,
      totalTradeProfit,
      netReturn:
        totalInvestedAmount > 0
          ? ((totalCurrentValue - totalInvestedAmount) / totalInvestedAmount) * 100
          : 0,
      commissionRate,
    },
    generatedAt: new Date().toISOString(),
  };
}

async function handleGetSummaryReportInvestmentsPage(request) {
  const {
    dateFrom,
    dateTo,
    investorId,
    traderId,
    page: pageRaw,
    pageSize: pageSizeRaw,
  } = request.params || {};
  const page = Math.max(0, parseInt(pageRaw, 10) || 0);
  const pageSize = Math.min(MAX_PAGE_SIZE, Math.max(1, parseInt(pageSizeRaw, 10) || 25));
  const filters = { dateFrom, dateTo, investorId, traderId };

  const commissionRate = await getTraderCommissionRate();

  const base = new Parse.Query('Investment');
  applyInvestmentQueryFilters(base, filters);

  const total = await base.count({ useMasterKey: true });

  const pageQuery = new Parse.Query('Investment');
  applyInvestmentQueryFilters(pageQuery, filters);
  applyQuerySort(pageQuery, request.params || {}, {
    allowed: ['createdAt', 'amount'],
    defaultField: 'createdAt',
    defaultDesc: true,
  });
  pageQuery.skip(page * pageSize);
  pageQuery.limit(pageSize);

  const rows = await pageQuery.find({ useMasterKey: true });
  const canonicalReturnMap = await loadCanonicalReturnByInvestmentId(rows.map((r) => r.id));
  const items = rows.map((inv) => mapInvestmentRow(inv, commissionRate, canonicalReturnMap));

  return { items, total, page, pageSize };
}

async function handleGetSummaryReportTradesPage(request) {
  const {
    dateFrom,
    dateTo,
    traderId,
    page: pageRaw,
    pageSize: pageSizeRaw,
  } = request.params || {};
  const page = Math.max(0, parseInt(pageRaw, 10) || 0);
  const pageSize = Math.min(MAX_PAGE_SIZE, Math.max(1, parseInt(pageSizeRaw, 10) || 25));
  const filters = { dateFrom, dateTo, traderId };

  const base = new Parse.Query('Trade');
  applyTradeQueryFilters(base, filters);

  const total = await base.count({ useMasterKey: true });

  const pageQuery = new Parse.Query('Trade');
  applyTradeQueryFilters(pageQuery, filters);
  applyQuerySort(pageQuery, request.params || {}, {
    allowed: ['createdAt', 'tradeNumber'],
    defaultField: 'createdAt',
    defaultDesc: true,
  });
  pageQuery.skip(page * pageSize);
  pageQuery.limit(pageSize);

  const rows = await pageQuery.find({ useMasterKey: true });
  const poolInvestorsByTrade = await loadDistinctInvestorIdsByTradeId(rows);
  const items = rows.map((t) => mapTradeRow(t, poolInvestorsByTrade.get(t.id)));

  return { items, total, page, pageSize };
}

function registerSummaryReportFunctions() {
  Parse.Cloud.define('getSummaryReport', async (request) => {
    requirePermission(request, 'getFinancialDashboard');
    return handleGetSummaryReport(request);
  });

  Parse.Cloud.define('getSummaryReportInvestmentsPage', async (request) => {
    requirePermission(request, 'getFinancialDashboard');
    return handleGetSummaryReportInvestmentsPage(request);
  });

  Parse.Cloud.define('getSummaryReportTradesPage', async (request) => {
    requirePermission(request, 'getFinancialDashboard');
    return handleGetSummaryReportTradesPage(request);
  });
}

module.exports = {
  registerSummaryReportFunctions,
};
