'use strict';

jest.mock('../../configHelper/index.js', () => ({
  loadConfig: jest.fn().mockResolvedValue({ financial: {} }),
}));

jest.mock('../settlementQueries', () => ({
  findExistingTraderTradeCashEntry: jest.fn(),
  findExistingStatementEntry: jest.fn().mockResolvedValue(null),
}));

jest.mock('../businessCaseId', () => ({
  ensureBusinessCaseIdForTrade: jest.fn().mockResolvedValue('bc-1'),
}));

jest.mock('../documents', () => ({
  createTradeExecutionDocument: jest.fn().mockResolvedValue({
    document: {
      id: 'doc-sell',
      get: (k) => {
        if (k === 'accountingDocumentNumber') return 'TSC-2026-0000001';
        if (k === 'metadata') {
          return {
            executionType: 'sell',
            quantity: 500,
            partialSell: { orderQuantity: 500 },
            instrumentLine: 'UB4PQLG - PUT - Dow Jones',
          };
        }
        return null;
      },
    },
    customerDisplay: {
      schemaVersion: 1,
      transactionType: 'sell',
      wknOrIsin: 'UB4PQLG',
      securitiesDirection: 'PUT',
      underlyingAsset: 'Dow Jones',
      quantity: '500',
      statementTitle: 'VERKAUF · PUT · Dow Jones · UB4PQLG',
    },
  }),
  findExistingTradeExecutionDocument: jest.fn().mockResolvedValue(null),
}));

jest.mock('../documentReferenceResolver', () => ({
  resolveDocumentReference: jest.fn(() => ({
    referenceDocumentId: 'doc-sell',
    referenceDocumentNumber: 'TSC-2026-0000001',
  })),
}));

jest.mock('../poolMirrorExecutionEigenbelegBook', () => ({
  ensurePoolMirrorExecutionEigenbelegDocument: jest.fn().mockResolvedValue(undefined),
}));

jest.mock('../settlementTradeMath', () => {
  const actual = jest.requireActual('../settlementTradeMath');
  return {
    ...actual,
    getSellOrdersAddedSince: jest.fn(),
  };
});

jest.mock('../statements', () => ({
  bookAccountStatementEntry: jest.fn(),
  bookSettlementEntry: jest.fn().mockResolvedValue({ id: 'stmt-1' }),
}));

const { createTradeExecutionDocument } = require('../documents');
const { ensurePoolMirrorExecutionEigenbelegDocument } = require('../poolMirrorExecutionEigenbelegBook');
const { bookTraderBuyEntryIfMissing, bookTraderSellDeltaIfAny } = require('../settlementDeltas');
const { findExistingStatementEntry } = require('../settlementQueries');
const { getSellOrdersAddedSince } = require('../settlementTradeMath');
const { bookSettlementEntry } = require('../statements');

function makeTrade(attrs) {
  return {
    id: 'trade-1',
    get(k) {
      return attrs[k];
    },
  };
}

describe('bookTraderBuyEntryIfMissing', () => {
  test('skips MIRROR_POOL trade leg', async () => {
    const trade = makeTrade({ traderId: 'trader-1', tradeNumber: 2, buyLegType: 'MIRROR_POOL' });
    const result = await bookTraderBuyEntryIfMissing(trade);
    expect(result).toBeNull();
    expect(bookSettlementEntry).not.toHaveBeenCalled();
  });
});

describe('bookTraderSellDeltaIfAny', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    findExistingStatementEntry.mockResolvedValue(null);
  });

  test('skips MIRROR_POOL trade leg', async () => {
    const trade = makeTrade({
      traderId: 'trader-1',
      tradeNumber: 2,
      symbol: 'DAX',
      buyLegType: 'MIRROR_POOL',
    });
    const previous = makeTrade({ traderId: 'trader-1', tradeNumber: 2, symbol: 'DAX' });

    const result = await bookTraderSellDeltaIfAny({ trade, previousTrade: previous });
    expect(result).toBeNull();
    expect(bookSettlementEntry).not.toHaveBeenCalled();
  });

  test('skips when no new sell orders since previous save', async () => {
    getSellOrdersAddedSince.mockReturnValue([]);

    const trade = makeTrade({ traderId: 'trader-1', tradeNumber: 1, symbol: 'DAX' });
    const previous = makeTrade({ traderId: 'trader-1', tradeNumber: 1, symbol: 'DAX' });

    const result = await bookTraderSellDeltaIfAny({ trade, previousTrade: previous });
    expect(result).toBeNull();
    expect(bookSettlementEntry).not.toHaveBeenCalled();
  });

  test('books net cash (Σ VERKAUF) per new sell order, not gross Kurswert', async () => {
    getSellOrdersAddedSince.mockReturnValue([
      { id: 'sell-leg-1', quantity: 500, totalAmount: 1000, price: 2 },
    ]);

    const trade = makeTrade({
      traderId: 'trader-1',
      tradeNumber: 1,
      symbol: 'DAX',
      status: 'partial',
      quantity: 1000,
    });
    const previous = makeTrade({ traderId: 'trader-1', tradeNumber: 1, symbol: 'DAX', quantity: 1000 });

    await bookTraderSellDeltaIfAny({ trade, previousTrade: previous });

    expect(createTradeExecutionDocument).toHaveBeenCalledWith(
      expect.objectContaining({
        executionType: 'sell',
        amount: 1000,
        sellOrderId: 'sell-leg-1',
      }),
    );
    expect(ensurePoolMirrorExecutionEigenbelegDocument).toHaveBeenCalledWith(
      expect.objectContaining({
        executionType: 'sell',
        sellOrderId: 'sell-leg-1',
      }),
    );
    expect(bookSettlementEntry).toHaveBeenCalledWith(
      expect.objectContaining({
        entryType: 'trade_sell',
        amount: 992,
        tradeId: 'trade-1',
        customerDisplaySnapshot: expect.objectContaining({
          schemaVersion: 1,
          quantity: '500',
        }),
      }),
    );
  });

  test('passes sellOrderId to createTradeExecutionDocument for per-order belege', async () => {
    getSellOrdersAddedSince.mockReturnValue([
      { id: 'sell-leg-2', quantity: 200, totalAmount: 1000 },
    ]);

    const trade = makeTrade({ traderId: 'trader-1', tradeNumber: 1, symbol: 'DAX', quantity: 1000 });
    const previous = makeTrade({ traderId: 'trader-1', tradeNumber: 1, symbol: 'DAX', quantity: 1000 });

    await bookTraderSellDeltaIfAny({ trade, previousTrade: previous });

    expect(createTradeExecutionDocument).toHaveBeenCalledWith(
      expect.objectContaining({
        executionType: 'sell',
        sellOrderId: 'sell-leg-2',
      }),
    );
  });

  test('skips statement when already booked for same TSC document', async () => {
    getSellOrdersAddedSince.mockReturnValue([
      { id: 'sell-leg-1', quantity: 500, totalAmount: 1000 },
    ]);
    findExistingStatementEntry.mockResolvedValue({ id: 'stmt-existing' });

    const trade = makeTrade({ traderId: 'trader-1', tradeNumber: 1, symbol: 'DAX', quantity: 1000 });
    const previous = makeTrade({ traderId: 'trader-1', tradeNumber: 1, symbol: 'DAX', quantity: 1000 });

    const result = await bookTraderSellDeltaIfAny({ trade, previousTrade: previous });

    expect(result).toEqual({ id: 'stmt-existing' });
    expect(bookSettlementEntry).not.toHaveBeenCalled();
  });
});
