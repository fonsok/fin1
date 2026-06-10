'use strict';

/**
 * Submodule-direct tests (not via facade) — dedup + signing rules for AVA rows.
 */
const {
  signedAmountFromAvaLedgerRow,
  syntheticEntryTypeFromLedgerRow,
  buildResidualReturnDedupKeys,
  isDuplicateAvaResidualLedgerRow,
} = require('../investorAccountStatementMerge/avaLedger');

function mockRow(attrs) {
  return {
    get: (key) => attrs[key],
  };
}

describe('investorAccountStatementMerge/avaLedger (submodule)', () => {
  it('signedAmountFromAvaLedgerRow treats debit as negative', () => {
    const row = mockRow({ amount: 100, side: 'debit' });
    expect(signedAmountFromAvaLedgerRow(row)).toBe(-100);
  });

  it('signedAmountFromAvaLedgerRow treats credit as positive', () => {
    const row = mockRow({ amount: 42.5, side: 'credit' });
    expect(signedAmountFromAvaLedgerRow(row)).toBe(42.5);
  });

  it('syntheticEntryTypeFromLedgerRow maps investmentEscrow legs', () => {
    const row = mockRow({
      transactionType: 'investmentEscrow',
      metadata: { leg: 'reserve' },
    });
    expect(syntheticEntryTypeFromLedgerRow(row)).toBe('investment_escrow_reserve');
  });

  it('buildResidualReturnDedupKeys and isDuplicateAvaResidualLedgerRow dedup residual_return', () => {
    const stmt = mockRow({
      entryType: 'residual_return',
      investmentId: 'inv-1',
      tradeId: 'trade-9',
      amount: 50,
    });
    const keys = buildResidualReturnDedupKeys([stmt]);

    const duplicateAva = mockRow({
      account: 'CLT-LIAB-AVA',
      side: 'credit',
      referenceType: 'Investment',
      referenceId: 'inv-1',
      amount: 50,
      metadata: { leg: 'reserveCapitalTradeSplit', splitPart: 'available', tradeId: 'trade-9' },
    });
    expect(isDuplicateAvaResidualLedgerRow(duplicateAva, keys)).toBe(true);

    const nonDuplicateLeg = mockRow({
      account: 'CLT-LIAB-AVA',
      side: 'credit',
      referenceType: 'Investment',
      referenceId: 'inv-1',
      amount: 50,
      metadata: { leg: 'reserveCapitalTradeSplit', splitPart: 'pool', tradeId: 'trade-9' },
    });
    expect(isDuplicateAvaResidualLedgerRow(nonDuplicateLeg, keys)).toBe(false);
  });
});
