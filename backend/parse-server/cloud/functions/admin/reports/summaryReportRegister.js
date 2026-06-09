'use strict';

const { requirePermission } = require('../../../utils/permissions');
const { getTraderCommissionRate, loadConfig } = require('../../../utils/configHelper/index.js');
const { MAX_PAGE_SIZE } = require('./summaryReportConstants');
const {
  buildInvestmentMatch,
  buildTradeMatch,
  applyInvestmentQueryFilters,
  applyTradeQueryFilters,
} = require('./summaryReportQueryHelpers');
const { fetchInvestmentsPage, fetchTradesPage } = require('./summaryReportPagedList');
const {
  handleGetAdminListSearchHealth,
  handleEnsureAdminListSearchIndexes,
} = require('./adminListSearchHealth');
const {
  normalizeInvestmentListFilters,
  normalizeTradeListFilters,
} = require('./summaryReportFilterHelpers');
const { enrichTradeListFiltersForSearch } = require('./summaryReportTraderSearch');
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
  loadTraderDisplayNamesForTrades,
} = require('./summaryReportTradeRows');
const {
  enrichSummaryReportTrades,
  attachPartialSellEventsToSummaryRows,
  resolvePairedLegContextsByTradeId,
} = require('./summaryReportTradePoolEnrichment');

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
  const { page: pageRaw, pageSize: pageSizeRaw } = request.params || {};
  const page = Math.max(0, parseInt(pageRaw, 10) || 0);
  const pageSize = Math.min(MAX_PAGE_SIZE, Math.max(1, parseInt(pageSizeRaw, 10) || 25));
  const filters = normalizeInvestmentListFilters(request.params);

  const commissionRate = await getTraderCommissionRate();

  const pageResult = await fetchInvestmentsPage(
    filters,
    request.params || {},
    page,
    pageSize,
  );
  const { total, rows, searchMode } = pageResult;
  const canonicalReturnMap = await loadCanonicalReturnByInvestmentId(rows.map((r) => r.id));
  const items = rows.map((inv) => mapInvestmentRow(inv, commissionRate, canonicalReturnMap));

  return { items, total, page, pageSize, searchMode: searchMode || 'none' };
}

async function handleGetSummaryReportTradesPage(request) {
  const { page: pageRaw, pageSize: pageSizeRaw } = request.params || {};
  const page = Math.max(0, parseInt(pageRaw, 10) || 0);
  const pageSize = Math.min(MAX_PAGE_SIZE, Math.max(1, parseInt(pageSizeRaw, 10) || 25));
  const config = await loadConfig();
  const feeConfig = config.financial || {};
  const filters = await enrichTradeListFiltersForSearch(
    normalizeTradeListFilters(request.params),
  );
  filters.feeConfig = feeConfig;

  const pageResult = await fetchTradesPage(
    filters,
    request.params || {},
    page,
    pageSize,
  );
  const { total, rows, searchMode } = pageResult;
  const poolInvestorsByTrade = await loadDistinctInvestorIdsByTradeId(rows);
  const traderNamesById = await loadTraderDisplayNamesForTrades(rows);
  const baseItems = rows.map((t) => {
    const traderId = t.get('traderId') || '';
    return mapTradeRow(
      t,
      poolInvestorsByTrade.get(t.id),
      traderNamesById.get(traderId),
      feeConfig,
    );
  });
  const pairedLegContexts = await resolvePairedLegContextsByTradeId(rows);
  let items = await enrichSummaryReportTrades(rows, baseItems, { pairedLegContexts });
  items = await attachPartialSellEventsToSummaryRows(items, rows);

  return { items, total, page, pageSize, searchMode: searchMode || 'none' };
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

  Parse.Cloud.define('getAdminListSearchHealth', async (request) => {
    return handleGetAdminListSearchHealth(request);
  });

  Parse.Cloud.define('ensureAdminListSearchIndexes', async (request) => {
    return handleEnsureAdminListSearchIndexes(request);
  });
}

module.exports = {
  registerSummaryReportFunctions,
};
