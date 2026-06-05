'use strict';

const {
  buildInvestorMergedTimeline,
  buildInvestorLedgerGoBTimeline,
  applyInvestorGoBCollectionBillFeeGranularity,
  mergedTimelineToDescendingApiRows,
  syntheticEntryTypeFromLedgerRow,
  summarizeClientFundsFromEscrowRows,
} = require('../investorAccountStatementMerge');
const {
  expandTraderLedgerStmtEntries,
} = require('../../functions/admin/traderLedgerStatementExpansion');
const { computeTradingFeesWithBreakdown } = require('../accountingHelper/settlementTradeMath');

function mockStmt(id, entryType, amount, createdAt, investmentId, tradeId) {
  return {
    id,
    get: (key) => {
      const map = {
        entryType,
        amount,
        createdAt,
        investmentId,
        tradeId: tradeId || null,
        source: 'backend',
      };
      return map[key];
    },
    toJSON() {
      return {
        objectId: id,
        entryType,
        amount,
        investmentId,
        createdAt: createdAt.toISOString(),
        source: 'backend',
      };
    },
  };
}

function mockLedger(id, leg, amount, side, createdAt, investmentId, investmentNumber, metaExtra = {}) {
  return {
    id,
    get: (key) => {
      if (key === 'metadata') {
        return { leg, investmentNumber, businessReference: investmentNumber, ...metaExtra };
      }
      const map = {
        amount: Math.abs(amount),
        side,
        createdAt,
        transactionType: 'investmentEscrow',
        account: 'CLT-LIAB-AVA',
        referenceType: 'Investment',
        referenceId: investmentId,
        description: `leg ${leg}`,
      };
      return map[key];
    },
  };
}

const user = { id: 'userObj', get: (k) => (k === 'stableId' ? 'user:test@example.com' : undefined) };

describe('investorAccountStatementMerge', () => {
  test('syntheticEntryTypeFromLedgerRow maps reserve leg', () => {
    const row = mockLedger('l1', 'reserve', 100, 'debit', new Date(), 'inv1', 'INV-001');
    expect(syntheticEntryTypeFromLedgerRow(row)).toBe('investment_escrow_reserve');
  });

  test('merged timeline keeps all AVA reserve legs when investment_activate stmt exists', () => {
    const t0 = new Date('2026-05-01T10:00:00Z');
    const t1 = new Date('2026-05-01T11:00:00Z');
    const t2 = new Date('2026-05-01T12:00:00Z');
    const t3 = new Date('2026-05-01T13:00:00Z');

    const stmtEntries = [
      mockStmt('s1', 'investment_activate', -1000, t2, 'inv1'),
    ];
    const avaRows = [
      mockLedger('l1', 'reserve', 500, 'debit', t0, 'invA', 'INV-A'),
      mockLedger('l2', 'reserve', 500, 'debit', t1, 'invB', 'INV-B'),
      mockLedger('l3', 'deployResidualToAvailable', 200, 'credit', t3, 'invA', 'INV-A'),
    ];

    const timeline = buildInvestorMergedTimeline({
      stmtEntries,
      avaRows,
      initialBalance: 10000,
    });

    const { rows, total } = mergedTimelineToDescendingApiRows(user, timeline, {
      entryType: null,
      limit: 50,
      skip: 0,
    });

    expect(total).toBe(3);
    const types = rows.map((r) => r.entryType);
    expect(types.filter((t) => t === 'investment_escrow_reserve')).toHaveLength(2);
    expect(types).not.toContain('investment_activate');
    expect(types).toContain('investment_escrow_deployResidualToAvailable');
  });

  test('customer merged timeline hides tradeSettlement pool/profit AVA legs (duplicate investment_return)', () => {
    const t0 = new Date('2026-05-18T12:40:00Z');
    const t1 = new Date('2026-05-18T12:41:00Z');
    const stmtEntries = [
      mockStmt('s1', 'investment_return', 1286.26, t0, 'inv1'),
    ];
    const avaRows = [
      mockLedger('l1', 'tradeSettlementPoolRelease', 997.36, 'credit', t1, 'inv1', 'INV-001', { tradeId: 'tr1' }),
      mockLedger('l2', 'tradeSettlementProfitRelease', 288.9, 'credit', t1, 'inv1', 'INV-001', { tradeId: 'tr1' }),
    ];
    const timeline = buildInvestorMergedTimeline({
      stmtEntries,
      avaRows,
      initialBalance: 7000,
    });
    expect(timeline).toHaveLength(1);
    expect(timeline[0].kind).toBe('stmt');
    expect(timeline[0].stmt.get('entryType')).toBe('investment_return');
    expect(timeline[0].balanceAfter).toBeCloseTo(8286.26, 2);

    const withLegs = buildInvestorMergedTimeline({
      stmtEntries,
      avaRows,
      initialBalance: 7000,
      includeInternalTradeSettlementLegs: true,
    });
    expect(withLegs).toHaveLength(3);
  });

  test('ledger GoB timeline includes AVA appServiceCharge (no AccountStatement row)', () => {
    const t0 = new Date('2026-05-18T12:40:00Z');
    const t1 = new Date('2026-05-18T12:40:30Z');
    const stmtEntries = [
      mockStmt('s1', 'deposit', 10000, new Date('2026-05-01T10:00:00Z'), null),
    ];
    const appFeeRow = {
      id: 'asc1',
      get: (key) => {
        if (key === 'metadata') return { invoiceNumber: 'INV-RE-1' };
        return {
          amount: 60,
          side: 'debit',
          createdAt: t1,
          transactionType: 'appServiceCharge',
          account: 'CLT-LIAB-AVA',
          referenceType: 'investment_batch',
          referenceId: 'batchX',
          description: 'Belastung Kundenguthaben Appgebühr (brutto)',
        }[key];
      },
    };
    const timeline = buildInvestorLedgerGoBTimeline({
      stmtEntries,
      avaRows: [appFeeRow],
      initialBalance: 0,
    });
    const types = timeline.map((row) => (row.kind === 'stmt' ? row.stmt.get('entryType') : syntheticEntryTypeFromLedgerRow(row.ledger)));
    expect(types).toContain('app_service_charge');
    expect(timeline.some((r) => r.kind === 'ledger' && syntheticEntryTypeFromLedgerRow(r.ledger) === 'app_service_charge')).toBe(true);
    const last = timeline[timeline.length - 1];
    expect(last.balanceAfter).toBeCloseTo(9940, 2);
  });

  test('ledger GoB timeline keeps investment_activate and adds reserve AVA only for investments without activate', () => {
    const t0 = new Date('2026-05-18T12:40:00Z');
    const t1 = new Date('2026-05-18T12:41:00Z');
    const stmtEntries = [
      mockStmt('s_act', 'investment_activate', -1000, t1, 'inv14'),
    ];
    const avaRows = [
      mockLedger('lr14', 'reserve', 1000, 'debit', t0, 'inv14', 'INV-14'),
      mockLedger('lr15', 'reserve', 1000, 'debit', t0, 'inv15', 'INV-15'),
      mockLedger('lr16', 'reserve', 1000, 'debit', t0, 'inv16', 'INV-16'),
    ];
    const timeline = buildInvestorLedgerGoBTimeline({
      stmtEntries,
      avaRows,
      initialBalance: 10000,
    });
    const types = timeline.map((row) => (row.kind === 'stmt' ? row.stmt.get('entryType') : syntheticEntryTypeFromLedgerRow(row.ledger)));
    expect(types.filter((t) => t === 'investment_activate')).toHaveLength(1);
    expect(types.filter((t) => t === 'investment_escrow_reserve')).toHaveLength(2);
    const reserveInvIds = timeline
      .filter((row) => row.kind === 'ledger')
      .map((row) => String(row.ledger.get('referenceId')));
    expect(reserveInvIds.sort()).toEqual(['inv15', 'inv16'].sort());
  });

  test('suppresses AVA split available leg when residual_return AccountStatement exists', () => {
    const t1 = new Date('2026-05-01T12:00:00Z');
    const t2 = new Date('2026-05-01T12:00:01Z');
    const stmtEntries = [
      mockStmt('s1', 'residual_return', 1.48, t1, 'inv47', 'trade1'),
    ];
    const avaRows = [
      mockLedger(
        'l1',
        'reserveCapitalTradeSplit',
        1.48,
        'credit',
        t2,
        'inv47',
        'INV-2026-0000047',
        { splitPart: 'available', tradeId: 'trade1' },
      ),
    ];

    const timeline = buildInvestorMergedTimeline({
      stmtEntries,
      avaRows,
      initialBalance: 5000,
    });

    expect(timeline).toHaveLength(1);
    expect(timeline[0].kind).toBe('stmt');
    expect(timeline[0].stmt.get('entryType')).toBe('residual_return');
  });

  test('summarizeClientFundsFromEscrowRows aggregates AVA RSV PTR nets', () => {
    const rows = [
      {
        get: (k) => ({
          account: 'CLT-LIAB-AVA',
          side: 'debit',
          amount: 1000,
        }[k]),
      },
      {
        get: (k) => ({
          account: 'CLT-LIAB-RSV',
          side: 'credit',
          amount: 1000,
        }[k]),
      },
      {
        get: (k) => ({
          account: 'CLT-LIAB-RSV',
          side: 'debit',
          amount: 1000,
        }[k]),
      },
      {
        get: (k) => ({
          account: 'CLT-LIAB-PTR',
          side: 'credit',
          amount: 998.52,
        }[k]),
      },
      {
        get: (k) => ({
          account: 'CLT-LIAB-AVA',
          side: 'credit',
          amount: 1.48,
        }[k]),
      },
    ];
    const summary = summarizeClientFundsFromEscrowRows(rows, 10000);
    expect(summary.available).toBeCloseTo(-998.52, 2);
    expect(summary.reserved).toBeCloseTo(0, 2);
    expect(summary.poolTrade).toBeCloseTo(998.52, 2);
  });

  test('ledger GoB: fee expansion splits aggregate trading_fees into buy phase then sell phase (trader parity)', () => {
    function mockStmtTrade(id, entryType, amount, createdAt, opts = {}) {
      return {
        id,
        get: (key) => {
          const map = {
            entryType,
            amount,
            createdAt,
            investmentId: opts.investmentId ?? null,
            tradeId: opts.tradeId ?? 'trade1',
            tradeNumber: opts.tradeNumber ?? 1,
            description: opts.description ?? entryType,
            referenceDocumentId: opts.referenceDocumentId ?? null,
            referenceDocumentNumber: opts.referenceDocumentNumber ?? null,
            source: 'backend',
          };
          return map[key];
        },
        toJSON() {
          return { objectId: id, entryType, amount };
        },
      };
    }

    function mockTradeForExpansion(buyAmount, sellAmount) {
      return {
        get: (key) => {
          if (key === 'buyOrder') return { totalAmount: buyAmount };
          if (key === 'sellOrders') return sellAmount > 0 ? [{ totalAmount: sellAmount }] : [];
          if (key === 'sellOrder') return sellAmount > 0 ? { totalAmount: sellAmount } : null;
          if (key === 'symbol') return 'VO5G3MN';
          if (key === 'tradeNumber') return 1;
          return null;
        },
      };
    }

    const tBuy = new Date('2026-05-18T12:41:00Z');
    const tSell = new Date('2026-05-18T12:43:00Z');
    const trade = mockTradeForExpansion(3000, 4000);
    const { totalFees } = computeTradingFeesWithBreakdown(trade);
    const totalFeesNeg = -totalFees;

    const stmtEntries = [
      mockStmtTrade('b1', 'trade_buy', -3000, tBuy),
      mockStmtTrade('s1', 'trade_sell', 4000, tSell),
      mockStmtTrade('f1', 'trading_fees', totalFeesNeg, tSell, {
        referenceDocumentId: 'TFS-2026-0000017',
      }),
    ];
    const expanded = expandTraderLedgerStmtEntries(stmtEntries, new Map([['trade1', trade]]));
    const plain = buildInvestorLedgerGoBTimeline({ stmtEntries, avaRows: [], initialBalance: 10000 });
    const gob = buildInvestorLedgerGoBTimeline({ stmtEntries: expanded, avaRows: [], initialBalance: 10000 });

    const tradingFeeRows = gob.filter((r) => r.kind === 'stmt' && r.stmt.get('entryType') === 'trading_fees');
    expect(tradingFeeRows.length).toBe(2);
    expect(String(tradingFeeRows[0].stmt.get('description'))).toMatch(/Kauf/i);
    expect(String(tradingFeeRows[1].stmt.get('description'))).toMatch(/Verkauf/i);

    expect(gob[gob.length - 1].balanceAfter).toBeCloseTo(plain[plain.length - 1].balanceAfter, 2);
  });

  test('expandTraderLedgerStmtEntries: Investor-Group ohne trade_buy/trading_fees darf KEINE Trader-Side-Sell-Fee synthetisieren (Phantomzeile #???)', () => {
    function mockStmtRow(id, entryType, amount, createdAt, opts = {}) {
      return {
        id,
        get: (key) => {
          const map = {
            entryType,
            amount,
            createdAt,
            investmentId: opts.investmentId ?? null,
            tradeId: opts.tradeId ?? null,
            tradeNumber: opts.tradeNumber ?? null,
            description: opts.description ?? entryType,
            referenceDocumentId: opts.referenceDocumentId ?? null,
            referenceDocumentNumber: opts.referenceDocumentNumber ?? null,
            source: 'backend',
          };
          return map[key];
        },
      };
    }
    function mockTrade(buyAmount, sellAmount) {
      return {
        get: (key) => {
          if (key === 'buyOrder') return { totalAmount: buyAmount };
          if (key === 'sellOrders') return sellAmount > 0 ? [{ totalAmount: sellAmount }] : [];
          if (key === 'sellOrder') return sellAmount > 0 ? { totalAmount: sellAmount } : null;
          if (key === 'symbol') return 'JP4GN2P';
          if (key === 'tradeNumber') return 1;
          return null;
        },
      };
    }

    // Investor sieht: investment_activate, residual_return, investment_return, commission_debit.
    // KEINE trade_buy / trade_sell / trading_fees. Trader-Trade hat 1850 buy + 3000 sell
    // → calculateOrderFees(3000, true) = 15 + 0,50 + 2,50 = 18 € (Trader-Sell-Fee).
    // Diese 18 € dürfen NICHT als „Handelsgebühren Verkauf Trade #???“ erscheinen.
    const t = new Date('2026-05-19T13:22:10Z');
    const stmtEntries = [
      mockStmtRow('a1', 'investment_activate', -1500, t, { investmentId: 'GrEAcjRWaG' }),
      mockStmtRow('r1', 'residual_return', 0.3, new Date(t.getTime() + 1), {
        investmentId: 'GrEAcjRWaG', tradeId: 'trade1', tradeNumber: 1,
      }),
      mockStmtRow('ret1', 'investment_return', 2309.9, new Date(t.getTime() + 60_000), {
        investmentId: 'GrEAcjRWaG', tradeId: 'trade1', tradeNumber: 1,
        referenceDocumentNumber: 'CB-2026-0000020',
      }),
      mockStmtRow('c1', 'commission_debit', -90.02, new Date(t.getTime() + 60_500), {
        investmentId: 'GrEAcjRWaG', tradeId: 'trade1', tradeNumber: 1,
        referenceDocumentNumber: 'CB-2026-0000020',
      }),
    ];
    const expanded = expandTraderLedgerStmtEntries(stmtEntries, new Map([['trade1', mockTrade(1850, 3000)]]));
    const tradingFeeRows = expanded.filter((r) => r.get('entryType') === 'trading_fees');
    expect(tradingFeeRows.length).toBe(0);
    expect(expanded.length).toBe(stmtEntries.length);
  });

  test('applyInvestorGoBCollectionBillFeeGranularity: einzelne Kauf-/Verkaufsgebühren am Aktivierungs- bzw. Residual-Zeitpunkt', () => {
    const t0 = new Date('2026-05-01T10:00:00Z');
    const t1 = new Date('2026-05-05T12:00:00Z');
    const t2 = new Date('2026-05-18T14:00:00Z');
    const t3 = new Date('2026-05-18T14:01:00Z');
    const bill = {
      documentId: 'docCb1',
      documentNumber: 'CB-001',
      tradeId: 'trade1',
      tradeNumber: 1,
      investmentId: 'inv1',
      feeComponents: [
        { side: 'buy', key: 'orderFee', amount: 5 },
        { side: 'buy', key: 'exchangeFee', amount: 0.5 },
        { side: 'buy', key: 'foreignCosts', amount: 2.5 },
        { side: 'sell', key: 'orderFee', amount: 6.64 },
        { side: 'sell', key: 'exchangeFee', amount: 0.5 },
        { side: 'sell', key: 'foreignCosts', amount: 2.5 },
      ],
    };
    const aggFees = -(8 + 9.64);
    const stmtEntries = [
      mockStmt('d1', 'deposit', 10000, t0, null, null),
      mockStmt('a1', 'investment_activate', -1000, t1, 'inv1', null),
      mockStmt('r1', 'residual_return', 1.48, t2, 'inv1', 'trade1'),
      mockStmt('ret1', 'investment_return', 1286.26, t3, 'inv1', 'trade1'),
      mockStmt('fee1', 'trading_fees', aggFees, t3, 'inv1', 'trade1'),
    ];
    const base = buildInvestorLedgerGoBTimeline({ stmtEntries, avaRows: [], initialBalance: 0 });
    const out = applyInvestorGoBCollectionBillFeeGranularity(base, [bill], 0);

    expect(out.some((r) => r.kind === 'stmt' && r.tie === 'fee1')).toBe(false);
    const feeRows = out.filter((r) => r.kind === 'stmt' && r.stmt.get('entryType') === 'trading_fees');
    expect(feeRows.length).toBe(6);
    expect(feeRows.filter((r) => String(r.stmt.get('description')).includes('Kauf')).length).toBe(3);
    expect(feeRows.filter((r) => String(r.stmt.get('description')).includes('Verkauf')).length).toBe(3);

    const buyTimes = feeRows.filter((r) => String(r.stmt.get('description')).includes('Kauf')).map((r) => r.at.getTime());
    expect(buyTimes.every((ms) => ms > t1.getTime())).toBe(true);
    const sellTimes = feeRows.filter((r) => String(r.stmt.get('description')).includes('Verkauf')).map((r) => r.at.getTime());
    expect(sellTimes.every((ms) => ms > t2.getTime())).toBe(true);

    expect(out[out.length - 1].balanceAfter).toBeCloseTo(base[base.length - 1].balanceAfter, 2);
  });
});
