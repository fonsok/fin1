'use strict';

const BELEG_DOCUMENT_TYPES = [
  'traderCollectionBill',
  'trade_execution_document',
  'poolMirrorExecutionEigenbeleg',
  'invoice',
  'traderCreditNote',
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
  const createdAt = doc.get('createdAt');
  return {
    documentId: doc.id,
    documentNumber: doc.get('accountingDocumentNumber') || '',
    documentType: doc.get('type') || '',
    executionType,
    label: overrides.label || defaultBelegLabel(doc),
    investmentId: overrides.investmentId ?? investmentIdFromDocument(doc) ?? undefined,
    investorId: overrides.investorId ?? (doc.get('userId') || undefined),
    createdAt: createdAt ? createdAt.toISOString() : undefined,
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

function buildTraderExecutionBelege(docs) {
  const exec = docs.filter(isTraderExecutionDoc);
  const buys = sortDocsByCreatedAt(exec.filter((d) => {
    const ex = String((d.get('metadata') || {}).executionType || '').toLowerCase();
    return ex === 'buy' || /kauf|buy/i.test(d.get('name') || '');
  }));
  const sells = sortDocsByCreatedAt(exec.filter((d) => {
    const ex = String((d.get('metadata') || {}).executionType || '').toLowerCase();
    return ex === 'sell' || /verkauf|sell/i.test(d.get('name') || '');
  }));
  const buy = buys.length ? mapDocumentToBelegLink(buys[0]) : null;
  const sellLinks = sells.map((d, i) => mapDocumentToBelegLink(d, {
    label: sells.length > 1
      ? `Verkaufsabrechnung (Trader) #${i + 1}`
      : 'Verkaufsabrechnung (Trader)',
    billKind: 'execution_sell',
    visibility: 'customer',
  }));
  return { buy, sells: sellLinks };
}

function buildTraderBelege(docs) {
  const traderExecution = buildTraderExecutionBelege(docs);
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
  const sells = sortDocsByCreatedAt(exec.filter((d) => {
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
  const sellLinks = sells.map((d, i) => mapDocumentToBelegLink(d, {
    label: sells.length > 1
      ? `Verkaufsabrechnung (Pool-Mirror) #${i + 1}`
      : 'Verkaufsabrechnung (Pool-Mirror)',
    billKind: 'pool_mirror_execution',
    visibility: 'internal',
  }));
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

function attachBelegeToSummaryRows(rows, docsByTradeId) {
  return rows.map((row) => {
    const traderTradeId =
      row.traderTrade?.tradeId
      || row.linkedTraderTrade?.tradeId
      || (row.legKind === 'trader' || row.legKind === 'standalone' ? row.tradeId : null);
    const poolTradeId = row.poolMirrorTrade?.tradeId || null;

    const traderDocs = traderTradeId ? (docsByTradeId.get(traderTradeId) || []) : [];
    const poolDocs = poolTradeId ? (docsByTradeId.get(poolTradeId) || []) : [];

    const traderBelege = traderTradeId ? buildTraderBelege(traderDocs) : null;
    const poolBelege = poolTradeId
      ? buildPoolBelege({
        poolDocs,
        participations: row.poolParticipations || [],
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
      ...row,
      traderBelege,
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
  buildTraderBelege,
  buildPoolBelege,
  partitionInvestorCollectionBills,
};
