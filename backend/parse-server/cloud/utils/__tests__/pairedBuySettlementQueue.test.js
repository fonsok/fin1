'use strict';

const { resetRedisClientForTests } = require('../redisClient');
const {
  runPairedBuySettlement,
  waitForPeerSettlement,
} = require('../pairedBuySettlementQueue');

jest.mock('../pairedBuyOrchestration', () => ({
  verifyPairedBuySettlement: jest.fn(async () => ({ ok: false, issues: ['pending'] })),
}));

describe('pairedBuySettlementQueue', () => {
  beforeEach(() => {
    resetRedisClientForTests();
    delete process.env.REDIS_URL;
    jest.clearAllMocks();
  });

  it('serializes two workers for the same pairExecutionId in-process', async () => {
    const order = [];
    const delay = (ms) => new Promise((r) => setTimeout(r, ms));

    const first = runPairedBuySettlement('pair-A', async () => {
      order.push('a-start');
      await delay(40);
      order.push('a-end');
      return 'a';
    });
    const second = runPairedBuySettlement('pair-A', async () => {
      order.push('b-start');
      order.push('b-end');
      return 'b';
    });

    const [ra, rb] = await Promise.all([first, second]);
    expect(ra === 'a' || ra?.peerCompleted === true).toBe(true);
    expect(rb === 'b' || rb?.peerCompleted === true).toBe(true);
    expect(order.indexOf('a-end')).toBeLessThan(order.indexOf('b-start'));
  });

  it('allows parallel workers for different pair ids', async () => {
    let concurrent = 0;
    let maxConcurrent = 0;

    const worker = async () => {
      concurrent += 1;
      maxConcurrent = Math.max(maxConcurrent, concurrent);
      await new Promise((r) => setTimeout(r, 30));
      concurrent -= 1;
      return true;
    };

    await Promise.all([
      runPairedBuySettlement('pair-1', worker),
      runPairedBuySettlement('pair-2', worker),
    ]);

    expect(maxConcurrent).toBe(2);
  });
});
