'use strict';

jest.mock('../../../utils/permissions', () => ({
  requireAdminRole: jest.fn(),
}));

let cloudHandler;

beforeEach(() => {
  jest.resetModules();
  global.Parse = {
    Cloud: { define: jest.fn((name, fn) => { cloudHandler = fn; }) },
    Query: class MockQuery {
      constructor(className) {
        this.className = className;
      }
      limit() { return this; }
      async find() {
        if (this.className === '_SCHEMA') {
          throw new Error('SCHEMA not queryable in test');
        }
        return [];
      }
    },
  };
  require('../system');
});

describe('getSystemHealth', () => {
  test('marks MongoDB connected when core class probe succeeds', async () => {
    const out = await cloudHandler({ user: { id: 'admin-1' } });
    expect(out.overall).toBe('healthy');
    expect(out.databases).toEqual(expect.arrayContaining([
      expect.objectContaining({ name: 'MongoDB', connected: true, probedClass: 'Trade' }),
    ]));
    expect(out.services.every((s) => s.status === 'healthy')).toBe(true);
  });
});
