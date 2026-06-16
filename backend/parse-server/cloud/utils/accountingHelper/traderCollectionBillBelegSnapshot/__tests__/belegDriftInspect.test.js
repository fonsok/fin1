'use strict';

const {
  inspectDocumentBelegDrift,
  parseSnapshotQuantity,
  parseSnapshotExecutionSide,
  parsePartialSellEventIndexFromSummary,
  inspectPartialSellMetadataInternalDrift,
  inspectPartialSellTradeLegDrift,
  inspectTraderCollectionBillBelegDrift,
} = require('../belegDriftInspect');

function mockDoc(fields = {}) {
  const data = {
    id: 'doc-tsc-1',
    type: 'traderCollectionBill',
    accountingDocumentNumber: 'TSC-2026-0000140',
    tradeId: 'trade-1',
    accountingSummaryText: '',
    metadata: {},
    ...fields,
  };
  return {
    id: data.id,
    get(key) {
      return data[key];
    },
  };
}

describe('traderCollectionBillBelegSnapshot/belegDriftInspect', () => {
  test('parseSnapshotQuantity reads Ordervolumen', () => {
    expect(parseSnapshotQuantity('Ordervolumen: 400 St.')).toBe(400);
  });

  test('parseSnapshotExecutionSide detects sell', () => {
    const text = 'Verkaufsabrechnung\nVERKAUF\nΣ VERKAUF: 988,50 €';
    expect(parseSnapshotExecutionSide(text)).toBe('sell');
  });

  test('flags needs_backfill when summary missing', () => {
    const out = inspectDocumentBelegDrift(mockDoc({ accountingSummaryText: '', metadata: { amount: 100 } }));
    expect(out.status).toBe('needs_backfill');
    expect(out.drifts.some((d) => d.field === 'accountingSummaryText')).toBe(true);
  });

  test('detects quantity drift between snapshot and metadata', () => {
    const summary = [
      'Verkaufsabrechnung',
      'Belegnummer: TSC-2026-0000140',
      'VERKAUF',
      'Ordervolumen: 400 St.',
      'Kurswert: 996,00 €',
      'Σ VERKAUF: 988,50 €',
    ].join('\n');
    const out = inspectDocumentBelegDrift(mockDoc({
      accountingSummaryText: summary,
      metadata: {
        belegSchemaVersion: 1,
        executionType: 'sell',
        amount: 996,
        quantity: 1200,
        totalWithFees: 988.5,
        traderDisplayName: 'Trader One',
        fees: { totalFees: 7.5, orderFee: 5 },
      },
    }));
    expect(out.status).toBe('drifted');
    expect(out.drifts).toEqual(expect.arrayContaining([
      expect.objectContaining({ field: 'quantity', snapshot: 400, metadata: 1200 }),
    ]));
  });

  test('healthy when snapshot and metadata align', () => {
    const summary = [
      'Kaufabrechnung',
      'Belegnummer: TBC-2026-0000099',
      'KAUF',
      'Ordervolumen: 500 St.',
      'Kurswert: 930,00 €',
      'Σ KAUF: 937,50 €',
    ].join('\n');
    const out = inspectDocumentBelegDrift(mockDoc({
      accountingSummaryText: summary,
      metadata: {
        belegSchemaVersion: 1,
        executionType: 'buy',
        amount: 930,
        quantity: 500,
        totalWithFees: 937.5,
        traderDisplayName: 'Trader One',
        fees: { totalFees: 7.5, orderFee: 5 },
      },
    }));
    expect(out.status).toBe('healthy');
    expect(out.drifts).toHaveLength(0);
  });

  test('parsePartialSellEventIndexFromSummary reads Teilverkauf line', () => {
    expect(parsePartialSellEventIndexFromSummary('Reihenfolge: Teilverkauf 2 von 2')).toBe(2);
  });

  test('accepts high-precision execution price when amount equals round2(qty * price)', () => {
    const drifts = inspectPartialSellMetadataInternalDrift({
      amount: 2465.64,
      quantity: 1000,
      price: 2.465642613502255,
      sellOrderId: 'sell-2',
      partialSell: {
        isPartialSell: true,
        sellOrderId: 'sell-2',
        orderQuantity: 1000,
        eventIndex: 2,
        totalSellEvents: 2,
        buyQuantity: 1500,
        cumulativeSoldQuantity: 1500,
        remainingQuantity: 0,
      },
    });
    expect(drifts.filter((d) => d.code === 'partial_sell_amount_quantity_price_mismatch')).toHaveLength(0);
  });

  test('detects partial-sell amount/qty/price inconsistency without Trade', () => {
    const drifts = inspectPartialSellMetadataInternalDrift({
      amount: 2400,
      quantity: 400,
      price: 3,
      sellOrderId: 'sell-1',
      partialSell: {
        isPartialSell: true,
        sellOrderId: 'sell-1',
        orderQuantity: 400,
        eventIndex: 1,
        buyQuantity: 1200,
        cumulativeSoldQuantity: 400,
        remainingQuantity: 800,
      },
    });
    expect(drifts).toEqual(expect.arrayContaining([
      expect.objectContaining({
        code: 'partial_sell_amount_quantity_price_mismatch',
        metadata: 2400,
        expected: 1200,
      }),
    ]));
  });

  test('detects stale sellOrderId vs Trade leg on partial sell TSC', () => {
    const trade = {
      get(k) {
        const data = {
          quantity: 1200,
          sellOrders: [
            { id: 'sell-1', quantity: 400, totalAmount: 1600 },
            { id: 'sell-2', quantity: 800, totalAmount: 2400 },
          ],
        };
        return data[k];
      },
    };
    const drifts = inspectPartialSellTradeLegDrift({
      executionType: 'sell',
      amount: 2400,
      quantity: 400,
      sellOrderId: 'sell-1',
      partialSell: {
        isPartialSell: true,
        sellOrderId: 'sell-1',
        orderQuantity: 400,
        eventIndex: 1,
      },
    }, trade);
    expect(drifts).toEqual(expect.arrayContaining([
      expect.objectContaining({
        field: 'sellOrderId',
        code: 'partial_sell_leg_mismatch',
        metadata: 'sell-1',
        expected: 'sell-2',
      }),
      expect.objectContaining({
        field: 'partialSell.eventIndex',
        code: 'partial_sell_leg_mismatch',
        metadata: 1,
        expected: 2,
      }),
    ]));
  });

  test('flags partial-sell leg drift on full document inspect with Trade option', () => {
    const summary = [
      'Verkaufsabrechnung',
      'Belegnummer: TSC-2026-0000141',
      'VERKAUF',
      'Ordervolumen: 400 St.',
      'Kurswert: 2.400,00 €',
      'Σ VERKAUF: 2.392,50 €',
      '',
      'TEILVERKAUF',
      'Reihenfolge: Teilverkauf 1 von 2',
      'Dieser Verkauf: 400 St.',
    ].join('\n');
    const trade = {
      get(k) {
        return {
          quantity: 1200,
          sellOrders: [
            { id: 'sell-1', quantity: 400, totalAmount: 1600 },
            { id: 'sell-2', quantity: 800, totalAmount: 2400 },
          ],
        }[k];
      },
    };
    const out = inspectDocumentBelegDrift(mockDoc({
      accountingSummaryText: summary,
      metadata: {
        belegSchemaVersion: 1,
        executionType: 'sell',
        amount: 2400,
        quantity: 400,
        price: 3,
        totalWithFees: 2392.5,
        traderDisplayName: 'Trader One',
        sellOrderId: 'sell-1',
        fees: { totalFees: 7.5, orderFee: 5 },
        partialSell: {
          isPartialSell: true,
          sellOrderId: 'sell-1',
          orderQuantity: 400,
          eventIndex: 1,
          totalSellEvents: 2,
          buyQuantity: 1200,
          cumulativeSoldQuantity: 400,
          remainingQuantity: 800,
        },
      },
    }), { trade });
    expect(out.status).toBe('drifted');
    expect(out.drifts.some((d) => d.code === 'partial_sell_amount_quantity_price_mismatch')).toBe(true);
    expect(out.drifts.some((d) => d.code === 'partial_sell_leg_mismatch')).toBe(true);
  });

  test('batch inspect aggregates drift counts', async () => {
    global.Parse = {
      Query: class MockQuery {
        constructor() { this.className = 'Document'; }
        containedIn() { return this; }
        equalTo() { return this; }
        descending() { return this; }
        skip() { return this; }
        limit() { return this; }
        async find() {
          return [mockDoc({
            accountingSummaryText: 'Verkaufsabrechnung\nVERKAUF\nOrdervolumen: 400 St.\nKurswert: 996,00 €\nΣ VERKAUF: 988,50 €',
            metadata: {
              belegSchemaVersion: 1,
              executionType: 'sell',
              amount: 996,
              quantity: 400,
              totalWithFees: 988.5,
              traderDisplayName: 'Trader One',
              fees: { totalFees: 7.5, orderFee: 5 },
            },
          })];
        }
      },
    };

    const report = await inspectTraderCollectionBillBelegDrift({ limit: 10, includeInvoice: false });
    expect(report.examined).toBe(1);
    expect(report.healthy).toBe(1);
    expect(report.drifted).toBe(0);
  });
});
