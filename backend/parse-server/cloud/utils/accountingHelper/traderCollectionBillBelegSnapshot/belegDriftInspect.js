'use strict';

const { round2 } = require('../shared');
const {
  TOLERANCE,
  isUsableTraderBelegSummaryText,
  metadataNeedsBackfill,
} = require('./shared');

const TRADER_DOC_TYPES = ['traderCollectionBill', 'trade_execution_document'];

function parseGermanEuro(fragment) {
  if (!fragment) return null;
  const m = String(fragment).match(/(-?[\d.]+,\d{2}|-?\d+(?:,\d+)?)\s*€/);
  if (!m) return null;
  const raw = m[1].replace(/\./g, '').replace(',', '.');
  const n = Number(raw);
  return Number.isFinite(n) ? round2(n) : null;
}

function parseSnapshotQuantity(text) {
  const m = String(text).match(/Ordervolumen:\s*(\d+(?:[.,]\d+)?)\s*St/i);
  if (!m) return null;
  return round2(Number(String(m[1]).replace(',', '.')));
}

function parseSnapshotExecutionSide(text) {
  const trimmed = String(text || '');
  if (/Verkaufsabrechnung/i.test(trimmed) || /\nVERKAUF\n/.test(trimmed) || /Σ\s+VERKAUF/i.test(trimmed)) {
    return 'sell';
  }
  if (/Kaufabrechnung/i.test(trimmed) || /\nKAUF\n/.test(trimmed) || /Σ\s+KAUF/i.test(trimmed)) {
    return 'buy';
  }
  return null;
}

function parseSnapshotSigmaAmount(text) {
  const m = String(text).match(/Σ\s+(KAUF|VERKAUF):\s*(-?[\d.,]+)\s*€/i);
  if (!m) return null;
  const raw = m[2].replace(/\./g, '').replace(',', '.');
  const n = Number(raw);
  return Number.isFinite(n) ? round2(Math.abs(n)) : null;
}

function amountsDiffer(a, b, tolerance = TOLERANCE) {
  if (a == null || b == null) return false;
  return Math.abs(round2(a) - round2(b)) > tolerance;
}

/**
 * @param {import('parse/node').Object} doc — Parse Document (trader collection bill)
 * @param {{ invoiceGrossAmount?: number|null }} [options]
 */
function inspectDocumentBelegDrift(doc, options = {}) {
  const stored = String(doc.get('accountingSummaryText') || '').trim();
  const meta = doc.get('metadata') || {};
  const drifts = [];
  let status = 'healthy';

  if (!isUsableTraderBelegSummaryText(stored)) {
    drifts.push({ field: 'accountingSummaryText', code: 'missing_or_unusable' });
    status = 'needs_backfill';
  }

  if (metadataNeedsBackfill(meta)) {
    drifts.push({ field: 'metadata', code: 'incomplete_metadata' });
    if (status === 'healthy') status = 'needs_backfill';
  }

  if (status === 'needs_backfill') {
    return {
      objectId: doc.id,
      accountingDocumentNumber: doc.get('accountingDocumentNumber') || doc.get('documentNumber'),
      tradeId: doc.get('tradeId') || null,
      status,
      drifts,
    };
  }

  const snapQty = parseSnapshotQuantity(stored);
  const metaQty = round2(Number(meta.quantity) || 0);
  if (snapQty != null && metaQty > 0 && amountsDiffer(snapQty, metaQty, 0.001)) {
    drifts.push({
      field: 'quantity',
      code: 'snapshot_metadata_mismatch',
      snapshot: snapQty,
      metadata: metaQty,
    });
  }

  const snapEx = parseSnapshotExecutionSide(stored);
  const metaEx = String(meta.executionType || '').toLowerCase();
  if (snapEx && metaEx && snapEx !== metaEx) {
    drifts.push({
      field: 'executionType',
      code: 'snapshot_metadata_mismatch',
      snapshot: snapEx,
      metadata: metaEx,
    });
  }

  const kurswertLine = stored.match(/Kurswert:\s*(-?[\d.,]+)\s*€/i);
  const snapAmount = parseGermanEuro(kurswertLine ? kurswertLine[0] : null);
  const metaAmount = round2(Number(meta.amount) || 0);
  if (snapAmount != null && metaAmount > 0 && amountsDiffer(snapAmount, metaAmount)) {
    drifts.push({
      field: 'amount',
      code: 'snapshot_metadata_mismatch',
      snapshot: snapAmount,
      metadata: metaAmount,
    });
  }

  const snapSigma = parseSnapshotSigmaAmount(stored);
  const metaTotal = round2(Number(meta.totalWithFees) || 0);
  if (snapSigma != null && metaTotal > 0 && amountsDiffer(snapSigma, metaTotal)) {
    drifts.push({
      field: 'totalWithFees',
      code: 'snapshot_metadata_mismatch',
      snapshot: snapSigma,
      metadata: metaTotal,
    });
  }

  const invoiceGross = options.invoiceGrossAmount != null
    ? round2(Number(options.invoiceGrossAmount) || 0)
    : null;
  if (invoiceGross != null && metaAmount > 0 && amountsDiffer(invoiceGross, metaAmount)) {
    drifts.push({
      field: 'amount',
      code: 'metadata_invoice_mismatch',
      metadata: metaAmount,
      invoice: invoiceGross,
    });
  }

  if (drifts.some((d) => d.code === 'snapshot_metadata_mismatch' || d.code === 'metadata_invoice_mismatch')) {
    status = 'drifted';
  }

  return {
    objectId: doc.id,
    accountingDocumentNumber: doc.get('accountingDocumentNumber') || doc.get('documentNumber'),
    tradeId: doc.get('tradeId') || null,
    status,
    drifts,
  };
}

async function buildDriftQuery(params) {
  const q = new Parse.Query('Document');
  q.containedIn('type', TRADER_DOC_TYPES);

  const tradeId = String(params.tradeId || '').trim();
  if (tradeId) q.equalTo('tradeId', tradeId);

  const objectId = String(params.objectId || '').trim();
  if (objectId) q.equalTo('objectId', objectId);

  const documentNumber = String(
    params.documentNumber || params.accountingDocumentNumber || '',
  ).trim();
  if (documentNumber) q.equalTo('accountingDocumentNumber', documentNumber);

  return q;
}

/**
 * Batch inspect trader TBC/TSC rows for snapshot ↔ metadata (and optional invoice) drift.
 */
async function inspectTraderCollectionBillBelegDrift(params = {}, deps = {}) {
  const limit = Math.min(500, Math.max(1, parseInt(params.limit, 10) || 50));
  const skip = Math.max(0, parseInt(params.skip, 10) || 0);
  const includeInvoice = Boolean(params.includeInvoice);
  const loadTradeInvoice = deps.loadTradeInvoice
    || ((tradeId, executionType) => {
      const { loadTradeInvoice: load } = require('../../../functions/admin/reports/documentBelegEnrichment');
      return load(tradeId, executionType);
    });

  const q = await buildDriftQuery(params);
  q.descending('createdAt');
  q.skip(skip);
  q.limit(limit);

  const docs = await q.find({ useMasterKey: true });

  let examined = 0;
  let healthy = 0;
  let needsBackfill = 0;
  let drifted = 0;
  const samples = [];

  for (const doc of docs) {
    examined += 1;
    let invoiceGrossAmount = null;

    if (includeInvoice) {
      const tradeId = String(doc.get('tradeId') || '').trim();
      const meta = doc.get('metadata') || {};
      const executionType = String(meta.executionType || 'buy').toLowerCase();
      if (tradeId) {
        try {
          const invoice = await loadTradeInvoice(tradeId, executionType);
          if (invoice) {
            const items = invoice.get('lineItems') || [];
            invoiceGrossAmount = items
              .filter((item) => String(item?.itemType || '') === 'securities')
              .reduce((sum, item) => sum + round2(Number(item?.totalAmount) || 0), 0);
          }
        } catch {
          // Invoice optional for drift inspect
        }
      }
    }

    const result = inspectDocumentBelegDrift(doc, { invoiceGrossAmount });
    if (result.status === 'healthy') healthy += 1;
    else if (result.status === 'needs_backfill') needsBackfill += 1;
    else if (result.status === 'drifted') drifted += 1;

    if (result.status !== 'healthy' && samples.length < 25) {
      samples.push(result);
    }
  }

  const overall = drifted > 0 || needsBackfill > 0 ? 'degraded' : 'healthy';

  return {
    overall,
    checkedAt: new Date().toISOString(),
    limit,
    skip,
    examined,
    healthy,
    needsBackfill,
    drifted,
    hasMore: docs.length === limit,
    samples,
    repairHint: 'Run backfillTraderCollectionBillBeleg with dryRun:true first, then dryRun:false',
  };
}

module.exports = {
  TRADER_DOC_TYPES,
  parseSnapshotQuantity,
  parseSnapshotExecutionSide,
  inspectDocumentBelegDrift,
  inspectTraderCollectionBillBelegDrift,
};
