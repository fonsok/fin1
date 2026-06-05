'use strict';

const { summarizeInvestorOutcomeHighlights } = require('../usersDetailStatementOutcomeSummary');

describe('summarizeInvestorOutcomeHighlights', () => {
  test('aggregates merged statement buckets', () => {
    const out = summarizeInvestorOutcomeHighlights([
      { entryType: 'investment_profit', amount: 200 },
      { entryType: 'investment_return', amount: 1000 },
      { entryType: 'residual_return', amount: 0.2 },
      { entryType: 'app_service_charge', amount: -60 },
      { entryType: 'commission_debit', amount: -20 },
      { entryType: 'withholding_tax_debit', amount: -25 },
      { entryType: 'trade_sell', amount: 500 },
      { entryType: 'trade_buy', amount: -400 },
      { entryType: 'deposit', amount: 10000 },
      { entryType: 'withdrawal', amount: -500 },
      { entryType: 'commission_credit', amount: 15 },
    ]);
    expect(out.sumProfitReturnsResiduals).toBe(1215.2);
    expect(out.sumFees).toBe(80);
    expect(out.sumTaxesWithheld).toBe(25);
    expect(out.sumTradeCashAndOrderFees).toBe(100);
    expect(out.sumDepositsWithdrawals).toBe(9500);
  });

  test('returns null for empty list', () => {
    expect(summarizeInvestorOutcomeHighlights([])).toBeNull();
  });
});
