'use strict';

jest.mock('../../admin/reports/documentBelegEnrichment', () => ({
  enrichTraderDocumentMetadata: jest.fn(async (doc) => doc.get('metadata') || {
    executionType: 'buy',
    amount: 930,
    quantity: 500,
    fees: { orderFee: 5, exchangeFee: 1, foreignCosts: 1.5, totalFees: 7.5 },
    totalWithFees: 937.5,
    belegSchemaVersion: 1,
  }),
}));

const { handleGetTraderDocumentBelegDetail } = require('../traderBelegDetail');

function mockUser(id = 'user-1', email = 'trader@test.com') {
  return {
    id,
    get(k) {
      if (k === 'email') return email;
      if (k === 'stableId') return `user:${email}`;
      return null;
    },
  };
}

function mockDoc(attrs) {
  return {
    id: attrs.id || 'doc-tbc-1',
    get(k) {
      return attrs[k];
    },
  };
}

describe('getTraderDocumentBelegDetail', () => {
  beforeEach(() => {
    global.Parse = {
      Error: class ParseError extends Error {
        constructor(code, message) {
          super(message);
          this.code = code;
        }
        static get INVALID_SESSION_TOKEN() { return 209; }
        static get INVALID_QUERY() { return 102; }
        static get OBJECT_NOT_FOUND() { return 101; }
        static get OPERATION_FORBIDDEN() { return 119; }
      },
      Query: class DocumentQuery {
        constructor() {
          this.id = null;
        }
        get(objectId) {
          if (objectId !== 'doc-tbc-1') throw new Error('not found');
          return Promise.resolve(mockDoc({
            id: 'doc-tbc-1',
            userId: 'user-1',
            type: 'traderCollectionBill',
            accountingDocumentNumber: 'TBC-2026-0000099',
            tradeNumber: 1,
            tradeId: 'trade-1',
            name: 'Kaufabrechnung',
            status: 'verified',
            fileURL: 'parse://x',
            size: 100,
            accountingSummaryText: '',
            metadata: { executionType: 'buy', amount: 930 },
          }));
        }
      },
    };
  });

  test('rejects without session', async () => {
    await expect(handleGetTraderDocumentBelegDetail({ params: { objectId: 'doc-tbc-1' } }))
      .rejects.toThrow('Login required');
  });

  test('returns enriched detail for own document', async () => {
    const out = await handleGetTraderDocumentBelegDetail({
      user: mockUser(),
      params: { objectId: 'doc-tbc-1' },
    });
    expect(out.objectId).toBe('doc-tbc-1');
    expect(out.accountingSummaryText).toContain('TBC-2026-0000099');
    expect(out.summarySource).toBe('snapshot');
    expect(out.displaySections.length).toBeGreaterThan(0);
  });

  test('hides foreign documents as not found', async () => {
    global.Parse.Query = class DocumentQuery {
      get() {
        return Promise.resolve(mockDoc({
          id: 'doc-other',
          userId: 'other-user',
          type: 'traderCollectionBill',
        }));
      }
    };
    await expect(handleGetTraderDocumentBelegDetail({
      user: mockUser(),
      params: { objectId: 'doc-other' },
    })).rejects.toThrow('not found');
  });
});
