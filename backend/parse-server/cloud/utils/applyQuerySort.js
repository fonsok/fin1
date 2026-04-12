'use strict';

/**
 * Apply a whitelist-safe sort to a Parse.Query.
 *
 * Parse Server merges cloud function args as: Object.assign({}, req.body, req.query),
 * so query-string params override the JSON body. Use `listSortOrder` in the POST body
 * for the effective direction when `sortOrder` might be pinned via ?sortOrder=desc.
 *
 * @param {Parse.Query} query
 * @param {object} requestParams – typically request.params (sortBy, sortOrder, listSortOrder)
 * @param {{ allowed: string[], defaultField: string }} options
 * @returns {{ sortBy: string, sortOrder: 'asc' | 'desc' }}
 */
function normalizeSortOrder(sortOrder) {
  if (sortOrder === true || sortOrder === 1 || sortOrder === '1') return 'asc';
  if (sortOrder === false || sortOrder === -1 || sortOrder === '-1') return 'desc';
  const s = String(sortOrder == null ? '' : sortOrder).trim().toLowerCase();
  if (s === 'asc' || s === 'ascending') return 'asc';
  if (s === 'desc' || s === 'descending') return 'desc';
  return 'desc';
}

/**
 * Effective list sort direction: prefers body-only `listSortOrder`, then `sortDirection`, then `sortOrder`.
 */
function resolveListSortOrder(requestParams) {
  if (!requestParams || typeof requestParams !== 'object') return 'desc';
  return normalizeSortOrder(
    requestParams.listSortOrder ?? requestParams.sortDirection ?? requestParams.sortOrder,
  );
}

function applyQuerySort(query, requestParams, options) {
  const { allowed, defaultField } = options;
  const sortOrderNorm = resolveListSortOrder(requestParams);
  const wantAsc = sortOrderNorm === 'asc';
  let field = typeof requestParams.sortBy === 'string' ? requestParams.sortBy.trim() : '';

  if (!allowed.includes(field)) {
    field = defaultField;
    if (wantAsc) {
      query.ascending(field);
    } else {
      query.descending(field);
    }
    return { sortBy: field, sortOrder: wantAsc ? 'asc' : 'desc' };
  }

  if (wantAsc) {
    query.ascending(field);
    return { sortBy: field, sortOrder: 'asc' };
  }
  query.descending(field);
  return { sortBy: field, sortOrder: 'desc' };
}

module.exports = { applyQuerySort, normalizeSortOrder, resolveListSortOrder };
