'use strict';

const { BACKEND_DOC_TYPES, BACKEND_STATEMENT_TYPES } = require('./constants');

async function findBackendDocumentsForTrades(tradeIds) {
  if (!tradeIds.length) return [];
  const q = new Parse.Query('Document')
    .containedIn('tradeId', tradeIds)
    .equalTo('source', 'backend')
    .containedIn('type', BACKEND_DOC_TYPES)
    .limit(1000);
  return q.find({ useMasterKey: true });
}

async function findBackendStatementsForTrades(tradeIds) {
  if (!tradeIds.length) return [];
  const q = new Parse.Query('AccountStatement')
    .containedIn('tradeId', tradeIds)
    .equalTo('source', 'backend')
    .containedIn('entryType', BACKEND_STATEMENT_TYPES)
    .limit(1000);
  return q.find({ useMasterKey: true });
}

async function findCommissionsForTrades(tradeIds) {
  if (!tradeIds.length) return [];
  const q = new Parse.Query('Commission')
    .containedIn('tradeId', tradeIds)
    .limit(1000);
  return q.find({ useMasterKey: true });
}

async function findParticipationsForTrades(tradeIds) {
  if (!tradeIds.length) return [];
  const q = new Parse.Query('PoolTradeParticipation')
    .containedIn('tradeId', tradeIds)
    .limit(1000);
  return q.find({ useMasterKey: true });
}

async function findBackendDocumentsForTrade(tradeId) {
  const q = new Parse.Query('Document')
    .equalTo('tradeId', tradeId)
    .equalTo('source', 'backend')
    .containedIn('type', BACKEND_DOC_TYPES)
    .limit(1000);
  return q.find({ useMasterKey: true });
}

async function findBackendStatementsForTrade(tradeId) {
  const q = new Parse.Query('AccountStatement')
    .equalTo('tradeId', tradeId)
    .equalTo('source', 'backend')
    .containedIn('entryType', BACKEND_STATEMENT_TYPES)
    .limit(1000);
  return q.find({ useMasterKey: true });
}

async function findCommissionsForTrade(tradeId) {
  const q = new Parse.Query('Commission')
    .equalTo('tradeId', tradeId)
    .limit(1000);
  return q.find({ useMasterKey: true });
}

async function findParticipationsForTrade(tradeId) {
  const q = new Parse.Query('PoolTradeParticipation')
    .equalTo('tradeId', tradeId)
    .limit(1000);
  return q.find({ useMasterKey: true });
}

async function findOtherSettledParticipationsForInvestment(investmentId, excludeTradeId) {
  const q = new Parse.Query('PoolTradeParticipation')
    .equalTo('investmentId', investmentId)
    .equalTo('isSettled', true)
    .notEqualTo('tradeId', excludeTradeId)
    .limit(1000);
  return q.find({ useMasterKey: true });
}

async function loadInvestmentById(investmentId) {
  if (!investmentId) return null;
  try {
    return await new Parse.Query('Investment').get(investmentId, { useMasterKey: true });
  } catch (_) {
    return null;
  }
}

module.exports = {
  findBackendDocumentsForTrades,
  findBackendStatementsForTrades,
  findCommissionsForTrades,
  findParticipationsForTrades,
  findBackendDocumentsForTrade,
  findBackendStatementsForTrade,
  findCommissionsForTrade,
  findParticipationsForTrade,
  findOtherSettledParticipationsForInvestment,
  loadInvestmentById,
};
