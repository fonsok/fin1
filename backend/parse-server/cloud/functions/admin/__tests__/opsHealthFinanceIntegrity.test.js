'use strict';

const {
  worstOverall,
  collectIssues,
} = require('../opsHealthFinanceIntegrity');

describe('opsHealthFinanceIntegrity helpers', () => {
  test('worstOverall picks highest severity', () => {
    expect(worstOverall([
      { overall: 'healthy' },
      { overall: 'degraded' },
      { overall: 'unknown' },
    ])).toBe('degraded');
    expect(worstOverall([
      { overall: 'healthy' },
      { overall: 'down' },
    ])).toBe('down');
  });

  test('collectIssues skips healthy checks', () => {
    const issues = collectIssues([
      { id: 'mirror_basis_drift', overall: 'healthy' },
      { id: 'trader_cash_duplicates', overall: 'degraded' },
    ]);
    expect(issues).toEqual(['trader_cash_duplicates_degraded']);
  });
});

describe('getFinanceIntegrityStatus (admin observability)', () => {
  const cloudFunctions = {};

  const adminUser = {
    id: 'admin-1',
    get(key) {
      if (key === 'role') return 'admin';
      return null;
    },
  };

  function makeSnapshot(id, attrs) {
    const runAt = attrs.runAt || new Date();
    return {
      id,
      attrs: Object.assign({
        healthy: true,
        runAt,
        updatedAt: runAt,
      }, attrs),
      get(key) { return this.attrs[key]; },
    };
  }

  const snapshots = new Map();

  class FakeQuery {
    constructor(className) {
      this.className = className;
    }
    async get(id) {
      if (this.className === 'OpsHealthSnapshot' && snapshots.has(id)) {
        return snapshots.get(id);
      }
      throw new global.Parse.Error(101, 'Object not found');
    }
    equalTo() { return this; }
    exists() { return this; }
    descending() { return this; }
    limit() { return this; }
    async find() { return []; }
    containedIn() { return this; }
  }

  beforeEach(() => {
    jest.resetModules();
    Object.keys(cloudFunctions).forEach((k) => delete cloudFunctions[k]);
    snapshots.clear();
    snapshots.set('mirror-basis-drift', makeSnapshot('mirror-basis-drift', {
      driftedDocuments: 0,
      checkedDocuments: 3,
      healthy: true,
    }));
    snapshots.set('trader-cash-booking-duplicates', makeSnapshot('trader-cash-booking-duplicates', {
      violationCount: 0,
      healthy: true,
    }));

    global.Parse = {
      Cloud: {
        define(name, fn) { cloudFunctions[name] = fn; },
      },
      Query: FakeQuery,
      Error: class ParseError extends Error {
        constructor(code, message) {
          super(message);
          this.code = code;
        }
      },
    };
    global.Parse.Error.OBJECT_NOT_FOUND = 101;
    global.Parse.Error.INVALID_SESSION_TOKEN = 209;
    global.Parse.Error.OPERATION_FORBIDDEN = 119;

    jest.doMock('../../../utils/permissions', () => ({
      requireAdminRole(request) {
        if (!request.user) throw new global.Parse.Error(209, 'Login required');
        if (request.user.get('role') !== 'admin') throw new global.Parse.Error(119, 'Admin access required');
      },
    }));

    jest.doMock('../../../utils/poolActivationLimiter', () => ({
      getPoolActivationLimiterStats: jest.fn().mockResolvedValue({ active: 0, queued: 0, maxConcurrent: 10 }),
    }));
    jest.doMock('../../../utils/pairedBuySettlementQueue', () => ({
      getPairedBuySettlementQueueStats: jest.fn().mockResolvedValue({ active: 0, queued: 0 }),
    }));
    jest.doMock('../../../utils/pairedOrderStatusCoupling', () => ({
      normalizeStatus: (s) => String(s || '').toLowerCase(),
    }));
    jest.doMock('../../../services/poolMirrorActivation/traderCustomerBookingPolicy', () => ({
      TRADER_CUSTOMER_ENTRY_TYPE_SET: new Set(['trade_buy']),
    }));
    jest.doMock('../opsHealthFinancePrevention', () => ({
      handleGetFinanceIntegrityPreventionStatus: jest.fn(async () => ({
        overall: 'healthy',
        accountStatementIndexes: { missing: [] },
      })),
    }));
    const healthyLiveCheck = jest.fn(async () => ({ overall: 'healthy' }));
    jest.doMock('../opsHealthPairedOrderStatusIntegrity', () => ({
      handleGetPairedOrderStatusIntegrityStatus: healthyLiveCheck,
    }));
    jest.doMock('../opsHealthTraderMirrorBookingIntegrity', () => ({
      handleGetTraderMirrorBookingIntegrityStatus: healthyLiveCheck,
    }));
    jest.doMock('../opsHealthTradeSettlementConsistency', () => ({
      handleGetTradeSettlementConsistencyStatus: healthyLiveCheck,
    }));
    jest.doMock('../opsHealthPairedSellInvestorChain', () => ({
      handleGetPairedSellInvestorChainStatus: healthyLiveCheck,
    }));
    jest.doMock('../opsHealthTraderPoolBidAskContract', () => ({
      handleGetTraderPoolBidAskContractStatus: healthyLiveCheck,
    }));
    jest.doMock('../opsHealthSettlementGLReconciliation', () => ({
      handleGetSettlementGLReconciliationStatus: healthyLiveCheck,
    }));
    jest.doMock('../opsHealthTraderCollectionBillBelegDrift', () => ({
      handleGetTraderCollectionBillBelegDriftStatus: healthyLiveCheck,
    }));

    // eslint-disable-next-line global-require
    require('../opsHealth');
  });

  test('returns healthy when all checks pass', async () => {
    const handler = cloudFunctions.getFinanceIntegrityStatus;
    const result = await handler({ user: adminUser, params: { settlementLimit: 5 } });
    expect(result.overall).toBe('healthy');
    expect(result.issues).toEqual([]);
    expect(result.checks.length).toBeGreaterThanOrEqual(5);
    expect(result.layers.prevention).toMatch(/unique indexes/i);
  });

  test('returns degraded when duplicate booking snapshot reports violations', async () => {
    snapshots.set('trader-cash-booking-duplicates', makeSnapshot('trader-cash-booking-duplicates', {
      violationCount: 2,
      healthy: false,
      byTradeNumber: 2,
    }));
    const handler = cloudFunctions.getFinanceIntegrityStatus;
    const result = await handler({ user: adminUser, params: {} });
    expect(result.overall).toBe('degraded');
    expect(result.issues).toContain('trader_cash_duplicates_degraded');
  });
});
