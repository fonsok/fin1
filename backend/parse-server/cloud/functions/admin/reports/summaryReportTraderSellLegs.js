'use strict';

const { projectDocumentDetail } = require('./documentBelegPresentation');
const {
  sortTraderSellBelegeChronologically,
} = require('../../../utils/accountingHelper/traderCollectionBillBelegSnapshot/partialSellSnapshot');

function isTraderSellDoc(doc) {
  const type = String(doc.get('type') || '');
  if (type !== 'traderCollectionBill' && type !== 'trade_execution_document') return false;
  const ex = String((doc.get('metadata') || {}).executionType || '').toLowerCase();
  return ex === 'sell' || /verkauf|sell/i.test(doc.get('name') || '');
}

function collectTraderSellDocs(traderDocs) {
  return sortTraderSellBelegeChronologically((traderDocs || []).filter(isTraderSellDoc));
}

function shouldShowTraderSellLegs(sellDocs, tradeStatus) {
  if (sellDocs.length > 1) return true;
  if (String(tradeStatus || '').toLowerCase() === 'partial') return sellDocs.length > 0;
  if (sellDocs.length === 1) {
    const partial = (sellDocs[0].get('metadata') || {}).partialSell;
    if (partial?.isPartialSell) return true;
    if (Number(partial?.totalSellEvents) > 1) return true;
  }
  return false;
}

function rowsFromSection(sections, title) {
  const section = sections.find((s) => s.title === title);
  return section?.rows?.map((r) => ({ label: r.label, value: String(r.value ?? '') })) ?? [];
}

function buildTraderSellLegCard(doc, index, total) {
  const meta = doc.get('metadata') || {};
  const partial = meta.partialSell && typeof meta.partialSell === 'object' ? meta.partialSell : null;
  const eventIndex = partial?.eventIndex ?? (index + 1);
  const totalSellEvents = partial?.totalSellEvents ?? total;
  const { displaySections } = projectDocumentDetail(doc, meta);
  const executedAt = partial?.executedAt
    || (doc.get('createdAt') ? doc.get('createdAt').toISOString() : undefined);

  return {
    eventIndex,
    totalSellEvents,
    title: totalSellEvents > 1
      ? `VERKAUF - Nr. ${eventIndex}/${totalSellEvents}`
      : 'VERKAUF',
    instrumentLine: String(meta.instrumentLine || meta.symbol || '').trim(),
    documentId: doc.id,
    documentNumber: doc.get('accountingDocumentNumber') || '',
    verkaufRows: rowsFromSection(displaySections, 'VERKAUF'),
    partialSellRows: rowsFromSection(displaySections, 'Teilverkauf'),
    createdAt: executedAt,
  };
}

function buildTraderSellLegsFromDocs(traderDocs, tradeStatus) {
  const sells = collectTraderSellDocs(traderDocs);
  if (!shouldShowTraderSellLegs(sells, tradeStatus)) return [];

  return sells.map((doc, index) => buildTraderSellLegCard(doc, index, sells.length));
}

module.exports = {
  collectTraderSellDocs,
  shouldShowTraderSellLegs,
  buildTraderSellLegsFromDocs,
};
