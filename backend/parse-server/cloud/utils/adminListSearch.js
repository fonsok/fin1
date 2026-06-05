'use strict';

const { escapeRegExp } = require('./helpers');

/** Max length (aligned with searchDocuments / admin list UX). */
const MAX_ADMIN_SEARCH_TERM = 80;

function normalizeAdminSearchTerm(raw) {
  const t = String(raw || '').trim();
  if (!t) return '';
  return t.slice(0, MAX_ADMIN_SEARCH_TERM);
}

/**
 * Denormalized lowercase blob for MongoDB `$text` (self-hosted; no Atlas required).
 * Updated on Investment/Trade beforeSave and via admin backfill.
 */
function buildInvestmentSearchBlob(source) {
  const get = typeof source.get === 'function'
    ? (k) => source.get(k)
    : (k) => source[k];
  const parts = [
    get('investmentNumber'),
    get('investorName'),
    get('traderName'),
    get('investorId'),
    get('traderId'),
  ]
    .map((v) => (v == null ? '' : String(v).trim()))
    .filter(Boolean);
  return parts.join(' ').toLowerCase().slice(0, 512);
}

function buildTradeSearchBlob(source) {
  const get = typeof source.get === 'function'
    ? (k) => source.get(k)
    : (k) => source[k];
  const buy = get('buyOrder') || {};
  const parts = [
    get('tradeNumber'),
    get('symbol'),
    buy.symbol,
    get('traderId'),
  ]
    .map((v) => (v == null ? '' : String(v).trim()))
    .filter(Boolean);
  return parts.join(' ').toLowerCase().slice(0, 512);
}

/** Prefix range end for lowercase `adminSearchBlob` (index-friendly fallback). */
function prefixRangeEnd(term) {
  return `${term}\uffff`;
}

/**
 * Fallback when `$text` index missing or query fails — uses `adminSearchBlob` B-tree index.
 */
function buildAdminListSearchPrefixClause(entity, search) {
  const term = normalizeAdminSearchTerm(search).toLowerCase();
  if (!term) return null;

  const parts = [];

  if (entity === 'Investment') {
    if (/^inv-/i.test(term)) {
      parts.push({
        investmentNumber: { $regex: `^${escapeRegExp(term)}`, $options: 'i' },
      });
    }
    parts.push({
      adminSearchBlob: { $gte: term, $lt: prefixRangeEnd(term) },
    });
    return parts.length === 1 ? parts[0] : { $or: parts };
  }

  if (entity === 'Trade') {
    if (/^\d+$/.test(term)) {
      parts.push({ tradeNumber: parseInt(term, 10) });
    }
    const sym = term.toUpperCase();
    if (/^[A-Z][A-Z0-9.-]{0,15}$/.test(sym)) {
      parts.push({ symbol: sym });
      parts.push({ 'buyOrder.symbol': sym });
    }
    parts.push({
      adminSearchBlob: { $gte: term, $lt: prefixRangeEnd(term) },
    });
    return parts.length === 1 ? parts[0] : { $or: parts };
  }

  return null;
}

/**
 * Mongo `$match` clause for admin list search (index-friendly where possible).
 * @param {'Investment'|'Trade'} entity
 * @param {string} search
 * @param {'text'|'prefix'} [mode='text']
 * @returns {object|null}
 */
function buildAdminListSearchMatchClause(entity, search, mode = 'text') {
  if (mode === 'prefix') {
    return buildAdminListSearchPrefixClause(entity, search);
  }

  const term = normalizeAdminSearchTerm(search);
  if (!term) return null;

  const textQuery = sanitizeTextSearchQuery(term);
  if (!textQuery) {
    return buildAdminListSearchPrefixClause(entity, search);
  }

  const parts = [];

  if (entity === 'Investment') {
    if (/^INV-/i.test(term)) {
      parts.push({
        investmentNumber: { $regex: `^${escapeRegExp(term)}`, $options: 'i' },
      });
    }
    parts.push({ $text: { $search: textQuery } });
    return parts.length === 1 ? parts[0] : { $or: parts };
  }

  if (entity === 'Trade') {
    if (/^\d+$/.test(term)) {
      parts.push({ tradeNumber: parseInt(term, 10) });
    }
    const sym = term.toUpperCase();
    if (/^[A-Z][A-Z0-9.-]{0,15}$/.test(sym)) {
      parts.push({ symbol: sym });
      parts.push({ 'buyOrder.symbol': sym });
    }
    parts.push({ $text: { $search: textQuery } });
    return parts.length === 1 ? parts[0] : { $or: parts };
  }

  return null;
}

function isMongoTextIndexError(err) {
  const msg = String((err && err.message) || err || '').toLowerCase();
  return (
    msg.includes('text index')
    || msg.includes('no text index')
    || msg.includes('$text')
    || msg.includes('text score')
    || msg.includes('index not found')
  );
}

/** Strip characters that break MongoDB text search parser. */
function sanitizeTextSearchQuery(term) {
  return String(term)
    .replace(/[^a-zA-Z0-9\s._-]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
    .slice(0, MAX_ADMIN_SEARCH_TERM);
}

module.exports = {
  MAX_ADMIN_SEARCH_TERM,
  normalizeAdminSearchTerm,
  buildInvestmentSearchBlob,
  buildTradeSearchBlob,
  buildAdminListSearchMatchClause,
  buildAdminListSearchPrefixClause,
  sanitizeTextSearchQuery,
  isMongoTextIndexError,
};
