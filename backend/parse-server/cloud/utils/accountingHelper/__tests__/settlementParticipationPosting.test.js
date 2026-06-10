'use strict';

// settleNewParticipation: proportional path + statements with heavy Parse/mocks.

jest.mock('../statements', () => ({
  bookAccountStatementEntry: jest.fn().mockResolvedValue(undefined),
  bookSettlementEntry: jest.fn().mockResolvedValue(undefined),
}));

jest.mock('../taxation', () => ({
  resolveUserTaxProfile: jest.fn().mockResolvedValue({}),
  calculateWithholdingBundle: jest.fn().mockReturnValue({
    totalTax: 0,
    withholdingTax: 0,
    solidaritySurcharge: 0,
    churchTax: 0,
  }),
}));

const mockCollectionBillMetadata = {
  transferAmount: 1180,
  netProfit: 180,
  residualAmount: 0,
  poolTradingAmount: 1000,
  investmentNominal: 1000,
  totalBuyCost: 1000,
};

jest.mock('../documents', () => ({
  createCollectionBillDocument: jest.fn().mockImplementation(() => Promise.resolve({
    id: 'bill-1',
    get(key) {
      return key === 'metadata' ? mockCollectionBillMetadata : undefined;
    },
  })),
  createWalletReceiptDocument: jest.fn().mockResolvedValue({ id: 'wr-1' }),
}));

jest.mock('../documentReferenceResolver', () => ({
  resolveDocumentReference: jest.fn().mockReturnValue({
    referenceDocumentId: 'doc-1',
    referenceDocumentNumber: 'DOC-1',
  }),
}));

jest.mock('../legs', () => ({
  ...jest.requireActual('../legs'),
  computeInvestorBuyLeg: jest.fn().mockReturnValue(null),
  computeInvestorSellLeg: jest.fn(),
  deriveMirrorTradeBasis: jest.fn().mockReturnValue(null),
}));

jest.mock('../settlementQueries', () => ({
  sumStatementAmounts: jest.fn().mockResolvedValue(0),
  getStatementSumsByType: jest.fn().mockResolvedValue({}),
}));

jest.mock('../settlementTaxEntries', () => ({
  bookInvestorTaxEntries: jest.fn().mockResolvedValue(undefined),
}));

jest.mock('../settlementSupport', () => ({
  createCommissionRecord: jest.fn().mockResolvedValue(undefined),
  createNotification: jest.fn().mockResolvedValue(undefined),
  formatCurrency: jest.fn((n) => `€${Number(n)}`),
}));

jest.mock('../investmentEscrow', () => ({
  bookReserveCapitalTradeSplit: jest.fn().mockResolvedValue(undefined),
  bookTradeSettlementPayout: jest.fn().mockResolvedValue(undefined),
  hasEscrowLeg: jest.fn().mockResolvedValue(false),
  resolveActivationCapitalSplitAmounts: jest.fn().mockResolvedValue({
    tradingAmount: 0,
    residualAmt: 0,
    poolPieces: 0,
    basis: 'mock',
  }),
}));

const statements = require('../statements');
const taxation = require('../taxation');
const documents = require('../documents');
const legs = require('../legs');
const settlementQueries = require('../settlementQueries');
const settlementTaxEntries = require('../settlementTaxEntries');
const settlementSupport = require('../settlementSupport');
const investmentEscrow = require('../investmentEscrow');
const { settleNewParticipation } = require('../settlementParticipationPosting');

class FakeQuery {
  constructor(className) {
    this.className = className;
  }

  equalTo() {
    return this;
  }

  async first() {
    if (this.className === 'AccountStatement') {
      return FakeQuery.accountStatementRow;
    }
    return FakeQuery.activationRow;
  }
}

FakeQuery.activationRow = null;
FakeQuery.accountStatementRow = null;

function makeParticipation() {
  const attrs = {};
  return {
    id: 'ptp-post-1',
    get(k) {
      return attrs[k];
    },
    set(k, v) {
      attrs[k] = v;
    },
    attrs,
    save: jest.fn().mockResolvedValue(undefined),
  };
}

function makeInvestment(overrides = {}) {
  const attrs = Object.assign({
    investorId: 'inv-user-1',
    amount: 1000,
    investmentNumber: 'INV-9',
    currentValue: 1000,
    profit: 0,
    totalCommissionPaid: 0,
    numberOfTrades: 0,
    status: 'active',
    initialValue: 1000,
    businessCaseId: 'bc-inv',
  }, overrides);
  return {
    id: 'inv-post-1',
    get(k) {
      return attrs[k];
    },
    set(k, v) {
      attrs[k] = v;
    },
    attrs,
    save: jest.fn().mockResolvedValue(undefined),
  };
}

const trade = {
  id: 'trade-post-1',
  get(k) {
    if (k === 'symbol') return 'ACME';
    return undefined;
  },
};

const baseArgs = () => ({
  participation: makeParticipation(),
  investment: makeInvestment(),
  trade,
  traderId: 'trader-post-1',
  tradeNumber: '42',
  commissionRate: 0.1,
  feeConfig: {},
  tradeBuyPrice: 0,
  tradeSellPrice: 0,
  taxConfig: {},
  proportionalProfitShare: 200,
  proportionalCommission: 20,
  proportionalNetProfit: 180,
  rawOwnership: 100,
  ownershipRatio: 1,
  businessCaseId: 'bc-1',
});

describe('settleNewParticipation', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    Object.assign(mockCollectionBillMetadata, {
      transferAmount: 1180,
      netProfit: 180,
      residualAmount: 0,
      poolTradingAmount: 1000,
      investmentNominal: 1000,
      totalBuyCost: 1000,
    });
    jest.spyOn(console, 'log').mockImplementation(() => {});
    FakeQuery.activationRow = null;
    FakeQuery.accountStatementRow = null;
    investmentEscrow.hasEscrowLeg.mockResolvedValue(false);
    global.Parse = { Query: FakeQuery };
    legs.computeInvestorBuyLeg.mockReturnValue(null);
    legs.deriveMirrorTradeBasis.mockReturnValue(null);
    taxation.calculateWithholdingBundle.mockReturnValue({
      totalTax: 0,
      withholdingTax: 0,
      solidaritySurcharge: 0,
      churchTax: 0,
    });
    settlementQueries.sumStatementAmounts.mockResolvedValue(0);
    settlementQueries.getStatementSumsByType.mockResolvedValue({});
  });

  afterEach(() => {
    delete global.Parse;
    jest.restoreAllMocks();
  });

  test('proportional basis: updates participation, bills, investment_return and commission_debit', async () => {
    const participation = makeParticipation();
    const investment = makeInvestment();
    const out = await settleNewParticipation({
      ...baseArgs(),
      participation,
      investment,
    });
    expect(out).toEqual({
      investorId: 'inv-user-1',
      investmentId: 'inv-post-1',
      grossProfit: 200,
      commission: 20,
      taxWithheld: 0,
    });
    expect(participation.get('profitBasis')).toBe('proportional');
    expect(participation.get('isSettled')).toBe(true);
    expect(participation.save).toHaveBeenCalled();
    expect(documents.createCollectionBillDocument).toHaveBeenCalledWith(
      expect.objectContaining({ allowIdempotentUpsert: true }),
    );
    expect(statements.bookAccountStatementEntry).toHaveBeenCalledWith(
      expect.objectContaining({
        entryType: 'investment_return',
        amount: 1180,
        tradeId: 'trade-post-1',
        investmentId: 'inv-post-1',
      }),
    );
    expect(investmentEscrow.bookTradeSettlementPayout).toHaveBeenCalledWith(
      expect.objectContaining({
        investorId: 'inv-user-1',
        investmentId: 'inv-post-1',
        tradeId: 'trade-post-1',
        transferAmount: 1180,
        netProfit: 180,
      }),
    );
    expect(statements.bookSettlementEntry).toHaveBeenCalledWith(
      expect.objectContaining({
        entryType: 'commission_debit',
        userRole: 'investor',
        amount: -20,
      }),
    );
    expect(settlementSupport.createCommissionRecord).toHaveBeenCalled();
    expect(settlementSupport.createNotification).toHaveBeenCalled();
  });

  test('does not book investment_activate (RSV→TRD / pool deploy is AppLedger-only)', async () => {
    FakeQuery.activationRow = null;
    const participation = makeParticipation();
    const investment = makeInvestment();
    await settleNewParticipation({
      ...baseArgs(),
      participation,
      investment,
    });
    const activationCalls = statements.bookAccountStatementEntry.mock.calls.filter(
      (c) => c[0].entryType === 'investment_activate',
    );
    expect(activationCalls).toHaveLength(0);
    expect(documents.createWalletReceiptDocument).not.toHaveBeenCalled();
  });

  test('uses mirror basis when deriveMirrorTradeBasis returns a tuple', async () => {
    legs.computeInvestorBuyLeg.mockReturnValue({ quantity: 1, amount: 100, fees: {}, residualAmount: 0 });
    legs.computeInvestorSellLeg.mockReturnValue({ amount: 200, fees: {} });
    legs.deriveMirrorTradeBasis.mockReturnValue({
      grossProfit: 55,
      commission: 5,
      netProfit: 50,
      netSellAmount: 60,
    });
    const participation = makeParticipation();
    const investment = makeInvestment();
    await settleNewParticipation({
      ...baseArgs(),
      participation,
      investment,
      tradeBuyPrice: 10,
      tradeSellPrice: 20,
    });
    expect(participation.get('profitShare')).toBe(55);
    expect(participation.get('commissionAmount')).toBe(5);
    expect(participation.get('grossReturn')).toBe(50);
    expect(participation.get('profitBasis')).toBe('mirror');
  });

  test('skips reserveCapitalTradeSplit when already booked at activation', async () => {
    legs.computeInvestorBuyLeg.mockReturnValue({
      quantity: 1,
      amount: 997.69,
      fees: {},
      residualAmount: 2.31,
    });
    investmentEscrow.hasEscrowLeg.mockResolvedValue(true);
    FakeQuery.accountStatementRow = { id: 'residual-stmt-existing' };
    const participation = makeParticipation();
    const investment = makeInvestment();

    await settleNewParticipation({
      ...baseArgs(),
      participation,
      investment,
      tradeBuyPrice: 10,
    });

    expect(investmentEscrow.bookReserveCapitalTradeSplit).not.toHaveBeenCalled();
    const residualCalls = statements.bookAccountStatementEntry.mock.calls.filter(
      (c) => c[0].entryType === 'residual_return',
    );
    expect(residualCalls).toHaveLength(0);
  });

  test('books reserveCapitalTradeSplit escrow before investment completed', async () => {
    Object.assign(mockCollectionBillMetadata, {
      residualAmount: 2.31,
      poolTradingAmount: 997.69,
      totalBuyCost: 997.69,
    });
    legs.computeInvestorBuyLeg.mockReturnValue({
      quantity: 1,
      amount: 997.69,
      fees: {},
      residualAmount: 2.31,
    });
    const participation = makeParticipation();
    const investment = makeInvestment();
    const saveOrder = [];
    investment.save = jest.fn(async () => {
      saveOrder.push('save');
    });
    investmentEscrow.bookReserveCapitalTradeSplit.mockImplementation(async () => {
      saveOrder.push('capitalSplitEscrow');
    });

    await settleNewParticipation({
      ...baseArgs(),
      participation,
      investment,
      tradeBuyPrice: 10,
    });

    expect(investmentEscrow.bookReserveCapitalTradeSplit).toHaveBeenCalledWith(
      expect.objectContaining({
        investorId: 'inv-user-1',
        nominal: 1000,
        tradingAmount: 997.69,
        availableAmount: 2.31,
        investmentId: 'inv-post-1',
        tradeId: 'trade-post-1',
      }),
    );
    expect(saveOrder.indexOf('capitalSplitEscrow')).toBeLessThan(saveOrder.indexOf('save'));
    expect(statements.bookAccountStatementEntry).toHaveBeenCalledWith(
      expect.objectContaining({
        entryType: 'residual_return',
        amount: 2.31,
      }),
    );
  });

  test('books investor tax entries when remaining tax > 0', async () => {
    taxation.calculateWithholdingBundle.mockReturnValue({
      totalTax: 10,
      withholdingTax: 8,
      solidaritySurcharge: 1,
      churchTax: 1,
    });
    const participation = makeParticipation();
    const investment = makeInvestment();
    await settleNewParticipation({
      ...baseArgs(),
      participation,
      investment,
    });
    expect(settlementTaxEntries.bookInvestorTaxEntries).toHaveBeenCalledTimes(1);
    expect(settlementTaxEntries.bookInvestorTaxEntries).toHaveBeenCalledWith(
      expect.objectContaining({
        investorId: 'inv-user-1',
        collectionBillId: 'doc-1',
        taxBreakdown: expect.objectContaining({ totalTax: 10 }),
      }),
    );
  });

  test('enriches buyLeg from buySnapshot SSOT before collection bill', async () => {
    investmentEscrow.resolveActivationCapitalSplitAmounts.mockResolvedValue({
      tradingAmount: 997.96,
      residualAmt: 2.04,
      poolPieces: 400,
      basis: 'buySnapshot',
    });
    legs.computeInvestorBuyLeg.mockReturnValue({
      quantity: 403,
      amount: 999.44,
      fees: { totalFees: 0 },
      residualAmount: 0,
    });
    legs.deriveMirrorTradeBasis.mockImplementation(
      jest.requireActual('../legs').deriveMirrorTradeBasis,
    );
    legs.computeInvestorSellLeg.mockReturnValue({
      quantity: 400,
      amount: 1471.2,
      fees: { totalFees: 0 },
    });

    await settleNewParticipation({
      ...baseArgs(),
      participation: makeParticipation(),
      investment: makeInvestment(),
      tradeBuyPrice: 2.48,
      tradeSellPrice: 3.68,
    });

    expect(documents.createCollectionBillDocument).toHaveBeenCalledWith(
      expect.objectContaining({
        buyLeg: expect.objectContaining({
          residualAmount: 2.04,
          quantity: 400,
          amount: 997.96,
        }),
      }),
    );
  });
});
