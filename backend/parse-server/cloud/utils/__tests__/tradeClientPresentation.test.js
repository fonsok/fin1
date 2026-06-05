'use strict';

const {
  normalizeTradeForClient,
  normalizeBuyOrderSnapshot,
} = require('../tradeClientPresentation');

function mockTrade(fields = {}) {
  const data = {
    id: 'trade-1',
    traderId: 'traderObj12',
    symbol: 'SAP',
    securityName: 'SAP SE',
    buyAmount: 930,
    quantity: 500,
    buyPrice: 1.86,
    createdAt: new Date('2026-05-15T12:00:00.000Z'),
    ...fields,
  };
  return {
    id: data.id,
    createdAt: data.createdAt,
    get(key) {
      return data[key];
    },
    toJSON() {
      return {
        objectId: data.id,
        tradeNumber: data.tradeNumber ?? 42,
        traderId: data.traderId,
        symbol: data.symbol,
        status: data.status ?? 'active',
        createdAt: data.createdAt,
        updatedAt: data.createdAt,
        buyOrder: data.buyOrder,
      };
    },
  };
}

describe('tradeClientPresentation', () => {
  test('normalizeBuyOrderSnapshot fills iOS-required buyOrder fields', () => {
    const trade = mockTrade();
    const snap = normalizeBuyOrderSnapshot({
      objectId: 'order-1',
      quantity: 500,
      price: 1.86,
      totalAmount: 930,
      symbol: 'SAP',
    }, trade);

    expect(snap.id).toBe('order-1');
    expect(snap.traderId).toBe('traderObj12');
    expect(snap.description).toBe('SAP SE');
    expect(snap.status).toBe('executed');
    expect(snap.createdAt).toBeTruthy();
  });

  test('normalizeBuyOrderSnapshot passes mirror-pool leg flags', () => {
    const trade = mockTrade();
    const snap = normalizeBuyOrderSnapshot({
      objectId: 'order-m',
      quantity: 18,
      price: 1.64,
      isMirrorPoolOrder: true,
      legType: 'MIRROR_POOL',
    }, trade);

    expect(snap.isMirrorPoolOrder).toBe(true);
    expect(snap.legType).toBe('MIRROR_POOL');
  });

  test('normalizeTradeForClient maps securityName to description', () => {
    const trade = mockTrade({
      buyOrder: { objectId: 'o1', quantity: 10, price: 2, totalAmount: 20, symbol: 'X' },
    });
    const out = normalizeTradeForClient(trade);
    expect(out.description).toBe('SAP SE');
    expect(out.buyOrder.id).toBe('o1');
    expect(out.buyOrder.description).toBe('SAP SE');
  });
});
