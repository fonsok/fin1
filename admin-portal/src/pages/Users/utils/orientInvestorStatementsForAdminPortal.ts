import type { AccountStatementData } from '../../../api/admin';

/**
 * Wie stark ein Payload der **gemergten App-/Kundensicht** entspricht (höher = eher Merge).
 * Merge (`buildInvestorMergedTimeline`) kann `app_subledger` / `app-ledger:*`-Zeilen haben, hat
 * **keine** `investment_activate`, und blendet `tradeSettlementPoolRelease` / `tradeSettlementProfitRelease` aus
 * Roh-GoB-Admin (`buildInvestorLedgerGoBTimeline`) typischerweise
 * `presentationMode: 'ledger'`, oft `investment_activate`, plus `app_subledger` für Reserve (offen) und `appServiceCharge`.
 */
function mergedLikeness(stmt: AccountStatementData): number {
  let score = 0;
  const hasActivate = stmt.entries.some((e) => e.entryType === 'investment_activate');
  if (stmt.entries.some((e) => e.source === 'app_subledger')) score += 100;
  if (stmt.entries.some((e) => String(e.objectId).startsWith('app-ledger:'))) score += 50;
  if (!hasActivate) score += 25;
  if (stmt.presentationMode === 'customer' && !hasActivate) score += 5;
  if (stmt.presentationMode === 'ledger') score += 3;
  /** API-Feld heißt „customer“, Inhalt ist aber Roh-GoB — stark depriorisieren. */
  if (stmt.presentationMode === 'customer' && hasActivate) score -= 120;
  return score;
}

/**
 * Ordnet `accountStatement` / `accountStatementLedger` für die Admin-UI zu:
 * `customerStatement` = Merge (wie `getAccountStatement` Investor),
 * `ledgerStatement` = Parse-`AccountStatement` + offene AVA-`reserve`-Legs (Admin GoB, siehe `buildInvestorLedgerGoBTimeline`).
 */
export function orientInvestorStatementsForAdminPortal(
  role: string,
  accountStatement: AccountStatementData | null | undefined,
  accountStatementLedger: AccountStatementData | null | undefined,
): {
  customerStatement: AccountStatementData | null | undefined;
  ledgerStatement: AccountStatementData | null | undefined;
} {
  if (!accountStatement) {
    return { customerStatement: null, ledgerStatement: accountStatementLedger };
  }
  if (String(role).toLowerCase() !== 'investor' || !accountStatementLedger) {
    return { customerStatement: accountStatement, ledgerStatement: accountStatementLedger };
  }

  const main = accountStatement;
  const ledger = accountStatementLedger;
  const scoreMain = mergedLikeness(main);
  const scoreLedger = mergedLikeness(ledger);

  if (scoreMain > scoreLedger) {
    return { customerStatement: main, ledgerStatement: ledger };
  }
  if (scoreLedger > scoreMain) {
    return { customerStatement: ledger, ledgerStatement: main };
  }

  /** Gleichstand: explizite Präsentations-Paarung */
  if (main.presentationMode === 'ledger' && ledger.presentationMode === 'customer') {
    return { customerStatement: ledger, ledgerStatement: main };
  }

  /** API-Konvention: erstes Feld = Kundensicht */
  return { customerStatement: main, ledgerStatement: ledger };
}
