'use strict';

describe('handleGetUserDetails integration', () => {
  const formatDate = (d) => (d ? new Date(d).toISOString() : null);

  function mockUser({ id, role, email }) {
    return {
      id,
      createdAt: new Date('2026-01-01'),
      updatedAt: new Date('2026-01-02'),
      get(key) {
        const data = {
          email,
          username: email,
          firstName: role === 'trader' ? 'Trader' : 'Investor',
          lastName: 'Test',
          role,
          status: 'active',
          kycStatus: 'verified',
        };
        return data[key];
      },
    };
  }

  function setupParseMock(userById) {
    class Query {
      constructor(cls) {
        this.cls = cls;
        this.filters = [];
      }
      equalTo(field, value) {
        this.filters.push({ field, value });
        return this;
      }
      descending() { return this; }
      limit() { return this; }
      async first() { return null; }
      async find() { return []; }
      async get(id) {
        const user = userById.get(id);
        if (!user) {
          throw new global.Parse.Error(101, 'Object not found.');
        }
        return user;
      }
    }

    global.Parse = {
      User: class {},
      Query: Query,
      Error: class ParseError extends Error {
        constructor(code, message) {
          super(message);
          this.code = code;
        }
      },
    };
    global.Parse.Error.INVALID_VALUE = 1;
    global.Parse.Error.OBJECT_NOT_FOUND = 101;
  }

  function loadHandlerWithMocks() {
    jest.resetModules();
    jest.doMock('../../../utils/permissions', () => ({
      logPermissionCheck: jest.fn(async () => {}),
    }));
    jest.doMock('../../../utils/userIdentity', () => ({
      readCustomerNumber: () => 'TRD-2026-00001',
    }));
    jest.doMock('../usersDetailFormat', () => ({
      formatAdminUserDate: formatDate,
    }));
    jest.doMock('../usersDetailTrader', () => ({
      loadTraderTradeLists: jest.fn(async (user) => (
        user.get('role') === 'trader'
          ? { trades: [{ id: 't1' }], tradeSummary: { totalTrades: 1 } }
          : { trades: [], tradeSummary: null }
      )),
      enrichTradesWithInvestors: jest.fn(async (trades) => trades),
    }));
    jest.doMock('../usersDetailInvestor', () => ({
      loadInvestorInvestmentLists: jest.fn(async (user) => (
        user.get('role') === 'investor'
          ? { investments: [{ id: 'inv1' }], investmentSummary: { totalInvestments: 1 } }
          : { investments: [], investmentSummary: null }
      )),
      mapInvestmentsForAdminDetail: jest.fn(async (investments) => investments),
    }));
    jest.doMock('../usersDetailStatementsAndWallet', () => ({
      loadAccountStatementAndWalletControls: jest.fn(async (user) => ({
        accountStatement: { entries: [], initialBalance: 0, closingBalance: 0 },
        accountStatementLedger: null,
        clientFundsBreakdown: null,
        investorOutcomeHighlights: null,
        walletControls: { effectiveMode: 'deposit_and_withdrawal' },
        userWalletActionModeOverride: null,
        investorCollectionBills: [],
      })),
    }));

    // eslint-disable-next-line global-require
    return require('../usersGetUserDetails').handleGetUserDetails;
  }

  const adminRequest = {
    params: {},
    user: { id: 'admin-1', get: (k) => (k === 'role' ? 'admin' : null) },
    ip: '127.0.0.1',
    headers: {},
  };

  test('trader: returns user payload and invokes statement loader', async () => {
    const trader = mockUser({ id: 'trader-1', role: 'trader', email: 'trader1@test.com' });
    setupParseMock(new Map([['trader-1', trader]]));
    const handleGetUserDetails = loadHandlerWithMocks();
    const { loadAccountStatementAndWalletControls } = require('../usersDetailStatementsAndWallet');
    const { loadTraderTradeLists } = require('../usersDetailTrader');

    const res = await handleGetUserDetails({
      ...adminRequest,
      params: { userId: 'trader-1' },
    });

    expect(res.user.objectId).toBe('trader-1');
    expect(res.user.role).toBe('trader');
    expect(res.tradeSummary?.totalTrades).toBe(1);
    expect(loadAccountStatementAndWalletControls).toHaveBeenCalledTimes(1);
    expect(loadTraderTradeLists).toHaveBeenCalledTimes(1);
  });

  test('investor: returns user payload and invokes statement loader', async () => {
    const investor = mockUser({ id: 'inv-1', role: 'investor', email: 'investor5@test.com' });
    setupParseMock(new Map([['inv-1', investor]]));
    const handleGetUserDetails = loadHandlerWithMocks();
    const { loadAccountStatementAndWalletControls } = require('../usersDetailStatementsAndWallet');
    const { loadInvestorInvestmentLists } = require('../usersDetailInvestor');

    const res = await handleGetUserDetails({
      ...adminRequest,
      params: { userId: 'inv-1' },
    });

    expect(res.user.objectId).toBe('inv-1');
    expect(res.user.role).toBe('investor');
    expect(res.investmentSummary?.totalInvestments).toBe(1);
    expect(loadAccountStatementAndWalletControls).toHaveBeenCalledTimes(1);
    expect(loadInvestorInvestmentLists).toHaveBeenCalledTimes(1);
  });

  test('missing userId throws INVALID_VALUE', async () => {
    setupParseMock(new Map());
    const handleGetUserDetails = loadHandlerWithMocks();
    await expect(handleGetUserDetails({ ...adminRequest, params: {} }))
      .rejects.toThrow('userId required');
  });
});
