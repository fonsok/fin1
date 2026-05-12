'use strict';

const {
  buildChecks,
  aggregateAccountStatements,
  aggregateAppLedger,
  evaluatePeriodNetPairRules,
} = require('../financialReconciliation');
const { PERIOD_NET_ZERO_PAIRS } = require('../financialReconciliationRules');

describe('financialReconciliation', () => {
  it('aggregateAccountStatements sums and detects missing BC', () => {
    const fake = [
      { get: (k) => ({ amount: 10, entryType: 'deposit', businessCaseId: 'bc1', source: 'backend', referenceDocumentId: 'd1', referenceDocumentNumber: 'n1' }[k]) },
      { get: (k) => ({ amount: -3, entryType: 'deposit', businessCaseId: '', source: 'backend', referenceDocumentId: 'd2', referenceDocumentNumber: 'n2' }[k]) },
    ];
    const agg = aggregateAccountStatements(fake);
    expect(agg.rowCount).toBe(2);
    expect(agg.sumAmount).toBe(7);
    expect(agg.missingBusinessCaseId).toBe(1);
    expect(agg.missingReferenceDocument).toBe(0);
  });

  it('buildChecks flags commission asymmetry', () => {
    const stmtAgg = {
      rowCount: 2,
      sumAmount: 0,
      byEntryType: {
        commission_debit: { count: 1, sumAmount: -100 },
        commission_credit: { count: 1, sumAmount: 50 },
      },
      missingBusinessCaseId: 0,
      missingReferenceDocument: 0,
    };
    const ledgerAgg = {
      rowCount: 0,
      byAccount: {},
      missingBusinessCaseId: 0,
    };
    const bankAgg = { rowCount: 0, byAccount: {} };
    const checks = buildChecks(
      { stmtAgg, ledgerAgg, bankAgg, byEntryType: stmtAgg.byEntryType },
      { truncated: false, stmtTrunc: false, ledgerTrunc: false, bankTrunc: false },
    );
    const asym = checks.find((c) => c.id === 'commission_statement_asymmetry');
    expect(asym).toBeDefined();
    expect(asym.severity).toBe('warning');
  });

  it('evaluatePeriodNetPairRules: balanced tradeCash nets sum to ~0', () => {
    const byType = {
      'CLT-LIAB-AVA': {
        tradeCash: { netDebitMinusCredit: 100 },
      },
      'BANK-TRT-CLT': {
        tradeCash: { netDebitMinusCredit: -100 },
      },
    };
    const results = evaluatePeriodNetPairRules(byType, PERIOD_NET_ZERO_PAIRS);
    const trade = results.find((r) => r.id === 'trade_cash_ava_trust');
    expect(trade).toBeDefined();
    expect(trade.ok).toBe(true);
  });

  it('evaluatePeriodNetPairRules: mismatch flags ok=false', () => {
    const byType = {
      'CLT-LIAB-AVA': { tradeCash: { netDebitMinusCredit: 50 } },
      'BANK-TRT-CLT': { tradeCash: { netDebitMinusCredit: -40 } },
    };
    const results = evaluatePeriodNetPairRules(byType, PERIOD_NET_ZERO_PAIRS);
    const trade = results.find((r) => r.id === 'trade_cash_ava_trust');
    expect(trade).toBeDefined();
    expect(trade.ok).toBe(false);
  });
});
