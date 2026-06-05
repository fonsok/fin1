'use strict';

jest.mock('../settlementQueries', () => ({
  findExistingTraderTradeCashEntry: jest.fn(),
  prefetchInvestmentsById: jest.fn(),
  resolveLedgerUserKeysForUserId: jest.fn().mockResolvedValue(['trader-1']),
  sumStatementAmounts: jest.fn(),
}));

jest.mock('../businessCaseId', () => ({
  ensureBusinessCaseIdForTrade: jest.fn().mockResolvedValue('bc-1'),
}));

jest.mock('../documents', () => ({
  createTradeExecutionDocument: jest.fn().mockResolvedValue({
    id: 'doc-sell',
    get: (k) => (k === 'accountingDocumentNumber' ? 'TSC-2026-0000001' : null),
  }),
  createCollectionBillDocument: jest.fn(),
}));

jest.mock('../documentReferenceResolver', () => ({
  resolveDocumentReference: jest.fn(() => ({
    referenceDocumentId: 'doc-sell',
    referenceDocumentNumber: 'TSC-2026-0000001',
  })),
}));

jest.mock('../settlementTradeMath', () => ({
  getTotalSellAmount: jest.fn(),
  getTotalSellQuantity: jest.fn(),
  getRepresentativeSellOrder: jest.fn(),
}));

jest.mock('../statements', () => ({
  bookAccountStatementEntry: jest.fn(),
  bookSettlementEntry: jest.fn().mockResolvedValue({ id: 'stmt-1' }),
}));

const { bookTraderBuyEntryIfMissing, bookTraderSellDeltaIfAny } = require('../settlementDeltas');
const { sumStatementAmounts } = require('../settlementQueries');
const { getTotalSellAmount } = require('../settlementTradeMath');
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

  test('skips when sell amount is already fully booked', async () => {
    getTotalSellAmount
      .mockReturnValueOnce(3974.5)
      .mockReturnValueOnce(3000);
    sumStatementAmounts.mockResolvedValue(3974.5);

    const trade = makeTrade({ traderId: 'trader-1', tradeNumber: 1, symbol: 'DAX' });
    const previous = makeTrade({ traderId: 'trader-1', tradeNumber: 1, symbol: 'DAX' });

    const result = await bookTraderSellDeltaIfAny({ trade, previousTrade: previous });
    expect(result).toBeNull();
    expect(bookSettlementEntry).not.toHaveBeenCalled();
  });

  test('books only the remaining sell delta when partial rows exist', async () => {
    getTotalSellAmount
      .mockReturnValueOnce(3974.5)
      .mockReturnValueOnce(2000);
    sumStatementAmounts.mockResolvedValue(2000);

    const trade = makeTrade({ traderId: 'trader-1', tradeNumber: 1, symbol: 'DAX' });
    const previous = makeTrade({ traderId: 'trader-1', tradeNumber: 1, symbol: 'DAX' });

    await bookTraderSellDeltaIfAny({ trade, previousTrade: previous });

    expect(bookSettlementEntry).toHaveBeenCalledWith(
      expect.objectContaining({
        entryType: 'trade_sell',
        amount: 1974.5,
        tradeId: 'trade-1',
      }),
    );
  });
});
