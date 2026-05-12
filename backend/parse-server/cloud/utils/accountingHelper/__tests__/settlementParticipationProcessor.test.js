'use strict';

// Characterization for ownership → proportional amounts and backfill short-circuit.

jest.mock('../businessCaseId', () => ({
  ensureBusinessCaseIdForTrade: jest.fn().mockResolvedValue('bc-proc'),
}));

jest.mock('../settlementInvestmentFallback', () => ({
  findInvestment: jest.fn(),
}));

jest.mock('../settlementParticipationBackfill', () => ({
  trySettleFromExistingBill: jest.fn(),
}));

jest.mock('../settlementParticipationPosting', () => ({
  settleNewParticipation: jest.fn().mockResolvedValue({ commission: 1, grossProfit: 2 }),
}));

const { ensureBusinessCaseIdForTrade } = require('../businessCaseId');
const { findInvestment } = require('../settlementInvestmentFallback');
const { trySettleFromExistingBill } = require('../settlementParticipationBackfill');
const { settleNewParticipation } = require('../settlementParticipationPosting');
const { settleParticipation } = require('../settlementParticipationProcessor');

function makeParticipation(ownershipPercentage, investmentId = 'inv-x') {
  return {
    id: 'ptp-proc-1',
    get(k) {
      if (k === 'ownershipPercentage') return ownershipPercentage;
      if (k === 'investmentId') return investmentId;
      return undefined;
    },
  };
}

function makeInvestment() {
  return {
    id: 'inv-x',
    get(k) {
      if (k === 'investorId') return 'investor-1';
      if (k === 'amount') return 5000;
      return undefined;
    },
  };
}

const tradeStub = { id: 't-1', get: () => undefined };
const feeConfig = {};
const taxConfig = {};

const baseArgs = () => ({
  participation: makeParticipation(25),
  trade: tradeStub,
  traderId: 'trader-1',
  tradeNumber: '7',
  netTradingProfit: 1000,
  commissionRate: 0.2,
  feeConfig,
  tradeBuyPrice: 10,
  tradeSellPrice: 12,
  taxConfig,
});

describe('settleParticipation (settlementParticipationProcessor)', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    findInvestment.mockResolvedValue(makeInvestment());
    trySettleFromExistingBill.mockResolvedValue(null);
    jest.spyOn(console, 'log').mockImplementation(() => {});
  });

  afterEach(() => {
    jest.restoreAllMocks();
  });

  test('treats ownershipPercentage > 1 as percent of 100', async () => {
    await settleParticipation(baseArgs());
    expect(settleNewParticipation).toHaveBeenCalledWith(
      expect.objectContaining({
        rawOwnership: 25,
        ownershipRatio: 0.25,
        proportionalProfitShare: 250,
        proportionalCommission: 50,
        proportionalNetProfit: 200,
        businessCaseId: 'bc-proc',
      }),
    );
    expect(ensureBusinessCaseIdForTrade).toHaveBeenCalledWith(tradeStub);
  });

  test('treats ownershipPercentage <= 1 as fractional ratio', async () => {
    await settleParticipation({
      ...baseArgs(),
      participation: makeParticipation(0.1),
      netTradingProfit: 800,
    });
    expect(settleNewParticipation).toHaveBeenCalledWith(
      expect.objectContaining({
        rawOwnership: 0.1,
        ownershipRatio: 0.1,
        proportionalProfitShare: 80,
        proportionalCommission: 16,
        proportionalNetProfit: 64,
      }),
    );
  });

  test('returns existing bill result without calling settleNewParticipation', async () => {
    const backfill = { commission: 99, grossProfit: 100, fromBackfill: true };
    trySettleFromExistingBill.mockResolvedValue(backfill);
    const out = await settleParticipation(baseArgs());
    expect(out).toEqual(backfill);
    expect(settleNewParticipation).not.toHaveBeenCalled();
  });

  test('throws fail-closed when investment is missing', async () => {
    findInvestment.mockResolvedValue(null);
    await expect(settleParticipation(baseArgs())).rejects.toThrow(/GoB fail-closed/);
    expect(settleNewParticipation).not.toHaveBeenCalled();
  });
});
