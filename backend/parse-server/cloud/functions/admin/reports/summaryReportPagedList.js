'use strict';

const { isMongoTextIndexError } = require('../../../utils/adminListSearch');
const { resolveListSortOrder } = require('../../../utils/applyQuerySort');
const { buildInvestmentMongoMatch, buildTradeMongoMatch } = require('./summaryReportMongoMatch');

/** Server-side guard against runaway admin list aggregates. */
const AGGREGATE_MAX_TIME_MS = 20_000;

function resolveSortField(sortParams, allowed, defaultField) {
  let field = typeof sortParams.sortBy === 'string' ? sortParams.sortBy.trim() : '';
  if (!allowed.includes(field)) field = defaultField;
  const order = resolveListSortOrder(sortParams) === 'asc' ? 1 : -1;
  return { [field]: order };
}

async function loadParseObjectsOrdered(className, ids) {
  if (!ids.length) return [];
  const q = new Parse.Query(className);
  q.containedIn('objectId', ids);
  q.limit(Math.min(ids.length, 500));
  const found = await q.find({ useMasterKey: true });
  const byId = new Map(found.map((o) => [o.id, o]));
  return ids.map((id) => byId.get(id)).filter(Boolean);
}

/**
 * Single aggregate round-trip: count + page ($facet).
 */
async function aggregatePagedList(className, match, sortParams, sortOptions, page, pageSize) {
  const sort = resolveSortField(sortParams, sortOptions.allowed, sortOptions.defaultField);
  const skip = Math.max(0, page) * pageSize;
  const pipeline = [
    { $match: match },
    {
      $facet: {
        meta: [{ $count: 'total' }],
        items: [
          { $sort: sort },
          { $skip: skip },
          { $limit: pageSize },
          { $project: { _id: 0, objectId: '$_id' } },
        ],
      },
    },
  ];

  const aggRows = await new Parse.Query(className).aggregate(pipeline, {
    useMasterKey: true,
    maxTimeMS: AGGREGATE_MAX_TIME_MS,
  });
  const bucket = aggRows && aggRows[0] ? aggRows[0] : {};
  const total = bucket.meta && bucket.meta[0] ? Number(bucket.meta[0].total) || 0 : 0;
  const ids = (bucket.items || []).map((r) => r.objectId).filter(Boolean);
  const rows = await loadParseObjectsOrdered(className, ids);
  return { total, rows };
}

async function fetchWithSearchFallback(className, filters, buildMatch, sortParams, sortOptions, page, pageSize) {
  if (!filters.search) {
    const match = buildMatch(filters);
    const result = await aggregatePagedList(className, match, sortParams, sortOptions, page, pageSize);
    return { ...result, searchMode: 'none' };
  }

  try {
    const match = buildMatch(filters, { searchMode: 'text' });
    const result = await aggregatePagedList(className, match, sortParams, sortOptions, page, pageSize);
    return { ...result, searchMode: 'text' };
  } catch (err) {
    if (!isMongoTextIndexError(err)) throw err;
    const match = buildMatch(filters, { searchMode: 'prefix' });
    const result = await aggregatePagedList(className, match, sortParams, sortOptions, page, pageSize);
    return { ...result, searchMode: 'prefix' };
  }
}

async function fetchInvestmentsPage(filters, sortParams, page, pageSize) {
  return fetchWithSearchFallback(
    'Investment',
    filters,
    buildInvestmentMongoMatch,
    sortParams,
    { allowed: ['createdAt', 'amount'], defaultField: 'createdAt' },
    page,
    pageSize,
  );
}

async function fetchTradesPage(filters, sortParams, page, pageSize) {
  return fetchWithSearchFallback(
    'Trade',
    filters,
    buildTradeMongoMatch,
    sortParams,
    { allowed: ['createdAt', 'tradeNumber'], defaultField: 'createdAt' },
    page,
    pageSize,
  );
}

module.exports = {
  AGGREGATE_MAX_TIME_MS,
  fetchInvestmentsPage,
  fetchTradesPage,
  loadParseObjectsOrdered,
  aggregatePagedList,
};
