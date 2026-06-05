'use strict';

jest.mock('../schemaMigrationsRegistry', () => ({
  SCHEMA_MIGRATIONS: [
    {
      migrationId: 'unit_test_migration',
      title: 'Unit test migration',
      apply: jest.fn().mockResolvedValue({ ok: true, status: 200 }),
    },
  ],
}));

describe('schemaMigrationRunner', () => {
  let saveMock;
  let firstMock;

  beforeEach(() => {
    jest.clearAllMocks();
    saveMock = jest.fn().mockResolvedValue(undefined);
    firstMock = jest.fn().mockResolvedValue(null);

    function FakeRow() {}
    FakeRow.prototype.set = jest.fn();
    FakeRow.prototype.save = saveMock;

    global.Parse = {
      Object: {
        extend: () => FakeRow,
      },
      Query: jest.fn().mockImplementation(() => ({
        equalTo: jest.fn().mockReturnThis(),
        limit: jest.fn().mockReturnThis(),
        descending: jest.fn().mockReturnThis(),
        first: firstMock,
        find: jest.fn().mockResolvedValue([]),
      })),
    };
  });

  afterEach(() => {
    delete global.Parse;
  });

  test('runPendingSchemaMigrations applies and records once', async () => {
    const { runPendingSchemaMigrations } = require('../schemaMigrationRunner');
    const registry = require('../schemaMigrationsRegistry');

    const out = await runPendingSchemaMigrations({ stopOnError: false });
    expect(out.ok).toBe(true);
    expect(out.results).toHaveLength(1);
    expect(out.results[0].status).toBe('applied');
    expect(registry.SCHEMA_MIGRATIONS[0].apply).toHaveBeenCalledTimes(1);
    expect(saveMock).toHaveBeenCalled();
  });

  test('runPendingSchemaMigrations skips when success already recorded', async () => {
    firstMock.mockResolvedValue({ id: 'x' });
    const { runPendingSchemaMigrations } = require('../schemaMigrationRunner');
    const registry = require('../schemaMigrationsRegistry');

    const out = await runPendingSchemaMigrations({ stopOnError: false });
    expect(out.results[0].status).toBe('already_applied');
    expect(registry.SCHEMA_MIGRATIONS[0].apply).not.toHaveBeenCalled();
  });
});
