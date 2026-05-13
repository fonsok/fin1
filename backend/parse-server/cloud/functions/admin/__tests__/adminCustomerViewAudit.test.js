'use strict';

describe('logAdminCustomerView', () => {
  const cloudFunctions = {};
  const savedRows = [];

  class FakeUser {
    constructor(id) {
      this.id = id;
    }
    get(key) {
      if (key === 'email') {
        return 'target@example.com';
      }
      if (key === 'customerNumber') {
        return 'ANL-TEST-1';
      }
      return null;
    }
  }

  class FakeUserQuery {
    constructor() {
      this.cls = 'User';
    }
    async get(id) {
      if (id === 'missing') {
        const err = new global.Parse.Error(101, 'Object not found');
        throw err;
      }
      return new FakeUser(id);
    }
  }

  beforeEach(() => {
    jest.resetModules();
    savedRows.length = 0;
    Object.keys(cloudFunctions).forEach((k) => {
      delete cloudFunctions[k];
    });

    global.Parse = {
      Cloud: {
        define(name, fn) {
          cloudFunctions[name] = fn;
        },
      },
      Query: FakeUserQuery,
      User: class {},
      Object: {
        extend() {
          return function AuditLogCtor() {
            this._data = {};
            this.set = (k, v) => {
              this._data[k] = v;
            };
            this.save = async () => {
              savedRows.push({ ...this._data });
              return this;
            };
          };
        },
      },
      Error: class ParseError extends Error {
        constructor(code, message) {
          super(message);
          this.code = code;
        }
      },
    };
    global.Parse.Error.INVALID_VALUE = 1;
    global.Parse.Error.OBJECT_NOT_FOUND = 101;

    jest.doMock('../../../utils/permissions', () => ({
      requirePermission() {},
    }));

    jest.doMock('../../../utils/userIdentity', () => ({
      readCustomerNumber(u) {
        return u.get('customerNumber') || '';
      },
    }));

    // eslint-disable-next-line global-require
    require('../adminCustomerViewAudit');
  });

  it('persists AuditLog admin_customer_view for known target', async () => {
    const request = {
      user: {
        id: 'admin-obj',
        get(key) {
          if (key === 'role') {
            return 'admin';
          }
          if (key === 'email') {
            return 'admin@example.com';
          }
          return null;
        },
      },
      params: {
        targetUserId: 'target-123',
        viewContext: 'user_detail_page',
        reason: 'Support',
      },
      headers: { 'user-agent': 'jest', 'x-forwarded-for': '203.0.113.1, 10.0.0.1' },
      ip: '127.0.0.1',
    };

    const res = await cloudFunctions.logAdminCustomerView(request);
    expect(res).toEqual({ success: true });
    expect(savedRows.length).toBe(1);
    expect(savedRows[0].logType).toBe('admin_customer_view');
    expect(savedRows[0].action).toBe('view_customer_record');
    expect(savedRows[0].resourceId).toBe('target-123');
    expect(savedRows[0].metadata.targetEmail).toBe('target@example.com');
    expect(savedRows[0].metadata.targetCustomerNumber).toBe('ANL-TEST-1');
    expect(savedRows[0].metadata.ip).toBe('203.0.113.1');
    expect(savedRows[0].metadata.reason).toBe('Support');
  });

  it('still logs when target user is not found', async () => {
    const request = {
      user: {
        id: 'admin-obj',
        get(key) {
          if (key === 'role') {
            return 'admin';
          }
          if (key === 'email') {
            return 'admin@example.com';
          }
          return null;
        },
      },
      params: { targetUserId: 'missing', viewContext: 'user_detail_page' },
      headers: {},
      ip: '',
    };

    await cloudFunctions.logAdminCustomerView(request);
    expect(savedRows.length).toBe(1);
    expect(savedRows[0].metadata.targetEmail).toBe('');
    expect(savedRows[0].metadata.targetCustomerNumber).toBe('');
  });

  it('throws when targetUserId missing', async () => {
    const request = {
      user: { id: 'a', get: () => 'admin' },
      params: {},
      headers: {},
    };
    await expect(cloudFunctions.logAdminCustomerView(request)).rejects.toMatchObject({
      code: global.Parse.Error.INVALID_VALUE,
    });
  });
});
