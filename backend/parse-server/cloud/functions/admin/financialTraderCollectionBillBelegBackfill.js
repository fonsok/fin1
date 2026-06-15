'use strict';

/**
 * Admin: persist `accountingSummaryText` + v1 `metadata` on legacy trader collection bills.
 * Idempotent — skips rows that already have usable SSOT snapshot text and complete metadata.
 */

const { audit } = require('../../utils/structuredLogger');
const { round2 } = require('../../utils/accountingHelper/shared');
const {
  buildTraderCollectionBillBelegSnapshot,
  formatTraderCollectionBillSummaryText,
  isUsableTraderBelegSummaryText,
  metadataNeedsBackfill,
} = require('../../utils/accountingHelper/traderCollectionBillBelegSnapshot');
const { enrichTraderDocumentMetadata, loadTradeInvoice } = require('./reports/documentBelegEnrichment');
const { resolveTraderDisplayNameForBeleg } = require('../../utils/traderDisplayNameForBeleg');
const { findSellOrderForBelegLeg } = require('../../utils/accountingHelper/settlementTradeMath');

const TRADER_DOC_TYPES = ['traderCollectionBill', 'trade_execution_document'];

function documentNeedsBackfill(doc, { force = false } = {}) {
  if (force) return true;
  const stored = String(doc.get('accountingSummaryText') || '').trim();
  const meta = doc.get('metadata') || {};
  if (!isUsableTraderBelegSummaryText(stored)) return true;
  return metadataNeedsBackfill(meta);
}

function resolveExecutionLabel(executionType) {
  const ex = String(executionType || 'buy').toLowerCase();
  if (ex === 'sell') return 'Verkaufsabrechnung';
  return 'Kaufabrechnung';
}

/**
 * @returns {{ metadata: object, accountingSummaryText: string, rebuildSource: string }}
 */
async function buildPersistedTraderBelegFields(doc) {
  const enriched = await enrichTraderDocumentMetadata(doc);
  const docNumber = doc.get('accountingDocumentNumber') || doc.get('documentNumber') || '';
  const tradeNumber = doc.get('tradeNumber') || enriched.tradeNumber || '';
  const executionType = String(enriched.executionType || 'buy').toLowerCase();
  const label = enriched.belegLabel || resolveExecutionLabel(executionType);
  const tradeId = String(doc.get('tradeId') || '').trim();
  const gross = round2(Number(enriched.amount) || 0);

  if (tradeId && gross > 0) {
    try {
      const trade = await new Parse.Query('Trade').get(tradeId, { useMasterKey: true });
      const invoice = await loadTradeInvoice(tradeId, executionType);
      const traderParty = await resolveTraderDisplayNameForBeleg(doc.get('userId'));
      const storedMeta = doc.get('metadata') || {};
      const sellOrder = executionType === 'sell'
        ? findSellOrderForBelegLeg(trade, {
          sellOrderId: storedMeta.sellOrderId
            || storedMeta.partialSell?.sellOrderId
            || enriched.sellOrderId,
          grossAmount: gross,
          quantity: enriched.quantity ?? storedMeta.quantity,
        })
        : null;
      const snapshot = buildTraderCollectionBillBelegSnapshot({
        trade,
        order: sellOrder,
        executionType,
        grossAmount: gross,
        feeConfig: trade.get('feeConfig') || {},
        label,
        docNumber,
        tradeNumber,
        invoice,
        traderParty,
      });
      return {
        metadata: snapshot.metadata,
        accountingSummaryText: snapshot.accountingSummaryText,
        rebuildSource: 'snapshot',
      };
    } catch (err) {
      audit.warn('admin.traderBeleg.backfill.snapshotFallback', {
        documentId: doc.id,
        tradeId,
        error: err && err.message ? err.message : String(err),
      });
    }
  }

  const accountingSummaryText = formatTraderCollectionBillSummaryText({
    label,
    docNumber,
    tradeNumber,
    metadata: enriched,
  });

  return {
    metadata: enriched,
    accountingSummaryText,
    rebuildSource: 'enriched',
  };
}

async function buildBackfillQuery(params) {
  const q = new Parse.Query('Document');
  q.containedIn('type', TRADER_DOC_TYPES);

  const tradeId = String(params.tradeId || '').trim();
  if (tradeId) q.equalTo('tradeId', tradeId);

  const objectId = String(params.objectId || '').trim();
  if (objectId) q.equalTo('objectId', objectId);

  const documentNumber = String(
    params.documentNumber || params.accountingDocumentNumber || '',
  ).trim();
  if (documentNumber) {
    q.equalTo('accountingDocumentNumber', documentNumber);
  }

  return q;
}

/**
 * @param {import('parse/node').Cloud.FunctionRequest} request
 */
async function handleBackfillTraderCollectionBillBeleg(request) {
  const params = request.params || {};
  const dryRun = params.dryRun !== false;
  const force = Boolean(params.force);
  const limit = Math.min(500, Math.max(1, parseInt(params.limit, 10) || 50));
  const skip = Math.max(0, parseInt(params.skip, 10) || 0);

  const q = await buildBackfillQuery(params);
  q.ascending('createdAt');
  q.skip(skip);
  q.limit(limit);

  const docs = await q.find({ useMasterKey: true });

  let examined = 0;
  let skipped = 0;
  let updated = 0;
  let failed = 0;
  const preview = [];

  for (const doc of docs) {
    examined += 1;
    if (!documentNeedsBackfill(doc, { force })) {
      skipped += 1;
      continue;
    }

    try {
      const { metadata, accountingSummaryText, rebuildSource } = await buildPersistedTraderBelegFields(doc);

      if (!isUsableTraderBelegSummaryText(accountingSummaryText)) {
        failed += 1;
        if (preview.length < 30) {
          preview.push({
            objectId: doc.id,
            accountingDocumentNumber: doc.get('accountingDocumentNumber'),
            status: 'failed',
            reason: 'could not build usable accountingSummaryText',
          });
        }
        continue;
      }

      if (!dryRun) {
        doc.set('metadata', metadata);
        doc.set('accountingSummaryText', accountingSummaryText);
        doc.set('size', Buffer.byteLength(accountingSummaryText, 'utf8'));
        await doc.save(null, { useMasterKey: true });
      }

      updated += 1;
      if (preview.length < 30) {
        preview.push({
          objectId: doc.id,
          accountingDocumentNumber: doc.get('accountingDocumentNumber'),
          status: dryRun ? 'wouldUpdate' : 'updated',
          rebuildSource,
          summaryLength: accountingSummaryText.length,
        });
      }
    } catch (err) {
      failed += 1;
      if (preview.length < 30) {
        preview.push({
          objectId: doc.id,
          accountingDocumentNumber: doc.get('accountingDocumentNumber'),
          status: 'error',
          reason: err && err.message ? err.message : String(err),
        });
      }
    }
  }

  audit.info('admin.traderBeleg.backfill', {
    dryRun,
    force,
    limit,
    skip,
    examined,
    skipped,
    updated,
    failed,
    message: 'backfillTraderCollectionBillBeleg completed',
  });

  return {
    dryRun,
    force,
    limit,
    skip,
    examined,
    skipped,
    updated,
    failed,
    hasMore: docs.length === limit,
    preview,
  };
}

module.exports = {
  handleBackfillTraderCollectionBillBeleg,
  buildPersistedTraderBelegFields,
  documentNeedsBackfill,
};
