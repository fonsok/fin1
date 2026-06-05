'use strict';

jest.mock('../settlementQueries', () => ({
  findExistingStatementEntry: jest.fn(),
  findExistingTraderTradeCashEntry: jest.fn().mockResolvedValue({ id: 'existing-buy' }),
  resolveLedgerUserKeysForUserId: jest.fn().mockResolvedValue(['trader-1']),
  sumStatementAmounts: jest.fn().mockResolvedValue(3000),
}));

jest.mock('../documents', () => ({
  createTradeExecutionDocument: jest.fn().mockResolvedValue({
    id: 'doc-fee',
    get: (k) => (k === 'accountingDocumentNumber' ? 'TFS-2026-0000001' : null),
  }),
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

jest.mock('../settlementTradeMath', () => ({
  getTotalSellAmount: jest.fn(() => 3000),
}));

jest.mock('../statements', () => ({
  bookSettlementEntry: jest.fn().mockResolvedValue({ id: 'stmt-fee' }),
}));

const {
  findExistingStatementEntry,
} = require('../settlementQueries');
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

  test('books trading_fees when findExistingStatementEntry returns null', async () => {
    findExistingStatementEntry.mockResolvedValue(null);

    const trade = makeTrade({
      traderId: 'trader-1',
      tradeNumber: 1,
      symbol: 'UB4PQLG',
      buyOrder: { totalAmount: 1880 },
      sellOrders: [{ quantity: 1000, totalAmount: 3000, price: 3 }],
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
