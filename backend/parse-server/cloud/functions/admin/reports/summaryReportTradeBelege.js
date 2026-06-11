'use strict';

const {
  sortTraderSellBelegeChronologically,
} = require('../../../utils/accountingHelper/traderCollectionBillBelegSnapshot/partialSellSnapshot');
const { metadataNeedsBackfill } = require('../../../utils/accountingHelper/traderCollectionBillBelegSnapshot');
const { enrichTraderDocumentMetadata } = require('./documentBelegEnrichment');
const {
  shouldShowTraderSellLegs,
  buildTraderSellLegsFromSells,
} = require('./summaryReportTraderSellLegs');

const BELEG_DOCUMENT_TYPES = [
  'traderCollectionBill',
  'trade_execution_document',
  'poolMirrorExecutionEigenbeleg',
  'invoice',
  'traderCreditNote',
  'appCommissionEigenbeleg',
  'investorCollectionBill',
  'investor_collection_bill',
  'investorPartialSellInternal',
];

function investmentIdFromDocument(doc) {
  const raw = doc.get('investmentId');
  if (!raw) return null;
  if (typeof raw === 'object' && raw.id) return String(raw.id);
  return String(raw).trim() || null;
}

function defaultBelegLabel(doc) {
  const type = String(doc.get('type') || '');
  const meta = doc.get('metadata') || {};
  const executionType = String(meta.executionType || '').toLowerCase();
  if (type === 'traderCreditNote') return 'Gutschrift (Provision)';
  if (type === 'appCommissionEigenbeleg' || type === 'appCommissionInternalEigenbeleg') {
    return 'Eigenbeleg (App-Erfolgsprovision)';
  }
  if (type === 'investorCollectionBill' || type === 'investor_collection_bill') {
    return 'Collection Bill (Investor)';
  }
  if (executionType === 'buy') return 'Kaufabrechnung (Trader)';
  if (executionType === 'sell') return 'Verkaufsabrechnung (Trader)';
  if (executionType === 'fees') return 'Gebührenabrechnung (Trader)';
  if (type === 'invoice') return 'Rechnung (Gebühren)';
  return doc.get('name') || 'Beleg';
}

function mapDocumentToBelegLink(doc, overrides = {}) {
  if (!doc) return null;
  const meta = doc.get('metadata') || {};
  const executionType = String(meta.executionType || '').toLowerCase();
  const docCreatedAt = doc.get('createdAt');
  const resolvedCreatedAt = overrides.createdAt != null
    ? String(overrides.createdAt)
    : (docCreatedAt ? docCreatedAt.toISOString() : undefined);
  return {
    documentId: doc.id,
    documentNumber: doc.get('accountingDocumentNumber') || '',
    documentType: doc.get('type') || '',
    executionType,
    label: overrides.label || defaultBelegLabel(doc),
    investmentId: overrides.investmentId ?? investmentIdFromDocument(doc) ?? undefined,
    investorId: overrides.investorId ?? (doc.get('userId') || undefined),
    createdAt: resolvedCreatedAt,
    visibility: overrides.visibility || 'customer',
    billKind: overrides.billKind,
  };
}

function sortDocsByCreatedAt(docs) {
  return [...docs].sort((a, b) => {
    const ta = a.get('createdAt')?.getTime?.() || 0;
    const tb = b.get('createdAt')?.getTime?.() || 0;
    return ta - tb;
  });
}

function isTraderExecutionDoc(doc) {
  const type = String(doc.get('type') || '');
  if (type === 'traderCollectionBill' || type === 'trade_execution_document') return true;
  const meta = doc.get('metadata') || {};
  const ex = String(meta.executionType || '').toLowerCase();
  return ex === 'buy' || ex === 'sell';
}

function isTraderBuyExecutionDoc(doc) {
  const ex = String((doc.get('metadata') || {}).executionType || '').toLowerCase();
  return ex === 'buy' || /kauf|buy/i.test(doc.get('name') || '');
}

function isTraderSellExecutionDoc(doc) {
  const ex = String((doc.get('metadata') || {}).executionType || '').toLowerCase();
  return ex === 'sell' || /verkauf|sell/i.test(doc.get('name') || '');
}

/** Single filter/sort pass for trader execution docs (buy + sell legs). */
function collectTraderExecutionSplit(docs) {
  const exec = (docs || []).filter(isTraderExecutionDoc);
  const buys = sortDocsByCreatedAt(exec.filter(isTraderBuyExecutionDoc));
  const sells = sortTraderSellBelegeChronologically(exec.filter(isTraderSellExecutionDoc));
  return { buys, sells };
}

function buildTraderExecutionBelegeFromSplit({ buys, sells }) {
  const buy = buys.length ? mapDocumentToBelegLink(buys[0]) : null;
  const sellLinks = sells.map((d, i) => {
    const meta = d.get('metadata') || {};
    const partial = meta.partialSell || {};
    const eventIndex = partial.eventIndex ?? (i + 1);
    const executedAt = partial.executedAt
      || (d.get('createdAt') ? d.get('createdAt').toISOString() : undefined);
    return mapDocumentToBelegLink(d, {
      label: sells.length > 1
        ? `Verkaufsabrechnung (Trader) #${eventIndex}`
        : 'Verkaufsabrechnung (Trader)',
      billKind: 'execution_sell',
      visibility: 'customer',
      createdAt: executedAt,
    });
  });
  return { buy, sells: sellLinks };
}

function buildTraderExecutionBelege(docs) {
  return buildTraderExecutionBelegeFromSplit(collectTraderExecutionSplit(docs));
}

function buildTraderBelege(docs, executionSplit) {
  const traderExecution = buildTraderExecutionBelegeFromSplit(
    executionSplit || collectTraderExecutionSplit(docs),
  );
  const creditDoc = sortDocsByCreatedAt(
    docs.filter((d) => String(d.get('type') || '') === 'traderCreditNote'),
  )[0];
  return {
    buy: traderExecution.buy,
    sells: traderExecution.sells,
    creditNote: creditDoc ? mapDocumentToBelegLink(creditDoc, {
      label: 'Gutschrift (Provision)',
      billKind: 'credit_note',
    }) : null,
  };
}

function isInvestorCollectionBill(doc) {
  const type = String(doc.get('type') || '');
  return type === 'investorCollectionBill' || type === 'investor_collection_bill';
}

function isInvestorPartialSellInternal(doc) {
  return String(doc.get('type') || '') === 'investorPartialSellInternal';
}

/**
 * Teil-Sell: mehrere CB pro Investment; Abschluss = letzter Beleg wenn Participation settled.
 */
function partitionInvestorCollectionBills(docs, participations = []) {
  const settledByInv = new Map();
  for (const p of participations) {
    if (p.investmentId) settledByInv.set(p.investmentId, Boolean(p.isSettled));
  }
  const byInv = new Map();
  for (const doc of docs.filter(isInvestorCollectionBill)) {
    const invId = investmentIdFromDocument(doc);
    if (!invId) continue;
    if (!byInv.has(invId)) byInv.set(invId, []);
    byInv.get(invId).push(doc);
  }

  const investorFullSettlement = [];
  const investorPartialSells = [];

  for (const [invId, invDocs] of byInv) {
    const sorted = sortDocsByCreatedAt(invDocs);
    const settled = settledByInv.get(invId) === true;
    if (settled && sorted.length > 0) {
      const last = sorted[sorted.length - 1];
      investorFullSettlement.push(mapDocumentToBelegLink(last, {
        label: 'Collection Bill (Investor, Abschluss)',
        billKind: 'full_settlement',
        visibility: 'customer',
        investmentId: invId,
      }));
      for (let i = 0; i < sorted.length - 1; i += 1) {
        investorPartialSells.push(mapPartialSellBeleg(sorted[i], invId, i + 1));
      }
    } else {
      sorted.forEach((d, i) => {
        investorPartialSells.push(mapPartialSellBeleg(d, invId, i + 1));
      });
    }
  }

  investorPartialSells.sort((a, b) => String(a.createdAt || '').localeCompare(String(b.createdAt || '')));
  investorFullSettlement.sort((a, b) => String(a.createdAt || '').localeCompare(String(b.createdAt || '')));
  return { investorFullSettlement, investorPartialSells };
}

function mapPartialSellBeleg(doc, investmentId, index) {
  const num = doc.get('accountingDocumentNumber') || doc.id?.slice(0, 8);
  return mapDocumentToBelegLink(doc, {
    label: `Eigenbeleg Teilverkauf (intern) · ${num}${index > 1 ? ` #${index}` : ''}`,
    billKind: 'partial_sell',
    visibility: 'internal',
    investmentId,
  });
}

function isPoolMirrorExecutionDoc(doc) {
  return String(doc.get('type') || '') === 'poolMirrorExecutionEigenbeleg';
}

/** Pool-Mirror: eigene Parse-Dokumente am Mirror-Trade (nicht Trader-TBC umbenennen). */
function buildPoolMirrorExecutionBelege(poolDocs) {
  const exec = poolDocs.filter(isPoolMirrorExecutionDoc);
  const buys = sortDocsByCreatedAt(exec.filter((d) => {
    const ex = String((d.get('metadata') || {}).executionType || '').toLowerCase();
    return ex === 'buy';
  }));
  const sells = sortTraderSellBelegeChronologically(exec.filter((d) => {
    const ex = String((d.get('metadata') || {}).executionType || '').toLowerCase();
    return ex === 'sell';
  }));
  const buy = buys.length
    ? mapDocumentToBelegLink(buys[0], {
      label: 'Kaufabrechnung (Pool-Mirror)',
      visibility: 'internal',
      billKind: 'pool_mirror_execution',
    })
    : null;
  const sellLinks = sells.map((d, i) => {
    const partial = (d.get('metadata') || {}).partialSell || {};
    const eventIndex = partial.eventIndex ?? (i + 1);
    return mapDocumentToBelegLink(d, {
      label: sells.length > 1
        ? `Verkaufsabrechnung (Pool-Mirror) #${eventIndex}`
        : 'Verkaufsabrechnung (Pool-Mirror)',
      billKind: 'pool_mirror_execution',
      visibility: 'internal',
      createdAt: partial.executedAt
        || (d.get('createdAt') ? d.get('createdAt').toISOString() : undefined),
    });
  });
  return { buy, sells: sellLinks };
}

function buildInvestorPartialSellInternalBelege(docs) {
  const internal = sortDocsByCreatedAt(docs.filter(isInvestorPartialSellInternal));
  return internal.map((doc, i) => {
    const invId = investmentIdFromDocument(doc);
    const num = doc.get('accountingDocumentNumber') || doc.id?.slice(0, 8);
    return mapDocumentToBelegLink(doc, {
      label: `Eigenbeleg Teilverkauf (intern) · ${num}${internal.length > 1 ? ` #${i + 1}` : ''}`,
      billKind: 'partial_sell',
      visibility: 'internal',
      investmentId: invId,
    });
  });
}

function buildPoolBelege({ poolDocs, participations }) {
  const traderExecution = buildPoolMirrorExecutionBelege(poolDocs);
  const { investorFullSettlement, investorPartialSells: legacyPartialFromCb } = partitionInvestorCollectionBills(
    poolDocs,
    participations,
  );
  const investorPartialSells = buildInvestorPartialSellInternalBelege(poolDocs);
  const mergedPartialSells = investorPartialSells.length > 0
    ? investorPartialSells
    : legacyPartialFromCb;
  return {
    traderExecution,
    investorFullSettlement,
    investorPartialSells: mergedPartialSells,
  };
}

async function loadDocumentsByTradeIds(tradeIds) {
  const ids = [...new Set(tradeIds.filter(Boolean))];
  if (!ids.length) return new Map();

  const q = new Parse.Query('Document');
  q.containedIn('tradeId', ids);
  q.containedIn('type', BELEG_DOCUMENT_TYPES);
  q.limit(2000);
  q.ascending('createdAt');
  const docs = await q.find({ useMasterKey: true });

  const byTrade = new Map();
  for (const doc of docs) {
    const tid = doc.get('tradeId');
    if (!tid) continue;
    if (!byTrade.has(tid)) byTrade.set(tid, []);
    byTrade.get(tid).push(doc);
  }
  return byTrade;
}

function collectTradeIdsFromDraftRows(rows) {
  const ids = new Set();
  for (const row of rows) {
    if (row.tradeId) ids.add(row.tradeId);
    if (row.traderTrade?.tradeId) ids.add(row.traderTrade.tradeId);
    if (row.poolMirrorTrade?.tradeId) ids.add(row.poolMirrorTrade.tradeId);
    if (row.linkedTraderTrade?.tradeId) ids.add(row.linkedTraderTrade.tradeId);
  }
  return [...ids];
}

function resolveTraderTradeIdForRow(row) {
  return row.traderTrade?.tradeId
    || row.linkedTraderTrade?.tradeId
    || (row.legKind === 'trader' || row.legKind === 'standalone' ? row.tradeId : null);
}

function resolveTraderTradeStatusForRow(row) {
  return row.traderTrade?.status
    || row.linkedTraderTrade?.status
    || (row.legKind === 'trader' || row.legKind === 'standalone' ? row.status : null);
}

function collectSellDocsNeedingMetadataEnrichment(rowContexts) {
  const candidates = new Map();
  for (const ctx of rowContexts) {
    if (!ctx.traderTradeId || !shouldShowTraderSellLegs(ctx.executionSplit.sells, ctx.traderTradeStatus)) {
      continue;
    }
    for (const doc of ctx.executionSplit.sells) {
      if (!metadataNeedsBackfill(doc.get('metadata') || {})) continue;
      candidates.set(doc.id, doc);
    }
  }
  return candidates;
}

async function enrichSellLegMetadataByDocId(candidates) {
  const enrichedMetaByDocId = new Map();
  if (!candidates.size) return enrichedMetaByDocId;

  const entries = await Promise.all(
    [...candidates.entries()].map(async ([docId, doc]) => {
      const meta = await enrichTraderDocumentMetadata(doc);
      return [docId, meta];
    }),
  );
  for (const [docId, meta] of entries) {
    enrichedMetaByDocId.set(docId, meta);
  }
  return enrichedMetaByDocId;
}

async function attachBelegeToSummaryRows(rows, docsByTradeId) {
  const rowContexts = rows.map((row) => {
    const traderTradeId = resolveTraderTradeIdForRow(row);
    const poolTradeId = row.poolMirrorTrade?.tradeId || null;
    const traderDocs = traderTradeId ? (docsByTradeId.get(traderTradeId) || []) : [];
    const poolDocs = poolTradeId ? (docsByTradeId.get(poolTradeId) || []) : [];
    const executionSplit = collectTraderExecutionSplit(traderDocs);

    return {
      row,
      traderTradeId,
      poolTradeId,
      traderDocs,
      poolDocs,
      executionSplit,
      traderTradeStatus: resolveTraderTradeStatusForRow(row),
    };
  });

  const enrichedMetaByDocId = await enrichSellLegMetadataByDocId(
    collectSellDocsNeedingMetadataEnrichment(rowContexts),
  );

  return rowContexts.map((ctx) => {
    const traderBelege = ctx.traderTradeId
      ? buildTraderBelege(ctx.traderDocs, ctx.executionSplit)
      : null;
    const traderSellLegs = ctx.traderTradeId
      ? buildTraderSellLegsFromSells(
        ctx.executionSplit.sells,
        ctx.traderTradeStatus,
        enrichedMetaByDocId,
      )
      : [];
    const poolBelege = ctx.poolTradeId
      ? buildPoolBelege({
        poolDocs: ctx.poolDocs,
        participations: ctx.row.poolParticipations || [],
      })
      : null;

    const poolExecutionBelege = poolBelege
      ? {
        buy: poolBelege.traderExecution.buy,
        sell: poolBelege.traderExecution.sells.length > 0
          ? poolBelege.traderExecution.sells[poolBelege.traderExecution.sells.length - 1]
          : null,
      }
      : { buy: null, sell: null };

    return {
      ...ctx.row,
      traderBelege,
      traderSellLegs,
      poolBelege,
      poolExecutionBelege,
    };
  });
}

module.exports = {
  mapDocumentToBelegLink,
  loadDocumentsByTradeIds,
  collectTradeIdsFromDraftRows,
  attachBelegeToSummaryRows,
  collectTraderExecutionSplit,
  buildTraderBelege,
  buildPoolBelege,
  partitionInvestorCollectionBills,
};
