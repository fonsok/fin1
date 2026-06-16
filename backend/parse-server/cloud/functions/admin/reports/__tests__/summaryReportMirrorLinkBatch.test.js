'use strict';

const mockLoadParticipationsByPoolTradeIds = jest.fn();
const mockLoadTradesById = jest.fn();
const mockLoadDocumentsByTradeIds = jest.fn();

jest.mock('../summaryReportParticipationLoader', () => ({
  loadParticipationsByPoolTradeIds: (...args) => mockLoadParticipationsByPoolTradeIds(...args),
  loadParticipationsBundleForSummaryReport: async (ids) => {
    const participationsByPool = await mockLoadParticipationsByPoolTradeIds(ids);
    const participationCountsByPool = new Map();
    const participationAggregatesByPool = new Map();
    for (const id of ids) {
      const rows = participationsByPool.get(id) || [];
      participationCountsByPool.set(id, rows.length);
      participationAggregatesByPool.set(id, {
        count: rows.length,
        totalCommission: rows.reduce((s, r) => s + (r.commissionAmount || 0), 0),
        totalProfitShare: rows.reduce((s, r) => s + (r.profitShare || 0), 0),
      });
      if (!participationsByPool.has(id)) participationsByPool.set(id, []);
    }
    return {
      participationsByPool,
      participationCountsByPool,
      participationAggregatesByPool,
      inlineMax: 50,
    };
  },
  enrichParticipationDisplayFields: (rows) => rows,
}));

jest.mock('../summaryReportPairedLegResolver', () => {
  const actual = jest.requireActual('../summaryReportPairedLegResolver');
  return {
    ...actual,
    loadTradesById: (...args) => mockLoadTradesById(...args),
  };
});

jest.mock('../summaryReportTradeBelege', () => {
  const actual = jest.requireActual('../summaryReportTradeBelege');
  return {
    ...actual,
    loadDocumentsByTradeIds: (...args) => mockLoadDocumentsByTradeIds(...args),
    attachBelegeToSummaryRows: (rows) => rows,
    collectTradeIdsFromDraftRows: (rows) => rows.flatMap((r) => [
      r.traderTrade?.tradeId,
      r.poolMirrorTrade?.tradeId,
    ].filter(Boolean)),
  };
});

jest.mock('../../../../utils/configHelper/index.js', () => ({
  loadConfig: jest.fn().mockResolvedValue({ financial: {} }),
  getTraderCommissionRate: jest.fn().mockResolvedValue(0),
}));

const {
  collectTraderRowsNeedingMirrorLink,
  collectPoolRowsNeedingTraderLink,
} = require('../summaryReportMirrorLinkBatch');
const {
  applyMissingMirrorLinks,
  applyMissingTraderLinks,
} = require('../summaryReportTradeBundle');
const { enrichSummaryReportTrades } = require('../summaryReportTradePoolEnrichment');

describe('summaryReportMirrorLinkBatch collectors', () => {
  const contexts = new Map([
    ['trader-1', { mirrorTradeId: 'pool-1', traderTradeId: 'trader-1' }],
    ['pool-1', { mirrorTradeId: 'pool-1', traderTradeId: 'trader-1' }],
    ['solo-1', { mirrorTradeId: null, traderTradeId: 'solo-1' }],
  ]);

  test('collectTraderRowsNeedingMirrorLink skips rows that already have poolMirrorTrade', () => {
    const tradeRows = [{ id: 'trader-1' }, { id: 'solo-1' }];
    const enrichedItems = [
      { legKind: 'trader', poolMirrorTrade: null },
      { legKind: 'standalone', poolMirrorTrade: null },
    ];

    const { mirrorTradeIds, rowIndices } = collectTraderRowsNeedingMirrorLink(
      enrichedItems,
      tradeRows,
      contexts,
    );

    expect(rowIndices).toEqual([0]);
    expect([...mirrorTradeIds]).toEqual(['pool-1']);
  });

  test('collectPoolRowsNeedingTraderLink targets mirror_pool rows missing traderTrade', () => {
    const tradeRows = [{ id: 'pool-1' }];
    const enrichedItems = [
      { legKind: 'mirror_pool', poolMirrorTrade: { tradeId: 'pool-1' }, traderTrade: null },
    ];

    const { traderTradeIds, rowIndices } = collectPoolRowsNeedingTraderLink(
      enrichedItems,
      tradeRows,
      contexts,
    );

    expect(rowIndices).toEqual([0]);
    expect([...traderTradeIds]).toEqual(['trader-1']);
  });
});

describe('summaryReportTradeBundle link fallbacks', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    mockLoadParticipationsByPoolTradeIds.mockResolvedValue(new Map([
      ['pool-1', [{ investorId: 'i1', investmentStatus: 'active', investmentCapital: 1000 }]],
      ['pool-2', [{ investorId: 'i2', investmentStatus: 'active', investmentCapital: 1000 }]],
    ]));
    mockLoadDocumentsByTradeIds.mockResolvedValue(new Map());
  });

  function mockTrade(id) {
    return {
      id,
      get(key) {
        return {
          tradeNumber: 1,
          symbol: 'X',
          status: 'active',
          quantity: 100,
          soldQuantity: 0,
          buyOrder: { quantity: 100, totalAmount: 500, price: 5 },
          sellOrders: [],
        }[key];
      },
    };
  }

  function makeBundle(contexts, tradeById, participationsByPool = new Map()) {
    const { createTradeLegSnapshotCache } = require('../summaryReportTradeSnapshotCache');
    const participationCountsByPool = new Map();
    const participationAggregatesByPool = new Map();
    for (const [id, rows] of participationsByPool) {
      participationCountsByPool.set(id, rows.length);
      participationAggregatesByPool.set(id, {
        count: rows.length,
        totalCommission: 0,
        totalProfitShare: 0,
      });
    }
    return {
      contexts,
      snapshotCache: createTradeLegSnapshotCache({}),
      tradeById,
      participationsByPool,
      participationCountsByPool,
      participationAggregatesByPool,
      participationsInlineMax: 50,
      feeConfig: {},
    };
  }

  test('applyMissingMirrorLinks batches trade and participation loads', async () => {
    const contexts = new Map([
      ['trader-1', { mirrorTradeId: 'pool-1', traderTradeId: 'trader-1' }],
      ['trader-2', { mirrorTradeId: 'pool-2', traderTradeId: 'trader-2' }],
    ]);
    const tradeRows = [mockTrade('trader-1'), mockTrade('trader-2')];
    const traderRef = {
      tradeId: 'trader-1',
      buyQuantity: 100,
      bidPricePerShare: 5,
      buyPrice: 5,
      sellOrders: [],
      soldQuantity: 0,
    };
    const items = [
      { legKind: 'trader', poolMirrorTrade: null, traderTrade: { ...traderRef, tradeId: 'trader-1' } },
      { legKind: 'trader', poolMirrorTrade: null, traderTrade: { ...traderRef, tradeId: 'trader-2' } },
    ];

    const bundle = makeBundle(contexts, new Map([
      ['trader-1', tradeRows[0]],
      ['trader-2', tradeRows[1]],
    ]));

    mockLoadTradesById.mockResolvedValue(new Map([
      ['pool-1', mockTrade('pool-1')],
      ['pool-2', mockTrade('pool-2')],
    ]));
    mockLoadParticipationsByPoolTradeIds.mockResolvedValue(new Map([
      ['pool-1', [{ investorId: 'i1', investmentStatus: 'active', investmentCapital: 1000 }]],
      ['pool-2', [{ investorId: 'i2', investmentStatus: 'active', investmentCapital: 1000 }]],
    ]));

    const out = await applyMissingMirrorLinks(items, tradeRows, bundle);

    expect(mockLoadTradesById).toHaveBeenCalledTimes(1);
    expect(mockLoadParticipationsByPoolTradeIds).toHaveBeenCalledTimes(1);
    expect(out[0].poolMirrorTrade).toBeTruthy();
    expect(out[1].poolMirrorTrade).toBeTruthy();
  });

  test('applyMissingTraderLinks batches trader trade loads', async () => {
    const contexts = new Map([
      ['pool-1', { mirrorTradeId: 'pool-1', traderTradeId: 'trader-1' }],
    ]);
    const tradeRows = [mockTrade('pool-1')];
    const items = [
      {
        legKind: 'mirror_pool',
        poolMirrorTrade: { tradeId: 'pool-1', buyQuantity: 50 },
        traderTrade: null,
      },
    ];

    const bundle = makeBundle(contexts, new Map([['pool-1', tradeRows[0]]]));
    mockLoadTradesById.mockResolvedValue(new Map([['trader-1', mockTrade('trader-1')]]));

    const out = await applyMissingTraderLinks(items, tradeRows, bundle);

    expect(mockLoadTradesById).toHaveBeenCalledTimes(1);
    expect(out[0].traderTrade?.tradeId).toBe('trader-1');
    expect(out[0].legKind).toBe('mirror_pool');
  });
});

describe('enrichSummaryReportTrades unified pipeline', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    mockLoadDocumentsByTradeIds.mockResolvedValue(new Map());
    mockLoadParticipationsByPoolTradeIds.mockResolvedValue(new Map());
    mockLoadTradesById.mockResolvedValue(new Map());
  });

  test('attaches belege once after link fallbacks', async () => {
    const tradeRows = [{
      id: 'trader-1',
      get(key) {
        return {
          tradeNumber: 1,
          symbol: 'X',
          status: 'active',
          quantity: 100,
          soldQuantity: 0,
          buyOrder: { quantity: 100, totalAmount: 500, price: 5 },
          sellOrders: [],
          buyOrderId: null,
        }[key];
      },
    }];
    const baseItems = [{ id: 'trader-1', buyAmount: 500, profit: 0, returnPercentage: 0, investorIds: [] }];
    const contexts = new Map([
      ['trader-1', { legKind: 'standalone', poolTradeId: 'trader-1', traderTradeId: 'trader-1', mirrorTradeId: null, pairExecutionId: null }],
    ]);

    await enrichSummaryReportTrades(tradeRows, baseItems, { pairedLegContexts: contexts });

    expect(mockLoadDocumentsByTradeIds).toHaveBeenCalledTimes(1);
  });
});
