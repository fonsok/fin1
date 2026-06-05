'use strict';

const {
  isCancellableStatus,
  cancelTraderOrder,
} = require('../pairedOrderCancellation');

beforeAll(() => {
  function ParseError(code, message) {
    const err = new Error(message);
    err.code = code;
    return err;
  }
  ParseError.OPERATION_FORBIDDEN = 119;
  ParseError.OBJECT_NOT_FOUND = 101;

  global.Parse = {
    Error: ParseError,
    Query: jest.fn(),
    Object: {
      extend: (name) => name,
      saveAll: jest.fn(async (objects) => objects),
    },
  };
});

function makeOrder(id, fields) {
  const attrs = { ...fields };
  return {
    id,
    get(key) {
      return attrs[key];
    },
    set(key, value) {
      attrs[key] = value;
    },
    save: jest.fn(async () => this),
  };
}

function makePairedExecution(id, fields) {
  const attrs = { ...fields };
  return {
    id,
    get(key) {
      return attrs[key];
    },
    set(key, value) {
      attrs[key] = value;
    },
    save: jest.fn(async () => this),
  };
}

describe('pairedOrderCancellation', () => {
  test('isCancellableStatus accepts pre-execution statuses', () => {
    expect(isCancellableStatus('submitted')).toBe(true);
    expect(isCancellableStatus('pending')).toBe(true);
    expect(isCancellableStatus('suspended')).toBe(true);
    expect(isCancellableStatus('executed')).toBe(false);
    expect(isCancellableStatus('completed')).toBe(false);
  });

  test('cancelTraderOrder cancels all paired legs while submitted', async () => {
    const traderLeg = makeOrder('ord-trader', {
      traderId: 'trader-1',
      pairExecutionId: 'pair-1',
      legType: 'TRADER',
      status: 'submitted',
      tradeId: null,
      executedQuantity: 0,
    });
    const mirrorLeg = makeOrder('ord-mirror', {
      traderId: 'trader-1',
      pairExecutionId: 'pair-1',
      legType: 'MIRROR_POOL',
      status: 'submitted',
      tradeId: null,
      executedQuantity: 0,
    });
    const execution = makePairedExecution('pair-1', {
      traderId: 'trader-1',
      status: 'COMMITTED',
      effectsApplied: false,
    });

    const originalQuery = Parse.Query;
    Parse.Query = jest.fn().mockImplementation(function Query(className) {
      this.equalTo = jest.fn().mockReturnThis();
      this.get = jest.fn(async (id) => {
        if (className === 'Order' && id === 'ord-trader') return traderLeg;
        if (className === 'PairedExecution' && id === 'pair-1') return execution;
        throw new Error(`not found ${className}/${id}`);
      });
      this.find = jest.fn(async () => {
        if (className === 'Order') return [traderLeg, mirrorLeg];
        return [];
      });
    });

    try {
      const result = await cancelTraderOrder('ord-trader', 'trader-1');
      expect(result.cancelledOrderIds).toEqual(['ord-trader', 'ord-mirror']);
      expect(result.cancelledLegCount).toBe(2);
      expect(traderLeg.get('status')).toBe('cancelled');
      expect(mirrorLeg.get('status')).toBe('cancelled');
      expect(execution.get('status')).toBe('CANCELLED');
    } finally {
      Parse.Query = originalQuery;
    }
  });

  test('cancelTraderOrder rejects executed leg', async () => {
    const traderLeg = makeOrder('ord-trader', {
      traderId: 'trader-1',
      pairExecutionId: 'pair-1',
      legType: 'TRADER',
      status: 'executed',
      tradeId: 'trade-1',
      executedQuantity: 100,
    });
    const mirrorLeg = makeOrder('ord-mirror', {
      traderId: 'trader-1',
      pairExecutionId: 'pair-1',
      legType: 'MIRROR_POOL',
      status: 'executed',
      tradeId: 'trade-2',
      executedQuantity: 500,
    });

    const originalQuery = Parse.Query;
    Parse.Query = jest.fn().mockImplementation(function Query(className) {
      this.equalTo = jest.fn().mockReturnThis();
      this.get = jest.fn(async (id) => {
        if (className === 'Order' && id === 'ord-trader') return traderLeg;
        throw new Error(`not found ${className}/${id}`);
      });
      this.find = jest.fn(async () => [traderLeg, mirrorLeg]);
    });

    try {
      await expect(cancelTraderOrder('ord-trader', 'trader-1')).rejects.toMatchObject({
        code: Parse.Error.OPERATION_FORBIDDEN,
      });
    } finally {
      Parse.Query = originalQuery;
    }
  });
});
