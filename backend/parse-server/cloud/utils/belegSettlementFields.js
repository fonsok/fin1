'use strict';

function toDate(value) {
  if (!value) return null;
  if (value instanceof Date) return Number.isNaN(value.getTime()) ? null : value;
  const d = new Date(value);
  return Number.isNaN(d.getTime()) ? null : d;
}

/** Wie iOS TradeStatement: Valuta dd.MM.yy */
function formatDeValueDate(value) {
  const d = toDate(value);
  if (!d) return null;
  const dd = String(d.getUTCDate()).padStart(2, '0');
  const mm = String(d.getUTCMonth() + 1).padStart(2, '0');
  const yy = String(d.getUTCFullYear()).slice(-2);
  return `${dd}.${mm}.${yy}`;
}

/** Wie iOS TradeStatement: Schlusstag dd.MM.yyyy, HH:mm Uhr */
function formatDeClosingDate(value) {
  const d = toDate(value);
  if (!d) return null;
  const dd = String(d.getUTCDate()).padStart(2, '0');
  const mm = String(d.getUTCMonth() + 1).padStart(2, '0');
  const yyyy = d.getUTCFullYear();
  const hh = String(d.getUTCHours()).padStart(2, '0');
  const min = String(d.getUTCMinutes()).padStart(2, '0');
  return `${dd}.${mm}.${yyyy}, ${hh}:${min} Uhr`;
}

function securitiesDescriptionFromLineItems(lineItems) {
  const items = Array.isArray(lineItems) ? lineItems : [];
  const sec = items.find((i) => String(i?.itemType || '') === 'securities');
  return String(sec?.description || '').trim();
}

/** Aus Invoice-Zeile „Börsenplatzgebühr (XETRA)“ → XETRA */
function tradingVenueFromLineItems(lineItems) {
  const items = Array.isArray(lineItems) ? lineItems : [];
  const ex = items.find((i) => String(i?.itemType || '') === 'exchangeFee');
  const desc = String(ex?.description || '');
  const m = desc.match(/\(([^)]+)\)/);
  return m ? m[1].trim() : '';
}

function settlementFromInvoice(invoice) {
  if (!invoice) return {};
  const at = invoice.get('invoiceDate') || invoice.get('createdAt') || null;
  const lineItems = invoice.get('lineItems') || [];
  const tradingVenue = tradingVenueFromLineItems(lineItems);
  return {
    valueDate: formatDeValueDate(at),
    closingDate: formatDeClosingDate(at),
    tradingVenue: tradingVenue || null,
    instrumentLine: securitiesDescriptionFromLineItems(lineItems) || null,
  };
}

function settlementFromOrderLike(order) {
  if (!order) return {};
  const at = order.executedAt || order.createdAt || order.invoiceDate || null;
  const exchange = String(order.exchange || order.tradingVenue || '').trim();
  return {
    valueDate: formatDeValueDate(at),
    closingDate: formatDeClosingDate(at),
    tradingVenue: exchange || null,
  };
}

module.exports = {
  formatDeValueDate,
  formatDeClosingDate,
  securitiesDescriptionFromLineItems,
  tradingVenueFromLineItems,
  settlementFromInvoice,
  settlementFromOrderLike,
};
