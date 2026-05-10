'use strict';

jest.mock('../../../utils/permissions', () => ({
  logPermissionCheck: jest.fn().mockResolvedValue(undefined),
}));

describe('handleCreateCorrectionRequest (fee_refund)', () => {
  const adminUser = {
    id: 'admin-1',
    get(key) {
      if (key === 'role') return 'admin';
      return null;
    },
  };

  let savedFourEyes;

  function invoiceRow(attrs) {
    return {
      get(k) {
        return attrs[k];
      },
    };
  }

  beforeEach(() => {
    jest.resetModules();
    savedFourEyes = [];

    class FakeFourEyes {
      constructor() {
        this.attrs = {};
        this.id = null;
      }
      set(k, v) {
        this.attrs[k] = v;
      }
      get(k) {
        return this.attrs[k];
      }
      async save() {
        this.id = `fe-${savedFourEyes.length + 1}`;
        savedFourEyes.push({ ...this.attrs, objectId: this.id });
      }
    }

    class FakeQuery {
      async get(id) {
        if (id === 'inv-ok') {
          return invoiceRow({
            invoiceType: 'service_charge',
            userId: 'user-1',
            customerId: 'user-1',
            batchId: 'batch-42',
          });
        }
        if (id === 'inv-wrong-batch') {
          return invoiceRow({
            invoiceType: 'service_charge',
            userId: 'user-1',
            batchId: 'other-batch',
          });
        }
        if (id === 'inv-wrong-user') {
          return invoiceRow({
            invoiceType: 'service_charge',
            userId: 'someone-else',
            batchId: 'batch-42',
          });
        }
        if (id === 'inv-order-type') {
          return invoiceRow({
            invoiceType: 'order',
            userId: 'user-1',
            batchId: 'batch-42',
          });
        }
        const err = new Error('not found');
        err.code = 101;
        throw err;
      }
    }

    global.Parse = {
      Object: {
        extend(name) {
          if (name === 'FourEyesRequest') return FakeFourEyes;
          if (name === 'Invoice') return class {};
          return class {};
        },
      },
      Query: FakeQuery,
      Error: class ParseErr extends Error {
        constructor(code, message) {
          super(message);
          this.code = code;
        }
      },
    };
    global.Parse.Error.INVALID_VALUE = 142;
    global.Parse.Error.OBJECT_NOT_FOUND = 101;
  });

  async function loadHandler() {
    const { handleCreateCorrectionRequest } = require('../financialRoundingAndCorrections');
    return handleCreateCorrectionRequest;
  }

  it('accepts fee_refund when invoiceId and batchId match the invoice', async () => {
    const handleCreateCorrectionRequest = await loadHandler();
    const res = await handleCreateCorrectionRequest({
      user: adminUser,
      params: {
        correctionType: 'fee_refund',
        targetId: 'user-1',
        targetType: 'user',
        reason: 'test',
        oldValue: '0',
        newValue: '119',
        invoiceId: 'inv-ok',
        batchId: 'batch-42',
      },
    });
    expect(res.success).toBe(true);
    expect(savedFourEyes).toHaveLength(1);
    expect(savedFourEyes[0].metadata.invoiceId).toBe('inv-ok');
    expect(savedFourEyes[0].metadata.batchId).toBe('batch-42');
  });

  it('rejects when batchId does not match invoice batch', async () => {
    const handleCreateCorrectionRequest = await loadHandler();
    await expect(
      handleCreateCorrectionRequest({
        user: adminUser,
        params: {
          correctionType: 'fee_refund',
          targetId: 'user-1',
          targetType: 'user',
          reason: 'test',
          oldValue: '0',
          newValue: '10',
          invoiceId: 'inv-wrong-batch',
          batchId: 'batch-42',
        },
      }),
    ).rejects.toMatchObject({ code: 142 });
    expect(savedFourEyes).toHaveLength(0);
  });

  it('rejects when invoice does not belong to targetId', async () => {
    const handleCreateCorrectionRequest = await loadHandler();
    await expect(
      handleCreateCorrectionRequest({
        user: adminUser,
        params: {
          correctionType: 'fee_refund',
          targetId: 'user-1',
          targetType: 'user',
          reason: 'test',
          oldValue: '0',
          newValue: '10',
          invoiceId: 'inv-wrong-user',
          batchId: 'batch-42',
        },
      }),
    ).rejects.toMatchObject({ code: 142 });
    expect(savedFourEyes).toHaveLength(0);
  });

  it('rejects when invoice is not a service-charge type', async () => {
    const handleCreateCorrectionRequest = await loadHandler();
    await expect(
      handleCreateCorrectionRequest({
        user: adminUser,
        params: {
          correctionType: 'fee_refund',
          targetId: 'user-1',
          targetType: 'user',
          reason: 'test',
          oldValue: '0',
          newValue: '10',
          invoiceId: 'inv-order-type',
          batchId: 'batch-42',
        },
      }),
    ).rejects.toMatchObject({ code: 142 });
    expect(savedFourEyes).toHaveLength(0);
  });

  it('rejects when invoice is not found', async () => {
    const handleCreateCorrectionRequest = await loadHandler();
    await expect(
      handleCreateCorrectionRequest({
        user: adminUser,
        params: {
          correctionType: 'fee_refund',
          targetId: 'user-1',
          targetType: 'user',
          reason: 'test',
          oldValue: '0',
          newValue: '10',
          invoiceId: 'missing-id',
          batchId: 'batch-42',
        },
      }),
    ).rejects.toMatchObject({ code: 101 });
    expect(savedFourEyes).toHaveLength(0);
  });

  it('allows fee_refund with only invoiceId (no cross-batch check)', async () => {
    const handleCreateCorrectionRequest = await loadHandler();
    const res = await handleCreateCorrectionRequest({
      user: adminUser,
      params: {
        correctionType: 'fee_refund',
        targetId: 'user-1',
        targetType: 'user',
        reason: 'test',
        oldValue: '0',
        newValue: '50',
        invoiceId: 'inv-ok',
      },
    });
    expect(res.success).toBe(true);
    expect(savedFourEyes[0].metadata.invoiceId).toBe('inv-ok');
    expect(savedFourEyes[0].metadata.batchId).toBeUndefined();
  });
});
