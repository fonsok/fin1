'use strict';

const { round2 } = require('../../../utils/accountingHelper/shared');
const { summarizeTimelineAmounts } = require('./timelineTotals');

/**
 * Admin ledger view: raw `AccountStatement` rows (GoB), incl. `trading_fees` per leg.
 */
function buildLedgerAccountStatementFromStmtEntries(
  stmtEntries,
  initialBalance,
  formatDate,
  sourceTruncated,
) {
  const sorted = [...stmtEntries].sort((a, b) => {
    const ta = (a.get('createdAt') || new Date(0)).getTime();
    const tb = (b.get('createdAt') || new Date(0)).getTime();
    if (ta !== tb) return ta - tb;
    return String(a.id).localeCompare(String(b.id));
  });

  let running = round2(initialBalance);
  const entries = [];
  const timelineForTotals = [];

  for (const e of sorted) {
    const amount = round2(Number(e.get('amount') || 0));
    running = round2(running + amount);
    entries.push({
      objectId: e.id,
      entryType: String(e.get('entryType') || ''),
      amount,
      balanceAfter: running,
      tradeId: e.get('tradeId') || undefined,
      tradeNumber: e.get('tradeNumber') ?? undefined,
      investmentId: e.get('investmentId') || undefined,
      description: e.get('description') || String(e.get('entryType') || ''),
      referenceDocumentId: e.get('referenceDocumentId') || null,
      referenceDocumentNumber: e.get('referenceDocumentNumber') || null,
      source: e.get('source') || 'backend',
      createdAt: formatDate(e.get('createdAt')),
    });
    timelineForTotals.push({ amount, balanceAfter: running });
  }

  const totals = summarizeTimelineAmounts(timelineForTotals, initialBalance);
  return {
    initialBalance,
    closingBalance: totals.closingBalance,
    totalCredits: totals.totalCredits,
    totalDebits: totals.totalDebits,
    netChange: totals.netChange,
    entries,
    sortOrder: 'asc',
    timelineTruncated: Boolean(sourceTruncated),
    presentationMode: 'ledger',
  };
}

module.exports = {
  buildLedgerAccountStatementFromStmtEntries,
};
