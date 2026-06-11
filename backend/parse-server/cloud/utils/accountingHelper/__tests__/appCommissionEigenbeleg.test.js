'use strict';

jest.mock('../../helpers', () => ({
  generateSequentialNumber: jest.fn().mockResolvedValue('EAP-2026-0000001'),
}));

const { createAppCommissionEigenbeleg } = require('../documents/appCommissionEigenbeleg');

function mockTrade(overrides = {}) {
  return {
    id: 'trade-app-1',
    get(key) {
      const data = {
        tradeNumber: 42,
        symbol: 'ACME',
        traderId: 'trader-1',
        businessCaseId: 'bc-1',
        ...overrides,
      };
      return data[key];
    },
  };
}

describe('createAppCommissionEigenbeleg', () => {
  const saved = [];

  beforeEach(() => {
    saved.length = 0;
    global.Parse = {
      Query: jest.fn().mockImplementation(() => ({
        equalTo: jest.fn().mockReturnThis(),
        containedIn: jest.fn().mockReturnThis(),
        first: jest.fn().mockResolvedValue(null),
      })),
      Object: {
        extend: jest.fn().mockReturnValue(
          class MockDocument {
            constructor() {
              this.attrs = {};
            }
            set(k, v) {
              this.attrs[k] = v;
            }
            get(k) {
              return this.attrs[k];
            }
            async save() {
              this.id = 'eap-doc-1';
              saved.push(this);
              return this;
            }
          },
        ),
      },
    };
  });

  afterEach(() => {
    delete global.Parse;
  });

  test('creates idempotent eigenbeleg with SKR03 booking metadata', async () => {
    const doc = await createAppCommissionEigenbeleg({
      trade: mockTrade(),
      traderId: 'trader-1',
      totalAppCommission: 25.5,
      appCommissionRate: 0.05,
      grossProfitBasis: 510,
      businessCaseId: 'bc-1',
    });

    expect(doc.get('type')).toBe('appCommissionEigenbeleg');
    expect(doc.get('accountingDocumentNumber')).toBe('EAP-2026-0000001');
    expect(doc.get('tradeId')).toBe('trade-app-1');
    expect(doc.get('metadata').appCommissionAmount).toBe(25.5);
    expect(doc.get('metadata').buchungskonten.soll.skr03).toBe('1700');
    expect(doc.get('metadata').buchungskonten.haben.skr03).toBe('8400');
    expect(doc.get('accountingSummaryText')).toContain('Erfolgsprovision');
  });

  test('returns null when amount is zero', async () => {
    const doc = await createAppCommissionEigenbeleg({
      trade: mockTrade(),
      totalAppCommission: 0,
    });
    expect(doc).toBeNull();
  });
});
