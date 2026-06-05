'use strict';

jest.mock('../../../utils/pairedTradeMirrorSync', () => ({
  getTraderTradeForPairedMirrorLeg: jest.fn(),
  getMirrorTradeForPairedTraderLeg: jest.fn(),
}));

const {
  isTraderCustomerFacingEntryType,
  resolveTraderCustomerBookingContext,
  resolveTraderSettlementBookingTrade,
} = require('../traderCustomerBookingPolicy');
const { getTraderTradeForPairedMirrorLeg } = require('../../../utils/pairedTradeMirrorSync');

function makeTrade(id, buyLegType, tradeNumber = 1) {
  return {
    id,
    get: (k) => ({ buyLegType, tradeNumber, traderId: 'trader-1' }[k]),
  };
}

describe('traderCustomerBookingPolicy', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    global.Parse = {
      Query: jest.fn().mockImplementation(() => ({
        get: jest.fn().mockResolvedValue(makeTrade('mirror-1', 'MIRROR_POOL', 2)),
      })),
    };
  });

  afterEach(() => {
    delete global.Parse;
  });

  test('isTraderCustomerFacingEntryType identifies trader cash legs', () => {
    expect(isTraderCustomerFacingEntryType('trade_buy')).toBe(true);
    expect(isTraderCustomerFacingEntryType('commission_credit')).toBe(true);
    expect(isTraderCustomerFacingEntryType('commission_debit')).toBe(false);
    expect(isTraderCustomerFacingEntryType('investment_return')).toBe(false);
  });

  test('passes through TRADER leg unchanged', async () => {
    const trade = makeTrade('trader-1', 'TRADER', 1);
    const out = await resolveTraderCustomerBookingContext({
      tradeId: 'trader-1',
      tradeNumber: 1,
      entryType: 'trade_buy',
      userRole: 'trader',
      trade,
    });
    expect(out.tradeId).toBe('trader-1');
    expect(out.redirected).toBe(false);
  });

  test('redirects MIRROR_POOL to TRADER leg', async () => {
    const mirror = makeTrade('mirror-1', 'MIRROR_POOL', 2);
    const trader = makeTrade('trader-1', 'TRADER', 1);
    getTraderTradeForPairedMirrorLeg.mockResolvedValue(trader);

    const out = await resolveTraderCustomerBookingContext({
      tradeId: 'mirror-1',
      entryType: 'commission_credit',
      userRole: 'trader',
      trade: mirror,
    });

    expect(out.tradeId).toBe('trader-1');
    expect(out.tradeNumber).toBe(1);
    expect(out.redirected).toBe(true);
    expect(out.sourceMirrorTradeId).toBe('mirror-1');
  });

  test('blocks MIRROR_POOL when no TRADER leg exists', async () => {
    getTraderTradeForPairedMirrorLeg.mockResolvedValue(null);
    const mirror = makeTrade('mirror-1', 'MIRROR_POOL', 2);

    await expect(resolveTraderCustomerBookingContext({
      tradeId: 'mirror-1',
      entryType: 'trade_buy',
      userRole: 'trader',
      trade: mirror,
    })).rejects.toThrow(/blocked.*MIRROR_POOL/i);
  });

  test('resolveTraderSettlementBookingTrade separates pool vs trader leg', async () => {
    const mirror = makeTrade('mirror-1', 'MIRROR_POOL', 2);
    const trader = makeTrade('trader-1', 'TRADER', 1);
    getTraderTradeForPairedMirrorLeg.mockResolvedValue(trader);

    const out = await resolveTraderSettlementBookingTrade(mirror);
    expect(out.invokedOnMirrorLeg).toBe(true);
    expect(out.poolSettlementTrade.id).toBe('mirror-1');
    expect(out.traderBookingTrade.id).toBe('trader-1');
  });
});
