'use strict';

const { handleExecutePairedBuy } = require('../tradingPairedBuyExecution');

jest.mock('../tradingIdentity', () => ({
  getUserStableId: jest.fn(() => 'trader-stable-1'),
}));

jest.mock('../../utils/poolMirrorBuyCap', () => ({
  capMirrorPoolQuantityForBuy: jest.fn(async ({ mirrorPoolQuantity }) => ({
    mirrorPoolQuantity,
    capped: false,
    maxGrossAllowed: null,
  })),
}));

jest.mock('../../utils/executionPriceResolver', () => ({
  resolvePairedBuyExecutionPrice: jest.fn(async () => ({
    executionPrice: 1.5,
    priceSource: 'client_quote_validated',
    clientSubmittedPrice: 1.5,
    serverReferencePrice: 1.5,
    priceSnapshotAt: new Date().toISOString(),
    clientQuotedAt: new Date().toISOString(),
  })),
}));

function makeUser(role = 'trader') {
  return {
    id: 'trader-user-1',
    get: (key) => (key === 'role' ? role : null),
  };
}

function makePairedExecution({ id, status, clientOrderIntentId }) {
  const store = new Map([
    ['status', status],
    ['clientOrderIntentId', clientOrderIntentId],
    ['traderId', 'trader-stable-1'],
  ]);
  return {
    id,
    get(key) { return store.get(key); },
    set(key, value) { store.set(key, value); },
    save: jest.fn(async () => {}),
  };
}

function makeOrderLeg({ id, legType, pairExecutionId }) {
  const store = new Map([
    ['legType', legType],
    ['quantity', 10],
    ['price', 1.5],
    ['status', 'submitted'],
    ['pairExecutionId', pairExecutionId],
  ]);
  return {
    id,
    get(key) { return store.get(key); },
    set(key, value) { store.set(key, value); },
    save: jest.fn(async function save() { return this; }),
  };
}

function baseParams(overrides = {}) {
  return {
    symbol: 'WKN-BUY',
    price: 1.5,
    orderInstruction: 'market',
    traderQuantity: 10,
    mirrorPoolQuantity: 0,
    clientOrderIntentId: 'intent-new',
    clientQuotedAt: new Date().toISOString(),
    ...overrides,
  };
}

describe('executePairedBuy idempotent replay', () => {
  let savedLegs;
  let pairedExecutionSaves;
  let PairedExecutionCtor;

  beforeEach(() => {
    jest.clearAllMocks();
    savedLegs = [];
    pairedExecutionSaves = 0;
    PairedExecutionCtor = null;

    const executionsByIntent = {
      'intent-committed': makePairedExecution({
        id: 'pair-committed',
        status: 'COMMITTED',
        clientOrderIntentId: 'intent-committed',
      }),
      'intent-aborted': makePairedExecution({
        id: 'pair-aborted',
        status: 'ABORTED',
        clientOrderIntentId: 'intent-aborted',
      }),
      'intent-cancelled': makePairedExecution({
        id: 'pair-cancelled',
        status: 'CANCELLED',
        clientOrderIntentId: 'intent-cancelled',
      }),
    };

    const ordersByPairId = {
      'pair-committed': [
        makeOrderLeg({ id: 'order-trader-1', legType: 'TRADER', pairExecutionId: 'pair-committed' }),
      ],
      'pair-aborted': [],
    };

    global.Parse = {
      Error: class extends Error {
        constructor(code, message) {
          super(message);
          this.code = code;
        }
        static get INVALID_VALUE() { return 400; }
        static get INVALID_SESSION_TOKEN() { return 209; }
        static get OPERATION_FORBIDDEN() { return 119; }
        static get SCRIPT_FAILED() { return 141; }
      },
      Object: {
        extend: jest.fn((className) => {
          if (className === 'PairedExecution') {
            PairedExecutionCtor = function PairedExecutionCtor() {
              const row = makePairedExecution({
                id: 'pair-new',
                status: 'PREPARED',
                clientOrderIntentId: 'intent-new',
              });
              row.id = `pair-new-${pairedExecutionSaves += 1}`;
              row.save = jest.fn(async () => {});
              return row;
            };
            return PairedExecutionCtor;
          }
          return function OrderCtor() {
            const leg = makeOrderLeg({
              id: `leg-${savedLegs.length + 1}`,
              legType: 'TRADER',
              pairExecutionId: 'pair-new-1',
            });
            leg.save = jest.fn(async () => {
              savedLegs.push(leg);
              return leg;
            });
            return leg;
          };
        }),
        destroyAll: jest.fn(async () => {}),
      },
      Query: jest.fn((subject) => {
        const isPairedExecution = subject === PairedExecutionCtor;
        const isOrder = subject === 'Order';
        const chain = {
          filters: {},
          equalTo(key, value) {
            this.filters[key] = value;
            return this;
          },
          ascending() { return this; },
          first: jest.fn(async () => {
            if (isPairedExecution) {
              const intent = chain.filters.clientOrderIntentId;
              return executionsByIntent[intent] || null;
            }
            return null;
          }),
          find: jest.fn(async () => {
            if (isOrder) {
              const pairId = chain.filters.pairExecutionId;
              return ordersByPairId[pairId] || [];
            }
            return [];
          }),
        };
        return chain;
      }),
    };
  });

  test('creates trader leg for new clientOrderIntentId', async () => {
    const result = await handleExecutePairedBuy({
      user: makeUser(),
      params: baseParams({ clientOrderIntentId: 'intent-new' }),
    });

    expect(result.idempotentReplay).toBe(false);
    expect(result.status).toBe('COMMITTED');
    expect(savedLegs).toHaveLength(1);
    expect(savedLegs[0].get('legType')).toBe('TRADER');
  });

  test('replays existing COMMITTED execution for same clientOrderIntentId', async () => {
    const result = await handleExecutePairedBuy({
      user: makeUser(),
      params: baseParams({ clientOrderIntentId: 'intent-committed' }),
    });

    expect(result.idempotentReplay).toBe(true);
    expect(result.status).toBe('COMMITTED');
    expect(result.pairExecutionId).toBe('pair-committed');
    expect(result.orders).toHaveLength(1);
    expect(savedLegs).toHaveLength(0);
  });

  test('replays existing ABORTED execution without creating new legs', async () => {
    const result = await handleExecutePairedBuy({
      user: makeUser(),
      params: baseParams({ clientOrderIntentId: 'intent-aborted' }),
    });

    expect(result.idempotentReplay).toBe(true);
    expect(result.status).toBe('ABORTED');
    expect(result.pairExecutionId).toBe('pair-aborted');
    expect(result.orders).toEqual([]);
    expect(savedLegs).toHaveLength(0);
  });

  test('rejects replay when paired execution was CANCELLED', async () => {
    await expect(handleExecutePairedBuy({
      user: makeUser(),
      params: baseParams({ clientOrderIntentId: 'intent-cancelled' }),
    })).rejects.toThrow(/cancelled/i);
    expect(savedLegs).toHaveLength(0);
  });
});
