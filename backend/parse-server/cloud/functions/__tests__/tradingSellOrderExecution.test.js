'use strict';

const { handleExecuteSellOrder } = require('../tradingSellOrderExecution');

jest.mock('../../utils/configHelper/index.js', () => ({
  loadConfig: jest.fn(async () => ({
    limits: {
      executionPriceMaxQuoteAgeSeconds: 30,
      executionPriceMarketDataMaxAgeSeconds: 300,
      executionPriceToleranceBps: 100,
    },
  })),
}));

jest.mock('../tradingIdentity', () => ({
  getUserStableId: jest.fn(() => 'trader-stable-1'),
}));

jest.mock('../../functions/legal/legalConsentUserSync', () => ({
  resolveUserLegalAcceptanceState: jest.fn(async () => ({
    acceptedTerms: true,
    acceptedPrivacyPolicy: true,
  })),
  resolveUserRoleAgreementState: jest.fn(async () => ({
    required: true,
    accepted: true,
    role: 'trader',
  })),
  resolveRequiredReConsents: jest.fn(async () => ({ required: [] })),
}));

jest.mock('../../utils/helpers', () => ({
  calculateOrderFees: jest.fn(() => ({
    orderFee: 5,
    exchangeFee: 1,
    foreignCosts: 0,
    totalFees: 6,
  })),
}));

function makeUser(role = 'trader') {
  return {
    id: 'trader-user-1',
    get: (k) => {
      if (k === 'role') return role;
      if (k === 'onboardingCompleted') return true;
      return null;
    },
  };
}

function makeOrder(attrs = {}) {
  const store = new Map(Object.entries({
    side: 'sell',
    status: 'submitted',
    orderNumber: 'ORD-SELL-1',
    price: 50,
    grossAmount: 500,
    totalFees: 6,
    netAmount: 494,
    executionPriceSource: 'client_quote_validated',
    ...attrs,
  }));
  return {
    id: attrs.id || 'order-sell-1',
    get(key) { return store.has(key) ? store.get(key) : undefined; },
    set(key, value) { store.set(key, value); },
  };
}

describe('executeSellOrder (ADR-019 Phase 1b)', () => {
  let savedOrder;

  beforeEach(() => {
    jest.clearAllMocks();
    savedOrder = null;

    global.Parse = {
      Error: class extends Error {
        constructor(code, message) {
          super(message);
          this.code = code;
        }
        static get INVALID_VALUE() { return 400; }
        static get INVALID_SESSION_TOKEN() { return 209; }
        static get OPERATION_FORBIDDEN() { return 119; }
        static get OBJECT_NOT_FOUND() { return 101; }
      },
      Object: {
        extend: jest.fn(() => function OrderCtor() {
          const row = makeOrder();
          row.save = jest.fn(async () => {
            savedOrder = row;
            return row;
          });
          return row;
        }),
      },
      Query: jest.fn((className) => {
        const chain = {
          className,
          filters: {},
          equalTo(key, value) {
            this.filters[key] = value;
            return this;
          },
          descending() { return this; },
          limit() { return this; },
          first: jest.fn(async () => {
            if (className === 'MarketData') return null;
            if (className === 'Order'
              && chain.filters.clientOrderIntentId === 'intent-replay'
              && chain.filters.side === 'sell') {
              return makeOrder({ id: 'existing-sell' });
            }
            if (className === 'Trade') {
              return {
                id: 'trade-1',
                get: (k) => {
                  if (k === 'traderId') return 'trader-stable-1';
                  if (k === 'remainingQuantity') return 100;
                  return undefined;
                },
              };
            }
            return null;
          }),
          get: jest.fn(async (id) => {
            if (id === 'trade-1') {
              return {
                id,
                get: (k) => {
                  if (k === 'traderId') return 'trader-stable-1';
                  if (k === 'remainingQuantity') return 100;
                  return undefined;
                },
              };
            }
            throw new Parse.Error(Parse.Error.OBJECT_NOT_FOUND, 'not found');
          }),
        };
        return chain;
      }),
    };
  });

  test('creates sell order with server execution price', async () => {
    const result = await handleExecuteSellOrder({
      user: makeUser(),
      params: {
        symbol: 'WKN-SELL',
        quantity: 10,
        price: 50,
        orderInstruction: 'market',
        clientOrderIntentId: 'intent-new',
        clientQuotedAt: new Date().toISOString(),
        tradeId: 'trade-1',
        originalHoldingId: 'holding-1',
      },
    });

    expect(result.idempotentReplay).toBe(false);
    expect(result.orderId).toBeTruthy();
    expect(result.executionPrice).toBe(50);
    expect(result.grossAmount).toBe(500);
    expect(savedOrder.get('executionPriceSource')).toBe('client_quote_validated');
    expect(savedOrder.get('tradeId')).toBe('trade-1');
  });

  test('replays existing sell for same clientOrderIntentId', async () => {
    const result = await handleExecuteSellOrder({
      user: makeUser(),
      params: {
        symbol: 'WKN-SELL',
        quantity: 10,
        price: 50,
        clientOrderIntentId: 'intent-replay',
      },
    });

    expect(result.idempotentReplay).toBe(true);
    expect(result.orderId).toBe('existing-sell');
    expect(savedOrder).toBeNull();
  });

  test('rejects non-trader', async () => {
    await expect(handleExecuteSellOrder({
      user: makeUser('investor'),
      params: {
        symbol: 'WKN',
        quantity: 1,
        price: 1,
        clientOrderIntentId: 'x',
      },
    })).rejects.toThrow(/Trader role required/i);
  });
});
