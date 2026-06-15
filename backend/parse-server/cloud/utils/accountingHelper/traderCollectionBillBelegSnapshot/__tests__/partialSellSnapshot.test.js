'use strict';

const {
  buildPartialSellSnapshot,
  sortTraderSellBelegeChronologically,
} = require('../partialSellSnapshot');
const { buildTraderCollectionBillBelegSnapshot } = require('../buildCollectionBill');

function mockTrade(attrs = {}) {
  return {
    id: 'trade-1',
    get(k) {
      return attrs[k];
    },
  };
}

function mockDoc({ id, docNumber, partialSell, createdAt }) {
  return {
    id,
    get(key) {
      if (key === 'accountingDocumentNumber') return docNumber;
      if (key === 'metadata') return { executionType: 'sell', partialSell };
      if (key === 'createdAt') return createdAt || new Date('2026-06-10T12:00:00Z');
      return null;
    },
  };
}

describe('partialSellSnapshot', () => {
  test('cumulative quantity stops at current sell leg, not later sells', () => {
    const trade = mockTrade({
      status: 'partial',
      quantity: 1000,
      sellOrders: [
        { id: 'sell-1', quantity: 500, totalAmount: 1500, createdAt: '2026-06-08T10:00:00Z' },
        { id: 'sell-2', quantity: 300, totalAmount: 900, createdAt: '2026-06-09T11:00:00Z' },
      ],
    });
    const first = buildPartialSellSnapshot({
      trade,
      order: { id: 'sell-1', quantity: 500 },
      orderLike: { id: 'sell-1', quantity: 500, createdAt: '2026-06-08T10:00:00Z' },
      sellOrderId: 'sell-1',
      buyQty: 1000,
      tradeStatus: 'partial',
    });
    expect(first.partialSell.eventIndex).toBe(1);
    expect(first.partialSell.totalSellEvents).toBe(2);
    expect(first.partialSell.cumulativeSoldQuantity).toBe(500);
    expect(first.partialSell.remainingQuantity).toBe(500);

    const second = buildPartialSellSnapshot({
      trade,
      order: { id: 'sell-2', quantity: 300 },
      orderLike: { id: 'sell-2', quantity: 300, createdAt: '2026-06-09T11:00:00Z' },
      sellOrderId: 'sell-2',
      buyQty: 1000,
      tradeStatus: 'partial',
    });
    expect(second.partialSell.eventIndex).toBe(2);
    expect(second.partialSell.cumulativeSoldQuantity).toBe(800);
    expect(second.partialSell.remainingQuantity).toBe(200);
  });

  test('final sell leg of multi-event sequence still emits partialSell block when trade completes', () => {
    const trade = mockTrade({
      status: 'completed',
      quantity: 1200,
      sellOrders: [
        { id: 'sell-1', quantity: 400, totalAmount: 1600, createdAt: '2026-06-15T12:45:00Z' },
        { id: 'sell-2', quantity: 800, totalAmount: 2400, createdAt: '2026-06-15T12:47:00Z' },
      ],
    });
    const second = buildPartialSellSnapshot({
      trade,
      order: { id: 'sell-2', quantity: 800 },
      orderLike: { id: 'sell-2', quantity: 800, createdAt: '2026-06-15T12:47:00Z' },
      sellOrderId: 'sell-2',
      buyQty: 1200,
      tradeStatus: 'completed',
    });
    expect(second.isPartialSell).toBe(true);
    expect(second.partialSell.eventIndex).toBe(2);
    expect(second.partialSell.totalSellEvents).toBe(2);
    expect(second.partialSell.orderQuantity).toBe(800);
    expect(second.partialSell.cumulativeSoldQuantity).toBe(1200);
    expect(second.partialSell.remainingQuantity).toBe(0);
    expect(second.partialSell.sellVolumeProgress).toBe(1);
  });

  test('sortTraderSellBelegeChronologically uses executedAt, not doc createdAt', () => {
    const docs = [
      mockDoc({
        id: 'late-doc',
        docNumber: 'TSC-129',
        partialSell: {
          eventIndex: 2,
          executedAt: '2026-06-09T11:00:00.000Z',
        },
        createdAt: new Date('2026-06-10T16:00:00Z'),
      }),
      mockDoc({
        id: 'early-doc',
        docNumber: 'TSC-128',
        partialSell: {
          eventIndex: 1,
          executedAt: '2026-06-08T10:00:00.000Z',
        },
        createdAt: new Date('2026-06-10T15:00:00Z'),
      }),
    ];
    const sorted = sortTraderSellBelegeChronologically(docs);
    expect(sorted[0].id).toBe('early-doc');
    expect(sorted[1].id).toBe('late-doc');
  });

  test('buildTraderCollectionBillBelegSnapshot persists executedAt on partial sell', () => {
    const trade = mockTrade({
      status: 'partial',
      quantity: 1000,
      sellOrders: [{ id: 'sell-1', quantity: 500, totalAmount: 1000, createdAt: '2026-06-08T10:00:00Z' }],
    });
    const out = buildTraderCollectionBillBelegSnapshot({
      trade,
      order: { id: 'sell-1', quantity: 500, totalAmount: 1000, createdAt: '2026-06-08T10:00:00Z' },
      executionType: 'sell',
      grossAmount: 1000,
      label: 'Verkaufsabrechnung',
      docNumber: 'TSC-2026-0000128',
      tradeNumber: 1,
    });
    expect(out.metadata.partialSell.executedAt).toBe('2026-06-08T10:00:00.000Z');
    expect(out.metadata.partialSell.eventIndex).toBe(1);
    expect(out.accountingSummaryText).toContain('Ausgeführt am:');
  });
});
