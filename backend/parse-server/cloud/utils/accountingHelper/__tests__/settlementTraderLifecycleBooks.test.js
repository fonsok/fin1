'use strict';

jest.mock('../../configHelper/index.js', () => ({
  loadConfig: jest.fn().mockResolvedValue({ financial: {} }),
}));

jest.mock('../settlementQueries', () => ({
  findExistingStatementEntry: jest.fn(),
  findExistingTraderTradeCashEntry: jest.fn().mockResolvedValue({ id: 'existing-buy' }),
}));

jest.mock('../documents', () => ({
  createTradeExecutionDocument: jest.fn().mockResolvedValue({
    document: {
      id: 'doc-fee',
      get: (k) => (k === 'accountingDocumentNumber' ? 'TFS-2026-0000001' : null),
    },
    customerDisplay: null,
  }),
  findExistingTradeExecutionDocument: jest.fn().mockResolvedValue(null),
}));

jest.mock('../poolMirrorExecutionEigenbelegBook', () => ({
  ensurePoolMirrorExecutionEigenbelegDocument: jest.fn().mockResolvedValue(null),
}));

jest.mock('../documentReferenceResolver', () => ({
  resolveDocumentReference: jest.fn(() => ({
    referenceDocumentId: 'doc-fee',
    referenceDocumentNumber: 'TFS-2026-0000001',
  })),
}));

jest.mock('../settlementDeltas', () => ({
  bookTraderSellOrderLeg: jest.fn().mockResolvedValue({ id: 'stmt-sell' }),
}));

jest.mock('../statements', () => ({
  bookSettlementEntry: jest.fn().mockResolvedValue({ id: 'stmt-fee' }),
}));

const {
  findExistingStatementEntry,
} = require('../settlementQueries');
const { bookTraderSellOrderLeg } = require('../settlementDeltas');
const { bookSettlementEntry } = require('../statements');
const { bookTraderTradeLifecycleEntries } = require('../settlementTraderLifecycleBooks');

function makeTrade(attrs) {
  return {
    id: 'trade-trader-1',
    get(k) {
      return attrs[k];
    },
  };
}

describe('bookTraderTradeLifecycleEntries', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  test('books missing sell legs per sellOrder and trading_fees', async () => {
    findExistingStatementEntry.mockResolvedValue(null);

    const sellOrder = { id: 'sell-1', quantity: 1000, totalAmount: 3000, price: 3 };
    const trade = makeTrade({
      traderId: 'trader-1',
      tradeNumber: 1,
      symbol: 'UB4PQLG',
      buyOrder: { totalAmount: 1880 },
      sellOrders: [sellOrder],
      pairExecutionId: 'pair-1',
    });

    await bookTraderTradeLifecycleEntries({
      trade,
      traderId: 'trader-1',
      tradeNumber: 1,
      totalTradingFees: 12.5,
      tradingFeeBreakdown: { orderFee: 12.5 },
      businessCaseId: 'bc-1',
    });

    expect(bookTraderSellOrderLeg).toHaveBeenCalledWith(
      expect.objectContaining({
        traderId: 'trader-1',
        trade,
        order: sellOrder,
        businessCaseId: 'bc-1',
      }),
    );
    expect(findExistingStatementEntry).toHaveBeenCalledWith({
      userId: 'trader-1',
      tradeId: 'trade-trader-1',
      entryType: 'trading_fees',
    });
    expect(bookSettlementEntry).toHaveBeenCalledWith(
      expect.objectContaining({ entryType: 'trading_fees', amount: -12.5 }),
    );
  });
});
