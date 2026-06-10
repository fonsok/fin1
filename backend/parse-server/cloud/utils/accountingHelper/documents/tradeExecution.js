'use strict';

const { generateSequentialNumber } = require('../../helpers');
const { round2, formatDateCompact, generateShortHash } = require('../shared');
const {
  buildTraderCollectionBillBelegSnapshot,
  buildTradingFeesBelegSnapshot,
} = require('../traderCollectionBillBelegSnapshot');
const { resolveTraderDisplayNameForBeleg } = require('../../traderDisplayNameForBeleg');
const { applyBusinessCaseIdToDocument } = require('./shared');
const { customerDisplayFromPersistedBelegMetadata } = require('../traderStatementCustomerDisplay');

async function loadTradeInvoiceForBeleg(tradeId, executionType) {
  const q = new Parse.Query('Invoice');
  q.equalTo('tradeId', tradeId);
  if (String(executionType).toLowerCase() === 'sell') {
    q.containedIn('invoiceType', ['sell_invoice', 'sell']);
  } else {
    q.containedIn('invoiceType', ['buy_invoice', 'buy']);
  }
  q.descending('invoiceDate');
  q.limit(1);
  return q.first({ useMasterKey: true });
}

async function findExistingTradeExecutionDocument({ tradeId, executionType, businessCaseId, sellOrderId }) {
  if (!tradeId || !executionType) return null;
  const normalizedType = String(executionType).toLowerCase();
  const q = new Parse.Query('Document');
  q.equalTo('tradeId', tradeId);
  q.equalTo('source', 'backend');
  q.equalTo('metadata.executionType', normalizedType);
  if (businessCaseId) {
    q.equalTo('businessCaseId', String(businessCaseId).trim());
  }
  const sellKey = String(sellOrderId || '').trim();
  if (normalizedType === 'sell' && sellKey) {
    q.equalTo('metadata.sellOrderId', sellKey);
  }
  q.ascending('createdAt');
  return q.first({ useMasterKey: true });
}

async function createTradeExecutionDocument({
  traderId,
  trade,
  executionType,
  amount,
  order,
  businessCaseId,
  feeBreakdown,
  sellOrderId,
}) {
  const tradeNumber = trade.get('tradeNumber');
  const symbol = trade.get('symbol') || '';
  const resolvedBusinessCaseId = businessCaseId || trade.get('businessCaseId');
  const resolvedSellOrderId = String(
    sellOrderId
    || order?.id
    || order?.objectId
    || order?.orderId
    || '',
  ).trim();
  const existingDoc = await findExistingTradeExecutionDocument({
    tradeId: trade.id,
    executionType,
    businessCaseId: resolvedBusinessCaseId,
    sellOrderId: String(executionType).toLowerCase() === 'sell' ? resolvedSellOrderId : undefined,
  });
  if (existingDoc) {
    return {
      document: existingDoc,
      customerDisplay: customerDisplayFromPersistedBelegMetadata(
        existingDoc.get('metadata'),
        executionType,
      ),
    };
  }

  const typeToDocType = {
    buy: 'traderCollectionBill',
    sell: 'traderCollectionBill',
    fees: 'invoice',
  };

  const typeToPrefix = {
    buy: 'TBC',
    sell: 'TSC',
    fees: 'TFS',
  };

  const typeToLabel = {
    buy: 'Kaufabrechnung',
    sell: 'Verkaufsabrechnung',
    fees: 'Gebührenabrechnung',
  };

  const docType = typeToDocType[executionType] || 'trade_execution_document';
  const prefix = typeToPrefix[executionType] || 'TED';
  const label = typeToLabel[executionType] || 'Trade Execution';

  const docNumber = await generateSequentialNumber(prefix, 'Document', 'accountingDocumentNumber');
  const dateStr = formatDateCompact(new Date());
  const hash = generateShortHash();
  const grossAmount = round2(Math.abs(amount));
  const traderParty = await resolveTraderDisplayNameForBeleg(traderId);
  let invoice = null;
  try {
    invoice = await loadTradeInvoiceForBeleg(trade.id, executionType);
  } catch {
    // Invoice optional at booking time
  }

  const snapshot = executionType === 'fees'
    ? buildTradingFeesBelegSnapshot({
      trade,
      totalFees: grossAmount,
      feeBreakdown,
      label,
      docNumber,
      tradeNumber,
    })
    : buildTraderCollectionBillBelegSnapshot({
      trade,
      order,
      executionType,
      grossAmount,
      feeConfig: trade.get('feeConfig') || {},
      label,
      docNumber,
      tradeNumber,
      invoice,
      traderParty,
    });

  const Document = Parse.Object.extend('Document');
  const doc = new Document();
  doc.set('userId', traderParty.traderId || traderId);
  doc.set('type', docType);
  doc.set('name', `${label}_Trade${tradeNumber}_${symbol}_${dateStr}_${hash}.pdf`);
  doc.set('tradeId', trade.id);
  doc.set('tradeNumber', tradeNumber);
  doc.set('accountingDocumentNumber', docNumber);
  doc.set('source', 'backend');
  const metadata = Object.assign({}, snapshot.metadata, {
    executionType: String(executionType).toLowerCase(),
    ...(String(executionType).toLowerCase() === 'sell' && resolvedSellOrderId
      ? { sellOrderId: resolvedSellOrderId }
      : {}),
  });
  doc.set('metadata', metadata);
  doc.set('accountingSummaryText', snapshot.accountingSummaryText);
  doc.set('size', Buffer.byteLength(snapshot.accountingSummaryText, 'utf8'));

  applyBusinessCaseIdToDocument(doc, resolvedBusinessCaseId);

  await doc.save(null, { useMasterKey: true });
  console.log(`📄 ${label} created: ${docNumber} for trade #${tradeNumber} (${symbol}), €${round2(Math.abs(amount))}`);
  return {
    document: doc,
    customerDisplay: snapshot.customerDisplay || null,
  };
}

module.exports = {
  createTradeExecutionDocument,
  findExistingTradeExecutionDocument,
};
