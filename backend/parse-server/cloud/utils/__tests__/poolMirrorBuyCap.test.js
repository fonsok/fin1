'use strict';

jest.mock('../configHelper/index.js', () => ({
  loadConfig: jest.fn(),
  DEFAULT_CONFIG: {
    limits: { maxPoolMirrorBuyOrderAmount: 0 },
  },
}));

const { loadConfig } = require('../configHelper/index.js');
const {
  assessPoolMirrorCapacity,
  capMirrorPoolQuantityForBuy,
  getMaxPoolMirrorBuyOrderAmount,
  sumTraderPoolQueueCapital,
} = require('../poolMirrorBuyCap');

function mockInvestments(rows) {
  global.Parse = {
    Query: jest.fn().mockImplementation((className) => {
      if (className !== 'Investment') {
        throw new Error(`unexpected class ${className}`);
      }
      return {
        equalTo: jest.fn().mockReturnThis(),
        containedIn: jest.fn().mockReturnThis(),
        limit: jest.fn().mockReturnThis(),
        find: jest.fn().mockResolvedValue(
          rows.map((r) => ({
            get: (key) => r[key],
          })),
        ),
      };
    }),
  };
}

describe('poolMirrorBuyCap', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    loadConfig.mockResolvedValue({
      limits: { maxPoolMirrorBuyOrderAmount: 100_000 },
    });
  });

  afterEach(() => {
    delete global.Parse;
  });

  test('getMaxPoolMirrorBuyOrderAmount reads limits', async () => {
    expect(await getMaxPoolMirrorBuyOrderAmount()).toBe(100_000);
  });

  test('assessPoolMirrorCapacity detects wouldExceed and max investable', async () => {
    mockInvestments([
      { traderId: 'trader-1', status: 'reserved', amount: 40_000, currentValue: 40_000 },
    ]);

    const cap = await assessPoolMirrorCapacity('trader-1', { additionalAmount: 80_000 });
    expect(cap.capEnabled).toBe(true);
    expect(cap.wouldExceed).toBe(true);
    expect(cap.isPoolNearlyFull).toBe(false);
    expect(cap.maxInvestableAmountForNextTrade).toBe(60_000);
  });

  test('assessPoolMirrorCapacity marks pool nearly full at 95%', async () => {
    mockInvestments([
      { traderId: 'trader-1b', status: 'reserved', amount: 96_000, currentValue: 96_000 },
    ]);

    const cap = await assessPoolMirrorCapacity('trader-1b', { additionalAmount: 0 });
    expect(cap.isPoolNearlyFull).toBe(true);
    expect(cap.wouldExceed).toBe(false);
  });

  test('capMirrorPoolQuantityForBuy clamps quantity to cap and pool', async () => {
    mockInvestments([
      { traderId: 'trader-2', status: 'reserved', amount: 50_000, currentValue: 50_000 },
    ]);

    const out = await capMirrorPoolQuantityForBuy({
      mirrorPoolQuantity: 1000,
      price: 100,
      traderId: 'trader-2',
    });
    expect(out.mirrorPoolQuantity).toBe(500);
    expect(out.capped).toBe(true);
  });
});
