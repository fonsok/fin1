'use strict';

const { collectLedgerUserIdCandidates } = require('../canonicalUserId');
const { buildUserInvoiceOrQueryBranches } = require('../../functions/tradingInvoiceQuery');
const {
  SETTLEMENT_INVOICE_TYPES,
  TIMELINE_SOURCE_LIMIT,
  dedupeParseObjectsById,
} = require('./shared');

async function loadTradeInstrumentContext(tradeIds) {
  const tradeById = new Map();
  const orderByTradeId = new Map();
  if (!tradeIds.length) {
    return { tradeById, orderByTradeId };
  }

  const tradeQuery = new Parse.Query('Trade');
  tradeQuery.containedIn('objectId', tradeIds);
  tradeQuery.limit(tradeIds.length);
  tradeQuery.select(
    'wkn',
    'symbol',
    'securityName',
    'securityType',
    'quantity',
    'buyOrder',
    'sellOrder',
    'sellOrders',
    'tradeNumber',
    'buyLegType',
  );
  const trades = await tradeQuery.find({ useMasterKey: true });
  for (const trade of trades) {
    tradeById.set(trade.id, trade);
  }

  const orderQuery = new Parse.Query('Order');
  orderQuery.containedIn('tradeId', tradeIds);
  orderQuery.ascending('createdAt');
  orderQuery.limit(Math.min(tradeIds.length * 3, TIMELINE_SOURCE_LIMIT));
  orderQuery.select(
    'tradeId',
    'wkn',
    'symbol',
    'optionDirection',
    'underlyingAsset',
    'strikePrice',
    'issuer',
    'quantity',
    'executedQuantity',
    'legType',
  );
  const orders = await orderQuery.find({ useMasterKey: true });
  for (const order of orders) {
    const tid = order.get('tradeId');
    if (tid && !orderByTradeId.has(tid)) {
      orderByTradeId.set(tid, order);
    }
  }

  return { tradeById, orderByTradeId };
}

function collectTradeIdsFromSources(stmtEntries, invoices, timeline) {
  const ids = new Set();
  for (const row of stmtEntries) {
    const tid = row.get('tradeId');
    if (tid) ids.add(String(tid).trim());
  }
  for (const inv of invoices) {
    const tid = inv.get('tradeId');
    if (tid) ids.add(String(tid).trim());
  }
  for (const event of timeline) {
    if (event.tradeId) ids.add(String(event.tradeId).trim());
  }
  return [...ids].filter(Boolean);
}

async function fetchTraderStatementRows(userKeys) {
  if (!userKeys?.length) return { rows: [], truncated: false };
  const q = new Parse.Query('AccountStatement');
  q.containedIn('userId', userKeys);
  q.ascending('createdAt');
  q.limit(TIMELINE_SOURCE_LIMIT + 1);
  const fetched = dedupeParseObjectsById(await q.find({ useMasterKey: true }));
  const truncated = fetched.length > TIMELINE_SOURCE_LIMIT;
  return {
    rows: truncated ? fetched.slice(0, TIMELINE_SOURCE_LIMIT) : fetched,
    truncated,
  };
}

async function fetchTraderSettlementInvoices(user) {
  const stableId = user.get('stableId') || user.id;
  const branches = buildUserInvoiceOrQueryBranches({
    stableId,
    parseUserId: user.id,
    role: 'trader',
    invoiceType: null,
    tradeIds: [],
  });
  if (!branches.length) return { rows: [], truncated: false };
  const settlementTypes = Array.from(SETTLEMENT_INVOICE_TYPES);
  for (const branch of branches) {
    branch.containedIn('invoiceType', settlementTypes);
  }
  const query = branches.length === 1 ? branches[0] : Parse.Query.or(...branches);
  query.ascending('invoiceDate');
  query.limit(TIMELINE_SOURCE_LIMIT + 1);
  const fetched = dedupeParseObjectsById(await query.find({ useMasterKey: true }));
  const truncated = fetched.length > TIMELINE_SOURCE_LIMIT;
  return {
    rows: truncated ? fetched.slice(0, TIMELINE_SOURCE_LIMIT) : fetched,
    truncated,
  };
}

/**
 * SSOT Kundensicht: AccountStatement-Rohbuchungen + Rechnungen → Netto-Zeilen.
 */
async function loadTraderAccountStatementSourceData(user) {
  const userKeys = collectLedgerUserIdCandidates(user);
  const [stmtResult, invoiceResult] = await Promise.all([
    fetchTraderStatementRows(userKeys),
    fetchTraderSettlementInvoices(user),
  ]);
  return {
    userKeys,
    stmtEntries: stmtResult.rows,
    invoices: invoiceResult.rows,
    sourceTruncated: stmtResult.truncated || invoiceResult.truncated,
  };
}

module.exports = {
  loadTradeInstrumentContext,
  collectTradeIdsFromSources,
  fetchTraderStatementRows,
  fetchTraderSettlementInvoices,
  loadTraderAccountStatementSourceData,
};
