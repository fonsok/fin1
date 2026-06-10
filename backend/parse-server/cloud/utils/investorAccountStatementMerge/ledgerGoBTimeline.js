'use strict';

const {
  CLT_LIAB_AVA,
  normalizeClientLiabilityAccount,
} = require('../accountingHelper/clientLiabilityAccounts');
const {
  signedAmountFromAvaLedgerRow,
  buildResidualReturnDedupKeys,
  isDuplicateAvaResidualLedgerRow,
} = require('./avaLedger');
const { includeLedgerRowInCustomerMergedTimeline } = require('./mergedTimeline');

/**
 * Investments, für die bereits eine Parse-`investment_activate`-Zeile existiert: dort ist die
 * frühere AVA-`reserve`-Buchung in der kombinierten Saldenrechnung nicht nochmals zu führen
 * (sonst −Reserve und −Activate doppelt).
 */
function investmentIdsWithActivateStmt(stmtEntries) {
  const ids = new Set();
  for (const e of stmtEntries) {
    if (String(e.get('entryType') || '') !== 'investment_activate') continue;
    const id = String(e.get('investmentId') || '').trim();
    if (id) ids.add(id);
  }
  return ids;
}

/**
 * Admin **Ledger (GoB)**: alle `AccountStatement`-Zeilen (inkl. `investment_activate`) plus
 * ausgewählte AVA-`AppLedgerEntry`-Zeilen, die **kein** eigenes `AccountStatement` haben:
 * - `leg=reserve` für Investments **ohne** `investment_activate` (noch reserviert)
 * - `transactionType=appServiceCharge` (App-Servicegebühr brutto auf AVA; Rechnung/Trigger, kein Parse-Kontoauszug)
 * Trade-Settlement-Release-Legs wie in der Kundensicht ausgeblendet (Duplikat von `investment_return`).
 * Für **Admin Ledger (GoB)** können `stmtEntries` vorab mit `expandTraderLedgerStmtEntries` (Trade-Order-Gebührenaufspaltung) angereichert werden — gleiche Logik wie Trader-Details. Wenn Collection-Bill-Metadaten vorliegen, ersetzt `applyInvestorGoBCollectionBillFeeGranularity` aggregierte `trading_fees` desselben Trades durch **Einzelzeilen** laut Beleg: Kaufgebühren am `investment_activate`, Verkaufsgebühren nach letzter `residual_return` (Fallback `investment_return` / `trade_sell`).
 */
function buildInvestorLedgerGoBTimeline({ stmtEntries, avaRows, initialBalance }) {
  const skipReserveForInv = investmentIdsWithActivateStmt(stmtEntries);
  const residualDedupKeys = buildResidualReturnDedupKeys(stmtEntries);
  const combined = [];
  for (const e of stmtEntries) {
    combined.push({
      kind: 'stmt',
      at: e.get('createdAt') || new Date(0),
      tie: e.id,
      amount: parseFloat(Number(e.get('amount') || 0).toFixed(2)),
      stmt: e,
    });
  }
  for (const r of avaRows) {
    if (normalizeClientLiabilityAccount(r.get('account')) !== CLT_LIAB_AVA) continue;
    const tt = String(r.get('transactionType') || '');
    if (tt === 'appServiceCharge') {
      combined.push({
        kind: 'ledger',
        at: r.get('createdAt') || new Date(0),
        tie: r.id,
        amount: signedAmountFromAvaLedgerRow(r),
        ledger: r,
      });
      continue;
    }
    if (tt !== 'investmentEscrow') continue;
    const meta = r.get('metadata') || {};
    const leg = String(meta.leg || '').trim();
    if (leg !== 'reserve') continue;
    if (isDuplicateAvaResidualLedgerRow(r, residualDedupKeys)) continue;
    const refType = String(r.get('referenceType') || '');
    const invId = refType === 'Investment' ? String(r.get('referenceId') || '').trim() : '';
    if (!invId || skipReserveForInv.has(invId)) continue;
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
  const timelineRows = combined.filter(includeLedgerRowInCustomerMergedTimeline);
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
  buildInvestorLedgerGoBTimeline,
};
