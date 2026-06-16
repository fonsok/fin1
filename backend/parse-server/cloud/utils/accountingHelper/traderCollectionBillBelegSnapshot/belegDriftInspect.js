'use strict';

const { round2 } = require('../shared');
const {
  TOLERANCE,
  isUsableTraderBelegSummaryText,
  metadataNeedsBackfill,
} = require('./shared');
const {
  findSellOrderForBelegLeg,
  getOrderArrayFromTradeLike,
  resolveSellOrderGrossAmount,
  resolveSellOrderKey,
} = require('../settlementTradeMath');
const { sortSellOrdersChronologically } = require('./partialSellSnapshot');

const TRADER_DOC_TYPES = ['traderCollectionBill', 'trade_execution_document'];

const DRIFT_STATUS_CODES = new Set([
  'snapshot_metadata_mismatch',
  'metadata_invoice_mismatch',
  'partial_sell_leg_mismatch',
  'partial_sell_metadata_inconsistent',
  'partial_sell_amount_quantity_price_mismatch',
  'partial_sell_progress_inconsistent',
  'partial_sell_leg_unresolved',
]);

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

function parsePartialSellEventIndexFromSummary(text) {
  const m = String(text || '').match(/Teilverkauf\s+(\d+)\s+von\s+(\d+)/i);
  if (!m) return null;
  const n = parseInt(m[1], 10);
  return Number.isFinite(n) && n > 0 ? n : null;
}

/** In-memory partial-sell consistency — no Trade fetch. */
function inspectPartialSellMetadataInternalDrift(meta, storedSummary = '') {
  const drifts = [];
  const partial = meta.partialSell && typeof meta.partialSell === 'object' ? meta.partialSell : null;
  if (!partial?.isPartialSell) return drifts;

  const metaSellId = String(meta.sellOrderId || '').trim();
  const partialSellId = String(partial.sellOrderId || '').trim();
  if (metaSellId && partialSellId && metaSellId !== partialSellId) {
    drifts.push({
      field: 'partialSell.sellOrderId',
      code: 'partial_sell_metadata_inconsistent',
      metadata: partialSellId,
      expected: metaSellId,
    });
  }

  const metaQty = round2(Number(meta.quantity) || 0);
  const legQty = round2(Number(partial.orderQuantity) || 0);
  if (metaQty > 0 && legQty > 0 && amountsDiffer(metaQty, legQty, 0.001)) {
    drifts.push({
      field: 'partialSell.orderQuantity',
      code: 'partial_sell_metadata_inconsistent',
      metadata: legQty,
      expected: metaQty,
    });
  }

  const price = Number(meta.price) || 0;
  const amount = round2(Number(meta.amount) || 0);
  const expectedGross = round2(metaQty * price);
  if (metaQty > 0 && price > 0 && amount > 0 && amountsDiffer(expectedGross, amount)) {
    drifts.push({
      field: 'amount',
      code: 'partial_sell_amount_quantity_price_mismatch',
      metadata: amount,
      expected: expectedGross,
      quantity: metaQty,
      price,
    });
  }

  const snapEvent = parsePartialSellEventIndexFromSummary(storedSummary);
  if (snapEvent != null && partial.eventIndex != null && snapEvent !== partial.eventIndex) {
    drifts.push({
      field: 'partialSell.eventIndex',
      code: 'snapshot_metadata_mismatch',
      snapshot: snapEvent,
      metadata: partial.eventIndex,
    });
  }

  const buyQty = round2(Number(partial.buyQuantity) || 0);
  const cumulative = round2(Number(partial.cumulativeSoldQuantity) || 0);
  const remaining = partial.remainingQuantity != null ? round2(Number(partial.remainingQuantity)) : null;
  if (buyQty > 0 && cumulative > 0 && remaining != null && amountsDiffer(round2(cumulative + remaining), buyQty, 0.001)) {
    drifts.push({
      field: 'partialSell',
      code: 'partial_sell_progress_inconsistent',
      cumulative,
      remaining,
      buyQuantity: buyQty,
    });
  }

  return drifts;
}

/** Trade-backed leg resolution — one Trade load per tradeId (caller caches). */
function inspectPartialSellTradeLegDrift(meta, trade) {
  const drifts = [];
  if (!trade || String(meta.executionType || '').toLowerCase() !== 'sell') return drifts;

  const partial = meta.partialSell && typeof meta.partialSell === 'object' ? meta.partialSell : null;
  const sellOrderId = String(meta.sellOrderId || partial?.sellOrderId || '').trim();
  const gross = round2(Number(meta.amount) || 0);
  if (!partial?.isPartialSell && !sellOrderId) return drifts;

  const sellOrders = getOrderArrayFromTradeLike(trade);
  if (!sellOrders.length) return drifts;

  const resolved = findSellOrderForBelegLeg(trade, {
    sellOrderId,
    grossAmount: gross,
    quantity: meta.quantity,
  });

  if (!resolved) {
    if (gross > 0) {
      drifts.push({
        field: 'partialSell',
        code: 'partial_sell_leg_unresolved',
        sellOrderId: sellOrderId || null,
        amount: gross,
      });
    }
    return drifts;
  }

  const resolvedKey = resolveSellOrderKey(resolved);
  if (sellOrderId && resolvedKey !== sellOrderId) {
    drifts.push({
      field: 'sellOrderId',
      code: 'partial_sell_leg_mismatch',
      metadata: sellOrderId,
      expected: resolvedKey,
    });
  }

  const resolvedGross = resolveSellOrderGrossAmount(resolved);
  if (gross > 0 && amountsDiffer(resolvedGross, gross)) {
    drifts.push({
      field: 'amount',
      code: 'partial_sell_leg_mismatch',
      metadata: gross,
      tradeOrder: resolvedGross,
    });
  }

  const sorted = sortSellOrdersChronologically(sellOrders);
  const idx = sorted.findIndex((o) => resolveSellOrderKey(o) === resolvedKey);
  const expectedEventIndex = idx >= 0 ? idx + 1 : null;
  if (partial?.eventIndex != null && expectedEventIndex != null && partial.eventIndex !== expectedEventIndex) {
    drifts.push({
      field: 'partialSell.eventIndex',
      code: 'partial_sell_leg_mismatch',
      metadata: partial.eventIndex,
      expected: expectedEventIndex,
    });
  }

  const resolvedQty = round2(Number(resolved.quantity || resolved.executedQuantity || 0));
  if (partial?.orderQuantity != null && resolvedQty > 0
    && amountsDiffer(Number(partial.orderQuantity), resolvedQty, 0.001)) {
    drifts.push({
      field: 'partialSell.orderQuantity',
      code: 'partial_sell_leg_mismatch',
      metadata: partial.orderQuantity,
      expected: resolvedQty,
    });
  }

  return drifts;
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

  if (metaEx === 'sell' || String(meta.executionType || '').toLowerCase() === 'sell') {
    drifts.push(...inspectPartialSellMetadataInternalDrift(meta, stored));
    if (options.trade) {
      drifts.push(...inspectPartialSellTradeLegDrift(meta, options.trade));
    }
  }

  if (drifts.some((d) => DRIFT_STATUS_CODES.has(d.code))) {
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
  const includeTrade = params.includeTrade !== false;
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
  const tradeCache = new Map();

  async function loadTradeCached(tradeId) {
    if (tradeCache.has(tradeId)) return tradeCache.get(tradeId);
    try {
      const trade = await new Parse.Query('Trade').get(tradeId, { useMasterKey: true });
      tradeCache.set(tradeId, trade);
      return trade;
    } catch {
      tradeCache.set(tradeId, null);
      return null;
    }
  }

  function sellDocNeedsTradeLegCheck(meta) {
    if (String(meta.executionType || '').toLowerCase() !== 'sell') return false;
    const partial = meta.partialSell && typeof meta.partialSell === 'object' ? meta.partialSell : null;
    return Boolean(partial?.isPartialSell || String(meta.sellOrderId || partial?.sellOrderId || '').trim());
  }

  for (const doc of docs) {
    examined += 1;
    let invoiceGrossAmount = null;
    let trade = null;

    const meta = doc.get('metadata') || {};
    const tradeId = String(doc.get('tradeId') || '').trim();
    const executionType = String(meta.executionType || 'buy').toLowerCase();

    if (includeInvoice && tradeId) {
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

    if (includeTrade && tradeId && sellDocNeedsTradeLegCheck(meta)) {
      trade = await loadTradeCached(tradeId);
    }

    const result = inspectDocumentBelegDrift(doc, { invoiceGrossAmount, trade });
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
  parsePartialSellEventIndexFromSummary,
  inspectPartialSellMetadataInternalDrift,
  inspectPartialSellTradeLegDrift,
  inspectDocumentBelegDrift,
  inspectTraderCollectionBillBelegDrift,
};
