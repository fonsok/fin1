'use strict';

/** @global {typeof import('parse/node')} Parse */
global.Parse = global.Parse || {
  Query: jest.fn(),
  Object: { extend: jest.fn(() => function MockObj() {}) },
};

const {
  resolveMirrorPoolBuyQuantityFromReservedPool,
  applyResolvedMirrorPoolBuyQuantityToOrder,
} = require('../resolveMirrorPoolBuyQuantity');

jest.mock('../investmentSelection', () => ({
  findTraderInvestmentsForActivation: jest.fn(),
  selectOneSplitPerInvestorForTrade: jest.fn(),
}));

jest.mock('../poolMirrorLimits', () => ({
  readMaxInvestorsPerMirrorTrade: jest.fn(() => 50),
}));

const {
  findTraderInvestmentsForActivation,
  selectOneSplitPerInvestorForTrade,
} = require('../investmentSelection');

describe('resolveMirrorPoolBuyQuantityFromReservedPool', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  test('598 pool pieces for 1000 EUR @ bid 1.66 (pool max affordable, not trader brief units)', async () => {
    const inv = {
      id: 'inv-1',
      get: (key) => ({ currentValue: 1000, amount: 1000, investorId: 'u1' }[key]),
    };
    findTraderInvestmentsForActivation.mockResolvedValue([inv]);
    selectOneSplitPerInvestorForTrade.mockResolvedValue([inv]);

    const traderBuyOrder = { price: 1.66, quantity: 1000, totalAmount: 1660 };
    const result = await resolveMirrorPoolBuyQuantityFromReservedPool({
      traderId: 'trader-1',
      traderBuyOrder,
      feeConfig: {},
    });

    expect(result.poolPieces).toBe(598);
    expect(result.poolCapitalAllocated).toBe(998.66);
    expect(result.costBasisPerShare).toBeCloseTo(1.6734, 3);
    expect(result.investorCount).toBe(1);
  });

  test('returns zero when no eligible investments', async () => {
    findTraderInvestmentsForActivation.mockResolvedValue([]);
    selectOneSplitPerInvestorForTrade.mockResolvedValue([]);

    const result = await resolveMirrorPoolBuyQuantityFromReservedPool({
      traderId: 'trader-1',
      traderBuyOrder: { quantity: 1000, totalAmount: 1660, price: 1.66 },
    });

    expect(result.poolPieces).toBe(0);
    expect(result.reason).toBe('no_eligible_pool_capital');
  });
});

describe('applyResolvedMirrorPoolBuyQuantityToOrder', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    global.Parse.Query = jest.fn().mockImplementation(() => ({
      equalTo: jest.fn().mockReturnThis(),
      first: jest.fn().mockResolvedValue(null),
      get: jest.fn().mockRejectedValue(new Error('not found')),
    }));
  });

  test('returns trader_leg_not_ready instead of throwing when mirror has no trader buyOrder', async () => {
    const mirrorOrder = {
      get: (key) => ({ pairExecutionId: 'pair-1', traderId: 'trader-1' }[key]),
      set: jest.fn(),
    };

    const result = await applyResolvedMirrorPoolBuyQuantityToOrder(mirrorOrder, { feeConfig: {} });

    expect(result).toEqual({ ok: false, reason: 'trader_leg_not_ready' });
  });
});
