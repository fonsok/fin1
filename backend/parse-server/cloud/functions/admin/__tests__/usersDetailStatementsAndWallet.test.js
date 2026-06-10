'use strict';

const { buildLedgerAccountStatementFromStmtEntries } = require('../usersDetailStatementsAndWallet/ledgerStatement');
const {
  mapTraderTimelineToAdminEntries,
  mapInvestorTimelineToAdminEntries,
} = require('../usersDetailStatementsAndWallet/timelineMappers');
const { mapInvestorCollectionBillDocumentToSummary } = require('../usersDetailStatementsAndWallet/collectionBillSummaries');
const { buildInvestorMergedTimeline, buildInvestorLedgerGoBTimeline } = require('../../../utils/investorAccountStatementMerge');

describe('usersDetailStatementsAndWallet', () => {
  test('buildLedgerAccountStatementFromStmtEntries keeps trading_fees row', () => {
    const at = new Date('2026-05-01T12:00:00Z');
    const stmtEntries = [
      {
        id: 's1',
        get: (key) => ({
          entryType: 'trade_buy',
          amount: -3000,
          createdAt: at,
          tradeId: 't1',
          tradeNumber: 1,
          description: 'Buy gross',
        }[key]),
      },
      {
        id: 's2',
        get: (key) => ({
          entryType: 'trading_fees',
          amount: -39.16,
          createdAt: at,
          tradeId: 't1',
          tradeNumber: 1,
          description: 'Fees',
        }[key]),
      },
    ];
    const ledger = buildLedgerAccountStatementFromStmtEntries(
      stmtEntries,
      10000,
      (d) => d.toISOString(),
      false,
    );
    const types = ledger.entries.map((e) => e.entryType);
    expect(types).toContain('trade_buy');
    expect(types).toContain('trading_fees');
    expect(ledger.presentationMode).toBe('ledger');
  });

  test('mapTraderTimelineToAdminEntries uses statementTitle as description', () => {
    const at = new Date('2026-05-01T12:00:00Z');
    const rows = mapTraderTimelineToAdminEntries([
      {
        objectId: 'invoice-display:1:sell',
        entryType: 'trade_sell',
        amount: 3974.5,
        balanceAfter: 10_000,
        tradeId: 'trade1',
        tradeNumber: 1,
        statementTitle: 'VERKAUF VO5G3MN · PUT · DAX',
        description: 'Netto Verkauf',
        referenceDocumentId: 'doc1',
        referenceDocumentNumber: 'TSC-001',
        source: 'customer_display',
        at,
      },
    ], (d) => d.toISOString());

    expect(rows).toHaveLength(1);
    expect(rows[0].description).toBe('VERKAUF VO5G3MN · PUT · DAX');
    expect(rows[0].entryType).toBe('trade_sell');
    expect(rows[0].source).toBe('customer_display');
  });

  test('investor admin: merged customer excludes investment_activate; ledger GoB timeline keeps it', () => {
    const t1 = new Date('2026-05-01T10:00:00Z');
    const t2 = new Date('2026-05-01T11:00:00Z');
    const stmtEntries = [
      {
        id: 'a1',
        get: (key) => ({
          entryType: 'investment_activate',
          amount: -500,
          createdAt: t1,
          investmentId: 'inv1',
          tradeId: null,
          tradeNumber: null,
          description: 'activate',
          referenceDocumentId: null,
          source: 'backend',
        }[key]),
      },
      {
        id: 'd1',
        get: (key) => ({
          entryType: 'deposit',
          amount: 2000,
          createdAt: t2,
          investmentId: null,
          tradeId: null,
          tradeNumber: null,
          description: 'dep',
          referenceDocumentId: null,
          source: 'backend',
        }[key]),
      },
    ];
    const timeline = buildInvestorMergedTimeline({ stmtEntries, avaRows: [], initialBalance: 0 });
    const merged = mapInvestorTimelineToAdminEntries(timeline, (d) => d.toISOString());
    expect(merged.some((e) => e.entryType === 'investment_activate')).toBe(false);
    const ledgerTimeline = buildInvestorLedgerGoBTimeline({ stmtEntries, avaRows: [], initialBalance: 0 });
    const ledgerEntries = mapInvestorTimelineToAdminEntries(ledgerTimeline, (d) => d.toISOString());
    expect(ledgerEntries.some((e) => e.entryType === 'investment_activate')).toBe(true);
  });

  test('mapInvestorCollectionBillDocumentToSummary extracts buy/sell fee components', () => {
    const doc = {
      id: 'docCb1',
      get: (key) => {
        const map = {
          metadata: {
            transferAmount: 1286.26,
            commission: 32.1,
            commissionRate: 0.1,
            grossProfit: 321,
            netProfit: 288.9,
            totalBuyCost: 997.36,
            netSellAmount: 1318.36,
            buyLeg: {
              quantity: 332,
              price: 2.98,
              amount: 989.36,
              fees: { orderFee: 5, exchangeFee: 0.5, foreignCosts: 2.5, totalFees: 8 },
            },
            sellLeg: {
              quantity: 332,
              price: 4,
              amount: 1328,
              fees: { orderFee: 6.64, exchangeFee: 0.5, foreignCosts: 2.5, totalFees: 9.64 },
            },
          },
          accountingDocumentNumber: 'CB-2026-0000016',
          tradeId: 'tr1',
          tradeNumber: 1,
          investmentId: 'inv1',
          createdAt: new Date('2026-05-18T12:43:00Z'),
        };
        return map[key];
      },
    };
    const s = mapInvestorCollectionBillDocumentToSummary(doc, (d) => (d instanceof Date ? d.toISOString() : String(d)));
    expect(s.feeComponents.length).toBe(6);
    expect(s.commission).toBeCloseTo(32.1, 2);
    expect(s.transferAmount).toBeCloseTo(1286.26, 2);
    expect(s.feeComponents.some((f) => f.side === 'buy' && f.key === 'orderFee' && f.amount === 5)).toBe(true);
  });
});
