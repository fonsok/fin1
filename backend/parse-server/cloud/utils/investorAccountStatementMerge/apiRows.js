'use strict';

const { round2 } = require('../accountingHelper/shared');
const { iso } = require('./shared');
const {
  signedAmountFromAvaLedgerRow,
  syntheticEntryTypeFromLedgerRow,
} = require('./avaLedger');

function timelineRowMatchesEntryType(row, entryType) {
  if (!entryType) return true;
  if (row.kind === 'stmt') {
    return String(row.stmt.get('entryType') || '') === entryType;
  }
  return syntheticEntryTypeFromLedgerRow(row.ledger) === entryType;
}

function buildStmtApiRow(e, userId, balanceBefore, balanceAfter) {
  const j = e.toJSON();
  j.userId = userId;
  j.balanceBefore = round2(balanceBefore);
  j.balanceAfter = round2(balanceAfter);
  if (j.createdAt && typeof j.createdAt === 'object' && j.createdAt.__type === 'Date') {
    j.createdAt = new Date(j.createdAt.iso).toISOString();
  }
  return j;
}

function buildLedgerSyntheticApiRow(r, userId, balanceBefore, balanceAfter) {
  const meta = r.get('metadata') || {};
  const refType = String(r.get('referenceType') || '');
  const investmentId = refType === 'Investment' ? r.get('referenceId') : null;
  const entryType = syntheticEntryTypeFromLedgerRow(r);
  const created = r.get('createdAt');
  const amt = signedAmountFromAvaLedgerRow(r);
  const investmentNumber = String(meta.investmentNumber || '').trim() || null;
  return {
    objectId: `app-ledger:${r.id}`,
    userId,
    entryType,
    amount: amt,
    balanceBefore: round2(balanceBefore),
    balanceAfter: round2(balanceAfter),
    tradeId: r.get('tradeId') || null,
    tradeNumber: r.get('tradeNumber') ?? null,
    investmentId,
    investmentNumber,
    businessReference: investmentNumber || meta.businessReference || null,
    description: r.get('description') || entryType,
    source: 'app_subledger',
    referenceDocumentId: meta.referenceDocumentId || null,
    referenceDocumentNumber: meta.referenceDocumentNumber || null,
    createdAt: iso(created),
  };
}

/**
 * JSON-Zeilen für App/API (ISO-Datum), aufsteigend sortiert (älteste zuerst), mit Pagination.
 */
function mergedTimelineToApiRows(user, timeline, opts) {
  const { entryType, limit, skip } = opts;
  const filtered = entryType
    ? timeline.filter((row) => timelineRowMatchesEntryType(row, entryType))
    : timeline;
  const asc = [...filtered].sort((a, b) => {
    const ta = a.at instanceof Date ? a.at.getTime() : 0;
    const tb = b.at instanceof Date ? b.at.getTime() : 0;
    if (ta !== tb) return ta - tb;
    return String(a.tie).localeCompare(String(b.tie));
  });
  const page = asc.slice(skip, skip + limit);
  const canonicalUserId = user.get('stableId') || user.id;
  const rows = page.map((row) => (row.kind === 'stmt'
    ? buildStmtApiRow(row.stmt, canonicalUserId, row.balanceBefore, row.balanceAfter)
    : buildLedgerSyntheticApiRow(row.ledger, canonicalUserId, row.balanceBefore, row.balanceAfter)));
  return { rows, total: filtered.length };
}

/** @deprecated Use mergedTimelineToApiRows (ascending). Kept for older imports. */
function mergedTimelineToDescendingApiRows(user, timeline, opts) {
  return mergedTimelineToApiRows(user, timeline, opts);
}

module.exports = {
  timelineRowMatchesEntryType,
  mergedTimelineToApiRows,
  mergedTimelineToDescendingApiRows,
};
