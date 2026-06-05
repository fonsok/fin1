'use strict';

const { round2 } = require('../../utils/accountingHelper/shared');

/**
 * Aggregiert den gemergten Investor-Kontoauszug (Admin) zu Kennzahlen für
 * Support / interne Abstimmung — keine Steuerbescheinigung.
 *
 * @param {Array<{ entryType?: string, amount?: number }>} entries
 * @returns {object|null}
 */
function summarizeInvestorOutcomeHighlights(entries) {
  if (!Array.isArray(entries) || entries.length === 0) {
    return null;
  }

  let profitAndReturns = 0;
  let fees = 0;
  let taxes = 0;
  let tradeCash = 0;
  let depositsWithdrawals = 0;

  for (const e of entries) {
    const t = String(e.entryType || '');
    const a = Number(e.amount);
    if (!Number.isFinite(a)) continue;

    if (t === 'investment_profit' || t === 'investment_return' || t === 'residual_return') {
      profitAndReturns += a;
    } else if (t === 'app_service_charge' || t === 'commission_debit') {
      fees += Math.abs(a);
    } else if (
      t === 'withholding_tax_debit'
      || t === 'solidarity_surcharge_debit'
      || t === 'church_tax_debit'
    ) {
      taxes += Math.abs(a);
    } else if (t === 'trade_buy' || t === 'trade_sell' || t === 'trading_fees') {
      tradeCash += a;
    } else if (t === 'deposit' || t === 'withdrawal') {
      depositsWithdrawals += a;
    } else if (t === 'commission_credit') {
      profitAndReturns += a;
    }
  }

  return {
    sumProfitReturnsResiduals: round2(profitAndReturns),
    sumFees: round2(fees),
    sumTaxesWithheld: round2(taxes),
    sumTradeCashAndOrderFees: round2(tradeCash),
    sumDepositsWithdrawals: round2(depositsWithdrawals),
    disclaimer:
      'Kurzauswertung aus dem gemergten Kontoauszug (intern, nur Lesen). '
      + 'Keine Steuerbescheinigung und kein Ersatz für Beratung durch Steuer/Legal.',
  };
}

module.exports = {
  summarizeInvestorOutcomeHighlights,
};
