'use strict';

const { settleParticipationSafe } = require('../settlementCore/participationSettlementLoop');

jest.mock('../settlementParticipationProcessor', () => ({
  settleParticipation: jest.fn(),
}));

const { settleParticipation } = require('../settlementParticipationProcessor');

describe('participationSettlementLoop batching', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  test('settleParticipationSafe returns structured failure', async () => {
    settleParticipation.mockRejectedValue(new Error('boom'));
    const participation = {
      id: 'ptp-1',
      get: (k) => (k === 'investmentId' ? 'inv-1' : null),
    };
    const out = await settleParticipationSafe({
      participation,
      poolSettlementTrade: { id: 'pool-1' },
      traderId: 't1',
      settlementTradeNumber: 1,
      netTradingProfitForPool: 100,
      feeConfig: {},
      tradeBuyPrice: 1,
      tradeSellPrice: 2,
      taxConfig: {},
    });
    expect(out.ok).toBe(false);
    expect(out.error).toBe('boom');
  });
});
