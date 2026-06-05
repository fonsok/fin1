'use strict';

/**
 * Kundenguthaben-Unterkonten (Teil-Verbindlichkeiten, SKR 1590–1592).
 * PTR = PoolTrade-Gebunden (Stückkauf), nicht „Trading“ als Produkt.
 */

/** Sofort verfügbar (SKR 1590). */
const CLT_LIAB_AVA = 'CLT-LIAB-AVA';

/** Für Investments reserviert (SKR 1591). */
const CLT_LIAB_RSV = 'CLT-LIAB-RSV';

/**
 * Im PoolTrade / Stückkauf gebunden (SKR 1592).
 * Früher: CLT-LIAB-TRD (irreführend – klang nach Trader-Trading).
 */
const CLT_LIAB_PTR = 'CLT-LIAB-PTR';

/** Legacy ledger code – nur noch Lesen/Backfill bis Migration durch ist. */
const CLT_LIAB_TRD_LEGACY = 'CLT-LIAB-TRD';

const CLIENT_LIABILITY_ACCOUNTS = [CLT_LIAB_AVA, CLT_LIAB_RSV, CLT_LIAB_PTR];

function normalizeClientLiabilityAccount(account) {
  const code = String(account || '').trim();
  if (code === CLT_LIAB_TRD_LEGACY) return CLT_LIAB_PTR;
  return code;
}

function isPoolTradeParticipationAccount(account) {
  return normalizeClientLiabilityAccount(account) === CLT_LIAB_PTR;
}

/** Mongo/Parse filter: PTR filter includes legacy TRD rows until backfill. */
function expandLedgerAccountFilter(account) {
  const code = String(account || '').trim();
  if (!code) return null;
  if (code === CLT_LIAB_PTR || code === CLT_LIAB_TRD_LEGACY) {
    return [CLT_LIAB_PTR, CLT_LIAB_TRD_LEGACY];
  }
  return [code];
}

module.exports = {
  CLT_LIAB_AVA,
  CLT_LIAB_RSV,
  CLT_LIAB_PTR,
  CLT_LIAB_TRD_LEGACY,
  CLIENT_LIABILITY_ACCOUNTS,
  normalizeClientLiabilityAccount,
  isPoolTradeParticipationAccount,
  expandLedgerAccountFilter,
};
