'use strict';

jest.mock('../../configHelper/index.js', () => ({
  getTraderCommissionRate: jest.fn().mockResolvedValue(0.15),
  getCommissionRateBundle: jest.fn().mockResolvedValue({
    traderRate: 0.15,
    appRate: 0,
    totalRate: 0.15,
  }),
  loadConfig: jest.fn().mockResolvedValue({ financial: {}, tax: {} }),
}));

jest.mock('../businessCaseId', () => ({
  ensureBusinessCaseIdForTrade: jest.fn().mockResolvedValue('bc-1'),
}));

jest.mock('../documents', () => ({
  createPartialSellInternalBeleg: jest.fn().mockResolvedValue({
    id: 'eb-1',
    get: (k) => (k === 'accountingDocumentNumber' ? 'EBP-2026-0000001' : null),
  }),
}));

jest.mock('../documentReferenceResolver', () => ({
  resolveDocumentReference: jest.fn(() => ({
    referenceDocumentId: 'eb-1',
    referenceDocumentNumber: 'EBP-2026-0000001',
  })),
}));

jest.mock('../settlementQueries', () => ({
  prefetchInvestmentsById: jest.fn(),
}));

jest.mock('../settlementInvestmentFallback', () => ({
  findInvestment: jest.fn(),
}));

jest.mock('../investmentEscrow', () => ({
  bookPartialSellPoolRelease: jest.fn().mockResolvedValue(undefined),
  bookPartialSellProfitRecognition: jest.fn().mockResolvedValue(undefined),
  hasEscrowLeg: jest.fn().mockResolvedValue(true),
}));

jest.mock('../../poolMirrorEconomics', () => ({
  resolvePoolContextForTraderSell: jest.fn(),
  computeInvestorPartialSellDelta: jest.fn(),
}));

jest.mock('../statements', () => ({
  bookAccountStatementEntry: jest.fn(),
  bookSettlementEntry: jest.fn(),
}));

const { resolvePoolContextForTraderSell, computeInvestorPartialSellDelta } = require('../../poolMirrorEconomics');
const { prefetchInvestmentsById } = require('../settlementQueries');

const { createPartialSellInternalBeleg } = require('../documents');
const {
  bookPartialSellPoolRelease,
  bookPartialSellProfitRecognition,
  hasEscrowLeg,
} = require('../investmentEscrow');
const { bookAccountStatementEntry, bookSettlementEntry } = require('../statements');
const { bookInvestorPartialRealizationDeltaIfAny } = require('../settlementInvestorPartialRealization');

function makeTrade(attrs, sellOrders = []) {
  return {
    id: attrs.id || 'trader-trade-1',
    get(k) {
      if (k === 'sellOrders') return sellOrders;
      return attrs[k];
    },
  };
}

function makeParticipation(investmentId) {
  return {
    get(k) {
      if (k === 'investmentId') return investmentId;
      if (k === 'isSettled') return false;
      return null;
    },
  };
}

function makeInvestment(id, investorId) {
  return {
    id,
    get(k) {
      const map = {
        investorId,
        investmentNumber: `INV-${id}`,
        amount: 1000,
        status: 'active',
      };
      return map[k];
    },
  };
}

describe('bookInvestorPartialRealizationDeltaIfAny (ADR-015)', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    hasEscrowLeg.mockResolvedValue(true);
    global.Parse = {
      Object: {
        extend(className) {
          return class {
            constructor() {
              this.attrs = {};
            }

            set(k, v) {
              this.attrs[k] = v;
            }

            unset(k) {
              delete this.attrs[k];
            }

            get(k) {
              return this.attrs[k];
            }

            toJSON() {
              return { ...this.attrs, objectId: this.id };
            }
          };
        },
      },
    };
  });

  test('books internal beleg + PTR→PPS escrow, no investor statement entries', async () => {
    const poolTrade = makeTrade({ id: 'pool-1', tradeNumber: '001' });
    const traderTrade = makeTrade(
      { id: 'trader-1', tradeNumber: '001', quantity: 1000, buyOrder: { quantity: 1000 } },
      [{ id: 'sell-order-1', quantity: 500, totalAmount: 1000 }],
    );
    const previousTrade = makeTrade(
      { id: 'trader-1', quantity: 1000, buyOrder: { quantity: 1000 } },
      [],
    );
    const participation = makeParticipation('inv-1');
    const investment = makeInvestment('inv-1', 'investor-1');

    resolvePoolContextForTraderSell.mockResolvedValue({
      poolTrade,
      traderTrade,
      participations: [participation],
    });
    prefetchInvestmentsById.mockResolvedValue(new Map([['inv-1', investment]]));
    computeInvestorPartialSellDelta.mockReturnValue({
      buyLeg: { amount: 415.5 },
      sellLeg: { quantity: 50, price: 2 },
      grossProfit: 50,
      commission: 7.5,
      netProfit: 42.5,
      investorSellCashDelta: 500,
      investorCostDelta: 415.5,
    });

    const results = await bookInvestorPartialRealizationDeltaIfAny({
      trade: traderTrade,
      previousTrade,
    });

    expect(createPartialSellInternalBeleg).toHaveBeenCalledWith(
      expect.objectContaining({
        investorId: 'investor-1',
        investmentId: 'inv-1',
        sellOrderId: 'sell-order-1',
        poolCapitalReleased: 415.5,
      }),
    );
    expect(bookPartialSellPoolRelease).toHaveBeenCalledWith(
      expect.objectContaining({
        investorId: 'investor-1',
        investmentId: 'inv-1',
        sellOrderId: 'sell-order-1',
        poolCapitalReleased: 415.5,
      }),
    );
    expect(bookPartialSellProfitRecognition).toHaveBeenCalledWith(
      expect.objectContaining({
        investorId: 'investor-1',
        investmentId: 'inv-1',
        sellOrderId: 'sell-order-1',
        grossProfit: 50,
      }),
    );
    expect(createPartialSellInternalBeleg).toHaveBeenCalledWith(
      expect.objectContaining({
        grossProfit: 50,
        netProfit: 42.5,
        commission: 7.5,
      }),
    );
    expect(bookAccountStatementEntry).not.toHaveBeenCalled();
    expect(bookSettlementEntry).not.toHaveBeenCalled();
    expect(results).toHaveLength(1);
    expect(results[0].poolCapitalReleased).toBe(415.5);
  });
});
