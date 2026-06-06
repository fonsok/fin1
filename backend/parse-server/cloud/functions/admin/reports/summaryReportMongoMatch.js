'use strict';

const { parseDateParam } = require('./summaryReportQueryHelpers');
const { buildAdminListSearchMatchClause } = require('../../../utils/adminListSearch');
const {
  buildExcludePoolMirrorLegMongoClause,
  buildHasPoolInvestorsMongoClause,
} = require('./summaryReportTradeListVisibility');

function appendDateRangeToMatch(match, dateFrom, dateTo) {
  const from = parseDateParam(dateFrom);
  const to = parseDateParam(dateTo);
  if (from || to) {
    match.createdAt = {};
    if (from) match.createdAt.$gte = from;
    if (to) match.createdAt.$lte = to;
  }
}

function combineAndClauses(clauses) {
  const parts = clauses.filter((c) => c && Object.keys(c).length > 0);
  if (parts.length === 0) return {};
  if (parts.length === 1) return parts[0];
  return { $and: parts };
}

function buildInvestmentMongoMatch(filters, options = {}) {
  const searchMode = options.searchMode === 'prefix' ? 'prefix' : 'text';
  const clauses = [];
  const base = {};
  appendDateRangeToMatch(base, filters.dateFrom, filters.dateTo);
  if (filters.investorId) base.investorId = filters.investorId;
  if (filters.traderId) base.traderId = filters.traderId;
  if (filters.status) base.status = filters.status;
  clauses.push(base);

  if (filters.returnSign === 'positive') {
    clauses.push({
      $expr: { $gt: [{ $ifNull: ['$currentValue', '$amount'] }, { $ifNull: ['$amount', 0] }] },
    });
  } else if (filters.returnSign === 'negative') {
    clauses.push({
      $expr: { $lt: [{ $ifNull: ['$currentValue', '$amount'] }, { $ifNull: ['$amount', 0] }] },
    });
  } else if (filters.returnSign === 'zero') {
    clauses.push({
      $expr: { $eq: [{ $ifNull: ['$currentValue', '$amount'] }, { $ifNull: ['$amount', 0] }] },
    });
  }

  const searchClause = buildAdminListSearchMatchClause('Investment', filters.search, searchMode);
  if (searchClause) clauses.push(searchClause);

  return combineAndClauses(clauses);
}

function buildTradeMongoMatch(filters, options = {}) {
  const searchMode = options.searchMode === 'prefix' ? 'prefix' : 'text';
  const clauses = [];
  const base = {};
  appendDateRangeToMatch(base, filters.dateFrom, filters.dateTo);
  if (filters.traderId) base.traderId = filters.traderId;
  if (filters.status) base.status = filters.status;
  if (filters.sellProgress === 'full') base.status = 'completed';
  else if (filters.sellProgress === 'partial') base.status = 'partial';
  clauses.push(base);
  clauses.push(buildExcludePoolMirrorLegMongoClause());

  const poolInvestorsClause = buildHasPoolInvestorsMongoClause(filters.hasPoolInvestors);
  if (poolInvestorsClause) clauses.push(poolInvestorsClause);

  if (filters.sellProgress === 'none') {
    clauses.push({
      $or: [
        { soldQuantity: 0 },
        { soldQuantity: { $exists: false } },
        { status: 'active' },
      ],
    });
  }

  if (filters.profitSign === 'positive') {
    clauses.push({
      $or: [{ grossProfit: { $gt: 0 } }, { calculatedProfit: { $gt: 0 } }],
    });
  } else if (filters.profitSign === 'negative') {
    clauses.push({
      $or: [{ grossProfit: { $lt: 0 } }, { calculatedProfit: { $lt: 0 } }],
    });
  }

  const searchClause = buildAdminListSearchMatchClause('Trade', filters.search, searchMode);
  if (searchClause) clauses.push(searchClause);

  return combineAndClauses(clauses);
}

module.exports = {
  buildInvestmentMongoMatch,
  buildTradeMongoMatch,
};
