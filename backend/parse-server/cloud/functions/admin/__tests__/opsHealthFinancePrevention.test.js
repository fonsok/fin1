'use strict';

const {
  REQUIRED_ACCOUNT_STATEMENT_UNIQUE_INDEXES,
  handleGetFinanceIntegrityPreventionStatus,
} = require('../opsHealthFinancePrevention');

const mockRequiredIndexNames = [
  'AccountStatement_backend_user_entry_tradeId_unique',
  'AccountStatement_backend_user_entry_businessCase_unique',
  'AccountStatement_backend_user_entry_tradeNumber_unique',
];

jest.mock('mongodb', () => ({
  MongoClient: jest.fn().mockImplementation(() => ({
    connect: jest.fn().mockResolvedValue(undefined),
    close: jest.fn().mockResolvedValue(undefined),
    db: () => ({
      collection: (name) => ({
        indexes: async () => {
          if (name === 'AccountStatement') {
            return mockRequiredIndexNames.map((indexName) => ({
              name: indexName,
              unique: true,
              key: { userId: 1 },
            }));
          }
          return [{ name: 'OpsHealthSnapshot_kind_runAt', key: { kind: 1, runAt: -1 } }];
        },
      }),
    }),
  })),
}));

describe('getFinanceIntegrityPreventionStatus', () => {
  const prevUri = process.env.PARSE_SERVER_DATABASE_URI;

  beforeEach(() => {
    process.env.PARSE_SERVER_DATABASE_URI = 'mongodb://127.0.0.1:27017/fin1';
  });

  afterEach(() => {
    process.env.PARSE_SERVER_DATABASE_URI = prevUri;
  });

  test('returns healthy when required indexes present', async () => {
    const result = await handleGetFinanceIntegrityPreventionStatus();
    expect(result.overall).toBe('healthy');
    expect(result.accountStatementIndexes.missing).toEqual([]);
  });

  test('returns unknown when database uri missing', async () => {
    delete process.env.PARSE_SERVER_DATABASE_URI;
    const result = await handleGetFinanceIntegrityPreventionStatus();
    expect(result.overall).toBe('unknown');
  });
});
