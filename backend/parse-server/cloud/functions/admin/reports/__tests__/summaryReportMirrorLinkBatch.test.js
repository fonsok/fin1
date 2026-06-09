'use strict';

const mockLoadParticipationsByPoolTradeIds = jest.fn();
const mockLoadTradesById = jest.fn();
const mockLoadDocumentsByTradeIds = jest.fn();

jest.mock('../summaryReportParticipationLoader', () => ({
  loadParticipationsByPoolTradeIds: (...args) => mockLoadParticipationsByPoolTradeIds(...args),
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
  };
});

jest.mock('../../../../utils/pairedTradeMirrorSync', () => ({
  getMirrorTradeForPairedTraderLeg: jest.fn(),
  getTraderTradeForPairedMirrorLeg: jest.fn(),
}));

const {
  collectTraderRowsNeedingMirrorLink,
  collectPoolRowsNeedingTraderLink,
} = require('../summaryReportMirrorLinkBatch');
const {
  getMirrorTradeForPairedTraderLeg,
  getTraderTradeForPairedMirrorLeg,
} = require('../../../../utils/pairedTradeMirrorSync');
const {
  ensureMirrorLinkForTraderRows,
  ensureTraderLinkForPoolRows,
} = require('../summaryReportTradePoolEnrichment');

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

describe('ensureMirrorLink batching (no per-row leg resolution)', () => {
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

  test('ensureMirrorLinkForTraderRows batches trades, participations, and documents', async () => {
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
    const enrichedItems = [
      { legKind: 'trader', poolMirrorTrade: null, traderTrade: { ...traderRef, tradeId: 'trader-1' } },
      { legKind: 'trader', poolMirrorTrade: null, traderTrade: { ...traderRef, tradeId: 'trader-2' } },
    ];

    mockLoadTradesById.mockResolvedValue(new Map([
      ['pool-1', mockTrade('pool-1')],
      ['pool-2', mockTrade('pool-2')],
    ]));

    const out = await ensureMirrorLinkForTraderRows(
      enrichedItems,
      tradeRows,
      {},
      { pairedLegContexts: contexts },
    );

    expect(getMirrorTradeForPairedTraderLeg).not.toHaveBeenCalled();
    expect(mockLoadTradesById).toHaveBeenCalledTimes(1);
    expect(mockLoadTradesById.mock.calls[0][0]).toEqual(expect.arrayContaining(['pool-1', 'pool-2']));
    expect(mockLoadParticipationsByPoolTradeIds).toHaveBeenCalledTimes(1);
    expect(mockLoadParticipationsByPoolTradeIds.mock.calls[0][0]).toEqual(
      expect.arrayContaining(['pool-1', 'pool-2']),
    );
    expect(mockLoadDocumentsByTradeIds).toHaveBeenCalledTimes(1);
    expect(out[0].poolMirrorTrade).toBeTruthy();
    expect(out[1].poolMirrorTrade).toBeTruthy();
  });

  test('ensureTraderLinkForPoolRows batches trader trade loads', async () => {
    const contexts = new Map([
      ['pool-1', { mirrorTradeId: 'pool-1', traderTradeId: 'trader-1' }],
    ]);
    const tradeRows = [mockTrade('pool-1')];
    const enrichedItems = [
      {
        legKind: 'mirror_pool',
        poolMirrorTrade: { tradeId: 'pool-1', buyQuantity: 50 },
        traderTrade: null,
      },
    ];

    mockLoadTradesById.mockResolvedValue(new Map([['trader-1', mockTrade('trader-1')]]));

    const out = await ensureTraderLinkForPoolRows(
      enrichedItems,
      tradeRows,
      {},
      { pairedLegContexts: contexts },
    );

    expect(getTraderTradeForPairedMirrorLeg).not.toHaveBeenCalled();
    expect(mockLoadTradesById).toHaveBeenCalledTimes(1);
    expect(mockLoadTradesById.mock.calls[0][0]).toEqual(['trader-1']);
    expect(out[0].traderTrade?.tradeId).toBe('trader-1');
    expect(out[0].legKind).toBe('mirror_pool');
  });
});
