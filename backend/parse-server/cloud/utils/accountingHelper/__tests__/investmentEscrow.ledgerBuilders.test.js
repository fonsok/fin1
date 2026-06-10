'use strict';

/**
 * Submodule-direct tests for paired ledger entry construction (balanced debit/credit).
 */
const { buildPairedLedgerEntries } = require('../investmentEscrow/ledgerBuilders');

class FakeAppLedgerEntry {
  constructor() {
    this.attrs = {};
    this.id = undefined;
  }

  set(k, v) {
    this.attrs[k] = v;
  }

  get(k) {
    return this.attrs[k];
  }
}

jest.mock('../accountMappingResolver', () => ({
  applyLedgerSnapshotToEntry: jest.fn((_row, account) => ({ accountCode: account })),
  mergeMetadataWithSnapshot: jest.fn((meta, snapshot) => Object.assign({}, meta, snapshot)),
}));

describe('investmentEscrow/ledgerBuilders (submodule)', () => {
  beforeEach(() => {
    global.Parse = {
      Object: {
        extend(className) {
          if (className !== 'AppLedgerEntry') {
            throw new Error(`Unexpected extend: ${className}`);
          }
          return FakeAppLedgerEntry;
        },
      },
    };
  });

  it('buildPairedLedgerEntries returns balanced debit/credit with shared reference fields', () => {
    const common = {
      userId: 'investor-1',
      userRole: 'investor',
      transactionType: 'investmentEscrow',
      referenceId: 'inv-42',
      referenceType: 'Investment',
      description: 'reserve',
      metadata: { leg: 'reserve' },
    };

    const [debit, credit] = buildPairedLedgerEntries(
      'CLT-LIAB-AVA',
      'CLT-LIAB-RSV',
      1000,
      common,
    );

    expect(debit.get('side')).toBe('debit');
    expect(credit.get('side')).toBe('credit');
    expect(debit.get('amount')).toBe(1000);
    expect(credit.get('amount')).toBe(1000);
    expect(debit.get('account')).toBe('CLT-LIAB-AVA');
    expect(credit.get('account')).toBe('CLT-LIAB-RSV');
    expect(debit.get('referenceId')).toBe('inv-42');
    expect(credit.get('referenceId')).toBe('inv-42');
    expect(debit.get('metadata').pairedAccount).toBe('CLT-LIAB-RSV');
    expect(credit.get('metadata').pairedAccount).toBe('CLT-LIAB-AVA');
  });
});
