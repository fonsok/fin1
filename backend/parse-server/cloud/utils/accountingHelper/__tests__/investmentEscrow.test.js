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

    getField(row, field) {
      if (!String(field).includes('.')) return row.get(field);
      const parts = String(field).split('.');
      let cur = row.get(parts[0]);
      for (let i = 1; i < parts.length; i += 1) {
        cur = cur && cur[parts[i]];
      }
      return cur;
    }

    async find() {
      return queryRows.filter((row) => {
        for (const [field, value] of Object.entries(this.filters)) {
          if (value && typeof value === 'object' && value.op === 'containedIn') {
            if (!value.values.includes(this.getField(row, field))) return false;
            continue;
          }
          if (this.getField(row, field) !== value) return false;
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
    const { buildPairedLedgerEntries } = jest.requireActual('../investmentEscrow/ledgerBuilders');
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

  test('bookReleaseTrading caps PTR release to remaining pool capital on ledger', async () => {
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
    expect(releaseDebit.get('amount')).toBeCloseTo(997.69, 2);
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

  test('bookPartialSellProfitRecognition: INV-PNL→PPS idempotent per sellOrderId', async () => {
    const escrow = require('../investmentEscrow');
    await escrow.bookPartialSellProfitRecognition({
      investorId: 'user-1',
      investmentId: 'inv-1',
      tradeId: 'trade-1',
      tradeNumber: '001',
      sellOrderId: 'sell-a',
      grossProfit: 120.5,
      internalBelegRef: { referenceDocumentId: 'eb-1', referenceDocumentNumber: 'EBP-001' },
    });
    await escrow.bookPartialSellProfitRecognition({
      investorId: 'user-1',
      investmentId: 'inv-1',
      tradeId: 'trade-1',
      tradeNumber: '001',
      sellOrderId: 'sell-a',
      grossProfit: 120.5,
    });

    const profitRows = savedEntries.filter(
      (e) => (e.get('metadata') || {}).leg === 'partialSellProfitRecognition',
    );
    expect(profitRows).toHaveLength(2);
    const pnlDebit = profitRows.find((e) => e.get('account') === 'CLT-EQT-INV-PNL' && e.get('side') === 'debit');
    const ppsCredit = profitRows.find((e) => e.get('account') === 'CLT-LIAB-PPS' && e.get('side') === 'credit');
    expect(pnlDebit.get('amount')).toBeCloseTo(120.5, 2);
    expect(ppsCredit.get('amount')).toBeCloseTo(120.5, 2);
  });

  test('bookPartialSellPoolRelease: PTR→PPS idempotent per sellOrderId', async () => {
    const escrow = require('../investmentEscrow');
    await escrow.bookPartialSellPoolRelease({
      investorId: 'user-1',
      investmentId: 'inv-1',
      tradeId: 'trade-1',
      tradeNumber: '001',
      sellOrderId: 'sell-a',
      poolCapitalReleased: 332.5,
      internalBelegRef: { referenceDocumentId: 'eb-1', referenceDocumentNumber: 'EBP-001' },
    });
    await escrow.bookPartialSellPoolRelease({
      investorId: 'user-1',
      investmentId: 'inv-1',
      tradeId: 'trade-1',
      tradeNumber: '001',
      sellOrderId: 'sell-a',
      poolCapitalReleased: 332.5,
    });

    const partialRows = savedEntries.filter(
      (e) => (e.get('metadata') || {}).leg === 'partialSellRelease',
    );
    expect(partialRows).toHaveLength(2);
    const ptrDebit = partialRows.find((e) => e.get('account') === 'CLT-LIAB-PTR' && e.get('side') === 'debit');
    const ppsCredit = partialRows.find((e) => e.get('account') === 'CLT-LIAB-PPS' && e.get('side') === 'credit');
    expect(ptrDebit.get('amount')).toBeCloseTo(332.5, 2);
    expect(ppsCredit.get('amount')).toBeCloseTo(332.5, 2);
    expect((ptrDebit.get('metadata') || {}).sellOrderId).toBe('sell-a');
  });

  test('bookTradeSettlementPayout: splits PTR and PPS when partial sells exist', async () => {
    queryRows.push(
      Object.assign(new FakeAppLedgerEntry(), {
        attrs: {
          referenceId: 'inv-1',
          referenceType: 'Investment',
          transactionType: 'investmentEscrow',
          account: 'CLT-LIAB-PTR',
          side: 'debit',
          amount: 400,
          metadata: { leg: 'partialSellRelease', tradeId: 'trade-1', sellOrderId: 'sell-1' },
        },
      }),
      Object.assign(new FakeAppLedgerEntry(), {
        attrs: {
          referenceId: 'inv-1',
          referenceType: 'Investment',
          transactionType: 'investmentEscrow',
          account: 'CLT-LIAB-PPS',
          side: 'credit',
          amount: 400,
          metadata: { leg: 'partialSellRelease', tradeId: 'trade-1', sellOrderId: 'sell-1' },
        },
      }),
      Object.assign(new FakeAppLedgerEntry(), {
        attrs: {
          referenceId: 'inv-1',
          referenceType: 'Investment',
          transactionType: 'investmentEscrow',
          account: 'CLT-EQT-INV-PNL',
          side: 'debit',
          amount: 60,
          metadata: { leg: 'partialSellProfitRecognition', tradeId: 'trade-1', sellOrderId: 'sell-1' },
        },
      }),
      Object.assign(new FakeAppLedgerEntry(), {
        attrs: {
          referenceId: 'inv-1',
          referenceType: 'Investment',
          transactionType: 'investmentEscrow',
          account: 'CLT-LIAB-PPS',
          side: 'credit',
          amount: 60,
          metadata: { leg: 'partialSellProfitRecognition', tradeId: 'trade-1', sellOrderId: 'sell-1' },
        },
      }),
    );

    const escrow = require('../investmentEscrow');
    await escrow.bookTradeSettlementPayout({
      investorId: 'user-1',
      investmentId: 'inv-1',
      tradeId: 'trade-1',
      tradeNumber: '001',
      tradingAmount: 1000,
      netProfit: 100,
      transferAmount: 1100,
    });

    const ptrRelease = savedEntries.filter(
      (e) => (e.get('metadata') || {}).leg === 'tradeSettlementPoolRelease',
    );
    const ppsRelease = savedEntries.filter(
      (e) => (e.get('metadata') || {}).leg === 'tradeSettlementPartialPoolRelease',
    );
    const profitRelease = savedEntries.filter(
      (e) => (e.get('metadata') || {}).leg === 'tradeSettlementProfitRelease',
    );
    expect(ptrRelease).toHaveLength(2);
    expect(ppsRelease).toHaveLength(2);
    expect(ptrRelease.find((e) => e.get('side') === 'debit').get('amount')).toBeCloseTo(600, 2);
    expect(ppsRelease.find((e) => e.get('side') === 'debit').get('amount')).toBeCloseTo(460, 2);
    expect(profitRelease.find((e) => e.get('side') === 'debit').get('amount')).toBeCloseTo(40, 2);
  });

  test('bookTradeSettlementPayout: no PTR release when partials already exceed ledger credit', async () => {
    queryRows.push(
      Object.assign(new FakeAppLedgerEntry(), {
        attrs: {
          referenceId: 'inv-1',
          referenceType: 'Investment',
          transactionType: 'investmentEscrow',
          account: 'CLT-LIAB-PTR',
          side: 'credit',
          amount: 997.96,
          metadata: { leg: 'reserveCapitalTradeSplit', tradeId: 'trade-1' },
        },
      }),
      Object.assign(new FakeAppLedgerEntry(), {
        attrs: {
          referenceId: 'inv-1',
          referenceType: 'Investment',
          transactionType: 'investmentEscrow',
          account: 'CLT-LIAB-PTR',
          side: 'debit',
          amount: 499.08,
          metadata: { leg: 'partialSellRelease', tradeId: 'trade-1', sellOrderId: 'sell-1' },
        },
      }),
      Object.assign(new FakeAppLedgerEntry(), {
        attrs: {
          referenceId: 'inv-1',
          referenceType: 'Investment',
          transactionType: 'investmentEscrow',
          account: 'CLT-LIAB-PTR',
          side: 'debit',
          amount: 499.08,
          metadata: { leg: 'partialSellRelease', tradeId: 'trade-1', sellOrderId: 'sell-2' },
        },
      }),
    );

    const escrow = require('../investmentEscrow');
    await escrow.bookTradeSettlementPayout({
      investorId: 'user-1',
      investmentId: 'inv-1',
      tradeId: 'trade-1',
      tradeNumber: '001',
      tradingAmount: 1000,
      netProfit: 471.2,
      transferAmount: 1471.2,
    });

    const ptrRelease = savedEntries.filter(
      (e) => (e.get('metadata') || {}).leg === 'tradeSettlementPoolRelease',
    );
    expect(ptrRelease).toHaveLength(0);
  });

  test('bookReleaseTrading: skipped when tradeSettlementPartialPoolRelease exists', async () => {
    queryRows.push(
      Object.assign(new FakeAppLedgerEntry(), {
        attrs: {
          referenceId: 'inv-1',
          referenceType: 'Investment',
          transactionType: 'investmentEscrow',
          account: 'CLT-LIAB-PPS',
          side: 'debit',
          amount: 1558.43,
          metadata: { leg: 'tradeSettlementPartialPoolRelease', tradeId: 'trade-1' },
        },
      }),
    );

    const escrow = require('../investmentEscrow');
    await escrow.bookReleaseTrading({
      investorId: 'user-1',
      amount: 1450.94,
      investmentId: 'inv-1',
      reason: 'complete',
    });

    const releaseRows = savedEntries.filter(
      (e) => (e.get('metadata') || {}).leg === 'releaseTradingComplete',
    );
    expect(releaseRows).toHaveLength(0);
  });

  test('bookReleaseTrading: skipped when PTR pool capital already released via partial sells', async () => {
    queryRows.push(
      Object.assign(new FakeAppLedgerEntry(), {
        attrs: {
          referenceId: 'inv-1',
          referenceType: 'Investment',
          transactionType: 'investmentEscrow',
          account: 'CLT-LIAB-PTR',
          side: 'credit',
          amount: 998.24,
          metadata: { leg: 'reserveCapitalTradeSplit', tradeId: 'trade-1' },
        },
      }),
      Object.assign(new FakeAppLedgerEntry(), {
        attrs: {
          referenceId: 'inv-1',
          referenceType: 'Investment',
          transactionType: 'investmentEscrow',
          account: 'CLT-LIAB-PTR',
          side: 'debit',
          amount: 498.45,
          metadata: { leg: 'partialSellRelease', tradeId: 'trade-1', sellOrderId: 'sell-1' },
        },
      }),
      Object.assign(new FakeAppLedgerEntry(), {
        attrs: {
          referenceId: 'inv-1',
          referenceType: 'Investment',
          transactionType: 'investmentEscrow',
          account: 'CLT-LIAB-PTR',
          side: 'debit',
          amount: 499.79,
          metadata: { leg: 'partialSellRelease', tradeId: 'trade-1', sellOrderId: 'sell-2' },
        },
      }),
    );

    const escrow = require('../investmentEscrow');
    await escrow.bookReleaseTrading({
      investorId: 'user-1',
      amount: 1450.94,
      investmentId: 'inv-1',
      reason: 'complete',
    });

    const releaseRows = savedEntries.filter(
      (e) => (e.get('metadata') || {}).leg === 'releaseTradingComplete',
    );
    expect(releaseRows).toHaveLength(0);
  });
});
