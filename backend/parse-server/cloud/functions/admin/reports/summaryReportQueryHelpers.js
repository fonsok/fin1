'use strict';

function parseDateParam(v) {
  if (v == null || v === '') return null;
  const d = v instanceof Date ? v : new Date(v);
  return Number.isNaN(d.getTime()) ? null : d;
}

function buildInvestmentMatch({ dateFrom, dateTo, investorId, traderId }) {
  const match = {};
  if (dateFrom || dateTo) {
    match.createdAt = {};
    if (dateFrom) match.createdAt.$gte = parseDateParam(dateFrom);
    if (dateTo) match.createdAt.$lte = parseDateParam(dateTo);
  }
  if (investorId) match.investorId = investorId;
  if (traderId) match.traderId = traderId;
  return match;
}

function buildTradeMatch({ dateFrom, dateTo, traderId }) {
  const match = {};
  if (dateFrom || dateTo) {
    match.createdAt = {};
    if (dateFrom) match.createdAt.$gte = parseDateParam(dateFrom);
    if (dateTo) match.createdAt.$lte = parseDateParam(dateTo);
  }
  if (traderId) match.traderId = traderId;
  return match;
}

function applyInvestmentQueryFilters(query, filters) {
  const { dateFrom, dateTo, investorId, traderId } = filters;
  const from = parseDateParam(dateFrom);
  const to = parseDateParam(dateTo);
  if (from) query.greaterThanOrEqualTo('createdAt', from);
  if (to) query.lessThanOrEqualTo('createdAt', to);
  if (investorId) query.equalTo('investorId', investorId);
  if (traderId) query.equalTo('traderId', traderId);
}

function applyTradeQueryFilters(query, filters) {
  const { dateFrom, dateTo, traderId } = filters;
  const from = parseDateParam(dateFrom);
  const to = parseDateParam(dateTo);
  if (from) query.greaterThanOrEqualTo('createdAt', from);
  if (to) query.lessThanOrEqualTo('createdAt', to);
  if (traderId) query.equalTo('traderId', traderId);
}

module.exports = {
  parseDateParam,
  buildInvestmentMatch,
  buildTradeMatch,
  applyInvestmentQueryFilters,
  applyTradeQueryFilters,
};
