'use strict';

const { round2, TOLERANCE_CENTS } = require('../shared');

const TRADER_COLLECTION_BILL_SCHEMA_VERSION = 1;
const TOLERANCE = TOLERANCE_CENTS / 100;

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

module.exports = {
  TRADER_COLLECTION_BILL_SCHEMA_VERSION,
  TOLERANCE,
  isUsableTraderBelegSummaryText,
  metadataNeedsBackfill,
  formatEuroDe,
  formatEuroDeSigned,
};
