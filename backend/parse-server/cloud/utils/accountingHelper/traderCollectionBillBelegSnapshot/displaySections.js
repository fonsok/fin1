'use strict';

const { round2 } = require('../shared');
const { formatDeClosingDate } = require('../../belegSettlementFields');
const { formatEuroDe, formatEuroDeSigned } = require('./shared');

/** Admin structured sections — derived only from snapshot metadata (no recompute). */
function traderCollectionBillDisplaySections(meta, doc, enrichment = {}) {
  const ex = String(meta.executionType || '').toLowerCase();
  const sectionLabel = ex === 'sell' ? 'VERKAUF' : 'KAUF';
  const title = meta.belegLabel
    || (ex === 'buy' ? 'Kaufabrechnung' : ex === 'sell' ? 'Verkaufsabrechnung' : 'Trade-Abrechnung');
  const sections = [];

  const traderUid = String(doc.get('userId') || meta.traderId || '').trim();
  const traderName = String(enrichment.partyDisplayName || meta.traderDisplayName || '').trim();
  const traderValue = traderUid
    ? (traderName ? `${traderName} · ${traderUid}` : traderUid)
    : null;

  const headerRows = [
    { label: 'Belegnummer', value: doc.get('accountingDocumentNumber') || '—' },
    { label: 'Trade', value: doc.get('tradeNumber') ? `#${doc.get('tradeNumber')}` : doc.get('tradeId') },
    traderValue ? { label: 'Trader (User-ID)', value: traderValue } : null,
  ].filter((r) => r != null && r.value != null && String(r.value).trim() !== '');

  if (headerRows.length) {
    sections.push({ title, rows: headerRows });
  }

  const bodyRows = [];
  const instrument = String(meta.instrumentLine || '').trim();
  if (instrument) bodyRows.push({ label: 'Wertpapier', value: instrument });
  else if (meta.symbol) bodyRows.push({ label: 'Symbol', value: String(meta.symbol) });

  const qty = Number(meta.quantity || 0);
  if (qty > 0) {
    bodyRows.push({ label: 'Ordervolumen', value: `${qty} St.` });
    bodyRows.push({ label: 'davon ausgef.', value: `${qty} St.` });
  }
  if (Number(meta.price) > 0) {
    bodyRows.push({ label: ex === 'sell' ? 'Kurs (Bid)' : 'Kurs (Ask)', value: formatEuroDe(meta.price) });
  }
  const gross = round2(Number(meta.amount) || 0);
  if (gross > 0) bodyRows.push({ label: 'Kurswert', value: formatEuroDe(gross) });

  const fees = meta.fees && typeof meta.fees === 'object' ? meta.fees : {};
  const orderFee = round2(Number(fees.orderFee) || 0);
  const exchangeFee = round2(Number(fees.exchangeFee) || 0);
  const foreignCosts = round2(Number(fees.foreignCosts) || 0);
  const totalFees = round2(Number(fees.totalFees) || 0);
  if (orderFee > 0 || exchangeFee > 0 || foreignCosts > 0 || totalFees > 0) {
    bodyRows.push({ label: 'Ordergebühr', value: formatEuroDe(orderFee) });
    bodyRows.push({ label: 'Handelsplatzgebühr', value: formatEuroDe(exchangeFee) });
    bodyRows.push({ label: 'Fremdkostenpauschale', value: formatEuroDe(foreignCosts) });
  }

  const totalWithFees = meta.totalWithFees != null
    ? round2(Number(meta.totalWithFees))
    : (ex === 'buy' ? round2(gross + totalFees) : round2(Math.max(0, gross - totalFees)));
  if (totalWithFees > 0 || gross > 0) {
    const signed = ex === 'buy' ? -totalWithFees : totalWithFees;
    bodyRows.push({ label: `Σ ${sectionLabel}`, value: formatEuroDeSigned(signed) });
  }
  if (meta.valueDate) bodyRows.push({ label: 'Valuta', value: String(meta.valueDate) });
  if (meta.closingDate) bodyRows.push({ label: 'Schlusstag', value: String(meta.closingDate) });
  if (meta.tradingVenue) bodyRows.push({ label: 'Handelsplatz', value: String(meta.tradingVenue) });

  if (bodyRows.length) {
    sections.push({ title: sectionLabel, rows: bodyRows });
  }

  const partial = meta.partialSell && typeof meta.partialSell === 'object' ? meta.partialSell : null;
  if (partial?.isPartialSell) {
    const executedLabel = partial.executedAt
      ? formatDeClosingDate(partial.executedAt)
      : null;
    const eventLabel = partial.eventIndex != null && partial.totalSellEvents != null
      ? `Teilverkauf ${partial.eventIndex} von ${partial.totalSellEvents}`
      : (partial.eventIndex != null ? `Teilverkauf #${partial.eventIndex}` : null);
    const partialRows = [
      eventLabel ? { label: 'Reihenfolge', value: eventLabel } : null,
      executedLabel ? { label: 'Ausgeführt am', value: executedLabel } : null,
      partial.sellOrderId ? { label: 'Verkaufsorder', value: String(partial.sellOrderId) } : null,
      partial.orderQuantity > 0
        ? { label: 'Dieser Verkauf', value: `${partial.orderQuantity} St.` }
        : null,
      partial.cumulativeSoldQuantity > 0 && partial.buyQuantity > 0
        ? {
          label: 'Verkauft (kumulativ)',
          value: `${partial.cumulativeSoldQuantity} von ${partial.buyQuantity} St.`,
        }
        : null,
      partial.remainingQuantity != null
        ? { label: 'Verbleibend', value: `${partial.remainingQuantity} St.` }
        : null,
      partial.sellVolumeProgress != null
        ? { label: 'Fortschritt', value: `${round2(partial.sellVolumeProgress * 100).toFixed(1)} %` }
        : null,
    ].filter(Boolean);
    if (partialRows.length) {
      sections.push({ title: 'Teilverkauf', rows: partialRows });
    }
  }

  return sections;
}

module.exports = {
  traderCollectionBillDisplaySections,
};
