'use strict';

/** @global {typeof import('parse/node')} Parse */
global.Parse = global.Parse || {
  Query: jest.fn(),
};

const {
  inspectMirrorPoolBuyDrift,
  repairMirrorPoolBuyQuantityForTrade,
  repairMirrorPoolBuyQuantityBatch,
} = require('../repairMirrorPoolBuyQuantity');

jest.mock('../syncMirrorTradeBuyFromSnapshots', () => ({
  inspectMirrorTradeBuyAlignment: jest.fn(),
  syncMirrorTradeBuyFromParticipationSnapshots: jest.fn(),
}));

jest.mock('../../../utils/pairedTradeMirrorSync', () => ({
  getTraderTradeForPairedMirrorLeg: jest.fn(),
}));

jest.mock('../../../utils/pairedTradeMirrorSync/sellSync', () => ({
  syncMirrorPoolSellProgressFromTraderLeg: jest.fn(),
}));

const {
  inspectMirrorTradeBuyAlignment,
  syncMirrorTradeBuyFromParticipationSnapshots,
} = require('../syncMirrorTradeBuyFromSnapshots');
const { getTraderTradeForPairedMirrorLeg } = require('../../../utils/pairedTradeMirrorSync');
const { syncMirrorPoolSellProgressFromTraderLeg } = require('../../../utils/pairedTradeMirrorSync/sellSync');

describe('repairMirrorPoolBuyQuantity', () => {
  const originalQuery = Parse.Query;

  afterEach(() => {
    Parse.Query = originalQuery;
    jest.clearAllMocks();
  });

  function makeMirrorTrade(overrides = {}) {
    return {
      id: 'mirror-1',
      get(key) {
        const data = {
          buyLegType: 'MIRROR_POOL',
          tradeNumber: 42,
          pairExecutionId: 'pair-1',
          quantity: 1000,
          buyAmount: 1660,
          ...overrides,
        };
        return data[key];
      },
    };
  }

  test('inspectMirrorPoolBuyDrift flags drift on mirror trade', async () => {
    const trade = makeMirrorTrade();
    Parse.Query = jest.fn().mockImplementation(() => ({
      equalTo: jest.fn().mockReturnThis(),
      limit: jest.fn().mockReturnThis(),
      find: jest.fn().mockResolvedValue([{ get: () => ({ poolPieces: 598, poolCapitalAllocated: 999.44 }) }]),
    }));
    inspectMirrorTradeBuyAlignment.mockReturnValue({
      aligned: false,
      reason: 'drift',
      poolPieces: 598,
      poolCapitalAllocated: 999.44,
      participationCount: 1,
      currentQuantity: 1000,
      currentBuyAmount: 1660,
      quantityDelta: -402,
      buyAmountDelta: -660.56,
    });

    const result = await inspectMirrorPoolBuyDrift(trade);
    expect(result.drift).toBe(true);
    expect(result.poolPieces).toBe(598);
    expect(result.quantityDelta).toBe(-402);
  });

  test('repairMirrorPoolBuyQuantityForTrade dry-run does not mutate', async () => {
    Parse.Query = jest.fn().mockImplementation((className) => {
      if (className === 'Trade') {
        return {
          get: jest.fn().mockResolvedValue(makeMirrorTrade()),
        };
      }
      return {
        equalTo: jest.fn().mockReturnThis(),
        limit: jest.fn().mockReturnThis(),
        find: jest.fn().mockResolvedValue([]),
      };
    });
    inspectMirrorTradeBuyAlignment.mockReturnValue({
      aligned: false,
      reason: 'drift',
      poolPieces: 598,
      poolCapitalAllocated: 999.44,
      participationCount: 1,
    });

    const result = await repairMirrorPoolBuyQuantityForTrade('mirror-1', { dryRun: true });
    expect(result.wouldRepair).toBe(true);
    expect(result.repaired).toBe(false);
    expect(syncMirrorTradeBuyFromParticipationSnapshots).not.toHaveBeenCalled();
  });

  test('repairMirrorPoolBuyQuantityForTrade applies sync and resyncs sell from trader', async () => {
    const trade = makeMirrorTrade({ soldQuantity: 0 });
    Parse.Query = jest.fn().mockImplementation((className) => {
      if (className === 'Trade') {
        return {
          get: jest.fn().mockResolvedValue(trade),
        };
      }
      return {
        equalTo: jest.fn().mockReturnThis(),
        limit: jest.fn().mockReturnThis(),
        find: jest.fn().mockResolvedValue([]),
      };
    });
    inspectMirrorTradeBuyAlignment.mockReturnValue({
      aligned: false,
      reason: 'drift',
      poolPieces: 598,
      poolCapitalAllocated: 999.44,
      participationCount: 1,
    });
    syncMirrorTradeBuyFromParticipationSnapshots.mockResolvedValue({
      synced: true,
      poolPieces: 598,
      poolCapital: 999.44,
      orderSync: { synced: true, orderId: 'ord-mirror' },
    });
    getTraderTradeForPairedMirrorLeg.mockResolvedValue({
      id: 'trader-1',
      get: (key) => (key === 'soldQuantity' ? 400 : null),
    });

    const result = await repairMirrorPoolBuyQuantityForTrade('mirror-1', { dryRun: false });
    expect(result.repaired).toBe(true);
    expect(result.poolPieces).toBe(598);
    expect(syncMirrorTradeBuyFromParticipationSnapshots).toHaveBeenCalledWith(trade);
    expect(syncMirrorPoolSellProgressFromTraderLeg).toHaveBeenCalled();
  });

  test('repairMirrorPoolBuyQuantityBatch scans mirror trades', async () => {
    const trades = [makeMirrorTrade({ id: 'm1' }), makeMirrorTrade({ id: 'm2', quantity: 598 })];
    Parse.Query = jest.fn().mockImplementation((className) => {
      if (className === 'Trade') {
        return {
          equalTo: jest.fn().mockReturnThis(),
          ascending: jest.fn().mockReturnThis(),
          limit: jest.fn().mockReturnThis(),
          find: jest.fn().mockResolvedValue(trades),
          get: jest.fn(async (id) => trades.find((t) => t.id === id) || trades[0]),
        };
      }
      return {
        equalTo: jest.fn().mockReturnThis(),
        limit: jest.fn().mockReturnThis(),
        find: jest.fn().mockResolvedValue([]),
      };
    });

    inspectMirrorTradeBuyAlignment.mockImplementation((trade) => {
      const qty = Number(trade.get('quantity') || 0);
      if (qty === 1000) {
        return {
          aligned: false,
          reason: 'drift',
          poolPieces: 598,
          poolCapitalAllocated: 999.44,
          participationCount: 1,
        };
      }
      return {
        aligned: true,
        reason: 'already_aligned',
        poolPieces: 598,
        poolCapitalAllocated: 999.44,
        participationCount: 1,
      };
    });

    syncMirrorTradeBuyFromParticipationSnapshots.mockResolvedValue({
      synced: true,
      poolPieces: 598,
      poolCapital: 999.44,
    });
    getTraderTradeForPairedMirrorLeg.mockResolvedValue(null);

    const report = await repairMirrorPoolBuyQuantityBatch({ dryRun: false, limit: 10 });
    expect(report.scanned).toBe(2);
    expect(report.driftCount).toBe(1);
    expect(report.repairedCount).toBe(1);
  });
});
