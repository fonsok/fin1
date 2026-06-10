'use strict';

const {
  traderCollectionBillDisplaySections,
} = require('../../../utils/accountingHelper/traderCollectionBillBelegSnapshot');

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

function buildTraderSellLegCard(doc, index, total, metaOverride) {
  const meta = metaOverride ?? (doc.get('metadata') || {});
  const partial = meta.partialSell && typeof meta.partialSell === 'object' ? meta.partialSell : null;
  const eventIndex = partial?.eventIndex ?? (index + 1);
  const totalSellEvents = partial?.totalSellEvents ?? total;
  const displaySections = traderCollectionBillDisplaySections(meta, doc);
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

function buildTraderSellLegsFromSells(sells, tradeStatus, enrichedMetaByDocId) {
  if (!shouldShowTraderSellLegs(sells, tradeStatus)) return [];
  const metaMap = enrichedMetaByDocId instanceof Map ? enrichedMetaByDocId : new Map();

  return sells.map((doc, index) => {
    const enriched = metaMap.get(doc.id);
    return buildTraderSellLegCard(
      doc,
      index,
      sells.length,
      enriched !== undefined ? enriched : undefined,
    );
  });
}

module.exports = {
  shouldShowTraderSellLegs,
  buildTraderSellLegsFromSells,
  buildTraderSellLegCard,
};
