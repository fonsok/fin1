'use strict';

const {
  shouldShowTraderSellLegs,
  buildTraderSellLegsFromSells,
  buildTraderSellLegCard,
} = require('../summaryReportTraderSellLegs');

function mockSellDoc({
  id,
  docNumber,
  partialSell,
  instrumentLine,
  quantity,
  price,
  amount,
  fees,
  totalWithFees,
}) {
  return {
    id,
    get(key) {
      const data = {
        type: 'traderCollectionBill',
        accountingDocumentNumber: docNumber,
        metadata: {
          belegSchemaVersion: 1,
          traderDisplayName: 'Trader One',
          executionType: 'sell',
          instrumentLine: instrumentLine || 'VO5G3MN - Put - DAX - Strike 38900',
          quantity: quantity ?? 800,
          price: price ?? 5,
          amount: amount ?? 4000,
          fees: fees ?? { orderFee: 20, exchangeFee: 4, foreignCosts: 1.5, totalFees: 25.5 },
          totalWithFees: totalWithFees ?? 3974.5,
          valueDate: '10.06.26',
          closingDate: '10.06.2026, 17:04 Uhr',
          partialSell: partialSell ?? null,
        },
        createdAt: new Date('2026-06-10T15:04:00Z'),
      };
      if (key === 'name') return 'Verkaufsabrechnung';
      return data[key];
    },
  };
}

describe('summaryReportTraderSellLegs', () => {
  test('shouldShowTraderSellLegs true for multiple sells', () => {
    expect(shouldShowTraderSellLegs([mockSellDoc({ id: 'a' }), mockSellDoc({ id: 'b' })], 'open')).toBe(true);
  });

  test('shouldShowTraderSellLegs true for partial trade with one sell', () => {
    expect(shouldShowTraderSellLegs([mockSellDoc({ id: 'a' })], 'partial')).toBe(true);
  });

  test('shouldShowTraderSellLegs false for single full sell', () => {
    expect(shouldShowTraderSellLegs([mockSellDoc({ id: 'a', partialSell: null })], 'completed')).toBe(false);
  });

  test('buildTraderSellLegsFromSells maps Collection-Bill-style cards via displaySections', () => {
    const sells = [
      mockSellDoc({
        id: 's1',
        docNumber: 'TSC-2026-0000134',
        partialSell: {
          isPartialSell: true,
          eventIndex: 1,
          totalSellEvents: 3,
          executedAt: '2026-06-10T15:04:00.000Z',
          orderQuantity: 800,
        },
        quantity: 800,
        amount: 4000,
        totalWithFees: 3974.5,
      }),
      mockSellDoc({
        id: 's2',
        docNumber: 'TSC-2026-0000135',
        partialSell: {
          isPartialSell: true,
          eventIndex: 2,
          totalSellEvents: 3,
          executedAt: '2026-06-10T15:05:00.000Z',
          orderQuantity: 300,
        },
        quantity: 300,
        price: 2.9613,
        amount: 888.4,
        totalWithFees: 880.9,
      }),
    ];
    const legs = buildTraderSellLegsFromSells(sells, 'partial');
    expect(legs).toHaveLength(2);
    expect(legs[0].title).toBe('VERKAUF - Nr. 1/3');
    expect(legs[1].title).toBe('VERKAUF - Nr. 2/3');
    expect(legs[0].verkaufRows.some((r) => r.label === 'Ordervolumen')).toBe(true);
    expect(legs[0].verkaufRows.some((r) => r.label === 'Σ VERKAUF')).toBe(true);
    expect(legs[0].partialSellRows.some((r) => r.label === 'Reihenfolge')).toBe(true);
  });

  test('buildTraderSellLegCard uses enriched metadata override', () => {
    const doc = mockSellDoc({
      id: 's1',
      docNumber: 'TSC-1',
      instrumentLine: '',
      quantity: 0,
      amount: 0,
      fees: { orderFee: 0, exchangeFee: 0, foreignCosts: 0, totalFees: 0 },
      totalWithFees: 0,
    });
    const enriched = {
      belegSchemaVersion: 1,
      traderDisplayName: 'Trader One',
      executionType: 'sell',
      instrumentLine: 'ENRICHED - Put - DAX',
      quantity: 500,
      price: 2,
      amount: 1000,
      fees: { orderFee: 5, exchangeFee: 1, foreignCosts: 1.5, totalFees: 7.5 },
      totalWithFees: 992.5,
      valueDate: '10.06.26',
      closingDate: '10.06.2026, 17:04 Uhr',
    };
    const leg = buildTraderSellLegCard(doc, 0, 1, enriched);
    expect(leg.instrumentLine).toBe('ENRICHED - Put - DAX');
    expect(leg.verkaufRows.some((r) => r.label === 'Ordervolumen' && r.value.includes('500'))).toBe(true);
  });
});
