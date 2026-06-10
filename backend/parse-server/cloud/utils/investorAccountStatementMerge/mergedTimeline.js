'use strict';

const { INTERNAL_TRADE_SETTLEMENT_RELEASE_LEGS } = require('./shared');
const {
  signedAmountFromAvaLedgerRow,
  buildResidualReturnDedupKeys,
  isDuplicateAvaResidualLedgerRow,
} = require('./avaLedger');

/**
 * @param {{ kind: 'stmt'|'ledger', at: Date, tie: string, amount: number, stmt?: Parse.Object, ledger?: Parse.Object }} row
 * @returns {boolean}
 */
function includeLedgerRowInCustomerMergedTimeline(row) {
  if (row.kind !== 'ledger') return true;
  const meta = row.ledger.get('metadata') || {};
  const leg = String(meta.leg || '').trim();
  return !INTERNAL_TRADE_SETTLEMENT_RELEASE_LEGS.has(leg);
}

/**
 * Chronologische Zeitleiste: Parse AccountStatement + Investor-AVA-AppLedger.
 * @param {{ stmtEntries: Parse.Object[], avaRows: Parse.Object[], initialBalance: number, includeInternalTradeSettlementLegs?: boolean }} p — optional `includeInternalTradeSettlementLegs: true` keeps AVA `tradeSettlementPoolRelease` / `tradeSettlementProfitRelease` (normally hidden; they duplicate `investment_return`).
 * @returns {Array<{ kind: 'stmt'|'ledger', at: Date, tie: string, amount: number, balanceAfter: number, stmt?: Parse.Object, ledger?: Parse.Object }>}
 */
function buildInvestorMergedTimeline({
  stmtEntries,
  avaRows,
  initialBalance,
  includeInternalTradeSettlementLegs = false,
}) {
  const residualDedupKeys = buildResidualReturnDedupKeys(stmtEntries);
  const combined = [];
  for (const e of stmtEntries) {
    // Internal RSV→TRD move; visible on AVA sub-ledger as investment_escrow_deploy.
    if (String(e.get('entryType') || '') === 'investment_activate') {
      continue;
    }
    combined.push({
      kind: 'stmt',
      at: e.get('createdAt') || new Date(0),
      tie: e.id,
      amount: parseFloat(Number(e.get('amount') || 0).toFixed(2)),
      stmt: e,
    });
  }
  for (const r of avaRows) {
    if (isDuplicateAvaResidualLedgerRow(r, residualDedupKeys)) {
      continue;
    }
    combined.push({
      kind: 'ledger',
      at: r.get('createdAt') || new Date(0),
      tie: r.id,
      amount: signedAmountFromAvaLedgerRow(r),
      ledger: r,
    });
  }
  combined.sort((a, b) => {
    const ta = a.at instanceof Date ? a.at.getTime() : 0;
    const tb = b.at instanceof Date ? b.at.getTime() : 0;
    if (ta !== tb) return ta - tb;
    return String(a.tie).localeCompare(String(b.tie));
  });
  const timelineRows = includeInternalTradeSettlementLegs
    ? combined
    : combined.filter(includeLedgerRowInCustomerMergedTimeline);
  let running = initialBalance;
  return timelineRows.map((row) => {
    const balanceBefore = parseFloat(running.toFixed(2));
    running += row.amount;
    const balanceAfter = parseFloat(running.toFixed(2));
    return {
      ...row,
      balanceBefore,
      balanceAfter,
    };
  });
}

module.exports = {
  includeLedgerRowInCustomerMergedTimeline,
  buildInvestorMergedTimeline,
};
