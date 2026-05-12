'use strict';

// ============================================================================
// Tests for `bookSettlementEntry` (ADR-010 / PR4).
//
// Covers the new Sub-Ledger + GL contract:
//   - AccountStatement is always written (legacy contract).
//   - Each entryType in the settlement GL rule table produces a balanced
//     AppLedgerEntry pair with a deterministic `metadata.leg`.
//   - `trading_fees` with feeBreakdown emits one pair per non-zero component
//     against the matching PLT-REV-* account.
//   - entryTypes intentionally excluded from GL (e.g. `investment_return`)
//     stay AccountStatement-only.
// ============================================================================

describe('bookSettlementEntry (statements.js)', () => {
  let savedAccountStatements;
  let savedAppLedgerEntries;

  class FakeAccountStatement {
    constructor() { this.attrs = {}; this.id = undefined; }
    set(k, v) { this.attrs[k] = v; }
    get(k) { return this.attrs[k]; }
    async save() {
      this.id = 'stmt-' + (savedAccountStatements.length + 1);
      savedAccountStatements.push(this);
      return this;
    }
  }

  class FakeAppLedgerEntry {
    constructor() { this.attrs = {}; this.id = undefined; }
    set(k, v) { this.attrs[k] = v; }
    get(k) { return this.attrs[k]; }
    async save() {
      this.id = 'ale-' + (savedAppLedgerEntries.length + 1);
      savedAppLedgerEntries.push(this);
      return this;
    }
  }

  class FakeQuery {
    constructor(className) { this.className = className; this.filters = {}; this.limitValue = 100; }
    equalTo(field, value) { this.filters[field] = value; return this; }
    descending() { return this; }
    limit(n) { this.limitValue = n; return this; }
    async first() { return undefined; } // no prior balance row
    async find() { return []; }          // no prior GL leg → never idempotent
  }

  beforeEach(() => {
    jest.resetModules();
    savedAccountStatements = [];
    savedAppLedgerEntries = [];

    global.Parse = {
      Object: {
        extend(className) {
          if (className === 'AccountStatement') {
            FakeAccountStatement.__fakeClassName = 'AccountStatement';
            return FakeAccountStatement;
          }
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

  function findEntries(account) {
    return savedAppLedgerEntries.filter((e) => e.attrs.account === account);
  }

  test('commission_debit posts CLT-LIAB-AVA / PLT-LIAB-COM', async () => {
    // eslint-disable-next-line global-require
    const { bookSettlementEntry } = require('../statements');

    await bookSettlementEntry({
      userId: 'investor-1',
      userRole: 'investor',
      entryType: 'commission_debit',
      amount: -25,
      tradeId: 'trade-7',
      tradeNumber: '0007',
      investmentId: 'inv-9',
      description: 'Provision Trade #0007',
      referenceDocumentId: 'col-bill-1',
      referenceDocumentNumber: 'CB-2026-0000001',
    });

    expect(savedAccountStatements).toHaveLength(1);
    expect(savedAccountStatements[0].attrs.entryType).toBe('commission_debit');
    expect(savedAccountStatements[0].attrs.amount).toBe(-25);

    expect(savedAppLedgerEntries).toHaveLength(2);
    const [debit, credit] = savedAppLedgerEntries;
    expect(debit.attrs.account).toBe('CLT-LIAB-AVA');
    expect(debit.attrs.side).toBe('debit');
    expect(credit.attrs.account).toBe('PLT-LIAB-COM');
    expect(credit.attrs.side).toBe('credit');
    expect(debit.attrs.amount).toBeCloseTo(25, 2);
    expect(credit.attrs.amount).toBeCloseTo(25, 2);
  });

  test('commission_credit posts PLT-LIAB-COM / CLT-LIAB-AVA (Trader-side)', async () => {
    // eslint-disable-next-line global-require
    const { bookSettlementEntry } = require('../statements');

    await bookSettlementEntry({
      userId: 'trader-1',
      userRole: 'trader',
      entryType: 'commission_credit',
      amount: 25,
      tradeId: 'trade-7',
      tradeNumber: '0007',
      description: 'Gutschrift Trade #0007',
      referenceDocumentId: 'credit-note-1',
      referenceDocumentNumber: 'CN-2026-0000001',
    });

    expect(savedAppLedgerEntries).toHaveLength(2);
    const debit = savedAppLedgerEntries.find((e) => e.attrs.side === 'debit');
    const credit = savedAppLedgerEntries.find((e) => e.attrs.side === 'credit');
    expect(debit.attrs.account).toBe('PLT-LIAB-COM');
    expect(credit.attrs.account).toBe('CLT-LIAB-AVA');
  });

  test('Investor + Trader commission together saldieren PLT-LIAB-COM auf 0', async () => {
    // eslint-disable-next-line global-require
    const { bookSettlementEntry } = require('../statements');

    await bookSettlementEntry({
      userId: 'investor-1', userRole: 'investor',
      entryType: 'commission_debit', amount: -25,
      tradeId: 'trade-7', tradeNumber: '0007',
      description: 'Provision', referenceDocumentId: 'doc-1', referenceDocumentNumber: 'DOC-1',
    });
    await bookSettlementEntry({
      userId: 'trader-1', userRole: 'trader',
      entryType: 'commission_credit', amount: 25,
      tradeId: 'trade-7', tradeNumber: '0007',
      description: 'Gutschrift', referenceDocumentId: 'doc-2', referenceDocumentNumber: 'DOC-2',
    });

    const liabRows = findEntries('PLT-LIAB-COM');
    const debitSum = liabRows.filter((e) => e.attrs.side === 'debit').reduce((s, e) => s + e.attrs.amount, 0);
    const creditSum = liabRows.filter((e) => e.attrs.side === 'credit').reduce((s, e) => s + e.attrs.amount, 0);
    expect(debitSum).toBeCloseTo(creditSum, 2);
  });

  test('withholding_tax_debit posts CLT-LIAB-AVA / PLT-TAX-WHT', async () => {
    // eslint-disable-next-line global-require
    const { bookSettlementEntry } = require('../statements');

    await bookSettlementEntry({
      userId: 'investor-1', userRole: 'investor',
      entryType: 'withholding_tax_debit', amount: -10,
      tradeId: 'trade-7', tradeNumber: '0007', investmentId: 'inv-9',
      description: 'KESt', referenceDocumentId: 'doc-3', referenceDocumentNumber: 'DOC-3',
    });
    expect(findEntries('PLT-TAX-WHT')).toHaveLength(1);
    expect(findEntries('CLT-LIAB-AVA')).toHaveLength(1);
  });

  test('solidarity_surcharge_debit / church_tax_debit hit the right tax accounts', async () => {
    // eslint-disable-next-line global-require
    const { bookSettlementEntry } = require('../statements');

    await bookSettlementEntry({
      userId: 'investor-1', userRole: 'investor',
      entryType: 'solidarity_surcharge_debit', amount: -1, tradeId: 't', tradeNumber: '1',
      description: 'Soli', referenceDocumentId: 'd', referenceDocumentNumber: 'DOC-SOLI',
    });
    await bookSettlementEntry({
      userId: 'investor-1', userRole: 'investor',
      entryType: 'church_tax_debit', amount: -2, tradeId: 't', tradeNumber: '1',
      description: 'KiSt', referenceDocumentId: 'd', referenceDocumentNumber: 'DOC-KIST',
    });

    expect(findEntries('PLT-TAX-SOL')).toHaveLength(1);
    expect(findEntries('PLT-TAX-CHU')).toHaveLength(1);
  });

  test('trading_fees with feeBreakdown emits one pair per non-zero component', async () => {
    // eslint-disable-next-line global-require
    const { bookSettlementEntry } = require('../statements');

    await bookSettlementEntry({
      userId: 'trader-1', userRole: 'trader',
      entryType: 'trading_fees', amount: -7,
      tradeId: 'trade-9', tradeNumber: '0009',
      description: 'Handelsgebühren',
      referenceDocumentId: 'doc-fee',
      referenceDocumentNumber: 'DOC-FEE',
      feeBreakdown: { orderFee: 5, exchangeFee: 1.5, foreignCosts: 0 },
    });

    expect(findEntries('PLT-REV-ORD')).toHaveLength(1);
    expect(findEntries('PLT-REV-EXC')).toHaveLength(1);
    expect(findEntries('PLT-REV-FRG')).toHaveLength(0); // 0 → skipped
    // CLT-LIAB-AVA debit appears twice (one per non-zero component)
    expect(findEntries('CLT-LIAB-AVA')).toHaveLength(2);
  });

  test('investment_return is AccountStatement-only (no GL pair, escrow already covers)', async () => {
    // eslint-disable-next-line global-require
    const { bookSettlementEntry } = require('../statements');

    await bookSettlementEntry({
      userId: 'investor-1', userRole: 'investor',
      entryType: 'investment_return', amount: 100,
      tradeId: 'trade-7', tradeNumber: '0007', investmentId: 'inv-9',
      description: 'Return', referenceDocumentId: 'doc-1', referenceDocumentNumber: 'DOC-RET',
    });

    expect(savedAccountStatements).toHaveLength(1);
    expect(savedAppLedgerEntries).toHaveLength(0);
  });

  test('fails closed when referenceDocumentNumber is missing', async () => {
    // eslint-disable-next-line global-require
    const { bookSettlementEntry } = require('../statements');

    await expect(bookSettlementEntry({
      userId: 'investor-1',
      userRole: 'investor',
      entryType: 'commission_debit',
      amount: -10,
      tradeId: 'trade-x',
      tradeNumber: '0001',
      description: 'Provision',
      referenceDocumentId: 'doc-x',
    })).rejects.toThrow('referenceDocumentId + referenceDocumentNumber');
  });

  // ── ADR-011 / PR5 ──────────────────────────────────────────────────────
  test('trade_buy posts CLT-LIAB-AVA / BANK-TRT-CLT (Trader-side cash leg)', async () => {
    // eslint-disable-next-line global-require
    const { bookSettlementEntry } = require('../statements');

    await bookSettlementEntry({
      userId: 'trader-1', userRole: 'trader',
      entryType: 'trade_buy', amount: -1000,
      tradeId: 'trade-7', tradeNumber: '0007',
      description: 'BUY', referenceDocumentId: 'doc-buy', referenceDocumentNumber: 'DOC-BUY',
    });

    expect(findEntries('CLT-LIAB-AVA')).toHaveLength(1);
    expect(findEntries('BANK-TRT-CLT')).toHaveLength(1);
    const debit = savedAppLedgerEntries.find((e) => e.attrs.side === 'debit');
    const credit = savedAppLedgerEntries.find((e) => e.attrs.side === 'credit');
    expect(debit.attrs.account).toBe('CLT-LIAB-AVA');
    expect(credit.attrs.account).toBe('BANK-TRT-CLT');
    expect(debit.attrs.amount).toBeCloseTo(1000, 2);
    expect(credit.attrs.amount).toBeCloseTo(1000, 2);
  });

  test('trade_sell posts BANK-TRT-CLT / CLT-LIAB-AVA (Trader-side cash leg)', async () => {
    // eslint-disable-next-line global-require
    const { bookSettlementEntry } = require('../statements');

    await bookSettlementEntry({
      userId: 'trader-1', userRole: 'trader',
      entryType: 'trade_sell', amount: 1100,
      tradeId: 'trade-7', tradeNumber: '0007',
      description: 'SELL', referenceDocumentId: 'doc-sell', referenceDocumentNumber: 'DOC-SELL',
    });

    const debit = savedAppLedgerEntries.find((e) => e.attrs.side === 'debit');
    const credit = savedAppLedgerEntries.find((e) => e.attrs.side === 'credit');
    expect(debit.attrs.account).toBe('BANK-TRT-CLT');
    expect(credit.attrs.account).toBe('CLT-LIAB-AVA');
  });

  test('deposit posts BANK-TRT-CLT / CLT-LIAB-AVA against WalletTransaction reference', async () => {
    // eslint-disable-next-line global-require
    const { bookSettlementEntry } = require('../statements');

    await bookSettlementEntry({
      userId: 'user-1', userRole: 'user',
      entryType: 'deposit', amount: 500,
      description: 'Einzahlung', referenceDocumentId: 'rcpt-1', referenceDocumentNumber: 'RCP-1',
      ledgerReference: { referenceId: 'wtx-1', referenceType: 'WalletTransaction' },
    });

    expect(savedAppLedgerEntries).toHaveLength(2);
    const debit = savedAppLedgerEntries.find((e) => e.attrs.side === 'debit');
    const credit = savedAppLedgerEntries.find((e) => e.attrs.side === 'credit');
    expect(debit.attrs.account).toBe('BANK-TRT-CLT');
    expect(credit.attrs.account).toBe('CLT-LIAB-AVA');
    expect(debit.attrs.referenceId).toBe('wtx-1');
    expect(debit.attrs.referenceType).toBe('WalletTransaction');
  });

  test('withdrawal posts CLT-LIAB-AVA / BANK-TRT-CLT', async () => {
    // eslint-disable-next-line global-require
    const { bookSettlementEntry } = require('../statements');

    await bookSettlementEntry({
      userId: 'user-1', userRole: 'user',
      entryType: 'withdrawal', amount: -200,
      description: 'Auszahlung', referenceDocumentId: 'rcpt-2', referenceDocumentNumber: 'RCP-2',
      ledgerReference: { referenceId: 'wtx-2', referenceType: 'WalletTransaction' },
    });

    const debit = savedAppLedgerEntries.find((e) => e.attrs.side === 'debit');
    const credit = savedAppLedgerEntries.find((e) => e.attrs.side === 'credit');
    expect(debit.attrs.account).toBe('CLT-LIAB-AVA');
    expect(credit.attrs.account).toBe('BANK-TRT-CLT');
  });

  test('full trade settlement keeps Σdebit == Σcredit across all pairs', async () => {
    // eslint-disable-next-line global-require
    const { bookSettlementEntry } = require('../statements');

    // Simulate the full chain that settlement.js produces for a single trade:
    //   trader BUY (1000) → trader SELL (1100) → fees (5) → comm_credit/debit (10/10)
    //   → tax (2.50)
    await bookSettlementEntry({
      userId: 'trader-1', userRole: 'trader', entryType: 'trade_buy', amount: -1000,
      tradeId: 'trade-7', tradeNumber: '0007',
      description: 'BUY', referenceDocumentId: 'd1', referenceDocumentNumber: 'D-1',
    });
    await bookSettlementEntry({
      userId: 'trader-1', userRole: 'trader', entryType: 'trade_sell', amount: 1100,
      tradeId: 'trade-7', tradeNumber: '0007',
      description: 'SELL', referenceDocumentId: 'd2', referenceDocumentNumber: 'D-2',
    });
    await bookSettlementEntry({
      userId: 'trader-1', userRole: 'trader', entryType: 'trading_fees', amount: -5,
      tradeId: 'trade-7', tradeNumber: '0007',
      description: 'fees', referenceDocumentId: 'd3', referenceDocumentNumber: 'D-3',
      feeBreakdown: { orderFee: 4, exchangeFee: 1, foreignCosts: 0 },
    });
    await bookSettlementEntry({
      userId: 'investor-1', userRole: 'investor', entryType: 'commission_debit', amount: -10,
      tradeId: 'trade-7', tradeNumber: '0007', investmentId: 'inv-9',
      description: 'comm', referenceDocumentId: 'd4', referenceDocumentNumber: 'D-4',
    });
    await bookSettlementEntry({
      userId: 'trader-1', userRole: 'trader', entryType: 'commission_credit', amount: 10,
      tradeId: 'trade-7', tradeNumber: '0007',
      description: 'comm', referenceDocumentId: 'd5', referenceDocumentNumber: 'D-5',
    });
    await bookSettlementEntry({
      userId: 'investor-1', userRole: 'investor', entryType: 'withholding_tax_debit', amount: -2.5,
      tradeId: 'trade-7', tradeNumber: '0007', investmentId: 'inv-9',
      description: 'KESt', referenceDocumentId: 'd6', referenceDocumentNumber: 'D-6',
    });

    const debitSum = savedAppLedgerEntries
      .filter((e) => e.attrs.side === 'debit')
      .reduce((sum, e) => sum + e.attrs.amount, 0);
    const creditSum = savedAppLedgerEntries
      .filter((e) => e.attrs.side === 'credit')
      .reduce((sum, e) => sum + e.attrs.amount, 0);
    expect(debitSum).toBeCloseTo(creditSum, 2);
  });
});
