'use strict';

const {
  buildInvestmentSearchQuery,
  buildTradeSearchQuery,
  buildTradeProfitSignQuery,
  buildTradeSellProgressQuery,
  buildTradeHasPoolInvestorsQuery,
  combineQueries,
} = require('./summaryReportFilterHelpers');

function parseDateParam(v) {
  if (v == null || v === '') return null;
  const d = v instanceof Date ? v : new Date(v);
  return Number.isNaN(d.getTime()) ? null : d;
}

function buildInvestmentMatch({ dateFrom, dateTo, investorId, traderId, status, returnSign }) {
  const match = {};
  if (dateFrom || dateTo) {
    match.createdAt = {};
    if (dateFrom) match.createdAt.$gte = parseDateParam(dateFrom);
    if (dateTo) match.createdAt.$lte = parseDateParam(dateTo);
  }
  if (investorId) match.investorId = investorId;
  if (traderId) match.traderId = traderId;
  if (status) match.status = status;
  return match;
}

function buildTradeMatch({
  dateFrom,
  dateTo,
  traderId,
  status,
  profitSign,
  sellProgress,
}) {
  const match = {};
  if (dateFrom || dateTo) {
    match.createdAt = {};
    if (dateFrom) match.createdAt.$gte = parseDateParam(dateFrom);
    if (dateTo) match.createdAt.$lte = parseDateParam(dateTo);
  }
  if (traderId) match.traderId = traderId;
  if (status) match.status = status;
  if (sellProgress === 'full') match.status = 'completed';
  else if (sellProgress === 'partial') match.status = 'partial';
  else if (sellProgress === 'none') {
    match.$or = [
      { soldQuantity: 0 },
      { soldQuantity: { $exists: false } },
      { status: 'active' },
    ];
  }
  if (profitSign === 'positive') {
    match.$or = [
      ...(match.$or || []),
      { grossProfit: { $gt: 0 } },
      { calculatedProfit: { $gt: 0 } },
    ];
  }
  return match;
}

function applyInvestmentQueryFilters(query, filters) {
  const { dateFrom, dateTo, investorId, traderId, status, returnSign } = filters;
  const from = parseDateParam(dateFrom);
  const to = parseDateParam(dateTo);
  if (from) query.greaterThanOrEqualTo('createdAt', from);
  if (to) query.lessThanOrEqualTo('createdAt', to);
  if (investorId) query.equalTo('investorId', investorId);
  if (traderId) query.equalTo('traderId', traderId);
  if (status) query.equalTo('status', status);
  // returnSign filtering uses aggregate ($expr currentValue vs amount) in summaryReportPagedList.
}

function applyTradeQueryFilters(query, filters) {
  const { dateFrom, dateTo, traderId, status } = filters;
  const from = parseDateParam(dateFrom);
  const to = parseDateParam(dateTo);
  if (from) query.greaterThanOrEqualTo('createdAt', from);
  if (to) query.lessThanOrEqualTo('createdAt', to);
  if (traderId) query.equalTo('traderId', traderId);
  if (status) query.equalTo('status', status);
}

function buildFilteredInvestmentQuery(filters) {
  const base = new Parse.Query('Investment');
  applyInvestmentQueryFilters(base, filters);
  const searchQ = buildInvestmentSearchQuery(filters.search);
  return combineQueries([base, searchQ]);
}

function buildFilteredTradeQuery(filters) {
  const base = new Parse.Query('Trade');
  applyTradeQueryFilters(base, filters);
  const extra = [
    buildTradeSearchQuery(filters.search),
    buildTradeProfitSignQuery(filters.profitSign),
    buildTradeSellProgressQuery(filters.sellProgress),
    buildTradeHasPoolInvestorsQuery(filters.hasPoolInvestors),
  ];
  return combineQueries([base, ...extra]);
}

module.exports = {
  parseDateParam,
  buildInvestmentMatch,
  buildTradeMatch,
  applyInvestmentQueryFilters,
  applyTradeQueryFilters,
  buildFilteredInvestmentQuery,
  buildFilteredTradeQuery,
};
