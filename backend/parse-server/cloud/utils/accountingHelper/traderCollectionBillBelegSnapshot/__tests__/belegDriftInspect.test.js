'use strict';

const {
  inspectDocumentBelegDrift,
  parseSnapshotQuantity,
  parseSnapshotExecutionSide,
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
