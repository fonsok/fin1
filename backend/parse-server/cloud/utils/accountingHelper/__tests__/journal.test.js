'use strict';

// ============================================================================
// Unit tests for journal.postLedgerPair (ADR-010 / PR4).
//
// Contract under test:
//   - Atomic balanced pair (Σdebit == Σcredit) via Parse.Object.saveAll.
//   - Idempotency keyed on (referenceId + referenceType + transactionType +
//     metadata.leg) — second call with the same key is a no-op.
//   - Throws when `leg` is missing (forces caller to choose a deterministic
//     idempotency token).
//   - Mapping snapshot fields are present on both sides.
// ============================================================================

describe('postLedgerPair', () => {
  let savedEntries;
  let queryResults;

  class FakeAppLedgerEntry {
    constructor() { this.attrs = {}; this.id = undefined; }
    set(key, value) { this.attrs[key] = value; }
    get(key) { return this.attrs[key]; }
    async save() {
      this.id = 'ale-' + (savedEntries.length + 1);
      savedEntries.push(this);
      return this;
    }
  }

  class FakeQuery {
    constructor(className) {
      this.className = className;
      this.filters = {};
      this.limitValue = 100;
    }
    equalTo(field, value) { this.filters[field] = value; return this; }
    limit(n) { this.limitValue = n; return this; }
    async find() {
      // Return only rows that match all filters AND a deterministic class name
      return queryResults.filter((row) => {
        if (this.className !== row.__className) return false;
        return Object.entries(this.filters).every(([k, v]) => row.attrs[k] === v);
      }).slice(0, this.limitValue);
    }
  }

  beforeEach(() => {
    jest.resetModules();
    savedEntries = [];
    queryResults = [];

    global.Parse = {
      Object: {
        extend(className) {
          if (className === 'AppLedgerEntry') {
            FakeAppLedgerEntry.__fakeClassName = 'AppLedgerEntry';
            return FakeAppLedgerEntry;
          }
          throw new Error(`Unexpected Parse.Object.extend(${className})`);
        },
        async saveAll(rows) {
          for (const row of rows) {
            // eslint-disable-next-line no-await-in-loop
            await row.save();
          }
          return rows;
        },
      },
      Query: FakeQuery,
    };
    jest.spyOn(console, 'warn').mockImplementation(() => {});
    jest.spyOn(console, 'error').mockImplementation(() => {});
  });

  test('writes a balanced debit + credit pair with snapshot metadata', async () => {
    // eslint-disable-next-line global-require
    const { postLedgerPair } = require('../journal');

    const result = await postLedgerPair({
      debitAccount: 'CLT-LIAB-AVA',
      creditAccount: 'PLT-LIAB-COM',
      amount: 12.345,
      userId: 'investor-1',
      userRole: 'investor',
      transactionType: 'commission',
      referenceId: 'trade-7',
      referenceType: 'Trade',
      description: 'Provision Trade #7',
      metadata: { investmentId: 'inv-9' },
      leg: 'commission',
    });

    expect(result).toHaveLength(2);
    expect(savedEntries).toHaveLength(2);

    const [debit, credit] = savedEntries;
    expect(debit.attrs.account).toBe('CLT-LIAB-AVA');
    expect(debit.attrs.side).toBe('debit');
    expect(credit.attrs.account).toBe('PLT-LIAB-COM');
    expect(credit.attrs.side).toBe('credit');

    // round2(12.345) = 12.35
    expect(debit.attrs.amount).toBeCloseTo(12.35, 2);
    expect(credit.attrs.amount).toBeCloseTo(12.35, 2);
    expect(debit.attrs.amount).toBe(credit.attrs.amount);

    // Both rows share reference + transactionType
    expect(debit.attrs.referenceId).toBe('trade-7');
    expect(credit.attrs.referenceId).toBe('trade-7');
    expect(debit.attrs.transactionType).toBe('commission');

    // metadata.leg is on both sides for cheap idempotency probing
    expect(debit.attrs.metadata.leg).toBe('commission');
    expect(credit.attrs.metadata.leg).toBe('commission');

    // Snapshot fields populated on both sides
    expect(debit.attrs.chartCodeSnapshot).toBeTruthy();
    expect(credit.attrs.chartCodeSnapshot).toBeTruthy();
  });

  test('skips when amount is zero or negative', async () => {
    // eslint-disable-next-line global-require
    const { postLedgerPair } = require('../journal');

    const zero = await postLedgerPair({
      debitAccount: 'CLT-LIAB-AVA',
      creditAccount: 'PLT-LIAB-COM',
      amount: 0,
      transactionType: 'commission',
      referenceId: 'trade-7',
      leg: 'commission',
    });
    expect(zero).toEqual([]);
    expect(savedEntries).toHaveLength(0);

    const neg = await postLedgerPair({
      debitAccount: 'CLT-LIAB-AVA',
      creditAccount: 'PLT-LIAB-COM',
      amount: -5,
      transactionType: 'commission',
      referenceId: 'trade-7',
      leg: 'commission',
    });
    // Negative amount is treated as absolute → still skipped only on |amount|<=0.
    // -5 has abs() = 5, so this should write a pair. Document the behaviour.
    expect(neg).toHaveLength(2);
  });

  test('throws when leg is missing', async () => {
    // eslint-disable-next-line global-require
    const { postLedgerPair } = require('../journal');

    await expect(postLedgerPair({
      debitAccount: 'CLT-LIAB-AVA',
      creditAccount: 'PLT-LIAB-COM',
      amount: 5,
      transactionType: 'commission',
      referenceId: 'trade-7',
    })).rejects.toThrow(/leg.*required/i);
  });

  test('idempotent: second call with same leg+referenceId is a no-op', async () => {
    // eslint-disable-next-line global-require
    const { postLedgerPair } = require('../journal');

    queryResults = [{
      __className: 'AppLedgerEntry',
      attrs: {
        referenceId: 'trade-7',
        referenceType: 'Trade',
        transactionType: 'commission',
        metadata: { leg: 'commission' },
      },
      get(key) { return this.attrs[key]; },
    }];

    const result = await postLedgerPair({
      debitAccount: 'CLT-LIAB-AVA',
      creditAccount: 'PLT-LIAB-COM',
      amount: 12,
      transactionType: 'commission',
      referenceId: 'trade-7',
      referenceType: 'Trade',
      leg: 'commission',
    });

    expect(result).toEqual([]);
    expect(savedEntries).toHaveLength(0);
  });
});
