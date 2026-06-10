'use strict';

const {
  reconcileSettlementGLForTrade,
  hasLedgerLegForStatement,
} = require('../settlementGLReconciliation');

describe('settlementGLReconciliation', () => {
  test('healthy when each investor commission_debit has scoped GL leg', () => {
    const tradeId = 'pool-1';
    const statements = [
      {
        id: 's1',
        entryType: 'commission_debit',
        amount: -116.21,
        investmentId: 'inv-a',
        userId: 'u-a',
        tradeId,
        source: 'backend',
      },
      {
        id: 's2',
        entryType: 'commission_debit',
        amount: -233.02,
        investmentId: 'inv-b',
        userId: 'u-b',
        tradeId,
        source: 'backend',
      },
    ];
    const ledger = [
      {
        account: 'PLT-LIAB-COM',
        side: 'credit',
        amount: 116.21,
        transactionType: 'commission',
        referenceId: tradeId,
        userId: 'u-a',
        metadata: { leg: 'commission:inv:inv-a' },
      },
      {
        account: 'PLT-LIAB-COM',
        side: 'credit',
        amount: 233.02,
        transactionType: 'commission',
        referenceId: tradeId,
        userId: 'u-b',
        metadata: { leg: 'commission:inv:inv-b' },
      },
    ];

    expect(reconcileSettlementGLForTrade(tradeId, statements, ledger)).toEqual([]);
  });

  test('flags missing_gl_leg when second investor has no GL pair', () => {
    const tradeId = 'pool-1';
    const statements = [
      {
        id: 's1',
        entryType: 'commission_debit',
        amount: -116.21,
        investmentId: 'inv-a',
        userId: 'u-a',
        tradeId,
        source: 'backend',
      },
      {
        id: 's2',
        entryType: 'commission_debit',
        amount: -116.21,
        investmentId: 'inv-b',
        userId: 'u-b',
        tradeId,
        source: 'backend',
      },
    ];
    const ledger = [
      {
        account: 'PLT-LIAB-COM',
        side: 'credit',
        amount: 116.21,
        transactionType: 'commission',
        referenceId: tradeId,
        userId: 'u-a',
        metadata: { leg: 'commission:inv:inv-a' },
      },
    ];

    const violations = reconcileSettlementGLForTrade(tradeId, statements, ledger);
    expect(violations.some((v) => v.type === 'missing_gl_leg' && v.investmentId === 'inv-b')).toBe(true);
    expect(violations.some((v) => v.type === 'plt_liab_com_credit_mismatch')).toBe(true);
  });

  test('flags legacy_gl_leg_only when only trade-level commission leg exists', () => {
    const stmt = {
      id: 's1',
      entryType: 'commission_debit',
      amount: -116.21,
      investmentId: 'inv-a',
      userId: 'u-a',
      tradeId: 'pool-1',
      source: 'backend',
    };
    const ledger = [{
      account: 'PLT-LIAB-COM',
      side: 'credit',
      amount: 116.21,
      transactionType: 'commission',
      referenceId: 'pool-1',
      userId: 'u-a',
      metadata: { leg: 'commission' },
    }];

    const check = hasLedgerLegForStatement(stmt, ledger);
    expect(check.ok).toBe(false);
    expect(check.mode).toBe('legacy_only');
  });

  test('trader commission_credit requires PLT-LIAB-COM debit', () => {
    const tradeId = 'trader-1';
    const statements = [{
      id: 's1',
      entryType: 'commission_credit',
      amount: 581.65,
      investmentId: '',
      userId: 'trader',
      tradeId,
      source: 'backend',
    }];
    const ledger = [{
      account: 'PLT-LIAB-COM',
      side: 'debit',
      amount: 581.65,
      transactionType: 'commission',
      referenceId: tradeId,
      userId: 'trader',
      metadata: { leg: 'commission' },
    }];

    expect(reconcileSettlementGLForTrade(tradeId, statements, ledger)).toEqual([]);
  });
});
