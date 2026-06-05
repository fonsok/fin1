'use strict';

const {
  buildTraderCustomerTimeline,
  buildNetTradeDisplayEvents,
  enrichTimelineWithTradeInstruments,
  parseInstrumentFromTrade,
  tradeStatementTitle,
  traderCustomerTimelineToApiRows,
} = require('../traderAccountStatementPresentation');

function mockStmt(id, entryType, amount, createdAt, extra = {}) {
  return {
    id,
    get: (key) => {
      const map = {
        entryType,
        amount,
        createdAt,
        tradeId: extra.tradeId || null,
        tradeNumber: extra.tradeNumber ?? null,
        referenceDocumentId: extra.referenceDocumentId || null,
        referenceDocumentNumber: extra.referenceDocumentNumber || null,
        description: extra.description || entryType,
        source: 'backend',
      };
      return map[key];
    },
  };
}

function mockInvoice(id, invoiceType, totalAmount, invoiceDate, extra = {}) {
  return {
    id,
    get: (key) => {
      const map = {
        invoiceType,
        totalAmount,
        invoiceDate,
        createdAt: invoiceDate,
        tradeId: extra.tradeId || 'trade1',
        tradeNumber: extra.tradeNumber ?? 1,
        invoiceNumber: extra.invoiceNumber || `INV-${id}`,
        side: extra.side || null,
        lineItems: extra.lineItems || [{
          itemType: 'securities',
          description: 'VO5G3MN - PUT - DAX',
          quantity: 10,
        }],
      };
      return map[key];
    },
  };
}

function mockTrade(id, buyLegType = 'TRADER') {
  return {
    id,
    get: (key) => ({ buyLegType }[key]),
  };
}

const user = { id: 'userObj', get: (k) => (k === 'stableId' ? 'user:trader@test.com' : undefined) };

describe('traderAccountStatementPresentation', () => {
  test('tradeStatementTitle builds instrument line', () => {
    const title = tradeStatementTitle('buy', {
      wknOrIsin: 'VO5G3MN',
      securitiesDirection: 'PUT',
      underlyingAsset: 'DAX',
    });
    expect(title).toBe('KAUF VO5G3MN · PUT · DAX');
  });

  test('mirror pool buy invoice and stmt legs are hidden from customer timeline', () => {
    const t0 = new Date('2026-05-01T10:00:00Z');
    const mirrorTradeId = 'mirror-trade';
    const traderTradeId = 'trader-trade';
    const stmtEntries = [
      mockStmt('m1', 'trade_buy', -8989.69, t0, { tradeId: mirrorTradeId, tradeNumber: 2 }),
      mockStmt('t1', 'trade_buy', -1668.8, t0, { tradeId: traderTradeId, tradeNumber: 1 }),
    ];
    const invoices = [
      mockInvoice('inv-mirror', 'buy_invoice', 8989.69, t0, {
        tradeId: mirrorTradeId,
        tradeNumber: 2,
        invoiceNumber: 'INV-2026-0000002',
      }),
    ];
    const instrumentContext = {
      tradeById: new Map([
        [mirrorTradeId, mockTrade(mirrorTradeId, 'MIRROR_POOL')],
        [traderTradeId, mockTrade(traderTradeId, 'TRADER')],
      ]),
      orderByTradeId: new Map(),
    };

    const events = buildNetTradeDisplayEvents(stmtEntries, invoices, instrumentContext);
    const buyEvents = events.filter((e) => e.entryType === 'trade_buy');
    expect(buyEvents).toHaveLength(1);
    expect(buyEvents[0].amount).toBe(-1668.8);
  });

  test('invoice net sell replaces duplicate trade_sell legs', () => {
    const t1 = new Date('2026-05-10T10:00:00Z');
    const t2 = new Date('2026-05-10T10:01:00Z');
    const stmtEntries = [
      mockStmt('s1', 'trade_sell', 4000, t1, {
        tradeId: 'trade1',
        tradeNumber: 1,
        referenceDocumentNumber: 'ABCDEFG-INV-001',
      }),
      mockStmt('s2', 'trade_sell', 4000, t2, {
        tradeId: 'trade1',
        tradeNumber: 1,
        referenceDocumentNumber: 'TSC-001',
      }),
      mockStmt('s3', 'trading_fees', -25.5, t2, { tradeId: 'trade1', tradeNumber: 1 }),
    ];
    const invoices = [
      mockInvoice('inv1', 'sell_invoice', 3974.5, t2, {
        tradeId: 'trade1',
        tradeNumber: 1,
        invoiceNumber: 'TSC-001',
      }),
    ];

    const events = buildNetTradeDisplayEvents(stmtEntries, invoices);
    const sellEvents = events.filter((e) => e.entryType === 'trade_sell');
    expect(sellEvents).toHaveLength(1);
    expect(sellEvents[0].amount).toBe(3974.5);
    expect(sellEvents[0].statementTitle).toContain('VERKAUF');
    expect(sellEvents[0].statementTitle).toContain('VO5G3MN');
    expect(sellEvents[0].referenceDocumentNumber).toBe('TSC-001');
  });

  test('trading_fees never appear as standalone timeline row', () => {
    const t0 = new Date('2026-05-01T10:00:00Z');
    const stmtEntries = [
      mockStmt('s1', 'trade_buy', -5000, t0, { tradeId: 't1', tradeNumber: 1 }),
      mockStmt('s2', 'trading_fees', -50, t0, { tradeId: 't1', tradeNumber: 1 }),
      mockStmt('s3', 'commission_credit', 100, t0, { tradeId: 't1', tradeNumber: 1 }),
    ];
    const timeline = buildTraderCustomerTimeline({
      stmtEntries,
      invoices: [],
      initialBalance: 10000,
    });
    const types = timeline.map((r) => r.entryType);
    expect(types).not.toContain('trading_fees');
    expect(types).toContain('trade_buy');
    expect(types).toContain('commission_credit');
  });

  test('commission_credit sorts after trade event', () => {
    const tTrade = new Date('2026-05-01T10:00:00Z');
    const tComm = new Date('2026-05-01T09:00:00Z');
    const stmtEntries = [
      mockStmt('s1', 'trade_sell', 1000, tTrade, { tradeId: 't1', tradeNumber: 1 }),
      mockStmt('s2', 'commission_credit', 50, tComm, { tradeId: 't1', tradeNumber: 1 }),
    ];
    const timeline = buildTraderCustomerTimeline({
      stmtEntries,
      invoices: [],
      initialBalance: 0,
    });
    expect(timeline[0].entryType).toBe('trade_sell');
    expect(timeline[1].entryType).toBe('commission_credit');
  });

  test('parseInstrumentFromTrade uses trade and order fields', () => {
    const trade = {
      get: (key) => ({
        wkn: 'VO5G3MN',
        symbol: 'VO5G3MN',
        securityType: 'PUT',
        quantity: 5,
        buyOrder: {},
        sellOrder: {},
        sellOrders: [],
      }[key]),
    };
    const order = {
      get: (key) => ({
        optionDirection: 'PUT',
        underlyingAsset: 'DAX',
      }[key]),
    };
    const instrument = parseInstrumentFromTrade(trade, order);
    expect(instrument.wknOrIsin).toBe('VO5G3MN');
    expect(instrument.underlyingAsset).toBe('DAX');
    expect(tradeStatementTitle('buy', instrument)).toBe('KAUF VO5G3MN · PUT · DAX');
  });

  test('enrichTimelineWithTradeInstruments fills missing titles', () => {
    const trade = {
      get: (key) => ({
        wkn: 'ABC123',
        securityType: 'CALL',
        buyOrder: {},
        sellOrder: {},
        sellOrders: [],
      }[key]),
    };
    const tradeById = new Map([['t1', trade]]);
    const timeline = [{
      tradeId: 't1',
      transactionTypeLabel: 'buy',
      wknOrIsin: null,
      securitiesDirection: null,
      underlyingAsset: null,
      statementTitle: 'KAUF · Trade #001',
    }];
    const enriched = enrichTimelineWithTradeInstruments(timeline, tradeById, new Map());
    expect(enriched[0].statementTitle).toContain('ABC123');
  });

  test('duplicate buy invoices for same tradeNumber show only once', () => {
    const t0 = new Date('2026-05-01T10:00:00Z');
    const invoices = [
      mockInvoice('inv1', 'buy_invoice', 1658.75, t0, {
        tradeId: 'trade-a',
        tradeNumber: 1,
        invoiceNumber: 'INV-2026-0000001',
      }),
      mockInvoice('inv2', 'buy_invoice', 1658.75, t0, {
        tradeId: 'trade-b',
        tradeNumber: 1,
        invoiceNumber: 'INV-2026-0000002',
      }),
    ];
    const stmtEntries = [
      mockStmt('s1', 'trade_buy', -1850, t0, {
        tradeId: 'trade-a',
        tradeNumber: 1,
        referenceDocumentNumber: 'TBC-2026-0000083',
      }),
      mockStmt('s2', 'trade_buy', -1850, t0, {
        tradeId: 'trade-b',
        tradeNumber: 1,
        referenceDocumentNumber: 'TBC-2026-0000083',
      }),
    ];

    const events = buildNetTradeDisplayEvents(stmtEntries, invoices);
    const buyEvents = events.filter((e) => e.entryType === 'trade_buy');
    expect(buyEvents).toHaveLength(1);
  });

  test('API rows expose presentation fields', () => {
    const t0 = new Date('2026-05-01T10:00:00Z');
    const invoices = [
      mockInvoice('inv1', 'buy_invoice', 5000, t0, {
        lineItems: [{ itemType: 'securities', description: 'VO5G3MN - PUT - DAX', quantity: 5 }],
      }),
    ];
    const timeline = buildTraderCustomerTimeline({
      stmtEntries: [],
      invoices,
      initialBalance: 10000,
    });
    const { rows } = traderCustomerTimelineToApiRows(user, timeline, { limit: 50, skip: 0 });
    expect(rows[0].source).toBe('customer_display');
    expect(rows[0].statementTitle).toBe('KAUF VO5G3MN · PUT · DAX');
    expect(rows[0].displayAmountMode).toBe('netCash');
    expect(rows[0].amount).toBe(-5000);
  });
});
