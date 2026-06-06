'use strict';

const { escapeRegExp } = require('../../../utils/helpers');
const { normalizeAdminSearchTerm } = require('../../../utils/adminListSearch');

const INVESTMENT_STATUSES = new Set([
  'reserved',
  'active',
  'executing',
  'paused',
  'closing',
  'completed',
  'cancelled',
]);

const TRADE_STATUSES = new Set(['active', 'partial', 'completed', 'cancelled']);

function trimParam(v) {
  if (v == null) return '';
  return String(v).trim();
}

function normalizeSearchTerm(v) {
  return normalizeAdminSearchTerm(v);
}

function normalizeEnum(v, allowed) {
  const t = trimParam(v);
  if (!t || t === 'any') return '';
  return allowed.has(t) ? t : '';
}

function normalizeInvestmentListFilters(params = {}) {
  const search = normalizeSearchTerm(params.search);
  const status = normalizeEnum(params.status, INVESTMENT_STATUSES);
  let returnSign = trimParam(params.returnSign);
  if (returnSign === 'any') returnSign = '';
  if (!['positive', 'negative', 'zero'].includes(returnSign)) returnSign = '';

  return {
    dateFrom: params.dateFrom,
    dateTo: params.dateTo,
    investorId: trimParam(params.investorId) || undefined,
    traderId: trimParam(params.traderId) || undefined,
    search: search || undefined,
    status: status || undefined,
    returnSign: returnSign || undefined,
  };
}

function normalizeTradeListFilters(params = {}) {
  const search = normalizeSearchTerm(params.search);
  const status = normalizeEnum(params.status, TRADE_STATUSES);
  let profitSign = trimParam(params.profitSign);
  if (profitSign === 'any') profitSign = '';
  if (!['positive', 'negative'].includes(profitSign)) profitSign = '';

  let sellProgress = trimParam(params.sellProgress);
  if (sellProgress === 'any') sellProgress = '';
  if (!['none', 'partial', 'full'].includes(sellProgress)) sellProgress = '';

  let hasPoolInvestors = trimParam(params.hasPoolInvestors);
  if (hasPoolInvestors === 'any') hasPoolInvestors = '';
  if (!['yes', 'no'].includes(hasPoolInvestors)) hasPoolInvestors = '';

  return {
    dateFrom: params.dateFrom,
    dateTo: params.dateTo,
    traderId: trimParam(params.traderId) || undefined,
    search: search || undefined,
    status: status || undefined,
    profitSign: profitSign || undefined,
    sellProgress: sellProgress || undefined,
    hasPoolInvestors: hasPoolInvestors || undefined,
  };
}

function buildInvestmentSearchQuery(search) {
  const term = normalizeSearchTerm(search);
  if (!term) return null;

  const re = new RegExp(escapeRegExp(term), 'i');
  const numberQ = new Parse.Query('Investment');
  numberQ.matches('investmentNumber', re);
  const investorQ = new Parse.Query('Investment');
  investorQ.matches('investorName', re);
  const traderQ = new Parse.Query('Investment');
  traderQ.matches('traderName', re);

  return Parse.Query.or(numberQ, investorQ, traderQ);
}

function buildTradeSearchQuery(search) {
  const term = normalizeSearchTerm(search);
  if (!term) return null;

  const parts = [];
  const re = new RegExp(escapeRegExp(term), 'i');

  const symbolQ = new Parse.Query('Trade');
  symbolQ.matches('symbol', re);
  parts.push(symbolQ);

  const buySymbolQ = new Parse.Query('Trade');
  buySymbolQ.matches('buyOrder.symbol', re);
  parts.push(buySymbolQ);

  if (/^\d+$/.test(term)) {
    const num = parseInt(term, 10);
    if (Number.isFinite(num)) {
      const tradeNumQ = new Parse.Query('Trade');
      tradeNumQ.equalTo('tradeNumber', num);
      parts.push(tradeNumQ);
    }
  }

  return Parse.Query.or(...parts);
}

function buildTradeProfitSignQuery(profitSign) {
  if (!profitSign) return null;
  if (profitSign === 'positive') {
    const grossQ = new Parse.Query('Trade');
    grossQ.greaterThan('grossProfit', 0);
    const calcQ = new Parse.Query('Trade');
    calcQ.greaterThan('calculatedProfit', 0);
    return Parse.Query.or(grossQ, calcQ);
  }
  const grossQ = new Parse.Query('Trade');
  grossQ.lessThan('grossProfit', 0);
  const calcQ = new Parse.Query('Trade');
  calcQ.lessThan('calculatedProfit', 0);
  return Parse.Query.or(grossQ, calcQ);
}

function buildTradeSellProgressQuery(sellProgress) {
  if (!sellProgress) return null;
  if (sellProgress === 'full') {
    const q = new Parse.Query('Trade');
    q.equalTo('status', 'completed');
    return q;
  }
  if (sellProgress === 'partial') {
    const q = new Parse.Query('Trade');
    q.equalTo('status', 'partial');
    return q;
  }
  const zeroSold = new Parse.Query('Trade');
  zeroSold.equalTo('soldQuantity', 0);
  const missingSold = new Parse.Query('Trade');
  missingSold.doesNotExist('soldQuantity');
  const activeOpen = new Parse.Query('Trade');
  activeOpen.equalTo('status', 'active');
  return Parse.Query.or(zeroSold, missingSold, activeOpen);
}

const {
  buildHasPoolInvestorsParseQuery,
} = require('./summaryReportTradeListVisibility');

/** Paired TRADER legs + denormalized `hasPoolParticipation` (see poolParticipationTradeSync). */
function buildTradeHasPoolInvestorsQuery(hasPoolInvestors) {
  return buildHasPoolInvestorsParseQuery(hasPoolInvestors);
}

function combineQueries(parts) {
  const queries = parts.filter(Boolean);
  if (queries.length === 0) {
    return new Parse.Query('Investment');
  }
  if (queries.length === 1) return queries[0];
  return Parse.Query.and(...queries);
}

module.exports = {
  INVESTMENT_STATUSES,
  TRADE_STATUSES,
  normalizeInvestmentListFilters,
  normalizeTradeListFilters,
  buildInvestmentSearchQuery,
  buildTradeSearchQuery,
  buildTradeProfitSignQuery,
  buildTradeSellProgressQuery,
  buildTradeHasPoolInvestorsQuery,
  combineQueries,
};
