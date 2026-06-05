'use strict';

describe('investmentEscrow (reserveCapitalTradeSplit)', () => {
  let savedEntries;
  let queryRows;

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

  class FakeQuery {
    constructor() {
      this.filters = {};
      this.limitValue = 500;
    }

    equalTo(field, value) {
      this.filters[field] = value;
      return this;
    }

    containedIn(field, values) {
      this.filters[field] = { op: 'containedIn', values };
      return this;
    }

    limit(n) {
      this.limitValue = n;
      return this;
    }

    async find() {
      return queryRows.filter((row) => {
        for (const [field, value] of Object.entries(this.filters)) {
          if (field === 'referenceType' && value.op === 'containedIn') {
            const rt = row.get('referenceType');
            if (!value.values.includes(rt)) return false;
            continue;
          }
          if (row.get(field) !== value) return false;
        }
        return true;
      });
    }

    async first() {
      const rows = await this.find();
      return rows[0];
    }
  }

  beforeEach(() => {
    jest.resetModules();
    savedEntries = [];
    queryRows = [];

    global.Parse = {
      Object: {
        extend(className) {
          if (className !== 'AppLedgerEntry') {
            throw new Error(`Unexpected extend: ${className}`);
          }
          return FakeAppLedgerEntry;
        },
        async saveAll(rows) {
          for (const row of rows) {
            row.id = `ale-${savedEntries.length + 1}`;
            savedEntries.push(row);
            queryRows.push(row);
          }
          return rows;
        },
      },
      Query: FakeQuery,
    };
    jest.spyOn(console, 'error').mockImplementation(() => {});
  });

  function seedDeploy(investmentId, investorId, nominal) {
    const escrow = require('../investmentEscrow');
    const common = {
      userId: investorId,
      userRole: 'investor',
      transactionType: 'investmentEscrow',
      referenceId: investmentId,
      referenceType: 'Investment',
      description: 'deploy',
      metadata: { leg: 'deploy' },
    };
    const pair = require('../investmentEscrow');
    void pair;
    const { buildPairedLedgerEntries } = jest.requireActual('../investmentEscrow');
    void buildPairedLedgerEntries;
    queryRows.push(
      Object.assign(new FakeAppLedgerEntry(), {
        attrs: {
          account: 'CLT-LIAB-RSV',
          side: 'debit',
          amount: nominal,
          userId: investorId,
          transactionType: 'investmentEscrow',
          referenceId: investmentId,
          referenceType: 'Investment',
          metadata: { leg: 'deploy' },
        },
      }),
      Object.assign(new FakeAppLedgerEntry(), {
        attrs: {
          account: 'CLT-LIAB-PTR',
          side: 'credit',
          amount: nominal,
          userId: investorId,
          transactionType: 'investmentEscrow',
          referenceId: investmentId,
          referenceType: 'Investment',
          metadata: { leg: 'deploy' },
        },
      }),
    );
  }

  test('bookReserveCapitalTradeSplit posts RSV debit, PTR and AVA credit', async () => {
    seedDeploy('inv-1', 'user-1', 1000);
    const escrow = require('../investmentEscrow');
    await escrow.bookReserveCapitalTradeSplit({
      investorId: 'user-1',
      nominal: 1000,
      tradingAmount: 997.69,
      availableAmount: 2.31,
      investmentId: 'inv-1',
      investmentNumber: 'INV-2026-0000020',
      tradeId: 'trade-1',
      tradeNumber: '42',
    });

    const splitRows = savedEntries.filter(
      (e) => (e.get('metadata') || {}).leg === 'reserveCapitalTradeSplit',
    );
    expect(splitRows).toHaveLength(3);

    const rsv = splitRows.find((e) => e.get('account') === 'CLT-LIAB-RSV');
    const ptr = splitRows.find((e) => e.get('account') === 'CLT-LIAB-PTR');
    const ava = splitRows.find((e) => e.get('account') === 'CLT-LIAB-AVA');
    expect(rsv.get('side')).toBe('debit');
    expect(rsv.get('amount')).toBeCloseTo(1000, 2);
    expect(ptr.get('side')).toBe('credit');
    expect(ptr.get('amount')).toBeCloseTo(997.69, 2);
    expect(ava.get('side')).toBe('credit');
    expect(ava.get('amount')).toBeCloseTo(2.31, 2);
  });

  test('bookReserveCapitalTradeSplit without prior deploy skips deploy reversal', async () => {
    const escrow = require('../investmentEscrow');
    await escrow.bookReserveCapitalTradeSplit({
      investorId: 'user-1',
      nominal: 1000,
      tradingAmount: 998,
      availableAmount: 2,
      investmentId: 'inv-no-deploy',
      tradeId: 'trade-2',
    });

    const legs = savedEntries.map((e) => (e.get('metadata') || {}).leg);
    expect(legs).not.toContain('deployReversalForCapitalSplit');
    expect(legs.filter((l) => l === 'reserveCapitalTradeSplit')).toHaveLength(3);
  });

  test('bookReserveCapitalTradeSplit reverses prior deploy when residual > 0', async () => {
    seedDeploy('inv-1', 'user-1', 1000);
    const escrow = require('../investmentEscrow');
    await escrow.bookReserveCapitalTradeSplit({
      investorId: 'user-1',
      nominal: 1000,
      tradingAmount: 997.69,
      availableAmount: 2.31,
      investmentId: 'inv-1',
      tradeId: 'trade-1',
    });

    const reversal = savedEntries.filter(
      (e) => (e.get('metadata') || {}).leg === 'deployReversalForCapitalSplit',
    );
    expect(reversal).toHaveLength(2);
    const ptrRev = reversal.find((e) => e.get('account') === 'CLT-LIAB-PTR' && e.get('side') === 'debit');
    expect(ptrRev.get('amount')).toBeCloseTo(1000, 2);
  });

  test('bookReleaseTrading reduces amount by capital split to available', async () => {
    seedDeploy('inv-1', 'user-1', 1000);
    const escrow = require('../investmentEscrow');
    await escrow.bookReserveCapitalTradeSplit({
      investorId: 'user-1',
      nominal: 1000,
      tradingAmount: 997.69,
      availableAmount: 2.31,
      investmentId: 'inv-1',
      tradeId: 'trade-1',
    });
    await escrow.bookReleaseTrading({
      investorId: 'user-1',
      amount: 1285.02,
      investmentId: 'inv-1',
      reason: 'complete',
    });

    const releaseDebit = savedEntries.find(
      (e) => e.get('account') === 'CLT-LIAB-PTR'
        && (e.get('metadata') || {}).leg === 'releaseTradingComplete',
    );
    expect(releaseDebit).toBeDefined();
    expect(releaseDebit.get('amount')).toBeCloseTo(1282.71, 2);
  });

  test('bookTradeSettlementPayout: PTR pool release + investor P/L to AVA', async () => {
    const escrow = require('../investmentEscrow');
    await escrow.bookTradeSettlementPayout({
      investorId: 'user-1',
      investmentId: 'inv-1',
      tradeId: 'trade-1',
      tradeNumber: '001',
      tradingAmount: 997.69,
      netProfit: 518.22,
      transferAmount: 1515.5,
    });

    const poolRelease = savedEntries.filter(
      (e) => (e.get('metadata') || {}).leg === 'tradeSettlementPoolRelease',
    );
    expect(poolRelease).toHaveLength(2);
    const ptrDebit = poolRelease.find((e) => e.get('account') === 'CLT-LIAB-PTR' && e.get('side') === 'debit');
    expect(ptrDebit.get('amount')).toBeCloseTo(997.69, 2);

    const profitRelease = savedEntries.filter(
      (e) => (e.get('metadata') || {}).leg === 'tradeSettlementProfitRelease',
    );
    expect(profitRelease).toHaveLength(2);
    const pnlDebit = profitRelease.find((e) => e.get('account') === 'CLT-EQT-INV-PNL' && e.get('side') === 'debit');
    expect(pnlDebit.get('amount')).toBeCloseTo(518.22, 2);
  });
});
