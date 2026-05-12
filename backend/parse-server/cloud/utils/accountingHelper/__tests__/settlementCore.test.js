'use strict';

// Orchestration characterization for settleAndDistribute (early exit + commission_credit path).
// Heavy dependencies are mocked; Parse.Query is a minimal fake chain.

jest.mock('../../configHelper/index.js', () => ({
  getTraderCommissionRate: jest.fn().mockResolvedValue(0.25),
  loadConfig: jest.fn().mockResolvedValue({ financial: {}, tax: {} }),
}));

jest.mock('../businessCaseId', () => ({
  ensureBusinessCaseIdForTrade: jest.fn().mockResolvedValue('bc-test'),
}));

jest.mock('../statements', () => ({
  bookSettlementEntry: jest.fn().mockResolvedValue(undefined),
}));

jest.mock('../taxation', () => ({
  resolveUserTaxProfile: jest.fn().mockResolvedValue({}),
  calculateWithholdingBundle: jest.fn().mockReturnValue({
    totalTax: 0,
    lines: [],
  }),
}));

jest.mock('../documents', () => ({
  createCreditNoteDocument: jest.fn().mockResolvedValue({ id: 'cn-doc-1' }),
}));

jest.mock('../documentReferenceResolver', () => ({
  resolveDocumentReference: jest.fn().mockReturnValue({
    referenceDocumentId: 'cn-doc-1',
    referenceDocumentNumber: 'CN-2026-0001',
  }),
}));

jest.mock('../../pairedTradeMirrorSync', () => ({
  isPairedTraderLegTrade: jest.fn().mockResolvedValue(false),
  getMirrorTradeForPairedTraderLeg: jest.fn().mockResolvedValue(null),
}));

jest.mock('../settlementTradeMath', () => ({
  computeTradingFeesWithBreakdown: jest.fn().mockReturnValue({
    totalFees: 10,
    breakdown: { testFee: 10 },
  }),
}));

jest.mock('../settlementInvestmentFallback', () => ({
  ensureParticipationsForTrade: jest.fn().mockResolvedValue([]),
}));

jest.mock('../settlementTaxEntries', () => ({
  bookTraderTaxEntries: jest.fn().mockResolvedValue(undefined),
}));

jest.mock('../settlementParticipationProcessor', () => ({
  settleParticipation: jest.fn(),
}));

jest.mock('../settlementTraderLifecycleBooks', () => ({
  bookTraderTradeLifecycleEntries: jest.fn().mockResolvedValue(undefined),
}));

const { isPairedTraderLegTrade, getMirrorTradeForPairedTraderLeg } = require('../../pairedTradeMirrorSync');
const { settleParticipation } = require('../settlementParticipationProcessor');
const { bookSettlementEntry } = require('../statements');
const { createCreditNoteDocument } = require('../documents');
const { ensureParticipationsForTrade } = require('../settlementInvestmentFallback');
const { bookTraderTaxEntries } = require('../settlementTaxEntries');
const { bookTraderTradeLifecycleEntries } = require('../settlementTraderLifecycleBooks');
const taxation = require('../taxation');
const { settleAndDistribute } = require('../settlementCore');

function makeTrade(overrides = {}) {
  const attrs = Object.assign({
    id: 'trade-core-1',
    traderId: 'trader-t1',
    tradeNumber: '99',
    grossProfit: 1000,
    buyOrder: {},
    sellOrders: [],
    entryPrice: 10,
    exitPrice: 12,
    symbol: 'TEST',
  }, overrides);
  return {
    id: attrs.id,
    get(k) {
      return attrs[k];
    },
  };
}

class FakeQuery {
  constructor(className) {
    this.className = className;
    this.tradeIdFilter = undefined;
  }

  equalTo(field, value) {
    if (field === 'tradeId') {
      this.tradeIdFilter = value;
    }
    return this;
  }

  descending() {
    return this;
  }

  limit() {
    return this;
  }

  async first() {
    if (this.className === 'AccountStatement') {
      return FakeQuery.firstAccountStatement;
    }
    if (this.className === 'Document') {
      return FakeQuery.firstDocument;
    }
    return null;
  }

  async find() {
    if (this.className === 'PoolTradeParticipation') {
      const tid = this.tradeIdFilter;
      if (FakeQuery.mirrorTradeId && tid === FakeQuery.mirrorTradeId) {
        return FakeQuery.mirrorParticipations;
      }
      return FakeQuery.participationRows;
    }
    return [];
  }
}

FakeQuery.participationRows = [];
FakeQuery.mirrorParticipations = [];
FakeQuery.mirrorTradeId = '';
FakeQuery.firstAccountStatement = null;
FakeQuery.firstDocument = null;

describe('settleAndDistribute (settlementCore)', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    FakeQuery.participationRows = [];
    FakeQuery.mirrorParticipations = [];
    FakeQuery.mirrorTradeId = '';
    FakeQuery.firstAccountStatement = null;
    FakeQuery.firstDocument = null;
    global.Parse = { Query: FakeQuery };
    settleParticipation.mockResolvedValue({ commission: 40, grossProfit: 160 });
    isPairedTraderLegTrade.mockResolvedValue(false);
    getMirrorTradeForPairedTraderLeg.mockResolvedValue(null);
    taxation.calculateWithholdingBundle.mockReturnValue({
      totalTax: 0,
      lines: [],
    });
  });

  afterEach(() => {
    delete global.Parse;
  });

  test('returns null when no participations and fallback yields none', async () => {
    FakeQuery.participationRows = [];
    const trade = makeTrade();
    const result = await settleAndDistribute(trade);
    expect(result).toBeNull();
    expect(ensureParticipationsForTrade).toHaveBeenCalledWith(trade);
    expect(settleParticipation).not.toHaveBeenCalled();
  });

  test('runs lifecycle hook then settles each participation', async () => {
    const p1 = { id: 'ptp-1', get: () => 1 };
    FakeQuery.participationRows = [p1];
    const trade = makeTrade();
    await settleAndDistribute(trade);
    expect(bookTraderTradeLifecycleEntries).toHaveBeenCalledWith(
      expect.objectContaining({
        trade,
        traderId: 'trader-t1',
        tradeNumber: '99',
        totalTradingFees: 10,
      }),
    );
    expect(settleParticipation).toHaveBeenCalledTimes(1);
    expect(settleParticipation).toHaveBeenCalledWith(
      expect.objectContaining({
        participation: p1,
        trade,
        traderId: 'trader-t1',
        tradeNumber: '99',
        netTradingProfit: 990,
      }),
    );
  });

  test('books commission_credit when totalCommission > 0 and not already booked', async () => {
    FakeQuery.participationRows = [{ id: 'ptp-1', get: () => 1 }];
    const trade = makeTrade();
    const summary = await settleAndDistribute(trade);
    expect(createCreditNoteDocument).toHaveBeenCalled();
    expect(bookSettlementEntry).toHaveBeenCalledWith(
      expect.objectContaining({
        userId: 'trader-t1',
        userRole: 'trader',
        entryType: 'commission_credit',
        amount: 40,
        tradeId: 'trade-core-1',
        tradeNumber: '99',
        businessCaseId: 'bc-test',
      }),
    );
    expect(summary).toMatchObject({
      tradeId: 'trade-core-1',
      tradeNumber: '99',
      rawGrossProfit: 1000,
      tradingFees: 10,
      netTradingProfit: 990,
      totalCommission: 40,
      investorCount: 1,
    });
  });

  test('skips commission_credit when trader commission or credit note already exists', async () => {
    FakeQuery.participationRows = [{ id: 'ptp-1', get: () => 1 }];
    FakeQuery.firstAccountStatement = { id: 'stmt-existing' };
    const trade = makeTrade();
    await settleAndDistribute(trade);
    expect(createCreditNoteDocument).not.toHaveBeenCalled();
    expect(bookSettlementEntry).not.toHaveBeenCalledWith(
      expect.objectContaining({ entryType: 'commission_credit' }),
    );
  });

  describe('paired trader mirror leg', () => {
    const mirrorTrade = {
      id: 'mirror-trade-1',
      get(k) {
        const attrs = {
          tradeNumber: '88',
          grossProfit: 500,
          buyOrder: {},
          sellOrders: [],
          entryPrice: 1,
          exitPrice: 2,
        };
        return attrs[k];
      },
    };

    beforeEach(() => {
      FakeQuery.participationRows = [];
      FakeQuery.mirrorParticipations = [{ id: 'ptp-m', get: (k) => (k === 'ownershipPercentage' ? 1 : undefined) }];
      FakeQuery.mirrorTradeId = 'mirror-trade-1';
      isPairedTraderLegTrade.mockResolvedValue(true);
      getMirrorTradeForPairedTraderLeg.mockResolvedValue(mirrorTrade);
    });

    test('loads participations from mirror trade and uses mirror net profit', async () => {
      const trade = makeTrade();
      await settleAndDistribute(trade);
      expect(ensureParticipationsForTrade).not.toHaveBeenCalled();
      expect(settleParticipation).toHaveBeenCalledTimes(1);
      expect(settleParticipation).toHaveBeenCalledWith(
        expect.objectContaining({
          participation: FakeQuery.mirrorParticipations[0],
          trade: mirrorTrade,
          tradeNumber: '88',
          netTradingProfit: 490,
        }),
      );
    });
  });

  describe('trader withholding on commission', () => {
    beforeEach(() => {
      taxation.calculateWithholdingBundle.mockReturnValue({
        totalTax: 12.5,
        lines: [{ kind: 'wht', amount: 12.5 }],
      });
    });

    test('calls bookTraderTaxEntries when commission is booked and totalTax > 0', async () => {
      FakeQuery.participationRows = [{ id: 'ptp-1', get: () => 1 }];
      const trade = makeTrade();
      await settleAndDistribute(trade);
      expect(bookTraderTaxEntries).toHaveBeenCalledTimes(1);
      expect(bookTraderTaxEntries).toHaveBeenCalledWith(
        expect.objectContaining({
          traderId: 'trader-t1',
          trade,
          tradeNumber: '99',
          bookSettlementEntry,
        }),
      );
    });
  });
});
