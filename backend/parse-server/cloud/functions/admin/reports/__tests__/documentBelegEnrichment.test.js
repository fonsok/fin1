'use strict';

jest.mock('../../../../utils/helpers', () => ({
  calculateOrderFees: jest.fn(() => ({
    orderFee: 5,
    exchangeFee: 1,
    foreignCosts: 1.5,
    totalFees: 7.5,
  })),
}));

const { enrichTraderDocumentMetadata } = require('../documentBelegEnrichment');

function mockDoc(fields) {
  const data = { metadata: {}, ...fields };
  return {
    id: data.id || 'doc-1',
    get(key) {
      return data[key];
    },
  };
}

describe('documentBelegEnrichment', () => {
  beforeEach(() => {
    global.Parse = {
      Query: class MockQuery {
        constructor(className) {
          this.className = className;
        }
        equalTo() { return this; }
        containedIn() { return this; }
        descending() { return this; }
        limit() { return this; }
        get(objectId) {
          if (this.className !== 'Trade' || objectId !== 'trade-33') {
            throw new Error('not found');
          }
          return Promise.resolve({
            get(k) {
              const trade = {
                quantity: 500,
                feeConfig: {},
                createdAt: new Date('2026-05-15T14:30:00.000Z'),
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
                symbol: 'CI4YLSD',
              };
              return trade[k];
            },
          });
        }
        async first() {
          if (this.className !== 'Invoice') return null;
          return {
            get(k) {
              const data = {
                invoiceDate: new Date('2026-05-15T14:30:00.000Z'),
                lineItems: [
                  { itemType: 'securities', description: 'CI4YLSD - PUT - FTSE 100 - 12.808 Pkt. - Citigroup' },
                  { itemType: 'exchangeFee', description: 'Börsenplatzgebühr (XETRA)' },
                ],
              };
              return data[k];
            },
          };
        }
      },
    };
  });

  test('fills fees and instrument from Trade when metadata sparse', async () => {
    const doc = mockDoc({
      type: 'traderCollectionBill',
      tradeId: 'trade-33',
      metadata: { executionType: 'buy', symbol: 'CI4YLSD', amount: 930 },
    });
    const meta = await enrichTraderDocumentMetadata(doc);
    expect(meta.instrumentLine).toContain('CI4YLSD');
    expect(meta.fees.orderFee).toBe(5);
    expect(meta.quantity).toBe(500);
    expect(meta.totalWithFees).toBe(937.5);
    expect(meta.valueDate).toBe('15.05.26');
    expect(meta.tradingVenue).toBe('XETRA');
    expect(meta.instrumentLine).toContain('Citigroup');
  });
});
