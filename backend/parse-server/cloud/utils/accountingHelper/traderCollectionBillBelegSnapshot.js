'use strict';

/**
 * GoB: Trader Collection Bill (TBC/TSC) = SSOT for trade buy/sell Beleg content.
 * One canonical snapshot per document; Admin/iOS should read metadata + accountingSummaryText only.
 * @see Documentation/BOOKING_AND_BELEG_SSOT.md
 */

const { round2 } = require('./shared');
const { calculateOrderFees } = require('../helpers');
const { parseInstrumentFromTrade } = require('../traderAccountStatementPresentation');
const {
  formatDeValueDate,
  formatDeClosingDate,
  settlementFromInvoice,
  settlementFromOrderLike,
  securitiesDescriptionFromLineItems,
} = require('../belegSettlementFields');

const TRADER_COLLECTION_BILL_SCHEMA_VERSION = 1;
const TOLERANCE = 0.02;

/** Klartext vorhanden und plausibel (Admin/iOS/Backfill). */
function isUsableTraderBelegSummaryText(text) {
  const trimmed = String(text || '').trim();
  if (!trimmed) return false;
  return trimmed.includes('Belegnummer')
    || trimmed.includes('Ordervolumen')
    || trimmed.includes('Σ KAUF')
    || trimmed.includes('Σ VERKAUF')
    || trimmed.includes('Kaufabrechnung')
    || trimmed.includes('Verkaufsabrechnung');
}

function metadataNeedsBackfill(meta) {
  if (!meta || typeof meta !== 'object') return true;
  if (Number(meta.belegSchemaVersion) < TRADER_COLLECTION_BILL_SCHEMA_VERSION) return true;
  if (!(Number(meta.amount) > 0)) return true;
  if (!String(meta.traderDisplayName || '').trim()) return true;
  const fees = meta.fees;
  if (!fees || typeof fees !== 'object') return true;
  const totalFees = round2(Number(fees.totalFees) || 0);
  const orderFee = round2(Number(fees.orderFee) || 0);
  return totalFees <= 0 && orderFee <= 0;
}

function formatEuroDe(amount) {
  const n = round2(Math.abs(Number(amount) || 0));
  return new Intl.NumberFormat('de-DE', { style: 'currency', currency: 'EUR' }).format(n);
}

function formatEuroDeSigned(amount) {
  const n = round2(Number(amount) || 0);
  const abs = formatEuroDe(Math.abs(n));
  return n < 0 ? `-${abs}` : abs;
}

function formatInstrumentLine(instrument) {
  const parts = [];
  if (instrument.wknOrIsin) parts.push(instrument.wknOrIsin);
  if (instrument.securitiesDirection) parts.push(instrument.securitiesDirection);
  if (instrument.underlyingAsset) parts.push(instrument.underlyingAsset);
  if (instrument.strikePrice) parts.push(`${instrument.strikePrice} Pkt.`);
  if (instrument.issuer) parts.push(instrument.issuer);
  return parts.join(' - ');
}

function orderLikeFromOrder(order, trade, executionType) {
  if (order && typeof order.get === 'function') {
    return {
      executedAt: order.get('executedAt') || order.get('createdAt'),
      createdAt: order.get('createdAt'),
      exchange: order.get('exchange'),
      quantity: order.get('executedQuantity') || order.get('quantity'),
      price: order.get('price'),
      wkn: order.get('wkn'),
      id: order.id,
    };
  }
  const embedded = executionType === 'sell'
    ? (trade.get('sellOrder') || (trade.get('sellOrders') || [])[0] || trade.get('buyOrder') || {})
    : (trade.get('buyOrder') || {});
  return Object.assign({}, embedded, order || {});
}

function assertTotalWithFees(executionType, grossAmount, fees, totalWithFees, context) {
  const expected = executionType === 'buy'
    ? round2(grossAmount + (fees.totalFees || 0))
    : round2(Math.max(0, grossAmount - (fees.totalFees || 0)));
  if (Math.abs(round2(totalWithFees) - expected) > TOLERANCE) {
    throw new Error(
      `Trader collection bill invariant totalWithFees: ${totalWithFees} ≠ ${expected} `
      + JSON.stringify(context),
    );
  }
}

/**
 * @param {object} params
 * @param {Parse.Object} params.trade
 * @param {Parse.Object|object} [params.order]
 * @param {'buy'|'sell'} params.executionType
 * @param {number} params.grossAmount — Kurswert (positiv)
 * @param {object} [params.feeConfig]
 * @param {string} params.label — z. B. Kaufabrechnung
 * @param {string} params.docNumber — accountingDocumentNumber
 * @param {number|string} params.tradeNumber
 * @param {Parse.Object} [params.invoice] — optional; Wertpapierzeile aus Invoice bevorzugt
 * @param {{ traderId?: string, traderDisplayName?: string|null, traderUsername?: string|null }} [params.traderParty]
 * @returns {{ metadata: object, accountingSummaryText: string, booking: object }}
 */
function buildTraderCollectionBillBelegSnapshot({
  trade,
  order,
  executionType,
  grossAmount,
  feeConfig,
  label,
  docNumber,
  tradeNumber,
  invoice,
  traderParty,
}) {
  const ex = String(executionType || 'buy').toLowerCase();
  if (ex !== 'buy' && ex !== 'sell') {
    throw new Error(`Trader collection bill snapshot: invalid executionType "${executionType}"`);
  }

  const gross = round2(Math.abs(Number(grossAmount) || 0));
  if (gross <= 0) {
    throw new Error('Trader collection bill snapshot: grossAmount must be > 0 (GoB fail-closed)');
  }

  const orderLike = orderLikeFromOrder(order, trade, ex);
  const feesCalc = calculateOrderFees(gross, true, feeConfig || trade.get('feeConfig') || {});
  const fees = {
    orderFee: round2(feesCalc.orderFee || 0),
    exchangeFee: round2(feesCalc.exchangeFee || 0),
    foreignCosts: round2(feesCalc.foreignCosts || 0),
    totalFees: round2(feesCalc.totalFees || 0),
  };
  const totalWithFees = ex === 'buy'
    ? round2(gross + fees.totalFees)
    : round2(Math.max(0, gross - fees.totalFees));
  assertTotalWithFees(ex, gross, fees, totalWithFees, { tradeId: trade.id, docNumber });

  const qty = Number(
    orderLike.quantity
    || trade.get('quantity')
    || 0,
  );
  const price = Number(orderLike.price || 0);
  const symbol = String(trade.get('symbol') || orderLike.wkn || '').trim();

  let instrumentLine = '';
  if (invoice) {
    const fromInv = settlementFromInvoice(invoice);
    instrumentLine = fromInv.instrumentLine
      || securitiesDescriptionFromLineItems(invoice.get('lineItems'));
  }
  if (!instrumentLine) {
    instrumentLine = formatInstrumentLine(parseInstrumentFromTrade(trade, order || null));
  }

  const settlement = invoice
    ? settlementFromInvoice(invoice)
    : settlementFromOrderLike(orderLike);
  const bookedAt = orderLike.executedAt
    || orderLike.createdAt
    || trade.get('createdAt')
    || new Date();
  const tradingVenue = settlement.tradingVenue
    || (fees.exchangeFee > 0 ? 'XETRA' : null);
  const valueDate = settlement.valueDate || formatDeValueDate(bookedAt);
  const closingDate = settlement.closingDate || formatDeClosingDate(bookedAt);

  const party = traderParty && typeof traderParty === 'object' ? traderParty : {};
  const traderIdSnap = String(party.traderId || '').trim() || null;
  const traderDisplayNameSnap = String(party.traderDisplayName || '').trim() || null;
  const traderUsernameSnap = String(party.traderUsername || '').trim() || null;

  const metadata = {
    belegSchemaVersion: TRADER_COLLECTION_BILL_SCHEMA_VERSION,
    belegKind: 'traderCollectionBill',
    belegLabel: label,
    traderId: traderIdSnap,
    traderDisplayName: traderDisplayNameSnap,
    traderUsername: traderUsernameSnap,
    executionType: ex,
    symbol: symbol || null,
    instrumentLine: instrumentLine || null,
    amount: gross,
    quantity: qty > 0 ? qty : null,
    price: price > 0 ? price : null,
    orderId: orderLike.id || order?.id || order?.objectId || null,
    wkn: orderLike.wkn || symbol || null,
    fees,
    totalWithFees,
    valueDate,
    closingDate,
    tradingVenue,
    tradeNumber,
    generatedAt: new Date().toISOString(),
  };

  const accountingSummaryText = formatTraderCollectionBillSummaryText({
    label,
    docNumber,
    tradeNumber,
    metadata,
  });

  return {
    metadata,
    accountingSummaryText,
    booking: {
      grossAmount: gross,
      totalWithFees,
      signedTotal: ex === 'buy' ? -totalWithFees : totalWithFees,
      fees,
    },
  };
}

function formatTraderCollectionBillSummaryText({ label, docNumber, tradeNumber, metadata }) {
  const ex = String(metadata.executionType || 'buy').toLowerCase();
  const section = ex === 'sell' ? 'VERKAUF' : 'KAUF';
  const wertpapier = String(metadata.instrumentLine || '').trim()
    || (metadata.symbol ? String(metadata.symbol) : '');
  const fees = metadata.fees || {};
  const traderLine = String(metadata.traderDisplayName || '').trim();
  const lines = [
    label,
    `Belegnummer: ${docNumber}`,
    `Trade Nr.: ${tradeNumber}`,
    traderLine ? `Trader: ${traderLine}` : '',
    '',
    section,
    wertpapier ? `Wertpapier: ${wertpapier}` : '',
    metadata.quantity > 0 ? `Ordervolumen: ${metadata.quantity} St.` : '',
    metadata.quantity > 0 ? `davon ausgef.: ${metadata.quantity} St.` : '',
    metadata.price > 0 ? `Kurs (Ask): ${formatEuroDe(metadata.price)}` : '',
    metadata.amount > 0 ? `Kurswert: ${formatEuroDe(metadata.amount)}` : '',
    '',
    fees.orderFee > 0 ? `Ordergebühr: ${formatEuroDe(fees.orderFee)}` : '',
    fees.exchangeFee > 0 ? `Handelsplatzgebühr: ${formatEuroDe(fees.exchangeFee)}` : '',
    fees.foreignCosts > 0 ? `Fremdkostenpauschale: ${formatEuroDe(fees.foreignCosts)}` : '',
    fees.totalFees > 0 && !fees.orderFee ? `Gebühren gesamt: ${formatEuroDe(fees.totalFees)}` : '',
    '',
    `Σ ${section}: ${formatEuroDe(ex === 'buy' ? -metadata.totalWithFees : metadata.totalWithFees)}`,
    metadata.valueDate ? `Valuta: ${metadata.valueDate}` : '',
    metadata.closingDate ? `Schlusstag: ${metadata.closingDate}` : '',
    metadata.tradingVenue ? `Handelsplatz: ${metadata.tradingVenue}` : '',
  ];
  return lines.filter((line) => line !== '').join('\n');
}

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
  return sections;
}

/**
 * GoB companion for `trading_fees` ledger rows — not a Kauf-/Verkaufs-TBC/TSC.
 * Fees are already on buy/sell trader collection bills; this is an internal fee summary Beleg.
 */
function buildTradingFeesBelegSnapshot({
  trade,
  totalFees,
  feeBreakdown,
  label,
  docNumber,
  tradeNumber,
}) {
  const total = round2(Math.abs(Number(totalFees) || 0));
  if (total <= 0) {
    throw new Error('Trading fees beleg snapshot: totalFees must be > 0 (GoB fail-closed)');
  }
  const breakdown = feeBreakdown && typeof feeBreakdown === 'object' ? feeBreakdown : {};
  const fees = {
    orderFee: round2(Number(breakdown.orderFee) || 0),
    exchangeFee: round2(Number(breakdown.exchangeFee) || 0),
    foreignCosts: round2(Number(breakdown.foreignCosts) || 0),
    totalFees: total,
  };
  const sumParts = round2(fees.orderFee + fees.exchangeFee + fees.foreignCosts);
  if (sumParts > 0 && Math.abs(sumParts - total) > TOLERANCE) {
    console.warn(
      `⚠️ Trading fees beleg: breakdown sum €${sumParts} ≠ total €${total} (trade #${tradeNumber})`,
    );
  }

  const metadata = {
    belegSchemaVersion: TRADER_COLLECTION_BILL_SCHEMA_VERSION,
    belegKind: 'traderTradingFees',
    belegLabel: label,
    executionType: 'fees',
    symbol: String(trade.get('symbol') || '').trim() || null,
    amount: total,
    fees,
    totalWithFees: total,
    tradeNumber,
    generatedAt: new Date().toISOString(),
  };

  const lines = [
    label,
    `Belegnummer: ${docNumber}`,
    `Trade Nr.: ${tradeNumber}`,
    '',
    'GEBÜHREN (Handel)',
    fees.orderFee > 0 ? `Ordergebühr: ${formatEuroDe(fees.orderFee)}` : '',
    fees.exchangeFee > 0 ? `Handelsplatzgebühr: ${formatEuroDe(fees.exchangeFee)}` : '',
    fees.foreignCosts > 0 ? `Fremdkostenpauschale: ${formatEuroDe(fees.foreignCosts)}` : '',
    `Σ Gebühren: ${formatEuroDe(-total)}`,
  ];

  return {
    metadata,
    accountingSummaryText: lines.filter((line) => line !== '').join('\n'),
    booking: {
      grossAmount: total,
      totalWithFees: total,
      signedTotal: -total,
      fees,
    },
  };
}

module.exports = {
  TRADER_COLLECTION_BILL_SCHEMA_VERSION,
  TOLERANCE,
  isUsableTraderBelegSummaryText,
  metadataNeedsBackfill,
  buildTraderCollectionBillBelegSnapshot,
  buildTradingFeesBelegSnapshot,
  formatTraderCollectionBillSummaryText,
  traderCollectionBillDisplaySections,
  formatEuroDe,
  formatEuroDeSigned,
};
