'use strict';

const auditCalls = [];
jest.mock('../../../utils/structuredLogger', () => ({
  audit: {
    info: (event, fields) => auditCalls.push({ event, fields }),
    warn: jest.fn(),
    error: jest.fn(),
  },
}));

const mockEnrich = jest.fn();
const mockLoadInvoice = jest.fn();

jest.mock('../reports/documentBelegEnrichment', () => ({
  enrichTraderDocumentMetadata: (...args) => mockEnrich(...args),
  loadTradeInvoice: (...args) => mockLoadInvoice(...args),
}));

jest.mock('../../../utils/helpers', () => ({
  calculateOrderFees: jest.fn(() => ({
    orderFee: 5,
    exchangeFee: 1,
    foreignCosts: 1.5,
    totalFees: 7.5,
  })),
}));

const {
  handleBackfillTraderCollectionBillBeleg,
  documentNeedsBackfill,
  buildPersistedTraderBelegFields,
} = require('../financialTraderCollectionBillBelegBackfill');

function mockDoc(fields = {}) {
  const data = {
    id: 'doc-legacy',
    type: 'traderCollectionBill',
    accountingDocumentNumber: 'TBC-2026-0000033',
    tradeId: 'trade-33',
    tradeNumber: 33,
    accountingSummaryText: '',
    metadata: { amount: 930, executionType: 'buy' },
    ...fields,
  };
  const sets = {};
  return {
    id: data.id,
    get(key) {
      return data[key];
    },
    set(key, val) {
      sets[key] = val;
      data[key] = val;
    },
    save: jest.fn(async () => ({ id: data.id })),
    _sets: sets,
  };
}

let docsToFind = [];

beforeEach(() => {
  auditCalls.length = 0;
  docsToFind = [];
  mockEnrich.mockReset();
  mockLoadInvoice.mockReset();

  global.Parse = {
    Query: class MockQuery {
      constructor(className) {
        this.className = className;
      }
      containedIn() { return this; }
      equalTo() { return this; }
      ascending() { return this; }
      skip() { return this; }
      limit() { return this; }
      async find() {
        if (this.className === 'Document') return docsToFind;
        return [];
      }
      get(objectId) {
        if (this.className !== 'Trade') {
          return Promise.reject(new Error('Trade not found'));
        }
        if (objectId === 'trade-partial-sell') {
          return Promise.resolve({
            get(k) {
              const trade = {
                quantity: 1200,
                feeConfig: {},
                tradeNumber: 140,
                symbol: 'CI4YLSD',
                status: 'completed',
                buyOrder: {
                  price: 1.86,
                  quantity: 1200,
                  wkn: 'CI4YLSD',
                  createdAt: new Date('2026-05-15T14:30:00.000Z'),
                },
                sellOrders: [
                  {
                    id: 'sell-1',
                    quantity: 400,
                    totalAmount: 1600,
                    createdAt: '2026-06-15T12:45:00.000Z',
                  },
                  {
                    id: 'sell-2',
                    quantity: 800,
                    totalAmount: 2400,
                    createdAt: '2026-06-15T12:47:00.000Z',
                  },
                ],
              };
              return trade[k];
            },
          });
        }
        if (objectId !== 'trade-33') {
          return Promise.reject(new Error('Trade not found'));
        }
        return Promise.resolve({
          get(k) {
            const trade = {
              quantity: 500,
              feeConfig: {},
              tradeNumber: 33,
              symbol: 'CI4YLSD',
              buyOrder: {
                price: 1.86,
                quantity: 500,
                wkn: 'CI4YLSD',
                optionDirection: 'PUT',
                underlyingAsset: 'FTSE 100',
                strikePrice: '12.808',
                issuer: 'Citigroup',
                createdAt: new Date('2026-05-15T14:30:00.000Z'),
              },
            };
            return trade[k];
          },
        });
      }
    },
  };
});

describe('documentNeedsBackfill', () => {
  test('skips when summary and metadata are SSOT-complete', () => {
    const doc = mockDoc({
      accountingSummaryText: 'Kaufabrechnung\nBelegnummer TBC-2026-0000033\nOrdervolumen 930,00 €',
      metadata: {
        belegSchemaVersion: 1,
        amount: 930,
        traderDisplayName: 'Dr. Hans-Peter Müller',
        fees: { totalFees: 7.5, orderFee: 5 },
      },
    });
    expect(documentNeedsBackfill(doc)).toBe(false);
  });

  test('needs backfill when summary missing Ordervolumen markers', () => {
    const doc = mockDoc({ accountingSummaryText: 'kurz', metadata: { belegSchemaVersion: 1, amount: 930, fees: { totalFees: 1 } } });
    expect(documentNeedsBackfill(doc)).toBe(true);
  });
});

describe('buildPersistedTraderBelegFields', () => {
  test('uses full snapshot when tradeId and amount present', async () => {
    mockEnrich.mockResolvedValue({
      amount: 930,
      executionType: 'buy',
      belegLabel: 'Kaufabrechnung',
      tradeNumber: 33,
      fees: { totalFees: 7.5, orderFee: 5, exchangeFee: 1, foreignCosts: 1.5 },
    });
    mockLoadInvoice.mockResolvedValue(null);

    const doc = mockDoc();
    const out = await buildPersistedTraderBelegFields(doc);

    expect(out.rebuildSource).toBe('snapshot');
    expect(out.metadata.belegSchemaVersion).toBe(1);
    expect(out.accountingSummaryText).toContain('Ordervolumen');
    expect(out.accountingSummaryText).toContain('TBC-2026-0000033');
  });

  test('sell backfill resolves leg by sellOrderId when consistent', async () => {
    mockEnrich.mockResolvedValue({
      amount: 2400,
      quantity: 800,
      executionType: 'sell',
      belegLabel: 'Verkaufsabrechnung',
      tradeNumber: 140,
      fees: { totalFees: 7.5, orderFee: 5, exchangeFee: 1, foreignCosts: 1.5 },
    });
    mockLoadInvoice.mockResolvedValue(null);

    const doc = mockDoc({
      id: 'doc-sell-2',
      accountingDocumentNumber: 'TSC-2026-0000141',
      tradeId: 'trade-partial-sell',
      tradeNumber: 140,
      metadata: {
        amount: 2400,
        quantity: 800,
        executionType: 'sell',
        sellOrderId: 'sell-2',
      },
    });
    const out = await buildPersistedTraderBelegFields(doc);

    expect(out.rebuildSource).toBe('snapshot');
    expect(out.metadata.partialSell.eventIndex).toBe(2);
    expect(out.metadata.partialSell.orderQuantity).toBe(800);
    expect(out.metadata.sellOrderId).toBe('sell-2');
    expect(out.accountingSummaryText).toContain('Teilverkauf 2 von 2');
  });

  test('sell backfill ignores stale sellOrderId when gross amount points to another leg', async () => {
    mockEnrich.mockResolvedValue({
      amount: 2400,
      quantity: 400,
      executionType: 'sell',
      belegLabel: 'Verkaufsabrechnung',
      tradeNumber: 140,
      fees: { totalFees: 7.5, orderFee: 5, exchangeFee: 1, foreignCosts: 1.5 },
    });
    mockLoadInvoice.mockResolvedValue(null);

    const doc = mockDoc({
      id: 'doc-sell-2-stale',
      accountingDocumentNumber: 'TSC-2026-0000141',
      tradeId: 'trade-partial-sell',
      tradeNumber: 140,
      metadata: {
        amount: 2400,
        quantity: 400,
        executionType: 'sell',
        sellOrderId: 'sell-1',
      },
    });
    const out = await buildPersistedTraderBelegFields(doc);

    expect(out.metadata.partialSell.eventIndex).toBe(2);
    expect(out.metadata.partialSell.orderQuantity).toBe(800);
    expect(out.metadata.sellOrderId).toBe('sell-2');
    expect(out.metadata.quantity).toBe(800);
  });
});

describe('backfillTraderCollectionBillBeleg', () => {
  test('dryRun previews wouldUpdate without save', async () => {
    const legacy = mockDoc();
    docsToFind = [legacy];

    mockEnrich.mockResolvedValue({
      amount: 930,
      executionType: 'buy',
      belegLabel: 'Kaufabrechnung',
      tradeNumber: 33,
      fees: { totalFees: 7.5, orderFee: 5, exchangeFee: 1, foreignCosts: 1.5 },
    });
    mockLoadInvoice.mockResolvedValue(null);

    const out = await handleBackfillTraderCollectionBillBeleg({
      params: { dryRun: true, documentNumber: 'TBC-2026-0000033' },
    });

    expect(out.examined).toBe(1);
    expect(out.updated).toBe(1);
    expect(out.skipped).toBe(0);
    expect(out.preview[0]).toMatchObject({
      objectId: 'doc-legacy',
      status: 'wouldUpdate',
      rebuildSource: 'snapshot',
    });
    expect(legacy.save).not.toHaveBeenCalled();
  });

  test('live run persists metadata and accountingSummaryText', async () => {
    const legacy = mockDoc();
    docsToFind = [legacy];

    mockEnrich.mockResolvedValue({
      amount: 930,
      executionType: 'buy',
      belegLabel: 'Kaufabrechnung',
      tradeNumber: 33,
      fees: { totalFees: 7.5, orderFee: 5, exchangeFee: 1, foreignCosts: 1.5 },
    });
    mockLoadInvoice.mockResolvedValue(null);

    const out = await handleBackfillTraderCollectionBillBeleg({
      params: { dryRun: false, documentNumber: 'TBC-2026-0000033' },
    });

    expect(out.updated).toBe(1);
    expect(legacy.save).toHaveBeenCalled();
    expect(String(legacy.get('accountingSummaryText'))).toContain('Ordervolumen');
    expect(legacy.get('metadata').belegSchemaVersion).toBe(1);
    expect(auditCalls.some((c) => c.event === 'admin.traderBeleg.backfill')).toBe(true);
  });

  test('skips documents that already have usable SSOT', async () => {
    const complete = mockDoc({
      accountingSummaryText: 'Kaufabrechnung\nBelegnummer TBC-2026-0000099\nOrdervolumen 100,00 €',
      metadata: {
        belegSchemaVersion: 1,
        amount: 100,
        traderDisplayName: 'Dr. Hans-Peter Müller',
        fees: { totalFees: 5, orderFee: 5 },
      },
    });
    docsToFind = [complete];

    const out = await handleBackfillTraderCollectionBillBeleg({ params: { dryRun: true } });

    expect(out.skipped).toBe(1);
    expect(out.updated).toBe(0);
    expect(mockEnrich).not.toHaveBeenCalled();
  });
});
