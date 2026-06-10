'use strict';

const { buildTraderCustomerTimeline } = require('../traderAccountStatementPresentation/timeline');
const { buildNetTradeDisplayEvents } = require('../traderAccountStatementPresentation/netTradeDisplay');
const {
  enrichTimelineWithTradeInstruments,
  parseInstrumentFromTrade,
  parseInstrumentFromInvoice,
  shouldEnrichTimelineEvent,
} = require('../traderAccountStatementPresentation/instruments');
const {
  buildOrderMapsFromParseOrders,
  resolveOrderForTradeSide,
} = require('../traderAccountStatementPresentation/orderContext');
const { tradeStatementTitle } = require('../traderAccountStatementPresentation/instrumentTitles');
const { traderCustomerTimelineToApiRows } = require('../traderAccountStatementPresentation/apiRows');

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
        customerDisplaySnapshot: extra.customerDisplaySnapshot || null,
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
        orderId: extra.orderId || null,
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

function mockParseOrder(id, side, tradeId, extra = {}) {
  return {
    id,
    get: (key) => ({
      tradeId,
      side,
      wkn: extra.wkn || 'UB4PQLG',
      symbol: extra.symbol || 'UB4PQLG',
      optionDirection: extra.optionDirection || 'PUT',
      underlyingAsset: extra.underlyingAsset || 'Dow Jones',
      quantity: extra.quantity ?? 500,
      executedQuantity: extra.executedQuantity ?? extra.quantity ?? 500,
      grossAmount: extra.grossAmount ?? 2000,
      netAmount: extra.netAmount ?? 1987,
      legType: extra.legType || 'TRADER',
    }[key]),
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
    expect(title).toBe('KAUF · PUT · DAX · VO5G3MN');
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
      buyOrderByTradeId: new Map(),
      sellOrdersByTradeId: new Map(),
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
    const instrument = parseInstrumentFromTrade(trade, order, { transactionType: 'buy' });
    expect(instrument.wknOrIsin).toBe('VO5G3MN');
    expect(instrument.underlyingAsset).toBe('DAX');
    expect(instrument.quantity).toBe('5');
    expect(tradeStatementTitle('buy', instrument)).toBe('KAUF · PUT · DAX · VO5G3MN');
  });

  test('parseInstrumentFromTrade uses sell-order underlying for buy when buy snapshot lacks it', () => {
    const trade = {
      get: (key) => ({
        wkn: 'UB4PQLG',
        symbol: 'UB4PQLG',
        securityType: 'PUT',
        quantity: 1000,
        buyOrder: { wkn: 'UB4PQLG', optionDirection: 'PUT', underlyingAsset: 'UB4PQLG' },
        sellOrder: { underlyingAsset: 'Dow Jones', optionDirection: 'PUT' },
        sellOrders: [],
      }[key]),
    };
    const instrument = parseInstrumentFromTrade(trade, null, { transactionType: 'buy' });
    expect(instrument.underlyingAsset).toBe('Dow Jones');
    expect(tradeStatementTitle('buy', instrument)).toBe('KAUF · PUT · Dow Jones · UB4PQLG');
  });

  test('resolveOrderQuantity uses order quantity when executedQuantity is zero', () => {
    const trade = {
      get: (key) => ({
        wkn: 'VO47OXA',
        symbol: 'VO47OXA',
        securityType: 'PUT',
        quantity: 900,
        buyOrder: { wkn: 'VO47OXA', quantity: 900 },
        sellOrder: {},
        sellOrders: [],
      }[key]),
    };
    const sellOrder = mockParseOrder('sell-partial', 'sell', 'trade-1', {
      quantity: 300,
      executedQuantity: 0,
      netAmount: 2668,
    });
    const instrument = parseInstrumentFromTrade(trade, sellOrder, { transactionType: 'sell' });
    expect(instrument.quantity).toBe('300');
  });

  test('stmt leg prefers booking-time customerDisplaySnapshot over order reconstruction', () => {
    const t0 = new Date('2026-06-10T15:00:00Z');
    const tradeId = 'trade-snapshot';
    const trade = {
      id: tradeId,
      get: (key) => ({
        wkn: 'VO47OXA',
        symbol: 'VO47OXA',
        securityType: 'PUT',
        quantity: 900,
        buyLegType: 'TRADER',
        buyOrder: { wkn: 'VO47OXA', quantity: 900 },
        sellOrder: {},
        sellOrders: [],
      }[key]),
    };
    const stmtEntries = [
      mockStmt('s-snap', 'trade_sell', 2668, t0, {
        tradeId,
        tradeNumber: 1,
        referenceDocumentNumber: 'TSC-2026-0000999',
        customerDisplaySnapshot: {
          schemaVersion: 1,
          transactionType: 'sell',
          wknOrIsin: 'VO47OXA',
          securitiesDirection: 'PUT',
          underlyingAsset: 'DAX',
          quantity: '300',
          statementTitle: 'VERKAUF · PUT · DAX · VO47OXA',
        },
      }),
    ];
    const instrumentContext = {
      tradeById: new Map([[tradeId, trade]]),
      buyOrderByTradeId: new Map(),
      sellOrdersByTradeId: new Map([[tradeId, [
        mockParseOrder('sell-wrong', 'sell', tradeId, { quantity: 900, executedQuantity: 900 }),
      ]]]),
    };
    const events = buildNetTradeDisplayEvents(stmtEntries, [], instrumentContext);
    expect(events[0].quantity).toBe('300');
    expect(events[0].statementTitle).toBe('VERKAUF · PUT · DAX · VO47OXA');
    expect(events[0].instrumentResolvedFromTrade).toBe(true);
  });

  test('partial sell stmt leg uses parse sell order quantity when executedQuantity is zero', () => {
    const t0 = new Date('2026-06-10T15:00:00Z');
    const tradeId = 'trade-vo47';
    const trade = {
      id: tradeId,
      get: (key) => ({
        wkn: 'VO47OXA',
        symbol: 'VO47OXA',
        securityType: 'PUT',
        quantity: 900,
        buyLegType: 'TRADER',
        buyOrder: { wkn: 'VO47OXA', quantity: 900 },
        sellOrder: {},
        sellOrders: [],
      }[key]),
    };
    const sellOrder = mockParseOrder('sell-partial', 'sell', tradeId, {
      quantity: 300,
      executedQuantity: 0,
      netAmount: 2668,
    });
    const stmtEntries = [
      mockStmt('s1', 'trade_sell', 2668, t0, {
        tradeId,
        tradeNumber: 1,
        referenceDocumentNumber: 'TSC-2026-0000127',
      }),
    ];
    const instrumentContext = {
      tradeById: new Map([[tradeId, trade]]),
      buyOrderByTradeId: new Map(),
      sellOrdersByTradeId: new Map([[tradeId, [sellOrder]]]),
    };
    const events = buildNetTradeDisplayEvents(stmtEntries, [], instrumentContext);
    expect(events[0].quantity).toBe('300');
  });

  test('parseInstrumentFromTrade uses sell-order quantity for partial sell, not trade buy quantity', () => {
    const trade = {
      get: (key) => ({
        wkn: 'UB4PQLG',
        symbol: 'UB4PQLG',
        securityType: 'PUT',
        quantity: 1000,
        buyOrder: { wkn: 'UB4PQLG', quantity: 1000 },
        sellOrder: {
          wkn: 'UB4PQLG',
          optionDirection: 'PUT',
          underlyingAsset: 'Dow Jones',
          quantity: 500,
        },
        sellOrders: [{
          id: 'sell-1',
          wkn: 'UB4PQLG',
          optionDirection: 'PUT',
          underlyingAsset: 'Dow Jones',
          quantity: 500,
          totalAmount: 1987,
        }],
      }[key]),
    };
    const instrument = parseInstrumentFromTrade(trade, null, { transactionType: 'sell' });
    expect(instrument.quantity).toBe('500');
    expect(instrument.underlyingAsset).toBe('Dow Jones');
    expect(tradeStatementTitle('sell', instrument)).toBe('VERKAUF · PUT · Dow Jones · UB4PQLG');
  });

  test('partial sell trade_sell stmt leg shows sell-order quantity in API row', () => {
    const t0 = new Date('2026-06-08T10:00:00Z');
    const tradeId = 'trade-partial';
    const trade = {
      id: tradeId,
      get: (key) => ({
        wkn: 'UB4PQLG',
        symbol: 'UB4PQLG',
        securityType: 'PUT',
        quantity: 1000,
        buyLegType: 'TRADER',
        buyOrder: { wkn: 'UB4PQLG', quantity: 1000 },
        sellOrder: {
          wkn: 'UB4PQLG',
          optionDirection: 'PUT',
          underlyingAsset: 'Dow Jones',
          quantity: 500,
          totalAmount: 1987,
        },
        sellOrders: [{
          id: 'sell-1',
          wkn: 'UB4PQLG',
          optionDirection: 'PUT',
          underlyingAsset: 'Dow Jones',
          quantity: 500,
          totalAmount: 1987,
        }],
      }[key]),
    };
    const stmtEntries = [
      mockStmt('s1', 'trade_sell', 1987, t0, {
        tradeId,
        tradeNumber: 1,
        referenceDocumentNumber: 'TSC-2026-0000124',
      }),
    ];
    const instrumentContext = {
      tradeById: new Map([[tradeId, trade]]),
      buyOrderByTradeId: new Map(),
      sellOrdersByTradeId: new Map([[
        tradeId,
        [mockParseOrder('sell-1', 'sell', tradeId, { quantity: 500, netAmount: 1987 })],
      ]]),
    };
    const events = buildNetTradeDisplayEvents(stmtEntries, [], instrumentContext);
    const sellEvents = events.filter((e) => e.entryType === 'trade_sell');
    expect(sellEvents).toHaveLength(1);
    expect(sellEvents[0].quantity).toBe('500');
    expect(sellEvents[0].statementTitle).toContain('Dow Jones');

    const timeline = buildTraderCustomerTimeline({
      stmtEntries,
      invoices: [],
      initialBalance: 0,
      instrumentContext,
    });
    const { rows } = traderCustomerTimelineToApiRows(user, timeline, { limit: 50, skip: 0 });
    expect(rows[0].quantity).toBe('500');
  });

  test('enrichTimelineWithTradeInstruments skips events already resolved from trade', () => {
    const trade = {
      get: (key) => ({
        wkn: 'OTHER',
        securityType: 'CALL',
        buyOrder: {},
        sellOrder: {},
        sellOrders: [],
      }[key]),
    };
    const timeline = [{
      tradeId: 't1',
      transactionTypeLabel: 'buy',
      statementTitle: 'KAUF · PUT · Dow Jones · UB4PQLG',
      instrumentResolvedFromTrade: true,
    }];
    expect(shouldEnrichTimelineEvent(timeline[0])).toBe(false);
    const enriched = enrichTimelineWithTradeInstruments(timeline, {
      tradeById: new Map([['t1', trade]]),
      buyOrderByTradeId: new Map(),
      sellOrdersByTradeId: new Map(),
    });
    expect(enriched[0].statementTitle).toBe('KAUF · PUT · Dow Jones · UB4PQLG');
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
    const enriched = enrichTimelineWithTradeInstruments(timeline, {
      tradeById,
      buyOrderByTradeId: new Map(),
      sellOrdersByTradeId: new Map(),
    });
    expect(enriched[0].statementTitle).toContain('ABC123');
  });

  test('buy invoice display uses trade instrument and unified title schema', () => {
    const t0 = new Date('2026-06-08T09:00:00Z');
    const tradeId = 'trade-buy-inv';
    const trade = {
      id: tradeId,
      get: (key) => ({
        wkn: 'UB4PQLG',
        symbol: 'UB4PQLG',
        securityType: 'PUT',
        quantity: 1000,
        buyLegType: 'TRADER',
        buyOrder: { wkn: 'UB4PQLG', optionDirection: 'PUT', underlyingAsset: 'UB4PQLG' },
        sellOrder: { underlyingAsset: 'Dow Jones', optionDirection: 'PUT' },
        sellOrders: [],
      }[key]),
    };
    const invoices = [
      mockInvoice('inv-buy', 'buy_invoice', 2513, t0, {
        tradeId,
        tradeNumber: 1,
        invoiceNumber: 'INV-2026-0000001',
        lineItems: [{
          itemType: 'securities',
          description: 'UB4PQLG - PUT - UB4PQLG - Strike 17191.23',
          quantity: 1000,
        }],
      }),
    ];
    const instrumentContext = {
      tradeById: new Map([[tradeId, trade]]),
      buyOrderByTradeId: new Map(),
      sellOrdersByTradeId: new Map(),
    };

    const events = buildNetTradeDisplayEvents([], invoices, instrumentContext);
    const buyEvents = events.filter((e) => e.entryType === 'trade_buy');
    expect(buyEvents).toHaveLength(1);
    expect(buyEvents[0].statementTitle).toBe('KAUF · PUT · Dow Jones · UB4PQLG');
    expect(buyEvents[0].underlyingAsset).toBe('Dow Jones');
    expect(buyEvents[0].instrumentResolvedFromTrade).toBe(true);
  });

  test('parseInstrumentFromInvoice prefers structured securities line item fields', () => {
    const invoice = mockInvoice('inv-structured', 'buy_invoice', 1000, new Date(), {
      lineItems: [{
        itemType: 'securities',
        description: 'UB4PQLG - PUT - UB4PQLG - Strike 17191.23',
        quantity: 1000,
        wkn: 'UB4PQLG',
        optionDirection: 'PUT',
        underlyingAsset: 'Dow Jones',
        strikePrice: '17191.23',
        issuer: 'Issuer AG',
      }],
    });
    const instrument = parseInstrumentFromInvoice(invoice);
    expect(instrument.underlyingAsset).toBe('Dow Jones');
    expect(instrument.strikePrice).toBe('Strike 17191.23');
    expect(tradeStatementTitle('buy', instrument)).toBe('KAUF · PUT · Dow Jones · UB4PQLG');
  });

  test('two partial sell stmt legs show as separate events with distinct TSC belege', () => {
    const t1 = new Date('2026-06-08T10:00:00Z');
    const t2 = new Date('2026-06-09T11:00:00Z');
    const tradeId = 'trade-vo47-partial';
    const trade = {
      id: tradeId,
      get: (key) => ({
        wkn: 'VO47OXA',
        symbol: 'VO47OXA',
        securityType: 'PUT',
        quantity: 1000,
        buyLegType: 'TRADER',
        buyOrder: { wkn: 'VO47OXA', quantity: 1000 },
        sellOrder: {},
        sellOrders: [],
      }[key]),
    };
    const sellOrder1 = mockParseOrder('sell-1', 'sell', tradeId, {
      quantity: 500,
      netAmount: 1500,
      underlyingAsset: 'DAX',
    });
    const sellOrder2 = mockParseOrder('sell-2', 'sell', tradeId, {
      quantity: 300,
      netAmount: 900,
      underlyingAsset: 'DAX',
    });
    const stmtEntries = [
      mockStmt('s-sell-1', 'trade_sell', 1500, t1, {
        tradeId,
        tradeNumber: 1,
        referenceDocumentId: 'doc-tsc-128',
        referenceDocumentNumber: 'TSC-2026-0000128',
        customerDisplaySnapshot: {
          schemaVersion: 1,
          transactionType: 'sell',
          wknOrIsin: 'VO47OXA',
          securitiesDirection: 'PUT',
          underlyingAsset: 'DAX',
          quantity: '500',
          statementTitle: 'VERKAUF · PUT · DAX · VO47OXA',
        },
      }),
      mockStmt('s-sell-2', 'trade_sell', 900, t2, {
        tradeId,
        tradeNumber: 1,
        referenceDocumentId: 'doc-tsc-129',
        referenceDocumentNumber: 'TSC-2026-0000129',
        customerDisplaySnapshot: {
          schemaVersion: 1,
          transactionType: 'sell',
          wknOrIsin: 'VO47OXA',
          securitiesDirection: 'PUT',
          underlyingAsset: 'DAX',
          quantity: '300',
          statementTitle: 'VERKAUF · PUT · DAX · VO47OXA',
        },
      }),
    ];
    const instrumentContext = {
      tradeById: new Map([[tradeId, trade]]),
      buyOrderByTradeId: new Map(),
      sellOrdersByTradeId: new Map([[tradeId, [sellOrder1, sellOrder2]]]),
    };
    const events = buildNetTradeDisplayEvents(stmtEntries, [], instrumentContext);
    const sellEvents = events
      .filter((e) => e.entryType === 'trade_sell')
      .sort((a, b) => a.at.getTime() - b.at.getTime());
    expect(sellEvents).toHaveLength(2);
    expect(sellEvents[0].referenceDocumentNumber).toBe('TSC-2026-0000128');
    expect(sellEvents[0].quantity).toBe('500');
    expect(sellEvents[0].netAmount).toBe(1500);
    expect(sellEvents[1].referenceDocumentNumber).toBe('TSC-2026-0000129');
    expect(sellEvents[1].quantity).toBe('300');
    expect(sellEvents[1].netAmount).toBe(900);
  });

  test('multiple sell invoices for same trade each produce a display event', () => {
    const t1 = new Date('2026-06-08T10:00:00Z');
    const t2 = new Date('2026-06-09T11:00:00Z');
    const tradeId = 'trade-multi-inv';
    const invoices = [
      mockInvoice('inv-sell-1', 'sell_invoice', 1500, t1, {
        tradeId,
        tradeNumber: 1,
        orderId: 'sell-1',
        invoiceNumber: 'TSC-2026-0000128',
      }),
      mockInvoice('inv-sell-2', 'sell_invoice', 900, t2, {
        tradeId,
        tradeNumber: 1,
        orderId: 'sell-2',
        invoiceNumber: 'TSC-2026-0000129',
      }),
    ];
    const stmtEntries = [
      mockStmt('s1', 'trade_sell', 1500, t1, {
        tradeId,
        tradeNumber: 1,
        referenceDocumentNumber: 'TSC-2026-0000128',
      }),
      mockStmt('s2', 'trade_sell', 900, t2, {
        tradeId,
        tradeNumber: 1,
        referenceDocumentNumber: 'TSC-2026-0000129',
      }),
    ];
    const events = buildNetTradeDisplayEvents(stmtEntries, invoices);
    const sellEvents = events
      .filter((e) => e.entryType === 'trade_sell')
      .sort((a, b) => a.at.getTime() - b.at.getTime());
    expect(sellEvents).toHaveLength(2);
    expect(sellEvents[0].netAmount).toBe(1500);
    expect(sellEvents[1].netAmount).toBe(900);
  });

  test('buildOrderMapsFromParseOrders keeps one buy and multiple sells per trade', () => {
    const tradeId = 'trade-1';
    const orders = [
      mockParseOrder('buy-1', 'buy', tradeId, { quantity: 1000 }),
      mockParseOrder('sell-1', 'sell', tradeId, { quantity: 500, netAmount: 1987 }),
      mockParseOrder('sell-2', 'sell', tradeId, { quantity: 500, netAmount: 1990 }),
    ];
    const maps = buildOrderMapsFromParseOrders(orders);
    expect(maps.buyOrderByTradeId.get(tradeId).id).toBe('buy-1');
    expect(maps.sellOrdersByTradeId.get(tradeId)).toHaveLength(2);
  });

  test('sell invoice display resolves quantity from linked sell order', () => {
    const t0 = new Date('2026-06-08T11:00:00Z');
    const tradeId = 'trade-sell-inv';
    const sellOrder = mockParseOrder('sell-partial', 'sell', tradeId, {
      quantity: 500,
      underlyingAsset: 'Dow Jones',
      netAmount: 1987,
    });
    const trade = {
      id: tradeId,
      get: (key) => ({
        wkn: 'UB4PQLG',
        quantity: 1000,
        buyLegType: 'TRADER',
        buyOrder: { wkn: 'UB4PQLG', quantity: 1000 },
        sellOrder: {},
        sellOrders: [],
      }[key]),
    };
    const invoices = [
      mockInvoice('inv-sell', 'sell_invoice', 1987, t0, {
        tradeId,
        orderId: 'sell-partial',
        lineItems: [{
          itemType: 'securities',
          description: 'UB4PQLG - PUT - UB4PQLG',
          quantity: 1000,
          wkn: 'UB4PQLG',
          optionDirection: 'PUT',
          underlyingAsset: 'Dow Jones',
        }],
      }),
    ];
    const instrumentContext = {
      tradeById: new Map([[tradeId, trade]]),
      buyOrderByTradeId: new Map([[tradeId, mockParseOrder('buy-1', 'buy', tradeId, { quantity: 1000 })]]),
      sellOrdersByTradeId: new Map([[tradeId, [sellOrder]]]),
    };
    const events = buildNetTradeDisplayEvents([], invoices, instrumentContext);
    expect(events[0].quantity).toBe('500');
    expect(events[0].statementTitle).toBe('VERKAUF · PUT · Dow Jones · UB4PQLG');

    const resolved = resolveOrderForTradeSide(instrumentContext, tradeId, 'sell', {
      orderId: 'sell-partial',
    });
    expect(resolved.id).toBe('sell-partial');
  });

  test('enrichTimelineWithTradeInstruments refreshes invoice buy title when wkn already set', () => {
    const trade = {
      get: (key) => ({
        wkn: 'UB4PQLG',
        securityType: 'PUT',
        buyOrder: { wkn: 'UB4PQLG', optionDirection: 'PUT' },
        sellOrder: { underlyingAsset: 'Dow Jones', optionDirection: 'PUT' },
        sellOrders: [],
      }[key]),
    };
    const timeline = [{
      tradeId: 't1',
      transactionTypeLabel: 'buy',
      wknOrIsin: 'UB4PQLG',
      underlyingAsset: 'UB4PQLG',
      securitiesDirection: 'PUT',
      statementTitle: 'KAUF UB4PQLG · PUT · UB4PQLG',
    }];
    const enriched = enrichTimelineWithTradeInstruments(timeline, {
      tradeById: new Map([['t1', trade]]),
      buyOrderByTradeId: new Map(),
      sellOrdersByTradeId: new Map(),
    });
    expect(enriched[0].statementTitle).toBe('KAUF · PUT · Dow Jones · UB4PQLG');
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
    expect(rows[0].statementTitle).toBe('KAUF · PUT · DAX · VO5G3MN');
    expect(rows[0].displayAmountMode).toBe('netCash');
    expect(rows[0].amount).toBe(-5000);
  });
});
